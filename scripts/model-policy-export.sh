#!/bin/bash
# scripts/model-policy-export.sh — Export active PG matrix to JSON cache
# CREST v1.3 (TKT-0546 A8)
# Generates state/model-policy.json from PG state_model_policy tables.
# Run nightly via cron to keep JSON cache fresh during v1.3 proving period.

set -euo pipefail

# ── Canonical skill load ────────────────────────────────────────────────────
# Load pg-sprint-backlog skill before any database operations.
# Exits non-zero if skill-load fails (set -e ensures this).
if ! bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/skill-load.sh" pg-sprint-backlog; then
  echo "ERROR: Failed to load pg-sprint-backlog skill. Aborting." >&2
  exit 10
fi

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsangiefpl/.openclaw/workspace}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_FILE="$WORKSPACE_ROOT/state/model-policy.json"
JQ="${JQ:-/opt/homebrew/bin/jq}"

# Get active matrix version
ACTIVE_VERSION=$(bash "$SCRIPT_DIR/db.sh" -c "
  SELECT version FROM policy_matrices WHERE active = TRUE AND tenant_id = 'ainchors' LIMIT 1;
" 2>/dev/null | tail -1 | xargs)

if [[ -z "$ACTIVE_VERSION" ]]; then
  echo "No active matrix version found. Export aborted." >&2
  exit 1
fi

# Build JSON export
TIMESTAMP=$(date -Iseconds)

# Export crest_phase_rules as JSON array
RULES_JSON=$(bash "$SCRIPT_DIR/db.sh" -c "
  SELECT json_agg(row_to_json(r)) FROM (
    SELECT role, phase, default_model, fallback_model, override_allowed, rationale
    FROM crest_phase_rules
    WHERE matrix_version = '$ACTIVE_VERSION' AND tenant_id = 'ainchors'
    ORDER BY role, phase
  ) r;
" 2>/dev/null | tail -1)

# Export model_registry as JSON array
REGISTRY_JSON=$(bash "$SCRIPT_DIR/db.sh" -c "
  SELECT json_agg(row_to_json(m)) FROM (
    SELECT canonical_name, provider, family, status
    FROM model_registry
    WHERE tenant_id = 'ainchors' AND status = 'active'
    ORDER BY canonical_name
  ) m;
" 2>/dev/null | tail -1)

# Build the export document — merge v1.3 data into existing structure
# Read existing file first, then overlay v1.3 PG data

if [[ -f "$OUTPUT_FILE" ]]; then
  EXISTING=$(cat "$OUTPUT_FILE")
else
  EXISTING='{}'
fi

echo "$EXISTING" | "$JQ" \
  --arg version "$ACTIVE_VERSION" \
  --arg timestamp "$TIMESTAMP" \
  --arg source "pg-export" \
  --argjson rules "${RULES_JSON:-[]}" \
  --argjson registry "${REGISTRY_JSON:-[]}" \
  '. + {
    crest_v13: {
      active_matrix: $version,
      last_exported: $timestamp,
      source: $source,
      phase_rules: $rules,
      model_registry: $registry
    },
    _note_crest_v13: "CREST v1.3 capability-based routing. PG state_model_policy is SSOT. This section is auto-generated nightly."
  }' > "$OUTPUT_FILE"

echo "Exported $ACTIVE_VERSION to $OUTPUT_FILE ($(wc -c < "$OUTPUT_FILE") bytes)"
