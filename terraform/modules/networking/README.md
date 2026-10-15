# Networking module

Creates a three-tier VPC across exactly two Availability Zones:

- two public subnets with an Internet Gateway route for a future internet-facing ALB;
- two private application subnets with outbound NAT routes for future ECS tasks;
- two isolated database subnets with no default Internet or NAT route for future RDS instances.

`single_nat_gateway = true` creates one lower-cost shared NAT Gateway. Setting it to `false` creates one NAT Gateway in each AZ and routes each application subnet through its local NAT, avoiding a single-AZ outbound dependency.

The module intentionally does not create security groups, ALB, ECS, RDS, ECR, Network ACL customizations, or VPC endpoints. Those belong to separate modules and phases.

Run `terraform test` from this directory to verify both the single-NAT development topology and the per-AZ production topology using Terraform's mocked AWS provider. The tests do not call AWS or create resources.
