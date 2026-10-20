mock_provider "aws" {
  mock_resource "aws_lb" {
    defaults = {
      arn      = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/mock/0123456789abcdef"
      dns_name = "mock-alb-123456789.us-east-1.elb.amazonaws.com"
      zone_id  = "Z35SXDOTRQ7X7K"
    }
  }

  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/mock/0123456789abcdef"
    }
  }

  mock_resource "aws_lb_listener" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/mock/0123456789abcdef/0123456789abcdef"
    }
  }

  mock_resource "aws_acm_certificate" {
    defaults = {
      arn = "arn:aws:acm:us-east-1:123456789012:certificate/01234567-89ab-cdef-0123-456789abcdef"
      domain_validation_options = [
        {
          domain_name           = "api.example.com"
          resource_record_name  = "_validation.api.example.com."
          resource_record_type  = "CNAME"
          resource_record_value = "_token.acm-validations.aws."
        }
      ]
    }
  }

  mock_resource "aws_route53_record" {
    defaults = {
      fqdn = "_validation.api.example.com"
    }
  }

  mock_resource "aws_acm_certificate_validation" {
    defaults = {
      certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/01234567-89ab-cdef-0123-456789abcdef"
    }
  }
}

variables {
  name_prefix                = "test-platform-dev"
  vpc_id                     = "vpc-0123456789abcdef0"
  public_subnet_ids          = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  alb_security_group_id      = "sg-0123456789abcdef0"
  container_port             = 8080
  enable_deletion_protection = false
}

run "development_load_balancer" {
  command = apply

  assert {
    condition = (
      aws_lb.this.internal == false &&
      aws_lb.this.load_balancer_type == "application" &&
      aws_lb.this.subnets == toset(var.public_subnet_ids) &&
      aws_lb.this.security_groups == toset([var.alb_security_group_id])
    )
    error_message = "The ALB must be internet-facing across the supplied public subnets with only its own security group."
  }

  assert {
    condition = (
      aws_lb.this.enable_http2 == true &&
      aws_lb.this.drop_invalid_header_fields == true &&
      aws_lb.this.enable_deletion_protection == false
    )
    error_message = "The development ALB must enable protocol hardening without blocking deliberate cleanup."
  }

  assert {
    condition = (
      aws_lb_target_group.application.target_type == "ip" &&
      aws_lb_target_group.application.protocol == "HTTP" &&
      aws_lb_target_group.application.port == 8080 &&
      aws_lb_target_group.application.vpc_id == var.vpc_id &&
      aws_lb_target_group.application.deregistration_delay == "30" &&
      aws_lb_target_group.application.load_balancing_algorithm_type == "round_robin"
    )
    error_message = "The target group must send HTTP to Fargate task IPs on port 8080 with connection draining."
  }

  assert {
    condition = (
      one(aws_lb_target_group.application.health_check).path == "/healthz" &&
      one(aws_lb_target_group.application.health_check).port == "traffic-port" &&
      one(aws_lb_target_group.application.health_check).matcher == "200" &&
      one(aws_lb_target_group.application.health_check).interval == 30 &&
      one(aws_lb_target_group.application.health_check).timeout == 5 &&
      one(aws_lb_target_group.application.health_check).healthy_threshold == 2 &&
      one(aws_lb_target_group.application.health_check).unhealthy_threshold == 2
    )
    error_message = "The target group must use deliberate liveness thresholds against /healthz."
  }

  assert {
    condition = (
      aws_lb_listener.http.port == 80 &&
      aws_lb_listener.http.protocol == "HTTP" &&
      one(aws_lb_listener.http.default_action).type == "forward" &&
      one(aws_lb_listener.http.default_action).target_group_arn == aws_lb_target_group.application.arn
    )
    error_message = "The temporary HTTP listener must forward to the application target group."
  }

  assert {
    condition     = length(aws_lb.this.name) <= 32 && length(aws_lb_target_group.application.name) <= 32
    error_message = "AWS load balancer and target group names must stay within their 32-character limits."
  }
}

run "production_load_balancer" {
  command = apply

  variables {
    name_prefix                = "test-platform-prod"
    enable_deletion_protection = true
  }

  assert {
    condition     = aws_lb.this.enable_deletion_protection == true
    error_message = "Production must protect the load balancer from accidental deletion."
  }
}

run "https_dns_edge" {
  command = apply

  variables {
    application_domain_name = "api.example.com"
    enable_https            = true
    route53_zone_id         = "Z0123456789ABCDEF"
    tls_security_policy     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  }

  assert {
    condition = (
      aws_acm_certificate.application[0].domain_name == "api.example.com" &&
      aws_acm_certificate.application[0].validation_method == "DNS" &&
      one(aws_acm_certificate.application[0].options).certificate_transparency_logging_preference == "ENABLED"
    )
    error_message = "HTTPS must request a transparent ACM certificate validated through DNS."
  }

  assert {
    condition = (
      aws_route53_record.certificate_validation[0].zone_id == "Z0123456789ABCDEF" &&
      aws_route53_record.certificate_validation[0].type == "CNAME" &&
      aws_acm_certificate_validation.application[0].certificate_arn == aws_acm_certificate.application[0].arn
    )
    error_message = "The ACM validation CNAME must be placed in the configured public hosted zone."
  }

  assert {
    condition = (
      aws_lb_listener.https[0].port == 443 &&
      aws_lb_listener.https[0].protocol == "HTTPS" &&
      aws_lb_listener.https[0].ssl_policy == "ELBSecurityPolicy-TLS13-1-2-2021-06" &&
      one(aws_lb_listener.https[0].default_action).type == "forward" &&
      one(aws_lb_listener.https[0].default_action).target_group_arn == aws_lb_target_group.application.arn
    )
    error_message = "The HTTPS listener must terminate TLS and forward traffic to the ECS target group."
  }

  assert {
    condition = (
      one(aws_lb_listener.http.default_action).type == "redirect" &&
      one(one(aws_lb_listener.http.default_action).redirect).protocol == "HTTPS" &&
      one(one(aws_lb_listener.http.default_action).redirect).port == "443" &&
      one(one(aws_lb_listener.http.default_action).redirect).status_code == "HTTP_301"
    )
    error_message = "HTTP must preserve the request and redirect permanently to HTTPS port 443."
  }

  assert {
    condition = (
      aws_route53_record.application[0].name == "api.example.com" &&
      aws_route53_record.application[0].type == "A" &&
      one(aws_route53_record.application[0].alias).name == aws_lb.this.dns_name &&
      one(aws_route53_record.application[0].alias).zone_id == aws_lb.this.zone_id &&
      one(aws_route53_record.application[0].alias).evaluate_target_health == true
    )
    error_message = "The public hostname must be an A alias to the Application Load Balancer."
  }
}
