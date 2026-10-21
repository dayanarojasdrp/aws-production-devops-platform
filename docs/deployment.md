# Deployment

## CI does not deploy

The pull-request workflows in this repository validate proposed changes. They
do not push images to ECR, update ECS, or apply Terraform. The only AWS-aware CI
operation is a manual, `main`-only speculative Terraform plan authenticated by
OIDC; it uses `-refresh=false` and must not be reused as an apply artifact.

A later CD phase will define artifact publication and deployment permissions.
Until then, infrastructure apply remains an explicit, reviewed operator action.
See [`cicd.md`](cicd.md) for the complete boundary.

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
