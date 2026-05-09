#!/bin/bash
DOCKER="/usr/local/bin/docker"
NGINX="/opt/homebrew/bin/nginx"
COMPOSE_DIR="/Users/ainchorsangiefpl/.openclaw/workspace/infra/rustdesk"
LOG="$COMPOSE_DIR/startup.log"

echo "[$(date)] RustDesk startup triggered" >> "$LOG"

# Wait for Docker
for i in $(seq 1 24); do
  if "$DOCKER" info &>/dev/null 2>&1; then
    echo "[$(date)] Docker ready" >> "$LOG"; break
  fi
  sleep 5
done

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
