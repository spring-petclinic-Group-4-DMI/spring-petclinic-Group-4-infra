output "zone_id" {
  description = "Route 53 hosted zone ID"
  value       = aws_route53_zone.this.zone_id
}

output "name_servers" {
  description = "Hosted zone NS records (delegate these at the registrar)"
  value       = aws_route53_zone.this.name_servers
}

output "certificate_arn" {
  description = "Validated wildcard ACM certificate ARN"
  value       = aws_acm_certificate_validation.wildcard.certificate_arn
}
