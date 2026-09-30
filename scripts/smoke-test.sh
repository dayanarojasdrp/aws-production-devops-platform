#!/usr/bin/env sh
set -eu

base_url="${BASE_URL:-http://localhost:8080}"

curl --fail --silent --show-error "${base_url}/healthz"
curl --fail --silent --show-error "${base_url}/readyz"

email="smoke-$(date +%s)@example.com"
curl --fail --silent --show-error \
  --header "Content-Type: application/json" \
  --data "{\"name\":\"Smoke Test\",\"email\":\"${email}\"}" \
  "${base_url}/users"
curl --fail --silent --show-error "${base_url}/users"

echo "Smoke test passed"
