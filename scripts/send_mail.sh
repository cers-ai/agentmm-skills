#!/bin/bash
set -euo pipefail

API_BASE="https://vszkvwrcccfyyipdtcvr.supabase.co/functions/v1/agent-api"
API_KEY="amm_sk_c37620f5a839416398b9364512aa8a17"

# Parse arguments
TO=""
SUBJECT=""
BODY=""
HTML=""
CC=""
BCC=""
REPLY_TO=""
ATTACHMENTS=""
TRACK=true

while [[ $# -gt 0 ]]; do
  case $1 in
    --to)
      TO="$2"
      shift 2
      ;;
    --subject)
      SUBJECT="$2"
      shift 2
      ;;
    --body)
      BODY="$2"
      shift 2
      ;;
    --html)
      HTML="$2"
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
    --reply-to)
      REPLY_TO="$2"
      shift 2
      ;;
    --attachments)
      ATTACHMENTS="$2"
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
if [[ -z "${TO:-}" || -z "${SUBJECT:-}" || -z "${BODY:-}" ]]; then
  echo "Error: --to, --subject, and --body are required."
  exit 1
fi

# Build JSON payload
PAYLOAD="{\"to\":\"$TO\",\"subject\":\"$SUBJECT\",\"content\":\"$BODY\"}"
if [[ -n "${HTML:-}" ]]; then
  PAYLOAD="$(echo "$PAYLOAD" | jq --arg html "$HTML" '. + {html: $html}')"
fi
if [[ -n "${CC:-}" ]]; then
  PAYLOAD="$(echo "$PAYLOAD" | jq --arg cc "$CC" '. + {cc: ($cc | split(","))}')"
fi
if [[ -n "${BCC:-}" ]]; then
  PAYLOAD="$(echo "$PAYLOAD" | jq --arg bcc "$BCC" '. + {bcc: ($bcc | split(","))}')"
fi
if [[ -n "${REPLY_TO:-}" ]]; then
  PAYLOAD="$(echo "$PAYLOAD" | jq --arg reply_to "$REPLY_TO" '. + {reply_to: $reply_to}')"
fi
if [[ -n "${ATTACHMENTS:-}" ]]; then
  # Note: Attachments would need to be handled differently in a real implementation
  # For now, we'll just note that this feature is planned
  echo "Warning: Attachments feature is planned for future implementation"
fi
if [[ -n "${TRACK:-}" ]]; then
  PAYLOAD="$(echo "$PAYLOAD" | jq --argjson track "$TRACK" '. + {track: $track}')"
fi

curl -s -X POST "$API_BASE/mail/send" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" | jq .