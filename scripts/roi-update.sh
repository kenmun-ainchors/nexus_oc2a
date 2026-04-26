#!/usr/bin/env bash
# ============================================================
# AInchors ROI Update Script
# Updates roi-tracker.json with new task entries and recalculates
# cumulative ROI metrics.
#
# Usage:
#   ./roi-update.sh add --date DATE --task-type TYPE --agent AGENT \
#                       --description DESC --hours HOURS \
#                       --human-rate RATE --agent-cost-aud COST \
#                       --deliverable DELIV [--revenue VALUE] \
#                       [--risk VALUE] [--notes NOTES]
#
#   ./roi-update.sh summary          # Print current ROI summary
#   ./roi-update.sh week [YYYY-WNN]  # Print week summary
#   ./roi-update.sh recalc           # Recalculate cumulative totals
#
# Task Types: strategic | operational | technical | content | admin | research
# ============================================================

set -euo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
TRACKER="$WORKSPACE/state/roi-tracker.json"
STATE_WRITE="$WORKSPACE/scripts/state-write.py"
AUD_RATE=0.64   # USD to AUD conversion (update periodically)

# Colour helpers
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "${CYAN}[roi-update]${NC} $*"; }
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
err()  { echo -e "${RED}✗ ERROR:${NC} $*" >&2; exit 1; }

# ── Dependency checks ──────────────────────────────────────
command -v jq  >/dev/null 2>&1 || err "jq is required. Install: brew install jq"
command -v python3 >/dev/null 2>&1 || err "python3 is required."
[[ -f "$TRACKER" ]] || err "Tracker not found: $TRACKER"

# ── Helpers ────────────────────────────────────────────────

get_week() {
  # Returns ISO week like 2026-W17
  local date_str="${1:-$(date +%Y-%m-%d)}"
  python3 -c "
from datetime import date
d = date.fromisoformat('$date_str')
year, week, _ = d.isocalendar()
print(f'{year}-W{week:02d}')
"
}

human_rate_for_type() {
  local task_type="$1"
  case "$task_type" in
    strategic)   echo 200 ;;
    technical)   echo 150 ;;
    operational) echo 120 ;;
    content)     echo 100 ;;
    research)    echo 90  ;;
    admin)       echo 35  ;;
    *)           echo 120 ;;
  esac
}

human_role_for_type() {
  local task_type="$1"
  case "$task_type" in
    strategic)   echo "Senior Business Analyst / CTO" ;;
    technical)   echo "Full-Stack Developer" ;;
    operational) echo "Operations Manager" ;;
    content)     echo "Content Writer / Marketing" ;;
    research)    echo "Research Analyst" ;;
    admin)       echo "Virtual Assistant / Admin" ;;
    *)           echo "Business Professional" ;;
  esac
}

# ── Command: add ───────────────────────────────────────────

