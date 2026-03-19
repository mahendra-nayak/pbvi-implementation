# Session Log — Session 4: Authentication & Security

**Session:** Session 4  
**Date:**  
**Engineer:**  
**Branch:** session/s04_auth_security

---

## Tasks

| Task ID | Task Name | Status | Commit |
|---------|-----------|--------|--------|
| 4.1 | API key middleware | | |
| 4.2 | Authentication-before-database-access ordering | | |
| 4.3 | Credential safety — key not in responses or logs | | |
| 4.4 | Error surface audit | | |
| 4.5 | UI route exempt from auth | | |
| 4.6 | Compose network isolation (no external calls) | | |

---

## Session Integration Check

```bash
bash scripts/smoke_test.sh && \
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8000/api/customer/CUST-001 && \
curl -s -H "X-API-Key: dev-test-key-12345" -o /dev/null -w "%{http_code}\n" http://localhost:8000/api/customer/CUST-001 && \
docker compose exec api python app/test_auth_ordering.py && \
docker compose exec api python app/test_credential_safety.py && \
docker compose exec api python app/test_error_surface.py
```

Expected: `401`, `200`, all test scripts print PASS.

**Integration check result:**  
**Sign-off:**
