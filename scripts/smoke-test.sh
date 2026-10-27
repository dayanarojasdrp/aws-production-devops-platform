#!/usr/bin/env sh
set -eu

base_url="${BASE_URL:-http://localhost:8080}"
base_url="${base_url%/}"
mode="${SMOKE_TEST_MODE:-full}"
attempts="${SMOKE_TEST_ATTEMPTS:-1}"
delay_seconds="${SMOKE_TEST_DELAY_SECONDS:-5}"

case "${mode}" in
  full | read-only) ;;
  *)
    echo "SMOKE_TEST_MODE must be full or read-only" >&2
    exit 2
    ;;
esac

case "${attempts}" in
  '' | *[!0-9]* | 0)
    echo "SMOKE_TEST_ATTEMPTS must be a positive integer" >&2
    exit 2
    ;;
esac

case "${delay_seconds}" in
  '' | *[!0-9]*)
    echo "SMOKE_TEST_DELAY_SECONDS must be a non-negative integer" >&2
    exit 2
    ;;
esac

request() {
  label="$1"
  path="$2"
  attempt=1

  while [ "${attempt}" -le "${attempts}" ]; do
    if curl --fail --silent --show-error \
      --connect-timeout 5 \
      --max-time 15 \
      "${base_url}${path}" >/dev/null; then
      echo "[PASS] ${label} returned a successful response"
      return 0
    fi

    if [ "${attempt}" -lt "${attempts}" ]; then
      echo "[RETRY] ${label} failed (${attempt}/${attempts}); waiting ${delay_seconds}s"
      sleep "${delay_seconds}"
    fi
    attempt=$((attempt + 1))
  done

  echo "[FAIL] ${label} did not return a successful response" >&2
  return 1
}

request "healthz" "/healthz"
request "readyz" "/readyz"

if [ "${mode}" = "read-only" ]; then
  echo "Smoke test passed (read-only mode)"
  exit 0
fi

email="smoke-$(date +%s)@example.com"
curl --fail --silent --show-error \
  --connect-timeout 5 \
  --max-time 15 \
  --header "Content-Type: application/json" \
  --data "{\"name\":\"Smoke Test\",\"email\":\"${email}\"}" \
  "${base_url}/users" >/dev/null
request "users" "/users"

echo "Smoke test passed (full mode)"
