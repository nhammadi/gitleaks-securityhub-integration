# gitleaks-securityhub-integration

A **serverless solution** allowing to ingest [Gitleaks](https://github.com/gitleaks/gitleaks) findings to **AWS Security Hub** via a POST request to a REST API deployed in **AWS API Gateway** or an **AWS SQS queue**

---

## 🔧 Features

- Can be easily integrated with CI/CD tools (GitHub Actions, Jenkins, GitLab CI/CD ...etc)
- Converts raw Gitleaks JSON findings into AWS Security Finding Format (ASFF)
- Findings can be sent to AWS native services (SQS or API Gateway)
- Built with Terraform for easy infrastructure provisioning
- Lightweight, serverless, and cost-effective

---

## 🛠️ Prerequisites for local testing

- AWS Account with:
  - Security Hub enabled
  - AWS credentials with permissions to manage Lambda, SQS, API Gateway
- Tools:
  - [`jq`](https://stedolan.github.io/jq/)
  - `curl` (for REST API option)
  - `aws-cli` (for direct SQS option)
  - `terraform`
  - `python`
  - `pre-commit`
  - `Gitleaks`


## ⚙️ Architecture

The solution is composed of the following AWS-native components:

- **API Gateway (REST API)**
  - Accepts incoming Gitleaks findings over HTTPS.
  - Protected using an **API key**.
  - Integrates directly with an **Amazon SQS queue** to buffer incoming findings in JSON format.

- **Amazon SQS**
  - Decouples ingestion from processing.
  - Provides durable, scalable storage of findings prior to processing.

- **AWS Lambda (Python)**
  - Consumes SQS messages asynchronously.
  - Transforms each finding into the [ASFF (AWS Security Finding Format)](https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-findings-format.html).
  - Creates or updates findings in **AWS Security Hub**.
  - Uses the `backoff` library to gracefully handle retry logic when throttled by AWS APIs.

## 🧩 Submission Options

You can choose **either** of the following submission paths based on your environment:

Use the following command to run Gitleaks and output findings in JSON format:

```bash
gitleaks detect --verbose \
  --source . \
  --report-format json \
  --report-path gitleaks-report.json \
  --redact
```

### ✅ Option 1: Submit via REST API (No AWS CLI)

Ideal for CI/CD environments where AWS credentials are **not** available. Just use an API key and HTTPS endpoint.

```bash
#!/bin/bash
GITLEAKS_REPORT="gitleaks-report.json"
API_URL="${API_URL}"
API_KEY="${API_KEY}"

REPO_NAME="${GITHUB_REPOSITORY}"
jq --arg repo_name "$REPO_NAME" \
   '{
      Repository: $repo_name,
      Leaks: .
    }' "$GITLEAKS_REPORT" | \
curl -s -X POST "$API_URL" \
     -H "Content-Type: application/json" \
     -H "x-api-key: $API_KEY" \
     --data-binary @-

```

### ✅ Option 2: Submit Directly to SQS (AWS CLI required)
Ideal for trusted environments with access to AWS credentials.

```bash
#!/bin/bash
GITLEAKS_REPORT="gitleaks-report.json"
SQS_QUEUE_URL="${SQS_QUEUE_URL}"
REPO_NAME="${GITHUB_REPOSITORY}"

jq --arg repo_name "$REPO_NAME" \
   '{
      Repository: $repo_name,
      Leaks: .
    }' "$GITLEAKS_REPORT" | \
aws sqs send-message \
  --queue-url "$SQS_QUEUE_URL" \
  --message-body file:///dev/stdin
```
## 🔧 Potential Improvements

To enhance security and reduce your attack surface, and meet enterprise-grade compliance standards., consider the following improvements:

- **Private API Gateway Endpoint**
  If your CI/CD system runs inside a private VPC (e.g., in AWS CodeBuild, EC2, or a self-managed runner), deploy the API Gateway as a **private endpoint**. This restricts access to internal networks only, preventing public exposure.

- **CloudWatch Log Groups Customization**
  Configure CloudWatch Log Groups with:
  - **Fine-tuned retention policies** to manage log storage efficiently.
  - **Encryption using AWS KMS CMK** to protect logs containing sensitive data.

- **SQS Encryption with AWS KMS**
  Enable **server-side encryption (SSE)** for the SQS queue using a **customer-managed AWS KMS key (CMK)** to protect sensitive findings at rest and meet compliance requirements.
