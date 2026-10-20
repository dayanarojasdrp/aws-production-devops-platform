output "alb_arn" {
  description = "ARN of the internet-facing Application Load Balancer."
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "AWS-assigned public DNS name behind the optional Route 53 alias."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID used by the Route 53 alias record."
  value       = aws_lb.this.zone_id
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener, which redirects to HTTPS when enabled."
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener, or null when HTTPS is disabled."
  value       = try(aws_lb_listener.https[0].arn, null)
}

output "certificate_arn" {
  description = "ARN of the DNS-validated ACM certificate, or null when HTTPS is disabled."
  value       = try(aws_acm_certificate_validation.application[0].certificate_arn, null)
}

output "application_domain_name" {
  description = "Public API hostname, or null when HTTPS is disabled."
  value       = var.enable_https ? var.application_domain_name : null
}

output "application_url" {
  description = "Canonical HTTPS URL, or null when HTTPS is disabled."
  value       = var.enable_https ? "https://${var.application_domain_name}" : null
}

output "target_group_arn" {
  description = "ARN of the IP target group registered by the ECS service."
  value       = aws_lb_target_group.application.arn
}

output "target_group_name" {
  description = "Target group name used by AWS CLI health inspection commands."
  value       = aws_lb_target_group.application.name
}

output "health_check_path" {
  description = "HTTP path used to decide whether a task may receive traffic."
  value       = var.health_check_path
}
