---
description: "Register current session with the relay server"
---

# Register

Register the current Claude Code session with the running relay server.

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

3. Confirm registration and show current session count from health endpoint.
