#!/usr/bin/env bash
set -euo pipefail

# Inputs via env:
# - TESTSAVANT_API_KEY (required)
# - REDTEAMING_ID (required)
# - RECEIVER_WEBHOOK_URLS (optional, comma-separated) or RECEIVER_WEBHOOK_URL (single)
# - TS_STRICT (default 1), MAX_VULN_RATE, MAX_VULN_COUNT, TS_POLL_TIMEOUT
# - GITHUB_TOKEN, GITHUB_REPOSITORY, DISPATCH_EVENT (default testsavant_poll_passed)

echo "[ts] Starting & gating Red-Teaming run..." >&2

: "${TESTSAVANT_API_KEY:?TESTSAVANT_API_KEY is required}"
: "${REDTEAMING_ID:?REDTEAMING_ID is required}"

STRICT_VAL="${TS_STRICT:-1}"
POLL_TIMEOUT_VAL="${TS_POLL_TIMEOUT:-3600}"
MAX_RATE_VAL="${MAX_VULN_RATE:-}"
MAX_COUNT_VAL="${MAX_VULN_COUNT:-}"
CALLBACK_URLS_VAL="${RECEIVER_WEBHOOK_URLS:-}"
CALLBACK_URL_VAL="${RECEIVER_WEBHOOK_URL:-}"

ARGS=( run-and-wait --redteaming-id "$REDTEAMING_ID" )

# Strict flag
shopt -s nocasematch
if [[ "${STRICT_VAL}" == "0" || "${STRICT_VAL}" == "false" ]]; then
  : # no --strict
else
  ARGS+=( --strict )
fi
shopt -u nocasematch

# Thresholds
if [[ -n "$MAX_RATE_VAL" ]]; then ARGS+=( --max-vulnerability-rate "$MAX_RATE_VAL" ); fi
if [[ -n "$MAX_COUNT_VAL" ]]; then ARGS+=( --max-vulnerable-count "$MAX_COUNT_VAL" ); fi

# Timeout is handled inside utils; CLI uses default; we keep env to pass to utils implicitly.
export TS_POLL_TIMEOUT="$POLL_TIMEOUT_VAL"

# Callbacks
if [[ -n "$CALLBACK_URLS_VAL" ]]; then
  ARGS+=( --callback-urls "$CALLBACK_URLS_VAL" )
elif [[ -n "$CALLBACK_URL_VAL" ]]; then
  ARGS+=( --callback-url "$CALLBACK_URL_VAL" )
fi

RESULT_FILE="result.json"

set +e
python -m testsavant_redteaming.cli --api-key "$TESTSAVANT_API_KEY" "${ARGS[@]}" > "$RESULT_FILE"
code=$?
set -e

# Expose run_id to GITHUB_OUTPUT if available
RUN_ID=$(python - <<'PY'
import json,sys
try:
  data=json.load(open('result.json'))
  print(data.get('id',''))
except Exception:
  print('')
PY
)
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  [[ -n "$RUN_ID" ]] && echo "run_id=$RUN_ID" >> "$GITHUB_OUTPUT"
fi

cat "$RESULT_FILE"

# Determine proceed based on CLI exit code (0 = pass)
PROCEED="false"
if [[ $code -eq 0 ]]; then PROCEED="true"; fi
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "proceed=$PROCEED" >> "$GITHUB_OUTPUT"
fi

# Dispatch next workflow on success
EVENT_TYPE="${DISPATCH_EVENT:-testsavant_poll_passed}"
if [[ -z "${SKIP_DISPATCH:-}" && -n "${GITHUB_TOKEN:-}" && -n "${GITHUB_REPOSITORY:-}" && "$PROCEED" == "true" ]]; then
  echo "[ts] Dispatching $EVENT_TYPE to $GITHUB_REPOSITORY..." >&2
  curl -sS -X POST \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -d @- "https://api.github.com/repos/${GITHUB_REPOSITORY}/dispatches" <<JSON
{
  "event_type": "${EVENT_TYPE}",
  "client_payload": { "run_id": "${RUN_ID}", "result": $(cat "$RESULT_FILE") }
}
JSON
else
  echo "[ts] Skipping repository_dispatch (skip or missing creds or not proceed)." >&2
fi

echo "[ts] Done." >&2
# Always exit 0; consumers decide using 'proceed' output
exit 0
