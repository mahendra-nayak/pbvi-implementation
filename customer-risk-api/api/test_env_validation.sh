#!/usr/bin/env bash
set -euo pipefail

# Run from the api/ directory: bash test_env_validation.sh

OUTPUT=$(API_KEY="" POSTGRES_USER=riskuser POSTGRES_PASSWORD=riskpass POSTGRES_DB=riskdb \
  uvicorn app.main:app --host 0.0.0.0 --port 8001 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 0 ]; then
  echo "FAIL: process exited 0 — expected non-zero"
  exit 1
fi

if echo "$OUTPUT" | grep -q "API_KEY"; then
  echo "PASS: process exited $EXIT_CODE and error mentions API_KEY"
else
  echo "FAIL: error output does not contain 'API_KEY'"
  echo "Output was: $OUTPUT"
  exit 1
fi
