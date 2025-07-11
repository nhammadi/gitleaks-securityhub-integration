# -*- coding: utf-8 -*-
import json
import logging
from typing import List
from typing import Optional

import backoff
import boto3
import botocore
from common import COMPANY_NAME
from common import GENERATOR_ID
from common import PRODUCT_ARN
from common import PRODUCT_NAME
from common import SECRET_FOUND_CONTROL_ID
from securityhub_finding import SecurityHubFinding

logger = logging.getLogger()
logger.setLevel(logging.INFO)

RETRY_COUNTS = 10

securityhub = boto3.client("securityhub")
get_findings_paginator = securityhub.get_paginator("get_findings")


@backoff.on_exception(
    backoff.expo, botocore.exceptions.ClientError, max_tries=RETRY_COUNTS
)
def get_findings_by_repository_name(repository_name: str) -> Optional[dict]:
    """Return all findings related to a GitHub repository."""
    return get_findings_paginator.paginate(
        Filters={
            "GeneratorId": [{"Value": GENERATOR_ID, "Comparison": "EQUALS"}],
            "ProductName": [{"Value": PRODUCT_NAME, "Comparison": "EQUALS"}],
            "CompanyName": [{"Value": COMPANY_NAME, "Comparison": "EQUALS"}],
            "RecordState": [{"Value": "ACTIVE", "Comparison": "EQUALS"}],
            "ComplianceSecurityControlId": [
                {"Value": SECRET_FOUND_CONTROL_ID, "Comparison": "EQUALS"}
            ],
            "WorkflowStatus": [{"Value": "NEW", "Comparison": "EQUALS"}],
            "ProductFields": [
                {"Key": "Repository", "Value": repository_name, "Comparison": "EQUALS"}
            ],
        }
    )


@backoff.on_exception(
    backoff.expo, botocore.exceptions.ClientError, max_tries=RETRY_COUNTS
)
def resolve_findings(finding_ids_to_resolve: List[str]) -> None:
    """Update findings to RESOLVED WorkflowStatus with INFORMATIONAL Severity."""
    if not finding_ids_to_resolve:
        logger.info("No findings to resolve.")
        return
    logger.info(f"Resolving findings: {finding_ids_to_resolve}")
    securityhub.batch_update_findings(
        FindingIdentifiers=[
            {"Id": finding_id, "ProductArn": PRODUCT_ARN}
            for finding_id in finding_ids_to_resolve
        ],
        Workflow={"Status": "RESOLVED"},
        Severity={"Label": "INFORMATIONAL"},
    )


def import_findings(findings: List[dict]) -> None:
    """Import a list of findings into AWS Security Hub.

    Args:
        findings (List[dict]): A list of finding dictionaries to be imported.

    Returns:
        None
    """
    if findings:
        securityhub.batch_import_findings(Findings=findings)


def lambda_handler(event: dict, context: dict) -> dict:
    """AWS Lambda function entry point that processes incoming Security Hub findings.

    This function:
    - Parses the incoming event records containing GitHub repository findings.
    - Generates new Security Hub findings from the event data.
    - Imports new findings into Security Hub.
    - Retrieves existing findings for the repository and resolves outdated ones.

    Args:
        event (dict): The event data passed by AWS Lambda, expected to contain SNS/SQS records.
        context (dict): The runtime information provided by AWS Lambda.

    Returns:
        dict: A response dictionary with statusCode and body confirming processing completion.
    """
    for record in event.get("Records", []):
        message = json.loads(record.get("body", "{}"))
        repository_name = message.get("Repository")
        sent_timestamp = int(record.get("attributes").get("SentTimestamp"))
        findings_data = message.get("Leaks", [])

        finding_objs = [
            SecurityHubFinding(finding, repository_name, sent_timestamp)
            for finding in findings_data
        ]
        new_finding_ids = [f.finding_id for f in finding_objs]
        new_finding_dicts = [f.to_dict() for f in finding_objs]

        import_findings(new_finding_dicts)

        existing_pages = get_findings_by_repository_name(repository_name)
        existing_ids = {f["Id"] for page in existing_pages for f in page["Findings"]}
        findings_to_resolve = list(existing_ids - set(new_finding_ids))

        resolve_findings(findings_to_resolve)

    return {"statusCode": 200, "body": json.dumps("Processed and updated findings.")}
