#!/usr/bin/env bash
# eod-journal-finalizer.sh — EOD Journal Finalization Wrapper (CHG-0837)
# Deterministic EOD journal finalizer called by cron 4d926b2c.
# Usage: bash scripts/eod-journal-finalizer.sh [--dry-run] [--date YYYY-MM-DD]
#   --dry-run: print what would be done without making changes
#   --date: override target date (default: today's date in Australia/Melbourne)

set -euo pipefail

WORKSPACE="${WORKSPACE_ROOT:-/Users/ainchorsangiefpl/.openclaw/workspace}"
DRY_RUN=false
TARGET_DATE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --date)
      TARGET_DATE="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      echo "Usage: $0 [--dry-run] [--date YYYY-MM-DD]" >&2
      exit 1
      ;;
  esac
done

# Determine target date (AEST)
if [[ -z "$TARGET_DATE" ]]; then
  TARGET_DATE=$(TZ=Australia/Melbourne date +%Y-%m-%d)
fi

# Calculate day number (epoch 2026-04-25 = Day 1)
EPOCH_SECONDS=$(TZ=Australia/Melbourne date -j -f "%Y-%m-%d" "2026-04-25" "+%s" 2>/dev/null || echo 0)
TARGET_SECONDS=$(TZ=Australia/Melbourne date -j -f "%Y-%m-%d" "$TARGET_DATE" "+%s" 2>/dev/null || echo 0)
if [[ "$EPOCH_SECONDS" -gt 0 && "$TARGET_SECONDS" -gt 0 ]]; then
  DAY_NUM=$(( (TARGET_SECONDS - EPOCH_SECONDS) / 86400 + 1 ))
else
  DAY_NUM="?"
fi

JOURNAL_FILE="${WORKSPACE}/memory/journal-${TARGET_DATE}.md"
BLOCK_FILE="${WORKSPACE}/state/eod-blocked-${TARGET_DATE}.json"
ARIA_BRIEF="${WORKSPACE}/state/aria-daily-brief.md"

log() { echo "[EOD-FINALIZER] $*" >&2; }

echo "=== EOD Journal Finalizer (CHG-0837) ==="
echo "Target date: $TARGET_DATE | Day: $DAY_NUM | Dry-run: $DRY_RUN"
echo ""

# ──────────────────────────────────────────────
# STEP 1: Health Assert Gate
# ──────────────────────────────────────────────
log "STEP 1: Health Assert Gate"
if [[ -f "$BLOCK_FILE" ]]; then
  log "BLOCKED: $BLOCK_FILE exists"
  echo "EOD-BLOCKED: Block file exists for $TARGET_DATE. Aborting."
  exit 1
fi

if [[ "$DRY_RUN" == "false" ]]; then
  set +e
  bash "${WORKSPACE}/scripts/state-health-assert.sh"
  HEALTH_EXIT=$?
  set -euo pipefail
  if [[ $HEALTH_EXIT -ne 0 ]]; then
    log "HEALTH ASSERT FAILED (exit $HEALTH_EXIT)"
    echo "EOD-BLOCKED: Health assert failed. See $BLOCK_FILE"
    exit 1
  fi
  log "Health assert: PASS"
else
  log "Health assert: SKIP (dry-run)"
fi
echo ""

# ──────────────────────────────────────────────
# STEP 2: Journal Generate (gap fill / skeleton)
# ──────────────────────────────────────────────
log "STEP 2: Journal Generate (gap fill)"
if [[ "$DRY_RUN" == "false" ]]; then
  set +e
  bash "${WORKSPACE}/scripts/journal-generate.sh" "$TARGET_DATE"
  JGEN_EXIT=$?
  set -euo pipefail
  log "Journal generate: exit $JGEN_EXIT"
else
  log "Journal generate: SKIP (dry-run)"
  log "  Would run: bash ${WORKSPACE}/scripts/journal-generate.sh $TARGET_DATE"
fi
echo ""

# ──────────────────────────────────────────────
# STEP 3: Cost Report
# ──────────────────────────────────────────────
log "STEP 3: Cost Report"
if [[ "$DRY_RUN" == "false" ]]; then
  set +e
  COST_OUTPUT=$(bash "${WORKSPACE}/scripts/cost-tracker.sh" "$TARGET_DATE" 2>&1)
  COST_EXIT=$?
  set -euo pipefail
  log "Cost tracker: exit $COST_EXIT"
else
  log "Cost tracker: SKIP (dry-run)"
  log "  Would run: bash ${WORKSPACE}/scripts/cost-tracker.sh $TARGET_DATE"
fi
echo ""

# ──────────────────────────────────────────────
# STEP 4: Read Aria Daily Brief & append Business Stream
# ──────────────────────────────────────────────
log "STEP 4: Aria Business Stream"
ARIA_BUSINESS=""
if [[ -f "$ARIA_BRIEF" ]]; then
  ARIA_LINES=$(grep -E "^## " "$ARIA_BRIEF" | head -3 || echo "")
  ARIA_BUSINESS=$(echo "$ARIA_LINES" | sed 's/^## //' | tr '\n' '; ' | sed 's/; $//')
  if [[ -z "$ARIA_BUSINESS" ]]; then
    ARIA_BUSINESS="(Aria daily brief exists but no sections found)"
  fi
