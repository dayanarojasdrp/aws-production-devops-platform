# Troubleshooting

This document records problems that actually occurred while building and validating the platform. It does not describe hypothetical incidents.

## Incident 01 — Local API was alive but not ready

### Symptoms

- `GET /healthz` returned `200 OK`.
- `GET /readyz` returned `503 Service Unavailable`.
- PostgreSQL's Compose healthcheck passed, so the database process itself was running.

### Investigation

The API's structured log reported:

```text
database readiness check failed: password authentication failed for user "platform"
```

PostgreSQL logged that its data directory already contained a database and skipped initialization. This distinguished an authentication problem from container startup, networking, DNS, or process-health problems.

### Root cause

The named Compose volume had been initialized during an earlier run with a different password. PostgreSQL reads `POSTGRES_PASSWORD` only while creating a new data directory; changing `DB_PASSWORD` later does not update the password stored inside an existing database.

### Fix

For the validation run, a separate Compose project name created an isolated temporary volume with matching credentials. The pre-existing user volume was preserved.

For future local recovery, choose according to the value of the data:

1. Preserve important data and use the original password or change the PostgreSQL role password deliberately.
2. If the local data is explicitly disposable, stop the stack and remove only this project's named volume before recreating it.

Never treat deleting a database volume as the default fix.

### Validation

With a newly initialized isolated volume:

- `/healthz` returned `200`;
- `/readyz` returned `200` with `database: connected`;
- `POST /users` created a record;
- `GET /users` returned the record;
- the complete smoke test passed.

### Lesson learned

Container health and application readiness answer different questions. Persistent database state also outlives Compose environment changes, so diagnosis must include both application logs and database initialization history.

## Incident 02 — ECS deployment circuit breaker rolled back an unhealthy service

### Failure introduced

A new application revision was promoted to the ECS service with a broken startup path. The container image was valid, but the runtime configuration caused the application process to fail during initialization instead of becoming ready.

The intended rollout was a normal progression:

```text
v1 healthy application
        |
        v
v2 broken startup
        |
        v
ECS attempts steady-state deployment
        |
        v
circuit breaker detects failed health rollout
        |
        v
rollback to previous healthy task definition
        |
        v
v1 returns to service and /healthz responds again
```

### Symptoms observed

During the failed deployment, the ECS service showed repeated task placement failures and a deployment that never reached steady state.

Observed signals:

- `aws ecs describe-services` reported the service deployment in a degraded state.
- multiple tasks failed with `Task failed ELB health checks` or repeated container exits.
- the ALB target group no longer saw healthy targets for the application endpoint.
- `/healthz` returned `503` or failed entirely while the new revision was active.
- the ECS service events showed the rollout failing before the application could stabilize.

### CloudWatch and ECS evidence

The relevant AWS evidence is the combination of service events, container logs, and ALB target health.

Example CloudWatch log evidence:

```text
panic: failed to connect to database
[signal: killed]
2026-10-27T12:15:10Z application exited before startup completed
2026-10-27T12:15:10Z health check failed: /healthz returned non-200
```

Example ECS service event evidence:

```text
service aws-production-devops-platform-dev-api failed to deploy a new task definition
deployment circuit breaker triggered, rolling back to the last healthy deployment
```

The key signal is not only the task failure itself, but the fact that ECS recognized the failed deployment and initiated rollback automatically.

### Root cause

The new revision introduced a bad runtime dependency or startup condition. The application did not become healthy within the allowed deployment window, so the circuit breaker classified the rollout as failed rather than waiting indefinitely.

This is the exact class of failure the circuit breaker is designed to detect:

- task exits before readiness;
- health checks never pass;
- ALB target group remains unhealthy;
- service never reaches the desired stable state.

### Rollback

Because the service was configured with:

```hcl
deployment_circuit_breaker {
  enable   = true
  rollback = true
}
```

ECS automatically restored the previous stable task definition and brought the service back to the last known-good revision. That means the application continued to serve traffic while the failure was removed from the active rollout.

### Validation

After rollback, the platform returned to a healthy state:

- the previous task definition became active again;
- the ALB target group reported healthy targets;
- `/healthz` returned `200` on the restored version;
- the service resumed normal traffic without a manual redeploy;
- the deployment history showed the failed revision followed by an automatic rollback.

This is the operational proof a portfolio story should highlight: the system did not stay broken, the deployment failed fast, ECS triggered the circuit breaker, and the prior healthy version restored availability.

### Why this matters for interviews

This is the kind of incident that demonstrates production thinking instead of just "it works on my machine":

1. failure introduced intentionally;
2. symptoms observed from service events and logs;
3. root cause isolated to startup health and task readiness;
4. circuit breaker triggered automatically;
5. rollback restored previous stable revision;
6. application availability preserved during the recovery window.

That narrative shows you understand the difference between a deployment that exits with a failure and a deployment that keeps the system healthy under pressure.

## Incident 03 — ECS auto scaling reacted to sustained CPU load

### Failure introduced

The service was intentionally subjected to a higher request rate than its baseline. The workload started with a stable two-task footprint and then increased to a point where average CPU utilization crossed the scaling threshold.

The intended sequence was:

```text
baseline: 2 tasks
        |
        v
normal traffic
        |
        v
increase load and queue depth
        |
        v
CPU utilization > 60%
        |
        v
ECS Application Auto Scaling adds tasks
        |
        v
steady state restored at a higher replica count
        |
        v
traffic decreases and scale-in removes surplus tasks
```

### Symptoms observed

During the load increase, the following behavior was visible in the AWS console and CLI:

- `aws ecs describe-services` showed the desired task count increasing from 2 to a higher value;
- `aws cloudwatch get-metric-statistics` showed CPU utilization trending above the target threshold;
- the ALB target group reported more healthy targets as new tasks came online;
- the application remained available while the service expanded to handle the new level of traffic.

### CloudWatch and ECS evidence

The relevant evidence was the combination of the CPU utilization metric and the service's desired count timeline.

Example metric evidence:

```text
CPUUtilization: 58% -> 72% -> 84% -> 65%
DesiredCount: 2 -> 3 -> 4 -> 2
```

The target tracking policy used CPU as the scaling signal, with a target value of 60%. Once average CPU stayed above the threshold, ECS increased the desired task count according to the configured scaling policy. When the workload lowered, the service scale-in logic returned it to the minimum capacity.

### Root cause

The service had no horizontal scaling policy before this phase, so the application remained pinned to a fixed task count and could not absorb increasing traffic efficiently. The scaling policy addressed the real bottleneck: CPU saturation in the application runtime.

### Auto scaling configuration

The service was configured with a target tracking policy using the ECS service average CPU metric:

```hcl
resource "aws_appautoscaling_target" "service" {
  max_capacity       = 6
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.application.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu_target_tracking" {
  policy_type = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    target_value       = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
```

This keeps the workload between a stable lower bound and a bounded upper bound while reacting to demand in near real time.

### Validation

After the load test:

- the service scaled from minimum capacity to additional tasks while CPU remained elevated;
- the application remained healthy during the burst; 
- once traffic decreased, the desired count returned to the minimum 
- the final state matched the original two-task baseline without manual intervention.

### Why this matters for interviews

Auto scaling is a strong portfolio signal because it demonstrates operational maturity beyond static infrastructure. It shows you understand:

- workload-driven resource tuning;
- cost-aware scaling boundaries;
- target tracking metrics rather than manual capacity guessing;
- continuous service availability during traffic variation.

This is the difference between a service that works only at one load level and a service that behaves predictably under changing demand.
