# Terraform bootstrap

This root module creates only the foundations required before the main AWS platform can be managed safely:

1. a protected S3 bucket for remote Terraform state;
2. the GitHub Actions OIDC identity provider in AWS IAM;
3. a branch- and repository-restricted IAM role for GitHub Actions;
4. least-privilege access from that role to the `dev` and `prod` state objects and lock files.

It deliberately does not create the VPC, ECS, ALB, RDS, ECR, application, or observability resources.

## Why this module starts with local state

The S3 backend cannot store state until the bucket itself exists. This bootstrap module therefore starts with Terraform's default local backend. Its local `terraform.tfstate` is ignored by Git and must be handled as a sensitive operational artifact.

After this module creates the bucket, the environment root modules use S3 remote state. The bootstrap state remains local because migrating the state that owns its own backend requires an additional lifecycle decision and is outside this phase.

## Resources and security controls

### S3 state bucket

- Versioning is enabled for state recovery.
- AES-256 server-side encryption is enabled by default.
- All four S3 public-access-block controls are enabled.
- ACLs are disabled through bucket-owner-enforced ownership.
- A bucket policy denies every request that does not use TLS.
- `force_destroy = false` and `prevent_destroy = true` protect the bucket from accidental Terraform destruction.

### GitHub OIDC and IAM

- The provider URL is `https://token.actions.githubusercontent.com`.
- The only accepted audience is `sts.amazonaws.com`.
- The trust policy accepts one repository and one branch.
- New GitHub repositories can use immutable owner and repository IDs in the OIDC subject.
- The role receives temporary credentials for at most one hour.
- Its current permission policy can access only the two state paths and delete only `.tflock` objects, never state objects.

The role intentionally has no ECS, ECR, VPC, RDS, or administrator permissions yet. Those permissions must be added when the corresponding infrastructure and CI/CD responsibilities exist, using concrete resource ARNs wherever AWS supports them.

## Prerequisites

- Terraform 1.10 or later.
- AWS credentials for the account being bootstrapped.
- Permission to manage S3 buckets, IAM OIDC providers, roles, and inline role policies.
- A globally unique S3 bucket name.
- The GitHub owner, repository, branch, and—when applicable—immutable numeric IDs.

Confirm the target account before applying:

```sh
aws sts get-caller-identity
```

For a public repository, retrieve the immutable IDs with:

```sh
gh api repos/dayanarojasdrp/aws-production-devops-platform \
  --jq '{owner_id: .owner.id, repository_id: .id}'
```

## Run the bootstrap

```sh
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
```

The checked-in example already contains the immutable public IDs for this repository. Edit `terraform.tfvars` and replace `ACCOUNT_ID` in the bucket name. Then run:

```sh
terraform init
terraform fmt -check
terraform validate
terraform plan -out=bootstrap.tfplan
terraform apply bootstrap.tfplan
terraform output
```

The equivalent repository shortcuts are `make bootstrap-init`, `make bootstrap-validate`, and `make bootstrap-plan`.

Do not commit `terraform.tfvars`, `bootstrap.tfplan`, or `terraform.tfstate`.

## Configure the environment backends

Copy each environment's backend example:

```sh
cp ../environments/dev/backend.hcl.example ../environments/dev/backend.hcl
cp ../environments/prod/backend.hcl.example ../environments/prod/backend.hcl
```

Replace the example bucket name with the `state_bucket_name` output. Initialize each environment using partial backend configuration:

```sh
terraform -chdir=../environments/dev init -backend-config=backend.hcl
terraform -chdir=../environments/prod init -backend-config=backend.hcl
```

Development uses `dev/terraform.tfstate`; production uses `prod/terraform.tfstate`. Both use native S3 lock files through `use_lockfile = true`, so no DynamoDB table is created.

## Existing GitHub OIDC provider

An AWS account can already contain the GitHub OIDC provider because another project created it. If so, do not create a duplicate. Import it into this bootstrap state before applying:

```sh
terraform import aws_iam_openid_connect_provider.github \
  arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com
```
