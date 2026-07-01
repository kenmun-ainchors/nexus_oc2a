: 
#!/bin/zsh
# OpenClaw update wrapper — runs outside gateway process tree.
# Created: 2026-07-01 22:00 AEST
# Logs to: /tmp/openclaw-update-2026-07-01-v2.log

LOG="/tmp/openclaw-update-2026-07-01-v2.log"
exec > "$LOG" 2>&1

set -euo pipefail

UID_NUM=$(id -u)
PLIST="${HOME}/Library/LaunchAgents/ai.openclaw.gateway.plist"

echo "=== OpenClaw Update Wrapper v2 ==="
echo "Started: $(date -Iseconds)"
echo "User: $(whoami)"
echo "UID: $UID_NUM"
echo ""

# 1. Stop gateway service safely
echo "[1/5] Stopping OpenClaw gateway..."
if launchctl list ai.openclaw.gateway >/dev/null 2>&1; then
    echo "Gateway job found; booting out..."
    launchctl bootout "gui/${UID_NUM}/ai.openclaw.gateway" || true
else
    echo "Gateway job not found in launchctl list; may already be stopped."
fi
sleep 8

# 2. Run update
echo "[2/5] Running openclaw update --yes..."
openclaw update --yes

# 3. Start gateway service
echo "[3/5] Starting OpenClaw gateway..."
if [ -f "$PLIST" ]; then
    launchctl bootstrap "gui/${UID_NUM}" "$PLIST" || true
else
    echo "Plist not found at $PLIST; attempting openclaw start..."
    openclaw start || true
fi
sleep 12

# 4. Verify gateway is up
echo "[4/5] Verifying gateway health..."
for i in {1..18}; do
  if curl -s http://localhost:18789/health 2>/dev/null | grep -q '"status":"ok"'; then
    echo "Gateway healthy after $i attempts."
    break
  fi
  echo "Attempt $i: gateway not ready yet..."
  sleep 5
done

# 5. Run doctor
echo "[5/5] Running openclaw doctor..."
openclaw doctor --recover 2>&1 || openclaw doctor 2>&1 || true

echo ""
echo "Finished: $(date -Iseconds)"
