#!/bin/zsh
# AInchors Startup Checks
# Runs once on gateway boot (via LaunchAgent ai.ainchors.startup-checks).
# Waits for gateway to be ready, then validates fallback chain.

WORKSPACE="$HOME/.openclaw/workspace"
LOG="$HOME/.openclaw/logs/startup-checks.log"

mkdir -p "$(dirname $LOG)"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Startup checks beginning..." >> "$LOG"

# Wait up to 60s for gateway to respond
for i in {1..12}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:18789/health 2>/dev/null || echo "000")
  if [[ "$STATUS" == "200" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Gateway ready. Running fallback chain validation..." >> "$LOG"
    break
  fi
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Gateway not ready (attempt $i/12). Waiting 5s..." >> "$LOG"
  sleep 5
done

# Run fallback chain validation
zsh "$WORKSPACE/scripts/validate-fallback-chain.sh" >> "$LOG" 2>&1
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Fallback chain: all links OK" >> "$LOG"
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Fallback chain: one or more links FAILED — check state/fallback-chain-status.json" >> "$LOG"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Startup checks complete." >> "$LOG"
