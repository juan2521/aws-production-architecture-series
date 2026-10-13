terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}
provider "aws" { region = var.aws_region }
variable "aws_region" { type = string; default = "us-east-1" }
variable "project" { type = string; default = "data-path" }
variable "environment" { type = string; default = "dev" }
variable "athena_scan_cutoff_bytes" { type = number; default = 10737418240 }
locals { prefix = "${var.project}-${var.environment}" }
data "aws_caller_identity" "current" {}
resource "aws_s3_bucket" "zone" {
  for_each = toset(["raw", "curated", "quarantine", "athena-results"])
  bucket = "${local.prefix}-${each.key}-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  tags = { Project = var.project, Environment = var.environment, Zone = each.key }
}
resource "aws_s3_bucket_public_access_block" "zone" {
  for_each = aws_s3_bucket.zone
  bucket = each.value.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_server_side_encryption_configuration" "zone" {
  for_each = aws_s3_bucket.zone
  bucket = each.value.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}
resource "aws_s3_bucket_versioning" "zone" {
  for_each = aws_s3_bucket.zone
  bucket = each.value.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_kinesis_stream" "events" {
  name = "${local.prefix}-events"
  shard_count = 1
  retention_period = 24
  encryption_type = "KMS"
  kms_key_id = "alias/aws/kinesis"
  tags = { Project = var.project, Environment = var.environment }
}
resource "aws_glue_catalog_database" "curated" {
  name = replace("${local.prefix}_curated", "-", "_")
}
resource "aws_athena_workgroup" "curated" {
  name = "${local.prefix}-curated"
  configuration {
    enforce_workgroup_configuration = true
    bytes_scanned_cutoff_per_query = var.athena_scan_cutoff_bytes
    result_configuration {
      output_location = "s3://${aws_s3_bucket.zone["athena-results"].bucket}/results/"
      encryption_configuration { encryption_option = "SSE_S3" }
    }
  }
  tags = { Project = var.project, Environment = var.environment }
}
output "bucket_names" { value = { for k,v in aws_s3_bucket.zone : k => v.bucket } }
output "stream_name" { value = aws_kinesis_stream.events.name }
output "glue_database" { value = aws_glue_catalog_database.curated.name }
output "athena_workgroup" { value = aws_athena_workgroup.curated.name }
