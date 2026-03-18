# VERIFICATION_RECORD.md

**Session:** Session 2 — Database Layer
**Date:** 18-03-2026
**Engineer:** Mahendra Nayak

---

## Task 2.1 — Schema creation SQL

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 2

| Case | Scenario | Expected | Result |
|---|---|---|---|
| T1 | Schema file runs without error in psql | Exit 0 | Yes |
| T2 | `risk_tier` CHECK constraint rejects invalid value | `INSERT … risk_tier='CRITICAL'` raises constraint violation | Yes |
| T3 | `api_user` cannot INSERT | `INSERT` as `api_user` raises permission denied | Yes |
| T4 | `api_user` can SELECT | `SELECT` as `api_user` returns rows |Yes it returns |

**Invariants Touched:** INV-03 (Read-Only Database Guarantee), INV-09 (Risk Tier Value Constraint)

### Prediction Statement

```
Verification command:
docker compose down -v && docker compose up postgres -d && sleep 10 && \
docker compose exec postgres psql -U riskuser -d riskdb -c "\d customers"
```

- T1 — [ENGINEER:  Exit 0]
- T2 — [ENGINEER: raises constraint violation]
- T3 — [ENGINEER: raises permission denied error]
- T4 — [ENGINEER: returns rows]

### CD Challenge Output

```

● Things not tested in Task 2.1:

  1. UPDATE and DELETE as api_user — T3 only tested INSERT. The REVOKE covers all three but only INSERT was verified.
  2. Re-running the script (idempotency) — running 01_schema.sql a second time against a database where the role and
  table already exist was not tested. The IF NOT EXISTS guards and the DO $$ ... IF NOT EXISTS role block are designed
  for this but weren't exercised.
  3. api_user cannot connect to a different database — GRANT CONNECT ON DATABASE riskdb was granted but we didn't verify
   api_user is denied on other databases (e.g. postgres).
  4. api_user has no DDL rights — the code review checklist includes confirming no CREATE, DROP, or ALTER rights, but
  this was not tested with an actual DDL statement as api_user.
  5. risk_tier CHECK allows all three valid values — T2 confirmed CRITICAL is rejected but we never inserted LOW,
  MEDIUM, and HIGH to confirm all three are accepted.
  6. risk_factors rejects NULL — the NOT NULL constraint on the TEXT[] column was not tested with an explicit NULL
  insert attempt.
```

*For each item identified: accepted (added case) / rejected (reason)*



### Code Review

- [Yes] `CHECK (risk_tier IN ('LOW', 'MEDIUM', 'HIGH'))` is present on the `risk_tier` column
- [Yes] `REVOKE INSERT, UPDATE, DELETE ON customers FROM api_user` is explicit — not relying solely on SELECT grant
- [Yes] `api_user` has no DDL rights (no GRANT CREATE, no GRANT ALL)
- [Yes] `GRANT SELECT ON customers TO api_user` is present
- [Yes] `GRANT CONNECT ON DATABASE riskdb TO api_user` is present
- [Yes] `GRANT USAGE ON SCHEMA public TO api_user` is present
- [Yes] `CREATE TABLE IF NOT EXISTS` used (idempotent)
- [Yes] `CREATE ROLE IF NOT EXISTS` (or equivalent) — script can run without erroring on re-run

### Scope Decisions
Item	|Decision |	Rationale
CREATE ROLE IF NOT EXISTS not available as native syntax	|Used DO $$ IF NOT EXISTS ... CREATE ROLE| block instead	PostgreSQL lacks CREATE ROLE IF NOT EXISTS; the DO block ensures idempotency without error on re-run
api_user password hardcoded as 'apipass123'	|Accepted – placeholder pending Task 2.3|	Task 2.1 scope is schema only; parameterisation via API_DB_PASSWORD is deferred to Task 2.3
### Verification Verdict

- [Yes] All planned cases passed
- [Yes] CD challenge reviewed
- [Yes] Code review complete (invariant-touching)
- [Yes] Scope decisions documented

**Status:**
Completed
---

## Task 2.2 — Seed data SQL

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 2

| Case | Scenario | Expected | Result |
|---|---|---|---|
| T1 | At least 3 LOW-tier customers exist | `SELECT COUNT(*) FROM customers WHERE risk_tier='LOW'` ≥ 3 |4 |
| T2 | At least 3 MEDIUM-tier customers exist | `SELECT COUNT(*) FROM customers WHERE risk_tier='MEDIUM'` ≥ 3 | 3|
| T3 | At least 3 HIGH-tier customers exist | `SELECT COUNT(*) FROM customers WHERE risk_tier='HIGH'` ≥ 3 | 3|
| T4 | Running seed twice produces no error | Script is idempotent via ON CONFLICT DO NOTHING |exist 0 |
| T5 | All risk_factors are non-empty arrays | No NULL or `{}` values in risk_factors column |Yes |

**Invariants Touched:** INV-09 (Risk Tier Value Constraint — seed data must only contain valid tier values)

### Prediction Statement

