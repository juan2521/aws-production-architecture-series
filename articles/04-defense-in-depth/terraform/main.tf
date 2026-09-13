terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" { region = var.aws_region }

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "trail_bucket" {
  statement {
    sid = "AWSCloudTrailAclCheck"
    principals { type = "Service" identifiers = ["cloudtrail.amazonaws.com"] }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.audit.arn]
  }
  statement {
    sid = "AWSCloudTrailWrite"
    principals { type = "Service" identifiers = ["cloudtrail.amazonaws.com"] }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.audit.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    condition {
      test = "StringEquals"
      variable = "s3:x-amz-acl"
      values = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket" "audit" { bucket_prefix = "juan-security-audit-" }
resource "aws_s3_bucket_public_access_block" "audit" {
  bucket = aws_s3_bucket.audit.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "audit" {
  bucket = aws_s3_bucket.audit.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}
resource "aws_s3_bucket_policy" "audit" {
  bucket = aws_s3_bucket.audit.id
  policy = data.aws_iam_policy_document.trail_bucket.json
}
resource "aws_cloudtrail" "security" {
  name = "security-baseline"
  s3_bucket_name = aws_s3_bucket.audit.id
  include_global_service_events = true
  is_multi_region_trail = true
  enable_log_file_validation = true
  depends_on = [aws_s3_bucket_policy.audit]
}
resource "aws_guardduty_detector" "this" { enable = true }
output "audit_bucket" { value = aws_s3_bucket.audit.id }
