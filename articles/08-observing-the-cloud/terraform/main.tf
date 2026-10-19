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
  default = "demo"
}

variable "alb_arn_suffix" {
  type        = string
  description = "ALB ARN suffix, e.g. app/my-alb/1234567890abcdef"
}

variable "alarm_sns_topic_arn" {
  type        = string
  description = "ARN of an existing SNS topic for alarm notifications"
}

resource "aws_cloudwatch_log_group" "application" {
  name              = "/architecture-observability/${var.environment}/application"
  retention_in_days = 30

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = "Juan Gutierrez"
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_http_5xx" {
  alarm_name          = "${var.environment}-alb-http-5xx"
  alarm_description   = "ALB 5xx count above threshold; tune for workload volume and SLO."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 10
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [var.alarm_sns_topic_arn]
  ok_actions    = [var.alarm_sns_topic_arn]
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.application.name
}
