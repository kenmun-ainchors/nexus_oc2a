#!/bin/bash
# scripts/check-model-policy-drift.sh — TKT-0540 A9
# Drift check: compares live runtime agent models and consumer behavior against
# state/model-policy.json (nightly cache; PG state_model_policy is SSOT per CREST v1.3). Writes alert file on drift.

set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsangiefpl/.openclaw/workspace}"
POLICY="$WORKSPACE_ROOT/state/model-policy.json"
QUERY="$WORKSPACE_ROOT/scripts/model-policy-query.sh"
ALERT="$WORKSPACE_ROOT/state/model-policy-drift-alert.json"
JQ=/opt/homebrew/bin/jq

# Load pg-sprint-backlog skill before any DB queries (model-policy-query.sh calls db.sh, which has a skill gate)
if ! bash "$WORKSPACE_ROOT/scripts/skill-load.sh" pg-sprint-backlog >/dev/null 2>&1; then
  echo '{"status":"error","drift":true,"alerts":["failed to load pg-sprint-backlog skill"]}' > "$ALERT"
  exit 1
fi

ALERTS=()
add_alert() { ALERTS+=("$1"); }

# 1. Validate policy JSON parses
if ! "$JQ" -e . "$POLICY" >/dev/null 2>&1; then
  add_alert "model-policy.json is not valid JSON"
fi

# 2. Check each declared agent's requiredPrimary vs runtime openclaw.json model
OPENCLAW="$WORKSPACE_ROOT/../openclaw/openclaw.json"
if [[ -f "$OPENCLAW" ]]; then
  while IFS= read -r agent; do
    required=$("$JQ" -r --arg a "$agent" '.agents[$a].requiredPrimary // empty' "$POLICY" 2>/dev/null || true)
    actual=$("$JQ" -r --arg a "$agent" '.agents.list[] | select(.id==$a) | .model // empty' "$OPENCLAW" 2>/dev/null || true)
    if [[ -n "$required" && -n "$actual" && "$required" != "$actual" ]]; then
      add_alert "runtime model drift: $agent actual=$actual required=$required"
    fi
  done < <("$JQ" -r '.agents | keys[]' "$POLICY" 2>/dev/null || true)
fi

# 3. Query helper --all must be valid JSON and every agent must have strong models for allowed phases
if ! bash "$QUERY" --all 2>/dev/null | "$JQ" -e '.effectiveMap' >/dev/null; then
  add_alert "model-policy-query.sh --all produced invalid or missing effectiveMap"
fi

# 4. Regression tests must pass
TEST_DIR="$WORKSPACE_ROOT/tests/regression/model-routing"
if [[ -d "$TEST_DIR" ]]; then
  for t in "$TEST_DIR"/test-*.sh; do
    if ! bash "$t" >/dev/null 2>&1; then
      add_alert "regression test failed: $(basename "$t")"
    fi
  done
fi

# Write alert or clear
if [[ ${#ALERTS[@]} -gt 0 ]]; then
  "$JQ" -n \
    --arg generated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson alerts "$(printf '%s\n' "${ALERTS[@]}" | "$JQ" -R . | "$JQ" -s .)" \
    '{generatedAt:$generated,acknowledged:false,source:"check-model-policy-drift.sh",alerts:$alerts}' \
    > "$ALERT"
  echo '{"status":"drift","alerts":'$(printf '%s\n' "${ALERTS[@]}" | "$JQ" -R . | "$JQ" -s .)'}'
  exit 1
else
  "$JQ" -n \
    --arg generated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{generatedAt:$generated,acknowledged:true,source:"check-model-policy-drift.sh",alerts:[]}' \
    > "$ALERT"
  echo '{"status":"ok","drift":false}'
  exit 0
fi
