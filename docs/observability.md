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

The HTTPS edge also needs later operational coverage for TLS negotiation errors, certificate renewal events, and DNS availability. ACM managed renewal reduces manual work but does not remove the need to alert when renewal eligibility or validation fails.

## Phase 16 — CloudWatch observability

This phase proves that the platform is not just deployed, but observable. A healthy system is one whose runtime behavior can be reasoned about during normal traffic, incident conditions, and deployment changes.

### What we monitor

The platform must surface both application health and platform health. The main signals are:

- application logs from the ECS task stream;
- ECS metrics for CPU, memory, task count, and deployment state;
- ALB metrics for request volume, target health, latency, 4xx, and 5xx;
- RDS metrics for CPU, connection count, free storage, I/O, and database errors.

### CloudWatch alarms to create

These should be created in the target AWS account with descriptive names such as:

```text
aws-production-devops-platform-dev-ecs-high-cpu
aws-production-devops-platform-dev-ecs-high-memory
aws-production-devops-platform-dev-alb-5xx
aws-production-devops-platform-dev-unhealthy-targets
aws-production-devops-platform-dev-rds-high-cpu
aws-production-devops-platform-dev-deployment-failed
```

Suggested alarm logic:

- High CPU: average CPU utilization above 75% for 5 minutes.
- High memory: average memory utilization above 80% for 5 minutes.
- ALB 5xx: HTTP 5xx count above 1 or a sustained threshold for 5 minutes.
- Unhealthy targets: target health check failures or an unhealthy target count greater than 0.
- Database problems: RDS CPU above 80% or free storage below threshold.
- Deployment failure: ECS service events or deployment health transitions to failed or rollback-triggered.

Alarm severity should be aligned to operational impact: warning for rising saturation, critical for service degradation or failed rollout.

### Dashboard concept

The dashboard should summarize the application and platform at a glance. A simple mockup is:

```text
┌─────────────────────────────────────────────┐
│ AWS DevOps Platform                         │
├─────────────────────────────────────────────┤
│ Requests        CPU                          │
│ ████████        ██████                       │
│                                             │
│ Memory          ECS Tasks                   │
│ █████           2                           │
│                                             │
│ ALB 5xx         Latency                     │
│ 0               42 ms                       │
└─────────────────────────────────────────────┘
```

This gives a fast operational picture without forcing an operator to dig across multiple consoles.

### Example dashboard widgets

Create widgets for:

- ECS service CPU utilization
- ECS service memory utilization
- ECS desired/running task count
- ALB request count by target group
- ALB latency p95/p99
- ALB HTTP 4xx and 5xx counts
- target health status by target group
- RDS CPU utilization
- RDS free storage
- application log stream search for `ERROR`, `panic`, and startup failures

### How to validate in AWS

When the AWS account is available, open the following console paths:

```text
CloudWatch
  -> Dashboards
  -> Create dashboard
  -> add widgets
  -> ECS, ALB, RDS metrics
  -> save dashboard
```

For alarms:

```text
CloudWatch
  -> Alarms
  -> Create alarm
  -> choose metric
  -> define threshold and evaluation period
  -> alert actions / SNS topic / email if configured
```

For logs:

```text
CloudWatch
  -> Logs Insights
  -> log group /ecs/<environment>/api
  -> query: fields @timestamp, @message
  -> filter @message like /ERROR|panic|failed|unhealthy/
```

For ECS and ALB metrics:

```text
CloudWatch
  -> Metrics
  -> ECS > ClusterName > ServiceName
  -> ALB > LoadBalancerName > TargetGroup
```

### Evidence to capture for portfolio

Capture screenshots of:

- the CloudWatch dashboard with CPU, memory, task count, and request widgets;
- at least one alarm in alarm state or configured state;
- a CloudWatch Logs Insights query showing an application log or error pattern;
- the ALB target health and request metrics panel;
- the RDS metrics panel proving database health is also monitored.

These screenshots tell a strong operational story: the platform is not only deployed, but measurable, diagnosable, and protected by alerting.

### Where to capture the screenshot right now

Without an AWS account, the capture must wait until the account is active. Once it is available, the easiest place is:

```text
AWS Console -> CloudWatch -> Dashboards -> <your dashboard name>
```

A second good capture is:

```text
AWS Console -> CloudWatch -> Alarms -> <alarm name>
```

This is the best place to show both a visual summary and active operational alerting in GitHub or portfolio screenshots.

### Why this matters for interviews

This phase demonstrates operational maturity. It shows you understand that production systems are not just deployed—they are monitored, alerted, and diagnosable. A strong candidate can connect the metrics to the runtime stack and explain what each signal means before reacting.

## Phase 17 — Operational alerts

This is the operations phase after the platform is deployed and monitored. The goal is not only to know that the service exists, but to detect failure automatically and route actionable information to the right owners before the blast radius grows.

### Event-driven alerting path

When an ECS deployment fails, the system should emit a cloud event and fan that signal into an operational notification flow:

```text
ECS deployment failure
      |
      v
EventBridge rule
      |
      v
SNS topic
      |
      v
email / chat / incident notification
```

The relevant AWS event is the ECS deployment failure signal, especially `SERVICE_DEPLOYMENT_FAILED` when the deployment circuit breaker is enabled. This is valuable because it catches the operational condition at the service level, not only in a dashboard or a user report.

### Why this matters

A deployment that stays healthy until the final two minutes is still a deployment problem, not just a build problem. Operating teams need a signal at the moment the service transitions into a failed state so they can:

- confirm the failed revision;
- inspect ECS events;
- read CloudWatch logs;
- decide whether rollback is already in progress;
- escalate if the service remains unhealthy.

### EventBridge rule design

The alarm route should filter on ECS service events such as:

```text
detail-type: ECS Deployment Event
source: aws.ecs
detail:
  eventName: SERVICE_DEPLOYMENT_FAILED
```

The rule then publishes to an SNS topic:

```text
EventBridge -> SNS -> email / Slack / PagerDuty / incident channel
```

This creates a clear flow from infrastructure event to human notification without relying on someone to manually check the console.

### Operational evidence

A good evidence package for this phase includes:

- an ECS event showing the failing deployment;
- the EventBridge rule matching the service event;
- the SNS subscription delivery path;
- confirmation that the alert is triggered by the same condition that caused rollback.

This demonstrates real operations discipline: not only deployment automation, but automated detection and response.

### Interview narrative

This phase proves you understand the difference between shipping code and operating a system. Successful candidates can explain how a runtime failure is translated into a signal, routed to the right audience, and used to reduce MTTR without relying on manual polling.
