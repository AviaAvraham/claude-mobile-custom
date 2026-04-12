#!/bin/bash
# Claude Mobile Custom - Install Script
# Run this after cloning the repo: bash install.sh

set -e

# Convert paths for Windows (Git Bash uses /c/Users but Node needs C:/Users)
to_native_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1" | sed 's/\\/\//g'
  else
    echo "$1"
  fi
}

REPO_DIR="$(to_native_path "$(cd "$(dirname "$0")" && pwd)")"
SETTINGS_FILE="$(to_native_path "$HOME/.claude/settings.json")"

echo "Installing Claude Mobile Custom..."
echo "Repo: $REPO_DIR"

# 1. Install server dependencies
echo "Installing server dependencies..."
cd "$REPO_DIR/server" && npm install

# 2. Register plugin in settings.json
echo "Registering plugin..."
if [ ! -f "$SETTINGS_FILE" ]; then
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  echo '{}' > "$SETTINGS_FILE"
fi

# Use node to safely merge into settings.json
node -e "
const fs = require('fs');
const path = '$SETTINGS_FILE';
const repoDir = '${REPO_DIR}'.replace(/\\\\/g, '/');
const settings = JSON.parse(fs.readFileSync(path, 'utf8'));

// Add marketplace
if (!settings.extraKnownMarketplaces) settings.extraKnownMarketplaces = {};
settings.extraKnownMarketplaces['local-plugins'] = {
  source: {
    source: 'directory',
    path: repoDir
  }
};

// Enable plugin
if (!settings.enabledPlugins) settings.enabledPlugins = {};
settings.enabledPlugins['mobile-custom@local-plugins'] = true;

// Add hooks if not present
if (!settings.hooks) settings.hooks = {};

const hooks = {
  PermissionRequest: [{
    matcher: '',
    hooks: [{ type: 'command', command: 'bash ' + repoDir + '/server/hooks/permission-hook.sh', timeout: 310 }]
  }],
  PreToolUse: [{
    matcher: '',
    hooks: [{ type: 'command', command: 'bash ' + repoDir + '/server/hooks/activity-hook.sh', timeout: 3, async: true }]
  }],
  Stop: [{
    matcher: '',
    hooks: [{ type: 'command', command: 'bash ' + repoDir + '/server/hooks/stop-hook.sh', timeout: 130 }]
  }]
};

for (const [event, config] of Object.entries(hooks)) {
  if (!settings.hooks[event]) {
    settings.hooks[event] = config;
  } else {
    // Check if our hook is already there
    const existing = settings.hooks[event].some(h =>
      h.hooks?.some(hh => hh.command?.includes('claude-mobile-custom'))
    );
    if (!existing) {
      settings.hooks[event].push(...config);
    }
  }
}

// NOTE: statusLine is NOT added automatically. If the user wants /usage
// support from phone, they can configure it manually via /mobile-custom:configure

fs.writeFileSync(path, JSON.stringify(settings, null, 2));
console.log('Settings updated.');
"

echo ""
echo "Done! Restart Claude Code, then run:"
echo "  /mobile-custom:setup"
echo ""
echo "This will start the server and show the pairing QR code."
