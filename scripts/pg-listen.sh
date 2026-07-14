#!/bin/bash
# pg-listen.sh — Async NOTIFY listener via persistent psql with reconnect loops
# Usage: bash scripts/pg-listen.sh <agent_id> [channel1 channel2 ...]
#   bash scripts/pg-listen.sh yoda ticket_changed state_changed
#
# Design: Opens psql with LISTEN + short pg_sleep in -f mode.
#   psql -f mode prints async notifications between statements (-c mode does NOT).
#   Short pg_sleep(1) means notifications flush every ~1s with <1s latency.
#   Loop reconnects seamlessly — no polling queries, 1 connection at a time.
#
# Why this vs coprocess: bash 3.2 on macOS has no coproc. zsh coproc works but
#   psql buffers notifications until a SQL command is sent, negating the benefit.
#   This approach is simpler, reliable, and still 0 polling queries.
#
# Resource profile per agent: 1 PG connection (not persistent-across-sleep but 
#   only one active at a time), 0 polling queries, ~0.1% CPU for reconnect overhead.

AGENT_ID="${1:-unknown}"; shift
CHANNELS="$@"
CYCLE_SECS="${PG_LISTEN_CYCLE:-1}"    # pg_sleep duration — lower = faster notifications
export PGHOST="${PGHOST:-/tmp}"
export PGUSER="${PGUSER:-"${PGUSER:-$(whoami)}"}"
export PGDATABASE="${PGDATABASE:-ainchors_nexus}"
PSQL="${PSQL_BIN:-$(brew --prefix postgresql@16 2>/dev/null)/bin/psql}"

if [[ -z "$CHANNELS" ]]; then
  CHANNELS="ticket_changed state_changed alert_raised"
fi

echo "pg-listen [async]: agent=$AGENT_ID cycle=${CYCLE_SECS}s channels: $CHANNELS pid=$$" >&2

# Build the LISTEN SQL prefix (reused each cycle)
LISTEN_PREFIX=""
for ch in $CHANNELS; do
  LISTEN_PREFIX="${LISTEN_PREFIX}LISTEN ${ch};"
done

# Pre-write the listen script template once, just update each cycle
LISTEN_FILE="/tmp/pg_listen_${AGENT_ID}.sql"

# Main listen loop
while true; do
  # Write fresh SQL: LISTEN on all channels, then sleep
  echo "${LISTEN_PREFIX}SELECT pg_sleep(${CYCLE_SECS});" > "$LISTEN_FILE"

  # Run psql in -f mode (this is what prints async notifications)
  $PSQL -A --no-psqlrc -f "$LISTEN_FILE" 2>/dev/null | while IFS= read -r line; do
    # Parse async notification lines:
    # Asynchronous notification "channel" with payload "payload" received from server process with PID N.
    if [[ "$line" =~ ^Asynchronous\ notification\ \"([^\"]+)\"\ with\ payload\ \"(.*)\"\ received ]]; then
      channel="${BASH_REMATCH[1]}"
      payload="${BASH_REMATCH[2]}"
      ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      printf '{"agent":"%s","channel":"%s","payload":%s,"ts":"%s"}\n' \
        "$AGENT_ID" "$channel" "$payload" "$ts"
    fi
  done

  # psql exited (pg_sleep completed). Loop immediately to reconnect.
  # No sleep between cycles — LISTEN state is per-connection, so we need fresh LISTEN each cycle.
done
