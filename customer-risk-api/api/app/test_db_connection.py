"""Manual smoke test for the database connection module.

Run inside the api container:
    docker compose exec api python app/test_db_connection.py
"""

from db import get_connection, get_customer_by_id


def main():
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        print("DB connection OK")
    except RuntimeError as e:
        print(f"DB connection FAILED: {e}")

    print(get_customer_by_id("CUST-001"))
    print(get_customer_by_id("CUST-NONEXISTENT") or "None (expected)")


if __name__ == "__main__":
    main()
