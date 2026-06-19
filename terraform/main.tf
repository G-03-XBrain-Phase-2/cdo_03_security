terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Generate unique suffix for S3 Bucket
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# 1. Create S3 Bucket and Upload sensitive data
resource "aws_s3_bucket" "macie_bucket" {
  bucket        = "cdo-security-macie-demo-${random_string.suffix.result}"
  force_destroy = true
}

resource "aws_s3_object" "sensitive_data" {
  bucket = aws_s3_bucket.macie_bucket.id
  key    = "sensitive-data.csv"
  source = "${path.module}/../sample-data/sensitive-data.csv"
  etag   = filemd5("${path.module}/../sample-data/sensitive-data.csv")
}

# 2. Create SNS Topic & Subscription
resource "aws_sns_topic" "macie_alerts" {
  name = "macie-alerts-topic"
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.macie_alerts.arn
  protocol  = "email"
  endpoint  = var.email_address
}

# Allow EventBridge to publish to SNS Topic
resource "aws_sns_topic_policy" "default" {
  arn    = aws_sns_topic.macie_alerts.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    effect  = "Allow"
    actions = ["SNS:Publish"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    resources = [aws_sns_topic.macie_alerts.arn]
  }
}

# 3. Create EventBridge Rule for Macie Findings
resource "aws_cloudwatch_event_rule" "macie_rule" {
  name        = "macie-findings-rule"
  description = "Capture Macie findings and route to SNS"
  event_pattern = jsonencode({
    source      = ["aws.macie"]
    detail-type = ["Macie Finding"]
  })
}

resource "aws_cloudwatch_event_target" "sns_target" {
  rule      = aws_cloudwatch_event_rule.macie_rule.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.macie_alerts.arn
}

# 4. Enable Macie & Create Classification Job
data "aws_caller_identity" "current" {}

resource "aws_macie2_account" "macie" {
  status = "ENABLED"
}

resource "aws_macie2_classification_job" "macie_job" {
  depends_on = [aws_macie2_account.macie, aws_s3_object.sensitive_data]

  name     = "cdo-macie-scan-job"
  job_type = "ONE_TIME"

  s3_job_definition {
    bucket_definitions {
      account_id = data.aws_caller_identity.current.account_id
      buckets    = [aws_s3_bucket.macie_bucket.id]
    }
  }
}
