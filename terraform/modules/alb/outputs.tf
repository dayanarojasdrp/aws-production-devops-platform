output "alb_arn" {
  description = "ARN of the internet-facing Application Load Balancer."
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "AWS-assigned public DNS name used for Phase 10 HTTP validation."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID required by a future Route 53 alias record."
  value       = aws_lb.this.zone_id
}

output "http_listener_arn" {
  description = "ARN of the temporary HTTP forwarding listener."
  value       = aws_lb_listener.http.arn
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
