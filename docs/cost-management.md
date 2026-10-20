# Cost Management

## Networking

NAT Gateways have hourly and data-processing charges even when application traffic is low.

- Development uses one shared NAT Gateway to reduce fixed cost.
- Production uses one NAT Gateway per Availability Zone to avoid a single-AZ outbound dependency.
- Unused development infrastructure should be destroyed when it is no longer needed.
- A later review should compare NAT traffic cost with VPC endpoints for ECR, S3, CloudWatch Logs, and Secrets Manager.

All networking resources are tagged with `Project`, `Environment`, `ManagedBy`, and `Owner` to support cost allocation.

## Database and secrets

RDS instance runtime, allocated storage, backup storage beyond the included allowance, Multi-AZ deployment, and Secrets Manager secrets can all incur charges.

- Development uses `db.t4g.micro`, Single-AZ, 20 GiB gp3, and short backup retention.
- Production is designed for `db.t4g.small`, Multi-AZ, more storage, and longer retention.
- Storage autoscaling has an explicit maximum in each environment.
- Production is represented as code and does not need to remain deployed for portfolio development.
- Destroy development resources when they are no longer needed, but confirm the data is disposable before removing its database or secret.

## Container registry

ECR charges for stored image data and data transfer. Repeated pushes can accumulate layers even when an image is no longer deployed.

- Development retains the newest 20 images.
- Production retains the newest 50 images to provide a larger rollback window.
- Image layers shared by several images are stored efficiently, but lifecycle cleanup still prevents indefinite growth.
- Development permits repository cleanup with images; production requires images to be removed deliberately first.
- Scan-on-push adds security evidence without requiring a customer-managed KMS key in this phase.

## ECS Fargate and logs

Fargate charges for provisioned task CPU and memory while tasks run. CloudWatch Logs charges for ingestion and retained storage, and task startup traffic through NAT can add processing charges.

- Development maintains one 0.25-vCPU/512-MiB task and retains logs for 7 days.
- Production is designed for two 0.5-vCPU/1-GiB tasks and 30-day log retention.
- Two production tasks trade higher steady cost for replica availability and rolling-deployment capacity.
- Task sizing is an initial hypothesis; CloudWatch and load testing must justify later increases.
- Fargate has no EC2 worker-management overhead, but predictable high-volume workloads may be cheaper on carefully managed EC2 capacity.

## Application Load Balancer

The ALB creates a continuous hourly charge plus Load Balancer Capacity Unit usage, even when development traffic is low. It cannot scale to zero.

- One ALB is created per deployed environment to preserve environment isolation.
- Development deletion protection is disabled so the stack can be destroyed after evidence is captured.
- Production deletion protection is enabled and must be deliberately disabled before destruction.
- Access logs are deferred until the observability phase to avoid creating an unplanned S3 logging design.
- HTTPS and Route 53 will add certificate/DNS design in the next phase; ACM public certificates themselves do not require replacing the ALB.
