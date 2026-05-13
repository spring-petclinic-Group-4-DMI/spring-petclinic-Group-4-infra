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

  lifecycle {
    prevent_destroy = true  # forces explicit removal before destroy can proceed
  }
}

resource "aws_acm_certificate" "main" {
  domain_name               = "staging.${var.domain_name}"
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"
  tags                      = var.default_tags
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = aws_route53_zone.main.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

# aws_acm_certificate_validation intentionally omitted.
# Terraform would block the entire apply waiting for DNS propagation from
# the external registrar (spaceship.com), which can take up to 48 hours.
# Instead, the CNAME records above are written to Route53 and validation
# completes automatically in the background once NS propagation finishes.
# The certificate_arn output uses aws_acm_certificate.main.arn directly
# (available immediately) so the ALB and Ingress can be provisioned without
# waiting. HTTPS will start working as soon as ACM status changes to ISSUED.

