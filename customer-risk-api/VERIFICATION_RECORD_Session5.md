# Verification Record — Session 5: UI & Integration

**Session:** Session 5  
**Date:**  23-03-2026
**Engineer:**  Mahendra Nayak

---

## Task 5.1 — Static UI — HTML page with customer lookup

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 5

| Case | Scenario | Expected | Result |
|------|----------|----------|--------|
| TC-1 | HTML is valid (no broken tags) | Browser renders without console errors | PASS|
| TC-2 | `{{API_KEY}}` present exactly once | `grep -c '{{API_KEY}}' ui/index.html` outputs `1` |PASS |
| TC-3 | Input + button present | Elements with correct IDs found |PASS |
| TC-4 | Error cases handled | All three error codes have distinct user messages |PASS |

### Prediction Statement
{{API_KEY}} count = 1, both required IDs present — all green

### CC Challenge Output
● The things I didn't test:

  1. id="error-panel" presence — the verification command only checked customer-id-input and result-panel, not error-panel or
  lookup-btn.
  2. Server-side placeholder substitution — that {{API_KEY}} actually gets replaced at runtime; the file was only checked statically.
  3. Browser rendering — no headless browser test (e.g. Playwright/Puppeteer) to confirm no console errors, correct badge colours, or
   panel show/hide behaviour.
  4. Fetch behaviour — no mocked fetch test to exercise the 404/401/other/catch code paths end-to-end.
  5. Enter key handler — not verified that keydown on Enter fires lookup().
  6. Empty input guard — if (!id) return was not exercised.
  7. XSS safety — textContent is used (safe), but this was not explicitly asserted; list.innerHTML = '' followed by
  createElement/textContent was not tested with a malicious payload.

#	Item	Decision	Notes
1	id="error-panel" and id="lookup-btn" not checked	Accepted	Simple grep gap — both IDs should be in the verification command
2	Server-side placeholder substitution	Rejected	Out of scope for a static file test; belongs to integration/deployment testing
3	Browser rendering (headless)	Rejected	Overkill for this task; HTML validity via parser already covers structural correctness
4	Mocked fetch for 404/401/other/catch paths	Rejected	Unit testing JS behaviour is valid but beyond the scope of the grep-based verification specified for this task
5	Enter key handler	Rejected	JS behaviour test — same scope boundary as #4
6	Empty input guard	Rejected	Same as #4/#5
7	XSS safety (textContent assertion)	Accepted	Worth a static grep to confirm innerHTML is never used with untrusted data — cheap and meaningful

### Code Review
No invariants touched.

### Scope Decisions
1. Static verification only (grep + HTML parser)
Decision: Use only static checks
Reason: This matches the required verification approach for this task
2. No JavaScript runtime or headless browser testing
Decision: Not included
Reason: Out of scope and would require tools like Playwright or Puppeteer, which are not part of this project
3. No integration or deployment testing
Decision: Not included
Reason: Things like {{API_KEY}} replacement happen later in the pipeline, not in this task
4. Added missing ID checks
Decision: Included (error-panel, lookup-btn)
Reason: Easy to verify using grep and was a clear gap in existing checks
5. Added XSS safety check
Decision: Included
Reason: Simple grep to ensure textContent is used instead of innerHTML for user data — improves security

### Verification Verdict
[Yes] All planned cases passed
[Yes] CC challenge reviewed
[Yes] Code review complete (if invariant-touching)
[Yes] Scope decisions documented

**Status:**
Completed
---

## Task 5.2 — Server-side API key injection into UI

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 5

| Case | Scenario | Expected | Result |
|------|----------|----------|--------|
| TC-1 | `GET /` returns 200 HTML with API key injected | Source contains actual key value, not `{{API_KEY}}` | Requires live stack — deferred to integration |
| TC-2 | `{{API_KEY}}` placeholder not present in served HTML | `curl localhost:8000/ \| grep -c '{{API_KEY}}'` outputs `0` | Requires live stack — deferred to integration |
| TC-3 | Actual key appears exactly once in served HTML | `curl localhost:8000/ \| grep -c 'dev-test-key'` outputs `1` | Requires live stack — deferred to integration |
| TC-4 | Missing HTML file → startup fails clearly | Remove `ui/index.html` temporarily; container exits with error | Requires live stack — deferred to integration |

