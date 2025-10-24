# modules/backend/outputs.tf
output "api_endpoint" {
  description = "The publicly accessible URL for the visitor counter API."
  value       = aws_apigatewayv2_stage.default.invoke_url
}