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

  default_tags {
    tags = var.default_tags
  }
}

# ---------------------------------------------------------------------------
# Data sources — ALBs provisioned in SPC-005-T8
# ---------------------------------------------------------------------------

data "aws_lb" "staging" {
  name = var.staging_alb_name
}

data "aws_lb" "prod" {
  count = var.create_prod_records ? 1 : 0
  name  = var.prod_alb_name
}

# ---------------------------------------------------------------------------
# Route 53 hosted zone
# ---------------------------------------------------------------------------

resource "aws_route53_zone" "main" {
  name    = var.domain_name
  comment = "Managed by Terraform — Spring PetClinic Group 4 (SPC-005-T9)"
}

# ---------------------------------------------------------------------------
# ACM certificate — wildcard covers staging.* and the apex domain.
# Must be provisioned in the same region as the ALB (not forced to us-east-1
# unless that is your deployment region — us-east-1 is only mandatory for
# CloudFront distributions, not ALBs).
# ---------------------------------------------------------------------------

resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    # New cert is fully issued before the old one is destroyed, preventing
    # any HTTPS downtime during certificate rotation or renewal.
    create_before_destroy = true
  }
}

# DNS CNAME records that ACM requires to prove domain ownership.
# for_each de-duplicates: a wildcard cert shares one validation record with
# the apex, so ACM may return fewer options than the number of SANs.
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

# Blocks apply until ACM confirms the validation CNAMEs are publicly reachable.
# The validated certificate ARN from this resource is what you attach to the
# ALB HTTPS listener (port 443) in SPC-005-T8 or your Helm ingress values.
resource "aws_acm_certificate_validation" "main" {
  certificate_arn = aws_acm_certificate.main.arn

  validation_record_fqdns = [
    for record in aws_route53_record.cert_validation : record.fqdn
  ]
}

# ---------------------------------------------------------------------------
# Staging DNS records — staging.petclinic-group4.com → staging ALB
# ---------------------------------------------------------------------------

resource "aws_route53_record" "staging_a" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "staging.${var.domain_name}"
  type    = "A"

  alias {
    # ALB-specific zone_id (not the Route 53 hosted zone id) is required for
    # alias records. This enables Route 53 health-check integration with the
    # ALB target groups and avoids the extra DNS hop of a CNAME record.
    name                   = data.aws_lb.staging.dns_name
    zone_id                = data.aws_lb.staging.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "staging_aaaa" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "staging.${var.domain_name}"
  type    = "AAAA"

  alias {
    name                   = data.aws_lb.staging.dns_name
    zone_id                = data.aws_lb.staging.zone_id
    evaluate_target_health = true
  }
}

# ---------------------------------------------------------------------------
# Production DNS records — petclinic-group4.com + www.petclinic-group4.com
# Guarded by var.create_prod_records so a staging-only apply does not require
# the prod ALB to exist yet. Set to true once the prod ALB is provisioned.
# ---------------------------------------------------------------------------

resource "aws_route53_record" "prod_apex_a" {
  count   = var.create_prod_records ? 1 : 0
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = data.aws_lb.prod[0].dns_name
    zone_id                = data.aws_lb.prod[0].zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "prod_apex_aaaa" {
  count   = var.create_prod_records ? 1 : 0
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = data.aws_lb.prod[0].dns_name
    zone_id                = data.aws_lb.prod[0].zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "prod_www_a" {
  count   = var.create_prod_records ? 1 : 0
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = data.aws_lb.prod[0].dns_name
    zone_id                = data.aws_lb.prod[0].zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "prod_www_aaaa" {
  count   = var.create_prod_records ? 1 : 0
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "AAAA"

  alias {
    name                   = data.aws_lb.prod[0].dns_name
    zone_id                = data.aws_lb.prod[0].zone_id
    evaluate_target_health = true
  }
}
