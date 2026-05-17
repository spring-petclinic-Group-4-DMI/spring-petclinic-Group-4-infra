###############################################################################
# modules/alb/outputs.tf
#
# These are the values this module exposes after it runs.
# Whoever calls this module in environments/staging/main.tf can use these
# as module.alb.<output_name>
###############################################################################

output "alb_dns_name" {
  description = "Public DNS name of the ALB. The QA team needs this to run integration tests (SPC-070). Also goes in the architecture diagram (SPC-073)."
  value       = aws_lb.this.dns_name
}

output "alb_arn" {
  description = "Full ARN of the ALB. The SRE needs this for Grafana CloudWatch metrics (SPC-062)."
  value       = aws_lb.this.arn
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the ALB. Needed to create a Route 53 alias record pointing the domain at the ALB."
  value       = aws_lb.this.zone_id
}

# output "https_listener_arn" {
#  description = "ARN of the HTTPS (port 443) listener. Useful if additional routing rules need to be added later."
#  value       = aws_lb_listener.https.arn
#}

output "acm_certificate_arn" {
  description = "ARN of the ACM TLS certificate used by the ALB. Passed through from the module input for use by other modules that need to know which cert is in use."
  value       = var.acm_certificate_arn
}