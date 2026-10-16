# Runbook

## ECS service is below desired count

1. Read the cluster, service, and log-group names from Terraform outputs.
2. Run `aws ecs describe-services` and compare desired, running, and pending counts.
3. Read recent service events in the same response.
4. List stopped tasks and inspect `stopCode`, `stoppedReason`, and container reasons.
5. Tail the CloudWatch application log group.
6. Classify the failure stage:
   - image pull: verify the SHA exists and execution-role ECR access;
   - secret injection: verify the secret ARN and execution-role permission;
   - logging initialization: verify log-group existence and permissions;
   - application startup: inspect database startup logs and the ECS-to-RDS path.
7. Confirm the private subnet has a working NAT path to ECR, Secrets Manager, and CloudWatch Logs.
8. Confirm the task ENI uses the ECS security group and RDS still permits that group on `5432`.
9. After correcting the cause, wait for the service to stabilize and record the validation evidence.

Do not solve a startup failure by assigning a public IP, exposing port `8080` to the internet, printing the secret, or granting administrator permissions.
