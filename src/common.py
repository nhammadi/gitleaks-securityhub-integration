# -*- coding: utf-8 -*-
import boto3

_session = boto3.session.Session()
AWS_REGION = _session.region_name

_sts_client = boto3.client("sts")
ACCOUNT_ID = _sts_client.get_caller_identity()["Account"]

PRODUCT_NAME = "Gitleaks"
COMPANY_NAME = "GitHub"  # Change to your org
GENERATOR_ID = "Gitleaks"
SECRET_FOUND_CONTROL_ID = "GitHub.1"
REMEDIATION_TEXT = "Remove sensitive data from the repository"
REMEDIATION_URL = (
    "https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/"
    "removing-sensitive-data-from-a-repository"
)

PRODUCT_ARN = (
    f"arn:aws:securityhub:{AWS_REGION}:{ACCOUNT_ID}:product/{ACCOUNT_ID}/default"
)
