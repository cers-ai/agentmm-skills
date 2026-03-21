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
  tags TEXT,        -- comma-separated string, empty if none
  context TEXT,
  related TEXT,     -- comma-separated string, empty if none
  created_at INTEGER,
  updated_at INTEGER,
  synced INTEGER DEFAULT 0,
  sync_attempts INTEGER DEFAULT 0
);
EOF
  fi
}

# Parse arguments
KEY=""
TAGS=""
CONTEXT_FILTER=""
LIMIT=100
OFFSET=0
SORT="created_at"

while [[ $# -gt 0 ]]; do
  case $1 in
    --key)
      KEY="$2"
      shift 2
      ;;
    --tags)
      TAGS="$2"
      shift 2
      ;;
    --context-filter)
      CONTEXT_FILTER="$2"
      shift 2
      ;;
    --limit)
      LIMIT="$2"
      shift 2
      ;;
    --offset)
      OFFSET="$2"
      shift 2
      ;;
    --sort)
      SORT="$2"
      shift 2
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

# Initialize local DB
init_local_db

# If a specific key is requested, try local first then backend
if [[ -n "${KEY:-}" ]]; then
  # Try to get from local DB
  LOCAL_RESULT=$(sqlite3 "$LOCAL_DB" "SELECT key, content, tags, context, related, created_at, updated_at FROM memories WHERE key='$KEY';")
  if [ -n "$LOCAL_RESULT" ]; then
    # Parse the local result (fields are separated by | because we used concat with | in the query? Actually we didn't; we selected columns separately.
    # sqlite3 outputs columns separated by | by default? No, by default it uses | only if you set .mode list. Default is to separate by spaces? Actually, the default mode is "list" which uses | as separator? Let's check: In the terminal, running sqlite3 and then SELECT ... gives columns separated by |? I think the default is to use | as separator when output is not going to a terminal? To be safe, let's change the SELECT to use a explicit separator.
    # We'll redo the query with CONCAT and a separator.
    # But we can also use sqlite3's column names and process line by line with IFS set to | if we ensure the output uses |.
    # Let's change the query to: SELECT key || '|' || content || '|' || tags || '|' || context || '|' || related || '|' || created_at || '|' || updated_at ...
    # However, if any field is NULL, the whole concatenation becomes NULL. We need to handle NULLs.
    # Instead, let's use sqlite3's built-in JSON functions if available (since we have sqlite3 3.45+ which supports JSON1). We can do:
    #   SELECT json_object('key', key, 'content', content, 'tags', tags, 'context', context, 'related', related, 'created_at', created_at, 'updated_at', updated_at) FROM memories WHERE key='$KEY';
    # This will return a JSON object for the row, or NULL if any field is NULL? Actually json_object will ignore NULL values? It will include them as null.
    # We'll use that if available, else fallback to manual parsing.
    # Given the time, let's assume no NULLs for simplicity (except tags, context, related can be empty string).
    # We'll set IFS to '|' and use a query that concatenates with '|' but we need to replace NULL with empty string.
    # We can use COALESCE(field, '') in the concatenation.
    LOCAL_RESULT=$(sqlite3 "$LOCAL_DB" "SELECT 
        COALESCE(key, '') || '|' || 
        COALESCE(content, '') || '|' || 
        COALESCE(tags, '') || '|' || 
        COALESCE(context, '') || '|' || 
        COALESCE(related, '') || '|' || 
        CAST(COALESCE(created_at, 0) AS TEXT) || '|' || 
        CAST(COALESCE(updated_at, 0) AS TEXT)
        FROM memories WHERE key='$KEY';")
    if [ -n "$LOCAL_RESULT" ]; then
      IFS='|' read -r l_key l_content l_tags l_context l_related l_created_at l_updated_at <<< "$LOCAL_RESULT"
      # Build JSON object for memory
      MEMORY_JSON="{"
      MEMORY_JSON+="\"key\":\"$l_key\","
      MEMORY_JSON+="\"content\":\"$(echo "$l_content" | sed 's/\"/\\\"/g')\","
      if [[ -n "$l_tags" ]]; then
        # Tags are stored as comma-separated string, convert to JSON array
        TAGS_JSON=$(echo "$l_tags" | jq -R 'split(",")' 2>/dev/null || echo "[]")
        MEMORY_JSON+="\"tags\":$TAGS_JSON,"
      else
        MEMORY_JSON+="\"tags\":[],"
      fi
      if [[ -n "$l_context" ]]; then
        MEMORY_JSON+="\"context\":\"$(echo "$l_context" | sed 's/\"/\\\"/g')\","
      else
        MEMORY_JSON+="\"context\":\"\","
      fi
      if [[ -n "$l_related" ]]; then
        RELATED_JSON=$(echo "$l_related" | jq -R 'split(",")' 2>/dev/null || echo "[]")
        MEMORY_JSON+="\"related\":$RELATED_JSON"
      else
        MEMORY_JSON+="\"related\":[]"
      fi
      MEMORY_JSON+="}"
      # Wrap in success
      echo "{\"success\":true,\"memory\":$MEMORY_JSON}"
      exit 0
    fi
    # If local result empty (should not happen if [ -n "$LOCAL_RESULT" ]), fall through to backend
  fi
  # If not found locally, fall through to backend
fi

# If we reach here, either no key was requested or key not found locally.
# We'll query the backend.

# Build query string
QUERY=""
if [[ -n "${KEY:-}" ]]; then
  QUERY="key=$KEY"
fi
if [[ -n "${TAGS:-}" ]]; then
  if [[ -n "$QUERY" ]]; then
    QUERY="$QUERY&tags=$TAGS"
  else
    QUERY="tags=$TAGS"
  fi
fi
if [[ -n "${CONTEXT_FILTER:-}" ]]; then
  if [[ -n "$QUERY" ]]; then
    QUERY="$QUERY&context=$CONTEXT_FILTER"
  else
    QUERY="context=$CONTEXT_FILTER"
  fi
fi
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
if [[ -n "${SORT:-}" ]]; then
  if [[ -n "$QUERY" ]]; then
    QUERY="$QUERY&sort=$SORT"
  else
    QUERY="sort=$SORT"
  fi
fi

# If QUERY is empty, we just hit the endpoint without query (get all)
if [[ -n "$QUERY" ]]; then
  BACKEND_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET "$API_BASE/memory?$QUERY" \
    -H "Authorization: Bearer $API_KEY") || true
