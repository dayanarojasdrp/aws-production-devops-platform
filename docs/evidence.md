# Evidence

## Phase 4: GitHub OIDC authentication

Record the successful GitHub Actions run after the AWS bootstrap is applied.

| Evidence | Value |
| --- | --- |
| Workflow | `AWS OIDC authentication test` |
| Run URL | Pending bootstrap deployment |
| Commit SHA | Pending workflow run |
| AWS account | Pending bootstrap deployment |
| Assumed-role ARN | Pending workflow run |
| Credential lifetime | 900 seconds |
| Permanent AWS keys stored | No |

The workflow job summary contains the `aws sts get-caller-identity` result. Do not paste temporary access keys, secret keys, session tokens, or raw OIDC tokens into this document.

## Phase 8: ECR artifact traceability

Record this only after the development repository has been applied and the image exercise has been performed.

| Evidence | Value |
| --- | --- |
| Repository URL | Pending development deployment |
| Source commit SHA | Pending image build |
| ECR image tag | Pending image push |
| ECR image digest | Pending image push |
| Scan result | Pending ECR scan |
| Pull validation | Pending runtime exercise |
| Immutable overwrite rejection | Pending negative test |

The tag must match the source commit, and the digest must come from ECR. Do not use `latest` as the deployment evidence and do not record registry login tokens.

## Phase 9: ECS Fargate runtime

Record this only after ECR contains the required SHA and the development environment has been applied.

| Evidence | Value |
| --- | --- |
| Cluster | Pending development deployment |
| Service | Pending development deployment |
| Desired / running tasks | Pending stable service |
| Task definition revision | Pending development deployment |
| ECR image SHA | Pending development deployment |
| Task private subnet and ENI | Pending runtime inspection |
| Public task IP | Must be absent |
| Database startup log | Pending CloudWatch validation |
| Replacement task exercise | Pending controlled stop test |

Capture the original and replacement task ARNs, the service event that launches the replacement, and the corresponding CloudWatch startup logs. Never capture secret values, registry tokens, or environment-variable dumps.

## Phase 10: Application Load Balancer

Record this only after the ALB and ECS service have been applied with an image that exists in ECR.

| Evidence | Value |
| --- | --- |
| ALB DNS name | Pending development deployment |
| Public subnets / Availability Zones | Pending runtime inspection |
| Listener `HTTP :80` | Pending development deployment |
| Target type / port | Must be `ip` / `8080` |
| Healthy targets | Pending stable service |
| `GET /healthz` through ALB | Pending HTTP `200` validation |
| `GET /readyz` through ALB | Pending database readiness validation |
| Task stop and replacement | Pending controlled two-target exercise |
| Requests during one-target failure | Pending continuous curl evidence |

For failure evidence, capture the initial healthy targets, the stopped/draining target, the still-healthy target, the replacement task, and the final restored healthy count. A single development task can prove replacement but cannot prove uninterrupted availability; use two tasks for that claim.

## Phase 11: Route 53, ACM, and HTTPS

Record this only after a real domain is delegated, HTTPS is enabled, and the environment is applied.

| Evidence | Value |
| --- | --- |
| Application hostname | Pending domain configuration |
| Route 53 `A` alias target | Pending HTTPS deployment |
| ACM certificate status | Pending `ISSUED` validation |
| Certificate hostname | Must equal the application hostname |
| HTTPS listener / TLS policy | Pending HTTPS deployment |
| HTTP request | Must return `301` with an HTTPS `Location` |
| HTTPS `/healthz` | Pending trusted HTTP `200` validation |
| HTTPS `/readyz` | Pending database readiness validation |
| Certificate verification | Must succeed without `--insecure` |

Capture the redirect with its `Location`, the trusted HTTPS response, and enough AWS metadata to connect the hostname, certificate, listener, and ALB. Do not capture credentials, tokens, certificate private material, or database secrets.
