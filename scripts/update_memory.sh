#!/bin/bash
set -euo pipefail

API_BASE="https://vszkvwrcccfyyipdtcvr.supabase.co/functions/v1/agent-api"
API_KEY="amm_sk_c37620f5a839416398b9364512aa8a17"

# Parse arguments
KEY=""
CONTENT=""
TAGS=""
CONTEXT=""
ADD_TAGS=""
REMOVE_TAGS=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --key)
      KEY="$2"
      shift 2
      ;;
    --content)
      CONTENT="$2"
      shift 2
      ;;
    --tags)
      TAGS="$2"
      shift 2
      ;;
    --context)
      CONTEXT="$2"
      shift 2
      ;;
    --add-tags)
      ADD_TAGS="$2"
      shift 2
      ;;
    --remove-tags)
      REMOVE_TAGS="$2"
      shift 2
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

# Validate required parameters
if [[ -z "${KEY:-}" ]]; then
  echo "Error: --key is required."
  exit 1
fi

# Build JSON payload
PAYLOAD="{\"key\":\"$KEY\"}"
if [[ -n "${CONTENT:-}" ]]; then
  PAYLOAD="$(echo "$PAYLOAD" | jq --arg content "$CONTENT" '. + {content: $content}')"
fi
if [[ -n "${TAGS:-}" ]]; then
  PAYLOAD="$(echo "$PAYLOAD" | jq --arg tags "$TAGS" '. + {tags: ($tags | split(","))}')"
fi
if [[ -n "${CONTEXT:-}" ]]; then
  PAYLOAD="$(echo "$PAYLOAD" | jq --arg context "$CONTEXT" '. + {context: $context}')"
fi
if [[ -n "${ADD_TAGS:-}" ]]; then
  PAYLOAD="$(echo "$PAYLOAD" | jq --arg add_tags "$ADD_TAGS" '. + {add_tags: ($add_tags | split(","))}')"
fi
if [[ -n "${REMOVE_TAGS:-}" ]]; then
  PAYLOAD="$(echo "$PAYLOAD" | jq --arg remove_tags "$REMOVE_TAGS" '. + {remove_tags: ($remove_tags | split(","))}')"
fi

curl -s -X PUT "$API_BASE/memory" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" | jq .