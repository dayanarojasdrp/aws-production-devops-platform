# Application Load Balancer and ECS traffic routing

## Responsibility boundary

The Application Load Balancer and ECS solve different problems:

```text
ALB -> decides which healthy task receives each request
ECS -> decides how many tasks must exist and replaces failed tasks
```

Users never connect to a task IP. They connect to the stable ALB endpoint while ECS tasks can be created, replaced, or moved between private subnets without changing the public entry point.

## Request path

```text
Internet
   |
   | HTTP :80 (temporary until the HTTPS phase)
   v
internet-facing ALB
   |  public subnet A + public subnet B
   |
   | listener -> target group
   v
healthy task IPs :8080
   |  private application subnet A + private application subnet B
   v
Go API
```

The ALB spans both public subnets and carries the ALB security group. Fargate tasks remain in private application subnets without public IPs and carry the ECS security group. The security chain is:

```text
0.0.0.0/0 -- TCP 80 --> ALB SG -- TCP 8080 --> ECS SG
```

Port `443` is already permitted at the ALB security group for the following DNS/HTTPS phase, but no TLS listener is fabricated before an ACM certificate exists.

## ALB, listener, and target group

These resources are related but not interchangeable:

- The **ALB** is the stable public Layer 7 endpoint.
- The **listener** accepts a protocol and port and chooses an action.
- The **target group** contains the destinations, health policy, and connection-draining behavior.

The current listener accepts HTTP on port `80` and forwards to the API target group. The next phase will add an HTTPS listener on `443` and replace HTTP forwarding with a redirect to HTTPS.

There is no separate path-based listener rule yet because this ALB serves one backend and the listener's default forward action is sufficient. Explicit priority rules become useful only when routing several hosts or paths to different target groups.

## Why the target type is `ip`

Fargate requires `awsvpc` networking. Every task receives an elastic network interface and a private IP address, so the target group registers task IPs rather than EC2 instance IDs:

```text
target_type = "ip"

10.0.11.x:8080
10.0.12.x:8080
```

Terraform does not register those addresses individually. The ECS service connects container `api` and port `8080` to the target group; ECS then registers new task IPs and deregisters stopped task IPs automatically.

## Health policy

The target group sends:

```text
GET /healthz -> expected HTTP 200
```

Configured behavior:

| Setting | Value | Purpose |
| --- | ---: | --- |
| Interval | 30 seconds | Time between independent checks |
| Timeout | 5 seconds | Maximum wait for one response |
| Healthy threshold | 2 | Consecutive successes to restore an unhealthy target |
| Unhealthy threshold | 2 | Consecutive failures to remove a target from normal routing |
| Matcher | `200` | Exact successful liveness response |
| ECS grace period | 30 seconds | Ignores early ALB failures while a task starts |

`/healthz` is deliberately lightweight and independent of PostgreSQL. It asks whether the process and HTTP server are alive. `/readyz` checks the current database connection and remains the stronger operational validation.

This avoids removing every application task during a temporary database incident, but it has a trade-off: a task can remain in ALB rotation while database-dependent endpoints return errors. `/readyz`, application error metrics, and RDS alarms will cover that dependency state in later observability work.

AWS Application Load Balancers fail open if every registered target is unhealthy: in that exceptional state, traffic can be sent to all targets. Multiple healthy replicas, ECS replacement, alarms, and rollback are therefore still necessary; health checks alone are not a complete availability strategy.

## Connection draining

The target group uses a 30-second deregistration delay:

```text
target begins draining
        |
        +-- no new normal traffic
        +-- existing requests get time to finish
        v
target is deregistered
```

Thirty seconds is appropriate for this API because its HTTP request timeouts are much shorter. The value remains configurable and should be revisited if long-running endpoints are introduced.

## Security hardening completed in this phase

ALB egress is no longer `0.0.0.0/0`. It is restricted by security-group reference to the ECS security group on TCP `8080`, covering both application requests and health checks.

The result is:

```text
Internet ------> ALB :80
Internet --X--> ECS :8080
ALB -----------> ECS :8080
ALB -------X---> any unrelated destination
```

ECS egress remains broader because tasks currently need RDS plus ECR, Secrets Manager, CloudWatch Logs, and other AWS API access through NAT.

## Environment design

