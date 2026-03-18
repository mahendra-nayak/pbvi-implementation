# psycopg2 is a synchronous driver and will block the asyncio event loop on every
# database call. This is a known trade-off accepted for this stage of the architecture.

import os
import psycopg2


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
