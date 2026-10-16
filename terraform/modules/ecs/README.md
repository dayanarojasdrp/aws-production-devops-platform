# ECS Fargate module

Creates the managed application runtime for one environment:

- an ECS cluster as the logical workload boundary;
- a versioned Fargate task definition for the exact immutable ECR Git SHA;
- an ECS service that maintains the desired number of replicas;
- private `awsvpc` networking with no public task IP;
- a CloudWatch log group for container stdout and stderr;
- a least-privilege execution role and a permission-free application task role.

The execution role can retrieve an ECR authorization token, pull only from the supplied repository, write only to this module's log group, and read only the supplied database secret. The task role has a trust policy but no permission policy because the Go application does not call AWS APIs.

`DB_HOST`, `DB_PORT`, `DB_NAME`, and `DB_SSLMODE` are non-secret environment values. `DB_USER` and `DB_PASSWORD` reference the `username` and `password` JSON keys in Secrets Manager. Fargate platform `1.4.0` is explicit because JSON-key secret injection requires Linux platform 1.4.0 or later.

The service currently has no load balancer block. The next phase will connect the public ALB target group to container `api` on port `8080` and use `/healthz` for traffic health. Until then, the tasks are intentionally unreachable from the internet.

The image must exist before the service is created. `image_tag` accepts only a full 40-character lowercase Git SHA and never defaults to `latest`. For an entirely new environment, create ECR first, push the image, and then apply the complete environment.

Task definition revisions use `skip_destroy = true` so replaced revisions remain available for deployment history and rollback. Decommissioning an environment therefore requires deliberately deregistering retained revisions after Terraform removes the active infrastructure.

Run `terraform test` from this directory to verify dev and prod sizing, private networking, secret injection, logging, IAM scope, and desired task counts with a mocked AWS provider. Tests do not create AWS resources.
