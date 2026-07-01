#!/bin/zsh
# OpenClaw update wrapper — runs under launchd outside gateway process tree.
# Created: 2026-07-01 22:10 AEST
# Logs to: /tmp/openclaw-update-2026-07-01-v4.log

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${HOME}/.local/bin"
LOG="/tmp/openclaw-update-2026-07-01-v4.log"
exec > "$LOG" 2>&1

set -euo pipefail

UID_NUM=$(id -u)
PLIST="${HOME}/Library/LaunchAgents/ai.openclaw.gateway.plist"
OPENCLAW="/opt/homebrew/bin/openclaw"

echo "=== OpenClaw Update Wrapper v4 ==="
echo "Started: $(date -Iseconds)"
echo "User: $(whoami)"
echo "UID: $UID_NUM"
echo "PATH: $PATH"
echo "OPENCLAW: $OPENCLAW"
echo ""

if [ ! -x "$OPENCLAW" ]; then
  echo "ERROR: openclaw binary not found at $OPENCLAW"
  exit 1
fi

# 1. Make sure gateway is stopped
echo "[1/5] Ensuring OpenClaw gateway is stopped..."
launchctl bootout "gui/${UID_NUM}/ai.openclaw.gateway" 2>/dev/null || true
sleep 10

# 2. Run update
echo "[2/5] Running openclaw update --yes..."
"$OPENCLAW" update --yes

# 3. Start gateway service
echo "[3/5] Starting OpenClaw gateway..."
if [ -f "$PLIST" ]; then
    launchctl bootstrap "gui/${UID_NUM}" "$PLIST" || true
else
    echo "Plist not found at $PLIST; attempting openclaw start..."
    "$OPENCLAW" start || true
fi
sleep 15

# 4. Verify gateway is up
echo "[4/5] Verifying gateway health..."
for i in {1..24}; do
  if curl -s http://localhost:18789/health 2>/dev/null | grep -q '"status":"ok"'; then
    echo "Gateway healthy after $i attempts."
    break
  fi
  echo "Attempt $i: gateway not ready yet..."
  sleep 5
done

# 5. Run doctor
echo "[5/5] Running openclaw doctor..."
"$OPENCLAW" doctor --recover 2>&1 || "$OPENCLAW" doctor 2>&1 || true

echo ""
echo "Finished: $(date -Iseconds)"
