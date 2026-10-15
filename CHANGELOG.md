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
