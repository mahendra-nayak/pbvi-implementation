# Verification Record — Session 4: Authentication & Security

**Session:** Session 4  
**Date:**  19-03-2026
**Engineer:**  Mahendra Nayak

---

## Task 4.1 — API key middleware

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 4

| Case | Scenario | Expected | Result |
|------|----------|----------|--------|
| TC-1 | Valid key in `X-API-Key` header → 200 | Customer data returned | PASS|
| TC-2 | Missing key → 401 | `{"detail": "Unauthorized"}` | PASS|
| TC-3 | Wrong key → 401 | Same static body |PASS |
| TC-4 | `/health` without key → 200 | Health endpoint unaffected |PASS |
| TC-5 | 401 body is static | Body identical regardless of what key was sent | PASS|

### Prediction Statement

### CD Challenge Output
 1. hmac.compare_digest is actually used — confirmed by code review but not by an observable test. A timing attack is
  not demonstrable functionally; this is code-review-only.
  2. Received API key value is not logged — we didn't inspect docker compose logs api after a valid or invalid request
  to confirm the key value never appears in output.
  3. /api/customer/CUST-NONEXISTENT with valid key → 404 — we only tested CUST-001 (200) with a valid key. The 404 path
  was not re-verified after auth was added.
  4. DB error path (500) still works with valid key — the 500 path was not re-verified after auth was added.
  5. X-API-Key header name is case-insensitive — HTTP headers are case-insensitive by spec; we only sent X-API-Key
  exactly. A client sending x-api-key was not tested.
  6. Empty string key "" → 401 — an empty header value is distinct from a missing header; hmac.compare_digest("",
  expected) would return False but this was not explicitly tested.


For each item: accepted (added case) / rejected (reason).

| Item | Decision | Rationale |
|------|----------|-----------|
| hmac.compare_digest usage | REJECTED | Not observable via black-box; confirmed via code review |
| API key not logged | ACCEPTED | Verify via logs after valid/invalid requests |
| Nonexistent customer with valid key returns 404 | ACCEPTED | Regression check after auth added |
| DB error 500 path with valid key | REJECTED | 500 occurs after auth; unaffected if 200 works |
| lowercase x-api-key header | REJECTED | Handled by FastAPI header normalization |
| Empty string key returns 401 | ACCEPTED | Distinct from missing key; worth validating |

### Code Review
Invariants touched: INV-04, INV-11
- Confirm `hmac.compare_digest` is used (not `==`)
- Confirm the dependency is applied to the customer route
- Confirm `/health` is not in a dependency group that requires the key
- Confirm the key value is never logged

### Scope Decisions
No scope decisions for this task — implementation matched the spec exactly.
### Verification Verdict
[Yes] All planned cases passed
[Yes] CD challenge reviewed
[Yes] Code review complete (invariant-touching)
[Yes] Scope decisions documented

**Status:**
Completed
---

## Task 4.2 — Authentication-before-database-access ordering

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 4

| Case | Scenario | Expected | Result |
|------|----------|----------|--------|
| TC-1 | No key → 401, db not queried | `get_query_count()` returns 0 after unauthenticated request |PASS |
| TC-2 | Valid key → 200, db queried | `get_query_count()` increments to 1 |PASS |
| TC-3 | Wrong key → 401, db not queried | Counter does not increment |PASS |

### Prediction Statement

### CD Challenge Output

  1. get_query_count() resets between test runs — the counter is module-level and never resets. If tests run in sequence
   in the same process, the counter accumulates. The valid-key test relied on starting from 0, which was true only
  because it ran in a fresh process.
  2. Auth check fires before DB connection attempt — we confirmed get_customer_by_id was not called (counter didn't
  increment), but get_connection() itself has no counter. If auth ran after connection but before query, the counter
  would still be 0. The ordering test doesn't distinguish "auth before DB touch" from "auth before query but after
  connection".
  3. /health with valid key still returns 200 — not re-verified after the auth dependency and counter were added.
  4. Counter increments exactly once per valid request, not multiple times — the valid-key test confirmed count went
  from 0 to 1, but if get_customer_by_id were called twice per request the counter would go to 2. This wasn't explicitly
   asserted (after == before + 1 does cover it, so this is actually tested — reject this).
  5. Test script handles the lifespan correctly — TestClient triggers the lifespan on context entry. The startup DB
  probe runs, which means a real DB connection is needed. This was implicitly satisfied because postgres was running,
  but the test would fail if run without postgres.

