# ECS Fargate application runtime

## ECS and Fargate have different responsibilities

Amazon ECS is the orchestrator: it stores the desired workload definition, creates deployments, observes the running task count, and launches replacements. AWS Fargate supplies the CPU and memory that execute each task without an EC2 worker fleet.

```text
ECS     -> decides what and how many containers should run
Fargate -> provides managed compute for those containers
```

The platform hierarchy is:

```text
ECS cluster
   |
   `-- API service (desired count)
          |
          `-- task definition family + revision
                 |
                 `-- running Fargate task(s)
```

A task definition is the versioned blueprint. A task is one running instance of that blueprint. The service continually reconciles actual tasks with `desired_count`.

## Runtime flow

```text
private ECR image:<git-sha>
          |
          v
ECS task definition revision
  - linux/amd64
  - CPU and memory
  - port 8080
  - non-secret database configuration
  - Secrets Manager references
  - awslogs configuration
          |
          v
ECS service on Fargate
  - private application subnets
  - ECS security group
  - no public IP
          |
          +------> RDS PostgreSQL :5432
          |
          `------> CloudWatch Logs
```

The service has no load balancer in this phase. Tasks cannot receive public traffic. The next phase will connect an ALB target group to container `api` on port `8080` and evaluate `GET /healthz`.

## Task definition contract

The task definition references the complete immutable Git SHA:

```text
<account>.dkr.ecr.<region>.amazonaws.com/<repository>:<40-character-git-sha>
```

`latest` cannot pass variable validation. A change to the image SHA or runtime configuration creates another task definition revision, preserving a direct source-to-artifact-to-runtime trail.

The container receives these non-secret values:

| Variable | Source |
| --- | --- |
| `HTTP_PORT` | Application port, currently `8080` |
| `DB_HOST` | Private RDS endpoint |
| `DB_PORT` | RDS PostgreSQL port |
| `DB_NAME` | Initial RDS database name |
| `DB_SSLMODE` | Fixed to `require` in AWS |

Credentials are injected from individual JSON keys in one secret:

```text
DB_USER     <- <secret-arn>:username::
DB_PASSWORD <- <secret-arn>:password::
```

The task uses Fargate Linux platform `1.4.0`, the minimum version that supports injecting a specific Secrets Manager JSON key. Secret values are not placed in Terraform variables, container definitions, outputs, or logs. Updating the secret does not update an already running container; credential rotation must also start fresh tasks.

The runtime is explicitly Linux `X86_64`, matching the `docker build --platform linux/amd64` artifact. The container runs as distroless UID `65532` with a read-only root filesystem.

## Database startup proof

Before opening port `8080`, the Go process performs a database readiness check with a ten-second timeout and creates the schema if required.

```text
secret injection succeeds
       |
private network path to RDS succeeds
       |
PostgreSQL authentication succeeds
       |
"database startup check passed"
       |
HTTP server starts
```

If configuration, IAM, networking, or PostgreSQL authentication is wrong, the process exits. The ECS service then observes that actual state is below desired state and launches a replacement. After successful startup, `/healthz` remains a process-liveness endpoint and `/readyz` continues to test current database readiness.

## IAM separation

Two roles deliberately separate platform and application permissions.

### Task execution role

Used by the ECS/Fargate agent before and around container startup. Its inline permissions are limited to:

- obtaining an ECR authorization token;
- pulling layers only from the environment's API repository;
- creating streams and writing events only under the API log group;
- reading only the environment's database secret.

`ecr:GetAuthorizationToken` requires resource `*`; repository-aware pull actions are scoped to the exact ECR repository ARN.

### Application task role

Credentials for this role are exposed to the application container. The Go API does not call AWS APIs, so the role has no permission policies. Pulling ECR images, resolving task-definition secrets, and publishing `awslogs` output are execution-role responsibilities, not application-role responsibilities.

## Private networking

Each Fargate task receives its own elastic network interface through `awsvpc` mode. The service uses both private application subnets, attaches only the ECS security group, enables Availability Zone rebalancing, and explicitly disables public IP assignment.

The existing NAT path supplies outbound access required during task startup:

```text
private task ENI -> NAT -> ECR / Secrets Manager / CloudWatch Logs
private task ENI --------> private RDS endpoint
```

VPC endpoints for ECR, S3, Secrets Manager, and CloudWatch Logs are a future cost/security trade-off. They are not necessary while the intentional NAT design exists.

## Development and production sizing

