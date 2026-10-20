# RDS PostgreSQL and database credentials

## Why the database is an RDS workload

ECS tasks are replaceable application processes; PostgreSQL owns persistent state. Running the database as another application container would couple durable data to an ephemeral workload. Amazon RDS provides managed PostgreSQL storage, backups, maintenance, encryption, and Multi-AZ availability options while ECS remains replaceable.

## Private database path

```text
ECS task
   |
   | TCP 5432
   v
RDS security group
   |
   v
RDS PostgreSQL
   |
   +-- private DB subnet A
   `-- private DB subnet B
```

The DB subnet group contains only the isolated database subnets from the networking module. The instance sets `publicly_accessible = false` and attaches only the RDS security group created in the security phase. Consequently, database access requires both private VPC routing and an allowed ECS security-group identity.

```text
Internet -X-> RDS
ALB      -X-> RDS
ECS SG    -> RDS SG :5432
```

## Credential flow

Terraform generates a 32-character password and creates a Secrets Manager secret containing this JSON shape:

```json
{
  "username": "appuser",
  "password": "generated-value"
}
```

The real value is never committed, placed in a tfvars file, built into the image, or exposed as a Terraform output. `password_wo` and `secret_string_wo` are write-only arguments, which prevents the RDS instance and secret-version resources from persisting duplicate plaintext values.

The `random_password` resource must retain its generated value in Terraform state so later plans remain stable. Therefore, the private, encrypted, access-controlled remote state from the bootstrap phase is part of the credential security boundary. Marking a value sensitive only hides normal CLI rendering; it does not by itself remove a value from state.

Credential rotation is deliberate:

```text
increment database_credentials_version
              |
              v
new random password
       |             |
       v             v
RDS password    Secret version
```

This project does not enable an independent automatic rotation schedule yet. ECS injects secret environment variables only when a task starts, so a future rotation procedure must update the password and force a fresh ECS deployment as one coordinated operation.

AWS documents that [RDS-managed master credentials rotate every seven days by default](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-secrets-manager.html) and that [an ECS container does not receive an updated secret automatically](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/secrets-envvar-secrets-manager.html). Controlled rotation avoids introducing those lifecycle requirements before the ECS deployment workflow exists.

## Application integration

The Go code does not call Secrets Manager directly. Its runtime contract stays environment-based:

```text
Local: Docker Compose -> DB_HOST / DB_USER / DB_PASSWORD
AWS:   ECS task definition + Secrets Manager -> same variables
```

The ECS task definition receives the non-secret endpoint, port, and database name as normal environment variables. It references JSON keys in `credentials_secret_arn` for the username and password. The ECS execution role receives `secretsmanager:GetSecretValue` only for that ARN.

The current credential is the RDS master credential used to bootstrap this small application and create its table. A separate least-privilege PostgreSQL application role is a valid future hardening step when versioned migrations or a dedicated database bootstrap job exists.

## Encryption

- `storage_encrypted = true` protects database storage and snapshots at rest using the AWS-managed RDS key by default.
- The AWS task definition sets `DB_SSLMODE` to `require`, enabling encrypted PostgreSQL transport to RDS.
- Full server identity verification with `verify-full` requires distributing the RDS CA bundle to the application image and remains a later hardening step.

## Development and production design

| Setting | Development | Production design | Reason |
| --- | --- | --- | --- |
| Instance class | `db.t4g.micro` | `db.t4g.small` | Lower dev cost; more production capacity |
| Initial storage | 20 GiB gp3 | 50 GiB gp3 | Environment-appropriate baseline |
| Storage autoscaling limit | 50 GiB | 200 GiB | Prevent unbounded configuration while allowing growth |
| Multi-AZ | No | Yes | Cost versus failover availability |
| Backup retention | 1 day | 7 days | More production recovery history |
| Deletion protection | No | Yes | Additional production deletion barrier |
| Final snapshot | Skipped | Required | Fast dev cleanup versus production recovery |
| Automated backups on deletion | Deleted | Preserved | Cost versus recovery |
| Secret deletion recovery | Immediate | 30 days | Fast dev cleanup versus accidental-deletion recovery |

Production is represented as code but does not need to remain deployed while developing the portfolio.

## Terraform contracts

`terraform/modules/rds` consumes:

```text
private_db_subnet_ids  <- networking module
rds_security_group_id <- security module
```

It exports only non-password connection metadata:

```text
database_endpoint
database_port
database_name
credentials_secret_arn
```

## Validation

Run the mocked module tests without creating AWS resources:

```sh
make rds-test
```

The tests prove that RDS is private and encrypted, uses only the database security group and private subnet group, and applies different lifecycle controls to dev and prod. Runtime database connectivity and backup/failover evidence must wait until the resources are intentionally deployed in AWS.
