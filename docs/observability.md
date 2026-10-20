# Observability

## ECS application logs

The API writes structured JSON to stdout and stderr. The ECS `awslogs` driver sends those streams to an environment-specific CloudWatch log group:

```text
/ecs/aws-production-devops-platform-dev/api   -> 7-day retention
/ecs/aws-production-devops-platform-prod/api  -> 30-day retention
```

The execution role can create streams and write events only below its own log group. The application task role does not need CloudWatch permissions because the ECS agent owns log delivery.

Expected startup events include:

```text
database startup check passed
HTTP server started
```

Failures before the HTTP listener starts produce `database startup check failed`; ECS service events and task stopped reasons must be inspected alongside CloudWatch logs.

Container Insights, dashboards, metric filters, and alarms remain part of the dedicated observability phase. Basic log persistence is implemented now because ephemeral task files disappear when Fargate replaces a task.

## ALB target health

The target group continuously evaluates `GET /healthz` and exposes target states and reason codes through `aws elbv2 describe-target-health`. Standard ALB metrics such as request count, response time, HTTP 4xx/5xx, healthy hosts, and unhealthy hosts become available after deployment. Dashboards, alarms, and access-log storage remain deliberately deferred to the observability phase.