| Setting | Development | Production design |
| --- | ---: | ---: |
| Desired tasks | 1 | 2 |
| Task CPU | 256 units / 0.25 vCPU | 512 units / 0.5 vCPU |
| Task memory | 512 MiB | 1024 MiB |
| Log retention | 7 days | 30 days |
| Private subnets | 2 | 2 |
| Public task IP | No | No |
| Rolling deployment | minimum 100%, maximum 200% | minimum 100%, maximum 200% |

The module validates supported Fargate CPU/memory pairs. Production starts with two tasks so losing one replica does not remove all compute capacity. Actual sizing must later be adjusted using CloudWatch CPU, memory, latency, and load-test evidence.

## Initial deployment order

An ECS service cannot stabilize until its exact image exists. For a completely new environment, ECR must therefore be created before the full stack. Targeted apply is used only for this one bootstrap dependency:

```sh
IMAGE_TAG="$(git rev-parse HEAD)"

terraform -chdir=terraform/environments/dev init -backend-config=backend.hcl
terraform -chdir=terraform/environments/dev apply \
  -target=module.ecr \
  -var="ecs_image_tag=$IMAGE_TAG"

REPOSITORY_URL="$(terraform -chdir=terraform/environments/dev output -raw ecr_repository_url)"
REGISTRY_HOST="${REPOSITORY_URL%%/*}"

aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin "$REGISTRY_HOST"

docker build --platform linux/amd64 -t "$REPOSITORY_URL:$IMAGE_TAG" app
docker push "$REPOSITORY_URL:$IMAGE_TAG"

terraform -chdir=terraform/environments/dev plan \
  -var="ecs_image_tag=$IMAGE_TAG" \
  -out=dev.tfplan
terraform -chdir=terraform/environments/dev apply dev.tfplan
```

Always inspect a targeted plan. After the first image exists, normal changes use complete plans rather than repeated `-target` operations. GitHub Actions will automate the build/push/deploy order in a later phase.

## Runtime validation

After a deliberate AWS apply:

```sh
CLUSTER="$(terraform -chdir=terraform/environments/dev output -raw ecs_cluster_name)"
SERVICE="$(terraform -chdir=terraform/environments/dev output -raw ecs_service_name)"
LOG_GROUP="$(terraform -chdir=terraform/environments/dev output -raw ecs_log_group_name)"

aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --query 'services[0].{desired:desiredCount,running:runningCount,pending:pendingCount,taskDefinition:taskDefinition}'

aws ecs list-tasks --cluster "$CLUSTER" --service-name "$SERVICE"
aws logs tail "$LOG_GROUP" --follow
```

Required evidence:

1. Desired and running task counts match.
2. The task definition references the expected full Git SHA.
3. The task uses private subnets, the ECS security group, and no public IP.
4. ECS successfully injects both secret keys.
5. CloudWatch contains `database startup check passed` and `HTTP server started`.
6. No secret value appears in task-definition JSON, Terraform output, or logs.

## Desired-state replacement exercise

Stop one development task intentionally only after recording its ARN:

```sh
OLD_TASK="$(aws ecs list-tasks \
  --cluster "$CLUSTER" \
  --service-name "$SERVICE" \
  --query 'taskArns[0]' \
  --output text)"

aws ecs stop-task \
  --cluster "$CLUSTER" \
  --task "$OLD_TASK" \
  --reason "Phase 9 desired-state replacement exercise"

aws ecs wait services-stable --cluster "$CLUSTER" --services "$SERVICE"
aws ecs list-tasks --cluster "$CLUSTER" --service-name "$SERVICE"
```

The replacement task ARN must differ from `OLD_TASK`, and desired/running counts must return to equality. Capture the ECS service events and CloudWatch startup logs. This exercise proves reconciliation; it does not prove load-balanced availability, which belongs to the ALB phase.

## Deliberately deferred controls

- ALB target group and `/healthz` traffic checks: next phase.
- Deployment circuit breaker and automatic rollback: rollback phase.
- Service auto scaling: auto-scaling phase.
- Container Insights dashboard and alarms: observability phase.
- GitHub-driven task-definition revisions: CD phase.
- ECR/Secrets Manager/CloudWatch VPC endpoints: later cost and egress review.

## References

- [Amazon ECS task execution IAM role](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html)
- [Amazon ECS task IAM role](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html)
- [Secrets Manager values in ECS environment variables](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/secrets-envvar-secrets-manager.html)
- [Fargate task networking](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-task-networking.html)
- [Fargate CPU and memory combinations](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html)
