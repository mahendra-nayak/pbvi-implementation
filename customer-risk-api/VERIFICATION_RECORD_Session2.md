# VERIFICATION_RECORD.md

**Session:** Session 2 — Database Layer
**Date:** _______________
**Engineer:** _______________

---

## Task 2.1 — Schema creation SQL

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 2

| Case | Scenario | Expected | Result |
|---|---|---|---|
| T1 | Schema file runs without error in psql | Exit 0 | |
| T2 | `risk_tier` CHECK constraint rejects invalid value | `INSERT … risk_tier='CRITICAL'` raises constraint violation | |
| T3 | `api_user` cannot INSERT | `INSERT` as `api_user` raises permission denied | |
| T4 | `api_user` can SELECT | `SELECT` as `api_user` returns rows | |

**Invariants Touched:** INV-03 (Read-Only Database Guarantee), INV-09 (Risk Tier Value Constraint)

### Prediction Statement

```
Verification command:
docker compose down -v && docker compose up postgres -d && sleep 10 && \
docker compose exec postgres psql -U riskuser -d riskdb -c "\d customers"
```

- T1 — [ENGINEER: predicted output]
- T2 — [ENGINEER: predicted output]
- T3 — [ENGINEER: predicted output]
- T4 — [ENGINEER: predicted output]

### CD Challenge Output

```
[ENGINEER: paste Claude Code response to "What did you not test in this task?" here]
```

*For each item identified: accepted (added case) / rejected (reason)*

### Code Review

- [ ] `CHECK (risk_tier IN ('LOW', 'MEDIUM', 'HIGH'))` is present on the `risk_tier` column
- [ ] `REVOKE INSERT, UPDATE, DELETE ON customers FROM api_user` is explicit — not relying solely on SELECT grant
- [ ] `api_user` has no DDL rights (no GRANT CREATE, no GRANT ALL)
- [ ] `GRANT SELECT ON customers TO api_user` is present
- [ ] `GRANT CONNECT ON DATABASE riskdb TO api_user` is present
- [ ] `GRANT USAGE ON SCHEMA public TO api_user` is present
- [ ] `CREATE TABLE IF NOT EXISTS` used (idempotent)
- [ ] `CREATE ROLE IF NOT EXISTS` (or equivalent) — script can run without erroring on re-run

### Scope Decisions

| Item | Decision | Rationale |
|---|---|---|
| | | |

### Verification Verdict

- [ ] All planned cases passed
- [ ] CD challenge reviewed
- [ ] Code review complete (invariant-touching)
- [ ] Scope decisions documented

**Status:**

---

## Task 2.2 — Seed data SQL

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 2

| Case | Scenario | Expected | Result |
|---|---|---|---|
| T1 | At least 3 LOW-tier customers exist | `SELECT COUNT(*) FROM customers WHERE risk_tier='LOW'` ≥ 3 | |
| T2 | At least 3 MEDIUM-tier customers exist | `SELECT COUNT(*) FROM customers WHERE risk_tier='MEDIUM'` ≥ 3 | |
| T3 | At least 3 HIGH-tier customers exist | `SELECT COUNT(*) FROM customers WHERE risk_tier='HIGH'` ≥ 3 | |
| T4 | Running seed twice produces no error | Script is idempotent via ON CONFLICT DO NOTHING | |
| T5 | All risk_factors are non-empty arrays | No NULL or `{}` values in risk_factors column | |

**Invariants Touched:** INV-09 (Risk Tier Value Constraint — seed data must only contain valid tier values)

### Prediction Statement

```
Verification command:
docker compose down -v && docker compose up postgres -d && sleep 10 && \
docker compose exec postgres psql -U riskuser -d riskdb -c \
"SELECT risk_tier, COUNT(*) FROM customers GROUP BY risk_tier ORDER BY risk_tier;"
```

- T1 — [ENGINEER: predicted output]
- T2 — [ENGINEER: predicted output]
- T3 — [ENGINEER: predicted output]
- T4 — [ENGINEER: predicted output]
- T5 — [ENGINEER: predicted output]

### CD Challenge Output

```
[ENGINEER: paste Claude Code response to "What did you not test in this task?" here]
```

*For each item identified: accepted (added case) / rejected (reason)*

### Code Review

- [ ] Every INSERT uses only `LOW`, `MEDIUM`, or `HIGH` for `risk_tier` — no other values
- [ ] `ON CONFLICT DO NOTHING` is present on all INSERT statements
- [ ] No real PII used — all names are fictional
- [ ] All `risk_factors` arrays are non-empty (at least one factor per record)
- [ ] `assessed_at` uses fixed timestamps (not `NOW()`) so seed is deterministic

### Scope Decisions

| Item | Decision | Rationale |
|---|---|---|
| | | |

### Verification Verdict

- [ ] All planned cases passed
- [ ] CD challenge reviewed
- [ ] Code review complete (invariant-touching)
- [ ] Scope decisions documented

**Status:**

---

## Task 2.3 — Read-only database role wired into Compose

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 2

| Case | Scenario | Expected | Result |
|---|---|---|---|
| T1 | `api_user` can connect and SELECT | `psql -U api_user -d riskdb -c "SELECT 1"` exits 0 | |
| T2 | `api_user` cannot INSERT | `psql -U api_user -d riskdb -c "INSERT INTO customers ..."` fails | |
| T3 | `.env.example` updated with new keys | `grep API_DB_USER .env.example` matches | |

**Invariants Touched:** INV-03 (Read-Only Database Guarantee)

### Prediction Statement

