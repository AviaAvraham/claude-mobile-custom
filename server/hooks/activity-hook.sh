#!/bin/bash
# Claude Code PreToolUse hook — sends activity status to phone (async, non-blocking)

# Check if server is running
curl -sf http://localhost:4090/health >/dev/null 2>&1 || exit 0

input=$(cat)

# Extract session_id and tool_name
session_id=$(echo "$input" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:.*"\([^"]*\)"/\1/')
tool_name=$(echo "$input" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:.*"\([^"]*\)"/\1/')

[ -z "$session_id" ] && exit 0

# Determine activity type from tool name
activity="thinking"
case "$tool_name" in
  Edit|Write|NotebookEdit) activity="coding" ;;
esac

curl -sf -X POST http://localhost:4090/activity \
  -H "Content-Type: application/json" \
  -d "{\"session_id\":\"$session_id\",\"activity\":\"$activity\",\"tool_name\":\"$tool_name\"}" \
  --max-time 2 >/dev/null 2>&1

exit 0
