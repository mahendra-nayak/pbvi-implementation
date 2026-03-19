# psycopg2 is a synchronous driver and will block the asyncio event loop on every
# database call. This is a known trade-off accepted for this stage of the architecture.

import os
import psycopg2

_query_count = 0  # module-level counter (for testing only)


def get_query_count():
    return _query_count


def get_connection():
    """Return a new psycopg2 connection using environment variables.

    Reads: POSTGRES_HOST (default: "postgres"), POSTGRES_PORT (default: "5432"),
           API_DB_USER, API_DB_PASSWORD, POSTGRES_DB

    On connection failure, raises RuntimeError("Database connection failed").
    The raw psycopg2 exception is not propagated to avoid leaking hostname,
    credentials, or internal state.

    Returns a psycopg2 connection with autocommit=False.
    """
    try:
        conn = psycopg2.connect(
            host=os.environ.get("POSTGRES_HOST", "postgres"),
            port=os.environ.get("POSTGRES_PORT", "5432"),
            user=os.environ["API_DB_USER"],
            password=os.environ["API_DB_PASSWORD"],
            dbname=os.environ["POSTGRES_DB"],
        )
        conn.autocommit = False
        return conn
    except psycopg2.OperationalError:
        raise RuntimeError("Database connection failed")


def get_customer_by_id(customer_id: str) -> dict | None:
    """Look up a customer by ID.

    Returns a dict with keys: customer_id (str), name (str), risk_tier (str),
    risk_factors (list of str).

    Returns None if no matching record exists.

    Raises RuntimeError("Database query failed") on any database error —
    the raw psycopg2 error is not propagated.
    """
    global _query_count
    _query_count += 1
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT customer_id, name, risk_tier, risk_factors"
            " FROM customers WHERE customer_id = %s",
            (customer_id,),
        )
        row = cur.fetchone()
        if row is None:
            return None
        return {
            "customer_id": row[0],
            "name": row[1],
            "risk_tier": row[2],
            "risk_factors": row[3],
        }
    except psycopg2.Error:
        raise RuntimeError("Database query failed")
    finally:
        conn.close()
