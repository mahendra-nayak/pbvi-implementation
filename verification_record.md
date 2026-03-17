# VERIFICATION_RECORD.md

**Session:** Session 1 — Project Scaffold & Environment
**Date:** _______________
**Engineer:** _______________

---

## Task 1.1 — Repository structure and `.env` template

### Test Cases Applied

| Case | Scenario | Expected | Result |
|---|---|---|---|
| T1 | `.env` is present in `.gitignore` | `git check-ignore .env` exits 0 | |
| T2 | `.env.example` contains all four required keys | `grep` finds `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `API_KEY` | |
| T3 | `docker-compose.yml` references `env_file: .env` or uses `${VAR}` syntax | `grep env_file docker-compose.yml` matches | |
| T4 | All directories exist | `ls db/init api/app ui/` exits 0 | |

**Invariant Touch:** INV-12 (partial — `.env` not committed, template present)

### Prediction Statement

```
Verification command:
git check-ignore .env && \
grep -q POSTGRES_USER .env.example && \
grep -q POSTGRES_PASSWORD .env.example && \
grep -q POSTGRES_DB .env.example && \
grep -q API_KEY .env.example && \
ls db/init api/app ui/index.html
```

- T1 — [ENGINEER: predicted output]
- T2 — [ENGINEER: predicted output]
- T3 — [ENGINEER: predicted output]
- T4 — [ENGINEER: predicted output]

### CD Challenge Output

```
[ENGINEER: paste Claude Code output here after running task prompt]
```

**Prompt used to challenge implementation:**
> Review the output of Task 1.1 against INV-12. Does the `.env.example` contain any real secrets or hardcoded credential values that would violate INV-12? Does the `.gitignore` cover `.env` at the root level specifically, or only via a pattern that could miss it?

### Code Review

- [ ] `.env` is in `.gitignore` at the root level (not only via glob pattern)
- [ ] `.env.example` uses placeholder values only (e.g. `API_KEY=changeme`) — no real secrets
- [ ] All four required keys present in `.env.example`: `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `API_KEY`
- [ ] `docker-compose.yml` declares `env_file: .env` or uses `${VAR}` syntax
- [ ] All required directories created: `db/init/`, `api/app/`, `ui/`

**Notes:**

---

## Task 1.2 — Postgres service with healthcheck

### Test Cases Applied

| Case | Scenario | Expected | Result |
|---|---|---|---|
| T1 | `docker compose up postgres -d` starts without error | Exit 0 | |
| T2 | Postgres passes healthcheck within 30s | `docker compose ps` shows `(healthy)` | |
| T3 | Named volume `pgdata` is created | `docker volume ls` lists `*_pgdata` | |
| T4 | `.env` is not tracked by git | `git status` does not list `.env` | |

**Invariant Touch:** INV-10 (postgres must come up automatically)

### Prediction Statement

```
Verification command:
docker compose up postgres -d && \
sleep 15 && \
docker compose ps postgres | grep healthy
```

- T1 — [ENGINEER: predicted output]
- T2 — [ENGINEER: predicted output]
- T3 — [ENGINEER: predicted output]
- T4 — [ENGINEER: predicted output]

### CD Challenge Output

```
[ENGINEER: paste Claude Code output here after running task prompt]
```

**Prompt used to challenge implementation:**
> Review the Postgres service definition in `docker-compose.yml` against INV-10. Is `restart: unless-stopped` present? Is the volume named (not anonymous)? Does the healthcheck use `pg_isready` with the correct `${POSTGRES_USER}` and `${POSTGRES_DB}` interpolation? Would the service reliably reach `(healthy)` state on a cold start with no pre-existing volume?

### Code Review

- [ ] `image: postgres:16-alpine` specified
- [ ] Environment variables loaded from `.env` (not hardcoded)
- [ ] Named volume `pgdata` declared and mounted at `/var/lib/postgresql/data`
- [ ] Healthcheck uses `pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}` with interval/timeout/retries set
- [ ] `restart: unless-stopped` present on postgres service
- [ ] Volume declaration present at bottom of compose file

**Notes:**

---

## Task 1.3 — FastAPI application skeleton

### Test Cases Applied

| Case | Scenario | Expected | Result |
|---|---|---|---|
| T1 | `docker compose build api` succeeds | Exit 0, no error output | |
| T2 | `docker compose up -d` starts both services | Both show in `docker compose ps` | |
| T3 | `GET /health` returns 200 | `curl -s http://localhost:8000/health` → `{"status":"ok"}` | |
| T4 | API waits for postgres healthy before starting | `docker compose logs api` shows no crash-restart loop | |

**Invariant Touch:** INV-10

### Prediction Statement

```
Verification command:
docker compose up -d && \
sleep 20 && \
curl -sf http://localhost:8000/health | grep -q '"status"'
```

- T1 — [ENGINEER: predicted output]
- T2 — [ENGINEER: predicted output]
- T3 — [ENGINEER: predicted output]
- T4 — [ENGINEER: predicted output]

### CD Challenge Output

```
[ENGINEER: paste Claude Code output here after running task prompt]
```

**Prompt used to challenge implementation:**
> Review `docker-compose.yml` and `api/app/main.py` against INV-10. Does `depends_on` use `condition: service_healthy` (not just the service name)? Is `restart: unless-stopped` on the API service? Does the Dockerfile copy `app/` correctly so `uvicorn app.main:app` resolves without import errors?

