#!/bin/bash
# RustDesk relay startup — uses Colima (not Docker Desktop)
# Colima auto-starts at login via: brew services start colima
# This script starts the hbbs/hbbr containers + nginx relay.
DOCKER="/usr/local/bin/docker"
NGINX="/opt/homebrew/bin/nginx"
COMPOSE_DIR="/Users/ainchorsangiefpl/.openclaw/workspace/infra/rustdesk"
LOG="$COMPOSE_DIR/startup.log"

echo "[$(date)] RustDesk startup triggered (Colima runtime)" >> "$LOG"

# Wait for Colima docker socket to be ready (Colima starts via brew services)
for i in $(seq 1 36); do
  if "$DOCKER" --context colima info &>/dev/null 2>&1; then
    echo "[$(date)] Colima docker ready" >> "$LOG"; break
  fi
  echo "[$(date)] Waiting for Colima... ($i/36)" >> "$LOG"
  sleep 5
done

# Use Colima context explicitly — never Docker Desktop
export DOCKER_CONTEXT=colima

# Start containers
cd "$COMPOSE_DIR"
"$DOCKER" compose up -d >> "$LOG" 2>&1
echo "[$(date)] Containers up: $?" >> "$LOG"

sleep 3

# Start nginx relay
[ -f "$COMPOSE_DIR/nginx-relay.pid" ] && kill $(cat "$COMPOSE_DIR/nginx-relay.pid") 2>/dev/null
pkill -f "nginx.*rustdesk" 2>/dev/null
sleep 1
"$NGINX" -c "$COMPOSE_DIR/nginx-relay.conf" >> "$LOG" 2>&1
echo "[$(date)] nginx relay started: $?" >> "$LOG"
