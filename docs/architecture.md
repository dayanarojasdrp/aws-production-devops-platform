# Architecture

The platform follows a three-tier AWS network design:

```text
Internet -> public ALB -> private ECS tasks -> isolated RDS PostgreSQL
```

Every tier spans two Availability Zones. Only the load balancer tier has an Internet Gateway route. Application workloads use NAT for outbound-only connectivity, while database subnets have no default Internet route.

See [`networking.md`](networking.md) for CIDRs, route tables, NAT trade-offs, module boundaries, and validation instructions.
