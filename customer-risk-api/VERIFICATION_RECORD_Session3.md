# VERIFICATION_RECORD.md

**Session:** Session 3 — API Core Endpoints
**Date:** 18-03-2026
**Engineer:** Mahendra Nayak

---

## Task 3.1 — Customer lookup route (happy path)

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 3

| Case | Scenario | Expected | Result |
|---|---|---|---|
| T1 | `GET /api/customer/CUST-001` → 200 | Body contains exactly three keys: `customer_id`, `risk_tier`, `risk_factors` |PASS |
| T2 | `risk_tier` value matches database | Value is `LOW`, `MEDIUM`, or `HIGH` — not transformed | PASS|
| T3 | `risk_factors` is a JSON array | Body field is `[]` syntax, not a string |PASS |
| T4 | Response has no extra fields | No `name`, `assessed_at`, or other fields in body |PASS |

**Invariants Touched:** INV-01 (Data Passthrough Fidelity), INV-08 (Response Shape Consistency)

### Prediction Statement

```
Verification command:
docker compose up -d && sleep 15 && \
curl -s http://localhost:8000/api/customer/CUST-001 | python3 -m json.tool
```

- T1 — [ENGINEER: 200(Body contains exactly three keys: `customer_id`, `risk_tier`, `risk_factors`)]
- T2 — [ENGINEER:  `risk_tier`  Value is `LOW`, `MEDIUM`, or `HIGH` ]
- T3 — [ENGINEER: Body field is `[]` syntax]
- T4 — [ENGINEER: No `name`, `assessed_at`, or other fields in body ]

### CD Challenge Output

```
 1. Unknown customer ID → 404 — we only tested the happy path. GET /api/customer/CUST-NONEXISTENT was not called; the
  current code would return a TypeError or 500 since get_customer_by_id returns None and the route tries to subscript
  it.
  2. "name" is absent from the response — the three required fields were present but we never asserted that name or
  assessed_at are not in the body.
  3. HTTP status code is exactly 200 — curl -s returned the body but we didn't inspect the status code (e.g. curl -s -o
  /dev/null -w "%{http_code}").
  4. customer_id casing is preserved from the database — we only tested CUST-001 which is uppercase in both the path and
   the database. A mixed-case stored ID was not tested to confirm the response uses the DB value, not the path
  parameter.
  5. risk_tier is not transformed — only a LOW record was tested. MEDIUM and HIGH records were not requested to confirm
  no normalisation is applied.
  6. risk_factors order is preserved — the array order returned by the database was not verified to be stable across
  calls.
```

*For each item identified: accepted (added case) / rejected (reason)*

### Code Review

- [Yes] Response dict is constructed explicitly with only the three keys: `customer_id`, `risk_tier`, `risk_factors`
- [Yes] `risk_tier` is assigned from `result["risk_tier"]` — no `.upper()`, `.lower()`, or any string transformation applied
- [Yes] `customer_id` in the response comes from `result["customer_id"]` (the db result), not from the path parameter directly
- [Yes] No `name` or `assessed_at` field is included anywhere in the response dict
- [Yes] Route is declared `async def` — not `def`

### Scope Decisions

No scope decisions for this task — implementation matched the spec exactly.

### Verification Verdict

- [Yes] All planned cases passed
- [Yes] CD challenge reviewed
- [Yes] Code review complete (invariant-touching)
- [Yes] Scope decisions documented

**Status:**
Completed
---

## Task 3.2 — 404 handling (customer not found)

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 3

| Case | Scenario | Expected | Result |
|---|---|---|---|
| T1 | Known ID → 200 | Unchanged from Task 3.1 | |
| T2 | Unknown ID `CUST-NONEXISTENT` → 404 | Status 404; body `{"detail": "Customer not found"}` | |
| T3 | Error body does not echo customer_id | Body does not contain the customer_id value | |
| T4 | Error body is static | Same body for any unknown ID | |

**Invariants Touched:** INV-02 (Existence Mapping Integrity), INV-06 (Error Surface Control)

### Prediction Statement

```
Verification command:
curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/api/customer/CUST-NONEXISTENT && \
curl -s http://localhost:8000/api/customer/CUST-NONEXISTENT | grep -q '"Customer not found"'
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

- [ ] 404 branch is `if result is None` — not a caught exception
- [ ] The `detail` string is hardcoded as `"Customer not found"` — no f-string or variable interpolation
- [ ] The customer_id path value is NOT included anywhere in the 404 response body
- [ ] No DB error can fall through to this branch (a raised RuntimeError goes to the 500 path, not here)
- [ ] `HTTPException(status_code=404, ...)` is used (not a manual JSONResponse with wrong status)

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

## Task 3.3 — 500 handling (database errors)

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 3

| Case | Scenario | Expected | Result |
|---|---|---|---|
| T1 | DB layer raises RuntimeError → 500 | Status 500; body `{"detail": "Internal server error"}` | |
| T2 | 500 body contains no stack trace | Response body has no `Traceback`, `psycopg2`, file path | |
| T3 | 500 body contains no SQL | No `SELECT`, `FROM`, `WHERE` in response body | |
| T4 | 404 still works after this change | Unknown ID still returns 404, not 500 | |

**Invariants Touched:** INV-02 (Existence Mapping Integrity), INV-06 (Error Surface Control)

### Prediction Statement

```
Verification command:
# Simulate DB error: temporarily stop postgres
docker compose stop postgres && sleep 3 && \
curl -s http://localhost:8000/api/customer/CUST-001 | python3 -m json.tool && \
docker compose start postgres
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

