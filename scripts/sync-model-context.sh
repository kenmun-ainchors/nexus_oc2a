#!/usr/bin/env bash
# sync-model-context.sh — Sync model context windows from Ollama API to PG model_registry
# CHG-0756 / TKT-0727: Dynamic Model Context Window Resolution
#
# Queries Ollama /api/tags, extracts context_length for each :cloud model,
# writes to PG model_registry (advertised_context, effective_context, last_synced_at).
# Falls back to family-based mapping if API is unreachable.
# Emits state/model-context-registry.json as SSOT consumable.
# Writes sync log to state/model-context-sync.log.

set -euo pipefail

WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
DB_RAW="$WORKSPACE/scripts/db-raw.sh"
STATE_DIR="$WORKSPACE/state"
LOG_FILE="$STATE_DIR/model-context-sync.log"
REGISTRY_FILE="$STATE_DIR/model-context-registry.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
AEST_TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S+10:00")

mkdir -p "$STATE_DIR"

log() {
  echo "[$AEST_TIMESTAMP] $*" | tee -a "$LOG_FILE"
}

# ── Step 1: Query Ollama API ─────────────────────────────────────────────
log "Querying Ollama API at http://127.0.0.1:11434/api/tags..."
OLLAMA_RESPONSE=$(curl -s --max-time 10 http://127.0.0.1:11434/api/tags 2>/dev/null || echo "")
API_AVAILABLE=false

if [[ -n "$OLLAMA_RESPONSE" ]] && echo "$OLLAMA_RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'models' in d" 2>/dev/null; then
  API_AVAILABLE=true
  log "Ollama API responded successfully."
  
  # Write API context to temp JSON for Python consumption
  echo "$OLLAMA_RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
result = {}
for m in data.get('models', []):
    name = m.get('name', '')
    if ':cloud' in name:
        cl = m.get('details', {}).get('context_length', '')
        family = m.get('details', {}).get('family', '')
        result[name] = {'context_length': cl, 'family': family}
        print(f'  API: {name} → context_length={cl} (family={family})')
with open('/tmp/sync-model-context-api.json', 'w') as f:
    json.dump(result, f)
" 2>&1 | while IFS= read -r line; do log "$line"; done
else
  log "WARNING: Ollama API unreachable. Using family fallback mapping."
  echo '{}' > /tmp/sync-model-context-api.json
fi

# ── Step 2: Build registry JSON and update PG ─────────────────────────────
log "Building model context registry and updating PG..."

python3 <<'PYEOF'
import json, subprocess, os
from datetime import datetime, timezone

DB_RAW = "/Users/ainchorsoc2a/.openclaw/workspace/scripts/db-raw.sh"
REGISTRY_FILE = "/Users/ainchorsoc2a/.openclaw/workspace/state/model-context-registry.json"
LOG_FILE = "/Users/ainchorsoc2a/.openclaw/workspace/state/model-context-sync.log"

# Load API context
api_context = {}
api_file = "/tmp/sync-model-context-api.json"
if os.path.exists(api_file):
    with open(api_file) as f:
        api_context = json.load(f)
    os.unlink(api_file)

api_available = len(api_context) > 0

# Family fallback mapping
FAMILY_CONTEXT = {
    "kimi": 262144,
    "kimi-k2": 262144,
    "gemma": 262144,
    "deepseek": 1048576,
    "minimax": 131072,
    "glm": 1000000,
    "qwen": 262144,
    "qwen35moe": 262144,
}

# Read current model_registry from PG
try:
    result = subprocess.run(
        [DB_RAW, "-c", "SELECT canonical_name, family, max_context, advertised_context, effective_context FROM model_registry WHERE status='active' ORDER BY canonical_name"],
        capture_output=True, text=True, timeout=10
    )
    pg_rows = result.stdout.strip().split('\n') if result.stdout.strip() else []
except Exception as e:
    pg_rows = []
    print(f"PG_QUERY_FAILED: {e}")

models = []
now_utc = datetime.now(timezone.utc).isoformat()

for row in pg_rows:
    if not row.strip() or row.startswith('('):
        continue
    parts = row.split('|')
    if len(parts) < 3:
        continue
    canonical_name = parts[0].strip()
    family = parts[1].strip() if len(parts) > 1 else ''
    pg_max_context = parts[2].strip() if len(parts) > 2 and parts[2].strip() else None
    pg_advertised = parts[3].strip() if len(parts) > 3 and parts[3].strip() else None
    pg_effective = parts[4].strip() if len(parts) > 4 and parts[4].strip() else None
    
    short_name = canonical_name.split('/', 1)[1] if '/' in canonical_name else canonical_name
    
    advertised_context = None
    source = 'manual'
    
    if api_available and short_name in api_context:
        cl = api_context[short_name].get('context_length', '')
        if cl:
            advertised_context = int(cl)
            source = 'ollama_api'
    elif family and family in FAMILY_CONTEXT:
        advertised_context = FAMILY_CONTEXT[family]
        source = 'family_fallback'
    elif pg_max_context:
        advertised_context = int(pg_max_context)
        source = 'pg_max_context'
    
    # effective_context: use existing if set (manual override), otherwise advertised
    effective_context = None
    if pg_effective:
        effective_context = int(pg_effective)
    else:
        effective_context = advertised_context
    
    model_entry = {
        "canonical_name": canonical_name,
        "family": family,
        "advertised_context": advertised_context,
        "effective_context": effective_context,
        "source": source,
        "last_synced_at": now_utc
    }
    models.append(model_entry)
    
    # Update PG
    if advertised_context is not None or effective_context is not None:
        sets = []
        if advertised_context is not None:
            sets.append(f"advertised_context={advertised_context}")
        if effective_context is not None:
            sets.append(f"effective_context={effective_context}")
        sets.append(f"last_synced_at='{now_utc}'::timestamptz")
        sets.append(f"sync_source='{source}'")
        sets.append("updated_at=NOW()")
        
        sql = f"UPDATE model_registry SET {', '.join(sets)} WHERE canonical_name='{canonical_name}'"
        pg_result = subprocess.run(
            [DB_RAW, "-c", sql],
            capture_output=True, text=True, timeout=10
        )
        if pg_result.returncode != 0:
            print(f"PG_UPDATE_FAILED: {canonical_name}: {pg_result.stderr.strip()}")

registry = {
    "generated_at": now_utc,
    "api_available": api_available,
    "models": models
}

with open(REGISTRY_FILE, 'w') as f:
    json.dump(registry, f, indent=2)

print(f"Registry written: {len(models)} models")
print(f"PG updated: {len(models)} models")
print("")
print("═══════════════════════════════════════════════════════════════")
print(f"  Model Context Sync — {datetime.now().strftime('%Y-%m-%dT%H:%M:%S+10:00')}")
print(f"  API available: {api_available}")
print("═══════════════════════════════════════════════════════════════")
for m in models:
    adv = str(m['advertised_context']) if m['advertised_context'] else 'None'
    eff = str(m['effective_context']) if m['effective_context'] else 'None'
    print(f"  {m['canonical_name']:40s} adv={adv:>8s}  eff={eff:>8s}  src={m['source']}")
print("═══════════════════════════════════════════════════════════════")
PYEOF

echo "[$AEST_TIMESTAMP] Sync complete." >> "$LOG_FILE"
