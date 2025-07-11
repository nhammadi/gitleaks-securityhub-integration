output "gitleaks_securityhub_integration_lambda_function_arn" {
  description = "ARN of the gitleaks-securityhub-integration lambda function"
  value       = module.gitleaks_integration_lambda_function.lambda_function_arn
}

output "gitleaks_securityhub_rest_api_url" {
  description = "URI of the gitleaks-securityhub REST API"
  value       = aws_api_gateway_stage.gitleaks_securityhub_api_stage.invoke_url
}