- [ ] `except RuntimeError` handler uses a static string `"Internal server error"` — no `str(e)` or `repr(e)` interpolation
- [ ] Global exception handler (`@app.exception_handler(Exception)`) is present and also returns the static string
- [ ] No `raise` in any exception handler that re-raises with detail attached
- [ ] No `print(e)` or `logging.error(str(e))` — raw exception text is not written to stdout/stderr
- [ ] Both the route-level handler and the global handler return identical static bodies

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

## Task 3.4 — Response shape enforcement

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 3

| Case | Scenario | Expected | Result |
|---|---|---|---|
| T1 | Successful response matches schema | `risk_tier` is one of the three literals (`LOW`, `MEDIUM`, `HIGH`) | |
| T2 | `risk_factors` type is correct | Always a list, never a string or null | |
| T3 | Response has no extra fields | Pydantic strips anything beyond the three declared fields | |

**Invariants Touched:** INV-08 (Response Shape Consistency), INV-09 (Risk Tier Value Constraint)

### Prediction Statement

```
Verification command:
curl -s http://localhost:8000/api/customer/CUST-001 | \
python3 -c "import json,sys; d=json.load(sys.stdin); assert set(d.keys())=={'customer_id','risk_tier','risk_factors'}, 'Extra fields found'; print('Shape OK')"
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

- [ ] `models.py` exists at `api/app/models.py` and is committed
- [ ] `risk_tier` field uses `Literal["LOW", "MEDIUM", "HIGH"]` — not `str`
- [ ] `response_model=CustomerRiskResponse` is on the `@app.get(...)` decorator
- [ ] `risk_factors` is typed as `list[str]` — not `list` or `Any`
- [ ] `CustomerRiskResponse` is imported from `models.py` — not defined inline in `main.py`
- [ ] Error paths (404, 500) are not affected by the response model (they bypass it correctly)

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

## Task 3.5 — Tier value guard

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 3

| Case | Scenario | Expected | Result |
|---|---|---|---|
| T1 | Normal tier values → 200 | Unchanged | |
| T2 | If DB returned `CRITICAL` (manually injected) → 500 | Returns 500, not a response with invalid tier | |
| T3 | VALID_TIERS is in constants.py, not inline | `grep VALID_TIERS api/app/main.py` → import reference only | |

**Invariants Touched:** INV-09 (Risk Tier Value Constraint)

### Prediction Statement

```
Verification command:
# Inject a bad tier directly into DB to test the guard
docker compose exec postgres psql -U riskuser -d riskdb -c \
"UPDATE customers SET risk_tier='CRITICAL' WHERE customer_id='CUST-001';" && \
curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/api/customer/CUST-001 && \
docker compose exec postgres psql -U riskuser -d riskdb -c \
"UPDATE customers SET risk_tier='HIGH' WHERE customer_id='CUST-001';"
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

- [ ] Guard raises `RuntimeError` — not `HTTPException`, not a custom 4xx
- [ ] `VALID_TIERS` is defined in `api/app/constants.py` — not inline in `main.py`
- [ ] `main.py` imports `VALID_TIERS` from `constants` — grep for inline `{"LOW", "MEDIUM", "HIGH"}` in `main.py` → zero matches
- [ ] Guard runs AFTER the None check (not-found case) and BEFORE the response is constructed
- [ ] `constants.py` is in source control

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

## Task 3.6 — Startup readiness and database availability

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 3

| Case | Scenario | Expected | Result |
|---|---|---|---|
| T1 | DB up → API starts, `/health` returns 200 | Normal start; `"Database connection verified."` in logs | |
| T2 | DB down at API startup → API crashes immediately | `docker compose logs api` shows FATAL message; container exits non-zero | |
| T3 | DB comes up before API (depends_on healthy) → normal | Compose waits; API starts clean | |

**Invariants Touched:** INV-10 (Startup Completeness)

### Prediction Statement

```
Verification command:
docker compose down -v && docker compose up -d --build && sleep 20 && \
curl -sf http://localhost:8000/health | grep '"status"'
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

- [ ] `sys.exit(1)` is called on DB probe failure — not just a `print` or `log`
- [ ] The probe runs inside the lifespan startup block — after env validation, before any request is served
- [ ] The probe connection is closed in a `finally` block (closed regardless of success or failure)
- [ ] The FATAL message does NOT include raw exception text or connection string details
- [ ] `"Database connection verified."` is printed on success (confirms probe ran)
- [ ] The probe uses `db.get_connection()` + `cursor.execute("SELECT 1")` — not a ping or custom check

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

## Session Integration Check

```bash
bash scripts/smoke_test.sh && \
curl -s http://localhost:8000/api/customer/CUST-001 | python3 -m json.tool && \
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8000/api/customer/CUST-999
```

Expected: `SMOKE TEST PASSED`, valid JSON with exactly three fields (`customer_id`, `risk_tier`, `risk_factors`), `404`

## Verification Verdict

- [ ] All test cases in this record have a Result entry (PASS or FAIL — no blanks)
- [ ] All FAIL results have a corresponding Deviation entry in SESSION_LOG.md
- [ ] All invariant-touching tasks have been reviewed against their named invariants
- [ ] Session integration check run and result recorded above

**Status:** In Progress
**Engineer sign-off:** _______________
