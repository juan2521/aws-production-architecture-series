terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

provider "aws" { region = var.aws_region }

data "aws_caller_identity" "current" {}

resource "aws_bedrock_guardrail" "production" {
  name                      = "${var.name}-guardrail"
  description               = "Baseline production guardrail managed by Terraform"
  blocked_input_messaging   = "I cannot process that request."
  blocked_outputs_messaging = "I cannot return that response."

  content_policy_config {
    filters_config { input_strength = "HIGH" output_strength = "HIGH" type = "HATE" }
    filters_config { input_strength = "HIGH" output_strength = "HIGH" type = "VIOLENCE" }
    filters_config { input_strength = "HIGH" output_strength = "HIGH" type = "SEXUAL" }
    filters_config { input_strength = "HIGH" output_strength = "HIGH" type = "MISCONDUCT" }
    filters_config { input_strength = "HIGH" output_strength = "HIGH" type = "INSULTS" }
    filters_config { input_strength = "HIGH" output_strength = "HIGH" type = "PROMPT_ATTACK" }
  }

  sensitive_information_policy_config {
    pii_entities_config { action = "ANONYMIZE" type = "EMAIL" }
    pii_entities_config { action = "ANONYMIZE" type = "PHONE" }
  }
}

resource "aws_bedrock_guardrail_version" "production" {
  guardrail_arn = aws_bedrock_guardrail.production.guardrail_arn
  description   = "Immutable version promoted by IaC"
}

resource "aws_iam_role" "app" {
  name = "${var.name}-bedrock-runtime"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}

resource "aws_iam_role_policy" "bedrock" {
  role = aws_iam_role.app.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream", "bedrock:ApplyGuardrail"]
      Resource = compact([var.model_arn, aws_bedrock_guardrail.production.guardrail_arn])
    }]
  })
}

variable "aws_region" { type = string default = "us-east-1" }
variable "name"       { type = string default = "genai-production" }
variable "model_arn" {
  type        = string
  description = "Exact foundation model or inference-profile ARN approved for this workload."
}

output "guardrail_id"      { value = aws_bedrock_guardrail.production.guardrail_id }
output "guardrail_version" { value = aws_bedrock_guardrail_version.production.version }
output "runtime_role_arn"  { value = aws_iam_role.app.arn }
