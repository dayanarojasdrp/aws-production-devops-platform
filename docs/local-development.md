# Local application phase

This phase proves one path end to end before adding AWS: an HTTP request reaches a Go process, the process talks to PostgreSQL, and the response returns as JSON.

## Runtime flow

```text
client on the host
       |
       | HTTP :8080
       v
Docker Compose: api service
       |
       | PostgreSQL protocol, postgres:5432
       v
Docker Compose: postgres service
       |
       v
named volume: postgres_data
```

`postgres` is a Compose service name and therefore an internal DNS name. From the API container, `localhost` would refer to the API container itself, not to the database container.

## Why the application is divided this way

### `app/cmd/api/main.go`

This is the executable entry point. It loads configuration, creates the database pool and HTTP handler, starts the server, and performs a graceful shutdown when Docker sends `SIGTERM`. Business and SQL details do not belong here because this file is responsible only for assembling and controlling the process.

### `app/internal/config/config.go`

This package reads runtime configuration from environment variables. It rejects missing database values and creates a PostgreSQL URL safely. Keeping configuration outside the source code avoids committed passwords and lets the same binary receive different values later from ECS, RDS, and Secrets Manager.

### `app/internal/database/postgres.go`

This package owns the PostgreSQL connection pool and every SQL operation. It:

- limits and recycles connections through `pgxpool`;
- pings PostgreSQL for readiness;
- creates the `users` table idempotently;
- inserts users with parameterized SQL (`$1`, `$2`);
- lists users in a stable order;
- translates PostgreSQL unique-constraint error `23505` into a domain error.

The pool is created without requiring PostgreSQL to be immediately reachable. Therefore, a short database delay does not kill the Go process; subsequent readiness checks and requests can reconnect through the pool.

### `app/internal/models/user.go`

This is the shared representation of a user. JSON tags define the public response names, while database tags map query columns when `pgx` builds structs from rows.

### `app/internal/handlers/handlers.go`

This is the HTTP boundary. It registers the four routes, validates request JSON, chooses HTTP status codes, calls the database package, and serializes responses. Database errors are logged internally without leaking implementation details or credentials to clients.

### `app/internal/handlers/middleware.go`

This contains behavior shared by several endpoints: request logging and bounded request contexts. Timeouts prevent a database failure from leaving HTTP requests waiting forever.

### `app/Dockerfile`

The builder stage contains the Go compiler and produces one statically linked binary. The runtime stage is a minimal, non-root Distroless image containing only what is needed to execute that binary. This reduces image size, dependencies, and attack surface.

### `docker-compose.yml`

Compose defines the local system rather than only one container. It creates the API, PostgreSQL, their private network, the persistent volume, environment variables, port mappings, and PostgreSQL healthcheck. `depends_on: condition: service_healthy` prevents Compose from starting the API before PostgreSQL passes `pg_isready`.

### `.env.example`

This documents safe local variable names without committing the real `.env`. Copy it to `.env` and change values as needed. `.gitignore` deliberately excludes `.env` but permits `.env.example`.

### `scripts/smoke-test.sh`

This script exercises liveness, readiness, insertion, and retrieval against a running stack. It creates a unique email on every run so repeated smoke tests do not collide with the database uniqueness rule.

### `scripts/validate.sh` and `Makefile`

The validation script checks Terraform formatting, Compose syntax, Go formatting, and Go compilation/tests in a Go container. The Makefile gives short, memorable entry points: `make up`, `make down`, `make logs`, `make validate`, and `make smoke-test`.

## Liveness versus readiness

`GET /healthz` does not touch PostgreSQL. A `200` means the Go process can answer HTTP.

`GET /readyz` performs a real database ping and ensures the table exists. A `200` means the application can serve database-backed work. A `503` means the process remains alive but should temporarily receive no production traffic.

This distinction maps directly to future container-orchestrator health checks: liveness answers whether to restart a process; readiness answers whether to send traffic to it.

## Table lifecycle

For this deliberately small infrastructure demonstration, the application runs `CREATE TABLE IF NOT EXISTS` before database-backed operations. A larger product should use versioned migrations, but adding a migration framework here would obscure the infrastructure lesson without adding meaningful value.

## Useful commands

```sh
cp .env.example .env
make up
make smoke-test
make logs
make down
```

If ports `8080` or `5432` are busy, override only the host ports:

```sh
API_PORT=18080 POSTGRES_PORT=15432 docker compose up --build -d
BASE_URL=http://localhost:18080 make smoke-test
```
