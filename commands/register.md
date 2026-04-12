---
description: "Register current session with the relay server and set up message monitor"
---

# Register

Register the current Claude Code session with the running relay server and set up the message monitor.

## Instructions

1. Check if server is running:
   ```bash
   curl -sf http://localhost:4090/health
   ```
   If not running, tell user to run `/mobile-custom:setup` or `/mobile-custom:restart` first.

2. Register the current session:
   ```bash
   curl -sf -X POST http://localhost:4090/register \
     -H "Content-Type: application/json" \
     -d "{\"session_id\":\"$CLAUDE_SESSION_ID\",\"project_dir\":\"$(pwd)\"}"
   ```

3. Set up the message monitor using the Monitor tool. The command MUST include:
   - `tail -f ~/.claude/mobile-messages.log` to watch for messages
   - `grep --line-buffered "PHONE_MSG"` to filter
   - `sed -u 's/^PHONE_MSG[^:]*://'` to strip prefix
   - A while loop that for each line:
     - Extracts `msg_id` and `session_id` from the JSON
     - Calls `curl -sf -X POST http://localhost:4090/ack-delivered` with the msg_id (THIS IS CRITICAL for double checkmarks)
     - Calls `curl -sf -X POST http://localhost:4090/activity` with session_id and activity "thinking"
     - Echoes the line as the monitor event

   The full monitor command:
   ```
   tail -f ~/.claude/mobile-messages.log | grep --line-buffered "PHONE_MSG" | sed -u 's/^PHONE_MSG[^:]*://' | while IFS= read -r line; do msg_id=$(echo "$line" | grep -o '"msg_id":"[^"]*"' | sed 's/"msg_id":"//;s/"//'); session_id=$(echo "$line" | grep -o '"session_id":"[^"]*"' | sed 's/"session_id":"//;s/"//'); if [ -n "$msg_id" ]; then curl -sf -X POST http://localhost:4090/ack-delivered -H "Content-Type: application/json" -d "{\"msg_id\":\"$msg_id\"}" >/dev/null 2>&1; fi; if [ -n "$session_id" ]; then curl -sf -X POST http://localhost:4090/activity -H "Content-Type: application/json" -d "{\"session_id\":\"$session_id\",\"activity\":\"thinking\"}" >/dev/null 2>&1; fi; echo "$line"; done
   ```

   Set persistent: true on the monitor.

4. Confirm registration and show current session count from health endpoint.
