#!/bin/bash
set -euo pipefail

API_BASE="https://vszkvwrcccfyyipdtcvr.supabase.co/functions/v1/agent-api"
API_KEY="amm_sk_c37620f5a839416398b9364512aa8a17"

# Parse arguments
LIMIT=10
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

curl -s -X GET "$API_BASE/mail/list?limit=$LIMIT&offset=$OFFSET" \
  -H "Authorization: Bearer $API_KEY" | jq .