else
  log "NOTE: No aria-daily-brief.md found"
  ARIA_BUSINESS="(No Aria business brief available)"
fi
log "Business stream: $ARIA_BUSINESS"

# Append business stream to journal only if file exists
if [[ -f "$JOURNAL_FILE" && "$DRY_RUN" == "false" ]]; then
  cat >> "$JOURNAL_FILE" << EOF

## Business Stream (from Aria)
${ARIA_BUSINESS}

EOF
  log "Business stream appended to journal"
elif [[ "$DRY_RUN" == "true" ]]; then
  log "Business stream append: SKIP (dry-run)"
  if [[ -f "$JOURNAL_FILE" ]]; then
    log "  Would append business stream section to $JOURNAL_FILE"
  fi
fi
echo ""

# ──────────────────────────────────────────────
# STEP 5: Prepend Session Overview header
# ──────────────────────────────────────────────
log "STEP 5: Session Overview Header"

# Count entries (safe even if file missing)
set +e
if [[ -f "$JOURNAL_FILE" ]]; then
  ENTRY_COUNT=$(grep -c '^## [0-9][0-9]:[0-9][0-9]' "$JOURNAL_FILE" 2>/dev/null || echo 0)
  FILE_SIZE=$(wc -c < "$JOURNAL_FILE" 2>/dev/null || echo 0)
else
  ENTRY_COUNT=0
  FILE_SIZE=0
fi
set -euo pipefail

log "Journal: $ENTRY_COUNT entries, $FILE_SIZE bytes"

# Build the Session Overview header
OVERVIEW_HEADER=$(cat << EOF
# AInchors Day ${DAY_NUM} Journal — ${TARGET_DATE}
_Author: Yoda 🟢 | For: Ken Mun (CTO) | Private — personal review only_
_Finalized: 23:55 AEST_

## Session Overview
- [X] ${ENTRY_COUNT} entries logged today across sessions (webchat + Telegram)
- Business stream: ${ARIA_BUSINESS}
- Journal builder: EOD finalizer (CHG-0837)
- Health assert: PASS
- Journal gap check: ${FILE_SIZE} bytes, ${ENTRY_COUNT} entries

---

EOF
)

if [[ -f "$JOURNAL_FILE" && "$DRY_RUN" == "false" ]]; then
  TMPFILE=$(mktemp /tmp/eod-journal-XXXXXX)
  echo "$OVERVIEW_HEADER" > "$TMPFILE"
  cat "$JOURNAL_FILE" >> "$TMPFILE"
  mv "$TMPFILE" "$JOURNAL_FILE"
  log "Header prepended to $JOURNAL_FILE"
elif [[ "$DRY_RUN" == "true" ]]; then
  log "Header prepend: SKIP (dry-run)"
  log "  Would prepend ${DAY_NUM}-entry overview header to $JOURNAL_FILE"
fi
echo ""

# ──────────────────────────────────────────────
# STEP 6: Git Commit
# ──────────────────────────────────────────────
log "STEP 6: Git Commit"
if [[ "$DRY_RUN" == "false" ]]; then
  cd "$WORKSPACE"
  set +e
  git add memory/journal-*.md 2>&1
  ADD_EXIT=$?
  if [[ $ADD_EXIT -ne 0 ]]; then
    log "WARNING: git add returned $ADD_EXIT"
  fi
  git commit -m "docs: Day ${DAY_NUM} journal finalized ${TARGET_DATE}" 2>&1
  COMMIT_EXIT=$?
  set -euo pipefail
  if [[ $COMMIT_EXIT -eq 0 ]]; then
    COMMIT_HASH=$(git rev-parse HEAD)
    log "Committed: $COMMIT_HASH"
  else
    log "Commit returned $COMMIT_EXIT (nothing to commit or error)"
  fi
  cd - > /dev/null 2>&1 || true
else
  log "Git commit: SKIP (dry-run)"
  log "  Would run: git add memory/journal-*.md && git commit -m \"docs: Day ${DAY_NUM} journal finalized ${TARGET_DATE}\""
fi
echo ""

# ──────────────────────────────────────────────
# STEP 7: Verification
# ──────────────────────────────────────────────
log "STEP 7: Verification"
VERIFY_FAIL=false
if [[ "$DRY_RUN" == "false" ]]; then
  if [[ -f "$JOURNAL_FILE" ]]; then
    FINAL_SIZE=$(wc -c < "$JOURNAL_FILE" 2>/dev/null || echo 0)
    FINAL_ENTRIES=$(grep -c '^## [0-9][0-9]:[0-9][0-9]' "$JOURNAL_FILE" 2>/dev/null || echo 0)
    log "Journal file: $JOURNAL_FILE ($FINAL_SIZE bytes, $FINAL_ENTRIES entries)"
    if [[ "$FINAL_SIZE" -lt 500 ]]; then
      log "WARNING: Journal file size ($FINAL_SIZE bytes) < 500 bytes — undersized"
      VERIFY_FAIL=true
    fi
  else
    log "ERROR: Journal file $JOURNAL_FILE does not exist after finalization"
    VERIFY_FAIL=true
  fi
fi

if [[ "$VERIFY_FAIL" == "true" ]]; then
  echo "EOD-FAILURE: Verification failed — see logs above"
  exit 1
fi

echo "=== EOD Journal Finalizer: COMPLETE ==="
exit 0
