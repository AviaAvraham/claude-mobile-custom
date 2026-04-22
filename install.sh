#!/bin/bash
# Claude Mobile Custom - Install Script
# Run this after cloning the repo: bash install.sh
# Copies plugin files to a stable location (~/.claude-mobile-custom/) so the
# install doesn't depend on where you cloned the repo.

set -e

# Convert paths for Windows (Git Bash uses /c/Users but Node needs C:/Users)
to_native_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1" | sed 's/\\/\//g'
  else
    echo "$1"
  fi
}

SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR_UNIX="$HOME/.claude-mobile-custom"
INSTALL_DIR="$(to_native_path "$INSTALL_DIR_UNIX")"
SETTINGS_FILE="$(to_native_path "$HOME/.claude/settings.json")"

echo "Installing Claude Mobile Custom..."
echo "  Source: $SOURCE_DIR"
echo "  Install: $INSTALL_DIR"

# 1. Copy plugin files to stable install location
echo "Copying files..."
mkdir -p "$INSTALL_DIR_UNIX"
for d in server commands scripts .claude-plugin; do
  [ -d "$SOURCE_DIR/$d" ] || continue
  rm -rf "$INSTALL_DIR_UNIX/$d"
  cp -r "$SOURCE_DIR/$d" "$INSTALL_DIR_UNIX/$d"
done

# 2. Install server dependencies in the install location
echo "Installing server dependencies..."
cd "$INSTALL_DIR_UNIX/server" && npm install

# 3. Register plugin in settings.json
echo "Registering plugin..."
if [ ! -f "$SETTINGS_FILE" ]; then
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  echo '{}' > "$SETTINGS_FILE"
fi

# Use node to safely merge into settings.json
node -e "
const fs = require('fs');
const path = '$SETTINGS_FILE';
const installDir = '${INSTALL_DIR}'.replace(/\\\\/g, '/');
const settings = JSON.parse(fs.readFileSync(path, 'utf8'));

// Add marketplace pointing at stable install dir
if (!settings.extraKnownMarketplaces) settings.extraKnownMarketplaces = {};
settings.extraKnownMarketplaces['local-plugins'] = {
  source: {
    source: 'directory',
    path: installDir
  }
};

// Enable plugin
if (!settings.enabledPlugins) settings.enabledPlugins = {};
settings.enabledPlugins['mobile-custom@local-plugins'] = true;

// Add hooks
if (!settings.hooks) settings.hooks = {};

const hooks = {
  PermissionRequest: [{
    matcher: '',
    hooks: [{ type: 'command', command: 'bash ' + installDir + '/server/hooks/permission-hook.sh', timeout: 310 }]
  }],
  PreToolUse: [{
    matcher: '',
    hooks: [{ type: 'command', command: 'bash ' + installDir + '/server/hooks/activity-hook.sh', timeout: 3, async: true }]
  }],
  Stop: [{
    matcher: '',
    hooks: [{ type: 'command', command: 'bash ' + installDir + '/server/hooks/stop-hook.sh', timeout: 130 }]
  }],
  SessionStart: [{
    matcher: '',
    hooks: [{ type: 'command', command: 'bash ' + installDir + '/server/hooks/session-start-hook.sh', timeout: 5 }]
  }]
};

for (const [event, config] of Object.entries(hooks)) {
  if (!settings.hooks[event]) {
    settings.hooks[event] = config;
  } else {
    // Remove any existing mobile-custom hooks (match old paths or new), then add fresh ones
    settings.hooks[event] = settings.hooks[event].filter(h =>
      !h.hooks?.some(hh => hh.command?.includes('claude-mobile-custom'))
    );
    settings.hooks[event].push(...config);
  }
}

// NOTE: statusLine is NOT added automatically. If the user wants /usage
// support from phone, they can configure it manually via /mobile-custom:configure

fs.writeFileSync(path, JSON.stringify(settings, null, 2));
console.log('Settings updated.');
"

echo ""
echo "Done! You can now delete the cloned repo — the plugin is installed at:"
echo "  $INSTALL_DIR"
echo ""
echo "Restart Claude Code, then run: /mobile-custom:setup"
