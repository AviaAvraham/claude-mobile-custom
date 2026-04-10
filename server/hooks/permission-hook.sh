#!/bin/bash
# Claude Code PermissionRequest hook — forwards to mobile relay server
input=$(cat)

# Check if server is running
curl -sf http://localhost:4090/health >/dev/null 2>&1 || exit 0

# POST the full hook input, block until server responds with decision
result=$(curl -sf -X POST http://localhost:4090/permission \
  -H "Content-Type: application/json" \
  -d "$input" \
  --max-time 305)

[ $? -eq 0 ] && [ -n "$result" ] && echo "$result"