| Setting | Development | Production design |
| --- | ---: | ---: |
| ALB subnets | 2 public AZ subnets | 2 public AZ subnets |
| ECS subnets | 2 private app subnets | 2 private app subnets |
| Desired tasks | 1 | 2 |
| ALB deletion protection | Disabled | Enabled |
| Deregistration delay | 30 seconds | 30 seconds |
| Health path | `/healthz` | `/healthz` |

One development task validates routing and replacement but does not demonstrate uninterrupted service during a task stop. Availability evidence requires two running tasks, either in the production design or by temporarily and deliberately setting development `ecs_desired_count = 2`.

## Deployment dependency

The ECS module explicitly depends on the ALB module. This ensures the ALB, target group, and listener exist before the service tries to register task IPs. The referenced Git SHA must already exist in ECR, as described in [`ecs-fargate.md`](ecs-fargate.md).

## Runtime validation

After a reviewed development apply:

```sh
ALB_DNS="$(terraform -chdir=terraform/environments/dev output -raw alb_dns_name)"
TARGET_GROUP_ARN="$(terraform -chdir=terraform/environments/dev output -raw alb_target_group_arn)"

aws elbv2 describe-target-health \
  --target-group-arn "$TARGET_GROUP_ARN" \
  --query 'TargetHealthDescriptions[].{ip:Target.Id,port:Target.Port,state:TargetHealth.State,reason:TargetHealth.Reason}'

curl --fail --show-error --silent "http://${ALB_DNS}/healthz"
curl --fail --show-error --silent "http://${ALB_DNS}/readyz"
BASE_URL="http://${ALB_DNS}" ./scripts/smoke-test.sh
```

Required evidence:

1. The ALB uses both public subnets.
2. The target group type is `ip` and its port is `8080`.
3. Desired/running ECS counts match.
4. Every expected task IP is registered and healthy.
5. `GET /healthz` through the ALB returns HTTP `200`.
6. `GET /readyz` proves the routed API can reach PostgreSQL.
7. No ECS task has a public IP.

## Controlled failure exercise

Run this only with at least two healthy targets. Keep a request loop active from another terminal:

```sh
ALB_DNS="$(terraform -chdir=terraform/environments/dev output -raw alb_dns_name)"

while true; do
  curl --silent --output /dev/null \
    --write-out '%{http_code}\n' \
    "http://${ALB_DNS}/healthz"
  sleep 1
done
```

Then record and stop exactly one task:

```sh
CLUSTER="$(terraform -chdir=terraform/environments/dev output -raw ecs_cluster_name)"
SERVICE="$(terraform -chdir=terraform/environments/dev output -raw ecs_service_name)"
TARGET_GROUP_ARN="$(terraform -chdir=terraform/environments/dev output -raw alb_target_group_arn)"

OLD_TASK="$(aws ecs list-tasks \
  --cluster "$CLUSTER" \
  --service-name "$SERVICE" \
  --query 'taskArns[0]' \
  --output text)"

aws ecs stop-task \
  --cluster "$CLUSTER" \
  --task "$OLD_TASK" \
  --reason "Phase 10 ALB failure-routing exercise"

aws ecs wait services-stable --cluster "$CLUSTER" --services "$SERVICE"
aws elbv2 describe-target-health --target-group-arn "$TARGET_GROUP_ARN"
```

Expected sequence:

```text
Task 1 healthy + Task 2 healthy
              |
Task 1 draining/stopped; Task 2 keeps serving
              |
ECS launches Task 3
              |
Task 2 healthy + Task 3 healthy
```

Capture the old and replacement task ARNs, target-health transitions, ECS service events, and continuous HTTP responses. Do not claim zero downtime unless the request-loop evidence actually demonstrates it.

## Deliberately deferred controls

- ACM certificate, HTTPS listener, and HTTP-to-HTTPS redirect: next phase.
- Route 53 alias and custom domain: next phase.
- Deployment circuit breaker and rollback: rollback phase.
- Auto Scaling: scaling phase.
- ALB metrics, alarms, dashboard, and access logs: observability phase.
- WAF: optional security hardening after the core platform is complete.

## References

- [Use an Application Load Balancer for Amazon ECS](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/alb.html)
- [ECS load balancer configuration](https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_LoadBalancer.html)
- [Application Load Balancer target health checks](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html)
- [Register and deregister ALB targets](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-register-targets.html)
