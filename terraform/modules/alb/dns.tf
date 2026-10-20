resource "aws_route53_record" "application" {
  count = var.enable_https ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.application_domain_name
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }

  depends_on = [aws_lb_listener.https]
}
