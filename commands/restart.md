---
description: "Restart the relay server and tunnel"
---

# Restart

Kill and restart the relay server process + cloudflared tunnel.

## Instructions

Find the repo path. Look for `server/server.js` in:
1. Current working directory and parents
2. `C:/CompilesNew/claude-mobile-custom`
3. Ask user if not found

Then:

1. Kill existing server by PID (do NOT use `taskkill //F //IM node.exe` — that kills ALL node processes including Playwright):
   ```bash
   # Find and kill only the server process
   ps aux | grep "node.*server.js" | grep -v grep | awk '{print $1}' | xargs kill 2>/dev/null
   ps aux | grep cloudflared | grep -v grep | awk '{print $1}' | xargs kill 2>/dev/null
   ```

2. Check for custom URL config:
   ```bash
   cat ~/.claude/mobile-server-config.json 2>/dev/null
   ```

3. Start server:
   - If custom URL configured: `TUNNEL_URL=THE_URL node $REPO_PATH/server/server.js &`
   - Otherwise: `node $REPO_PATH/server/server.js &`

4. Wait for: `curl -sf http://localhost:4090/health`

5. Register current session:
   ```bash
   curl -sf -X POST http://localhost:4090/register \
     -H "Content-Type: application/json" \
     -d "{\"session_id\":\"$CLAUDE_SESSION_ID\",\"project_dir\":\"$(pwd)\"}"
   ```

6. Report status to user.
