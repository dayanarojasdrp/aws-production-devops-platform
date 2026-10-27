# GitHub Actions authentication with AWS OIDC

Phase 4 proves that GitHub Actions can authenticate to AWS without a stored `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY`.

## Authentication flow

```text
GitHub Actions workflow
        |
        | requests a signed OIDC token
        v
GitHub OIDC provider
        |
        | token contains audience and subject claims
        v
AWS Security Token Service (STS)
        |
        | evaluates the IAM role trust policy
        v
Temporary role credentials
        |
        | expire after 15 minutes in this test
        v
aws sts get-caller-identity
```

OIDC proves who the workflow is. The role trust policy decides whether that identity may assume the role. The role permissions policy decides what it can do after assumption.

## Security boundaries

The bootstrap trust policy checks both claims below:

- `aud` must equal `sts.amazonaws.com`;
- `sub` must identify this repository, its immutable owner/repository IDs, and the `main` branch.

The repository was created after GitHub introduced immutable OIDC subjects in July 2026, so its expected subject is:

```text
repo:dayanarojasdrp@168503064/aws-production-devops-platform@1388204996:ref:refs/heads/main
```

A fork, another repository, or another branch produces a different subject and cannot assume the role. The workflow itself has only `contents: read` and `id-token: write`; the latter allows it to request an OIDC token but does not independently grant AWS access.

The test requests a 900-second role session. No permanent AWS credentials are stored in GitHub, source files, Terraform variables, or repository secrets.

## Workflow

The manual workflow is `.github/workflows/aws-oidc-test.yml`. It performs four checks:

1. requires all repository variables;
2. exchanges the GitHub OIDC token for temporary AWS credentials;
3. rejects credentials issued for an unexpected account;
4. runs `aws sts get-caller-identity` and verifies the assumed-role ARN.

The AWS credentials action is pinned to the immutable commit for version 6.3.0 rather than a moving major-version tag.

## Prerequisite: deploy the bootstrap

The workflow cannot succeed until `terraform/bootstrap` has created the OIDC provider and IAM role. Follow `terraform/bootstrap/README.md`, then record these outputs:

```sh
terraform -chdir=terraform/bootstrap output -raw aws_account_id
terraform -chdir=terraform/bootstrap output -raw aws_region
terraform -chdir=terraform/bootstrap output -raw github_terraform_role_arn
```

## Configure GitHub repository variables

In the GitHub repository, open:

```text
Settings
  -> Secrets and variables
  -> Actions
  -> Variables
```

Create these non-secret repository variables:

| Variable | Source | Example |
| --- | --- | --- |
| `AWS_ACCOUNT_ID` | `terraform output aws_account_id` | `123456789012` |
| `AWS_REGION` | `terraform output aws_region` | `us-east-1` |
| `AWS_TERRAFORM_ROLE_ARN` | `terraform output github_terraform_role_arn` | `arn:aws:iam::123456789012:role/aws-production-devops-platform-github-terraform` |

The manual Terraform CI plan also needs two repository variables:

| Variable | Source | Purpose |
| --- | --- | --- |
| `TF_STATE_BUCKET` | `terraform output -raw state_bucket_name` | Completes the partial S3 backend configuration |
| `ECS_IMAGE_TAG` | Existing ECR image tag | Must be a full lowercase 40-character Git SHA |

These are configuration identifiers, not credentials. The plan runs only from
`main`, requests temporary credentials through the same OIDC trust boundary,
and never executes `terraform apply`.

An IAM role ARN and AWS account ID are identifiers, not passwords. They can be repository variables. Do not create repository secrets containing permanent AWS access keys.

## Deployment roles and GitHub Environments

Application delivery does not reuse `AWS_TERRAFORM_ROLE_ARN`. The bootstrap creates two additional roles:

```sh
terraform -chdir=terraform/bootstrap output github_deployment_role_arns
terraform -chdir=terraform/bootstrap output github_deployment_oidc_subjects
```

The `dev` role trusts only the `development` GitHub Environment subject, and the `prod` role trusts only `production`. When a job declares a GitHub Environment, that environment replaces the branch stanza in the OIDC `sub` claim. The deployment workflow still rejects any Git ref other than `refs/heads/main` before requesting AWS credentials.

This produces three independent trust boundaries:

| Role | Trusted workflow context | AWS responsibility |
| --- | --- | --- |
| Terraform | Repository `main` branch | Terraform state access and planning |
| Deploy dev | `development` GitHub Environment | Dev ECR artifact and dev ECS service |
| Deploy prod | `production` GitHub Environment | Prod ECR artifact and prod ECS service |

Configure the environment-specific variables described in [`deployment.md`](deployment.md). Both Environments must restrict deployment branches to `main`; production should additionally require a reviewer and prevent self-review. No environment needs `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY`.

## Run the proof

After the workflow exists on `main`, open:

```text
Actions -> AWS OIDC authentication test -> Run workflow
```

Choose `main`. A successful execution prints an identity similar to:

```json
{
  "UserId": "ROLE_ID:github-oidc-RUN_ID",
  "Account": "123456789012",
  "Arn": "arn:aws:sts::123456789012:assumed-role/aws-production-devops-platform-github-terraform/github-oidc-RUN_ID"
}
```

This proves that GitHub issued the token, AWS trusted the claims, STS issued temporary credentials, and the workflow assumed the intended role.

## Expected negative tests

These failures are security evidence rather than defects:

- run from a branch other than `main`: AWS rejects the subject;
- configure the wrong `AWS_ACCOUNT_ID`: the credentials action rejects the account;
- configure a different role ARN: either the trust policy rejects assumption or the ARN verification fails;
- remove `id-token: write`: GitHub cannot issue the OIDC token;
- omit a repository variable: the first step fails with a precise error.

## Troubleshooting

### `Not authorized to perform sts:AssumeRoleWithWebIdentity`

Compare the trust policy subject with the actual repository format. Confirm the workflow is running from `main` and that the bootstrap contains the immutable GitHub IDs.

### `No OpenIDConnect provider found`

The bootstrap has not been applied in the target AWS account, or the workflow is pointing to a role in another account.

### `Repository variable ... is not configured`

Create all three variables under GitHub Actions repository variables. They are variables, not secrets.

### `InvalidClientTokenId` on the local computer

The local AWS credentials are invalid or expired. Refresh them before applying the bootstrap. This does not indicate a problem with GitHub OIDC; the workflow intentionally uses a different, temporary credential path.
