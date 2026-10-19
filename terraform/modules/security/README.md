# Security module

Creates the three security groups that enforce the platform's workload-to-workload traffic chain:

```text
Internet -- TCP 80/443 --> ALB SG -- TCP 8080 --> ECS SG -- TCP 5432 --> RDS SG
```

ECS ingress references the ALB security group rather than a CIDR block. RDS ingress references the ECS security group. Consequently, changing ECS task IP addresses do not require database firewall changes, and neither ECS nor RDS has public inbound access.

ALB outbound traffic is restricted to the ECS security group on the application port because its only backend dependency is now known. ECS egress remains explicitly open because private tasks currently reach ECR, CloudWatch Logs, Secrets Manager, and AWS APIs through NAT as well as RDS inside the VPC. RDS keeps explicit all-egress pending later hardening; these remaining rules can be reassessed after runtime traffic and VPC endpoints are available.

Run `terraform test` from this directory to validate the rule sources and ports with a mocked AWS provider. The tests do not contact AWS or create resources.
