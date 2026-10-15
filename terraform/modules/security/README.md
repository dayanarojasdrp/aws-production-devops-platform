# Security module

Creates the three security groups that enforce the platform's workload-to-workload traffic chain:

```text
Internet -- TCP 80/443 --> ALB SG -- TCP 8080 --> ECS SG -- TCP 5432 --> RDS SG
```

ECS ingress references the ALB security group rather than a CIDR block. RDS ingress references the ECS security group. Consequently, changing ECS task IP addresses do not require database firewall changes, and neither ECS nor RDS has public inbound access.

Outbound traffic is explicitly open during this phase because the future ECS tasks need ECR, CloudWatch Logs, Secrets Manager, RDS, and other AWS APIs. Restricting egress requires the corresponding workloads and optional VPC endpoints to exist first. This is a documented temporary design decision, not an accidental AWS default.

Run `terraform test` from this directory to validate the rule sources and ports with a mocked AWS provider. The tests do not contact AWS or create resources.
