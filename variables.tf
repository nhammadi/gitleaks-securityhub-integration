variable "region" {
  type        = string
  description = "Default AWS region."
  default     = "eu-west-1"
}

variable "lambda_timeout" {
  type        = string
  default     = 900
  description = "Default timeout for the Lambda function"
}

variable "lambda_runtime" {
  type        = string
  default     = "python3.13"
  description = "Default Lambda function runtime"
}

variable "cloudwatch_logs_retention_in_days" {
  type        = number
  description = "Default retention period for lambda Cloudwatch groups"
  default     = 30
}
