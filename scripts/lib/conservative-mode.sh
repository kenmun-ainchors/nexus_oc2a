#!/bin/zsh
# AInchors Conservative Mode Shared Library
# Sourced by all scripts that need interim period awareness.
# CHG-0367: Extracted from validate-fallback-chain.sh + warden-cron.sh
# Usage: source $WORKSPACE/scripts/lib/conservative-mode.sh
#
# Provides:
#   - is_interim_period_active() → exit 0 if active, 1 if not
#   - get_interim_period_info()  → echo JSON with details
#   - require_ken_approval()     → prompt for approval if interim + risky action
#   - skip_if_interim()          → return "skip" if interim, "ok" if not

set -uo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
STATE="$WORKSPACE/state"
INTERIM_FILE="$STATE/interim-model-period.json"

# ── Core: Check if interim period is active ──────────────────────────────────
is_interim_period_active() {
  if [[ ! -f "$INTERIM_FILE" ]]; then
    return 1  # Not active (file doesn't exist)
  fi
  
  local active
  active=$(python3 -c "
import json, sys
try:
    d = json.load(open('$INTERIM_FILE'))
    sys.exit(0 if d.get('active') else 1)
except:
    sys.exit(1)
" 2>/dev/null)
  
  return $?
}

# ── Get interim period details as JSON ──────────────────────────────────────
get_interim_period_info() {
  if [[ ! -f "$INTERIM_FILE" ]]; then
    echo '{"active":false,"reason":null,"startedAt":null}'
    return
  fi
  
  python3 -c "
import json
try:
    d = json.load(open('$INTERIM_FILE'))
    print(json.dumps({
        'active': d.get('active', false),
        'reason': d.get('reason'),
        'startedAt': d.get('startedAt'),
        'expectedEnd': d.get('expectedEnd'),
        'approvedBy': d.get('approvedBy'),
        'approvedAt': d.get('approvedAt'),
        'approvedVia': d.get('approvedVia'),
        'chgReference': d.get('chgReference'),
        'revertKeyword': d.get('revertKeyword')
    }))
except:
    print('{}')
" 2>/dev/null
}

# ── Get human-readable interim status ──────────────────────────────────────
get_interim_status_human() {
  if is_interim_period_active; then
    local info
    info=$(get_interim_period_info)
    local reason
    reason=$(echo "$info" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('reason','unknown'))")
    local started
    started=$(echo "$info" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('startedAt','unknown'))")
    echo "ACTIVE (since $started): $reason"
  else
    echo "INACTIVE"
  fi
}

# ── Skip action if interim period active ───────────────────────────────────
skip_if_interim() {
  if is_interim_period_active; then
    echo "skip"
  else
    echo "ok"
  fi
}

# ── Log message with interim context ─────────────────────────────────────────
log_with_interim() {
  local level="$1"
  local message="$2"
  local script_name="${3:-${0##*/}}"
  
  if is_interim_period_active; then
    local info
    info=$(get_interim_period_info)
    local chg_ref
    chg_ref=$(echo "$info" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('chgReference','CHG-0349'))")
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] [$script_name] [interim:$chg_ref] $message"
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] [$script_name] $message"
  fi
}

# ── Check if action requires Ken approval during interim ───────────────────
require_ken_approval() {
  local action_description="$1"
  local channel="${2:-webchat}"
  
  if is_interim_period_active; then
    # During interim period, risky actions require explicit Ken approval
    # This function should be called by scripts before performing:
    # - State file modifications
    # - Gateway config changes
    # - Cron modifications
    # - Agent model changes
    # - Destructive operations
    
    echo "⚠️ INTERIM PERIOD ACTIVE — Explicit Ken approval required"
    echo "   Action: $action_description"
    echo "   Channel: $channel"
    echo "   Approve with: 'PROCEED' or 'APPROVED'"
    
    # In non-interactive scripts, this returns a status code
    # Interactive scripts should prompt Ken
    return 2  # Special exit code: requires approval
  fi
  
  return 0  # Not interim, proceed normally
}

