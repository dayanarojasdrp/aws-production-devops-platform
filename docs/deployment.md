# Deployment

## Automated application delivery

Phase 13 turns an approved `main` commit into a running ECS revision. It does not automate Terraform apply: infrastructure changes remain a separate reviewed operation.

```text
Pull request -> CI gates -> merge to main
                              |
                              v
                       retest exact SHA
                              |
                              v
                   GitHub Environment + OIDC
                              |
                              v
                   build/reuse + scan artifact
                              |
                              v
                         immutable ECR tag
                              |
                              v
                  new ECS task-definition revision
                              |
                              v
                  rolling service deployment + ALB
                              |
                              v
                    stable service + smoke test
```

The workflow is `.github/workflows/deploy.yml`. A push containing application or delivery files automatically targets `development`. A manual run from `main` can target `development` or `production`; production should use a required reviewer on its GitHub Environment.

## What each deployment step proves

1. **Preflight** rejects non-`main` refs and any target other than `development` or `production` before AWS authentication.
2. **Retest** runs `go mod verify` and `go test ./...` against the exact checked-out `GITHUB_SHA`.
3. **OIDC authentication** exchanges a GitHub token for a one-hour STS session in the environment-specific deployment role. No permanent AWS keys exist.
4. **Artifact preparation** uses the full 40-character Git SHA as the ECR tag. If that immutable tag already exists, a rerun pulls and reuses it; otherwise the workflow builds it.
5. **Security scan** checks the exact local image for fixed HIGH and CRITICAL OS/library vulnerabilities before any new push.
6. **Publication** pushes only a new SHA. The workflow then resolves and records ECR's `sha256` digest.
7. **Task definition** downloads the latest Terraform-managed family baseline and changes only container `api`'s image.
8. **ECS deployment** registers a new revision, updates the one allowed service, and waits up to 20 minutes for service stability.
9. **Runtime verification** confirms the service uses the new revision and that desired/running counts match with no pending tasks.
10. **Smoke test** checks `/healthz` and `/readyz` in retryable read-only mode, so deployment validation does not create user records.

An accepted `UpdateService` API request is not considered success. Success means ECS is stable and the externally reachable health and database-readiness endpoints both respond successfully.

## GitHub Environment configuration

Create two GitHub Environments with these exact names:

```text
development
production
```

Configure the following non-secret variables in each Environment:

| Variable | Terraform/bootstrap source |
| --- | --- |
| `AWS_ACCOUNT_ID` | `terraform -chdir=terraform/bootstrap output -raw aws_account_id` |
| `AWS_REGION` | `terraform -chdir=terraform/bootstrap output -raw aws_region` |
| `AWS_DEPLOY_ROLE_ARN` | Matching value from `github_deployment_role_arns` |
| `ECR_REPOSITORY_NAME` | Environment output `ecr_repository_name` |
| `ECS_CLUSTER_NAME` | Environment output `ecs_cluster_name` |
| `ECS_SERVICE_NAME` | Environment output `ecs_service_name` |
| `ECS_TASK_DEFINITION_FAMILY` | Environment output `ecs_task_definition_family` |
| `APPLICATION_URL` | HTTPS `application_url`, or `http://` plus `alb_dns_name` before DNS/TLS is enabled |

Example commands for development:

```sh
terraform -chdir=terraform/bootstrap output github_deployment_role_arns
terraform -chdir=terraform/environments/dev output -raw ecr_repository_name
terraform -chdir=terraform/environments/dev output -raw ecs_cluster_name
terraform -chdir=terraform/environments/dev output -raw ecs_service_name
terraform -chdir=terraform/environments/dev output -raw ecs_task_definition_family
terraform -chdir=terraform/environments/dev output -raw application_url
```

If HTTPS is disabled, obtain `alb_dns_name` and prefix it with `http://`. Do not add `/healthz` to `APPLICATION_URL`; the smoke script adds endpoint paths.

In both Environments, set the deployment branch/tag rule to selected branches and allow only `main`. This rule is a security boundary because an Environment-based OIDC subject contains the Environment name instead of the branch. The workflow's preflight check is useful defense in depth, but repository code alone cannot replace the Environment branch rule.

Protect `production` with required reviewers, prevent self-review, and prevent administrators from bypassing the protection rule unless an emergency process is documented. Environment approval controls when the job can request its production OIDC token.

## IAM least privilege

The bootstrap creates separate `dev` and `prod` deployment roles. Each role can:

- authenticate Docker to ECR;
- read, pull, and push only its environment's repository;
- describe only its task-definition family;
- register a task-definition revision;
- describe and update only its ECS service;
- pass only the matching ECS execution and task roles, and only to `ecs-tasks.amazonaws.com`.

`ecs:RegisterTaskDefinition` uses resource `*` because the revision does not have an ARN until registration. It is not equivalent to administrator access: the workflow cannot pass arbitrary roles or update arbitrary services.

## Terraform and CD do not fight

Terraform continues to define the task configuration baseline. CD downloads the latest family revision and changes only its image. The ECS service ignores Terraform changes to the active `task_definition` attribute so a routine infrastructure apply cannot roll the application back to the bootstrap SHA.

