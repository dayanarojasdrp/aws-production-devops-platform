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