else
  BACKEND_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET "$API_BASE/memory" \
    -H "Authorization: Bearer $API_KEY") || true
fi

# Extract HTTP status and body
HTTP_STATUS=$(echo "$BACKEND_RESPONSE" | tail -n1 | sed 's/^HTTP_STATUS://')
RESPONSE_BODY=$(echo "$BACKEND_RESPONSE" | sed '$d')

# If the backend call was successful, we may want to cache the result(s) locally.
if [[ "$HTTP_STATUS" =~ ^2[0-9][0-9]$ ]]; then
  # We need to parse the response to extract memory(ies) and store them in local DB.
  # For simplicity, we will only cache if we requested a single key (i.e., KEY is set).
  # For list requests, we do not cache to avoid complexity.
  if [[ -n "${KEY:-}" ]]; then
    # Expect response format: { "success": true, "memory": { ... } }
    # Extract the memory object
    MEMORY_OBJECT=$(echo "$RESPONSE_BODY" | jq -c '.memory // empty')
    if [ -n "$MEMORY_OBJECT" ] && [ "$MEMORY_OBJECT" != "null" ]; then
      # Extract fields from the memory object
      MEM_KEY=$(echo "$MEMORY_OBJECT" | jq -r '.key // empty')
      MEM_CONTENT=$(echo "$MEMORY_OBJECT" | jq -r '.content // empty')
      MEM_TAGS=$(echo "$MEMORY_OBJECT" | jq -r '.tags // [] | join(",")' 2>/dev/null || echo "")
      MEM_CONTEXT=$(echo "$MEMORY_OBJECT" | jq -r '.context // empty')
      MEM_RELATED=$(echo "$MEMORY_OBJECT" | jq -r '.related // [] | join(",")' 2>/dev/null || echo "")
      MEM_CREATED_AT=$(echo "$MEMORY_OBJECT" | jq -r '.created_at // 0')
      MEM_UPDATED_AT=$(echo "$MEMORY_OBJECT" | jq -r '.updated_at // 0')
      # Insert or replace into local DB
      sqlite3 "$LOCAL_DB" <<EOF
INSERT OR REPLACE INTO memories 
(key, content, tags, context, related, created_at, updated_at, synced, sync_attempts)
VALUES (
  '$MEM_KEY',
  '$MEM_CONTENT',
  '$MEM_TAGS',
  '$MEM_CONTEXT',
  '$MEM_RELATED',
  $MEM_CREATED_AT,
  $MEM_UPDATED_AT,
  1,   -- Mark as synced since we just got it from backend
  0
);
EOF
    fi
  fi
  # Return the backend response as is
  echo "$RESPONSE_BODY"
else
  # Backend failed
  echo "$RESPONSE_BODY"
fi