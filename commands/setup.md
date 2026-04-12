---
description: "First-time setup - install deps, configure hooks, start server, show QR"
argument-hint: "[--url=CUSTOM_TUNNEL_URL]"
---

# Setup

First-time setup for Claude Mobile relay server.

## Instructions

Find the repo path. Look for `server/server.js` in:
1. Current working directory and parents
2. `C:/CompilesNew/claude-mobile-custom`
3. Ask user if not found

Then:

1. Check Node.js: `node --version`

2. Install deps: `cd $REPO_PATH/server && npm install`

3. Add hooks to `~/.claude/settings.json` if not already present (adjust paths to `$REPO_PATH`):
   - `PermissionRequest` → `bash $REPO_PATH/server/hooks/permission-hook.sh` (timeout: 310)
   - `PreToolUse` → `bash $REPO_PATH/server/hooks/activity-hook.sh` (timeout: 3, async: true)
   - `Stop` → `bash $REPO_PATH/server/hooks/stop-hook.sh` (timeout: 130)
   - `statusLine` → `bash $REPO_PATH/server/hooks/statusline.sh` (refreshInterval: 30)

4. If `--url=` provided: `echo '{"tunnelUrl":"THE_URL"}' > ~/.claude/mobile-server-config.json`

5. Start server in background:
   - With custom URL: `TUNNEL_URL=THE_URL node $REPO_PATH/server/server.js &`
   - Without: `node $REPO_PATH/server/server.js &`

6. Wait for: `curl -sf http://localhost:4090/health`

7. Register session:
   ```bash
   curl -sf -X POST http://localhost:4090/register \
     -H "Content-Type: application/json" \
     -d "{\"session_id\":\"$CLAUDE_SESSION_ID\",\"project_dir\":\"$(pwd)\"}"
   ```

8. Tell user to open http://localhost:4090/pair and scan QR with phone.
