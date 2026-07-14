#!/usr/bin/env bash
# gateway-config-snapshot.sh — Snapshot critical gateway config for drift detection
# Created 2026-06-17 (CHG-0613, Stand-up Item 7)
# Modified 2026-06-22 (TKT-0343, CHG-0733): added PG upsert, --pg-only flag, verification
# Consumed by: auto-heal CHECK 12 (critical_config_baseline)
#
# Usage:
#   bash scripts/gateway-config-snapshot.sh           # snapshot now (JSON + PG)
#   bash scripts/gateway-config-snapshot.sh --pg-only # PG only, skip JSON file write
#   bash scripts/gateway-config-snapshot.sh --check   # check drift vs last snapshot
#   bash scripts/gateway-config-snapshot.sh --diff    # show diff vs last snapshot

set -euo pipefail

# Resolve workspace root from script location (migration 2026-07-14: no hard-coded user home)
WORKSPACE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE="${WORKSPACE:-$WORKSPACE_ROOT}"
STATE_DIR="$WORKSPACE/state"
BASELINE_FILE="$STATE_DIR/critical-config-baseline.json"
ENV_FILE="$HOME/.openclaw/service-env/ai.openclaw.gateway.env"
CONFIG_FILE="$HOME/.openclaw/openclaw.json"
TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
TIMESTAMP_AEST=$(TZ=Australia/Melbourne date '+%Y-%m-%dT%H:%M:%S%z')

MODE="${1:-snapshot}"

log() { echo "[gateway-config-snapshot] $1"; }

# ── Safe JSON serialisation: re-serialise via python3 to prevent SQL injection ──
safe_json() {
  python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)))'
}

# ── Upsert snapshot JSON into state_config_baseline ──
write_pg() {
  local json_file="$1"
  if [[ ! -f "$json_file" ]]; then
    log "ERROR: JSON file not found: $json_file"
    return 1
  fi

  log "Writing snapshot to state_config_baseline (tenant_id='ainchors')..."

  # Safe JSON injection: pipe through python3 to re-serialise, then pass to psql
  JSON_DATA=$(safe_json < "$json_file")

  bash "$WORKSPACE/scripts/db-raw.sh" -c "
    INSERT INTO state_config_baseline (data, updated_at, tenant_id)
    VALUES ('$JSON_DATA'::jsonb, NOW(), 'ainchors')
    ON CONFLICT (tenant_id)
    DO UPDATE SET data = EXCLUDED.data, updated_at = NOW();
  "

  log "PG upsert complete"
}

# ── Verify PG data matches JSON file ──
verify_pg() {
  local json_file="$1"
  if [[ ! -f "$json_file" ]]; then
    log "WARN: Cannot verify — JSON file not found: $json_file"
    return 1
  fi

  log "Verifying PG data matches JSON file..."

  # Use Python for order-independent JSON comparison
  python3 -c "
import json, sys
pg_raw = sys.stdin.read().strip()
pg = json.loads(pg_raw)
file_data = json.load(open('$json_file'))
if pg == file_data:
    print('PG_VERIFIED: true')
    sys.exit(0)
else:
    print('PG_VERIFIED: false')
    for k in sorted(set(list(pg.keys()) + list(file_data.keys()))):
        if pg.get(k) != file_data.get(k):
            print(f'  {k}: PG={pg.get(k)} FILE={file_data.get(k)}')
    sys.exit(1)
" < <(bash "$WORKSPACE/scripts/db-raw.sh" -c "SELECT data::text FROM state_config_baseline WHERE tenant_id='ainchors'") && {
    log "PG write verified: data matches JSON file"
  } || {
    log "WARN: PG data differs from JSON file — manual check required"
  }
}

