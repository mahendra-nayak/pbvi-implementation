-- Schema for customer-risk-api
-- api_user is the read-only application role; write access is retained by the superuser for seeding.
-- NOTE: Replace 'apipass123' with the value of API_DB_PASSWORD in Task 2.3.

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'api_user') THEN
    CREATE ROLE api_user WITH LOGIN PASSWORD 'apipass123';
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS customers (
  customer_id  VARCHAR(50)  PRIMARY KEY,
  name         VARCHAR(255) NOT NULL,
  risk_tier    VARCHAR(10)  NOT NULL CHECK (risk_tier IN ('LOW', 'MEDIUM', 'HIGH')),
  risk_factors TEXT[]       NOT NULL,
  assessed_at  TIMESTAMP    NOT NULL DEFAULT NOW()
);

GRANT CONNECT ON DATABASE riskdb TO api_user;
GRANT USAGE ON SCHEMA public TO api_user;
GRANT SELECT ON customers TO api_user;

REVOKE INSERT, UPDATE, DELETE ON customers FROM api_user;
