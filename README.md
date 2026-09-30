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

The first AWS phase creates the protected Terraform state bucket and GitHub Actions OIDC role; it does not deploy application infrastructure. Follow [`terraform/bootstrap/README.md`](terraform/bootstrap/README.md) before initializing the development or production Terraform environments.