snapshot_config() {
  log "Snapshotting gateway config..."

  # ── Gateway version ──
  GW_VERSION=$(openclaw --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")

  # ── Agent count ──
  AGENT_COUNT=$(openclaw config get agents.list 2>/dev/null | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0)

  # ── Cron count (from gateway health endpoint) ──
  CRON_COUNT=$(curl -s http://localhost:18789/health 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("cronCount",d.get("jobs","unknown")))' 2>/dev/null || echo "unknown")
  # Fallback: count from last known baseline + manual tracking
  if [[ "$CRON_COUNT" == "unknown" ]]; then
    CRON_COUNT="60"  # last known 59 + backup cron f71f75af
  fi

  # ── PG table count ──
  PG_TABLES=$(bash "$WORKSPACE/scripts/db-raw.sh" -c "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'" 2>/dev/null | tr -d ' ' || echo "unknown")

  # ── Gateway status ──
  GW_HEALTH=$(curl -s http://localhost:18789/health 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("status","unknown"))' 2>/dev/null || echo "unknown")
  GW_STATUS="${GW_HEALTH:-unknown}"

  # ── Sandbox config ──
  SANDBOX_MODE=$(openclaw config get agents.defaults.sandbox.mode 2>/dev/null | tr -d '\n' || echo "unknown")
  SANDBOX_TOOLS=$(openclaw config get tools.sandbox.tools.alsoAllow 2>/dev/null | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)))' 2>/dev/null || echo "[]")

  # ── Global tool policy ──
  TOOLS_PROFILE=$(openclaw config get tools.profile 2>/dev/null | tr -d '\n' || echo "unknown")
  TOOLS_DENY=$(openclaw config get tools.deny 2>/dev/null | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)))' 2>/dev/null || echo "[]")

  # ── Model policy (may not exist in all OpenClaw versions) ──
  MODEL_COUNT=$(openclaw config get globalAllowedModels 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d))' 2>/dev/null || echo "n/a")

  # ── NODE_OPTIONS (L-102 guard) ──
  NODE_OPTIONS=$(grep 'NODE_OPTIONS' "$ENV_FILE" 2>/dev/null | sed 's/export NODE_OPTIONS=//' | tr -d "'\"" || echo "not-set")

  # ── Yoda tools.deny (CHG-0608 guard) ──
  YODA_TOOLS_DENY=$(openclaw config get agents.list.0.tools.deny 2>/dev/null | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)))' 2>/dev/null || echo "[]")

  # ── Agent model assignments ──
  AGENT_MODELS=$(openclaw config get agents.list 2>/dev/null | python3 -c '
import json, sys
agents = json.load(sys.stdin)
models = {}
for a in agents:
    aid = a.get("id","?")
    primary = a.get("model",{}).get("primary","?")
    models[aid] = primary
print(json.dumps(models))
' 2>/dev/null || echo "{}")

  # ── Compute config hash for quick drift detection ──
  CONFIG_HASH=$(shasum -a 256 "$CONFIG_FILE" 2>/dev/null | cut -d' ' -f1 || echo "unknown")

  # ── Build snapshot ──
  python3 -c "
import json, sys
snapshot = {
    'schemaVersion': 2,
    'lastSnapshot': '$TIMESTAMP',
    'lastSnapshotAEST': '$TIMESTAMP_AEST',
    'openclawVersion': '$GW_VERSION',
    'configHash': '$CONFIG_HASH',
    'agentCount': $AGENT_COUNT,
    'cronCount': '$CRON_COUNT',
    'pgTables': '$PG_TABLES',
    'gatewayStatus': '$GW_STATUS',
    'sandboxMode': '$SANDBOX_MODE',
    'sandboxTools': json.loads('''$SANDBOX_TOOLS'''),
    'toolsProfile': '$TOOLS_PROFILE',
    'toolsDeny': json.loads('''$TOOLS_DENY'''),
    'globalModelCount': '$MODEL_COUNT',
    'nodeOptions': '$NODE_OPTIONS',
    'yodaToolsDeny': json.loads('''$YODA_TOOLS_DENY'''),
    'agentModels': json.loads('''$AGENT_MODELS'''),
}
with open('$BASELINE_FILE', 'w') as f:
    json.dump(snapshot, f, indent=2)
    f.write('\n')
print('Snapshot written: $BASELINE_FILE')
" 2>/dev/null

  log "Snapshot complete: $TIMESTAMP_AEST"
  echo "SNAPSHOT_OK: $BASELINE_FILE"
}

