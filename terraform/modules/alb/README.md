# Application Load Balancer module

Creates the stable public HTTP entry point for one environment:

- an internet-facing Application Load Balancer spanning public subnets in at least two Availability Zones;
- an HTTP target group with `target_type = "ip"` for Fargate `awsvpc` task interfaces;
- `/healthz` checks on the application traffic port;
- a temporary port `80` listener that forwards to healthy ECS targets;
- connection draining for tasks removed during replacement or deployment.

The target group name incorporates the VPC and application-port contract and uses create-before-destroy lifecycle behavior, allowing a replacement target group to be connected before the prior one is removed.

The module never registers task IPs itself. The ECS service consumes `target_group_arn` and automatically registers and deregisters each ephemeral task. The ALB security group is supplied by the security module; the target group uses the same VPC as ECS.

HTTP forwarding is intentionally temporary so this phase can be validated through the AWS-assigned ALB DNS name. The DNS/HTTPS phase will add ACM and Route 53, create the `443` HTTPS listener, and change port `80` to an HTTP-to-HTTPS redirect.

Access logging, CloudWatch alarms, WAF, and advanced listener rules belong to later observability and security phases. Run `terraform test` from this directory to validate placement, listener routing, target type, health checks, connection draining, and environment-specific deletion protection without creating AWS resources.
