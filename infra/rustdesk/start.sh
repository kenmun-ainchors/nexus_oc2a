#!/bin/bash
# RustDesk server startup — waits for Docker daemon then starts containers
# Loaded by LaunchAgent: com.ainchors.rustdesk.plist

DOCKER="/usr/local/bin/docker"
COMPOSE_DIR="/Users/ainchorsangiefpl/.openclaw/workspace/infra/rustdesk"
LOG="/Users/ainchorsangiefpl/.openclaw/workspace/infra/rustdesk/startup.log"

echo "[$(date)] RustDesk startup triggered" >> "$LOG"

# Wait for Docker daemon (up to 120s)
for i in $(seq 1 24); do
  if "$DOCKER" info &>/dev/null 2>&1; then
    echo "[$(date)] Docker ready after $((i*5))s" >> "$LOG"
    break
  fi
  echo "[$(date)] Waiting for Docker... ($i/24)" >> "$LOG"
  sleep 5
done

# Start compose stack
cd "$COMPOSE_DIR"
"$DOCKER" compose up -d >> "$LOG" 2>&1
echo "[$(date)] Docker compose up exit: $?" >> "$LOG"
