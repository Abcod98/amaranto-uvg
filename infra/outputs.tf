output "s3_bucket_name" {
  value = aws_s3_bucket.site.bucket
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.site.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.site.id
}

output "chatbot_api_direct_endpoint" {
  description = "Endpoint directo de API Gateway (sin WAF), útil para depurar."
  value       = "${aws_apigatewayv2_api.chatbot.api_endpoint}/api/chat"
}
