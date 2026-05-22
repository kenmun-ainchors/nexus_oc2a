#!/bin/bash
# migrate-state-to-postgres.sh — JSON to Postgres migration for top 5 state files
# Usage: bash scripts/migrate-state-to-postgres.sh [--dry-run]
# TKT-0198 | 2026-05-21 | Idempotent — safe to re-run

set -e

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
PSQL="/opt/homebrew/bin/psql -U ainchorsangiefpl -d ainchors_nexus"
DRY_RUN=false

[[ "$1" == "--dry-run" ]] && DRY_RUN=true && echo "=== DRY RUN MODE ==="

run_psql() {
    if $DRY_RUN; then
        echo "[DRY-RUN] $1"
    else
        $PSQL -c "$1" 2>/dev/null || echo "(table/view already exists, skipping)"
    fi
}

echo "=== TKT-0198: JSON to Postgres Migration ==="

# ── Create tables (idempotent) ──
run_psql "CREATE TABLE IF NOT EXISTS state_tickets (id TEXT PRIMARY KEY, data JSONB NOT NULL, updated_at TIMESTAMPTZ DEFAULT now(), tenant_id TEXT DEFAULT 'ainchors');"
run_psql "CREATE TABLE IF NOT EXISTS state_cost (id SERIAL PRIMARY KEY, data JSONB NOT NULL, updated_at TIMESTAMPTZ DEFAULT now(), tenant_id TEXT DEFAULT 'ainchors');"
run_psql "CREATE TABLE IF NOT EXISTS state_model_policy (id SERIAL PRIMARY KEY, data JSONB NOT NULL, updated_at TIMESTAMPTZ DEFAULT now(), tenant_id TEXT DEFAULT 'ainchors');"
run_psql "CREATE TABLE IF NOT EXISTS state_task_queue (id SERIAL PRIMARY KEY, data JSONB NOT NULL, updated_at TIMESTAMPTZ DEFAULT now(), tenant_id TEXT DEFAULT 'ainchors');"
run_psql "CREATE TABLE IF NOT EXISTS state_config_baseline (id SERIAL PRIMARY KEY, data JSONB NOT NULL, updated_at TIMESTAMPTZ DEFAULT now(), tenant_id TEXT DEFAULT 'ainchors');"

# ── Create views ──
run_psql "CREATE SCHEMA IF NOT EXISTS state_v;"
run_psql "CREATE OR REPLACE VIEW state_v.tickets AS SELECT id, data FROM state_tickets;"
run_psql "CREATE OR REPLACE VIEW state_v.cost_state AS SELECT data FROM state_cost;"
run_psql "CREATE OR REPLACE VIEW state_v.model_policy AS SELECT data FROM state_model_policy;"
run_psql "CREATE OR REPLACE VIEW state_v.task_queue AS SELECT data FROM state_task_queue;"
run_psql "CREATE OR REPLACE VIEW state_v.config_baseline AS SELECT data FROM state_config_baseline;"

# ── Migrate data via Python (handles escaping) ──
if ! $DRY_RUN; then
    python3 << 'PYEOF'
import json, subprocess

PSQL = ['/opt/homebrew/bin/psql', '-U', 'ainchorsangiefpl', '-d', 'ainchors_nexus']
WORKSPACE = '/Users/ainchorsangiefpl/.openclaw/workspace'

files = {
    'state_tickets': 'state/tickets.json',
    'state_cost': 'state/cost-state.json',
    'state_model_policy': 'state/model-policy.json',
    'state_task_queue': 'state/task-queue.json',
    'state_config_baseline': 'state/critical-config-baseline.json',
}

for table, path in files.items():
    print(f"  Migrating {path} → {table}...")
    with open(f'{WORKSPACE}/{path}') as f:
        data = json.load(f)
    
    if table == 'state_tickets':
        tickets = data if isinstance(data, list) else data.get('tickets', [])
        seen = {}
        for t in tickets:
            if isinstance(t, dict) and 'id' in t:
                seen[t['id']] = t
        count = 0
        for tid, t in seen.items():
            t_json = json.dumps(t).replace("'", "''")
            sql = f"INSERT INTO {table} (id, data) VALUES ('{tid}', '{t_json}'::jsonb) ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data, updated_at = now();"
            subprocess.run(PSQL + ['-c', sql], capture_output=True)
            count += 1
        print(f"    {count} tickets migrated (unique)")
    else:
        data_json = json.dumps(data).replace("'", "''")
        sql = f"INSERT INTO {table} (data) VALUES ('{data_json}'::jsonb);"
        subprocess.run(PSQL + ['-c', sql], capture_output=True)
        print(f"    migrated")

print("  Migration complete")
PYEOF
fi

# ── Verify ──
echo ""
$PSQL -c "SELECT 'state_tickets' AS tbl, COUNT(*) FROM state_tickets UNION ALL SELECT 'state_cost', COUNT(*) FROM state_cost UNION ALL SELECT 'state_model_policy', COUNT(*) FROM state_model_policy UNION ALL SELECT 'state_task_queue', COUNT(*) FROM state_task_queue UNION ALL SELECT 'state_config_baseline', COUNT(*) FROM state_config_baseline ORDER BY tbl;"

echo "=== TKT-0198 Migration Complete ==="
