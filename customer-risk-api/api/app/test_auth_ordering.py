"""In-process auth ordering test.

Verifies that an invalid API key request returns 401 and does NOT
trigger a database query.

Run inside the api container:
    docker compose exec api python app/test_auth_ordering.py
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from starlette.testclient import TestClient
from app.main import app
from app import db


def main():
    client = TestClient(app, raise_server_exceptions=False)

    before = db.get_query_count()
    response = client.get("/api/customer/CUST-001")
    after = db.get_query_count()

    assert response.status_code == 401, (
        f"Expected 401, got {response.status_code}"
    )
    assert after == before, (
        f"DB was queried {after - before} time(s) — expected 0"
    )

    print("Auth ordering: PASS (401 returned, DB not queried)")


if __name__ == "__main__":
    main()
