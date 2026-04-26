#!/usr/bin/env bash
# incident-log.sh — AInchors Incident Log CLI
# Usage:
#   incident-log.sh log      — Log a new incident (interactive)
#   incident-log.sh list     — List all incidents
#   incident-log.sh rca <id> — Show RCA for an incident
#   incident-log.sh mttr     — Show MTTR stats
#   incident-log.sh report   — Full incident report

set -euo pipefail

WORKSPACE="${WORKSPACE:-/Users/ainchorsangiefpl/.openclaw/workspace}"
LOG_FILE="$WORKSPACE/state/incident-log.json"

CMD="${1:-help}"

# ── Helpers ────────────────────────────────────────────────────────────────────

err() { echo "❌ $*" >&2; exit 1; }
require_jq() { command -v jq &>/dev/null || err "jq required. Install: brew install jq"; }

next_id() {
  local date_part today count
  today="$(date +%Y%m%d)"
  count="$(jq --arg d "$today" '[.incidents[] | select(.id | startswith("INC-"+$d))] | length' "$LOG_FILE" 2>/dev/null || echo 0)"
  printf "INC-%s-%03d" "$today" "$((count + 1))"
}

update_summary() {
  local tmp="$LOG_FILE.tmp"
  jq '
    .summary.total_incidents = (.incidents | length) |
    .summary.total_downtime_minutes = ([.incidents[].duration_minutes] | add // 0) |
    .summary.avg_mttr_minutes = (if (.incidents | length) > 0 then (([.incidents[].mttr_minutes] | add) / (.incidents | length) | round) else 0 end) |
    .summary.last_updated = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
  ' "$LOG_FILE" > "$tmp" && mv "$tmp" "$LOG_FILE"
}

# ── Commands ───────────────────────────────────────────────────────────────────

cmd_log() {
  require_jq

  echo "=== Log New Incident ==="
  read -rp "Incident type (outage/degraded/security/data/planned) [outage]: " TYPE
  TYPE="${TYPE:-outage}"

  read -rp "Trigger (what caused it): " TRIGGER
  read -rp "Duration in minutes: " DURATION
  read -rp "RCA (root cause): " RCA
  read -rp "Resolution (how fixed): " RESOLUTION
  read -rp "Recurrence (y/n) [n]: " RECUR_INPUT
  RECUR="false"; [[ "${RECUR_INPUT:-n}" == "y" ]] && RECUR="true"

  local ID START END
  ID="$(next_id)"
  START="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  # Compute end time based on duration
  END="$(date -u -v "-${DURATION}M" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"

  local tmp="$LOG_FILE.tmp"
  jq --arg id "$ID" \
     --arg ts_start "$START" \
     --arg ts_end "$END" \
     --arg type "$TYPE" \
     --arg trigger "$TRIGGER" \
     --argjson duration "$DURATION" \
     --arg rca "$RCA" \
     --arg resolution "$RESOLUTION" \
     --argjson mttr "$DURATION" \
     --argjson recurrence "$RECUR" \
     '.incidents += [{
       id: $id,
       timestamp_start: $ts_start,
       timestamp_end: $ts_end,
       type: $type,
       trigger: $trigger,
       duration_minutes: $duration,
       rca: $rca,
       resolution: $resolution,
       mttr_minutes: $mttr,
       recurrence: $recurrence,
       notion_page_id: null,
       status: "resolved"
     }]' "$LOG_FILE" > "$tmp" && mv "$tmp" "$LOG_FILE"

  update_summary
  echo "✅ Incident $ID logged."
}

cmd_list() {
  require_jq
  echo "=== AInchors Incident Log ==="
  jq -r '.incidents[] | "[\(.id)] \(.timestamp_start | split("T")[0]) | \(.type | ascii_upcase) | \(.duration_minutes)min | \(.trigger | .[0:60])"' "$LOG_FILE"
  echo ""
  jq -r '"Total: \(.summary.total_incidents) incidents | Total downtime: \(.summary.total_downtime_minutes)min | Avg MTTR: \(.summary.avg_mttr_minutes)min"' "$LOG_FILE"
}

cmd_rca() {
  require_jq
  local ID="${2:-}"
  [[ -z "$ID" ]] && err "Usage: incident-log.sh rca <INC-ID>"

  jq -r --arg id "$ID" '
    .incidents[] | select(.id == $id) |
    "=== RCA: \(.id) ===\n" +
    "Date:       \(.timestamp_start)\n" +
    "Type:       \(.type)\n" +
    "Trigger:    \(.trigger)\n" +
    "Duration:   \(.duration_minutes) minutes\n" +
    "MTTR:       \(.mttr_minutes) minutes\n" +
    "Status:     \(.status)\n\n" +
    "Root Cause:\n\(.rca)\n\n" +
    "Resolution:\n\(.resolution)"
  ' "$LOG_FILE"
}

cmd_mttr() {
  require_jq
  echo "=== MTTR Report ==="
  jq -r '
    "Total incidents:       \(.summary.total_incidents)",
    "Total downtime:        \(.summary.total_downtime_minutes) minutes",
    "Average MTTR:          \(.summary.avg_mttr_minutes) minutes",
    "",
    "By type:",
    (.incidents | group_by(.type)[] |
      "  \(.[0].type): \(length) incident(s), avg \((map(.mttr_minutes) | add / length | round))min MTTR")
  ' "$LOG_FILE"
}

cmd_report() {
  require_jq
  echo "==================================================="
  echo " AInchors OC1 — Incident Report"
  echo " Generated: $(date '+%Y-%m-%d %H:%M %Z')"
  echo "==================================================="
  echo ""
  cmd_list
  echo ""
  echo "--- Full Details ---"
  jq -r '.incidents[] |
    "\n[\(.id)] \(.type | ascii_upcase) — \(.timestamp_start)\n" +
    "  Trigger:    \(.trigger)\n" +
    "  Duration:   \(.duration_minutes)min | MTTR: \(.mttr_minutes)min\n" +
    "  Status:     \(.status)\n" +
    "  RCA:        \(.rca)\n" +
    "  Resolution: \(.resolution)"
  ' "$LOG_FILE"
}

# ── Dispatch ───────────────────────────────────────────────────────────────────

case "$CMD" in
  log)    cmd_log ;;
  list)   cmd_list ;;
  rca)    cmd_rca "$@" ;;
  mttr)   cmd_mttr ;;
  report) cmd_report ;;
  help|*)
    echo "Usage: incident-log.sh <command>"
    echo ""
    echo "Commands:"
    echo "  log      Log a new incident (interactive)"
    echo "  list     List all incidents"
    echo "  rca <id> Show RCA for incident ID"
    echo "  mttr     MTTR statistics"
    echo "  report   Full incident report"
    ;;
esac
