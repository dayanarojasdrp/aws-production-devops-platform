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
