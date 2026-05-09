output "hosted_zone_id" {
  description = "Route 53 hosted zone ID. Reference this in the root module to create A/AAAA alias records pointing to the ALB."
  value       = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "The four Route 53 name servers assigned to the hosted zone. You must update your domain registrar's NS records to point to these servers before DNS will resolve. One-time manual step after the first terraform apply."
  value       = aws_route53_zone.main.name_servers
}

output "certificate_arn" {
  description = "ARN of the validated ACM wildcard certificate (*.petclinic-group4.com + apex). Pass into module.alb's acm_certificate_arn input."
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "certificate_status" {
  description = "Current ACM certificate status. Must be ISSUED before HTTPS will work on the ALB. If this stays PENDING_VALIDATION, check that the Route 53 NS records at the registrar match the name_servers output."
  value       = aws_acm_certificate.main.status
}
