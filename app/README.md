# Local API

Small Go HTTP API used to prove connectivity between an application and PostgreSQL before introducing AWS infrastructure.

## Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/healthz` | Confirms that the Go process is alive; it does not query PostgreSQL. |
| `GET` | `/readyz` | Pings PostgreSQL and returns `503` when the database is unavailable. |
| `GET` | `/users` | Returns all users stored in PostgreSQL. |
| `POST` | `/users` | Creates a user from a JSON body containing `name` and `email`. |

The API creates the `users` table automatically with `CREATE TABLE IF NOT EXISTS` when PostgreSQL becomes available.

## Environment variables

| Variable | Required | Default | Purpose |
| --- | --- | --- | --- |
| `HTTP_PORT` | No | `8080` | HTTP port inside the container. |
| `DB_HOST` | Yes | — | PostgreSQL hostname; under Compose it is `postgres`. |
| `DB_PORT` | No | `5432` | PostgreSQL port. |
| `DB_NAME` | Yes | — | Database name. |
| `DB_USER` | Yes | — | Database user. |
| `DB_PASSWORD` | Yes | — | Database password. |

## Run locally

From the repository root:

```sh
cp .env.example .env
docker compose up --build
```

In another terminal:

```sh
curl http://localhost:8080/healthz
curl http://localhost:8080/readyz
curl -X POST http://localhost:8080/users \
  -H 'Content-Type: application/json' \
  -d '{"name":"Dayana","email":"dayana@example.com"}'
curl http://localhost:8080/users
```

Stop the database to observe the difference between liveness and readiness:

```sh
docker compose stop postgres
curl -i http://localhost:8080/healthz
curl -i http://localhost:8080/readyz
```

The first request remains `200 OK`; the second becomes `503 Service Unavailable`.
