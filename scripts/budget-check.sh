#!/bin/zsh
# AInchors Budget Check — TKT-0092 FinOps
# Usage: budget-check.sh [--agent AGENT_ID] [--workflow WORKFLOW_NAME] [--report]
# Checks per-agent and workflow cost caps against actual spend.
# Writes alerts to state/budget-alert-state.json
# Exit codes: 0=OK, 1=warning (alert threshold), 2=exceeded (budget breached)

WORKSPACE="$HOME/.openclaw/workspace"
DB_READ="$WORKSPACE/scripts/db-read.sh"
# PG SSOT for cost/ticket data, file fallback for agent budgets
COST_STATE="$WORKSPACE/state/cost-state.json"  # fallback cache for db-read output
BUDGET_STATE="$WORKSPACE/state/agent-budgets.json"  # not yet in PG
ALERT_STATE="$WORKSPACE/state/budget-alert-state.json"
JQ="/opt/homebrew/bin/jq"
DATE="$(date +%Y-%m-%d)"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Parse args
MODE="check"
TARGET_AGENT=""
TARGET_WORKFLOW=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report) MODE="report"; shift ;;
    --agent)  MODE="agent"; TARGET_AGENT="$2"; shift 2 ;;
    --workflow) MODE="workflow"; TARGET_WORKFLOW="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# Verify dependencies
if [[ ! -f "$JQ" ]]; then
  echo "ERROR: jq not found at $JQ"
  exit 1
fi

# Read cost state from PG (SSOT) with file fallback
COST_STATE_DATA="$("$DB_READ" state_cost 2>/dev/null)"
if [[ -z "$COST_STATE_DATA" || "$COST_STATE_DATA" == "null" ]]; then
  # PG failed — fallback to file
  if [[ -f "$COST_STATE" ]]; then
    COST_STATE_DATA="$(cat "$COST_STATE")"
  else
    echo "ERROR: Cannot read cost state from PG or file"
    exit 1
  fi
fi

if [[ ! -f "$BUDGET_STATE" ]]; then
  echo "ERROR: agent-budgets.json not found at $BUDGET_STATE"
  exit 1
fi

# ---------------------------------------------------------------------------
# Extract today's total platform cost (from PG SSOT)
# Note: per-agent cost is not yet tracked separately. We use total cost and
# allocate proportionally to detect platform-level breaches.
# ---------------------------------------------------------------------------
PLATFORM_SPEND_TODAY="$(echo "$COST_STATE_DATA" | $JQ -r ".history[\"$DATE\"].totalCost // 0" 2>/dev/null || echo 0)"
PLATFORM_CAP="$($JQ -r '.dailyPlatformCap' "$BUDGET_STATE")"

# Read existing alert state (or init)
if [[ -f "$ALERT_STATE" ]]; then
  EXISTING_ALERTS="$($JQ -r '.alerts' "$ALERT_STATE" 2>/dev/null || echo '[]')"
else
  EXISTING_ALERTS="[]"
fi

EXIT_CODE=0
NEW_ALERTS="[]"