```
Verification command:
docker compose down -v && docker compose up postgres -d && sleep 10 && \
docker compose exec postgres psql -U api_user -d riskdb -W -c "SELECT customer_id, risk_tier FROM customers LIMIT 3;"
```
*(Password: apipass123)*

- T1 — [ENGINEER: predicted output]
- T2 — [ENGINEER: predicted output]
- T3 — [ENGINEER: predicted output]

### CD Challenge Output

```
[ENGINEER: paste Claude Code response to "What did you not test in this task?" here]
```

*For each item identified: accepted (added case) / rejected (reason)*

### Code Review

- [ ] API service environment in `docker-compose.yml` uses `API_DB_USER` and `API_DB_PASSWORD` — NOT `POSTGRES_USER` and `POSTGRES_PASSWORD`
- [ ] `api_user` role has no write grants confirmed in schema SQL
- [ ] `.env.example` has been updated with `API_DB_USER` and `API_DB_PASSWORD` keys
- [ ] `.env` has been updated with matching values
- [ ] The password in `01_schema.sql` matches the value in `.env` for `API_DB_PASSWORD`

### Scope Decisions

| Item | Decision | Rationale |
|---|---|---|
| | | |

### Verification Verdict

- [ ] All planned cases passed
- [ ] CD challenge reviewed
- [ ] Code review complete (invariant-touching)
- [ ] Scope decisions documented

**Status:**

---

## Task 2.4 — psycopg2 connection module

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 2

| Case | Scenario | Expected | Result |
|---|---|---|---|
| T1 | Connection succeeds with correct env vars | `SELECT 1` returns result; no exception | |
| T2 | Wrong password → RuntimeError raised | Error message is `"Database connection failed"` — no credential details leaked | |
| T3 | `POSTGRES_HOST` unreachable → RuntimeError raised | Same generic message | |

**Invariants Touched:** INV-06 (Error Surface Control — error message must not leak connection details)

### Prediction Statement

```
Verification command:
docker compose up -d && sleep 15 && \
docker compose exec api python app/test_db_connection.py
```

- T1 — [ENGINEER: predicted output]
- T2 — [ENGINEER: predicted output]
- T3 — [ENGINEER: predicted output]

### CD Challenge Output

```
[ENGINEER: paste Claude Code response to "What did you not test in this task?" here]
```

*For each item identified: accepted (added case) / rejected (reason)*

### Code Review

- [ ] `except psycopg2.OperationalError` used — not bare `except Exception`
- [ ] Raised `RuntimeError` message is a static string — no `str(e)` interpolation
- [ ] No `print(e)` or logging of the raw psycopg2 exception anywhere in `db.py`
- [ ] Module-level comment present noting psycopg2 is synchronous and blocks the asyncio event loop
- [ ] `POSTGRES_HOST` defaults to `"postgres"` (the Compose service name)
- [ ] Connection returned with `autocommit=False`

### Scope Decisions

| Item | Decision | Rationale |
|---|---|---|
| | | |

### Verification Verdict

- [ ] All planned cases passed
- [ ] CD challenge reviewed
- [ ] Code review complete (invariant-touching)
- [ ] Scope decisions documented

**Status:**

---

## Task 2.5 — Customer lookup query function

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 2

| Case | Scenario | Expected | Result |
|---|---|---|---|
| T1 | Known customer ID → correct dict returned | All four fields present; `risk_tier` in {LOW, MEDIUM, HIGH} | |
| T2 | Unknown customer ID → `None` returned | Function returns `None`, no exception | |
| T3 | SQL is parameterised | No f-string or `%` formatting in SQL string | |
| T4 | `risk_factors` is a Python list | `isinstance(result["risk_factors"], list)` is True | |
| T5 | Connection closed after query | No open connection handles after call | |

**Invariants Touched:** INV-01 (Data Passthrough Fidelity), INV-08 (Response Shape Consistency)

### Prediction Statement

```
Verification command:
docker compose up -d && sleep 15 && \
docker compose exec api python app/test_db_connection.py
```

- T1 — [ENGINEER: predicted output]
- T2 — [ENGINEER: predicted output]
- T3 — [ENGINEER: predicted output]
- T4 — [ENGINEER: predicted output]
- T5 — [ENGINEER: predicted output]

### CD Challenge Output

```
[ENGINEER: paste Claude Code response to "What did you not test in this task?" here]
```

*For each item identified: accepted (added case) / rejected (reason)*

### Code Review

- [ ] Only four fields returned in the dict: `customer_id`, `name`, `risk_tier`, `risk_factors` — no `assessed_at` or extras
- [ ] SQL uses `%s` parameterisation — grep for f-string or `.format(` in query string → zero matches
- [ ] Function returns `None` on empty result (not an exception, not an empty dict)
- [ ] Connection is closed in a `finally` block (not just in the success path)
- [ ] `cursor.fetchone()` is used (not `fetchall()`)
- [ ] `risk_tier` value is returned as-is — no `.upper()`, `.lower()`, or transformation applied

### Scope Decisions

| Item | Decision | Rationale |
|---|---|---|
| | | |

### Verification Verdict

- [ ] All planned cases passed
- [ ] CD challenge reviewed
- [ ] Code review complete (invariant-touching)
- [ ] Scope decisions documented

**Status:**

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
- [ ] Session integration check run and result recorded:
  ```
  docker compose down -v && docker compose up -d --build && sleep 20 && \
  docker compose exec api python app/test_db_connection.py
  ```
  Expected: `DB connection OK`, CUST-001 dict with valid tier, `None (expected)` for unknown ID

**Status:** In Progress
**Engineer sign-off:** _______________
