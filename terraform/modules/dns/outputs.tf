# ---------------------------------------------------------------------------
# Hosted zone
# ---------------------------------------------------------------------------

output "hosted_zone_id" {
  description = "Route 53 hosted zone ID. Reference this in other Terraform modules that need to create DNS records in the same zone (e.g. ArgoCD, Grafana, Zipkin subdomains)."
  value       = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "The four Route 53 name servers assigned to the hosted zone. You must update your domain registrar's NS records to point to these servers before DNS will resolve. This is a one-time manual step after the first terraform apply."
  value       = aws_route53_zone.main.name_servers
}

# ---------------------------------------------------------------------------
# Certificate
# ---------------------------------------------------------------------------

output "certificate_arn" {
  description = "ARN of the validated ACM wildcard certificate (*.petclinic-group4.com + apex). Attach this to the ALB HTTPS listener (port 443) in your Helm ingress values or the aws_lb_listener resource in SPC-005-T8."
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "certificate_status" {
  description = "Current ACM certificate status. Must be ISSUED before HTTPS will work on the ALB. If this stays PENDING_VALIDATION, check that the Route 53 NS records at the registrar match the name_servers output."
  value       = aws_acm_certificate.main.status
}

# ---------------------------------------------------------------------------
# Staging
# ---------------------------------------------------------------------------

output "staging_url" {
  description = "The staging HTTPS URL for the Spring PetClinic application."
  value       = "https://staging.${var.domain_name}"
}

output "staging_alb_dns" {
  description = "The raw ALB DNS name that the staging alias record resolves to. Useful for debugging — if nslookup staging.{domain} returns this value you know the alias is wired correctly."
  value       = data.aws_lb.staging.dns_name
}

output "staging_record_fqdn" {
  description = "The fully-qualified domain name of the staging A record."
  value       = aws_route53_record.staging_a.fqdn
}

# ---------------------------------------------------------------------------
# Production (conditionally populated)
# ---------------------------------------------------------------------------

output "prod_url" {
  description = "The production HTTPS URL. Empty string when create_prod_records is false."
  value       = var.create_prod_records ? "https://${var.domain_name}" : ""
}

output "prod_www_url" {
  description = "The www production HTTPS URL. Empty string when create_prod_records is false."
  value       = var.create_prod_records ? "https://www.${var.domain_name}" : ""
}

output "prod_record_fqdn" {
  description = "FQDN of the prod apex A record. Empty string when create_prod_records is false."
  value       = var.create_prod_records ? aws_route53_record.prod_apex_a[0].fqdn : ""
}
