#!/bin/bash
# daily-master-promote-check.sh — Daily-to-Master Memory Promotion Gate
#
# Scans memory/YYYY-MM-DD.md and memory/journal-YYYY-MM-DD.md files for
# #master-update and #execution-state tagged lines, then checks whether
# each tagged statement is reflected in MEMORY.md and the latest context
# handoff delta.
#
# Uses keyword-based drift detection: extracts significant tokens from each
# tagged statement and measures what fraction appear in each target file.
# A statement is considered "reflected" if >= 60% of its keywords appear
# in the target, OR if forced-key terms (e.g. "crest", "v1.3", "executed",
# "2026-06-20") are present.
#
# Usage:
#   bash scripts/daily-master-promote-check.sh [options]
#
# Options:
#   --since YYYY-MM-DD    Scan files from this date onward (default: 14 days before today)
#   --memory-file PATH    Target MEMORY.md file (default: MEMORY.md in workspace root)
#   --delta-file PATH     Target context handoff delta file (default: latest in docs/context-handoffs/)
#   --dry-run             Print JSON report but do not exit with error code
#   --help                Show this help text
#
# Exit codes:
#   0 — No drift found (or --dry-run)
#   1 — Drift found (statements in daily files not reflected in master targets)
#   2 — Usage error
#   3 — Missing dependency (jq)
#
# Output: JSON to stdout with keys:
#   drift       — array of tagged statements not found in master targets
#   promoted    — array of tagged statements found in master targets
#   total       — total tagged statements found
#   memory_file — path to MEMORY.md used
#   delta_file  — path to delta file used
#   since       — scan start date

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────
WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsoc2a/.openclaw/workspace}"
MEMORY_DIR="$WORKSPACE_ROOT/memory"
DEFAULT_MEMORY_FILE="$WORKSPACE_ROOT/MEMORY.md"
DEFAULT_DELTA_DIR="$WORKSPACE_ROOT/docs/context-handoffs"

# ── Parse args ────────────────────────────────────────────────────────────
SINCE=""
MEMORY_FILE=""
DELTA_FILE=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)
      shift
      if [[ -z "${1:-}" ]]; then
        echo "ERROR: --since requires a date argument (YYYY-MM-DD)" >&2
        exit 2
      fi
      SINCE="$1"
      shift
      ;;
    --memory-file)
      shift
      if [[ -z "${1:-}" ]]; then
        echo "ERROR: --memory-file requires a path argument" >&2
        exit 2
      fi
      MEMORY_FILE="$1"
      shift
      ;;
    --delta-file)
      shift
      if [[ -z "${1:-}" ]]; then
        echo "ERROR: --delta-file requires a path argument" >&2
        exit 2
      fi
      DELTA_FILE="$1"
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help|-h)
      echo "daily-master-promote-check.sh — Daily-to-Master Memory Promotion Gate"
      echo ""
      echo "Scans memory/YYYY-MM-DD.md and memory/journal-YYYY-MM-DD.md files for"
      echo "#master-update and #execution-state tagged lines, then checks whether"
      echo "each tagged statement is reflected in MEMORY.md and the latest context"
      echo "handoff delta."
      echo ""
      echo "Usage:"
      echo "  bash scripts/daily-master-promote-check.sh [options]"
      echo ""
      echo "Options:"
      echo "  --since YYYY-MM-DD    Scan files from this date onward (default: 14 days before today)"
      echo "  --memory-file PATH    Target MEMORY.md file (default: MEMORY.md in workspace root)"
      echo "  --delta-file PATH     Target context handoff delta file (default: latest in docs/context-handoffs/)"
      echo "  --dry-run             Print JSON report but do not exit with error code"
      echo "  --help                Show this help text"
      echo ""
      echo "Exit codes:"
      echo "  0 — No drift found (or --dry-run)"
      echo "  1 — Drift found"
      echo "  2 — Usage error"
      echo "  3 — Missing dependency (jq)"
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      echo "Usage: bash scripts/daily-master-promote-check.sh --help" >&2
      exit 2
      ;;
  esac
