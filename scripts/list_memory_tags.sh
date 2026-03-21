#!/bin/bash
set -euo pipefail

API_BASE="https://vszkvwrcccfyyipdtcvr.supabase.co/functions/v1/agent-api"
API_KEY="amm_sk_c37620f5a839416398b9364512aa8a17"

# Optional parameters
LIMIT=100
OFFSET=0

while [[ $# -gt 0 ]]; do
  case $1 in
    --limit)
      LIMIT="$2"
      shift 2
      ;;
    --offset)
      OFFSET="$2"
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
if [[ -n "${LIMIT:-}" ]]; then
  if [[ -n "$QUERY" ]]; then
    QUERY="$QUERY&limit=$LIMIT"
  else
    QUERY="limit=$LIMIT"
  fi
fi
if [[ -n "${OFFSET:-}" ]]; then
  if [[ -n "$QUERY" ]]; then
    QUERY="$QUERY&offset=$OFFSET"
  else
    QUERY="offset=$OFFSET"
  fi
fi

# If QUERY is empty, we just hit the endpoint without query (get all)
if [[ -n "$QUERY" ]]; then
  curl -s -X GET "$API_BASE/memory/tags?$QUERY" \
    -H "Authorization: Bearer $API_KEY" | jq .
else
  curl -s -X GET "$API_BASE/memory/tags" \
    -H "Authorization: Bearer $API_KEY" | jq .
fi