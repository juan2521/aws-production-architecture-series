terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.60"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "aws-production-architecture-series"
      ManagedBy = "Terraform"
      Article   = "01-secure-global-web-application-edge"
    }
  }
}

# CloudFront-scope AWS WAF resources must be managed in us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