| Item | Decision | Rationale |
|------|----------|-----------|
| Counter accumulates across test runs | REJECTED | Uses relative increment check, not absolute value |
| Auth fires before DB connection | REJECTED | No function call means no DB connection attempted |
| /health with valid key returns 200 | REJECTED | No auth or DB dependency; unaffected |
| Counter increments once per request | REJECTED | Already covered by before + 1 assertion |
| TestClient requires real DB | ACCEPTED | Depends on Postgres; fails unclearly without it |

### Code Review
Invariants touched: INV-11
- Confirm the test imports both `app` (FastAPI instance) and `db` module
- Confirm counter is reset between test cases
- Confirm the dependency ordering in FastAPI resolves `verify_api_key` before the route handler body executes

### Scope Decisions

### Verification Verdict
[Yes] All planned cases passed
[Yes] CD challenge reviewed
[Yes] Code review complete (invariant-touching)
[Yes] Scope decisions documented

**Status:**
Completed
---

## Task 4.3 — Credential safety — key not in responses or logs

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 4

| Case | Scenario | Expected | Result |
|------|----------|----------|--------|
| TC-1 | 200 response body → no key | Confirmed absent |PASS |
| TC-2 | 401 response body → no key | Confirmed absent |PASS|
| TC-3 | 500 response body → no key | Confirmed absent |PASS |
| TC-4 | /health response → no key | Confirmed absent |PASS |

### Prediction Statement
 - T1 — 200 body contains no API key value
  - T2 — 401 body does not echo the received key
  - T3 — 500 body contains no credential values
  - T4 — /health body contains no credential values

### CD Challenge Output
1. Response headers checked for key leakage — only response bodies were checked. The API key could theoretically
  appear in a response header (e.g. a misconfigured echo header) but headers were not inspected.
  2. "api_key" and "Authorization" strings checked in all paths — the assert_no_credentials_leaked function checks all
  four forbidden strings, but the individual inline tests only checked API_KEY and wrong_key. The full forbidden string
  set was not exercised via docker compose exec for each path.
  3. T4 /health body check not run — the health endpoint credential safety test was written in the script but not
  explicitly run in this session.
  4. Mock correctly intercepted the right import path — patch("app.main.get_customer_by_id") patches the name as
  imported in main.py. If the import path were wrong, the mock would silently fail and the real function would run. This
   was not verified separately.
  5. Response body checked against the actual key value, not a placeholder — the test uses os.environ["API_KEY"] which
  resolves to dev-test-key-12345. If the env var were unset or different, the assertion would pass vacuously. Not
  explicitly verified

| Item | Decision | Rationale |
|------|----------|-----------|
| Response headers checked for key leakage | REJECTED | Headers handled by framework; no key written in response |
| Full forbidden string set not checked inline | REJECTED | Covered in test_credential_safety.py |
| /health body check not run | ACCEPTED | Execute now as pending check |
| Mock intercept path correct | REJECTED | Correct patch path; failure would break T3 |
| Assertion uses real key value | REJECTED | Env var resolved at runtime; startup fails if missing |

### Code Review
Invariants touched: INV-05
- Confirm the test uses the actual `API_KEY` env value to search response bodies
- Confirm the test covers all four HTTP status paths
- Confirm there is no `print(api_key)` or `logger.info(...key...)` anywhere in `main.py` or `db.py`

### Scope Decisions
 No scope decisions for this task — implementation matched the spec exactly.
### Verification Verdict
[Yes] All planned cases passed
[Yes] CD challenge reviewed
[Yes] Code review complete (invariant-touching)
[Yes] Scope decisions documented

**Status:**
Completed
---

## Task 4.4 — Error surface audit

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 4

| Case | Scenario | Expected | Result |
|------|----------|----------|--------|
| TC-1 | 401 body check | Exactly `{"detail": "Unauthorized"}` |PASS |
| TC-2 | 404 body check | Exactly `{"detail": "Customer not found"}` |PASS |
| TC-3 | 500 body check | Exactly `{"detail": "Internal server error"}` |PASS |
| TC-4 | Forbidden strings absent from all error bodies | Zero matches |PASS |

### Prediction Statement

  - T1 (401) — Body will be exactly {"detail":"Unauthorized"}. No forbidden strings present — the response is built from
   a static HTTPException with no interpolation.
  - T2 (404) — Body will be exactly {"detail":"Customer not found"}. No SQL keywords or customer_id — the 404 response
  is a static string constant, never constructed from query input.
  - T3 (500) — Body will be exactly {"detail":"Internal server error"}. No stack trace or module names — the 500
  response is built from _INTERNAL_ERROR constant, and the RuntimeError is caught before it reaches any serialisation
  path.
