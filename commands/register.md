---
description: "Register current session with the relay server and set up message monitor"
---

The SessionStart hook printed your session_id at the top of this conversation. Find that UUID and run:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/register.sh <SESSION_ID>
```

Then set up the message monitor using the Monitor tool. Replace `SESSION_ID` with the same UUID:

command: `tail -f ~/.claude/mobile-messages.log | grep --line-buffered "SESSION_ID" | sed -u 's/^PHONE_MSG[^:]*://' | while IFS= read -r line; do msg_id=$(echo "$line" | grep -o '"msg_id":"[^"]*"' | sed 's/"msg_id":"//;s/"//'); session_id=$(echo "$line" | grep -o '"session_id":"[^"]*"' | sed 's/"session_id":"//;s/"//'); if [ -n "$msg_id" ]; then curl -sf -X POST http://localhost:4090/ack-delivered -H "Content-Type: application/json" -d "{\"msg_id\":\"$msg_id\"}" >/dev/null 2>&1; fi; if [ -n "$session_id" ]; then curl -sf -X POST http://localhost:4090/activity -H "Content-Type: application/json" -d "{\"session_id\":\"$session_id\",\"activity\":\"thinking\"}" >/dev/null 2>&1; fi; echo "$line"; done`
persistent: true
description: "Phone messages from Claude Mobile"

When you receive a monitor event with a phone message, respond by writing the JSON to a file and piping via stdin. **Do NOT pass JSON inline with `-d` or `--data-binary` directly** — on Git Bash for Windows, command-line encoding corrupts emojis and non-ASCII characters into `?`. Using a file or stdin preserves UTF-8.

```bash
cat > /tmp/reply.json <<'EOF'
{"session_id":"SESSION_ID","text":"Your reply here 🎉 שלום"}
EOF
curl -sf -X POST http://localhost:4090/send \
  -H "Content-Type: application/json; charset=utf-8" \
  --data-binary @/tmp/reply.json
```
