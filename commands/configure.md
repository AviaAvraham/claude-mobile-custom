---
description: "Configure settings (custom tunnel URL)"
argument-hint: "[--url=CUSTOM_TUNNEL_URL]"
---

# Configure

Change Claude Mobile relay server settings.

## Instructions

1. If `--url=` provided, save it:
   ```bash
   echo '{"tunnelUrl":"THE_URL"}' > ~/.claude/mobile-server-config.json
   ```
   Tell user to run `/mobile-custom:restart` for changes to take effect.

2. If no args, show current config:
   ```bash
   cat ~/.claude/mobile-server-config.json 2>/dev/null || echo "No custom config"
   cat ~/.claude/mobile-server-identity.json 2>/dev/null || echo "No identity yet"
   curl -sf http://localhost:4090/health 2>/dev/null || echo "Server not running"
   ```
