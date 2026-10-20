# AWS network architecture

Phase 5 created the network boundaries now consumed by the ALB, ECS service, and RDS database. Each workload remains owned by its dedicated module.

## Traffic model

```text
Internet
   |
   v
Internet Gateway
   |
   v
Public subnets (internet-facing ALB)
   |
   v
Private application subnets (ECS tasks)
   |
   v
Isolated database subnets (RDS PostgreSQL)
```

The intended rule is: Internet clients can reach the ALB; the ALB can reach ECS; ECS can reach RDS. Internet clients cannot directly reach ECS or RDS. The routing boundaries are implemented here, while the security groups enforcing the workload-to-workload chain are implemented in [`security.md`](security.md).

## VPC and Availability Zones

Each environment creates one VPC with DNS support and DNS hostnames enabled. Every network tier spans exactly two Availability Zones so future services can avoid depending on a single AZ.

Development uses `10.0.0.0/16`:

| Tier | AZ A | AZ B |
| --- | --- | --- |
| Public | `10.0.1.0/24` | `10.0.2.0/24` |
| Private application | `10.0.11.0/24` | `10.0.12.0/24` |
| Isolated database | `10.0.21.0/24` | `10.0.22.0/24` |

Production uses a separate `10.1.0.0/16` range with the same tier pattern. Separate non-overlapping VPC ranges leave room for future private connectivity without an immediate CIDR collision.

## What makes each subnet tier different

### Public subnets

Both public subnets share a route table containing:

```text
VPC CIDR   -> local
0.0.0.0/0 -> Internet Gateway
```

The Internet Gateway route is what makes a subnet public. A resource inside it is not automatically internet-accessible: addressing, security groups, network ACLs, and resource configuration still matter.

Automatic public IPv4 assignment is disabled even in this tier. The internet-facing ALB manages its own public addresses; unrelated resources should not receive a public IP merely because they are launched in a public subnet.

The internet-facing Application Load Balancer uses both public subnet IDs.

### Private application subnets

Each private application subnet has its own route table:

```text
VPC CIDR   -> local
0.0.0.0/0 -> NAT Gateway
```

This lets ECS tasks initiate outbound connections for operations such as pulling images and sending logs. The NAT Gateway does not create an unsolicited inbound path from the Internet to ECS.

### Isolated database subnets

Each database subnet has a dedicated route table containing only the automatic local VPC route:

```text
VPC CIDR -> local
```

There is no default route to the Internet Gateway or NAT Gateway. Future RDS instances will also set `publicly_accessible = false` and receive a security group that accepts PostgreSQL only from the ECS security group.

## NAT design and trade-off

The reusable module supports two modes:

| Mode | NAT Gateways | Benefit | Trade-off |
| --- | ---: | --- | --- |
| `single_nat_gateway = true` | 1 | Lower fixed development cost | Both app subnets depend on the NAT's AZ; cross-AZ traffic may occur |
| `single_nat_gateway = false` | 2 | Each app subnet uses a NAT in its own AZ | Higher fixed cost |

Development defaults to one NAT Gateway because it is a non-production cost decision. Production defaults to one per AZ because outbound availability is more important there. A later optimization can evaluate VPC endpoints for ECR, CloudWatch Logs, Secrets Manager, S3, and other AWS services.

NAT Gateways incur hourly and data-processing charges even when the application is idle. Destroy unused development infrastructure when it is not needed.

## Terraform module boundaries

`terraform/modules/networking` owns only:

- VPC;
- Internet Gateway;
- six subnets;
- NAT Elastic IP address or addresses;
- NAT Gateway or Gateways;
- public, application, and database route tables;
- default routes and subnet associations.

It does not own ALB, ECS, RDS, ECR, security groups, custom network ACLs, DNS records, or VPC endpoints.

The main outputs form contracts for later modules:

```text
public_subnet_ids      -> ALB module
private_app_subnet_ids -> ECS module
private_db_subnet_ids  -> RDS subnet group
vpc_id                 -> security groups and all VPC resources
```

## Validate and plan

After the bootstrap and backend are configured:

```sh
terraform -chdir=terraform/environments/dev init -backend-config=backend.hcl
terraform -chdir=terraform/environments/dev validate
terraform -chdir=terraform/environments/dev plan
```

The module topology itself can be tested without AWS credentials or real resources:

```sh
make network-test
```

Repeat for production only when production deployment is intended. Always inspect the plan, especially NAT count, Availability Zones, CIDRs, routes, and resource names, before applying.

## Expected resource counts

Development should plan approximately:

```text
1 VPC
1 Internet Gateway
6 subnets
1 Elastic IP
1 NAT Gateway
5 route tables
3 explicit default routes
6 route table associations
```

Production should differ by creating two Elastic IPs and two NAT Gateways, with one application default route pointing to each NAT.
