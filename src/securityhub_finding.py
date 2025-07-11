# -*- coding: utf-8 -*-
import hashlib
from datetime import datetime
from datetime import timezone

from common import ACCOUNT_ID
from common import AWS_REGION
from common import COMPANY_NAME
from common import GENERATOR_ID
from common import PRODUCT_ARN
from common import PRODUCT_NAME
from common import REMEDIATION_TEXT
from common import REMEDIATION_URL
from common import SECRET_FOUND_CONTROL_ID


class SecurityHubFinding:
    """Represents a Security Hub finding created from secret scanning data.

    Attributes:
        data (dict): The raw finding data.
        repository_name (str): The repository name where the secret was found.
        sent_timestamp (int): The timestamp when the finding was sent.
        commit_id (Optional[str]): The commit ID related to the finding.
        fingerprint (str): The unique fingerprint of the finding.
        secret_url (str): URL linking to the GitHub commit.
        finding_id (str): Unique Security Hub finding ARN.
        timestamp (str): ISO 8601 timestamp string.
    """

    def __init__(
        self,
        finding_data: dict,
        repository_name: str,
        sent_timestamp: int,
    ) -> None:
        """Initialize a SecurityHubFinding instance.

        Args:
            finding_data (dict): The finding information dictionary.
            repository_name (str): The repository name.
            sent_timestamp (int): The timestamp (in milliseconds) when the finding was sent.
        """
        self.data = finding_data
        self.repository_name = repository_name
        self.sent_timestamp = sent_timestamp

        self.commit_id = self.data.get("Commit")
        self.fingerprint = self.data["Fingerprint"]
        self.secret_url = self.generate_commit_url()
        self.finding_id = self.generate_finding_id()
        self.timestamp = self.generate_iso_timestamp()

    def generate_commit_url(self) -> str:
        """Generate the GitHub commit URL based on the repository path and commit ID.

        Returns:
            str: A URL string pointing to the specific commit on GitHub.
        """
        return f"https://github.com/{self.repository_name}/commit/{self.commit_id}"

    def generate_finding_id(self) -> str:
        """Generate a unique Security Hub finding ARN using a SHA-256 hash of the fingerprint.

        Returns:
            str: The ARN string representing the unique finding ID in Security Hub.
        """
        finding_hash = hashlib.sha256(self.fingerprint.encode()).hexdigest()
        return (
            f"arn:aws:securityhub:{AWS_REGION}:{ACCOUNT_ID}:"
            f"{PRODUCT_NAME.lower().replace(' ', '-')}:finding/{finding_hash}"
        )

    def generate_iso_timestamp(self) -> str:
        """Convert the sent timestamp (in milliseconds) to an ISO 8601 formatted UTC timestamp.

        Returns:
            str: ISO 8601 formatted timestamp string in UTC with millisecond precision.
        """
        return (
            datetime.fromtimestamp(self.sent_timestamp / 1000, tz=timezone.utc)
            .isoformat(timespec="milliseconds")
            .replace("+00:00", "Z")
        )

    def to_dict(self) -> dict:
        """Construct the Security Hub finding dictionary conforming to the required schema.

        Returns:
            dict: A dictionary representing the Security Hub finding with all necessary fields.
        """
        return {
            "SchemaVersion": "2018-10-08",
            "Id": self.finding_id,
            "ProductArn": PRODUCT_ARN,
            "ProductName": PRODUCT_NAME,
            "GeneratorId": GENERATOR_ID,
            "AwsAccountId": ACCOUNT_ID,
            "Types": ["GitLeaks Finding"],
            "FirstObservedAt": self.data["Date"],
            "CreatedAt": self.timestamp,
            "UpdatedAt": self.timestamp,
            "Severity": {"Label": "HIGH"},
            "Title": self.data["Description"],
            "Description": "Found potential sensitive secret in GitHub repository",
            "CompanyName": COMPANY_NAME,
            "Resources": [
                {
                    "Type": "GitHubSecret",
                    "Id": self.secret_url,
                    "Details": {
                        "Other": {
                            "Repository": self.repository_name,
                            "Author": self.data["Author"],
                            "Email": self.data["Email"],
                            "RuleId": self.data["RuleID"],
                            "CommitId": self.commit_id,
                            "File": self.data["File"],
                            "StartLine": str(self.data.get("StartLine")),
                            "EndLine": str(self.data.get("EndLine")),
                            "StartColumn": str(self.data.get("StartColumn")),
                            "EndColumn": str(self.data.get("EndColumn")),
                            "Match": str(self.data.get("Match")),
                        },
                    },
                }
            ],
            "Compliance": {
                "Status": "FAILED",
                "SecurityControlId": SECRET_FOUND_CONTROL_ID,
            },
            "ProductFields": {
                "Author": self.data["Author"],
                "Email": self.data["Email"],
                "GitleaksRuleId": self.data["RuleID"],
                "CommitID": self.commit_id,
                "Filename": self.data["File"],
                "Repository": self.repository_name,
                "SecretURL": self.secret_url,
            },
            "Workflow": {"Status": "NEW"},
            "RecordState": "ACTIVE",
            "Remediation": {
                "Recommendation": {
                    "Text": REMEDIATION_TEXT,
                    "Url": REMEDIATION_URL,
                }
            },
        }
