---
description: "Register current session with the relay server and set up message monitor"
allowed-tools: ["Bash(*)", "Monitor(*)"]
---

# Register

Register the current Claude Code session with the running relay server and set up the message monitor.

## Step 1: Ensure server is running

```!
curl -sf http://localhost:4090/health || echo "SERVER_DOWN"
```

If SERVER_DOWN, find the repo (look for `server/server.js` in cwd, parents, or ask user) and start it:
```!
node $REPO_PATH/server/server.js &
```

## Step 2: Register with real session ID

```!
curl -sf -X POST http://localhost:4090/register -H "Content-Type: application/json" -d "{\"session_id\":\"$CLAUDE_SESSION_ID\",\"project_dir\":\"$(pwd)\"}"
```

If that fails (empty $CLAUDE_SESSION_ID or rejected), the session ID must be a real UUID. Find it from the transcript file:
```!
basename "$(ls -t ~/.claude/projects/*/*.jsonl 2>/dev/null | head -1)" .jsonl
```

Then retry register with that ID.

## Step 3: Set up message monitor

Use the Monitor tool. The grep MUST filter by your session ID to avoid interfering with other sessions:

- command: `tail -f ~/.claude/mobile-messages.log | grep --line-buffered "$CLAUDE_SESSION_ID" | sed -u 's/^PHONE_MSG[^:]*://' | while IFS= read -r line; do msg_id=$(echo "$line" | grep -o '"msg_id":"[^"]*"' | sed 's/"msg_id":"//;s/"//'); session_id=$(echo "$line" | grep -o '"session_id":"[^"]*"' | sed 's/"session_id":"//;s/"//'); if [ -n "$msg_id" ]; then curl -sf -X POST http://localhost:4090/ack-delivered -H "Content-Type: application/json" -d "{\"msg_id\":\"$msg_id\"}" >/dev/null 2>&1; fi; if [ -n "$session_id" ]; then curl -sf -X POST http://localhost:4090/activity -H "Content-Type: application/json" -d "{\"session_id\":\"$session_id\",\"activity\":\"thinking\"}" >/dev/null 2>&1; fi; echo "$line"; done`
- persistent: true
- description: "Phone messages from Claude Mobile"

Replace `$CLAUDE_SESSION_ID` in the grep with the actual UUID if the env var is not available.

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
