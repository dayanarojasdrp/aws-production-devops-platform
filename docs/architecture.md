# Architecture

The platform follows a three-tier AWS network design:

```text
Internet -> public ALB -> private ECS tasks -> isolated RDS PostgreSQL
```

The application delivery path is separate from the request path:

```text
Git commit -> GitHub Actions -> private ECR repository -> ECS task definition -> Fargate tasks
```

Every tier spans two Availability Zones. The internet-facing ALB occupies the public subnets and forwards through an IP target group to Fargate tasks in private application subnets. Application workloads use NAT for outbound-only connectivity, while database subnets have no default Internet route.

See [`networking.md`](networking.md) for CIDRs, route tables, NAT trade-offs, and module boundaries. See [`security.md`](security.md) for the ALB-to-ECS-to-RDS security-group chain, [`database.md`](database.md) for private PostgreSQL, [`container-registry.md`](container-registry.md) for artifact traceability, [`ecs-fargate.md`](ecs-fargate.md) for the managed application runtime, and [`load-balancing.md`](load-balancing.md) for public routing and target health.
