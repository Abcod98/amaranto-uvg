variable "aws_region" {
  description = "Región de AWS donde vive el bucket S3 (CloudFront es global)."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre usado para tags y como prefijo del bucket."
  type        = string
  default     = "amaranto-uvg"
}

variable "openrouter_api_key" {
  description = "API key de OpenRouter para el chatbot. Pasar vía TF_VAR_openrouter_api_key, nunca commitear."
  type        = string
  sensitive   = true
}

variable "openrouter_model" {
  description = "Modelo de OpenRouter a usar por el chatbot."
  type        = string
  default     = "openai/gpt-4o-mini"
}

variable "chat_rate_limit_per_5min" {
  description = "Máximo de requests por IP a /api/chat en una ventana de 5 minutos (WAF)."
  type        = number
  default     = 20
}
