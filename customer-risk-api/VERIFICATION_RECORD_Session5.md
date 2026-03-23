# Verification Record — Session 5: UI & Integration

**Session:** Session 5  
**Date:**  
**Engineer:**  

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
| TC-1 | `GET /` returns 200 HTML with API key injected | Source contains actual key value, not `{{API_KEY}}` | |
| TC-2 | `{{API_KEY}}` placeholder not present in served HTML | `curl localhost:8000/ \| grep -c '{{API_KEY}}'` outputs `0` | |
| TC-3 | Actual key appears exactly once in served HTML | `curl localhost:8000/ \| grep -c 'dev-test-key'` outputs `1` | |
| TC-4 | Missing HTML file → startup fails clearly | Remove `ui/index.html` temporarily; container exits with error | |

### Prediction Statement

### CC Challenge Output
[Paste CC's response to: 'What did you not test in this task?'
For each item: accepted (added case) / rejected (reason).]

### Code Review
Invariants touched: INV-05
- Confirm `str.replace("{{API_KEY}}", key, 1)` (count=1 argument)
- Confirm the template is read at startup, not on every request (avoids file I/O per request)
- Confirm the HTML volume mount is `:ro` (read-only)

### Scope Decisions

### Verification Verdict
[ ] All planned cases passed
[ ] CC challenge reviewed
[ ] Code review complete (invariant-touching)
[ ] Scope decisions documented

**Status:**

---

## Task 5.3 — UI error path display

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 5

| Case | Scenario | Expected | Result |
|------|----------|----------|--------|
| TC-1 | Happy path test | PASS | |
| TC-2 | Not found test | PASS | |
| TC-3 | Auth failure test | PASS | |
| TC-4 | UI load test | PASS | |

### Prediction Statement

### CC Challenge Output
[Paste CC's response to: 'What did you not test in this task?'
For each item: accepted (added case) / rejected (reason).]

### Code Review
No invariants touched — integration test script.

### Scope Decisions

### Verification Verdict
[ ] All planned cases passed
[ ] CC challenge reviewed
[ ] Code review complete (if invariant-touching)
[ ] Scope decisions documented

**Status:**

---

## Task 5.4 — Full invariant verification script

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 5

| Case | Scenario | Expected | Result |
|------|----------|----------|--------|
| TC-1 | All 12 invariants pass on clean stack | `12/12 invariants PASSED` | |
| TC-2 | Script is executable | `ls -l scripts/verify_invariants.sh` shows `x` | |

### Prediction Statement

### CC Challenge Output
[Paste CC's response to: 'What did you not test in this task?'
For each item: accepted (added case) / rejected (reason).]

### Code Review
Invariants touched: All (INV-01 through INV-12)
- Confirm INV-02 test stops postgres rather than just passing a bad ID
- Confirm INV-11 uses the in-container query counter
- Confirm INV-12 grep patterns include common Python default-value patterns: `os.environ.get("API_KEY", ` and `os.getenv("API_KEY", `

### Scope Decisions

### Verification Verdict
[ ] All planned cases passed
[ ] CC challenge reviewed
[ ] Code review complete (invariant-touching)
[ ] Scope decisions documented

**Status:**

---

## Task 5.5 — README completion and final cleanup

### Test Cases Applied
Source: EXECUTION_PLAN.md Session 5

| Case | Scenario | Expected | Result |
|------|----------|----------|--------|
| TC-1 | README has all 6 env vars documented | `grep -c "POSTGRES_" README.md` ≥ 3 | |
| TC-2 | No debug artifacts in source | `grep -rn "print(e\|debug=True\|api_key)" api/app/` → no matches | |
| TC-3 | Final smoke test passes | `bash scripts/smoke_test.sh` → PASSED | |
| TC-4 | All invariants pass | `bash scripts/verify_invariants.sh` → 12/12 | |

### Prediction Statement

### CC Challenge Output
[Paste CC's response to: 'What did you not test in this task?'
For each item: accepted (added case) / rejected (reason).]

### Code Review
Invariants touched: All (final validation)
- Confirm `debug=True` is absent from `FastAPI()` instantiation
- Confirm no raw exception text is printed or logged
- Confirm all test-only code is gated or removed

### Scope Decisions

### Verification Verdict
[ ] All planned cases passed
[ ] CC challenge reviewed
[ ] Code review complete (invariant-touching)
[ ] Scope decisions documented

**Status:**