# ---------------------------------------------------------------------------
# Per-agent cost check
# We derive per-agent spend by reading session logs for each agent directory
# ---------------------------------------------------------------------------
check_agent() {
  local agent_id="$1"
  local daily_budget="$2"
  local alert_at="$3"
  local session_dir="$HOME/.openclaw/agents/$agent_id/sessions"

  # Sum today's spend for this agent from session logs
  local agent_spend=0
  agent_spend=$(python3 -c "
import json, glob, os
date = '$DATE'
agents_dir = os.path.expanduser('$HOME/.openclaw/agents/$agent_id/sessions')
total = 0.0
for jsonl_file in glob.glob(f'{agents_dir}/*.jsonl'):
    if '.trajectory.' in jsonl_file:
        continue
    try:
        with open(jsonl_file, 'r') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    record = json.loads(line)
                except:
                    continue
                ts = record.get('timestamp', '')
                if not ts.startswith(date):
                    continue
                msg = record.get('message', {})
                if record.get('type') != 'message' or msg.get('role') != 'assistant':
                    continue
                usage = msg.get('usage')
                if not usage:
                    continue
                cost = (usage.get('cost') or {}).get('total') or 0
                total += cost
    except:
        pass
print(round(total, 4))
" 2>/dev/null || echo 0)

  local pct=$(python3 -c "
spend=$agent_spend; budget=$daily_budget
print(round(spend/budget, 4) if budget > 0 else 0)")

  local agent_status="ok"
  if python3 -c "exit(0 if float('$agent_spend') >= float('$daily_budget') else 1)" 2>/dev/null; then
    agent_status="exceeded"
  elif python3 -c "exit(0 if float('$agent_spend') >= float('$daily_budget') * float('$alert_at') else 1)" 2>/dev/null; then
    agent_status="warning"
  fi

  echo "$agent_id|$agent_spend|$daily_budget|$pct|$agent_status"
}

# ---------------------------------------------------------------------------
# REPORT mode — print table of all agents
# ---------------------------------------------------------------------------
if [[ "$MODE" == "report" || "$MODE" == "check" ]]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  AInchors Budget Report — $DATE"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "  %-18s %10s %10s %8s %12s\n" "AGENT" "TODAY" "BUDGET" "%" "STATUS"
  printf "  %-18s %10s %10s %8s %12s\n" "──────────────────" "──────────" "──────────" "────────" "────────────"

  ALERT_ENTRIES="[]"

  # Platform-level check first
  PLATFORM_PCT=$(python3 -c "print(round(float('$PLATFORM_SPEND_TODAY')/float('$PLATFORM_CAP')*100, 1) if float('$PLATFORM_CAP') > 0 else 0)" 2>/dev/null || echo 0)
  PLATFORM_STATUS="✅ OK"
  if python3 -c "exit(0 if float('$PLATFORM_SPEND_TODAY') >= float('$PLATFORM_CAP') else 1)" 2>/dev/null; then
    PLATFORM_STATUS="❌ EXCEEDED"
    EXIT_CODE=2
  elif python3 -c "exit(0 if float('$PLATFORM_SPEND_TODAY') >= float('$PLATFORM_CAP') * 0.8 else 1)" 2>/dev/null; then
    PLATFORM_STATUS="⚠️  WARNING"
    [[ $EXIT_CODE -eq 0 ]] && EXIT_CODE=1
  fi
  printf "  %-18s %10s %10s %8s %12s\n" "[PLATFORM]" "\$$PLATFORM_SPEND_TODAY" "\$$PLATFORM_CAP" "${PLATFORM_PCT}%" "$PLATFORM_STATUS"
  echo ""

  # Per-agent checks
  AGENTS=($($JQ -r '.agents | keys[]' "$BUDGET_STATE"))
  for agent_id in $AGENTS; do
    daily_budget=$($JQ -r --arg a "$agent_id" '.agents[$a].dailyBudgetUsd' "$BUDGET_STATE")
    alert_at=$($JQ -r --arg a "$agent_id" '.agents[$a].alertAt' "$BUDGET_STATE")
    
    result=$(check_agent "$agent_id" "$daily_budget" "$alert_at")
    spend=$(echo "$result" | cut -d'|' -f2)
    budget=$(echo "$result" | cut -d'|' -f3)
    pct=$(echo "$result" | cut -d'|' -f4)
    agent_check_status=$(echo "$result" | cut -d'|' -f5)
    pct_display=$(python3 -c "print(round(float('$pct')*100,1))" 2>/dev/null || echo 0)

    case "$agent_check_status" in
      exceeded) status_display="❌ EXCEEDED"; [[ $EXIT_CODE -lt 2 ]] && EXIT_CODE=2 ;;
      warning)  status_display="⚠️  WARNING";  [[ $EXIT_CODE -lt 1 ]] && EXIT_CODE=1 ;;
      *)        status_display="✅ OK" ;;
    esac

    printf "  %-18s %10s %10s %8s %12s\n" "$agent_id" "\$$spend" "\$$budget" "${pct_display}%" "$status_display"

    # Build alert entry if needed
    if [[ "$agent_check_status" == "exceeded" || "$agent_check_status" == "warning" ]]; then
      ALERT_ENTRIES=$(echo "$ALERT_ENTRIES" | $JQ \
        --arg agent "$agent_id" \
        --arg type "$status" \
        --argjson spend "$spend" \
        --argjson budget "$budget" \
        --argjson pct "$pct" \
        --arg now "$NOW" \
        '. + [{
          "agent": $agent,
          "type": $type,
          "todaySpend": $spend,
          "budget": $budget,
          "pct": $pct,
          "detectedAt": $now,
          "acknowledged": false
        }]')
    fi
  done

  echo ""
  echo "  Platform cap: \$$PLATFORM_CAP/day"
  echo "  Avg daily (14d): \$$(echo "$COST_STATE_DATA" | $JQ -r '.avgDailyCost // "N/A"' 2>/dev/null || echo "N/A")"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Write alert state — atomic write via Python
  python3 -c "
