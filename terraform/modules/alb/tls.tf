resource "aws_acm_certificate" "application" {
  count = var.enable_https ? 1 : 0

  domain_name       = var.application_domain_name
  validation_method = "DNS"

  options {
    certificate_transparency_logging_preference = "ENABLED"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-certificate"
  })
}

resource "aws_route53_record" "certificate_validation" {
  count = var.enable_https ? 1 : 0

  zone_id = var.route53_zone_id
  name    = one(aws_acm_certificate.application[0].domain_validation_options).resource_record_name
  type    = one(aws_acm_certificate.application[0].domain_validation_options).resource_record_type
  ttl     = 60
  records = [one(aws_acm_certificate.application[0].domain_validation_options).resource_record_value]
}

resource "aws_acm_certificate_validation" "application" {
  count = var.enable_https ? 1 : 0

  certificate_arn         = aws_acm_certificate.application[0].arn
  validation_record_fqdns = [aws_route53_record.certificate_validation[0].fqdn]

  timeouts {
    create = "45m"
  }
}

resource "aws_lb_listener" "https" {
  count = var.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.tls_security_policy
  certificate_arn   = aws_acm_certificate_validation.application[0].certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.application.arn
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-https"
  })
}
