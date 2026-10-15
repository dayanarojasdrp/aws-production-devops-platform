# Cost Management

## Networking

NAT Gateways have hourly and data-processing charges even when application traffic is low.

- Development uses one shared NAT Gateway to reduce fixed cost.
- Production uses one NAT Gateway per Availability Zone to avoid a single-AZ outbound dependency.
- Unused development infrastructure should be destroyed when it is no longer needed.
- A later review should compare NAT traffic cost with VPC endpoints for ECR, S3, CloudWatch Logs, and Secrets Manager.

All networking resources are tagged with `Project`, `Environment`, `ManagedBy`, and `Owner` to support cost allocation.