cmd_add() {
  local date_val="" task_type="" agent="" description="" hours=""
  local human_rate="" agent_cost_aud="0" deliverable="" revenue="0"
  local risk="0" notes=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --date)          date_val="$2"; shift 2 ;;
      --task-type)     task_type="$2"; shift 2 ;;
      --agent)         agent="$2"; shift 2 ;;
      --description)   description="$2"; shift 2 ;;
      --hours)         hours="$2"; shift 2 ;;
      --human-rate)    human_rate="$2"; shift 2 ;;
      --agent-cost-aud) agent_cost_aud="$2"; shift 2 ;;
      --deliverable)   deliverable="$2"; shift 2 ;;
      --revenue)       revenue="$2"; shift 2 ;;
      --risk)          risk="$2"; shift 2 ;;
      --notes)         notes="$2"; shift 2 ;;
      *) err "Unknown flag: $1" ;;
    esac
  done

  # Defaults
  [[ -z "$date_val" ]] && date_val=$(date +%Y-%m-%d)
  [[ -z "$task_type" ]] && task_type="operational"
  [[ -z "$agent" ]] && agent="claude-sonnet-4-6"
  [[ -z "$description" ]] && err "--description is required"
  [[ -z "$hours" ]] && err "--hours is required"
  [[ -z "$deliverable" ]] && deliverable="$description"
  [[ -z "$human_rate" ]] && human_rate=$(human_rate_for_type "$task_type")

  local week
  week=$(get_week "$date_val")

  local human_cost_aud
  human_cost_aud=$(python3 -c "print(round($hours * $human_rate, 2))")

  local net_value_aud
  net_value_aud=$(python3 -c "print(round($human_cost_aud + $revenue + $risk - $agent_cost_aud, 2))")

  local roi_pct
  roi_pct=$(python3 -c "
cost = $agent_cost_aud
value = $human_cost_aud + $revenue + $risk
if cost > 0:
    print(round((value - cost) / cost * 100, 1))
else:
    print(9999)
")

  local human_role
  human_role=$(human_role_for_type "$task_type")

  local revenue_flag="false"
  [[ $(python3 -c "print('true' if $revenue > 0 else 'false')") == "true" ]] && revenue_flag="true"

  log "Adding task entry..."
  log "  Date:         $date_val ($week)"
  log "  Type:         $task_type | Agent: $agent"
  log "  Hours saved:  $hours hrs @ A\$$human_rate/hr = A\$$human_cost_aud"
  log "  Agent cost:   A\$$agent_cost_aud"
  log "  Revenue val:  A\$$revenue | Risk val: A\$$risk"
  log "  Net value:    A\$$net_value_aud | ROI: $roi_pct%"

  # Build new task entry JSON
  local new_entry
  new_entry=$(python3 -c "
import json
entry = {
    'date': '$date_val',
    'week': '$week',
    'taskType': '$task_type',
    'agent': '$agent',
    'description': '$description',
    'timeSavedHours': $hours,
    'humanCostEquivalentAUD': $human_cost_aud,
    'humanRole': '$human_role',
    'humanHourlyRateAUD': $human_rate,
    'agentCostAUD': $agent_cost_aud,
    'netValueAUD': $net_value_aud,
    'roiPercent': $roi_pct,
    'deliverable': '$deliverable',
    'revenueSupported': $revenue_flag,
    'revenueValueAUD': $revenue,
    'riskValueAUD': $risk,
    'notes': '$notes'
}
print(json.dumps(entry))
")

  # Append to taskLog using jq
  local tmp
  tmp=$(mktemp)
  jq ".taskLog += [$new_entry]" "$TRACKER" > "$tmp" && mv "$tmp" "$TRACKER"

  ok "Task entry added."

  # Recalculate cumulative totals
  cmd_recalc
}

# ── Command: recalc ────────────────────────────────────────

cmd_recalc() {
  log "Recalculating cumulative ROI..."

  python3 << 'PYEOF'
import json, os

tracker_path = "/Users/ainchorsangiefpl/.openclaw/workspace/state/roi-tracker.json"
with open(tracker_path) as f:
    data = json.load(f)

tasks = data.get("taskLog", [])

total_agent_cost  = sum(t.get("agentCostAUD", 0) for t in tasks)
total_time_saved  = sum(t.get("timeSavedHours", 0) for t in tasks)
total_time_value  = sum(t.get("humanCostEquivalentAUD", 0) for t in tasks)
total_output_val  = 0  # output value tracked via humanCostEquivalent
total_risk_val    = sum(t.get("riskValueAUD", 0) for t in tasks)
total_revenue_val = sum(t.get("revenueValueAUD", 0) for t in tasks)
total_value       = total_time_value + total_risk_val + total_revenue_val

net_value = total_value - total_agent_cost
roi_pct = round((total_value - total_agent_cost) / total_agent_cost * 100, 1) if total_agent_cost > 0 else 9999

data["cumulativeROI"] = {
    "startDate": data["cumulativeROI"].get("startDate", "2026-04-25"),
    "totalAgentCostAUD": round(total_agent_cost, 2),
    "totalValueDeliveredAUD": round(total_value, 2),
    "totalTimeSavedHours": round(total_time_saved, 1),
    "totalTimeSavedValueAUD": round(total_time_value, 2),
    "totalOutputValueAUD": round(total_output_val, 2),
    "totalRiskValueAUD": round(total_risk_val, 2),
    "totalRevenueValueAUD": round(total_revenue_val, 2),
    "netValueAUD": round(net_value, 2),
    "roiPercent": roi_pct,
    "note": "Auto-recalculated by roi-update.sh"
}

with open(tracker_path, "w") as f:
    json.dump(data, f, indent=2)

print(f"  Total agent cost:    A${total_agent_cost:.2f}")
print(f"  Total value:         A${total_value:.2f}")
print(f"    Time saved value:  A${total_time_value:.2f} ({total_time_saved:.1f} hrs)")
print(f"    Risk value:        A${total_risk_val:.2f}")
print(f"    Revenue value:     A${total_revenue_val:.2f}")
print(f"  Net value:           A${net_value:.2f}")
print(f"  ROI:                 {roi_pct}%")
PYEOF

  ok "Cumulative ROI updated."
}

# ── Command: summary ───────────────────────────────────────

cmd_summary() {
  log "AInchors ROI Summary"
  echo ""
  python3 << 'PYEOF'
import json

tracker_path = "/Users/ainchorsangiefpl/.openclaw/workspace/state/roi-tracker.json"
with open(tracker_path) as f:
    data = json.load(f)

roi = data.get("cumulativeROI", {})
budget = data.get("budgetTracking", {})
tasks = data.get("taskLog", [])

print("=" * 55)
print("  AInchors — AI Agent ROI Dashboard")
print("=" * 55)
print(f"  Period start:        {roi.get('startDate', 'N/A')}")
print(f"  Total tasks logged:  {len(tasks)}")
print("")
print("  💰 COST")
print(f"    Agent cost (all-time):  A${roi.get('totalAgentCostAUD', 0):.2f}")
print(f"    Monthly budget cap:     A${budget.get('monthlyBudgetCapAUD', 500):.2f}")
print("")
print("  📦 VALUE DELIVERED")
print(f"    Total value:            A${roi.get('totalValueDeliveredAUD', 0):.2f}")
print(f"    Time saved value:       A${roi.get('totalTimeSavedValueAUD', 0):.2f}")
print(f"    Hours saved:            {roi.get('totalTimeSavedHours', 0):.1f} hrs")
print(f"    Risk value:             A${roi.get('totalRiskValueAUD', 0):.2f}")
print(f"    Revenue attributed:     A${roi.get('totalRevenueValueAUD', 0):.2f}")
print("")
print("  📈 ROI")
print(f"    Net value:              A${roi.get('netValueAUD', 0):.2f}")
print(f"    ROI:                    {roi.get('roiPercent', 0)}%")
print("")
print("  🔄 RECENT TASKS")
for t in tasks[-5:]:
    print(f"    [{t['date']}] {t['taskType'][:8]:8} | {t['timeSavedHours']}h saved | A${t['humanCostEquivalentAUD']:>7.2f} value | {t['description'][:45]}")
print("=" * 55)
PYEOF
}

# ── Command: week ──────────────────────────────────────────

cmd_week() {
  local week_filter="${1:-$(get_week "$(date +%Y-%m-%d)")}"
  log "Week summary: $week_filter"
  python3 << PYEOF
import json

tracker_path = "/Users/ainchorsangiefpl/.openclaw/workspace/state/roi-tracker.json"
with open(tracker_path) as f:
    data = json.load(f)

week = "$week_filter"
tasks = [t for t in data.get("taskLog", []) if t.get("week") == week]

if not tasks:
    print(f"No tasks found for {week}")
else:
    total_hours  = sum(t.get("timeSavedHours", 0) for t in tasks)
    total_value  = sum(t.get("humanCostEquivalentAUD", 0) for t in tasks)
    total_cost   = sum(t.get("agentCostAUD", 0) for t in tasks)
    total_revenue= sum(t.get("revenueValueAUD", 0) for t in tasks)
    total_risk   = sum(t.get("riskValueAUD", 0) for t in tasks)
    net          = total_value + total_revenue + total_risk - total_cost
    roi          = round((total_value + total_revenue + total_risk - total_cost) / total_cost * 100, 1) if total_cost > 0 else 9999

    print(f"\n  Week {week}: {len(tasks)} tasks")
    print(f"  Hours saved:    {total_hours:.1f} hrs")
    print(f"  Time value:     A\${total_value:.2f}")
    print(f"  Revenue value:  A\${total_revenue:.2f}")
    print(f"  Risk value:     A\${total_risk:.2f}")
    print(f"  Agent cost:     A\${total_cost:.2f}")
    print(f"  Net value:      A\${net:.2f}")
    print(f"  Weekly ROI:     {roi}%")
    print()
    for t in tasks:
        print(f"  [{t['date']}] {t['taskType'][:10]:10} | {t['description'][:50]}")
PYEOF
}

# ── Command: notion-sync ───────────────────────────────────
# Syncs all unsynced task entries to Notion ROI database

cmd_notion_sync() {
  local notion_key
  notion_key=$(cat ~/.config/notion/api_key 2>/dev/null) || err "Notion API key not found"

  local db_id
  db_id=$(jq -r '.notionDatabaseId // empty' "$TRACKER" 2>/dev/null)
  [[ -z "$db_id" ]] && err "Notion database ID not set in tracker. Run create-notion-db first."

  log "Syncing unsynced tasks to Notion..."

  python3 << PYEOF
import json, urllib.request, urllib.error

tracker_path = "$TRACKER"
notion_key   = "$notion_key"
db_id        = "$db_id"

with open(tracker_path) as f:
    data = json.load(f)

tasks = [t for t in data.get("taskLog", []) if not t.get("notionSynced", False)]
log = data.setdefault("notionSyncLog", [])
synced = 0

for t in tasks:
    body = {
        "parent": {"database_id": db_id},
        "properties": {
            "Date":                  {"date": {"start": t["date"]}},
            "Week":                  {"rich_text": [{"text": {"content": t.get("week", "")}}]},
            "Task Type":             {"select": {"name": t.get("taskType", "operational").title()}},
            "Agent":                 {"select": {"name": t.get("agent", "claude-sonnet-4-6")}},
            "Time Saved (hrs)":      {"number": t.get("timeSavedHours", 0)},
            "Human Cost Equiv (AUD)":{"number": t.get("humanCostEquivalentAUD", 0)},
            "Agent Cost (AUD)":      {"number": t.get("agentCostAUD", 0)},
            "Net Value (AUD)":       {"number": t.get("netValueAUD", 0)},
            "ROI %":                 {"number": t.get("roiPercent", 0)},
            "Deliverable":           {"rich_text": [{"text": {"content": t.get("deliverable", "")[:2000]}}]},
            "Notes":                 {"rich_text": [{"text": {"content": t.get("notes", "")[:2000]}}]}
        }
    }
    req = urllib.request.Request(
        "https://api.notion.com/v1/pages",
        data=json.dumps(body).encode(),
        headers={
            "Authorization": f"Bearer {notion_key}",
            "Content-Type": "application/json",
            "Notion-Version": "2022-06-28"
        },
        method="POST"
    )
    try:
        with urllib.request.urlopen(req) as resp:
            result = json.loads(resp.read())
            t["notionSynced"] = True
            t["notionPageId"] = result.get("id", "")
            log.append({"date": t["date"], "taskDesc": t["description"][:60], "status": "synced"})
            synced += 1
            print(f"  ✓ Synced: {t['date']} — {t['description'][:50]}")
    except urllib.error.HTTPError as e:
        err_body = e.read().decode()
        print(f"  ✗ Failed: {t['description'][:50]} — {e.code}: {err_body[:200]}")
        log.append({"date": t["date"], "taskDesc": t["description"][:60], "status": f"error-{e.code}"})

with open(tracker_path, "w") as f:
    json.dump(data, f, indent=2)

print(f"\nSynced {synced}/{len(tasks)} tasks to Notion.")
PYEOF
}

# ── Command: budget-check ──────────────────────────────────

cmd_budget_check() {
  log "Budget check..."
  python3 << 'PYEOF'
import json
from datetime import date

tracker_path = "/Users/ainchorsangiefpl/.openclaw/workspace/state/roi-tracker.json"
with open(tracker_path) as f:
    data = json.load(f)

budget = data.get("budgetTracking", {})
cap_aud = budget.get("monthlyBudgetCapAUD", 500)
current_month = date.today().strftime("%Y-%m")

tasks = data.get("taskLog", [])
month_cost = sum(t.get("agentCostAUD", 0) for t in tasks if t.get("date", "").startswith(current_month))

pct = month_cost / cap_aud * 100
remaining = cap_aud - month_cost
days_in_month = 22
days_elapsed = date.today().day
daily_burn = month_cost / days_elapsed if days_elapsed > 0 else 0
days_remaining = remaining / daily_burn if daily_burn > 0 else 999

print(f"\n  Budget: A${month_cost:.2f} / A${cap_aud:.2f} ({pct:.1f}%)")
print(f"  Remaining: A${remaining:.2f}")
print(f"  Daily burn rate: A${daily_burn:.2f}/day")
print(f"  Estimated days to cap: {days_remaining:.0f} days")

if pct >= 90:
    print("  ⚠️  CRITICAL: 90%+ budget consumed!")
elif pct >= 75:
    print("  ⚠️  WARNING: 75%+ budget consumed.")
else:
    print("  ✓  Budget on track.")
PYEOF
}

# ── Main dispatcher ────────────────────────────────────────

COMMAND="${1:-summary}"
shift || true

case "$COMMAND" in
  add)           cmd_add "$@" ;;
  recalc)        cmd_recalc ;;
  summary)       cmd_summary ;;
  week)          cmd_week "${1:-}" ;;
  notion-sync)   cmd_notion_sync ;;
  budget-check)  cmd_budget_check ;;
  help|--help|-h)
    echo "Usage: roi-update.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  add            Add a new task entry (see --help for flags)"
    echo "  recalc         Recalculate cumulative ROI totals"
    echo "  summary        Print full ROI summary"
    echo "  week [YYYY-WNN] Print weekly breakdown"
    echo "  notion-sync    Sync unsynced tasks to Notion DB"
    echo "  budget-check   Check monthly budget status"
    echo ""
    echo "Add flags:"
    echo "  --date DATE              YYYY-MM-DD (default: today)"
    echo "  --task-type TYPE         strategic|operational|technical|content|admin|research"
    echo "  --agent AGENT            Agent name (default: claude-sonnet-4-6)"
    echo "  --description DESC       Task description (required)"
    echo "  --hours HOURS            Hours of human work saved (required)"
    echo "  --human-rate RATE        Override hourly rate in AUD (default: type-based)"
    echo "  --agent-cost-aud COST    Agent API cost in AUD (default: 0)"
    echo "  --deliverable DELIV      What was produced"
    echo "  --revenue VALUE          Revenue value in AUD (default: 0)"
    echo "  --risk VALUE             Risk value in AUD (default: 0)"
    echo "  --notes NOTES            Additional notes"
    ;;
  *) err "Unknown command: $COMMAND. Try: roi-update.sh help" ;;
esac