# ── Validate interim period state file integrity ─────────────────────────────
validate_interim_state() {
  if [[ ! -f "$INTERIM_FILE" ]]; then
    # No interim file = not active, which is valid
    return 0
  fi
  
  # Check JSON validity
  if ! python3 -c "import json; json.load(open('$INTERIM_FILE'))" 2>/dev/null; then
    echo "ERROR: $INTERIM_FILE is not valid JSON"
    return 1
  fi
  
  # Check required fields if active
  local active
  active=$(python3 -c "import json; d=json.load(open('$INTERIM_FILE')); print(d.get('active','false'))" 2>/dev/null || echo "false")
  
  if [[ "$active" == "True" || "$active" == "true" ]]; then
    # Required fields for active interim period
    local reason
    reason=$(python3 -c "import json; d=json.load(open('$INTERIM_FILE')); print(d.get('reason',''))" 2>/dev/null || echo "")
    if [[ -z "$reason" ]]; then
      echo "WARN: Interim period active but no reason documented"
    fi
    
    local chg_ref
    chg_ref=$(python3 -c "import json; d=json.load(open('$INTERIM_FILE')); print(d.get('chgReference',''))" 2>/dev/null || echo "")
    if [[ -z "$chg_ref" ]]; then
      echo "WARN: Interim period active but no CHG reference"
    fi
  fi
  
  return 0
}

# ── Auto-cleanup: Deactivate interim if CLAUDE RESTORE keyword detected ────
check_claude_restore() {
  # This is called by scripts that process Ken's input
  # Returns 0 if CLAUDE RESTORE detected, 1 otherwise
  local input="${1:-}"
  
  if [[ "$input" =~ "CLAUDE RESTORE" || "$input" =~ "claude restore" ]]; then
    return 0
  fi
  
  return 1
}

# ── Example usage (commented) ──────────────────────────────────────────────
# source "$WORKSPACE/scripts/lib/conservative-mode.sh"
# 
# if is_interim_period_active; then
#   log_with_interim "INFO" "Skipping expensive operation during interim period"
#   exit 0
# fi
# 
# OR:
# 
# case $(skip_if_interim) in
#   skip) echo "Skipped due to interim period"; exit 0 ;;
#   ok)   echo "Proceeding normally" ;;
# esac

# ──────────────────────────────────────────────────────────────────────────────
# INTERIM PERIOD CHECKLIST — L-040 (MANDATORY when declaring interim period)
# ──────────────────────────────────────────────────────────────────────────────
# When interim model period is declared (Anthropic outage, kimi substitution, etc.)
# ALL alert-generating scripts must be checked for interim awareness.
# Patching Warden alone IS NOT ENOUGH. The platform has multiple independent signal paths.
#
# MANDATORY AUDIT:
#   [ ] warden-cron.sh — Verify respects wardenBehavior field
#   [ ] validate-fallback-chain.sh — Verify skips Anthropic model checks
#   [ ] health-check.sh — Verify doesn't alert on Anthropic API 401/403
#   [ ] outage-detect.sh — Verify doesn't declare outage for credit depletion
#   [ ] outage-handler.sh — Verify doesn't trigger recovery for intentional interim
#   [ ] run-diagnostics.sh — Verify reports interim status, not "FAIL"
#   [ ] auto-heal.sh — Verify doesn't flag intentional model drifts as needs-ken
#   [ ] startup-checks.sh — Verify startup doesn't block on missing Anthropic models
#   [ ] obs-collector.sh — Verify OBS errors are annotated as interim
#
# VERIFICATION PROTOCOL:
#   For EACH script above:
#   1. Read the script
#   2. Identify ALL Anthropic model references (anthropic/*, claude*, sonnet*, haiku*, opus*)
#   3. Add interim period guard: source scripts/lib/conservative-mode.sh; if is_interim_period_active; then [skip/annotate]
#   4. Test: run script manually, verify interim-awareness
#   5. Commit: git add + git commit with CHG reference
#
# COMPLETION CRITERIA (L-037):
#   Do NOT claim "all scripts checked" until EVERY script is individually verified.
#   Partial completion: list which scripts are verified, which are pending.
#
# REFS: L-040, CHG-0362, CHG-0388, Day 24 fallback-chain-broken incident