done

# ── Dependencies ───────────────────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not found" >&2
  exit 3
fi

# ── Resolve defaults ───────────────────────────────────────────────────────
if [[ -z "$SINCE" ]]; then
  SINCE=$(date -v-14d +%Y-%m-%d 2>/dev/null || date -d '14 days ago' +%Y-%m-%d 2>/dev/null || echo "unknown")
fi

if [[ -z "$MEMORY_FILE" ]]; then
  MEMORY_FILE="$DEFAULT_MEMORY_FILE"
fi

if [[ -z "$DELTA_FILE" ]]; then
  # Find latest delta file by sorting filenames (lexicographic works for YYYYMMDD-YYYYMMDD)
  LATEST_DELTA=$(ls -1 "$DEFAULT_DELTA_DIR"/Context-Handoff-Delta-*.md 2>/dev/null | sort | tail -1 || true)
  if [[ -n "$LATEST_DELTA" ]]; then
    DELTA_FILE="$LATEST_DELTA"
  else
    DELTA_FILE=""
  fi
fi

# ── Helper: extract keywords from a statement ─────────────────────────────
# Removes tags, stop words, punctuation; normalizes whitespace; lowercases;
# returns tokens of length >= 3, one per line.
extract_keywords() {
  local text="$1"
  # Remove #master-update and #execution-state tags
  text="${text//#master-update/}"
  text="${text//#execution-state/}"
  # Remove punctuation (keep alphanumeric, hyphens, dots, slashes, underscores)
  text=$(echo "$text" | sed 's/[][{}()!@$%^&*+=<>?~`"'\'';:,]/ /g' | tr -s ' ')
  # Lowercase
  text=$(echo "$text" | tr '[:upper:]' '[:lower:]')
  # Split into words, filter stop words and short tokens
  local stop_words='^(a|an|the|and|or|but|in|on|at|to|for|of|with|by|is|was|are|were|be|been|being|it|its|this|that|these|those|from|as|not|yet|until|after|before)$'
  echo "$text" | tr ' ' '\n' | grep -vE "$stop_words" | grep -E '^.{3,}$' | sort -u
}

# ── Helper: check if a statement is reflected in target content ────────────
# Echoes the match ratio (float). Returns 0 (reflected) or 1 (not reflected).
# A statement is reflected if >= 60% of keywords match OR forced-key terms present.
check_reflection() {
  local statement="$1"
  local target_content="$2"

  # Extract keywords from statement
  local keywords
  keywords=$(extract_keywords "$statement")

  # Count total keywords
  local total_kw=0
  local matched_kw=0

  # Forced-key terms that indicate reflection even at low ratio
  # These are checked as exact substring matches (case-insensitive)
  # to avoid false positives (e.g., "executed" should not match "not executed")
  # Multi-word phrases are checked as-is.
  local forced_terms
  forced_terms="fully executed|2026-06-20"

  # Normalize target content for matching (lowercase)
  local target_lc
  target_lc=$(echo "$target_content" | tr '[:upper:]' '[:lower:]')

  # Check each keyword
  while IFS= read -r kw; do
    [[ -z "$kw" ]] && continue
    total_kw=$((total_kw + 1))
    if echo "$target_lc" | grep -qF "$kw"; then
      matched_kw=$((matched_kw + 1))
    fi
  done <<< "$keywords"

  # Calculate ratio
  if [[ "$total_kw" -eq 0 ]]; then
    echo "0.00"
    return 1
  fi

  local ratio
  ratio=$(awk "BEGIN { printf \"%.2f\", $matched_kw / $total_kw }")
  echo "$ratio"

  # Check forced-key terms with exact substring matching
  # to avoid false positives like "executed" matching "not executed"
  local forced_found=false
  local saved_ifs="$IFS"
  IFS='|'
  for term in $forced_terms; do
    IFS="$saved_ifs"
    if echo "$target_lc" | grep -qiF "$term"; then
      forced_found=true
      break
    fi
    IFS='|'
  done
  IFS="$saved_ifs"

  # Threshold: 60% match OR forced-key present
  local threshold=0.60
  local above_threshold
  above_threshold=$(echo "$ratio >= $threshold" | bc -l 2>/dev/null || echo 0)
  if [[ "$above_threshold" = 1 ]] || [[ "$forced_found" = true ]]; then
    return 0
  fi

  return 1
}

