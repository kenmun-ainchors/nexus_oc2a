#!/bin/zsh
# context-budget.sh: Pre-flight context budget estimation
# TKT-0337 / TKT-0310 — Platform Constraint Enforcement P1-A
# 
# Estimates token usage for injected context files and warns if approaching
# model context window limits. Uses char/4 heuristic (conservative for English).
#
# Usage:
#   context-budget.sh                          # Full report
#   context-budget.sh --check                  # Exit 0 if OK, 1 if warn, 2 if critical
#   context-budget.sh --model <alias>          # Model-specific check (deepseek, kimi, gemma4)
#   context-budget.sh --json                   # JSON output for auto-heal

set -euo pipefail

WORKSPACE="${WORKSPACE:-/Users/ainchorsangiefpl/.openclaw/workspace}"
PROFILE="$HOME/.openclaw"

# Model context windows (tokens)
declare -A MODEL_WINDOWS
MODEL_WINDOWS[deepseek]=524288
MODEL_WINDOWS[deepseek-pro]=524288
MODEL_WINDOWS[kimi]=262144
MODEL_WINDOWS[gemma4]=262144
MODEL_WINDOWS[gemma4cloud]=262144
MODEL_WINDOWS[haiku]=200000
MODEL_WINDOWS[sonnet]=200000
DEFAULT_MODEL="deepseek-pro"

# Thresholds
WARN_PCT=80
BLOCK_PCT=95

# Files injected at bootstrap (matches gateway config)
FILES=(
  "$WORKSPACE/SOUL.md"
  "$WORKSPACE/AGENTS.md"
  "$WORKSPACE/MEMORY.md"
  "$WORKSPACE/HEARTBEAT.md"
  "$WORKSPACE/USER.md"
  "$WORKSPACE/IDENTITY.md"
  "$WORKSPACE/TOOLS.md"
)

# Simple token estimator: chars/4 for English text (conservative, overestimates by ~10-15%)
estimate_tokens() {
  local chars=$1
  echo $(( chars / 4 ))
}

# Main
MODE="report"
MODEL="$DEFAULT_MODEL"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) MODE="check"; shift ;;
    --json)  MODE="json"; shift ;;
    --model) MODEL="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

WINDOW=${MODEL_WINDOWS[$MODEL]:-$MODEL_WINDOWS[$DEFAULT_MODEL]}
TOTAL_CHARS=0
FILE_COUNT=0

# Use temp file for file data (newline-separated, avoids space parsing issues)
TMPDATA=$(mktemp)
trap "rm -f $TMPDATA" EXIT

for f in "${FILES[@]}"; do
  if [[ -f "$f" ]]; then
    chars=$(wc -c < "$f" 2>/dev/null || echo 0)
    tokens=$(estimate_tokens "$chars")
    TOTAL_CHARS=$((TOTAL_CHARS + chars))
    FILE_COUNT=$((FILE_COUNT + 1))
    echo "$(basename "$f")|$chars|$tokens" >> "$TMPDATA"
  fi
done

TOTAL_TOKENS=$(estimate_tokens "$TOTAL_CHARS")
USAGE_PCT=$(( TOTAL_TOKENS * 100 / WINDOW ))
WARN_THRESHOLD=$(( WINDOW * WARN_PCT / 100 ))
BLOCK_THRESHOLD=$(( WINDOW * BLOCK_PCT / 100 ))

# Determine status
STATUS="OK"
EXIT_CODE=0
if (( TOTAL_TOKENS > BLOCK_THRESHOLD )); then
  STATUS="CRITICAL"
  EXIT_CODE=2
elif (( TOTAL_TOKENS > WARN_THRESHOLD )); then
  STATUS="WARN"
  EXIT_CODE=1
fi

case "$MODE" in
  check)
    echo "$STATUS: $TOTAL_TOKENS tokens ($USAGE_PCT%) of $WINDOW window"
    exit $EXIT_CODE
    ;;
  json)
    echo "{"
    echo "  \"model\": \"$MODEL\","
    echo "  \"window\": $WINDOW,"
    echo "  \"totalChars\": $TOTAL_CHARS,"
    echo "  \"totalTokens\": $TOTAL_TOKENS,"
    echo "  \"usagePercent\": $USAGE_PCT,"
    echo "  \"warnThreshold\": $WARN_THRESHOLD,"
    echo "  \"blockThreshold\": $BLOCK_THRESHOLD,"
    echo "  \"status\": \"$STATUS\","
    echo "  \"files\": {"
    first=true
    while IFS='|' read -r name chars tokens; do
      [[ -z "$name" ]] && continue
      if $first; then first=false; else echo ","; fi
      echo -n "    \"$name\": {\"chars\": $chars, \"tokens\": $tokens}"
    done < "$TMPDATA"
    echo ""
    echo "  }"
    echo "}"
    ;;
  report)
    echo "=== Context Budget Report — $MODEL (${WINDOW} token window) ==="
    echo ""
    printf "%-25s %8s %8s %7s\n" "FILE" "CHARS" "TOKENS" "%OFWIN"
    printf "%-25s %8s %8s %7s\n" "----" "-----" "------" "------"
    while IFS='|' read -r name chars tokens; do
      [[ -z "$name" ]] && continue
      pct=$(( tokens * 100 / WINDOW ))
      printf "%-25s %8d %8d %6d%%\n" "$name" "$chars" "$tokens" "$pct"
    done < "$TMPDATA"
    echo ""
    printf "%-25s %8d %8d %6d%%\n" "TOTAL ($FILE_COUNT files)" "$TOTAL_CHARS" "$TOTAL_TOKENS" "$USAGE_PCT"
    echo ""
    echo "Window:       $WINDOW tokens"
    echo "Warn at:      $WARN_THRESHOLD tokens (${WARN_PCT}%)"
    echo "Block at:     $BLOCK_THRESHOLD tokens (${BLOCK_PCT}%)"
    echo "Status:       $STATUS"
    echo ""
    echo "Remaining for conversation: ~$((WINDOW - TOTAL_TOKENS)) tokens"
    ;;
esac
