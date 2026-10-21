# Continuous integration

Phase 12 adds pull-request quality gates. It does not publish an image, modify
AWS, update ECS, or run `terraform apply`.

## CI and CD are different controls

| Control | Question answered | This phase |
| --- | --- | --- |
| Continuous Integration (CI) | Is this proposed code safe and internally consistent enough to merge? | Implemented |
| Continuous Delivery/Deployment (CD) | Which approved artifact should be released, and how is it promoted and rolled back? | Deliberately deferred |

The CI workflows are therefore allowed to test, compile, lint, scan, and create
a speculative plan. They are not allowed to push to ECR, register an ECS task
definition, update a service, apply Terraform, or destroy infrastructure.

```text
Pull request
    |
    +-- application paths changed? -- yes --> tests + lint + image build + scan
    |                              \-- no  --> jobs skipped, gate reports success
    |
    +-- Terraform paths changed? --- yes --> fmt + validate + tests + lint + scan
                                   \-- no  --> jobs skipped, gate reports success

Approved merge to main
    |
    +-- CI runs again for the affected area
    |
    +-- no deployment in Phase 12
```

## Application workflow

`.github/workflows/app-ci.yml` validates the Go service.

### Change detection

The workflow always starts for pull requests targeting `main`, then compares
the pull request's base and head SHAs. Expensive jobs run only when application
code, its lint policy, the shared validation commands, or the workflow itself
changed.

This two-level design is intentional. A workflow skipped entirely by a path
filter can leave a required GitHub check in `Pending`. Here the workflow always
reports `Application CI gate`, while individual jobs may safely report
`Skipped` for a Terraform-only change.

### Test and vet

This job:

1. reads the required Go version from `app/go.mod`;
2. restores the module cache using `app/go.sum`;
3. downloads and verifies module checksums;
4. rejects files that are not formatted by `gofmt`;
5. runs `go vet ./...`;
6. runs tests with race detection and writes a coverage profile.

`go vet` finds suspicious constructs that compile but are often mistakes. The
race detector instruments concurrent access and fails when tests expose an
unsafe data race. The coverage file is produced for inspection; this phase does
not impose an arbitrary coverage percentage.

### Lint

`golangci-lint` runs the standard linter set plus the `gofmt` and `goimports`
formatters configured in `.golangci.yml`. The linter and its GitHub Action are
version-pinned, so a moving upstream release cannot silently change a pull
request result.

### Container build and vulnerability scan

The workflow builds the real `app/Dockerfile` and tags the local CI image with
the source commit SHA. Trivy then checks operating-system and Go-module
vulnerabilities. A fixed `HIGH` or `CRITICAL` vulnerability makes the job fail.

The image is local to the runner. CI never logs in to ECR and never pushes it.
The later deployment workflow will rebuild or promote a reviewed SHA-tagged
artifact with a separate AWS deployment role.

The first local scan in this phase correctly detected vulnerabilities in Go
1.24 and old `pgx`/Go module versions. The baseline was upgraded to Go 1.27.3,
`pgx` 5.9.0, `x/sync` 0.22.0, and `x/text` 0.41.0. The rebuilt image then
reported zero `HIGH` or `CRITICAL` findings.

## Terraform workflow

`.github/workflows/terraform-ci.yml` separates checks that need no AWS identity
from a plan that needs controlled, temporary AWS access.

### Format, validate, and test

`scripts/terraform-static-checks.sh` is the single entry point used by CI and by
`make terraform-check`. It:

1. runs `terraform fmt -check -recursive terraform`;
2. initializes each root and implemented module with `-backend=false`;
3. validates bootstrap, modules, development, and production;
4. executes the existing mocked module tests.

`terraform validate` proves syntax and internal consistency. It does not read
remote state, contact AWS resource APIs, or prove what a real plan will change.
That limitation is why validation and planning are separate controls.

The optional `TERRAFORM_BIN` environment variable lets a developer validate
with an explicitly downloaded Terraform binary without rewriting the script.
CI uses Terraform 1.16.6 directly from `setup-terraform`.

### TFLint

`.tflint.hcl` enables the Terraform language rules and the pinned AWS ruleset.
It checks naming, documented variables and outputs, required provider/version
constraints, deprecated interpolation, unused declarations, and AWS-specific
configuration mistakes.