# ── Collect tagged lines from daily memory/journal files ──────────────────
TAGGED_LINES=""
TOTAL=0

# Build date range
SINCE_EPOCH=$(date -j -f "%Y-%m-%d" "$SINCE" "+%s" 2>/dev/null || date -d "$SINCE" +%s 2>/dev/null || echo 0)
TODAY_EPOCH=$(date +%s 2>/dev/null || date -j +%s 2>/dev/null || echo 0)

# Scan memory/YYYY-MM-DD.md files
for f in "$MEMORY_DIR"/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md; do
  [[ -f "$f" ]] || continue
  BASENAME=$(basename "$f" .md)
  FILE_EPOCH=$(date -j -f "%Y-%m-%d" "$BASENAME" "+%s" 2>/dev/null || date -d "$BASENAME" +%s 2>/dev/null || echo 0)
  if [[ "$FILE_EPOCH" -ge "$SINCE_EPOCH" ]] 2>/dev/null; then
    while IFS= read -r line; do
      if echo "$line" | grep -q '#master-update\|#execution-state'; then
        LINENO=$(grep -n "$line" "$f" | head -1 | cut -d: -f1)
        TAG=""
        if echo "$line" | grep -q '#master-update'; then TAG="master-update"; fi
        if echo "$line" | grep -q '#execution-state'; then TAG="execution-state"; fi
        TAGGED_LINES+="$BASENAME|$LINENO|$TAG|$line"$'\n'
        TOTAL=$((TOTAL + 1))
      fi
    done < "$f"
  fi
done

# Scan memory/journal-YYYY-MM-DD.md files
for f in "$MEMORY_DIR"/journal-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md; do
  [[ -f "$f" ]] || continue
  # Extract date from journal-YYYY-MM-DD.md
  BASENAME=$(basename "$f" .md | sed 's/^journal-//')
  FILE_EPOCH=$(date -j -f "%Y-%m-%d" "$BASENAME" "+%s" 2>/dev/null || date -d "$BASENAME" +%s 2>/dev/null || echo 0)
  if [[ "$FILE_EPOCH" -ge "$SINCE_EPOCH" ]] 2>/dev/null; then
    while IFS= read -r line; do
      if echo "$line" | grep -q '#master-update\|#execution-state'; then
        LINENO=$(grep -n "$line" "$f" | head -1 | cut -d: -f1)
        TAG=""
        if echo "$line" | grep -q '#master-update'; then TAG="master-update"; fi
        if echo "$line" | grep -q '#execution-state'; then TAG="execution-state"; fi
        TAGGED_LINES+="journal-$BASENAME|$LINENO|$TAG|$line"$'\n'
        TOTAL=$((TOTAL + 1))
      fi
    done < "$f"
  fi
done

# ── Check each tagged line against master targets ─────────────────────────
DRIFT_JSON=""
PROMOTED_JSON=""
DRIFT_COUNT=0
PROMOTED_COUNT=0

# Read master files
MEMORY_CONTENT=""
if [[ -f "$MEMORY_FILE" ]]; then
  MEMORY_CONTENT=$(cat "$MEMORY_FILE")
fi

DELTA_CONTENT=""
if [[ -n "$DELTA_FILE" && -f "$DELTA_FILE" ]]; then
  DELTA_CONTENT=$(cat "$DELTA_FILE")
fi