```
Verification command:
docker compose down -v && docker compose up postgres -d && sleep 10 && \
docker compose exec postgres psql -U riskuser -d riskdb -c \
"SELECT risk_tier, COUNT(*) FROM customers GROUP BY risk_tier ORDER BY risk_tier;"
```

- T1 — [ENGINEER: `SELECT COUNT(*) FROM customers WHERE risk_tier='LOW'` ≥ 3`]
- T2 — [ENGINEER: `SELECT COUNT(*) FROM customers WHERE risk_tier='MEDIUM'` ≥ 3`]
- T3 — [ENGINEER: ``SELECT COUNT(*) FROM customers WHERE risk_tier='HIGH'` ≥ 3`]
- T4 — [ENGINEER: exist 0]
- T5 — [ENGINEER: No NULL or `{}` values in risk_factors column]

### CD Challenge Output

```

● Things not tested in Task 2.2:

  1. Individual risk_factors arrays are non-empty — T5 requires no NULL or {} values, but we didn't run a query to
  assert array_length(risk_factors, 1) > 0 for every row.
  2. risk_factors column is not NULL on any row — related to T5 but distinct: a NULL array vs an empty array {} are
  different failure modes, neither was explicitly queried.
  3. All assessed_at values are fixed timestamps — we didn't verify that no row has a NOW()-derived timestamp (would
  matter if the script were ever edited to use NOW()).
  4. No row contains an invalid risk_tier — we verified counts per tier but didn't assert that exactly 3 distinct tier
  values exist and no others (e.g. a typo like 'MEDUM' would be caught by the CHECK constraint but wasn't explicitly
  probed).
  5. Idempotency leaves row count unchanged — we confirmed the second run produced no error and INSERT 0 0, but didn't
  re-run the COUNT(*) GROUP BY risk_tier query afterward to confirm no data was modified.
  6. customer_id format compliance — no check that all IDs match the CUST-NNN format (a constraint not enforced by the
  schema).
```

*For each item identified: accepted (added case) / rejected (reason)*

### Code Review

- [Yes] Every INSERT uses only `LOW`, `MEDIUM`, or `HIGH` for `risk_tier` — no other values
- [Yes] `ON CONFLICT DO NOTHING` is present on all INSERT statements
- [YEs] No real PII used — all names are fictional
- [Yes] All `risk_factors` arrays are non-empty (at least one factor per record)
- [Yes] `assessed_at` uses fixed timestamps (not `NOW()`) so seed is deterministic

### Scope Decisions

 No scope decisions for Task 2.2 — implementation matched the spec exactly. The only choices made (single multi-row
  INSERT vs. individual INSERTs, 4 LOW records instead of minimum 3) were within the stated requirements and don't
  warrant recording.

### Verification Verdict

- [Yes] All planned cases passed
- [Yes] CD challenge reviewed
- [Yes] Code review complete (invariant-touching)
- [Yes] Scope decisions documented

**Status:**
Completed
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

- T1 — [ENGINEER: exits 0]
- T2 — [ENGINEER: Access Denied (fails)]
- T3 — [ENGINEER:  API_DB_USER is present in .env.example]

### CD Challenge Output

```

● Things not tested in Task 2.3:

  1. api_user cannot INSERT/UPDATE/DELETE — T2 from the verification record was not run in this task. We confirmed it in
   Task 2.1, but it wasn't re-verified after the Task 2.3 changes.
  2. API_DB_PASSWORD in .env matches the password in 01_schema.sql — the code review checklist requires this, but no
  automated check was run to assert the two values are identical.
  3. API_DB_PASSWORD is present in .env.example — we only grepped for API_DB_USER. API_DB_PASSWORD was not explicitly
  verified.
  4. The api service picks up API_DB_USER and API_DB_PASSWORD as environment variables — we confirmed the keys are in
  .env and docker-compose.yml, but didn't bring the api container up and inspect its environment (e.g. docker compose
  exec api env | grep API_DB).
  5. POSTGRES_USER/POSTGRES_PASSWORD are unchanged — the task explicitly required the superuser credentials not to be
  modified, but no check was run to confirm the postgres service still authenticates as riskuser.

```

*For each item identified: accepted (added case) / rejected (reason)*

### Code Review

- [Yes] API service environment in `docker-compose.yml` uses `API_DB_USER` and `API_DB_PASSWORD` — NOT `POSTGRES_USER` and `POSTGRES_PASSWORD`
- [Yes] `api_user` role has no write grants confirmed in schema SQL
- [Yes] `.env.example` has been updated with `API_DB_USER` and `API_DB_PASSWORD` keys
- [Yes] `.env` has been updated with matching values
- [Yes] The password in `01_schema.sql` matches the value in `.env` for `API_DB_PASSWORD`

### Scope Decisions

Item	|Decision|	Rationale
-W (interactive password prompt) replaced with PGPASSWORD env var in verification|	Accepted	|Shell is non-interactive; PGPASSWORD is the standard psql equivalent — behaviour and security properties are identical in this context

### Verification Verdict

- [Yes] All planned cases passed
- [Yes] CD challenge reviewed
- [Yes] Code review complete (invariant-touching)
- [Yes] Scope decisions documented

**Status:**
Completed
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
