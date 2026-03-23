# customer-risk-api

A Docker Compose application that exposes a REST API for assessing customer risk scores. It consists of a PostgreSQL database for persistent storage and a Python API service that processes customer data and returns risk assessments. Copy `.env.example` to `.env` and fill in the required values before running `docker compose up`.

## Prerequisites

- Docker and Docker Compose installed
- Tested on Docker 24+

## Setup

1. Copy `.env.example` to `.env` and fill in values:
   ```bash
   cp .env.example .env
   ```
2. Start the stack:
   ```bash
   docker compose up -d --build
   ```
3. Wait for the health check to pass:
   ```bash
   curl http://localhost:8000/health
   ```
4. Open the UI: http://localhost:8000

## Environment variables

| Variable | Description | Example |
|---|---|---|
| `POSTGRES_USER` | Superuser for the PostgreSQL instance | `riskuser` |
| `POSTGRES_PASSWORD` | Password for the PostgreSQL superuser | `riskpass` |
| `POSTGRES_DB` | Database name | `riskdb` |
| `API_KEY` | Shared secret required in the `X-API-Key` header | `dev-test-key-12345` |
| `API_DB_USER` | Read-only application role used by the API | `api_user` |
| `API_DB_PASSWORD` | Password for the read-only application role | `apipass123` |

## Resetting the database

```bash
docker compose down -v && docker compose up -d
```

## Known limitations

- Single shared API key — no per-user audit trail
- Synchronous `psycopg2` in async FastAPI — low-concurrency use only
- API key visible in browser page source
- No TLS

## Running verification

```bash
bash scripts/smoke_test.sh
bash scripts/verify_invariants.sh
```