### Code Review

- [ ] `api/Dockerfile` present with `python:3.11-slim` base
- [ ] `requirements.txt` pins: `fastapi==0.111.0`, `uvicorn[standard]==0.29.0`, `psycopg2-binary==2.9.9`, `python-dotenv==1.0.0`
- [ ] `api/app/__init__.py` present (empty)
- [ ] `main.py` defines `app = FastAPI()` with no `debug=True`
- [ ] `GET /health` returns `{"status": "ok"}`
- [ ] `depends_on` uses `condition: service_healthy` (not just service name)
- [ ] `restart: unless-stopped` on API service
- [ ] Port `8000:8000` mapped

**Notes:**

---

## Task 1.4 — Environment variable validation at startup

### Test Cases Applied

| Case | Scenario | Expected | Result |
|---|---|---|---|
| T1 | All env vars present → app starts | `GET /health` returns 200 | |
| T2 | `API_KEY` unset → app refuses to start | Process exits non-zero; stderr contains "API_KEY" | |
| T3 | `POSTGRES_DB` set to empty string → app refuses to start | Process exits non-zero; stderr contains "POSTGRES_DB" | |
| T4 | Error message names the missing variable | Output includes variable name, not a generic "config error" | |

**Invariant Touch:** INV-12

### Prediction Statement

```
Verification command:
docker compose up -d && sleep 10 && curl -sf http://localhost:8000/health && \
docker compose run --rm -e API_KEY="" api python -c "import app.main" 2>&1 | grep -q "API_KEY"
```

- T1 — [ENGINEER: predicted output]
- T2 — [ENGINEER: predicted output]
- T3 — [ENGINEER: predicted output]
- T4 — [ENGINEER: predicted output]

### CD Challenge Output

```
[ENGINEER: paste Claude Code output here after running task prompt]
```

**Prompt used to challenge implementation:**
> Review `api/app/main.py` against INV-12. Are there any `os.environ.get("VAR", "default")` patterns anywhere in the file — including for variables other than `API_KEY`? Does the validation run before any route handler or other application logic is registered? Does the error message name the specific missing variable, or is it a generic message?

### Code Review

- [ ] Validation checks all four required vars: `API_KEY`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`
- [ ] Uses `os.environ.get()` — no `load_dotenv()` call in production path
- [ ] No hardcoded fallback values anywhere: grep for `os.environ.get("API_KEY",` → zero matches
- [ ] No hardcoded fallback values anywhere: grep for `os.getenv("API_KEY",` → zero matches
- [ ] Error message names the specific variable (not generic)
- [ ] Validation runs before any other startup logic
- [ ] Empty string treated as missing (not just `None` check)

**Notes:**

---

## Task 1.5 — Compose smoke test script

### Test Cases Applied

| Case | Scenario | Expected | Result |
|---|---|---|---|
| T1 | Clean start → health endpoint ready within 60s | Script prints `SMOKE TEST PASSED`, exits 0 | |
| T2 | Postgres not yet healthy when API starts → script still passes | Script does not exit early | |
| T3 | Script is executable | `ls -l scripts/smoke_test.sh` shows `x` bit | |

*(No invariant touch — utility script)*

### Prediction Statement

```
Verification command:
bash scripts/smoke_test.sh
```

- T1 — [ENGINEER: predicted output]
- T2 — [ENGINEER: predicted output]
- T3 — [ENGINEER: predicted output]

### CD Challenge Output

```
[ENGINEER: paste Claude Code output here after running task prompt]
```

**Prompt used to challenge implementation:**
> Review `scripts/smoke_test.sh`. Does it run `docker compose down -v` before `up` to guarantee a clean state? Does it poll with a timeout (not just a fixed sleep)? Would it correctly detect a case where the health endpoint returns a non-200 status during warm-up but eventually reaches 200? Does it exit non-zero on timeout?

### Code Review

- [ ] Script runs `docker compose down -v` before `up`
- [ ] Script polls `/health` (not just sleeps)
- [ ] Timeout of 60s with 3s poll interval
- [ ] Prints `SMOKE TEST PASSED` on success
- [ ] Prints `SMOKE TEST FAILED: health endpoint not ready` and exits 1 on timeout
- [ ] No external dependencies beyond `bash`, `curl`, `docker`
- [ ] Script is executable (`chmod +x` applied)

**Notes:**

---

## Test Cases Added During Session

| Task | Case ID | Scenario | Expected | Result | Reason Added |
|---|---|---|---|---|---|
| | | | | | |

---

## Scope Decisions

*Record any prompt instructions or implementation outputs that appeared to expand scope beyond the files listed in Claude.md. For each, record whether it was rejected, flagged, or accepted with rationale.*

| Task | Scope Item Observed | Decision | Rationale |
|---|---|---|---|
| | | | |

---

## Verification Verdict

- [ ] All test cases in this record have a Result entry (PASS or FAIL — no blanks)
- [ ] All FAIL results have a corresponding Deviation entry in SESSION_LOG.md
- [ ] All invariant-touching tasks have been reviewed against their named invariants
- [ ] Session integration check (`bash scripts/smoke_test.sh`) has been run and result recorded

**Status:** In Progress
**Engineer sign-off:** _______________
