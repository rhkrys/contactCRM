########################################################################
# ContactCRM — static web dashboard hosting
# S3 (private) + CloudFront (OAC, HTTPS) + ACM (DNS) + Route 53
#
# This captures the infrastructure currently serving
# https://sales.awesomeblackbusiness.com (AWS account 306499034564).
# The site was first provisioned via the AWS CLI; this Terraform is the
# declarative source of truth going forward. To adopt the existing
# resources without recreating them, `terraform import` each one (see
# README.md in this directory).
########################################################################

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# CloudFront + ACM certs for CloudFront must live in us-east-1.
provider "aws" {
  region  = "us-east-1"
  profile = var.aws_profile
}

########################################################################
# Variables
########################################################################

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "svc-ai-cowork-mcp"
}

variable "domain_name" {
  description = "Fully-qualified site domain"
  type        = string
  default     = "sales.awesomeblackbusiness.com"
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID for awesomeblackbusiness.com"
  type        = string
  default     = "ZQKDSIZ3XJDSM"
}

########################################################################
# S3 bucket — private origin (no public access, OAC only)
########################################################################

resource "aws_s3_bucket" "site" {
  bucket = var.domain_name
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "site" {
  statement {
    sid       = "AllowCloudFrontOAC"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site.json
}

########################################################################
# ACM certificate — DNS validated
########################################################################

resource "aws_acm_certificate" "site" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = var.hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 300
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "site" {
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

########################################################################
# CloudFront — OAC, HTTPS, SPA fallback
########################################################################

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "contactcrm-sales-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# AWS managed "CachingOptimized" policy.
data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  default_root_object = "index.html"
  aliases             = [var.domain_name]
  price_class         = "PriceClass_100"
  comment             = "ContactCRM sales dashboard"

  origin {
    origin_id                = "s3-${var.domain_name}"
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-${var.domain_name}"
    viewer_protocol_policy  = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.optimized.id
  }

  # SPA fallback: unmatched paths (403 from S3) serve index.html.
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.site.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

########################################################################
# Route 53 — alias to CloudFront
########################################################################

resource "aws_route53_record" "site" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = "Z2FDTNDATAQYW2" # CloudFront's fixed zone ID
    evaluate_target_health = false
  }
}

########################################################################
# Outputs
########################################################################

output "site_url" {
  value = "https://${var.domain_name}"
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.site.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.site.id
}

output "s3_bucket" {
  value = aws_s3_bucket.site.id
}
