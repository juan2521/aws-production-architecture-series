terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "environment must be dev, qa or prod."
  }
}

variable "log_retention_days" {
  type    = number
  default = 30
  validation {
    condition     = contains([1,3,5,7,14,30,60,90,120,150,180,365,400,545,731,1096,1827,2192,2557,2922,3288,3653], var.log_retention_days)
    error_message = "Use a supported CloudWatch Logs retention value."
  }
}

resource "aws_cloudwatch_log_group" "platform" {
  name              = "/reference/final-architecture/${var.environment}"
  retention_in_days = var.log_retention_days
  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "AWS-Final-Architecture"
    Owner       = "Juan-Gutierrez"
  }
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.platform.name
}
