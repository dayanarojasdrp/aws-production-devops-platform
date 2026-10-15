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
