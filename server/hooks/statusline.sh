#!/bin/bash
# Claude Code statusLine — forwards usage data to mobile relay server
input=$(cat)

# Extract fields with grep/sed
five_hour_pct=$(echo "$input" | grep -o '"five_hour"[^}]*' | grep -o '"used_percentage"[[:space:]]*:[[:space:]]*[0-9.]*' | grep -o '[0-9.]*$')
seven_day_pct=$(echo "$input" | grep -o '"seven_day"[^}]*' | grep -o '"used_percentage"[[:space:]]*:[[:space:]]*[0-9.]*' | grep -o '[0-9.]*$')
five_hour_resets=$(echo "$input" | grep -o '"five_hour"[^}]*' | grep -o '"resets_at"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*$')
seven_day_resets=$(echo "$input" | grep -o '"seven_day"[^}]*' | grep -o '"resets_at"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*$')
context_pct=$(echo "$input" | grep -o '"used_percentage"[[:space:]]*:[[:space:]]*[0-9.]*' | head -1 | grep -o '[0-9.]*$')
session_id=$(echo "$input" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:.*"\([^"]*\)"/\1/')

# Forward to server (non-blocking)
curl -sf -X POST http://localhost:4090/usage-update \
  -H "Content-Type: application/json" \
  -d "{\"session_id\":\"$session_id\",\"five_hour_pct\":${five_hour_pct:-0},\"seven_day_pct\":${seven_day_pct:-0},\"five_hour_resets\":${five_hour_resets:-0},\"seven_day_resets\":${seven_day_resets:-0},\"context_pct\":${context_pct:-0}}" \
  --max-time 1 >/dev/null 2>&1 &

# Output nothing — keeps the CLI status line unchanged
