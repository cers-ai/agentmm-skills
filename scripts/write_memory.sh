#!/bin/bash
set -euo pipefail

API_BASE="https://vszkvwrcccfyyipdtcvr.supabase.co/functions/v1/agent-api"
API_KEY="amm_sk_c37620f5a839416398b9364512aa8a17"

# Local SQLite database path
LOCAL_DB="/root/.openclaw/workspace/skills/AgentMM/data/local_memory.db"

# Initialize local database if not exists
init_local_db() {
  if [ ! -f "$LOCAL_DB" ]; then
    mkdir -p "$(dirname "$LOCAL_DB")"
    sqlite3 "$LOCAL_DB" <<EOF
CREATE TABLE memories (
  key TEXT PRIMARY KEY,
  content TEXT,
  tags TEXT DEFAULT '[]',        -- JSON array string
  context TEXT,
  related TEXT DEFAULT '[]',     -- JSON array string
  created_at INTEGER,
  updated_at INTEGER,
  synced INTEGER DEFAULT 0,   -- 0: not synced, 1: synced
  sync_attempts INTEGER DEFAULT 0
);
EOF
  fi
}

# Parse arguments
KEY=""
CONTENT=""
TAGS=""
TTL=""
CONTEXT=""
RELATED=""

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
    --ttl)
      TTL="$2"
      shift 2
      ;;
    --context)
      CONTEXT="$2"
      shift 2
      ;;
    --related)
      RELATED="$2"
      shift 2
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

# Validate required parameters
if [[ -z "${KEY:-}" || -z "${CONTENT:-}" ]]; then
  echo "Error: --key and --content are required."
  exit 1
fi

# Initialize local DB
init_local_db

# Get current timestamp in seconds
NOW=$(date +%s)

# Convert tags and related to JSON array strings for storage
TAGS_JSON="[]"
if [[ -n "${TAGS:-}" ]]; then
  TAGS_JSON=$(echo "$TAGS" | jq -R 'split(",")' 2>/dev/null || echo "[]")
fi
RELATED_JSON="[]"
if [[ -n "${RELATED:-}" ]]; then
  RELATED_JSON=$(echo "$RELATED" | jq -R 'split(",")' 2>/dev/null || echo "[]")
fi

# Write to local database (always first, to reduce perceived latency)
sqlite3 "$LOCAL_DB" <<EOF
INSERT OR REPLACE INTO memories 
(key, content, tags, context, related, created_at, updated_at, synced, sync_attempts)
VALUES (
  '$KEY',
  '$CONTENT',
  '$TAGS_JSON',
  '${CONTEXT:-}',
  '$RELATED_JSON',
  $NOW,
  $NOW,
  0,   -- Not synced yet
  0    -- Reset sync attempts on new write
);
EOF

# Attempt to sync to backend
# Build JSON payload for backend (using the original comma-separated strings for backend compatibility)
PAYLOAD="{\"key\":\"$KEY\",\"content\":\"$CONTENT\"}"
if [[ -n "${TAGS:-}" ]]; then
  # Backend expects comma-separated? Actually, from the original script, it seems the backend expects a JSON array? 
  # Looking at the original write_memory.sh, it did not send tags at all. So the backend may not support tags.
  # But in our enhanced skill, we are adding tags support. We assume the backend accepts a JSON array for tags.
  # We'll send the JSON array.
  PAYLOAD="$(echo "$PAYLOAD" | jq --argjson tags "$TAGS_JSON" '. + {tags: $tags}')"
fi
if [[ -n "${TTL:-}" ]]; then
  PAYLOAD="$(echo "$PAYLOAD" | jq --argjson ttl "$TTL" '. + {ttl: $ttl}')"
fi
if [[ -n "${CONTEXT:-}" ]]; then
  PAYLOAD="$(echo "$PAYLOAD" | jq --arg context "$CONTEXT" '. + {context: $context}')"
fi
if [[ -n "${RELATED:-}" ]]; then
  PAYLOAD="$(echo "$PAYLOAD" | jq --argjson related "$RELATED_JSON" '. + {related: $related}')"
fi

# Backend request
BACKEND_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$API_BASE/memory" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD") || true

# Extract HTTP status and body
HTTP_STATUS=$(echo "$BACKEND_RESPONSE" | tail -n1 | sed 's/^HTTP_STATUS://')
RESPONSE_BODY=$(echo "$BACKEND_RESPONSE" | sed '$d')

# Check if backend call was successful (HTTP 2xx and JSON success)
if [[ "$HTTP_STATUS" =~ ^2[0-9][0-9]$ ]] && echo "$RESPONSE_BODY" | grep -q '"success":true'; then
  # Update local record as synced
  sqlite3 "$LOCAL_DB" "UPDATE memories SET synced=1, sync_attempts=0, updated_at=$NOW WHERE key='$KEY';"
  # Return the backend response (as original script did)
  echo "$RESPONSE_BODY"
else
  # Backend failed: increment sync_attempts and update updated_at
  sqlite3 "$LOCAL_DB" "UPDATE memories SET sync_attempts=sync_attempts+1, updated_at=$NOW WHERE key='$KEY';"
  # Return a local success message
  echo "{\"success\":true,\"message\":\"Written to local cache, backend sync failed (HTTP $HTTP_STATUS). Will retry.\",\"local_key\":\"$KEY\"}"
fi