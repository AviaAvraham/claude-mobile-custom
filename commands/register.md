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

3. Set up the message monitor. Use the Monitor tool with EXACTLY this command (copy-paste, do not modify):

   command: `tail -f ~/.claude/mobile-messages.log | grep --line-buffered "PHONE_MSG" | sed -u 's/^PHONE_MSG[^:]*://' | while IFS= read -r line; do msg_id=$(echo "$line" | grep -o '"msg_id":"[^"]*"' | sed 's/"msg_id":"//;s/"//'); session_id=$(echo "$line" | grep -o '"session_id":"[^"]*"' | sed 's/"session_id":"//;s/"//'); if [ -n "$msg_id" ]; then curl -sf -X POST http://localhost:4090/ack-delivered -H "Content-Type: application/json" -d "{\"msg_id\":\"$msg_id\"}" >/dev/null 2>&1; fi; if [ -n "$session_id" ]; then curl -sf -X POST http://localhost:4090/activity -H "Content-Type: application/json" -d "{\"session_id\":\"$session_id\",\"activity\":\"thinking\"}" >/dev/null 2>&1; fi; echo "$line"; done`
   persistent: true
   description: "Phone messages from Claude Mobile"

   IMPORTANT: This single command does everything — tails the log, sends delivery acknowledgements (for double checkmarks), sends activity status (for thinking indicator), and outputs messages as monitor events. Do NOT call /ack-delivered separately. Do NOT set up a simpler monitor without the while loop. The ack-delivered and activity calls are embedded IN the monitor command.

4. Confirm registration and show current session count from health endpoint.

## Responding to phone messages

When you receive a monitor event with a phone message, respond using the `/send` endpoint:

```bash
curl -sf -X POST http://localhost:4090/send \
  -H "Content-Type: application/json" \
  -d '{"session_id":"SESSION_ID_FROM_MESSAGE","text":"Your reply here"}'
```

Replace `SESSION_ID_FROM_MESSAGE` with the session_id from the monitor event, and `Your reply here` with your response.

## Server commands handled by the server

These commands are handled directly by the server when the phone sends them — no action needed from you:
- `/usage` — server replies with usage stats automatically
