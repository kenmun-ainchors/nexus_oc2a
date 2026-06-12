#!/usr/bin/env bash
# lessons-staleness-check.sh — Warden 🔍 Strike-3 LESSONS.md Staleness Check
# Verifies memory/LESSONS.md has a recent lesson entry.
# Pattern: model-drift-check.sh (TKT-0013)
# Owner: TKT-0401 / CHG-0503

set -u

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
LESSONS_FILE="${LESSONS_FILE:-$WORKSPACE/memory/LESSONS.md}"
STATE="$WORKSPACE/state/lessons-staleness-state.json"
AEST_TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S+10:00")
TODAY=$(date +"%Y-%m-%d")

# ── Source skill-gate for consistency with other domain scripts ──────────────
# Use subshell to avoid bleeding set -e from skill-gate into main script.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
(set +e; source "${SCRIPT_DIR}/skill-gate.sh" "pg-sprint-backlog" 2>/dev/null) || true

write_state() {
  local lesson_id="$1"
  local age="$2"
  local status="$3"
  local last_updated="$4"
  mkdir -p "$(dirname "$STATE")" 2>/dev/null || true
  cat > "$STATE" <<EOF
{"checkedAt":"$AEST_TIMESTAMP","mostRecentLesson":${lesson_id:-null},"ageDays":${age},"status":"$status","lastUpdated":${last_updated:-null}}
EOF
}

# ── Missing file → exit 4 ────────────────────────────────────────────────────
if [[ ! -f "$LESSONS_FILE" ]]; then
  echo "CRITICAL  lessons.md (file missing: $LESSONS_FILE)" >&2
  echo "Error: LESSONS.md does not exist at $LESSONS_FILE" >&2
  write_state "null" "-1" "missing" "null"
  exit 4
fi

# ── Find most recent L-NNN heading + date ────────────────────────────────────
# Format in LESSONS.md: "## L-NNN — YYYY-MM-DD | ..." (or "## L-NNN | YYYY-MM-DD | ..." for newer entries).
# File is sorted chronologically ascending, so the MOST RECENT entry is at the BOTTOM.
# L-080: previous `head -1` was wrong — it picked L-030 (oldest with date match) and ignored
# new entries appended at the end. tail -1 returns the most recent by file order.
LINE=$(grep -E "^## L-[0-9]+.*[0-9]{4}-[0-9]{2}-[0-9]{2}" "$LESSONS_FILE" | tail -1 || true)

if [[ -z "$LINE" ]]; then
  echo "CRITICAL  lessons.md (no L-NNN entries found)" >&2
  write_state "null" "-1" "critical" "null"
  exit 3
fi

# Extract lesson ID (e.g. L-078)
LESSON_ID=$(echo "$LINE" | sed -E 's/^## (L-[0-9]+).*/\1/')
# Extract date
LESSON_DATE=$(echo "$LINE" | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}" | head -1)

# ── Compute age in days (macOS date compatibility) ──────────────────────────
if [[ "$(uname)" == "Darwin" ]]; then
  LESSON_EPOCH=$(date -j -f "%Y-%m-%d" "$LESSON_DATE" +%s 2>/dev/null || echo 0)
  TODAY_EPOCH=$(date -j -f "%Y-%m-%d" "$TODAY" +%s 2>/dev/null || echo 0)
else
  LESSON_EPOCH=$(date -d "$LESSON_DATE" +%s 2>/dev/null || echo 0)
  TODAY_EPOCH=$(date -d "$TODAY" +%s 2>/dev/null || echo 0)
fi

if [[ "$LESSON_EPOCH" -eq 0 || "$TODAY_EPOCH" -eq 0 ]]; then
  echo "CRITICAL  lessons.md (date parse failure: $LESSON_DATE)" >&2
  write_state "\"$LESSON_ID\"" "-1" "critical" "\"$LESSON_DATE\""
  exit 3
fi

AGE_DAYS=$(( (TODAY_EPOCH - LESSON_EPOCH) / 86400 ))

# ── Threshold logic ──────────────────────────────────────────────────────────
if [[ $AGE_DAYS -le 7 ]]; then
  STATUS="pass"
  LABEL="PASS"
  EXIT_CODE=0
elif [[ $AGE_DAYS -le 14 ]]; then
  STATUS="warn"
  LABEL="WARN"
  EXIT_CODE=1
elif [[ $AGE_DAYS -le 30 ]]; then
  STATUS="alert"
  LABEL="ALERT"
  EXIT_CODE=2
else
  STATUS="critical"
  LABEL="CRITICAL"
  EXIT_CODE=3
fi

echo "$LABEL  lessons.md (most recent: $LESSON_ID $LESSON_DATE, age: $AGE_DAYS days)"

# ── Persist state ────────────────────────────────────────────────────────────
write_state "\"$LESSON_ID\"" "$AGE_DAYS" "$STATUS" "\"$LESSON_DATE\""

exit $EXIT_CODE
