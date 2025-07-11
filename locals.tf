locals {
  account_id                                = data.aws_caller_identity.current.account_id
  region                                    = data.aws_region.current.region
  gitleaks_queue_name                       = "gitleaks-queue"
  gitleaks_integration_lambda_function_name = "gitleaks-securityhub-integration"
  apigateway_cloudwatch_role_name           = "aws-gateway-role-for-cloudwatch"
  apigateway_cloudwatch_policy_name         = "apigateway-clouwatch-policy"
  rest_api_name                             = "gitleaks-securityhub-api"
  rest_api_stage_name                       = "v1"
  leaks_validation_model_name               = "LeaksInputModel"
  rest_api_key_name                         = "${local.rest_api_name}-key"
  apigateway_sqs_role_name                  = "apigateway-sqs-role"
  apigateway_sqs_policy_name                = "apigateway-sqs-policy"
}
