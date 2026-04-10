#!/bin/bash
# Claude Code UserPromptSubmit hook — drains pending phone messages

# Check if server is running
curl -sf http://localhost:4090/health >/dev/null 2>&1 || exit 0

input=$(cat)

# Extract session_id with grep/sed (no jq dependency)
session_id=$(echo "$input" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:.*"\([^"]*\)"/\1/')
[ -z "$session_id" ] && exit 0

# Check for pending phone messages
result=$(curl -sf "http://localhost:4090/drain-messages?session_id=$session_id" 2>/dev/null) || exit 0

[ -n "$result" ] && [ "$result" != "null" ] && echo "$result"
exit 0
