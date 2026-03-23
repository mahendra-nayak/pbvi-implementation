#!/usr/bin/env bash
set -uo pipefail

BASE_URL="http://localhost:8000"
API_KEY="dev-test-key-12345"
PASS=0
FAIL=0

run_test() {
  local name="$1"
  local expected_status="$2"
  local expected_body="$3"
  local actual_status="$4"
  local actual_body="$5"

  if [ "$actual_status" -eq "$expected_status" ] && echo "$actual_body" | grep -q "$expected_body"; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name"
    echo "  expected status=$expected_status body contains '$expected_body'"
    echo "  got     status=$actual_status body='$actual_body'"
    FAIL=$((FAIL + 1))
  fi
}

# Test 1 — happy path
body=$(curl -s -w "\n%{http_code}" -H "X-API-Key: $API_KEY" "$BASE_URL/api/customer/CUST-003")
status=$(echo "$body" | tail -n1)
content=$(echo "$body" | head -n -1)
run_test "happy path (CUST-003)" 200 "risk_tier" "$status" "$content"
echo "$content" | grep -q "risk_factors" || { echo "  FAIL: happy path missing risk_factors"; FAIL=$((FAIL + 1)); PASS=$((PASS - 1)); }

# Test 2 — not found
body=$(curl -s -w "\n%{http_code}" -H "X-API-Key: $API_KEY" "$BASE_URL/api/customer/CUST-999")
status=$(echo "$body" | tail -n1)
content=$(echo "$body" | head -n -1)
run_test "not found (CUST-999)" 404 "Customer not found" "$status" "$content"

# Test 3 — auth failure
body=$(curl -s -w "\n%{http_code}" "$BASE_URL/api/customer/CUST-001")
status=$(echo "$body" | tail -n1)
content=$(echo "$body" | head -n -1)
run_test "auth failure (no key)" 401 "Unauthorized" "$status" "$content"

# Test 4 — UI page loads
body=$(curl -s -w "\n%{http_code}" "$BASE_URL/")
status=$(echo "$body" | tail -n1)
content=$(echo "$body" | head -n -1)
run_test "UI page loads" 200 "Customer Risk Lookup" "$status" "$content"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
