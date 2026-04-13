---
description: "First-time setup - install deps, configure hooks, start server, show QR"
argument-hint: "[--url=CUSTOM_TUNNEL_URL]"
---

# Setup

First-time setup for Claude Mobile relay server.

## Instructions

The repo path is available as `${CLAUDE_PLUGIN_ROOT}` — use that directly.

Then:

1. Check Node.js: `node --version`

2. Install deps: `cd ${CLAUDE_PLUGIN_ROOT}/server && npm install`

3. Add hooks to `~/.claude/settings.json` if not already present (adjust paths to `${CLAUDE_PLUGIN_ROOT}`):
   - `PermissionRequest` → `bash ${CLAUDE_PLUGIN_ROOT}/server/hooks/permission-hook.sh` (timeout: 310)
   - `PreToolUse` → `bash ${CLAUDE_PLUGIN_ROOT}/server/hooks/activity-hook.sh` (timeout: 3, async: true)
   - `Stop` → `bash ${CLAUDE_PLUGIN_ROOT}/server/hooks/stop-hook.sh` (timeout: 130)
   - `statusLine` → `bash ${CLAUDE_PLUGIN_ROOT}/server/hooks/statusline.sh` (refreshInterval: 30)

4. If `--url=` provided: `echo '{"tunnelUrl":"THE_URL"}' > ~/.claude/mobile-server-config.json`

5. Start server in background:
   - With custom URL: `TUNNEL_URL=THE_URL node ${CLAUDE_PLUGIN_ROOT}/server/server.js &`
   - Without: `node ${CLAUDE_PLUGIN_ROOT}/server/server.js &`

6. Wait for: `curl -sf http://localhost:4090/health`

7. Run `/mobile-custom:register` to register the session and set up the message monitor.

8. Tell user to open http://localhost:4090/pair and scan QR with phone.
