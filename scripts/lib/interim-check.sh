#!/usr/bin/env bash
# interim-check.sh — Single source of truth for interim model period detection
# Source this in ALL alert-generating scripts to ensure consistent interim awareness.
# L-040: Every script that generates alerts must check this before firing.

# Usage:
#   source "$(dirname "$0")/lib/interim-check.sh"
#   check_interim_period
#   if [[ "$INTERIM_ACTIVE" == "true" ]]; then
#     echo "Interim period active: $INTERIM_REASON"
#     # Decide: skip alert, annotate alert, downgrade severity
#   fi

INTERIM_FILE="${WORKSPACE:-/Users/ainchorsoc2a/.openclaw/workspace}/state/interim-model-period.json"

check_interim_period() {
  export INTERIM_ACTIVE=false
  export INTERIM_REASON=""
  export INTERIM_BEHAVIOR="SKIP_ALL_CHECKS"
  
  if [[ -f "$INTERIM_FILE" ]]; then
    INTERIM_ACTIVE=$(/usr/bin/python3 -c "import json; d=json.load(open('$INTERIM_FILE')); print(str(d.get('active',False)).lower())" 2>/dev/null || echo "false")
    INTERIM_REASON=$(/usr/bin/python3 -c "import json; d=json.load(open('$INTERIM_FILE')); print(d.get('reason','unknown'))" 2>/dev/null || echo "unknown")
    INTERIM_BEHAVIOR=$(/usr/bin/python3 -c "import json; d=json.load(open('$INTERIM_FILE')); print(d.get('wardenBehavior','SKIP_ALL_CHECKS'))" 2>/dev/null || echo "SKIP_ALL_CHECKS")
  fi
}

# Check if a model is an Anthropic model (should be skipped during interim)
is_anthropic_model() {
  local model="$1"
  case "$model" in
    anthropic/*|claude*|sonnet*|haiku*|opus*)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

# Annotate an alert message with interim context
annotate_interim_alert() {
  local original_alert="$1"
  if [[ "$INTERIM_ACTIVE" == "true" ]]; then
    echo "[INTERIM PERIOD] $original_alert (Reason: $INTERIM_REASON)"
  else
    echo "$original_alert"
  fi
}
