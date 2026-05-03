#!/usr/bin/env bash
# spawn-with-routing.sh — Route a task through route-model.sh and log the decision
# Usage:   MODEL=$(bash spawn-with-routing.sh <task-type> [caller] [notes])
# Returns: model ID on stdout; logs routing decision to obs.db
#
# Integration pattern for shell scripts:
#   MODEL=$(bash "$WORKSPACE/scripts/spawn-with-routing.sh" "governance-review" "governance-review.sh")
#   # Use $MODEL when spawning sessions or passing to openclaw cron payloads
#
# TKT-0039 — Tier A/B/C delegation wiring

set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
ROUTE_SCRIPT="$WORKSPACE/scripts/route-model.sh"
OBS_SCRIPT="$WORKSPACE/scripts/obs-log.sh"

TASK_TYPE="${1:-unknown}"
CALLER="${2:-spawn-with-routing}"
NOTES="${3:-}"

# ── Validate route-model.sh exists ───────────────────────────────────────────
if [[ ! -f "$ROUTE_SCRIPT" ]]; then
  echo "anthropic/claude-sonnet-4-6"  # conservative fallback
  exit 0
fi

# ── Get routed model ──────────────────────────────────────────────────────────
MODEL=$(bash "$ROUTE_SCRIPT" "$TASK_TYPE")

# ── Determine tier label for logging ──────────────────────────────────────────
case "$MODEL" in
  *sonnet*|*opus*)           TIER="T1" ;;
  *haiku*)                   TIER="T2" ;;
  *deepseek*|*kimi*|*qwen*)  TIER="T2-cloud" ;;
  *gemma4:e2b*)              TIER="T3" ;;
  *gemma4:26b*)              TIER="emergency" ;;
  *)                         TIER="unknown" ;;
esac

# ── Log routing decision to obs.db ────────────────────────────────────────────
if [[ -f "$OBS_SCRIPT" ]]; then
  DETAIL="{\"taskType\":\"$TASK_TYPE\",\"model\":\"$MODEL\",\"tier\":\"$TIER\",\"caller\":\"$CALLER\",\"notes\":\"$NOTES\"}"
  bash "$OBS_SCRIPT" \
    --source "route-model" \
    --level  "INFO" \
    --type   "routing-decision" \
    --message "Routed $TASK_TYPE → $MODEL ($TIER) [caller: $CALLER]" \
    --agent  "yoda" \
    --detail "$DETAIL" >/dev/null 2>&1 || true  # non-fatal if obs.db unavailable
fi

# ── Emit model ID ─────────────────────────────────────────────────────────────
echo "$MODEL"
