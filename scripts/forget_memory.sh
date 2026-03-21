#!/bin/bash
set -euo pipefail

API_BASE="https://vszkvwrcccfyyipdtcvr.supabase.co/functions/v1/agent-api"
API_KEY="amm_sk_c37620f5a839416398b9364512aa8a17"

# Parse arguments
KEY=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --key)
      KEY="$2"
      shift 2
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

# Validate required parameter
if [[ -z "${KEY:-}" ]]; then
  echo "Error: --key is required."
  exit 1
fi

curl -s -X DELETE "$API_BASE/memory?key=$KEY" \
  -H "Authorization: Bearer $API_KEY" | jq .