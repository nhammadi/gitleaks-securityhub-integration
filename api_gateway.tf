resource "aws_api_gateway_resource" "gitleaks_securityhub_api_gateway_findings_resource" {
  rest_api_id = aws_api_gateway_rest_api.gitleaks_securityhub_api.id
  parent_id   = aws_api_gateway_rest_api.gitleaks_securityhub_api.root_resource_id
  path_part   = "findings"
}

resource "aws_api_gateway_model" "leaks_validation_model" {
  rest_api_id  = aws_api_gateway_rest_api.gitleaks_securityhub_api.id
  name         = local.leaks_validation_model_name
  content_type = "application/json"
  schema       = file("${path.module}/schema.json")
}

resource "aws_api_gateway_request_validator" "body_validator" {
  rest_api_id                 = aws_api_gateway_rest_api.gitleaks_securityhub_api.id
  name                        = "ValidateBodyOnly"
  validate_request_body       = true
  validate_request_parameters = false
}

resource "aws_api_gateway_method" "gitleaks_securityhub_api_gateway_findings_method" {
  rest_api_id      = aws_api_gateway_rest_api.gitleaks_securityhub_api.id
  resource_id      = aws_api_gateway_resource.gitleaks_securityhub_api_gateway_findings_resource.id
  api_key_required = true
  http_method      = "POST"
  authorization    = "NONE"
  request_models = {
    "application/json" = aws_api_gateway_model.leaks_validation_model.name
  }

  request_validator_id = aws_api_gateway_request_validator.body_validator.id
}

resource "aws_api_gateway_integration" "gitleaks_securityhub_api_integration" {
  rest_api_id             = aws_api_gateway_rest_api.gitleaks_securityhub_api.id
  resource_id             = aws_api_gateway_resource.gitleaks_securityhub_api_gateway_findings_resource.id
  http_method             = aws_api_gateway_method.gitleaks_securityhub_api_gateway_findings_method.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${local.region}:sqs:path/${local.account_id}/${module.sqs_queue.queue_name}"
  credentials             = aws_iam_role.apigateway_sqs_role.arn

  request_parameters = {
    "integration.request.header.Content-Type" : "'application/x-www-form-urlencoded'"
  }

  request_templates = {
    "application/json" : "Action=SendMessage&MessageBody=$input.body"
  }
}

resource "aws_api_gateway_method_response" "gitleaks_securityhub_api_gateway_findings_method_response_200" {
  rest_api_id = aws_api_gateway_rest_api.gitleaks_securityhub_api.id
  resource_id = aws_api_gateway_resource.gitleaks_securityhub_api_gateway_findings_resource.id
  http_method = aws_api_gateway_method.gitleaks_securityhub_api_gateway_findings_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "gitleaks_securityhub_api_gateway_findings_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.gitleaks_securityhub_api.id
  resource_id = aws_api_gateway_resource.gitleaks_securityhub_api_gateway_findings_resource.id
  http_method = aws_api_gateway_method.gitleaks_securityhub_api_gateway_findings_method.http_method
  status_code = aws_api_gateway_method_response.gitleaks_securityhub_api_gateway_findings_method_response_200.status_code

  depends_on = [
    aws_api_gateway_integration.gitleaks_securityhub_api_integration
  ]
}

resource "aws_api_gateway_deployment" "gitleaks_securityhub_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.gitleaks_securityhub_api.id

  lifecycle {
    create_before_destroy = true
  }
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.gitleaks_securityhub_api_gateway_findings_resource.id,
      aws_api_gateway_method.gitleaks_securityhub_api_gateway_findings_method.id,
      aws_api_gateway_model.leaks_validation_model,
      aws_api_gateway_request_validator.body_validator,
      aws_api_gateway_rest_api_policy.gitleaks_securityhub_api_policy.id,
      aws_api_gateway_integration.gitleaks_securityhub_api_integration.id,
      aws_api_gateway_method_response.gitleaks_securityhub_api_gateway_findings_method_response_200.status_code,
      aws_api_gateway_integration_response.gitleaks_securityhub_api_gateway_findings_integration_response.id
    ]))
  }
  depends_on = [aws_api_gateway_rest_api_policy.gitleaks_securityhub_api_policy]
}

resource "aws_api_gateway_stage" "gitleaks_securityhub_api_stage" {
  stage_name           = local.rest_api_stage_name
  deployment_id        = aws_api_gateway_deployment.gitleaks_securityhub_api_deployment.id
  rest_api_id          = aws_api_gateway_rest_api.gitleaks_securityhub_api.id
  xray_tracing_enabled = "true"
  access_log_settings { # https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-logging.html
    destination_arn = aws_cloudwatch_log_group.gitleaks_securityhub_api_access_logs.arn
    format = jsonencode({
      "requestId" : "$context.requestId",
      "extendedRequestId" : "$context.extendedRequestId",
      "ip" : "$context.identity.sourceIp",
      "caller" : "$context.identity.caller",
      "user" : "$context.identity.user",
      "requestTime" : "$context.requestTime",
      "httpMethod" : "$context.httpMethod",
      "resourcePath" : "$context.resourcePath",
      "status" : "$context.status",
      "protocol" : "$context.protocol",
      "responseLength" : "$context.responseLength"
    })
  }
  depends_on = [
    aws_cloudwatch_log_group.gitleaks_securityhub_api_access_logs,
    aws_api_gateway_rest_api_policy.gitleaks_securityhub_api_policy,
    aws_api_gateway_account.api_gateway_account_settings
  ]
}

resource "aws_api_gateway_usage_plan" "gitleaks_securityhub_api_usage_plan" {
  name = "DefaultPlan"

  api_stages {
    api_id = aws_api_gateway_rest_api.gitleaks_securityhub_api.id
    stage  = aws_api_gateway_stage.gitleaks_securityhub_api_stage.stage_name
  }
}

resource "aws_api_gateway_api_key" "gitleaks_securityhub_api_key" {
  name        = local.rest_api_key_name
  description = "API Key for ${local.rest_api_name} REST API"
  enabled     = true
}


resource "aws_api_gateway_usage_plan_key" "gitleaks_securityhub_api_plan_key" {
  key_id        = aws_api_gateway_api_key.gitleaks_securityhub_api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.gitleaks_securityhub_api_usage_plan.id
}


resource "aws_api_gateway_method_settings" "gitleaks_securityhub_api_settings" {
  rest_api_id = aws_api_gateway_rest_api.gitleaks_securityhub_api.id
  stage_name  = aws_api_gateway_stage.gitleaks_securityhub_api_stage.stage_name
  method_path = "*/*"

  settings {
    logging_level        = "INFO"
    metrics_enabled      = true
    data_trace_enabled   = true
    cache_data_encrypted = false
  }
}

resource "aws_cloudwatch_log_group" "gitleaks_securityhub_api_access_logs" {
  name              = "APIG-Execution-Logs_${aws_api_gateway_rest_api.gitleaks_securityhub_api.name}"
  retention_in_days = 90
}
