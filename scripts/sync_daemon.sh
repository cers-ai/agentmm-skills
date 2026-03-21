#!/bin/bash
set -euo pipefail

API_BASE="https://vszkvwrcccfyyipdtcvr.supabase.co/functions/v1/agent-api"
API_KEY="amm_sk_c37620f5a839416398b9364512aa8a17"
LOCAL_DB="/root/.openclaw/workspace/skills/AgentMM/data/local_memory.db"
LOG_FILE="/root/.openclaw/workspace/skills/AgentMM/data/sync_daemon.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Ensure local DB exists
if [ ! -f "$LOCAL_DB" ]; then
  log "Local database not found at $LOCAL_DB. Exiting."
  exit 1
fi

log "Starting sync daemon for AgentMM local cache."

while true; do
  # Find records that are not synced or have sync attempts > 0 (i.e., failed syncs)
  # We limit to 50 records per cycle to avoid long-running transactions.
  UNSYNCED=$(sqlite3 "$LOCAL_DB" "SELECT key FROM memories WHERE synced=0 OR sync_attempts>0 LIMIT 50;" 2>>"$LOG_FILE")
  
  if [ -z "$UNSYNCED" ]; then
    # No unsynced records, sleep and continue
    sleep 30
    continue
  fi
  
  log "Found unsynced records: $UNSYNCED"
  
  for KEY in $UNSYNCED; do
    # Fetch the record from local DB
    RECORD=$(sqlite3 "$LOCAL_DB" "SELECT key, content, tags, context, related, created_at, updated_at FROM memories WHERE key='$KEY';" 2>>"$LOG_FILE")
    if [ -z "$RECORD" ]; then
      log "Record $KEY not found in local DB (maybe deleted). Skipping."
      continue
    fi
    
    # Parse the record (fields separated by | because we will use a separator in the SELECT below? Actually we didn't use a separator in the SELECT above.
    # Let's change the SELECT to use a separator. But for simplicity, we'll assume no spaces in key and use the fact that sqlite3 outputs in list mode with | separator? 
    # We'll instead use the same method as in read_memory.sh: concatenate with a separator and replace NULLs.
    # We'll do it inline:
    PARSED=$(sqlite3 "$LOCAL_DB" "SELECT 
        COALESCE(key, '') || '|' || 
        COALESCE(content, '') || '|' || 
        COALESCE(tags, '') || '|' || 
        COALESCE(context, '') || '|' || 
        COALESCE(related, '') || '|' || 
        CAST(COALESCE(created_at, 0) AS TEXT) || '|' || 
        CAST(COALESCE(updated_at, 0) AS TEXT)
        FROM memories WHERE key='$KEY';" 2>>"$LOG_FILE")
    if [ -z "$PARSED" ]; then
      log "Failed to parse record $KEY. Skipping."
      continue
    fi
    
    IFS='|' read -r l_key l_content l_tags l_context l_related l_created_at l_updated_at <<< "$PARSED"
    
    # Convert tags and related from stored JSON array strings to JSON arrays for backend
    TAGS_JSON="$l_tags"
    RELATED_JSON="$l_related"
    # If they are empty strings, set to empty array
    if [ -z "$l_tags" ]; then
      TAGS_JSON="[]"
    fi
    if [ -z "$l_related" ]; then
      RELATED_JSON="[]"
    fi
    
    # Build payload
    PAYLOAD="{\"key\":\"$l_key\",\"content\":\"$l_content\"}"
    if [ -n "$l_tags" ] || [ "$l_tags" = "[]" ]; then
      # Only add tags if we have a non-empty array or even empty array to override backend?
      # We'll send the tags as is.
      PAYLOAD="$(echo "$PAYLOAD" | jq --argjson tags "$TAGS_JSON" '. + {tags: $tags}')"
    fi
    if [ -n "$l_context" ]; then
      PAYLOAD="$(echo "$PAYLOAD" | jq --arg context "$l_context" '. + {context: $context}')"
    fi
    if [ -n "$l_related" ] || [ "$l_related" = "[]" ]; then
      PAYLOAD="$(echo "$PAYLOAD" | jq --argjson related "$RELATED_JSON" '. + {related: $related}')"
    fi
    
    # Attempt to sync
    BACKEND_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$API_BASE/memory" \
      -H "Authorization: Bearer $API_KEY" \
      -H "Content-Type: application/json" \
      -d "$PAYLOAD") || true
    
    HTTP_STATUS=$(echo "$BACKEND_RESPONSE" | tail -n1 | sed 's/^HTTP_STATUS://')
    RESPONSE_BODY=$(echo "$BACKEND_RESPONSE" | sed '$d')
    
    if [[ "$HTTP_STATUS" =~ ^2[0-9][0-9]$ ]] && echo "$RESPONSE_BODY" | grep -q '"success":true'; then
      # Success: mark as synced, reset sync_attempts, update updated_at to now
      NOW=$(date +%s)
      sqlite3 "$LOCAL_DB" "UPDATE memories SET synced=1, sync_attempts=0, updated_at=$NOW WHERE key='$l_key';" 2>>"$LOG_FILE"
      log "Successfully synced record $l_key."
    else
      # Failed: increment sync_attempts, update updated_at
      NOW=$(date +%s)
      sqlite3 "$LOCAL_DB" "UPDATE memories SET sync_attempts=sync_attempts+1, updated_at=$NOW WHERE key='$l_key';" 2>>"$LOG_FILE"
      log "Failed to sync record $l_key (HTTP $HTTP_STATUS). Response: $RESPONSE_BODY"
    fi
  done
  
  # Sleep before next cycle
  sleep 30
done