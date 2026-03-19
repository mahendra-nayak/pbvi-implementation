"""Credential safety test.

Verifies that API key values and auth header names never appear in response bodies.

Run inside the api container:
    docker compose exec api python app/test_credential_safety.py
"""

import os
import sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from unittest.mock import patch
from starlette.testclient import TestClient
from app.main import app

API_KEY = os.environ["API_KEY"]
FORBIDDEN_STRINGS = [API_KEY, "X-API-Key", "api_key", "Authorization"]

client = TestClient(app, raise_server_exceptions=False)


def assert_no_credentials_leaked(body: str, label: str):
    for s in FORBIDDEN_STRINGS:
        assert s not in body, (
            f"[{label}] Forbidden string {s!r} found in response body: {body!r}"
        )


def test_valid_request_no_key_in_body():
    response = client.get("/api/customer/CUST-001", headers={"X-API-Key": API_KEY})
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    assert_no_credentials_leaked(response.text, "200 path")
    print("T1 PASS: valid request body contains no credential values")


def test_invalid_key_not_echoed():
    wrong_key = "super-secret-wrong-key"
    response = client.get("/api/customer/CUST-001", headers={"X-API-Key": wrong_key})
    assert response.status_code == 401, f"Expected 401, got {response.status_code}"
    assert wrong_key not in response.text, (
        f"Wrong key value echoed in 401 body: {response.text!r}"
    )
    assert_no_credentials_leaked(response.text, "401 path")
    print("T2 PASS: 401 body does not echo the received key")


def test_server_error_no_key_in_body():
    with patch("app.main.get_customer_by_id", side_effect=RuntimeError("db error")):
        response = client.get("/api/customer/CUST-001", headers={"X-API-Key": API_KEY})
    assert response.status_code == 500, f"Expected 500, got {response.status_code}"
    assert_no_credentials_leaked(response.text, "500 path")
    print("T3 PASS: 500 body contains no credential values")


def test_health_no_key_in_body():
    response = client.get("/health")
    assert response.status_code == 200, f"Expected 200, got {response.status_code}"
    assert_no_credentials_leaked(response.text, "/health")
    print("T4 PASS: /health body contains no credential values")


if __name__ == "__main__":
    test_valid_request_no_key_in_body()
    test_invalid_key_not_echoed()
    test_server_error_no_key_in_body()
    test_health_no_key_in_body()
    print("All credential safety tests PASSED")
