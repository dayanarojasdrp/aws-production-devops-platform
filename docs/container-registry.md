# Amazon ECR container registry

## Responsibility in the platform

GitHub stores source code, Amazon ECR stores built container artifacts, and ECS Fargate runs those artifacts:

```text
Git commit
    |
    v
GitHub Actions builds the container
    |
    v
ECR stores <repository>:<git-sha>
    |
    v
ECS task definition runs that exact image
```

ECR is not an application server. It is the private registry between the build and runtime stages. The Terraform resource creates a private repository; no public ECR repository is used.

## Repository naming and environment isolation

Each environment owns its repository:

```text
aws-production-devops-platform-dev-api
aws-production-devops-platform-prod-api
```

This avoids two Terraform states managing the same ECR resource and permits different cleanup protections. A future delivery workflow can push the same tested Git SHA to each environment repository when promoting a release.

## Traceable image tags

The canonical deployment tag will be the full Git commit SHA:

```text
123456789012.dkr.ecr.us-east-1.amazonaws.com/aws-production-devops-platform-prod-api:<git-sha>
```

This provides a direct mapping between source commit, workflow execution, stored image, and ECS task definition. ECS must not depend only on `latest`, because that tag does not identify a unique source revision.

The repository uses `IMMUTABLE` tag mutability. Once a SHA tag exists, a second push using that tag fails instead of changing the artifact it identifies. All tags are immutable; there is no mutable `latest` exception.

The image digest remains the content identity calculated by the registry. The Git SHA tag supplies the human and CI/CD trace back to source code. Both should be recorded as deployment evidence.

## Security controls

- The repository is private and relies on AWS IAM authentication.
- ECR-managed AES-256 server-side encryption protects stored image layers.
- Basic vulnerability scanning runs when an image is pushed.
- Tags are immutable to prevent artifact replacement.
- Project, environment, owner, and management tags support inventory and cost attribution.

The repository does not contain credentials and Terraform outputs no Docker password. `aws ecr get-login-password` produces a temporary registry login from the caller's AWS identity.

Scan-on-push is a detection control, not an admission controller: it produces vulnerability findings but does not by itself reject a vulnerable image or stop its deployment. A later CI phase will use Trivy as the pre-push blocking control, while ECR scanning provides registry-side visibility.

Repository-level scan-on-push is used in this phase because each environment owns its ECR module. AWS recommends central registry-level scanning configuration for broader governance; that is an account-wide concern and should live in one shared security or registry stack rather than be declared once per environment.

## Lifecycle and rollback window

The lifecycle policy expires images when the repository contains more than the configured count:

| Environment | Images retained | Repository deletion |
| --- | ---: | --- |
| Development | 20 | Allowed with images for intentional cleanup |
| Production | 50 | Refused while images remain |

The policy limits storage growth but also defines the available rollback history. Before production automation is enabled, deployment logic and operational procedures must ensure that the running image and intended rollback image remain inside this window.

Tag immutability and lifecycle retention solve different problems:

```text
immutability -> a retained tag cannot change
retention    -> an old image can eventually expire
```

## IAM boundaries for later phases

No IAM policy is created in this phase. Later roles will use separate responsibilities:

```text
GitHub deployment role -> authenticate, upload layers, push image
ECS execution role     -> authenticate, inspect layers, pull image
Application task role  -> no ECR permissions
```

Push permissions will be scoped to the repository ARN exported by this module. ECR authorization-token retrieval cannot be scoped to one repository and must use resource `*`, while upload actions can be restricted to the repository ARN. The ECS execution role will use the standard pull actions; the application role does not need ECR access because the ECS agent pulls the image before the container starts.

## Terraform outputs

The environment exposes:

```text
ecr_repository_arn  -> IAM policy scoping
ecr_repository_name -> AWS CLI operations
ecr_repository_url  -> Docker tag and ECS image reference
```

These values are identifiers, not credentials.

## Validation after an intentional AWS deployment

Terraform tests prove the configuration without creating resources. Runtime evidence requires applying the development environment and then performing a controlled push/pull exercise.

Use the repository URL from Terraform rather than constructing it manually:

```sh
AWS_REGION="us-east-1"
REPOSITORY_URL="$(terraform -chdir=terraform/environments/dev output -raw ecr_repository_url)"
IMAGE_TAG="$(git rev-parse HEAD)"
REGISTRY_HOST="${REPOSITORY_URL%%/*}"

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY_HOST"

docker build --platform linux/amd64 -t "$REPOSITORY_URL:$IMAGE_TAG" app
docker push "$REPOSITORY_URL:$IMAGE_TAG"
aws ecr describe-images \
  --repository-name "$(terraform -chdir=terraform/environments/dev output -raw ecr_repository_name)" \
  --image-ids imageTag="$IMAGE_TAG" \
  --region "$AWS_REGION"
docker pull "$REPOSITORY_URL:$IMAGE_TAG"
```

The explicit platform must match the future ECS task definition. The planned default is `linux/amd64`; changing ECS to ARM64 would require changing the build platform as the same coordinated decision.

Validation evidence should demonstrate:

1. The local image builds successfully.
2. The pushed tag equals the source commit SHA.
3. ECR reports the tag, digest, push timestamp, and scan result.
4. Pulling the image succeeds.
5. Attempting to push different content with the existing SHA tag fails with `ImageTagAlreadyExistsException`.

Do not fabricate this evidence before the repository has been deployed. Record the real workflow URL, commit SHA, image digest, scan result, and immutable-tag failure when the AWS validation is performed.

## References

- [Preventing image tags from being overwritten in Amazon ECR](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-tag-mutability.html)
- [Configuring basic scanning for images in Amazon ECR](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning-basic-enabling.html)
- [Lifecycle policy properties in Amazon ECR](https://docs.aws.amazon.com/AmazonECR/latest/userguide/lifecycle_policy_parameters.html)
