# modules/frontend/variables.tf

variable "domain_name" {
  description = "The root domain name for the resume website (e.g., resume.yourdomain.com)."
  type        = string
}

variable "api_url" {
  description = "The Invoke URL of the deployed API Gateway endpoint."
  type        = string
}