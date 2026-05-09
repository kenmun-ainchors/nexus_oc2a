#!/bin/bash
# RustDesk relay — nginx stream proxy bridges Tailscale/LAN → Docker loopback
# Replaces broken Docker Desktop non-loopback forwarding

LOG=/Users/ainchorsangiefpl/.openclaw/workspace/infra/rustdesk/relay.log
NGINX=/opt/homebrew/bin/nginx
CONF=/Users/ainchorsangiefpl/.openclaw/workspace/infra/rustdesk/nginx-relay.conf
PID_FILE=/Users/ainchorsangiefpl/.openclaw/workspace/infra/rustdesk/nginx-relay.pid

echo "[$(date)] Starting RustDesk relay (nginx)" >> "$LOG"

# Stop any existing relay
[ -f "$PID_FILE" ] && kill $(cat "$PID_FILE") 2>/dev/null
pkill -f "nginx.*rustdesk" 2>/dev/null
sleep 1

$NGINX -c "$CONF" >> "$LOG" 2>&1
echo "[$(date)] nginx relay started: $?" >> "$LOG"
