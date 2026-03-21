#!/bin/bash
set -euo pipefail

API_BASE="https://vszkvwrcccfyyipdtcvr.supabase.co/functions/v1/agent-api"
API_KEY="amm_sk_c37620f5a839416398b9364512aa8a17"

# Parse arguments
QUERY=""
TAGS=""
LIMIT=50
FUZZY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --query)
      QUERY="$2"
      shift 2
      ;;
    --tags)
      TAGS="$2"
      shift 2
      ;;
    --limit)
      LIMIT="$2"
      shift 2
      ;;
    --fuzzy)
      FUZZY=true
      shift
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

# Validate required parameters
if [[ -z "${QUERY:-}" ]]; then
  echo "Error: --query is required."
  exit 1
fi

# Build JSON payload for POST request
PAYLOAD="{\"query\":\"$QUERY\",\"limit\":$LIMIT}"
if [[ -n "${TAGS:-}" ]]; then
  PAYLOAD="$(echo "$PAYLOAD" | jq --arg tags "$TAGS" '. + {tags: ($tags | split(","))}')"
fi
if [[ "$FUZZY" == true ]]; then
  PAYLOAD="$(echo "$PAYLOAD" | jq '. + {fuzzy: true}')"
fi

curl -s -X POST "$API_BASE/memory/search" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" | jq .