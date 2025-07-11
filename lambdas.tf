module "gitleaks_integration_lambda_function" {
  source                            = "terraform-aws-modules/lambda/aws"
  version                           = "8.0.1"
  function_name                     = local.gitleaks_integration_lambda_function_name
  description                       = "Manage Gitleaks findings in AWS Security Hub"
  handler                           = "lambda_function.lambda_handler"
  runtime                           = var.lambda_runtime
  timeout                           = var.lambda_timeout
  cloudwatch_logs_retention_in_days = var.cloudwatch_logs_retention_in_days
  source_path = [
    "${path.module}/src/lambda_function.py",
    "${path.module}/src/common.py",
    "${path.module}/src/securityhub_finding.py",
    {
      pip_requirements = "${path.module}/src/requirements.txt",
    }
  ]
  create_current_version_allowed_triggers = false
  environment_variables = {
    ACCOUNT_ID = local.account_id
  }
  attach_policy_statements = true
  policy_statements = {
    "SQS" = {
      effect    = "Allow"
      actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
      resources = [module.sqs_queue.queue_arn]
    },
    "SecurityHub" = {
      effect = "Allow"
      actions = [
        "securityhub:GetFindings",
        "securityhub:BatchUpdateFindings",
        "securityhub:BatchImportFindings"
      ]
      resources = ["*"]
    }
  }
  event_source_mapping = {
    sqs = {
      event_source_arn = module.sqs_queue.queue_arn
    }
  }

  allowed_triggers = {
    EventBridge = {
      principal  = "sqs.amazonaws.com"
      source_arn = module.sqs_queue.queue_arn
    }
  }
}
