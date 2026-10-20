locals {
  name_hash          = substr(sha1(var.name_prefix), 0, 6)
  target_group_hash  = substr(sha1("${var.name_prefix}:${var.vpc_id}:${var.container_port}"), 0, 6)
  load_balancer_name = "${substr(var.name_prefix, 0, 21)}-alb-${local.name_hash}"
  target_group_name  = "${substr(var.name_prefix, 0, 21)}-api-${local.target_group_hash}"
}

resource "aws_lb" "this" {
  name                       = local.load_balancer_name
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [var.alb_security_group_id]
  subnets                    = var.public_subnet_ids
  enable_deletion_protection = var.enable_deletion_protection
  enable_http2               = true
  drop_invalid_header_fields = true
  idle_timeout               = var.idle_timeout_seconds

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb"
    Tier = "load-balancer"
  })
}

resource "aws_lb_target_group" "application" {
  name                          = local.target_group_name
  port                          = var.container_port
  protocol                      = "HTTP"
  protocol_version              = "HTTP1"
  target_type                   = "ip"
  vpc_id                        = var.vpc_id
  deregistration_delay          = var.deregistration_delay_seconds
  load_balancing_algorithm_type = "round_robin"

  health_check {
    enabled             = true
    protocol            = "HTTP"
    port                = "traffic-port"
    path                = var.health_check_path
    matcher             = "200"
    interval            = var.health_check_interval_seconds
    timeout             = var.health_check_timeout_seconds
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
  }

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = var.health_check_timeout_seconds < var.health_check_interval_seconds
      error_message = "health_check_timeout_seconds must be lower than health_check_interval_seconds."
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-api"
    Tier = "application"
  })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = var.enable_https ? [] : [true]

    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.application.arn
    }
  }

  dynamic "default_action" {
    for_each = var.enable_https ? [true] : []

    content {
      type = "redirect"

      redirect {
        host        = "#{host}"
        path        = "/#{path}"
        port        = "443"
        protocol    = "HTTPS"
        query       = "#{query}"
        status_code = "HTTP_301"
      }
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-http"
  })
}
