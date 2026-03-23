#!/usr/bin/env bash
set -uo pipefail

cd "$(dirname "$0")/.."

BASE_URL="http://localhost:8000"
API_KEY="dev-test-key-12345"
PASS=0
FAIL=0
_body_500=""   # captured in INV-02, reused in INV-06

pass() { echo "INV-$1: PASS"; PASS=$((PASS+1)); }
fail() { echo "INV-$1: FAIL — $2"; FAIL=$((FAIL+1)); }

http_status() { curl -s -o /dev/null -w "%{http_code}" "$@"; }

wait_healthy() {
  local elapsed=0
  until curl -sf "$BASE_URL/health" >/dev/null 2>&1; do
    [ $elapsed -ge 60 ] && return 1
    sleep 3; elapsed=$((elapsed+3))
  done
}

wait_db_ready() {
  # Polls until an authenticated API request returns something other than 500,
  # confirming postgres is accepting connections again after a stop/start.
  local elapsed=0
  until [ "$(http_status -H "X-API-Key: $API_KEY" "$BASE_URL/api/customer/CUST-001")" != "500" ]; do
    [ $elapsed -ge 30 ] && return 1
    sleep 2; elapsed=$((elapsed+2))
  done
}

# ── INV-01: Data Passthrough Fidelity ───────────────────────────────────────
api_body=$(curl -s -H "X-API-Key: $API_KEY" "$BASE_URL/api/customer/CUST-001")
inv01=$(echo "$api_body" | docker compose exec -T api python3 -c "
import json, sys, os, psycopg2
api = json.load(sys.stdin)
conn = psycopg2.connect(host='postgres', dbname=os.environ['POSTGRES_DB'],
    user=os.environ['POSTGRES_USER'], password=os.environ['POSTGRES_PASSWORD'])
cur = conn.cursor()
cur.execute(\"SELECT risk_tier, risk_factors FROM customers WHERE customer_id='CUST-001'\")
row = cur.fetchone(); conn.close()
if api['risk_tier'] != row[0]:
    print(f'tier mismatch: api={api[\"risk_tier\"]} db={row[0]}'); sys.exit(1)
if api['risk_factors'] != list(row[1]):
    print(f'factors mismatch: api={api[\"risk_factors\"]} db={list(row[1])}'); sys.exit(1)
print('PASS')
" 2>&1)
[ "$inv01" = "PASS" ] && pass "01" || fail "01" "$inv01"

# ── INV-02: Existence Mapping Integrity ─────────────────────────────────────
docker compose stop postgres >/dev/null 2>&1
sleep 3
_body_500=$(curl -s -H "X-API-Key: $API_KEY" "$BASE_URL/api/customer/CUST-001")
status_db_down=$(http_status -H "X-API-Key: $API_KEY" "$BASE_URL/api/customer/CUST-001")
docker compose start postgres >/dev/null 2>&1
wait_healthy || { fail "02" "postgres did not recover within 60s"; }
wait_db_ready  || { fail "02" "DB not accepting queries within 30s of recovery"; }
status_nonexistent=$(http_status -H "X-API-Key: $API_KEY" "$BASE_URL/api/customer/CUST-NONEXISTENT")
if [ "$status_db_down" -eq 500 ] && [ "$status_nonexistent" -eq 404 ]; then
  pass "02"
else
  fail "02" "db_down=$status_db_down (want 500), nonexistent=$status_nonexistent (want 404)"
fi

# ── INV-03: Read-Only Database ───────────────────────────────────────────────
insert_out=$(docker compose exec -T postgres psql -U api_user -d riskdb -c \
  "INSERT INTO customers (customer_id, name, risk_tier, risk_factors, assessed_at) VALUES ('TEST-999','Test','LOW','{}',NOW())" 2>&1)
select_out=$(docker compose exec -T postgres psql -U api_user -d riskdb -t -A -c \
  "SELECT risk_tier FROM customers WHERE customer_id='CUST-001'" 2>&1)
insert_denied=$(echo "$insert_out" | grep -qi "permission denied" && echo yes || echo no)
select_ok=$(echo "$select_out" | grep -q "LOW" && echo yes || echo no)
[ "$insert_denied" = "yes" ] && [ "$select_ok" = "yes" ] \
  && pass "03" || fail "03" "insert_denied=$insert_denied select_ok=$select_ok"

# ── INV-04: Authentication Enforcement ──────────────────────────────────────
s_none=$(http_status "$BASE_URL/api/customer/CUST-001")
s_wrong=$(http_status -H "X-API-Key: wrong-key-xyz" "$BASE_URL/api/customer/CUST-001")
s_valid=$(http_status -H "X-API-Key: $API_KEY" "$BASE_URL/api/customer/CUST-001")
s_ui=$(http_status "$BASE_URL/")
if [ "$s_none" -eq 401 ] && [ "$s_wrong" -eq 401 ] && \
   [ "$s_valid" -eq 200 ] && [ "$s_ui" -eq 200 ]; then
  pass "04"
else
  fail "04" "no_key=$s_none wrong_key=$s_wrong valid=$s_valid ui=$s_ui"
fi

# ── INV-05: Credential Safety ────────────────────────────────────────────────
inv05=$(docker compose exec -T api python3 app/test_credential_safety.py 2>&1)
echo "$inv05" | grep -q "All credential safety tests PASSED" \
  && pass "05" || fail "05" "$(echo "$inv05" | tail -1)"

# ── INV-06: Error Surface Control ────────────────────────────────────────────
body_401=$(curl -s "$BASE_URL/api/customer/CUST-001")
body_404=$(curl -s -H "X-API-Key: $API_KEY" "$BASE_URL/api/customer/CUST-NONE")
body_500="$_body_500"
combined="$body_401$body_404$body_500"
bad_strings=0
echo "$combined" | grep -qiE "Traceback|psycopg2|SELECT" && bad_strings=1
has_401_msg=$(echo "$body_401" | grep -q "Unauthorized"       && echo yes || echo no)
has_404_msg=$(echo "$body_404" | grep -q "Customer not found" && echo yes || echo no)
has_500_msg=$(echo "$body_500" | grep -q "Internal server error" && echo yes || echo no)
if [ $bad_strings -eq 0 ] && \
   [ "$has_401_msg" = "yes" ] && [ "$has_404_msg" = "yes" ] && [ "$has_500_msg" = "yes" ]; then
  pass "06"
else
  fail "06" "bad_strings=$bad_strings has_401=$has_401_msg has_404=$has_404_msg has_500=$has_500_msg"
fi

# ── INV-07: External Isolation ───────────────────────────────────────────────
ext_result=$(docker compose exec -T api python3 -c "
import urllib.request, sys
try:
    urllib.request.urlopen('http://1.1.1.1', timeout=5)
    print('REACHABLE')
except Exception:
    print('BLOCKED')
" 2>/dev/null)
[ "$ext_result" = "BLOCKED" ] && pass "07" || fail "07" "api container can reach external internet"

# ── INV-08: Response Shape Consistency ──────────────────────────────────────
body_200=$(curl -s -H "X-API-Key: $API_KEY" "$BASE_URL/api/customer/CUST-001")
key_count=$(echo "$body_200" | docker compose exec -T api python3 -c \
  "import json,sys; print(len(json.load(sys.stdin)))" 2>&1)
[ "$key_count" = "3" ] && pass "08" || fail "08" "response has $key_count keys (expected 3)"

# ── INV-09: Risk Tier Value Constraint ──────────────────────────────────────
inv09_ok=true
for cust in CUST-001 CUST-002 CUST-003 CUST-004 CUST-005 \
            CUST-006 CUST-007 CUST-008 CUST-009 CUST-010; do
  tier=$(curl -s -H "X-API-Key: $API_KEY" "$BASE_URL/api/customer/$cust" \
         | grep -o '"risk_tier":"[^"]*"' | cut -d'"' -f4)
  case "$tier" in
    LOW|MEDIUM|HIGH) ;;
    *) inv09_ok=false; fail "09" "$cust returned tier='$tier'"; break ;;
  esac
done
$inv09_ok && pass "09"

# ── INV-10: Startup Completeness ─────────────────────────────────────────────
docker compose down -v >/dev/null 2>&1
docker compose up -d >/dev/null 2>&1
wait_healthy && pass "10" || fail "10" "health endpoint not ready within 60s"

# ── INV-11: Auth Before Data Access ──────────────────────────────────────────
inv11=$(docker compose exec -T api python3 app/test_auth_ordering.py 2>&1)
echo "$inv11" | grep -q "PASS" && pass "11" || fail "11" "$inv11"

# ── INV-12: Environment Config Integrity ─────────────────────────────────────
matches=$(grep -rn \
  -e 'os\.environ\.get("API_KEY",' \
  -e 'os\.getenv("API_KEY",' \
  -e 'os\.environ\.get("POSTGRES_PASSWORD",' \
  -e 'os\.getenv("POSTGRES_PASSWORD",' \
  -e 'os\.environ\.get("API_DB_PASSWORD",' \
  -e 'os\.getenv("API_DB_PASSWORD",' \
  api/app/ 2>/dev/null || true)
[ -z "$matches" ] && pass "12" || fail "12" "hardcoded fallback found: $matches"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "$PASS/12 invariants PASSED"
[ $FAIL -eq 0 ]
