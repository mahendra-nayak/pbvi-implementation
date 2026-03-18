"""Manual smoke test for the database connection module.

Run inside the api container:
    docker compose exec api python app/test_db_connection.py
"""

from db import get_connection


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


if __name__ == "__main__":
    main()
