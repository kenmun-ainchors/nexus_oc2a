#!/bin/bash
# pg-poll.sh — Stateless polling fallback for agents that can't use LISTEN
# Usage: bash scripts/pg-poll.sh <table> [last_updated_timestamp]
#   bash scripts/pg-poll.sh state_tickets "2026-05-23T19:00:00+10:00"

TABLE="$1"; SINCE="${2:-}"
DB="/Users/ainchorsoc2a/.openclaw/workspace/scripts/db-raw.sh"

if [[ -z "$TABLE" ]]; then
  echo '{"error": "usage: pg-poll.sh <table> [since_timestamp]"}' >&2
  exit 1
fi

if [[ -n "$SINCE" ]]; then
  bash "$DB" -c "SELECT jsonb_agg(row_to_json(t)) FROM (SELECT * FROM $TABLE WHERE updated_at > '$SINCE' OR created_at > '$SINCE') t"
else
  bash "$DB" -c "SELECT jsonb_agg(row_to_json(t)) FROM (SELECT * FROM $TABLE ORDER BY updated_at DESC NULLS LAST LIMIT 20) t"
fi
