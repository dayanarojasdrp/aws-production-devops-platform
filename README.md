# AWS Production DevOps Platform

Production-oriented AWS platform scaffold using Go, Terraform, containers, and automated delivery workflows.

The current phase focuses on proving the application locally with Go, PostgreSQL, and Docker Compose. AWS infrastructure remains scaffolded for a later phase.

## Repository layout

- `app/`: Go application and container definition.
- `terraform/`: bootstrap configuration, reusable modules, and environments.
- `scripts/`: validation, smoke-test, and load-test helpers.
- `docs/`: architecture and operations documentation.
- `.github/workflows/`: CI/CD workflows.

## Getting started

```sh
cp .env.example .env
make up
make smoke-test
```

Use `make logs` to follow the containers and `make down` to stop them. See [`app/README.md`](app/README.md) for endpoint details and [`docs/local-development.md`](docs/local-development.md) for the architecture and file-by-file explanation.

## AWS bootstrap

The first AWS phase creates the protected Terraform state bucket and a Terraform-specific GitHub Actions OIDC role; it does not deploy application infrastructure. This identity is intentionally separate from the future application-deployment and ECS runtime roles. Follow [`terraform/bootstrap/README.md`](terraform/bootstrap/README.md) before initializing the development or production Terraform environments.

After applying the bootstrap, follow [`docs/oidc.md`](docs/oidc.md) to configure and run the GitHub Actions proof of temporary AWS authentication.

The first application-infrastructure module builds the three-tier VPC. See [`docs/networking.md`](docs/networking.md) for subnet placement, routing, NAT availability/cost trade-offs, and module outputs.

Network ingress is restricted through security-group chaining: the public ALB accepts ports 80/443, ECS accepts port 8080 only from the ALB security group, and RDS accepts port 5432 only from the ECS security group. See [`docs/security.md`](docs/security.md).

The stateful tier uses private, encrypted RDS PostgreSQL with automated backups and Secrets Manager credentials. Development prioritizes lower cost; the production design enables Multi-AZ, longer retention, deletion protection, and a required final snapshot. See [`docs/database.md`](docs/database.md).
