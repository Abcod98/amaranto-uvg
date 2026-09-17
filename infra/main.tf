# Sufijo aleatorio para que el nombre del bucket sea único globalmente.
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

locals {
  bucket_name = "${var.project_name}-site-${random_id.bucket_suffix.hex}"
  tags = {
    Project = var.project_name
  }
}

resource "aws_s3_bucket" "site" {
  bucket = local.bucket_name
  tags   = local.tags
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.project_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  # "AllViewer" reenvia el Host original del navegador, y API Gateway lo rechaza
  # porque no coincide con su propio dominio execute-api. Esta variante omite Host.
  name = "Managed-AllViewerExceptHostHeader"
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  tags                = local.tags
  web_acl_id          = aws_wafv2_web_acl.site.arn

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = local.bucket_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  origin {
    domain_name = replace(replace(aws_apigatewayv2_api.chatbot.api_endpoint, "https://", ""), "http://", "")
    origin_id   = "chatbot-api"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.bucket_name
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  ordered_cache_behavior {
    path_pattern             = "/api/chat*"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    target_origin_id         = "chatbot-api"
    viewer_protocol_policy   = "redirect-to-https"
    compress                 = true
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

data "aws_iam_policy_document" "site" {
  statement {
    sid       = "AllowCloudFrontServicePrincipalReadOnly"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site.json
}

# --- Chatbot backend (Lambda + API Gateway) ---

resource "aws_ssm_parameter" "openrouter_api_key" {
  name  = "/${var.project_name}/openrouter-api-key"
  type  = "SecureString"
  value = var.openrouter_api_key
  tags  = local.tags
}

data "aws_iam_policy_document" "chatbot_lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "chatbot_lambda" {
  name               = "${var.project_name}-chatbot-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.chatbot_lambda_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "chatbot_lambda_basic" {
  role       = aws_iam_role.chatbot_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "chatbot" {
  function_name    = "${var.project_name}-chatbot"
  role             = aws_iam_role.chatbot_lambda.arn
  handler          = "com.amaranto.chatbot.StreamLambdaHandler::handleRequest"
  runtime          = "java17"
  memory_size      = 1024
  timeout          = 20
  filename         = "${path.module}/../backend/target/chatbot-lambda.jar"
  source_code_hash = filebase64sha256("${path.module}/../backend/target/chatbot-lambda.jar")
  tags             = local.tags

  snap_start {
    apply_on = "PublishedVersions"
  }

  environment {
    variables = {
      OPENROUTER_API_KEY = var.openrouter_api_key
      OPENROUTER_MODEL   = var.openrouter_model
    }
  }
}

resource "aws_apigatewayv2_api" "chatbot" {
  name          = "${var.project_name}-chatbot-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "chatbot" {
  api_id                 = aws_apigatewayv2_api.chatbot.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.chatbot.invoke_arn
  # 1.0: aws-serverless-java-container espera el formato de evento tipo API Gateway REST (AwsProxyRequest),
  # no el formato nativo de HTTP API v2 (APIGatewayV2HTTPEvent).
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_route" "chatbot" {
  api_id    = aws_apigatewayv2_api.chatbot.id
  route_key = "POST /api/chat" # coincide con el path que CloudFront reenvia (/api/chat*), sin reescritura
  target    = "integrations/${aws_apigatewayv2_integration.chatbot.id}"
}

resource "aws_apigatewayv2_stage" "chatbot" {
  api_id      = aws_apigatewayv2_api.chatbot.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "chatbot_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chatbot.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.chatbot.execution_arn}/*/*"
}

# --- WAF: rate limit por IP en /api/chat, asociado a CloudFront ---

resource "aws_wafv2_web_acl" "site" {
  name        = "${var.project_name}-waf"
  description = "Rate limit para el chatbot de Amaranto, sitio publico."
  scope       = "CLOUDFRONT"
  tags        = local.tags

  default_action {
    allow {}
  }

  rule {
    name     = "rate-limit-chat"
    priority = 1

    statement {
      rate_based_statement {
        limit              = var.chat_rate_limit_per_5min * 15 # WAF cuenta en ventanas de 5 min, minimo 100
        aggregate_key_type = "IP"

        scope_down_statement {
          byte_match_statement {
            search_string = "/api/chat"
            field_to_match {
              uri_path {}
            }
            positional_constraint = "STARTS_WITH"
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
      }
    }

    action {
      block {}
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit-chat"
    }
  }

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf"
  }
}