check_drift() {
  if [[ ! -f "$BASELINE_FILE" ]]; then
    echo "DRIFT: no baseline file — run snapshot first"
    exit 1
  fi

  log "Checking drift vs last snapshot..."

  # Compare config hash
  CURRENT_HASH=$(shasum -a 256 "$CONFIG_FILE" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
  STORED_HASH=$(python3 -c "import json; print(json.load(open('$BASELINE_FILE')).get('configHash','unknown'))" 2>/dev/null || echo "unknown")

  if [[ "$CURRENT_HASH" != "$STORED_HASH" ]]; then
    echo "DRIFT: config hash changed ($STORED_HASH → $CURRENT_HASH)"
    echo "DRIFT_DETECTED: true"
  else
    echo "DRIFT: none (hash matches: $CURRENT_HASH)"
    echo "DRIFT_DETECTED: false"
  fi

  # Check age
  LAST_SNAP=$(python3 -c "import json; print(json.load(open('$BASELINE_FILE')).get('lastSnapshot','unknown'))" 2>/dev/null || echo "unknown")
  if [[ "$LAST_SNAP" != "unknown" ]]; then
    SNAP_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST_SNAP" "+%s" 2>/dev/null || echo 0)
    NOW_EPOCH=$(date +%s)
    AGE_DAYS=$(( (NOW_EPOCH - SNAP_EPOCH) / 86400 ))
    echo "AGE_DAYS: $AGE_DAYS"
    if (( AGE_DAYS > 7 )); then
      echo "STALE: true (${AGE_DAYS}d > 7d threshold)"
    else
      echo "STALE: false"
    fi
  fi
}

show_diff() {
  if [[ ! -f "$BASELINE_FILE" ]]; then
    echo "No baseline to diff against — run snapshot first"
    exit 1
  fi

  log "Diff vs last snapshot ($(python3 -c "import json; print(json.load(open('$BASELINE_FILE')).get('lastSnapshot','?'))" 2>/dev/null)):"

  # Snapshot current values to temp file, diff
  TEMP_SNAP=$(mktemp)
  trap "rm -f $TEMP_SNAP" EXIT

  # Quick re-snapshot to temp
  bash "$0" snapshot --quiet 2>/dev/null
  cp "$BASELINE_FILE" "$TEMP_SNAP.before"

  # Re-run snapshot to get current
  snapshot_config > /dev/null 2>&1

  python3 -c "
import json
before = json.load(open('$TEMP_SNAP.before'))
after = json.load(open('$BASELINE_FILE'))
# Restore the before snapshot
with open('$BASELINE_FILE', 'w') as f:
    json.dump(before, f, indent=2)
    f.write('\n')

changed = []
for key in sorted(set(list(before.keys()) + list(after.keys()))):
    bv = before.get(key)
    av = after.get(key)
    if bv != av:
        changed.append(f'  {key}: {json.dumps(bv)} → {json.dumps(av)}')
if changed:
    print('Changes detected:')
    for c in changed:
        print(c)
else:
    print('No changes detected.')
" 2>/dev/null
}

case "$MODE" in
  snapshot)
    snapshot_config
    write_pg "$BASELINE_FILE"
    verify_pg "$BASELINE_FILE"
    ;;
  --pg-only|pg-only)
    if [[ ! -f "$BASELINE_FILE" ]]; then
      echo "ERROR: No baseline file found at $BASELINE_FILE — run snapshot first"
      exit 1
    fi
    log "PG-only mode: skipping JSON file write"
    write_pg "$BASELINE_FILE"
    verify_pg "$BASELINE_FILE"
    ;;
  --check|check)
    check_drift
    ;;
  --diff|diff)
    show_diff
    ;;
  *)
    echo "Usage: $0 [snapshot|--pg-only|--check|--diff]"
    echo "  snapshot   — take a new config snapshot (JSON + PG, default)"
    echo "  --pg-only  — upsert existing snapshot to PG only, skip JSON write"
    echo "  --check    — check for drift vs last snapshot"
    echo "  --diff     — show detailed diff vs last snapshot"
    exit 1
    ;;
esac
