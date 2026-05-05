output "alb_dns_name" {
  description = "Public DNS name of the ALB. Used in the Kubernetes Ingress and shared with the QA team for integration tests (SPC-070)."
  value       = aws_lb.this.dns_name
}

output "alb_arn" {
  description = "Full ARN of the ALB. The SRE needs this for Grafana CloudWatch metrics (SPC-062)."
  value       = aws_lb.this.arn
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the ALB. Used to create a Route 53 alias record pointing the domain at the ALB."
  value       = aws_lb.this.zone_id
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener. Needed if additional listener rules are added later."
  value       = aws_lb_listener.https.arn
}