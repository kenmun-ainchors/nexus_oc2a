#!/bin/bash
# sync-out.sh — Export Postgres to JSON files for file-based readers
# Usage: bash scripts/sync-out.sh [--all]
DB="/Users/ainchorsangiefpl/.openclaw/workspace/scripts/db-raw.sh"
WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"

# Export tickets (small enough for direct SELECT)
bash "$DB" -c "SELECT jsonb_agg(row_to_json(t)) FROM state_tickets t" > "$WORKSPACE/state/tickets-pg-export.json" 2>/dev/null && echo "✅ tickets exported"

# Export sprints
bash "$DB" -c "SELECT jsonb_agg(row_to_json(s)) FROM state_sprints s" > "$WORKSPACE/state/sprints-pg-export.json" 2>/dev/null && echo "✅ sprints exported"

# Export standups
bash "$DB" -c "SELECT jsonb_agg(row_to_json(s) ORDER BY standup_date DESC) FROM state_standups s" > "$WORKSPACE/state/standups-pg-export.json" 2>/dev/null && echo "✅ standups exported"

echo "Sync-out complete: $(date)"