When Terraform changes CPU, memory, port, environment values, secret references, IAM roles, or logging, it creates a newer baseline revision. Run the deployment workflow afterward to promote that baseline with the desired image. Query `aws ecs describe-services` for the actual running revision; the Terraform task-definition output identifies its managed baseline.

## Failure boundaries

| Failure | Result |
| --- | --- |
| Tests fail | No AWS authentication or artifact publication |
| OIDC/configuration fails | No ECR or ECS mutation |
| Build or Trivy fails | No new image push and no ECS update |
| ECR push/digest lookup fails | Existing ECS revision remains active |
| Task registration/update fails | Workflow fails; old healthy tasks remain subject to ECS rolling behavior |
| Service never stabilizes | Workflow fails before smoke testing |
| Smoke test fails | Deployment is visibly unsuccessful even if ECS reports stable |

Automatic rollback is intentionally the next reliability phase. This phase detects and reports an unhealthy deployment; the deployment circuit breaker will later restore the previous healthy revision automatically.

## Validation and evidence

This phase is complete in AWS only after proving:

- a `main` application merge automatically starts development delivery;
- the job assumes the development role with OIDC;
- ECR contains the exact full Git SHA and records its digest;
- ECS creates a new task-definition revision with that image;
- old tasks are progressively replaced only after ALB health checks pass;
- desired and running task counts match;
- `/healthz` and `/readyz` pass through the public endpoint;
- a production run waits for Environment approval;
- no permanent AWS keys are stored.

Record run URLs and screenshots in [`evidence.md`](evidence.md). Do not capture ECR passwords, STS credentials, OIDC tokens, database secret values, or complete task environment dumps.

## Infrastructure provisioning

The current Terraform configuration provisions networking, security groups, RDS PostgreSQL, its Secrets Manager credential, the private ECR repository, the ECS Fargate application runtime, and an internet-facing ALB connected to the ECS service. With a real domain and public hosted zone, it also provisions the Route 53 alias, DNS-validated ACM certificate, HTTPS listener, and HTTP redirect.

After the bootstrap and development backend are configured:

```sh
terraform -chdir=terraform/environments/dev init -backend-config=backend.hcl
terraform -chdir=terraform/environments/dev validate
terraform -chdir=terraform/environments/dev plan -out=dev.tfplan
terraform -chdir=terraform/environments/dev show dev.tfplan
terraform -chdir=terraform/environments/dev apply dev.tfplan
```

Review the plan before applying, especially:

- `publicly_accessible = false`;
- `storage_encrypted = true`;
- private DB subnet IDs;
- only the RDS security group attached;
- instance class and Multi-AZ choice;
- backup retention and deletion controls;
- absence of password outputs;
- ECR tag mutability set to `IMMUTABLE`;
- ECR scan-on-push and AES-256 encryption enabled;
- environment-appropriate image retention and deletion behavior.
- a full Git SHA in `ecs_image_tag`, already present in ECR;
- Fargate tasks placed only in private application subnets with no public IP;
- execution-role access scoped to the repository, log group, and database secret;
- expected dev/prod CPU, memory, desired count, and log retention;
- an internet-facing ALB using both public subnets;
- an `ip` target group forwarding to port `8080`;
- `/healthz` matcher `200`, deliberate thresholds, and connection draining;
- an ECS service load-balancer block using container `api` and the target group;
- ALB egress restricted to the ECS security group on `8080`;
- production ALB deletion protection enabled.
- HTTPS disabled unless a real hostname and authoritative Route 53 zone are supplied;
- when enabled, ACM DNS validation in the intended public hosted zone;
- a `443` HTTPS listener using the reviewed TLS policy;
- the port `80` default action changing to `HTTP_301` redirect;
- the Route 53 `A` alias targeting the ALB DNS name and zone ID.

After apply, use the non-sensitive outputs to record the endpoint, port, database name, and secret ARN. Do not print or copy the secret value into documentation.

Production deletion protection intentionally prevents a direct destroy. Removing a production database requires an explicit configuration change, a reviewed apply that disables deletion protection, and a final snapshot. Development can be destroyed without a final snapshot when its data is confirmed disposable.

After ECR exists, follow the controlled build, SHA tagging, push, pull, and immutability checks in [`container-registry.md`](container-registry.md). These manual checks produce evidence for this phase; GitHub Actions will automate the same artifact flow in a later CI/CD phase.

For a new environment, follow the ECR-first bootstrap order and ECS runtime validation in [`ecs-fargate.md`](ecs-fargate.md). A normal full apply before the referenced image exists will cause the ECS service to fail steady-state validation because Fargate cannot pull a nonexistent tag.

After the service stabilizes, follow the ALB health and controlled target-failure checks in [`load-balancing.md`](load-balancing.md). If DNS and HTTPS are enabled, follow [`dns-https.md`](dns-https.md) to prove certificate issuance, alias resolution, HTTP `301`, trusted HTTPS, health, and database readiness.
