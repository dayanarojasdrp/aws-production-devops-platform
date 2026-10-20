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

## ALB target is unhealthy

1. Read `alb_target_group_arn`, `ecs_cluster_name`, `ecs_service_name`, and `ecs_log_group_name` from Terraform outputs.
2. Run `aws elbv2 describe-target-health` and record the target state, reason, IP, and port.
3. Confirm the target is registered on port `8080` and its task ENI belongs to a private application subnet.
4. Confirm ALB egress and ECS ingress both reference the ALB-to-ECS path on TCP `8080`.
5. Test whether `/healthz` returns exactly HTTP `200`; check application logs for startup or server failures.
6. Inspect ECS service events, stopped reasons, desired/running counts, and the 30-second startup grace period.
7. Check that the target Availability Zone is enabled on the ALB through its public subnet.
8. If every target is unhealthy, treat the service as unavailable even if ALB fail-open behavior still sends requests.
9. Correct the cause, wait for service stability, and confirm target state returns to `healthy` before closing the incident.

Do not register task IPs manually. ECS owns target registration and deregistration for the service.
