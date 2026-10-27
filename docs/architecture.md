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

## FASE 20 — Dev and Prod

The repository follows a shared-module design instead of duplicating infrastructure definitions. The same Terraform modules are reused across both environments, while each environment applies its own sizing and resilience profile.

```text
modules/
    |
    +-----------> dev
    |
    +-----------> prod
```

This is the correct production pattern: keep the implementation reusable, but let the environment decide how much availability and cost it needs.

### Development profile

Development is intentionally lean. It prioritizes low spend and fast iteration while still keeping a realistic runtime path.

- ECS minimum tasks: 1
- RDS smaller instance class
- single NAT strategy
- lower storage and lower backup retention
- cheaper ALB and log settings
- optional HTTPS disabled until a hostname and costed DNS flow are needed

This keeps the environment running without requiring a full production footprint for every debug session or feature branch.

### Production profile

Production is designed for fault tolerance, controlled failure domains, and recovery safety.

- ECS minimum tasks: 2+
- RDS Multi-AZ enabled
- higher availability and failover posture
- deletion protection enabled
- more redundancy across subnets and service capacity
- safer rollout and rollback assumptions

Production is not just a copy of development with bigger numbers. Its settings reflect operational risk: a failed instance, a failed AZ, or a failed update must be absorbed without a complete outage.

### Engineering trade-offs

This phase is important because engineering is not only about adding infrastructure; it is about choosing the right level of resilience for the right cost.

A strong platform decision is:

- dev: cheap, disposable, fast feedback
- prod: more resilient, more expensive, more durable

This is a real engineering trade-off. More infrastructure is not automatically better. The correct design is the one that matches the business and operational risk model.

This is also why the repo keeps the same modules and varies only the environment-level profile: the architecture stays consistent, while the operational cost and availability strategy remain explicit.

See [`networking.md`](networking.md) for CIDRs, route tables, NAT trade-offs, and module boundaries. See [`security.md`](security.md) for the ALB-to-ECS-to-RDS security-group chain, [`database.md`](database.md) for private PostgreSQL, [`container-registry.md`](container-registry.md) for artifact traceability, [`ecs-fargate.md`](ecs-fargate.md) for the managed application runtime, [`load-balancing.md`](load-balancing.md) for target routing, and [`dns-https.md`](dns-https.md) for DNS, certificates, TLS termination, and redirect validation.
