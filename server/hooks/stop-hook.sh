#!/bin/bash
# Claude Code Stop hook — sends last response + idle status to phone
input=$(cat)

# Don't interfere with existing stop-hook recursion guard
if echo "$input" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi

# Check if server is running
curl -sf http://localhost:4090/health >/dev/null 2>&1 || exit 0

# Extract session_id and transcript_path
session_id=$(echo "$input" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:.*"\([^"]*\)"/\1/')
transcript_path=$(echo "$input" | grep -o '"transcript_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:.*"\([^"]*\)"/\1/')

# Send transcript to server (extracts last response, sends to phone)
curl -sf -X POST http://localhost:4090/stop \
  -H "Content-Type: application/json" \
  -d "{\"session_id\":\"$session_id\",\"transcript_path\":\"$transcript_path\"}" \
  --max-time 5 >/dev/null 2>&1 &

# Send idle status
curl -sf -X POST http://localhost:4090/activity \
  -H "Content-Type: application/json" \
  -d "{\"session_id\":\"$session_id\",\"activity\":\"idle\"}" \
  --max-time 2 >/dev/null 2>&1 &

exit 0
