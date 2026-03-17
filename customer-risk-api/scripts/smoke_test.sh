#!/usr/bin/env bash
set -euo pipefail

HEALTH_URL="http://localhost:8000/health"
TIMEOUT=60
INTERVAL=3
elapsed=0

echo "==> Tearing down existing stack..."
docker compose down -v

echo "==> Building and starting services..."
docker compose up -d --build

echo "==> Polling $HEALTH_URL (timeout: ${TIMEOUT}s)..."
until curl -sf "$HEALTH_URL" > /dev/null 2>&1; do
  if [ "$elapsed" -ge "$TIMEOUT" ]; then
    echo "SMOKE TEST FAILED: health endpoint not ready"
    exit 1
  fi
  sleep "$INTERVAL"
  elapsed=$((elapsed + INTERVAL))
done

echo "SMOKE TEST PASSED"
