# Verification Record — Session 4: Authentication & Security

**Session:** Session 4  
**Date:**  
**Engineer:**  

---

## Task 4.1 — API key middleware

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 4

| Case | Scenario | Expected | Result |
|------|----------|----------|--------|
| TC-1 | Valid key in `X-API-Key` header → 200 | Customer data returned | |
| TC-2 | Missing key → 401 | `{"detail": "Unauthorized"}` | |
| TC-3 | Wrong key → 401 | Same static body | |
| TC-4 | `/health` without key → 200 | Health endpoint unaffected | |
| TC-5 | 401 body is static | Body identical regardless of what key was sent | |

### Prediction Statement

### CD Challenge Output
[Paste CD's response to: 'What did you not test in this task?'
For each item: accepted (added case) / rejected (reason).]

### Code Review
Invariants touched: INV-04, INV-11
- Confirm `hmac.compare_digest` is used (not `==`)
- Confirm the dependency is applied to the customer route
- Confirm `/health` is not in a dependency group that requires the key
- Confirm the key value is never logged

### Scope Decisions

### Verification Verdict
[ ] All planned cases passed
[ ] CD challenge reviewed
[ ] Code review complete (invariant-touching)
[ ] Scope decisions documented

**Status:**

---

## Task 4.2 — Authentication-before-database-access ordering

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 4

| Case | Scenario | Expected | Result |
|------|----------|----------|--------|
| TC-1 | No key → 401, db not queried | `get_query_count()` returns 0 after unauthenticated request | |
| TC-2 | Valid key → 200, db queried | `get_query_count()` increments to 1 | |
| TC-3 | Wrong key → 401, db not queried | Counter does not increment | |

### Prediction Statement

### CD Challenge Output
[Paste CD's response to: 'What did you not test in this task?'
For each item: accepted (added case) / rejected (reason).]

### Code Review
Invariants touched: INV-11
- Confirm the test imports both `app` (FastAPI instance) and `db` module
- Confirm counter is reset between test cases
- Confirm the dependency ordering in FastAPI resolves `verify_api_key` before the route handler body executes

### Scope Decisions

### Verification Verdict
[ ] All planned cases passed
[ ] CD challenge reviewed
[ ] Code review complete (invariant-touching)
[ ] Scope decisions documented

**Status:**

---

## Task 4.3 — Credential safety — key not in responses or logs

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 4

| Case | Scenario | Expected | Result |
|------|----------|----------|--------|
| TC-1 | 200 response body → no key | Confirmed absent | |
| TC-2 | 401 response body → no key | Confirmed absent | |
| TC-3 | 500 response body → no key | Confirmed absent | |
| TC-4 | /health response → no key | Confirmed absent | |

### Prediction Statement

### CD Challenge Output
[Paste CD's response to: 'What did you not test in this task?'
For each item: accepted (added case) / rejected (reason).]

### Code Review
Invariants touched: INV-05
- Confirm the test uses the actual `API_KEY` env value to search response bodies
- Confirm the test covers all four HTTP status paths
- Confirm there is no `print(api_key)` or `logger.info(...key...)` anywhere in `main.py` or `db.py`

### Scope Decisions

### Verification Verdict
[ ] All planned cases passed
[ ] CD challenge reviewed
[ ] Code review complete (invariant-touching)
[ ] Scope decisions documented

**Status:**

---

## Task 4.4 — Error surface audit

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 4

| Case | Scenario | Expected | Result |
|------|----------|----------|--------|
| TC-1 | 401 body check | Exactly `{"detail": "Unauthorized"}` | |
| TC-2 | 404 body check | Exactly `{"detail": "Customer not found"}` | |
| TC-3 | 500 body check | Exactly `{"detail": "Internal server error"}` | |
| TC-4 | Forbidden strings absent from all error bodies | Zero matches | |

### Prediction Statement

### CD Challenge Output
[Paste CD's response to: 'What did you not test in this task?'
For each item: accepted (added case) / rejected (reason).]

### Code Review
Invariants touched: INV-06
- Confirm forbidden strings list includes all psycopg2 identifiers
- Confirm the global exception handler in `main.py` does not use `str(exc)` or `repr(exc)` in the response
- Confirm FastAPI's default `debug=False` (do not set `app = FastAPI(debug=True)` in production code path)

### Scope Decisions

### Verification Verdict
[ ] All planned cases passed
[ ] CD challenge reviewed
[ ] Code review complete (invariant-touching)
[ ] Scope decisions documented

**Status:**

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
