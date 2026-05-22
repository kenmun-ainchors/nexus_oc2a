#!/bin/bash
# RustDesk relay startup — uses Colima (not Docker Desktop)
# Colima auto-starts at login via: brew services start colima
# This script starts the hbbs/hbbr containers + nginx relay.
# CHG-XXXX: Fixed 2026-05-22 — Colima socket path, docker-compose (not docker compose).
DOCKER="/opt/homebrew/bin/docker"
COMPOSE="/opt/homebrew/bin/docker-compose"
NGINX="/opt/homebrew/bin/nginx"
COMPOSE_DIR="/Users/ainchorsangiefpl/.openclaw/workspace/infra/rustdesk"
LOG="$COMPOSE_DIR/startup.log"
SOCKET="unix:///Users/ainchorsangiefpl/.colima/default/docker.sock"

echo "[$(date)] RustDesk startup triggered" >> "$LOG"

# Wait for Colima docker socket
for i in $(seq 1 36); do
  if DOCKER_HOST="$SOCKET" "$DOCKER" info &>/dev/null 2>&1; then
    echo "[$(date)] Colima docker ready" >> "$LOG"; break
  fi
  [ "$i" -eq 36 ] && echo "[$(date)] ERROR: Colima not ready after 3 min. Exiting." >> "$LOG" && exit 1
  sleep 5
done

# Start containers via docker-compose (not docker compose — standalone CLI)
cd "$COMPOSE_DIR"
DOCKER_HOST="$SOCKET" "$COMPOSE" up -d >> "$LOG" 2>&1
echo "[$(date)] Compose exit: $?" >> "$LOG"

# Start nginx relay
[ -f "$COMPOSE_DIR/nginx-relay.pid" ] && kill $(cat "$COMPOSE_DIR/nginx-relay.pid") 2>/dev/null
pkill -f "nginx.*rustdesk" 2>/dev/null
sleep 1
"$NGINX" -c "$COMPOSE_DIR/nginx-relay.conf" >> "$LOG" 2>&1
echo "[$(date)] nginx relay started: $?" >> "$LOG"
