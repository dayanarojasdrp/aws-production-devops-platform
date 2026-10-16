# Deployment

## Database provisioning phase

The current Terraform configuration can provision networking, security groups, RDS PostgreSQL, and its Secrets Manager credential. It does not yet deploy the application.

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
- absence of password outputs.

After apply, use the non-sensitive outputs to record the endpoint, port, database name, and secret ARN. Do not print or copy the secret value into documentation.

Production deletion protection intentionally prevents a direct destroy. Removing a production database requires an explicit configuration change, a reviewed apply that disables deletion protection, and a final snapshot. Development can be destroyed without a final snapshot when its data is confirmed disposable.
