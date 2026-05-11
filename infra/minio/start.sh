#!/bin/bash
# MinIO startup — runs via LaunchAgent at login
# Waits for Colima, starts MinIO container

DOCKER="/opt/homebrew/bin/docker-compose"
COMPOSE_DIR="/Users/ainchorsangiefpl/.openclaw/workspace/infra/minio"
LOG="$COMPOSE_DIR/startup.log"

echo "[$(date)] MinIO startup triggered" >> "$LOG"

# Wait for Colima
for i in $(seq 1 36); do
  if DOCKER_CONTEXT=colima /opt/homebrew/bin/docker info &>/dev/null 2>&1; then
    echo "[$(date)] Colima ready" >> "$LOG"; break
  fi
  sleep 5
done

export DOCKER_CONTEXT=colima
cd "$COMPOSE_DIR"
"$DOCKER" up -d >> "$LOG" 2>&1
echo "[$(date)] MinIO started: $?" >> "$LOG"
