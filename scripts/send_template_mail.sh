#!/bin/bash
set -euo pipefail

API_BASE="https://vszkvwrcccfyyipdtcvr.supabase.co/functions/v1/agent-api"
API_KEY="amm_sk_c37620f5a839416398b9364512aa8a17"

# Parse arguments
TEMPLATE=""
TO=""
VARS=""
CC=""
BCC=""
TRACK=true

while [[ $# -gt 0 ]]; do
  case $1 in
    --template)
      TEMPLATE="$2"
      shift 2
      ;;
    --to)
      TO="$2"
      shift 2
      ;;
    --vars)
      VARS="$2"
      shift 2
      ;;
    --cc)
      CC="$2"
      shift 2
      ;;
    --bcc)
      BCC="$2"
      shift 2
      ;;
    --track)
      TRACK="$2"
      shift 2
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

# Validate required parameters
if [[ -z "${TEMPLATE:-}" || -z "${TO:-}" ]]; then
  echo "Error: --template and --to are required."
  exit 1
fi

# Build JSON payload
PAYLOAD="{\"template\":\"$TEMPLATE\",\"to\":\"$TO\"}"
if [[ -n "${VARS:-}" ]]; then
  # Parse vars as key=value pairs
  declare -A var_map
  IFS=',' read -ra pairs <<< "$VARS"
  for pair in "${pairs[@]}"; do
    IFS='=' read -r key value <<< "$pair"
    var_map["$key"]="$value"
  done
  
  # Convert to JSON object
  json_vars="{"
  first=true
  for key in "${!var_map[@]}"; do
    if [[ $first == true ]]; then
      first=false
    else
      json_vars+=","
    fi
    json_vars+="\"$key\":\"${var_map[$key]}\""
  done
  json_vars+="}"
  
  PAYLOAD="$(echo "$PAYLOAD" | jq --argjson vars "$json_vars" '. + {vars: $vars}')"
fi
if [[ -n "${CC:-}" ]]; then
  PAYLOAD="$(echo "$PAYLOAD" | jq --arg cc "$CC" '. + {cc: ($cc | split(","))}')"
fi
if [[ -n "${BCC:-}" ]]; then
  PAYLOAD="$(echo "$PAYLOAD" | jq --arg bcc "$BCC" '. + {bcc: ($bcc | split(","))}')"
fi
if [[ -n "${TRACK:-}" ]]; then
  PAYLOAD="$(echo "$PAYLOAD" | jq --argjson track "$TRACK" '. + {track: $track}')"
fi

curl -s -X POST "$API_BASE/mail/template" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" | jq .