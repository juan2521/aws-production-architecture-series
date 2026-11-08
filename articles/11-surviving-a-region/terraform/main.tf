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
  region = "us-east-1"
}

variable "zone_id" {
  type        = string
  description = "Existing public Route 53 hosted zone ID"
}
variable "record_name" {
  type        = string
  description = "DNS name within the hosted zone"
}
variable "primary_ip" {
  type        = string
  description = "Existing public IPv4 address of primary endpoint"
}
variable "secondary_ip" {
  type        = string
  description = "Existing public IPv4 address of standby endpoint"
}
variable "health_fqdn" {
  type        = string
  description = "Public hostname for primary health endpoint; must resolve to primary_ip"
}

resource "aws_route53_health_check" "primary" {
  fqdn              = var.health_fqdn
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health/ready"
  request_interval  = 30
  failure_threshold = 3
  enable_sni        = true
  tags = {
    Name = "chapter-11-primary-health"
  }
}

resource "aws_route53_record" "primary" {
  zone_id         = var.zone_id
  name            = var.record_name
  type            = "A"
  ttl             = 60
  records         = [var.primary_ip]
  set_identifier  = "primary"
  health_check_id = aws_route53_health_check.primary.id
  failover_routing_policy {
    type = "PRIMARY"
  }
}

resource "aws_route53_record" "secondary" {
  zone_id        = var.zone_id
  name           = var.record_name
  type           = "A"
  ttl            = 60
  records        = [var.secondary_ip]
  set_identifier = "secondary"
  failover_routing_policy {
    type = "SECONDARY"
  }
}

output "record_name" {
  value = var.record_name
}
