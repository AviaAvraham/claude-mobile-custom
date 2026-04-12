#!/bin/bash
input=$(cat)
session_id=$(echo "$input" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:.*"\([^"]*\)"/\1/')
[ -z "$session_id" ] && exit 0
echo "$session_id"
exit 0
