# Terraform — Secure Global Web Application Edge

This directory is a focused Infrastructure as Code baseline for **AWS Production Architecture #01**.

It assumes you already have:

- an internal Application Load Balancer;
- healthy application targets behind that ALB;
- a Route 53 public hosted zone;
- an ACM certificate in `us-east-1` for the CloudFront hostname.

The code creates:

```text
CloudFront VPC Origin
AWS WAF Web ACL
CloudFront Distribution
Route 53 Alias Record
```

## Important

The managed AWS WAF rule groups start in `COUNT` mode so you can inspect real traffic and tune exclusions before enforcing blocks. The example global rate-based rule is set to `BLOCK` and its threshold must be tuned for your application.

The VPC origin baseline uses `http-only` between CloudFront's private VPC-origin path and the ALB. If your security requirements mandate origin TLS, implement an origin hostname/certificate design that CloudFront can validate and change the origin protocol policy to `https-only`.

## Example

Create a local `terraform.tfvars` that is **not committed with secrets**:

```hcl
aws_region                 = "us-east-1"
application_domain         = "app.example.com"
route53_zone_id            = "Z0123456789EXAMPLE"
cloudfront_certificate_arn = "arn:aws:acm:us-east-1:111122223333:certificate/00000000-0000-0000-0000-000000000000"
internal_alb_arn            = "arn:aws:elasticloadbalancing:us-east-1:111122223333:loadbalancer/app/internal-app/0000000000000000"
internal_alb_dns_name       = "internal-app-0000000000.us-east-1.elb.amazonaws.com"
```

Then:

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
```

## Production extensions

A real deployment should usually add or integrate:

- remote Terraform state and state locking;
- CI/CD plan and approval gates;
- WAF logging destination;
- CloudFront access logging;
- ALB access logging;
- CloudWatch alarms and dashboards;
- centralized security logging;
- environment-specific cache behaviors;
- sensitive endpoint rate rules;
- AWS Shield Advanced when justified by risk and business requirements;
- AWS Config / Security Hub controls where appropriate;
- automated policy and IaC security scanning.

This code is intentionally small enough to study while remaining aligned with the architecture described in the article.
