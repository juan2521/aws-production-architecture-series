variable "aws_region" {
  description = "AWS Region where the private ALB is deployed."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix used by the reference resources."
  type        = string
  default     = "secure-global-web-edge"
}

variable "application_domain" {
  description = "Public hostname served through CloudFront, for example app.example.com."
  type        = string
}

variable "route53_zone_id" {
  description = "Route 53 public hosted zone ID containing application_domain."
  type        = string
}

variable "cloudfront_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for the CloudFront viewer certificate."
  type        = string
}

variable "internal_alb_arn" {
  description = "ARN of the internal Application Load Balancer used as the CloudFront VPC origin."
  type        = string
}

variable "internal_alb_dns_name" {
  description = "DNS name of the internal ALB."
  type        = string
}

variable "waf_rate_limit" {
  description = "Five-minute per-IP request threshold for the example global rate-based rule. Tune before production."
  type        = number
  default     = 2000
}
