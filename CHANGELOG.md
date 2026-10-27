# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

- Initial repository structure.
- Local Go API with liveness, readiness, and user endpoints.
- PostgreSQL development service and persistent volume through Docker Compose.
- Environment example and executable smoke-test workflow.
- Terraform bootstrap for secure S3 remote state and GitHub Actions OIDC authentication.
- Manual GitHub Actions workflow that verifies AWS OIDC and STS role assumption without permanent access keys.
- Reusable two-AZ networking module with public, private application, and isolated database subnet tiers.
- Unit-tested API configuration and HTTP boundaries, including explicit PostgreSQL SSL policy and structured response logging.
- Terraform-specific GitHub OIDC role naming in preparation for separate deployment and ECS runtime identities.
- Reusable security module with public ALB ingress and ALB-to-ECS-to-RDS security-group chaining.
- Private encrypted RDS PostgreSQL module with generated Secrets Manager credentials and environment-specific recovery controls.
- Private encrypted ECR repositories with immutable image tags, scan-on-push, and environment-specific lifecycle retention.
- Private ECS Fargate services with SHA-pinned task definitions, desired-state reconciliation, scoped runtime IAM roles, Secrets Manager injection, and CloudWatch logging.
- Multi-AZ Application Load Balancers with IP target groups, `/healthz` checks, connection draining, private ECS registration, and ALB-to-ECS egress restriction.
- Optional Route 53 application aliases, DNS-validated ACM certificates, HTTPS listeners, modern TLS policy, and permanent HTTP-to-HTTPS redirects.
- Application CI with dependency verification, formatting, vet, race-enabled tests, golangci-lint, Docker builds, and Trivy image scanning.
- Terraform CI with backend-free validation, mocked module tests, TFLint, Trivy IaC scanning, stable branch-protection gates, and a manual OIDC-authenticated speculative plan.
- Reviewed and expiring Trivy exceptions for intentional platform design trade-offs.
- Environment-scoped GitHub OIDC deployment roles with least-privilege ECR, ECS, and `iam:PassRole` permissions.
- Automated development delivery and approval-ready production delivery using immutable Git SHA images, ECS task-definition revisions, service-stability waiting, and post-deployment smoke tests.
- Idempotent deployment reruns that reuse an existing immutable ECR artifact instead of overwriting its tag.

### Changed

- Upgraded the application build baseline to Go 1.27.3 and patched PostgreSQL/Go module dependencies after container scanning identified fixed high and critical vulnerabilities.
- Assigned active ECS task-definition revision ownership to the application CD pipeline while Terraform continues to define the runtime configuration baseline.
- Added retryable read-only mode to the smoke-test script so deployments validate health without creating production data.
