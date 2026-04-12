#!/bin/bash
# Register session with mobile relay server
# Usage: bash register.sh <session_id>

SESSION_ID="${1:-$CLAUDE_SESSION_ID}"

if [ -z "$SESSION_ID" ]; then
  echo "ERROR: session_id required"
  exit 1
fi

# Write PowerShell script to temp file
PS_SCRIPT=/tmp/find_claude_$$.ps1
cat > "$PS_SCRIPT" << PSEOF
# Strategy 1: find claude.exe with this session_id in command line (resumed sessions)
\$procs = Get-CimInstance Win32_Process -Filter "Name='claude.exe'"
\$match = \$procs | Where-Object { \$_.CommandLine -like '*${SESSION_ID}*' } | Select-Object -First 1
if (\$match) { Write-Output \$match.ProcessId; exit }

# Strategy 2: find bare interactive claude.exe (no -p flag, no --resume)
\$bare = \$procs | Where-Object {
  \$_.CommandLine -notlike '* -p *' -and \$_.CommandLine -notlike '* -p"*' -and \$_.CommandLine -notlike '*--resume*'
}
if (\$bare -and \$bare.Count -eq 1) { Write-Output \$bare.ProcessId; exit }
if (\$bare -and -not \$bare.Count) { Write-Output \$bare.ProcessId; exit }
PSEOF

CLAUDE_PID=$(/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT" 2>/dev/null | tr -d '\r')
rm -f "$PS_SCRIPT"

if [ -z "$CLAUDE_PID" ] || echo "$CLAUDE_PID" | grep -q '[^0-9]'; then
  echo "WARNING: Could not find claude.exe, registering without PID"
  CLAUDE_PID=""
fi

curl -sf -X POST http://localhost:4090/register \
  -H "Content-Type: application/json" \
  -d "{\"session_id\":\"$SESSION_ID\",\"project_dir\":\"$(pwd)\",\"pid\":${CLAUDE_PID:-null}}"
