output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID."
  value       = aws_cloudfront_distribution.app.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name."
  value       = aws_cloudfront_distribution.app.domain_name
}

output "application_url" {
  description = "Public HTTPS application URL."
  value       = "https://${var.application_domain}"
}

output "waf_web_acl_arn" {
  description = "AWS WAF Web ACL ARN associated with CloudFront."
  value       = aws_wafv2_web_acl.edge.arn
}

output "cloudfront_vpc_origin_id" {
  description = "CloudFront VPC origin ID."
  value       = aws_cloudfront_vpc_origin.alb.id
}
