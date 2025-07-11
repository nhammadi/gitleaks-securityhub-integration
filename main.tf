resource "aws_api_gateway_account" "api_gateway_account_settings" {
  cloudwatch_role_arn = aws_iam_role.apigateway_cloudwatch_role.arn
}

resource "aws_api_gateway_rest_api" "gitleaks_securityhub_api" {
  name        = local.rest_api_name
  description = "API Gateway to ingest gitleaks findings to the SQS queue"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_rest_api_policy" "gitleaks_securityhub_api_policy" {
  rest_api_id = aws_api_gateway_rest_api.gitleaks_securityhub_api.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "execute-api:Invoke"
        Resource  = "${aws_api_gateway_rest_api.gitleaks_securityhub_api.execution_arn}/*"
        Effect    = "Allow"
        Principal = "*"
      },
    ]
  })
}
