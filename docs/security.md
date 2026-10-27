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
| Internet (`0.0.0.0/0`) | ALB SG | 80 | Permanent redirect from HTTP to HTTPS when TLS is enabled |
| ALB SG | ECS SG | 8080 | Application traffic to Go API tasks |
| ECS SG | RDS SG | 5432 | PostgreSQL traffic from the application |

Only the ALB security group contains public inbound rules. ECS does not expose port 8080 to a public CIDR, and RDS does not expose port 5432 to a public CIDR. With HTTPS enabled, port `80` returns a `301` redirect without forwarding plaintext application traffic; port `443` terminates TLS with ACM before the ALB forwards private HTTP to ECS.

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

## FASE 19 — IAM least privilege

This phase enforces the principle that AWS identities are purpose-bound and permission-scoped. A production platform should not grant broad wildcard access simply because it is convenient. Every identity gets only the actions necessary to complete its own job.

### Identity split

The project separates the platform identities into dedicated roles rather than using a single high-privilege identity:

- GitHub Terraform Role
  - assumes AWS access from GitHub OIDC for Terraform state and plan operations;
  - can read and write only the required backend state paths and lock files;
  - cannot deploy workloads, push images, or administer the account.

- GitHub Deployment Role
  - assumes AWS access from GitHub Environment OIDC for application delivery;
  - can publish images to the target ECR repository only;
  - can update only the matching ECS service;
  - can pass only the exact ECS execution and task roles to `ecs-tasks.amazonaws.com`.

- ECS Execution Role
  - allows the ECS agent to pull the image from ECR;
  - can write to the specific CloudWatch log group for the service;
  - can read only the database secret required by the task;
  - supports runtime startup and log delivery without granting application-level AWS access.

- ECS Task Role
  - exposes the service identity to the runtime container;
  - intentionally holds almost no permissions because the Go API does not call AWS APIs;
  - this is the correct architecture when the task does not need AWS SDK access.

### Why this matters

The main goal is to remove the temptation to grant `AdministratorAccess` or a broad `PowerUser` policy because it is faster to set up. That approach hides real runtime risk and makes security reviews harder.

The platform keeps an explicit separation between:

1. infrastructure management identity;
2. deployment identity;
3. runtime executor identity;
4. application identity.

This is not just about meeting a checklist; it reduces blast radius, forces clearer boundaries, and makes incident response faster.

### Least-privilege policy shape

The execution role is intentionally narrow:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GetEcrAuthorizationToken",
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    },
    {
      "Sid": "PullApplicationImage",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Resource": "arn:aws:ecr:REGION:ACCOUNT_ID:repository/PROJECT-api"
    },
    {
      "Sid": "WriteApplicationLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:REGION:ACCOUNT_ID:log-group:PROJECT-api:log-stream:*"
    },
    {
      "Sid": "ReadApplicationSecret",
      "Effect": "Allow",
      "Action": "secretsmanager:GetSecretValue",
      "Resource": "arn:aws:secretsmanager:REGION:ACCOUNT_ID:secret:PROJECT-db-credentials-*"
    }
  ]
}
```

The application task role is even more constrained: no AWS API policy unless the application begins to call a real AWS service, such as S3, Secrets Manager, or SQS. In that case, permissions should be added one service at a time and only at the exact resource scope required.

This is the correct design principle: do not grant permissions because they may be useful later; add them only when the runtime contract proves they are required.

## CI supply-chain and security controls

Pull-request workflows use read-only repository permissions by default. Only
the manual Terraform plan job can request an OIDC token, and the current trust
policy limits that identity to `main`. Reusable Actions are pinned to full
commit SHAs so a mutable tag cannot silently replace reviewed workflow code.

Application CI scans the built runtime image for fixed `HIGH` and `CRITICAL`
operating-system and library vulnerabilities. Terraform CI scans IaC at the same
severity threshold and runs TFLint with a pinned AWS ruleset.

Accepted Trivy findings live in `.trivyignore.yaml`; they are scoped by path,
contain a rationale, and expire on 2027-04-20. Expiration is deliberate: public
ALB placement, temporary HTTP bootstrap behavior, broad managed-service egress,
and SSE-S3 state encryption must be reconsidered during the final security and
IAM hardening phases rather than becoming permanent invisible exceptions.

## Deployment identity boundaries

Application delivery uses two environment-specific OIDC roles rather than the Terraform role. Development and production trust different GitHub Environment subjects. Each role can publish only to its matching ECR repository, update only its matching ECS service, read only its task-definition family, and pass only the exact ECS execution and task roles with `iam:PassedToService = ecs-tasks.amazonaws.com`.

`ecs:RegisterTaskDefinition` is the deliberate wildcard: AWS authorizes registration before the new revision ARN exists. That wildcard does not let the workflow deploy arbitrary account roles because `iam:PassRole` is limited to two named roles, and it does not let the workflow update another service because `ecs:UpdateService` is limited to one service ARN.

See [`cicd.md`](cicd.md) for job behavior and branch-protection guidance.