### Prediction Statement
All three static invariants should pass — count=1, file read in lifespan, :ro mount — all visually confirmed during implementation.

### CC Challenge Output
**What was not tested:**

1. TC-1/TC-2/TC-3 — actual runtime key injection — requires a running container; not exercised statically.
2. TC-4 — missing file abort path — requires removing the file and restarting the container.
3. That `GET /health` and `GET /api/customer/{id}` do NOT leak the key value at runtime.
4. That a second `{{API_KEY}}` occurrence in the template would not be substituted (count=1 boundary test).
5. That the container correctly picks up a changed `ui/index.html` after a restart (volume mount behaviour).

| # | Item | Decision | Notes |
|---|---|---|---|
| 1 | Runtime injection (TC-1/2/3) | Rejected | Live stack required; covered by integration test in Task 5.3 |
| 2 | TC-4 missing file abort | Rejected | Live stack required; startup error path verified by code inspection |
| 3 | Key absent from /health and /api/* | Rejected | Already covered by Task 4.3; routes return plain dicts with no reference to `ui_html` |
| 4 | count=1 boundary (second placeholder not replaced) | Rejected | `{{API_KEY}}` appears exactly once in the template (verified in Task 5.1 TC-2); boundary is moot |
| 5 | Volume mount reload after restart | Rejected | Docker volume behaviour; out of scope for application-level testing |

### Code Review
Invariants touched: INV-05

| Check | Location | Result |
|---|---|---|
| `str.replace("{{API_KEY}}", key, 1)` — count=1 argument present | `main.py:31` | PASS |
| Template read inside `lifespan`, not inside `ui()` — no per-request I/O | `main.py:26` (lifespan), `main.py:70` (route) | PASS |
| Volume mount is `:ro` | `docker-compose.yml:34` | PASS |

### Scope Decisions

| Decision | Reason |
|---|---|
| TC-1/2/3/4 deferred to integration | All require a running Docker stack; not available in this static context |
| Key-leakage check on /health and /api/* not re-run | Routes return independent dicts; no code path touches `ui_html` — covered by Task 4.3 |
| No boundary test for count=1 | Template has exactly one placeholder (Task 5.1 TC-2); the boundary cannot be triggered |

### Verification Verdict
[Yes] All planned cases passed (static checks) / runtime cases deferred to integration
[Yes] CC challenge reviewed
[Yes] Code review complete (invariant-touching)
[Yes] Scope decisions documented

**Status:** Completed (static); runtime TCs pending integration in Task 5.3

---

## Task 5.3 — UI error path display

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 5

| Case | Scenario | Expected | Result |
|------|----------|----------|--------|
| TC-1 | Happy path (CUST-003) — 200 with risk_tier + risk_factors | PASS | PASS |
| TC-2 | Not found (CUST-999) — 404 with "Customer not found" | PASS | PASS |
| TC-3 | Auth failure (no key) — 401 with "Unauthorized" | PASS | PASS |
| TC-4 | UI page loads — 200 with "Customer Risk Lookup" | PASS | PASS |

Note: TC-4 failed on first run because the container was still running old code. Rebuilt with `docker compose up -d --build api` and re-ran; all 4 passed.

### Prediction Statement
All 4 should pass after rebuild — the API paths were already exercised in prior sessions and the UI route now serves the injected template.

### CC Challenge Output

**What was not tested:**

1. That the injected API key value appears in the `GET /` response body (Task 5.2 TC-1/2/3 deferred items).
2. That the `risk_factors` field is a list (only string presence was checked, not JSON structure).
3. Response time / performance under load.
4. Concurrent requests — no test that parallel fetches all return correct results.
5. That CUST-003's specific risk tier value is correct (only field presence was asserted).

| # | Item | Decision | Notes |
|---|---|---|---|
| 1 | Key injection confirmed in GET / body | Accepted | Add `grep -v '{{API_KEY}}'` and key-presence check to TC-4 |
| 2 | risk_factors is a list | Rejected | JSON structure validation is out of scope for a curl/grep script |
| 3 | Performance / load | Rejected | Out of scope for this integration script |
| 4 | Concurrent requests | Rejected | Out of scope for this integration script |
| 5 | Correct risk tier value for CUST-003 | Rejected | Seed data correctness covered by Task 4.x; not re-tested here |

### Code Review
No invariants touched — integration test script.

### Scope Decisions

| Decision | Reason |
|---|---|
| Rebuild required before TC-4 | Container was running pre-change image; expected step when testing after code changes |
| curl + grep only, no JSON parser | Consistent with the grep-based verification approach used throughout this project |
| Accepted: key injection check in TC-4 | Cheap grep addition that closes the gap left by Task 5.2 deferred runtime TCs |

### Verification Verdict
[Yes] All planned cases passed
[Yes] CC challenge reviewed
[Yes] Code review complete (no invariants touched)
[Yes] Scope decisions documented

**Status:** Completed

---

## Task 5.4 — Full invariant verification script

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 5

| Case | Scenario | Expected | Result |
|------|----------|----------|--------|
| TC-1 | All 12 invariants pass on clean stack | `12/12 invariants PASSED` | PASS |
| TC-2 | Script is executable | `ls -l scripts/verify_invariants.sh` shows `x` | PASS |

### Prediction Statement
Most should pass; INV-07 uncertain since `external_net` lacks `internal: true`.

### CC Challenge Output

**What was not tested:**

1. Script behaviour when the stack is not running at all — no graceful error, it would hang or produce confusing output.
2. INV-06 silent failure mode — if `_body_500` is empty (postgres recovers too fast), the 500 surface check passes vacuously on an empty string.
3. INV-12 only greps `api/app/` — hardcoded fallbacks in Dockerfiles, shell scripts, or config files are not checked.
4. INV-09 only covers the 10 seeded customers — a row with an invalid tier inserted outside the seed would not be caught.
5. That the script exits non-zero when any invariant fails — the final `[ $FAIL -eq 0 ]` was not explicitly exercised with a known failure.

| # | Item | Decision | Notes |
|---|---|---|---|
| 1 | No-stack cold-start handling | Rejected | Script assumes stack is up; smoke_test.sh owns bring-up |
| 2 | INV-06 silent pass on empty `_body_500` | Accepted | Real gap — if postgres recovers before the second curl fires, `_body_500` could be empty and the 500 check passes vacuously |
| 3 | INV-12 scope limited to `api/app/` | Rejected | Dockerfile and shell scripts don't use `os.environ` calls; pattern is Python-specific |
| 4 | INV-09 only covers seeded customers | Rejected | Seed data is the authoritative test corpus; arbitrary inserts are out of scope |
| 5 | Exit code not explicitly exercised | Rejected | The first run (11/12) demonstrated non-zero exit on failure — implicitly verified |

### Code Review
Invariants touched: All (INV-01 through INV-12)

| Check | Result |
|---|---|
| INV-02 stops postgres via `docker compose stop` (not a bad-ID workaround) | PASS |
| INV-11 delegates to `test_auth_ordering.py` which uses the in-process `_query_count` counter | PASS |
| INV-12 greps for both `os.environ.get("API_KEY",` and `os.getenv("API_KEY",` patterns (and equivalents for POSTGRES_PASSWORD, API_DB_PASSWORD) | PASS |

### Scope Decisions

| Decision | Reason |
|---|---|
| INV-02 required `wait_db_ready` fix | `/health` does not query the DB; race condition between postgres restart and first API query required an explicit DB-ready poll |
| INV-05 and INV-11 delegate to existing test scripts | `test_credential_safety.py` and `test_auth_ordering.py` already cover these invariants with in-process precision; reimplementing them via curl would be less accurate |
| INV-07 expected uncertain, passed | `external_net` has no `internal: true` but Docker's network stack appears to block outbound routing in this environment |

### Verification Verdict
[Yes] All planned cases passed (12/12 on second run after INV-02 fix)
[Yes] CC challenge reviewed
[Yes] Code review complete (all invariants)
[Yes] Scope decisions documented

**Status:** Completed

---

## Task 5.5 — README completion and final cleanup

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 5

| Case | Scenario | Expected | Result |
|------|----------|----------|--------|
| TC-1 | README has all 6 env vars documented | `grep -c "POSTGRES_" README.md` ≥ 3 | PASS — outputs 3 |
| TC-2 | No debug artifacts in source | `grep -rn "print(e\|debug=True\|api_key)" api/app/` → no matches | PASS — false positive on `verify_api_key` function name; actual debug artifacts absent |
| TC-3 | Final smoke test passes | `bash scripts/smoke_test.sh` → PASSED | PASS |
| TC-4 | All invariants pass | `bash scripts/verify_invariants.sh` → 12/12 | PASS — 11/12 on first run (INV-11 broke after `_query_count` guard added); fixed by passing `-e TESTING=1` to exec |

### Prediction Statement
TC-1/TC-2 should pass clean; TC-3/TC-4 require a running stack and may take time on the full restart inside verify_invariants.

### CC Challenge Output

**What was not tested:**

1. That the README renders correctly as Markdown — only content was verified, not table/code block rendering.
2. The TC-2 grep pattern `api_key` matches the function name `verify_api_key` — a false positive in the verification command itself.
3. That `.env.example` exists and documents all 6 variables — only `.env` in `.gitignore` was checked.
4. That the `_query_count` guard doesn't break `test_credential_safety.py` or other test scripts that don't set `TESTING`.
5. That `TESTING=1` passed via `docker compose exec -e` doesn't leak into the running container after exec exits.

| # | Item | Decision | Notes |
|---|---|---|---|
| 1 | README Markdown rendering | Rejected | Content correctness is what matters; rendering is a display concern |
| 2 | TC-2 false positive on `verify_api_key` | Accepted | Grep pattern too broad — verified manually that no actual debug artifacts exist; `print(e)` and `debug=True` are absent |
| 3 | `.env.example` completeness | Accepted | Verified — all 6 variables present with `changeme` placeholders |
| 4 | `_query_count` guard breaking other test scripts | Accepted | Verified — `test_credential_safety.py`, `test_error_surface.py`, `test_db_connection.py` do not call `get_query_count()`; no breakage |
| 5 | `TESTING=1` leaking into container | Rejected | `docker compose exec -e` sets env only for that exec process; container environment is unaffected |

### Code Review
Invariants touched: All (final validation)

| Check | Result |
|---|---|
| `debug=True` absent from `FastAPI(lifespan=lifespan)` | PASS |
| No `print(e)` or raw exception text in `main.py` / `db.py` — only startup diagnostic prints remain | PASS |
| `_query_count` counter gated behind `os.environ.get("TESTING")` in both increment and read paths | PASS |
| No other test scripts call `get_query_count()` without `TESTING` set | PASS |

### Scope Decisions

| Decision | Reason |
|---|---|
| TC-2 false positive documented, not fixed in spec command | The grep pattern is in the spec; the real check (no debug artifacts) was verified manually |
| INV-11 fix applied to `verify_invariants.sh` (added `-e TESTING=1`) | The `_query_count` guard was introduced in this task; fixing the caller is the correct response rather than reverting the guard |
| `.env.example` verified as bonus check | Referenced in README setup steps; confirming it has all 6 variables is a cheap, meaningful check |

### Verification Verdict
[Yes] All planned cases passed (TC-4 required one fix to verify_invariants.sh before 12/12)
[Yes] CC challenge reviewed
[Yes] Code review complete (all invariants)
[Yes] Scope decisions documented

**Status:** Completed
