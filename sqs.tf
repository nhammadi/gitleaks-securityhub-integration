module "sqs_queue" {
  source                     = "terraform-aws-modules/sqs/aws"
  version                    = "5.0.0"
  name                       = local.gitleaks_queue_name
  kms_master_key_id          = "alias/aws/sqs"
  visibility_timeout_seconds = 900
  create_queue_policy        = true
  queue_policy_statements = {
    DenyUnsecureTransport = {
      sid     = "DenyUnsecureTransport"
      effect  = "Deny"
      actions = ["sqs:SendMessage", "sqs:ReceiveMessage"]
      principals = [
        {
          type        = "AWS"
          identifiers = ["*"]
        }
      ]
      conditions = [{
        test     = "Bool"
        variable = "aws:SecureTransport"
        values   = ["false"]
      }]
    }
  }
}
