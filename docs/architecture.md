# Architecture

The platform follows a public edge and three-tier AWS network design:

```text
Client -> Route 53 -> HTTPS/ACM on public ALB -> private ECS tasks -> isolated RDS PostgreSQL
```

The application delivery path is separate from the request path:

```text
Git commit -> GitHub Actions -> private ECR repository -> ECS task definition -> Fargate tasks
```

Every tier spans two Availability Zones. The internet-facing ALB occupies the public subnets and forwards through an IP target group to Fargate tasks in private application subnets. Application workloads use NAT for outbound-only connectivity, while database subnets have no default Internet route.

Route 53 resolves the configured API hostname to the ALB. ACM supplies the certificate, and TLS terminates at the ALB before private HTTP forwarding to ECS. Port `80` performs only a permanent redirect when HTTPS is enabled.

See [`networking.md`](networking.md) for CIDRs, route tables, NAT trade-offs, and module boundaries. See [`security.md`](security.md) for the ALB-to-ECS-to-RDS security-group chain, [`database.md`](database.md) for private PostgreSQL, [`container-registry.md`](container-registry.md) for artifact traceability, [`ecs-fargate.md`](ecs-fargate.md) for the managed application runtime, [`load-balancing.md`](load-balancing.md) for target routing, and [`dns-https.md`](dns-https.md) for DNS, certificates, TLS termination, and redirect validation.