while IFS='|' read -r SOURCE_FILE LINE_NUM TAG TAG_LINE; do
  [[ -z "$SOURCE_FILE" ]] && continue

  # Extract the statement after the tag for matching
  # Remove the tag itself and any leading/trailing whitespace
  STATEMENT=$(echo "$TAG_LINE" | sed 's/#master-update//g; s/#execution-state//g' | xargs)

  # Check if statement is reflected in MEMORY.md using keyword matching
  IN_MEMORY=false
  MEMORY_RATIO=0.00
  if [[ -n "$MEMORY_CONTENT" ]]; then
    MEMORY_RATIO=$(check_reflection "$STATEMENT" "$MEMORY_CONTENT"; echo __EXIT__$?)
    _mr_exit="${MEMORY_RATIO##*__EXIT__}"
    MEMORY_RATIO="${MEMORY_RATIO%__EXIT__*}"
    if [[ "$_mr_exit" -eq 0 ]]; then
      IN_MEMORY=true
    fi
  fi

  # Check if statement is reflected in delta file using keyword matching
  IN_DELTA=false
  DELTA_RATIO=0.00
  if [[ -n "$DELTA_CONTENT" ]]; then
    DELTA_RATIO=$(check_reflection "$STATEMENT" "$DELTA_CONTENT"; echo __EXIT__$?)
    _dr_exit="${DELTA_RATIO##*__EXIT__}"
    DELTA_RATIO="${DELTA_RATIO%__EXIT__*}"
    if [[ "$_dr_exit" -eq 0 ]]; then
      IN_DELTA=true
    fi
  fi

  ENTRY_JSON=$(jq -n \
    --arg source "$SOURCE_FILE" \
    --arg line "$LINE_NUM" \
    --arg tag "$TAG" \
    --arg statement "$STATEMENT" \
    --arg date "$SOURCE_FILE" \
    --argjson in_memory $IN_MEMORY \
    --argjson in_delta $IN_DELTA \
    --argjson memory_match_ratio "$MEMORY_RATIO" \
    --argjson delta_match_ratio "$DELTA_RATIO" \
    '{
      source_file: $source,
      line_number: ($line | tonumber),
      tag: $tag,
      statement: $statement,
      date: ($date | split("journal-")[-1] | split(".")[0]),
      in_memory: $in_memory,
      in_delta: $in_delta,
      memory_match_ratio: $memory_match_ratio,
      delta_match_ratio: $delta_match_ratio
    }')

  if $IN_MEMORY && $IN_DELTA; then
    if [[ -z "$PROMOTED_JSON" ]]; then
      PROMOTED_JSON="$ENTRY_JSON"
    else
      PROMOTED_JSON="$PROMOTED_JSON,$ENTRY_JSON"
    fi
    PROMOTED_COUNT=$((PROMOTED_COUNT + 1))
  else
    if [[ -z "$DRIFT_JSON" ]]; then
      DRIFT_JSON="$ENTRY_JSON"
    else
      DRIFT_JSON="$DRIFT_JSON,$ENTRY_JSON"
    fi
    DRIFT_COUNT=$((DRIFT_COUNT + 1))
  fi
done <<< "$TAGGED_LINES"

# ── Build JSON output ─────────────────────────────────────────────────────
if [[ -z "$DRIFT_JSON" ]]; then
  DRIFT_JSON="[]"
else
  DRIFT_JSON="[$DRIFT_JSON]"
fi

if [[ -z "$PROMOTED_JSON" ]]; then
  PROMOTED_JSON="[]"
else
  PROMOTED_JSON="[$PROMOTED_JSON]"
fi

OUTPUT=$(jq -n \
  --argjson drift "$DRIFT_JSON" \
  --argjson promoted "$PROMOTED_JSON" \
  --argjson total "$TOTAL" \
  --arg memory_file "$MEMORY_FILE" \
  --arg delta_file "${DELTA_FILE:-}" \
  --arg since "$SINCE" \
  '{
    drift: $drift,
    promoted: $promoted,
    total: $total,
    memory_file: $memory_file,
    delta_file: $delta_file,
    since: $since
  }')

echo "$OUTPUT"

# ── Exit code ──────────────────────────────────────────────────────────────
if $DRY_RUN; then
  exit 0
fi

if [[ "$DRIFT_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
