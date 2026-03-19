"""Error surface test.

Verifies that error responses never expose internal implementation details,
stack traces, credentials, SQL, or module names.

Run inside the api container:
    docker compose exec api python app/test_error_surface.py
"""

import json
import os
import sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from unittest.mock import patch
from starlette.testclient import TestClient
from app.main import app

API_KEY = os.environ["API_KEY"]

FORBIDDEN_IN_BODY = [
    "Traceback", "psycopg2", "uvicorn", "fastapi", "/app/",
    "SELECT ", "FROM ", "WHERE ", "POSTGRES_", "API_KEY",
    "riskuser", "riskpass",
]

FORBIDDEN_HEADERS = ["x-powered-by", "server"]

client = TestClient(app, raise_server_exceptions=False)


def assert_clean_error(response, label: str):
    body = response.text
    for s in FORBIDDEN_IN_BODY:
        assert s not in body, (
            f"[{label}] Forbidden string {s!r} found in body: {body!r}"
        )
    assert response.headers.get("content-type", "").startswith("application/json"), (
        f"[{label}] Expected application/json, got {response.headers.get('content-type')}"
    )
    for h in FORBIDDEN_HEADERS:
        assert h not in response.headers, (
            f"[{label}] Forbidden header {h!r} present"
        )


def test_missing_key_401():
    response = client.get("/api/customer/CUST-001")
    assert response.status_code == 401
    assert response.json() == {"detail": "Unauthorized"}
    assert_clean_error(response, "401 missing key")
    print("T1 PASS: 401 body is exact, no internal detail leaked")


def test_unknown_customer_404():
    response = client.get("/api/customer/CUST-NONEXISTENT", headers={"X-API-Key": API_KEY})
    assert response.status_code == 404
    assert response.json() == {"detail": "Customer not found"}
    body = response.text
    assert "CUST-NONEXISTENT" not in body, (
        f"customer_id echoed in 404 body: {body!r}"
    )
    assert_clean_error(response, "404 unknown customer")
    print("T2 PASS: 404 body is exact, no SQL or customer_id leaked")


def test_db_failure_500():
    with patch("app.main.get_customer_by_id", side_effect=RuntimeError("db error")):
        response = client.get("/api/customer/CUST-001", headers={"X-API-Key": API_KEY})
    assert response.status_code == 500
    assert response.json() == {"detail": "Internal server error"}
    assert_clean_error(response, "500 db failure")
    print("T3 PASS: 500 body is exact, no stack trace or module names leaked")


def test_ui_root():
    response = client.get("/")
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    assert "text/html" in response.headers.get("content-type", ""), (
        f"Expected text/html, got {response.headers.get('content-type')}"
    )
    assert API_KEY not in response.text, "API_KEY value found in UI response body"
    print("T4 PASS: GET / returns 200 text/html with no API key value")


if __name__ == "__main__":
    test_missing_key_401()
    test_unknown_customer_404()
    test_db_failure_500()
    test_ui_root()
    print("All error surface tests PASSED")
