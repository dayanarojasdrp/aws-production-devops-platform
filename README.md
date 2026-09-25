# AWS Production DevOps Platform

Production-oriented AWS platform scaffold using Go, Terraform, containers, and automated delivery workflows.

## Repository layout

- `app/`: Go application and container definition.
- `terraform/`: bootstrap configuration, reusable modules, and environments.
- `scripts/`: validation, smoke-test, and load-test helpers.
- `docs/`: architecture and operations documentation.
- `.github/workflows/`: CI/CD workflows.

## Getting started

Copy the relevant `terraform.tfvars.example`, configure the remote backend, and run `make validate` before planning infrastructure changes.
