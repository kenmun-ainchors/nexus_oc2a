#!/usr/bin/env bash
# route-model.sh — Model Routing Decision Engine
# Returns the correct model ID for a given task type.
# Usage: bash route-model.sh <task-type>
# Output: model ID string (e.g. anthropic/claude-sonnet-4-6)
# TKT-0014 / CHG-0049

# ── Tier Definitions ──────────────────────────────────────────────────────────
TIER1="anthropic/claude-sonnet-4-6"   # Orchestration — Ken-facing, complex, multi-step
TIER2="anthropic/claude-haiku-4-5"    # Sub-tasks — bounded, structured, governance
TIER3="ollama/gemma4:e2b"             # Background — offline crons, zero-cost batch
FALLBACK="ollama/gemma4:26b"          # Emergency — offline when Anthropic API down

TASK_TYPE="${1:-unknown}"

# ── Routing Rules ─────────────────────────────────────────────────────────────
case "$TASK_TYPE" in

  # TIER 1 — Sonnet
  # Ken-facing responses, complex orchestration, multi-step planning,
  # anything with external consequences or requiring frontier reasoning
  orchestration|planning|research|ken-facing|external|financial|critical|\
  blog|journal|standup|strategy|code-review|agent-design|incident-response)
    echo "$TIER1" ;;

  # TIER 2 — Haiku
  # Bounded sub-tasks within pipelines, structured output, governance checks,
  # health interpretation, status formatting, simple routing decisions
  health-check|governance-review|shield-review|lex-review|sage-review|\
  warden-check|status-format|routing-decision|ticket-update|structured-output|\
  classification|extraction|summary-brief|backup-report|compliance-check|\
  alert-format|sub-task|bounded)
    echo "$TIER2" ;;

  # TIER 3 — gemma4:e2b (local, free, offline-capable)
  # Fully deterministic background crons, cost tracking, asset review,
  # batch processing where latency and API cost must be zero
  cost-tracker|asset-review|batch|background-cron|offline|zero-cost)
    echo "$TIER3" ;;

  # EMERGENCY — gemma4:26b
  # Only when Anthropic API is unreachable
  emergency|fallback-only|api-down)
    echo "$FALLBACK" ;;

  # DEFAULT — conservative fallback to Sonnet
  *)
    echo "$TIER1" ;;
esac