import sys, os, json
try:
    sys.path.insert(0, os.path.join(os.path.dirname('$0'), 'lib'))
    from atomic_write import atomic_write_json as atw
    data = {'lastChecked': '$NOW', 'alerts': json.loads('''$ALERT_ENTRIES''')}
    atw('$ALERT_STATE', data)
" 2>/dev/null || echo '{"lastChecked": "$NOW", "alerts": $ALERT_ENTRIES}' > "$ALERT_STATE"

  if [[ $EXIT_CODE -eq 2 ]]; then
    echo "🚨 BUDGET EXCEEDED — at least one agent or platform cap breached."
  elif [[ $EXIT_CODE -eq 1 ]]; then
    echo "⚠️  BUDGET WARNING — at least one agent approaching limit."
  else
    echo "✅ All agents within budget."
  fi
  echo ""
fi

# ---------------------------------------------------------------------------
# AGENT mode — check a single agent
# ---------------------------------------------------------------------------
if [[ "$MODE" == "agent" ]]; then
  if [[ -z "$TARGET_AGENT" ]]; then
    echo "ERROR: --agent requires an agent ID"
    exit 1
  fi
  
  daily_budget=$($JQ -r --arg a "$TARGET_AGENT" '.agents[$a].dailyBudgetUsd // empty' "$BUDGET_STATE")
  if [[ -z "$daily_budget" ]]; then
    echo "ERROR: Agent '$TARGET_AGENT' not found in agent-budgets.json"
    exit 1
  fi
  alert_at=$($JQ -r --arg a "$TARGET_AGENT" '.agents[$a].alertAt' "$BUDGET_STATE")
  
  result=$(check_agent "$TARGET_AGENT" "$daily_budget" "$alert_at")
  spend=$(echo "$result" | cut -d'|' -f2)
  pct=$(echo "$result" | cut -d'|' -f4)
  agent_check_status=$(echo "$result" | cut -d'|' -f5)
  pct_display=$(python3 -c "print(round(float('$pct')*100,1))" 2>/dev/null || echo 0)

  echo "Agent: $TARGET_AGENT | Today: \$$spend | Budget: \$$daily_budget | ${pct_display}% | Status: $agent_check_status"

  case "$agent_check_status" in
    exceeded) EXIT_CODE=2 ;;
    warning)  EXIT_CODE=1 ;;
    *)        EXIT_CODE=0 ;;
  esac
fi

# ---------------------------------------------------------------------------
# WORKFLOW mode — check a specific workflow's estimated vs cap
# ---------------------------------------------------------------------------
if [[ "$MODE" == "workflow" ]]; then
  if [[ -z "$TARGET_WORKFLOW" ]]; then
    echo "ERROR: --workflow requires a workflow name"
    exit 1
  fi
  
  cap=$($JQ -r --arg w "$TARGET_WORKFLOW" '.workflows[$w].perRunCapUsd // empty' "$BUDGET_STATE")
  if [[ -z "$cap" ]]; then
    echo "ERROR: Workflow '$TARGET_WORKFLOW' not found in agent-budgets.json"
    exit 1
  fi
  
  # estimate_workflow_cost is in cost-tracker.sh — source it
  TRACKER="$WORKSPACE/scripts/cost-tracker.sh"
  if [[ -f "$TRACKER" ]]; then
    # Call the estimator inline
    python3 << PYEOF
import json, os
# Read cost data from PG via the already-loaded data
state_file = os.path.expanduser("$COST_STATE")
workflow = "$TARGET_WORKFLOW"
cap = float("$cap")

# Without per-workflow session tagging, we estimate from total daily cost
# divided by expected workflow frequency per day
# This is a placeholder until per-workflow cost tagging is implemented
print(f"WORKFLOW {workflow}: p50=N/A p90=N/A cap=\${cap:.2f} STATUS=NO_DATA")
print(f"Note: Per-workflow cost tracking requires session tagging. Use --report for platform-level view.")
PYEOF
  else
    echo "WORKFLOW $TARGET_WORKFLOW: cap=\$$cap (no historical data)"
  fi
fi

exit $EXIT_CODE
