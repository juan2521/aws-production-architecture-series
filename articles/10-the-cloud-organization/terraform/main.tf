terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}

# Run only with credentials authorized to manage SCPs in AWS Organizations.
# This is an UNATTACHED policy by default; it creates no accounts or landing zone.
provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS provider region (Organizations policy APIs are global)."
  type        = string
  default     = "us-east-1"
}

variable "policy_name" {
  description = "Unique name for the sample SCP."
  type        = string
  default     = "example-protect-audit-logging"
}

variable "attach_policy" {
  description = "Opt-in only: attach the SCP to an existing test OU after review."
  type        = bool
  default     = false
}

variable "target_ou_id" {
  description = "Existing AWS Organizations OU ID, required only when attach_policy=true."
  type        = string
  default     = ""
}

resource "aws_organizations_policy" "audit_guardrail" {
  name        = var.policy_name
  description = "Example preventive guardrail for member-account audit logging. Test before attaching."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyDisablingCoreAuditLogging"
        Effect = "Deny"
        Action = [
          "cloudtrail:StopLogging",
          "cloudtrail:DeleteTrail",
          "config:StopConfigurationRecorder",
          "config:DeleteConfigurationRecorder"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    purpose    = "governance-demo"
    managed-by = "terraform"
    chapter    = "10"
  }
}

# The default count is ZERO. Explicit opt-in and a valid test OU are required.
resource "aws_organizations_policy_attachment" "lab_ou" {
  count     = var.attach_policy ? 1 : 0
  policy_id = aws_organizations_policy.audit_guardrail.id
  target_id = var.target_ou_id

  lifecycle {
    precondition {
      condition     = startswith(var.target_ou_id, "ou-")
      error_message = "Set target_ou_id to an existing OU ID (ou-...) before attachment."
    }
  }
}

output "policy_id" {
  description = "ID of the example SCP after apply."
  value       = aws_organizations_policy.audit_guardrail.id
}

output "attachment_enabled" {
  description = "Whether the optional test-OU attachment was requested."
  value       = var.attach_policy
}