### CD Challenge Output
 1. 200 happy path checked against forbidden strings — only error paths (401, 404, 500) were tested. A valid request
  returning 200 was not checked against the forbidden strings list.
  2. /health response checked against forbidden strings — the health endpoint was not included in test_error_surface.py
  (it was in test_credential_safety.py but not here).
  3. Forbidden headers check on 200 response — assert_clean_error checks headers, but it was only called on error
  responses. The 200 path header check was not run.
  4. "db error" string from the mocked RuntimeError does not appear in 500 body — the mock raises RuntimeError("db
  error"); we confirmed "db error" is not in the body by inspection but it's not in FORBIDDEN_IN_BODY and was not
  explicitly asserted.
  5. Forbidden strings list is complete — the list covers known leakage vectors but not exhaustively. For example,
  "riskdb" (the database name), "172.18" (internal Docker IP), or "api_user" (the DB role name) could also appear in a
  misconfigured error but are not in FORBIDDEN_IN_BODY.
  6. Content-Type header checked on 200 and 404 live responses — assert_clean_error checks Content-Type but only via
  TestClient. A live curl against the running container did not verify Content-Type: application/json on any response.

For each item: accepted (added case) / rejected (reason).

| Item | Decision | Rationale |
|------|----------|-----------|
| 200 path checked against forbidden strings | REJECTED | Response fields from DB cannot contain forbidden strings |
| /health checked against forbidden strings | REJECTED | Static {"status":"ok"} response |
| Forbidden headers on 200 response | REJECTED | Headers managed globally by framework |
| "db error" from mock in 500 body | REJECTED | Replaced by constant error response |
| FORBIDDEN_IN_BODY list incomplete | ACCEPTED (PARTIAL) | Add "riskdb" and "api_user" for safety |
| Content-Type via curl check | REJECTED | Same ASGI stack; redundant |

### Code Review
Invariants touched: INV-06
- Confirm forbidden strings list includes all psycopg2 identifiers
- Confirm the global exception handler in `main.py` does not use `str(exc)` or `repr(exc)` in the response
- Confirm FastAPI's default `debug=False` (do not set `app = FastAPI(debug=True)` in production code path)

### Scope Decisions
No scope decisions for this task — implementation matched the spec exactly.
### Verification Verdict
[Yes] All planned cases passed
[Yes] CD challenge reviewed
[Yes] Code review complete (invariant-touching)
[Yes] Scope decisions documented

**Status:**
Completed
---

## Task 4.5 — UI route exempt from auth

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 4

| Case | Scenario | Expected | Result |
|------|----------|----------|--------|
| TC-1 | `GET /` no key → 200 | HTML response | |
| TC-2 | `GET /` no key → HTML content-type | `text/html` in Content-Type | |
| TC-3 | UI body does not leak key | API_KEY value absent from HTML | |

### Prediction Statement

### CD Challenge Output
[Paste CD's response to: 'What did you not test in this task?'
For each item: accepted (added case) / rejected (reason).]

### Code Review
Invariants touched: INV-04, INV-05
- Confirm there is no auth dependency on the `/` route
- Confirm the HTML does not include the `API_KEY` value

### Scope Decisions

### Verification Verdict
[ ] All planned cases passed
[ ] CD challenge reviewed
[ ] Code review complete (invariant-touching)
[ ] Scope decisions documented

**Status:**

---

## Task 4.6 — Compose network isolation (no external calls)

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 4

| Case | Scenario | Expected | Result |
|------|----------|----------|--------|
| TC-1 | Stack starts with internal network | `docker compose up -d` exits 0 | |
| TC-2 | `GET /health` still reachable from host | `curl localhost:8000/health` returns 200 | |
| TC-3 | Container cannot reach external host | `docker compose exec api curl -s --max-time 3 https://example.com` fails/times out | |
| TC-4 | API can reach postgres | Customer lookup still works | |

### Prediction Statement

### CD Challenge Output
[Paste CD's response to: 'What did you not test in this task?'
For each item: accepted (added case) / rejected (reason).]

### Code Review
Invariants touched: INV-07
- Confirm `internal: true` is on the network definition
- Confirm both services are on `risk_net`
- Confirm no service has an additional non-internal network attached

### Scope Decisions

### Verification Verdict
[ ] All planned cases passed
[ ] CD challenge reviewed
[ ] Code review complete (invariant-touching)
[ ] Scope decisions documented

**Status:**
