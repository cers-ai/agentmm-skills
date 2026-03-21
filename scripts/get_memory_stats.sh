#!/bin/bash
set -euo pipefail

API_BASE="https://vszkvwrcccfyyipdtcvr.supabase.co/functions/v1/agent-api"
API_KEY="amm_sk_c37620f5a839416398b9364512aa8a17"

# Parse arguments
DAYS=30

while [[ $# -gt 0 ]]; do
  case $1 in
    --days)
      DAYS="$2"
      shift 2
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

# Build query string
QUERY=""
if [[ -n "${DAYS:-}" ]]; then
  if [[ -n "$QUERY" ]]; then
    QUERY="$QUERY&days=$DAYS"
  else
    QUERY="days=$DAYS"
  fi
fi

# If QUERY is empty, we just hit the endpoint without query
if [[ -n "$QUERY" ]]; then
  curl -s -X GET "$API_BASE/memory/stats?$QUERY" \
    -H "Authorization: Bearer $API_KEY" | jq .
else
  curl -s -X GET "$API_BASE/memory/stats" \
    -H "Authorization: Bearer $API_KEY" | jq .
fi