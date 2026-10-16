# Security

## Network security model

The platform uses security-group chaining so every tier accepts new connections only from the tier directly in front of it:

```text
Internet
   |
   | TCP 80/443
   v
ALB Security Group
   |
   | TCP 8080
   v
ECS Security Group
   |
   | TCP 5432
   v
RDS Security Group
```

| Source | Destination | Port | Reason |
| --- | --- | ---: | --- |
| Internet (`0.0.0.0/0`) | ALB SG | 443 | Public HTTPS entry point |
| Internet (`0.0.0.0/0`) | ALB SG | 80 | Future redirect from HTTP to HTTPS |
| ALB SG | ECS SG | 8080 | Application traffic to Go API tasks |
| ECS SG | RDS SG | 5432 | PostgreSQL traffic from the application |

Only the ALB security group contains public inbound rules. ECS does not expose port 8080 to a public CIDR, and RDS does not expose port 5432 to a public CIDR. The port 80 rule permits traffic to the future ALB listener; the listener itself will be configured later to redirect requests to HTTPS rather than forward HTTP to the application.

## Why security-group references are used

ECS task IP addresses change as tasks are replaced or scaled. The RDS rule therefore trusts the ECS security group rather than task IP addresses. The same identity-based relationship connects the ALB to ECS. A replacement resource remains reachable only when it is attached to the expected security group.

This produces the intended negative boundaries:

```text
Internet -X-> ECS :8080
Internet -X-> RDS :5432
ALB      -X-> RDS :5432
ALB       --> ECS :8080
ECS       --> RDS :5432
```

## Stateful behavior

Security groups are stateful. When an allowed request travels from the ALB to ECS, response traffic for that connection is allowed automatically; a reverse inbound rule is not required. Network ACLs are different: they operate at subnet level, are stateless, and support both allow and deny rules. This project uses security groups as its primary workload firewall and keeps the default network ACL behavior.

## Outbound policy

All three security groups currently declare unrestricted IPv4 egress explicitly. This is intentional for the current phase: future ECS tasks require access to ECR, CloudWatch Logs, Secrets Manager, RDS, and AWS APIs, and those dependencies do not exist yet.

Inbound least privilege is enforced now. Egress can be narrowed later after the workload paths and any VPC endpoints are present and testable. An explicit temporary rule is preferable to relying silently on AWS's default security-group egress behavior.

## Terraform ownership and contracts

`terraform/modules/security` owns only the three security groups and their rules. It receives the VPC ID from the networking module and exports:

```text
alb_security_group_id -> future ALB module
ecs_security_group_id -> future ECS service/task networking
rds_security_group_id -> future RDS module
```

It does not create listeners, tasks, databases, subnets, routes, IAM permissions, or TLS certificates.

## Validation

The module can be tested without AWS credentials or real resources:

```sh
make security-test
```

The mocked Terraform test verifies the public ALB ports, the ALB-to-ECS reference, the ECS-to-RDS reference, and the explicit outbound policy. Environment validation also confirms that both dev and prod consume the security module correctly.

After ALB, ECS, and RDS exist, runtime evidence must prove both allowed and denied paths. A Terraform plan alone cannot prove network connectivity.

## Database credentials

The RDS password is generated rather than supplied through source code or tfvars. Secrets Manager stores the username/password document, and the future ECS execution role will be limited to reading that specific secret ARN. No password is exposed as a Terraform output.

See [`database.md`](database.md) for private placement, encryption, state handling, credential rotation, and the dev/prod database trade-offs.
