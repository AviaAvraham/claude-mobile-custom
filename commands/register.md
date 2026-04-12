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
   If not running, find the repo path (look for `server/server.js` in cwd, parents, or ask user) and start it:
   ```bash
   node $REPO_PATH/server/server.js &
   ```
   Wait for health check to pass before continuing.

2. Get your real session ID. Do NOT make up an ID — it MUST match what hooks send internally.

   First try `$CLAUDE_SESSION_ID`:
   ```bash
   echo $CLAUDE_SESSION_ID
   ```

   If empty, find it from the projects folder — your session transcript is at `~/.claude/projects/<sanitized-cwd>/<session-id>.jsonl`:
   ```bash
   ls -t ~/.claude/projects/*//*.jsonl 2>/dev/null | head -1
   ```
   The filename (without .jsonl) is your session ID.

   If that also fails, trigger a hook and check the server log:
   ```bash
   tail -1 ~/.claude/mobile-messages.log
   ```
   The session_id in the output is the real one.

3. Register with the real session ID:
   ```bash
   curl -sf -X POST http://localhost:4090/register \
     -H "Content-Type: application/json" \
     -d "{\"session_id\":\"YOUR_REAL_SESSION_ID\",\"project_dir\":\"$(pwd)\"}"
   ```
   The server will REJECT non-UUID session IDs. If rejected, your ID is wrong.

4. Set up the message monitor. Replace `YOUR_SESSION_ID` with the real UUID from step 2, then use the Monitor tool with this command:

   command: `tail -f ~/.claude/mobile-messages.log | grep --line-buffered "YOUR_SESSION_ID" | sed -u 's/^PHONE_MSG[^:]*://' | while IFS= read -r line; do msg_id=$(echo "$line" | grep -o '"msg_id":"[^"]*"' | sed 's/"msg_id":"//;s/"//'); session_id=$(echo "$line" | grep -o '"session_id":"[^"]*"' | sed 's/"session_id":"//;s/"//'); if [ -n "$msg_id" ]; then curl -sf -X POST http://localhost:4090/ack-delivered -H "Content-Type: application/json" -d "{\"msg_id\":\"$msg_id\"}" >/dev/null 2>&1; fi; if [ -n "$session_id" ]; then curl -sf -X POST http://localhost:4090/activity -H "Content-Type: application/json" -d "{\"session_id\":\"$session_id\",\"activity\":\"thinking\"}" >/dev/null 2>&1; fi; echo "$line"; done`

   CRITICAL: The grep MUST filter by YOUR session ID. Without it, your monitor will interfere with other sessions' activity status on the same machine.
   persistent: true
   description: "Phone messages from Claude Mobile"

   IMPORTANT: This single command does everything — tails the log, sends delivery acknowledgements (for double checkmarks), sends activity status (for thinking indicator), and outputs messages as monitor events. Do NOT call /ack-delivered separately. Do NOT set up a simpler monitor without the while loop. The ack-delivered and activity calls are embedded IN the monitor command.

5. Confirm registration and show current session count from health endpoint.

## Behavior after registration

Once registered with the monitor running, you are connected to a phone user via the relay server.

- When a message comes from the **phone** (via monitor event), reply via `/send` endpoint (see below). The phone user cannot see CLI output.
- When a message comes from the **CLI** (the user typing locally), reply normally on the CLI.
- You can do normal work (edit files, run commands) while chatting. The phone user sees your activity status (thinking/coding) automatically via hooks.
- If the phone user sends a command like `/usage`, the server handles it automatically — no action needed from you.

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
