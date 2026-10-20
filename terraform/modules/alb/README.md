# Application Load Balancer edge module

Creates the stable public entry point for one environment:

- an internet-facing Application Load Balancer spanning public subnets in at least two Availability Zones;
- an HTTP target group with `target_type = "ip"` for Fargate `awsvpc` task interfaces;
- `/healthz` checks on the application traffic port;
- a port `80` listener that forwards only while HTTPS is disabled;
- connection draining for tasks removed during replacement or deployment;
- an optional DNS-validated ACM public certificate;
- an optional port `443` HTTPS listener using a modern TLS policy;
- an HTTP `301` redirect to HTTPS when TLS is enabled; and
- an optional Route 53 `A` alias from the public API hostname to the ALB.

The target group name incorporates the VPC and application-port contract and uses create-before-destroy lifecycle behavior, allowing a replacement target group to be connected before the prior one is removed.

The module never registers task IPs itself. The ECS service consumes `target_group_arn` and automatically registers and deregisters each ephemeral task. The ALB security group is supplied by the security module; the target group uses the same VPC as ECS.

## Enabling DNS and HTTPS

The hosted zone must already exist in Route 53 and be publicly delegated. Set all three values together:

```hcl
enable_https            = true
application_domain_name = "api.example.com"
route53_zone_id         = "Z0123456789ABCDEF"
```

Terraform requests the certificate in the same provider region as the ALB, writes the ACM validation CNAME into that hosted zone, waits for issuance, creates the HTTPS listener, changes HTTP to a `301` redirect, and finally publishes the application alias. Keeping the validation CNAME allows ACM to renew an in-use certificate automatically.

With `enable_https = false`, no certificate or DNS record is fabricated and port `80` continues forwarding for initial ALB validation. This is useful before a real domain is available, but it is not the final production posture.

## Boundaries

TLS terminates at the ALB. Traffic from the ALB to private ECS targets remains HTTP on the configured container port. End-to-end TLS is not required by this project's current threat model.

Access logging, CloudWatch alarms, WAF, and advanced listener rules belong to later observability and security phases. Run `terraform test` from this directory to validate placement, HTTP and HTTPS listener behavior, DNS, certificate validation, target type, health checks, connection draining, and environment-specific deletion protection without creating AWS resources.
