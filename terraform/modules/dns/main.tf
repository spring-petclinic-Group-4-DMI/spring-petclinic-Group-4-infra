terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
  }
}

# This module creates the Route53 hosted zone + ACM certificate only.
# ALB alias records (A/AAAA) live in the root because they depend on
# module.alb outputs — keeping them here would create a cycle since
# module.alb consumes this module's certificate_arn output.

resource "aws_route53_zone" "main" {
  name    = var.domain_name
  comment = "Managed by Terraform — Spring PetClinic Group 4 (SPC-005-T9)"
  tags    = var.default_tags
}

resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"
  tags                      = var.default_tags

  lifecycle {
    # New cert is fully issued before the old one is destroyed, preventing
    # HTTPS downtime during certificate rotation or renewal.
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn = aws_acm_certificate.main.arn

  validation_record_fqdns = [
    for record in aws_route53_record.cert_validation : record.fqdn
  ]
}
