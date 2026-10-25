terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}

# AWS Budgets is an account-level billing service. us-east-1 is used
# as a provider configuration region; the budget is not a regional resource.
provider "aws" {
  region = "us-east-1"
}

variable "budget_name" {
  description = "Unique monthly cost budget name within the AWS account."
  type        = string
  default     = "finops-monthly-cost"
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget in USD. Example only, not a cost cap."
  type        = number
  default     = 1000

  validation {
    condition     = var.monthly_budget_usd > 0
    error_message = "monthly_budget_usd must be positive."
  }
}

variable "alert_email" {
  description = "Email address to receive AWS Budgets notifications."
  type        = string
}

resource "aws_budgets_budget" "monthly_cost" {
  name         = var.budget_name
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}

output "budget_name" {
  description = "Created AWS Budgets monthly cost budget."
  value       = aws_budgets_budget.monthly_cost.name
}
