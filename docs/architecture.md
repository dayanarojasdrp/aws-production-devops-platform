# Architecture

The platform follows a three-tier AWS network design:

```text
Internet -> public ALB -> private ECS tasks -> isolated RDS PostgreSQL
```

The application delivery path is separate from the request path:

```text
Git commit -> GitHub Actions -> private ECR repository -> ECS task definition -> Fargate tasks
```

Every tier spans two Availability Zones. Only the load balancer tier has an Internet Gateway route. Application workloads use NAT for outbound-only connectivity, while database subnets have no default Internet route.

See [`networking.md`](networking.md) for CIDRs, route tables, NAT trade-offs, and module boundaries. See [`security.md`](security.md) for the ALB-to-ECS-to-RDS security-group chain, [`database.md`](database.md) for private PostgreSQL, [`container-registry.md`](container-registry.md) for artifact traceability, and [`ecs-fargate.md`](ecs-fargate.md) for the managed application runtime.
