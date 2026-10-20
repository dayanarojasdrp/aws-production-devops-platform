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

Only the ALB security group contains public inbound rules. ECS does not expose port 8080 to a public CIDR, and RDS does not expose port 5432 to a public CIDR. Port `80` currently reaches the ALB's temporary HTTP forwarding listener; the HTTPS phase will change that listener to a redirect rather than forward plaintext HTTP to the application.

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

ALB egress is restricted to the ECS security group on TCP `8080`, which covers application traffic and target health checks. ECS tasks still require broader outbound access to ECR, CloudWatch Logs, Secrets Manager, RDS, and AWS APIs through the private-subnet NAT path. RDS retains its explicit managed-service egress rule pending later hardening.

Inbound least privilege and the known ALB backend path are enforced now. ECS egress can be narrowed after runtime traffic has been observed and the ECR, S3, CloudWatch Logs, and Secrets Manager VPC endpoint trade-offs have been evaluated. An explicit temporary rule is preferable to relying silently on AWS's default security-group egress behavior.

## Terraform ownership and contracts

`terraform/modules/security` owns only the three security groups and their rules. It receives the VPC ID from the networking module and exports:

```text
alb_security_group_id -> internet-facing ALB
ecs_security_group_id -> ECS Fargate task network interfaces
rds_security_group_id -> private RDS module
```

It does not create listeners, tasks, databases, subnets, routes, IAM permissions, or TLS certificates. Those resources consume the security-group IDs through separate modules.

## Validation

The module can be tested without AWS credentials or real resources:

```sh
make security-test
```

The mocked Terraform test verifies the public ALB ports, the ALB-to-ECS reference, the ECS-to-RDS reference, and the explicit outbound policy. Environment validation also confirms that both dev and prod consume the security module correctly.

After ALB, ECS, and RDS exist, runtime evidence must prove both allowed and denied paths. A Terraform plan alone cannot prove network connectivity.

## Database credentials

The RDS password is generated rather than supplied through source code or tfvars. Secrets Manager stores the username/password document, and the ECS execution role can read only that specific secret ARN. The task definition references individual JSON keys; no password is exposed as a Terraform output.

See [`database.md`](database.md) for private placement, encryption, state handling, credential rotation, and the dev/prod database trade-offs.

## ECS IAM identities

The task execution role is used by the ECS agent and is limited to the exact ECR repository, CloudWatch log group, and database secret required to start the task. `ecr:GetAuthorizationToken` is the one unavoidable wildcard because that API does not support repository-level resource scoping.

The application task role has no AWS API permissions. Pulling the image, injecting task-definition secrets, and publishing `awslogs` output do not justify granting permissions to application code.
