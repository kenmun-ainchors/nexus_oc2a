#!/usr/bin/env bash
# apply-model-context.sh — Apply model context from registry to openclaw.json
# CHG-0756 / TKT-0727: Dynamic Model Context Window Resolution
#
# Reads state/model-context-registry.json and ensures ~/.openclaw/openclaw.json
# model entries (models.providers.ollama.models[]) use effective_context for
# contextWindow and num_ctx.
# Keeps manual override possible by respecting effective_context if set.
# Backs up openclaw.json before any modification.
# Validates with openclaw config validate.

set -euo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
OC_CONFIG="/Users/ainchorsangiefpl/.openclaw/openclaw.json"
REGISTRY_FILE="$WORKSPACE/state/model-context-registry.json"
BACKUP_DIR="$WORKSPACE/state/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

mkdir -p "$BACKUP_DIR"

echo "=== Apply Model Context to openclaw.json ==="
echo "Timestamp: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
echo ""

# ── Step 1: Check registry exists ─────────────────────────────────────────
if [[ ! -f "$REGISTRY_FILE" ]]; then
  echo "ERROR: Registry file not found at $REGISTRY_FILE"
  echo "Run scripts/sync-model-context.sh first."
  exit 1
fi

# ── Step 2: Backup openclaw.json ──────────────────────────────────────────
BACKUP_FILE="$BACKUP_DIR/openclaw.json.bak-$TIMESTAMP"
cp "$OC_CONFIG" "$BACKUP_FILE"
echo "Backup saved to: $BACKUP_FILE"

# ── Step 3: Apply context from registry ──────────────────────────────────
echo ""
echo "Applying model context from registry..."

python3 <<'PYEOF'
import json, os, sys

oc_config_path = "/Users/ainchorsangiefpl/.openclaw/openclaw.json"
registry_path = "/Users/ainchorsangiefpl/.openclaw/workspace/state/model-context-registry.json"

# Load registry
with open(registry_path) as f:
    registry = json.load(f)

# Build lookup: short model name (e.g. "kimi-k2.7-code:cloud") -> effective_context
context_map = {}
for m in registry.get('models', []):
    cn = m['canonical_name']
    eff = m.get('effective_context')
    if eff is not None:
        # canonical_name is "ollama/kimi-k2.7-code:cloud", short is "kimi-k2.7-code:cloud"
        short = cn.split('/', 1)[1] if '/' in cn else cn
        context_map[short] = eff

if not context_map:
    print("No context values found in registry. Nothing to apply.")
    sys.exit(0)

# Load openclaw.json
with open(oc_config_path) as f:
    config = json.load(f)

changes = []

# Update models in models.providers.ollama.models[] (the actual model definitions)
ollama_models = config.get('models', {}).get('providers', {}).get('ollama', {}).get('models', [])
for model_def in ollama_models:
    model_id = model_def.get('id', '')
    if model_id in context_map:
        ctx = context_map[model_id]
        old_cw = model_def.get('contextWindow')
        old_nc = model_def.get('params', {}).get('num_ctx')
        if old_cw != ctx or old_nc != ctx:
            model_def['contextWindow'] = ctx
            if 'params' not in model_def:
                model_def['params'] = {}
            model_def['params']['num_ctx'] = ctx
            changes.append(f"  models.providers.ollama.models[{model_id}]: contextWindow {old_cw} → {ctx}, num_ctx {old_nc} → {ctx}")

if not changes:
    print("No changes needed — all model contexts already match registry.")
else:
    # Write updated config
    with open(oc_config_path, 'w') as f:
        json.dump(config, f, indent=2)
    
    print(f"Applied {len(changes)} change(s):")
    for c in changes:
        print(c)

print(f"\nRegistry models with context:")
for m in registry.get('models', []):
    print(f"  {m['canonical_name']:40s} effective_context={m.get('effective_context', 'N/A')}")
PYEOF

# ── Step 4: Validate ───────────────────────────────────────────────────────
echo ""
echo "Validating config..."
if command -v openclaw &>/dev/null; then
  openclaw config validate 2>&1 || {
    echo "WARNING: Config validation failed. Restoring backup..."
    cp "$BACKUP_FILE" "$OC_CONFIG"
    echo "Restored from: $BACKUP_FILE"
    exit 1
  }
  echo "Config validation passed."
else
  echo "WARNING: openclaw CLI not available. Skipping validation."
fi

echo ""
echo "=== Done ==="
