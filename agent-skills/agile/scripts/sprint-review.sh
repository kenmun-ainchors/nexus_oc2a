#!/bin/bash
# sprint-review.sh — Canonical Sprint Review Report Generator
# Part of the agile skill package.
# Usage: bash agent-skills/agile/scripts/sprint-review.sh [--sprint "Sprint N"]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TMP_DIR="$WORKSPACE_ROOT/.openclaw/tmp"
mkdir -p "$TMP_DIR"

# --- SKILL GATES ---
source "$WORKSPACE_ROOT/scripts/skill-gate.sh" "agile" || exit $?
source "$WORKSPACE_ROOT/scripts/skill-gate.sh" "pg-sprint-backlog" || exit $?

# --- ARGUMENTS ---
SPRINT_NAME=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sprint)
      SPRINT_NAME="$2"
      shift 2
      ;;
    --help)
      echo "Usage: bash agent-skills/agile/scripts/sprint-review.sh [--sprint \"Sprint N\"]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Use --help for usage." >&2
      exit 1
      ;;
  esac
done

# --- UTILITIES ---
log() { echo "[sprint-review] $1"; }
run_cmd() { bash "$@" 2>&1 || true; }

# Default to current sprint if not provided
if [[ -z "$SPRINT_NAME" ]]; then
  SPRINT_NAME=$(cd "$WORKSPACE_ROOT" && bash scripts/db-sprint.sh current 2>/dev/null | jq -r '.sprint_name // empty')
  if [[ -z "$SPRINT_NAME" ]]; then
    echo "ERROR: Could not determine current sprint. Use --sprint." >&2
    exit 1
  fi
fi

SAFE_NAME="$(echo "$SPRINT_NAME" | tr ' ' '-')"
REPORT_FILE="$TMP_DIR/sprint-review-report-${SAFE_NAME}.md"
TS="$(date '+%Y-%m-%d %H:%M AEST')"

log "Generating review for $SPRINT_NAME..."

# --- DATA COLLECTION ---
SPRINT_JSON=$(cd "$WORKSPACE_ROOT" && bash scripts/db-sprint.sh current 2>/dev/null || echo "{}")
SPRINT_STATUS=$(echo "$SPRINT_JSON" | jq -r '.status // "unknown"')
SPRINT_START=$(echo "$SPRINT_JSON" | jq -r '.start_date // "?"')
SPRINT_END=$(echo "$SPRINT_JSON" | jq -r '.end_date // "?"')
SPRINT_ITEMS=$(echo "$SPRINT_JSON" | jq '.items // []')
SPRINT_ITEM_COUNT=$(echo "$SPRINT_ITEMS" | jq 'length')

STATUS_TEXT=$(cd "$WORKSPACE_ROOT" && bash scripts/db-sprint.sh status --sprint "$SPRINT_NAME" 2>/dev/null || echo "Status unavailable")
PLAN_TEXT=$(cd "$WORKSPACE_ROOT" && bash scripts/db-sprint.sh plan --sprint "$SPRINT_NAME" 2>/dev/null || echo "Plan unavailable")

HEALTH_TEXT=$(cd "$WORKSPACE_ROOT" && bash scripts/health-check.sh 2>/dev/null || echo "Health check unavailable")
BUDGET_TEXT=$(cd "$WORKSPACE_ROOT" && bash scripts/request-budget-check.sh --report 2>/dev/null || echo "Budget check unavailable")
CRON_TEXT=$(cd "$WORKSPACE_ROOT" && bash scripts/cron-health-check.sh 2>/dev/null || echo "Cron check unavailable")

OPEN_DECISIONS=""
if [[ -f "$WORKSPACE_ROOT/state/open-decisions.json" ]]; then
  OPEN_DECISIONS=$(cat "$WORKSPACE_ROOT/state/open-decisions.json")
fi

DRAFT_DOCS=""
if [[ -f "$WORKSPACE_ROOT/state/draft-docs.json" ]]; then
  DRAFT_DOCS=$(cat "$WORKSPACE_ROOT/state/draft-docs.json")
fi

# --- REPORT ---
cat > "$REPORT_FILE" <<EOF
# Sprint Review — $SPRINT_NAME

_Generated: ${TS}_

## 1. Sprint Identity

| Field | Value |
|-------|-------|
| Sprint | $SPRINT_NAME |
| Status | $SPRINT_STATUS |
| Dates | $SPRINT_START to $SPRINT_END |
| Committed items (items array) | $SPRINT_ITEM_COUNT |

## 2. Delivery Status

\`\`\`
$STATUS_TEXT
\`\`\`

## 3. Sprint Plan Detail

\`\`\`
$PLAN_TEXT
\`\`\`

## 4. Platform Health

\`\`\`
$HEALTH_TEXT
\`\`\`

## 5. Budget / Cost

\`\`\`
$BUDGET_TEXT
\`\`\`

## 6. Cron Health

\`\`\`
$CRON_TEXT
\`\`\`

## 7. Open Decisions

EOF

if [[ -n "$OPEN_DECISIONS" ]]; then
  echo "\`\`\`json" >> "$REPORT_FILE"
  echo "$OPEN_DECISIONS" >> "$REPORT_FILE"
  echo "\`\`\`" >> "$REPORT_FILE"
else
  echo "_No open-decisions file found._" >> "$REPORT_FILE"
fi

cat >> "$REPORT_FILE" <<EOF

## 8. Draft Docs

EOF

if [[ -n "$DRAFT_DOCS" ]]; then
  echo "\`\`\`json" >> "$REPORT_FILE"
  echo "$DRAFT_DOCS" >> "$REPORT_FILE"
  echo "\`\`\`" >> "$REPORT_FILE"
else
  echo "_No draft-docs file found._" >> "$REPORT_FILE"
fi

cat >> "$REPORT_FILE" <<EOF

## 9. Next-Sprint Signals

- Review carry-forward items in Section 2.
- Check velocity signal against rolling 4-sprint baseline.
- Surface any P1/P2 blockers from Section 6 (Cron Health) or Section 4 (Health).

## 10. Checklist Reference

See \`agent-skills/agile/references/sprint-review-checklist.md\`.
EOF

log "Report written: $REPORT_FILE"
echo ""
echo "=== Sprint Review Summary — $SPRINT_NAME ==="
echo "Dates: $SPRINT_START to $SPRINT_END"
echo "Committed items: $SPRINT_ITEM_COUNT"
echo "Report: $REPORT_FILE"
echo ""
echo "Open decisions file: $(if [[ -n "$OPEN_DECISIONS" ]]; then echo present; else echo missing; fi)"
echo "Draft docs file: $(if [[ -n "$DRAFT_DOCS" ]]; then echo present; else echo missing; fi)"
