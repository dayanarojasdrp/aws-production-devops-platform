# ECR module

Creates one private Amazon ECR repository for the API container images. Private is the native repository type created by `aws_ecr_repository`; no public registry resource is used.

The module makes every image tag immutable, enables basic scanning on push, uses ECR-managed AES-256 server-side encryption, and expires images beyond an environment-specific retention count. A tag derived from a Git commit SHA therefore continues to identify the same artifact for its entire retained lifetime.

`force_delete` is enabled only by the disposable development environment. Production refuses repository deletion while images remain. Lifecycle expiration is based on image count, so deployment automation must keep the running and intended rollback images within the configured retention window.

The outputs expose the repository ARN, name, URL, and registry ID. They contain no registry credentials. A later IAM phase will scope GitHub push permissions to `repository_arn`; the ECS task execution role will receive the standard ECR pull permissions.

Run `terraform test` from this directory to validate the development and production controls with a mocked AWS provider. The tests do not create AWS resources or push images.