TFLint runs from `terraform/`, while the config path is absolute. This matters:
recursive TFLint workers start in child directories, so a relative root config
path would fail to resolve.

### IaC security scan

Trivy scans every Terraform root for `HIGH` and `CRITICAL` misconfigurations and
fails the job when an unaccepted finding exists.

`.trivyignore.yaml` contains four narrow, temporary design exceptions. Every
entry has a resource path, explanation, and expiration date:

| Finding | Existing design decision | Required follow-up |
| --- | --- | --- |
| State bucket uses SSE-S3 rather than a customer KMS key | State is still encrypted, versioned, and public access is blocked | Reassess KMS key policy with final IAM roles |
| ALB is internet-facing | It is the intended and only public ingress tier | Keep ECS and RDS private |
| Port 80 listener exists | It redirects to HTTPS when enabled and supports domainless development before ACM | Require HTTPS for the final production deployment |
| ECS/RDS security groups contain broad egress | ECS needs NAT access to AWS services during the current design; no public ingress is permitted | Reassess VPC endpoints and egress in hardening phase |

An exception is not proof that a resource is secure. Expiry forces the decision
back into review; a new unrelated finding still fails CI.

### Authenticated speculative plan

Static checks run for pull requests without AWS credentials. A real plan is a
manual `workflow_dispatch` operation and only runs from `main`, which matches
the current OIDC role trust boundary. This prevents unreviewed pull-request or
fork code from receiving an AWS identity.

The job requires these GitHub repository variables:

| Variable | Purpose |
| --- | --- |
| `AWS_ACCOUNT_ID` | Reject credentials from an unexpected AWS account |
| `AWS_REGION` | Configure STS and the S3 backend region |
| `AWS_TERRAFORM_ROLE_ARN` | Assume the Terraform-specific role through OIDC |
| `TF_STATE_BUCKET` | Complete the partial S3 backend configuration |
| `ECS_IMAGE_TAG` | Supply an existing full 40-character Git SHA to the ECS module |

The plan uses temporary OIDC credentials, initializes the selected `dev` or
`prod` remote state, and accepts Terraform detailed exit codes `0` (no change)
and `2` (change present). It writes a short summary but does not upload the plan
file because a saved plan can contain sensitive values.

`-refresh=false` is deliberate at this stage: the current Terraform role is
state-oriented and has not yet received final least-privilege read permissions
for every AWS service. The result can compare configuration with stored state,
but it cannot detect out-of-band drift and must never be treated as the final
apply plan. A future CD workflow must create a fresh, reviewed plan with refresh
enabled immediately before apply.

## Permissions and supply-chain controls

Both workflows default to `contents: read`. Only the manual plan job receives
`id-token: write`, and it receives no repository write permission. All reusable
GitHub Actions are pinned to full commit SHAs; comments retain the human-readable
release version for maintenance.

No permanent AWS access key is used. Application CI receives no AWS permission
at all.

## Final gate jobs and branch protection

Require these two stable checks on `main`:

- `Application CI / Application CI gate`
- `Terraform CI / Terraform CI gate`

Each gate fails if path detection fails or if any relevant child job fails. On
an unrelated change, expensive children are skipped and the gate succeeds. Do
not require the individual conditional jobs; the two gates are the durable
branch-protection contract.

Recommended repository rule:

1. require a pull request before merging;
2. require the two CI gates above;
3. require branches to be up to date before merging;
4. prevent bypass unless an explicitly documented emergency process exists;
5. optionally require one approval and resolution of review conversations.

## Local validation

```sh
make app-test
make terraform-check
docker build --tag users-api:ci-local app
```

The GitHub runner additionally executes race detection, golangci-lint, TFLint,
and Trivy using the pinned versions in the workflow files.

## Controlled failure exercises

Run these only on a short-lived branch and revert the intentional defect before
merging:

1. make a Go test assertion fail and confirm `Application CI gate` blocks;
2. misformat a `.tf` file and confirm the Terraform format job blocks;
3. add a test security-group rule exposing port `5432` publicly and confirm
   Trivy blocks it;
4. revert each defect and record the successful rerun URL in `evidence.md`.

The useful evidence is the transition from failed check, through diagnosis and
fix, to a green gate—not merely a screenshot of a green tick.
