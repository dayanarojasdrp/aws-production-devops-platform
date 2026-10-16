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
