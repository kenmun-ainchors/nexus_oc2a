#!/bin/zsh
# file-size-guard.sh: Pre-write file size validation with remediation guidance
# TKT-0338 / TKT-0310 — Platform Constraint Enforcement P1-B

export PATH="/usr/bin:/bin:/opt/homebrew/bin:$PATH"
set -euo pipefail

WORKSPACE="${WORKSPACE:-/Users/ainchorsangiefpl/.openclaw/workspace}"

LIMITS_DATA=(
  "SOUL.md|10000|6000|Trim non-essential sections. Target: identity + traits + rules + cadences only."
  "AGENTS.md|12000|8000|Archive old procedural sections. Details belong in RULES.md (not injected)."
  "MEMORY.md|15000|10000|Archive EOD sections to memory/MEMORY-archive-YYYY-MM-DD.md. Trim to ~10K."
  "HEARTBEAT.md|15000|10000|Consolidate duplicate check descriptions. Keep names + state keys + thresholds only."
  "USER.md|2000|1000|Keep minimal — name, email, timezone, primary channel only."
  "IDENTITY.md|2000|1000|Keep to ~5 lines — name, role, vibe, emoji."
  "TOOLS.md|5000|3000|Device-specific config only. General usage in SKILL.md files."
)

get_limits() {
  local bname="$1"
  for entry in "${LIMITS_DATA[@]}"; do
    local ename="${entry%%|*}"
    if [[ "$bname" == "$ename" ]]; then
      echo "$entry"
      return
    fi
  done
  echo ""
}

check_one() {
  local path="$1" bname hard soft remedy size hard_pct soft_pct
  bname="${path##*/}"
  
  local limits
  limits=$(get_limits "$bname")
  
  if [[ -z "$limits" ]]; then
    if [[ -f "$path" ]]; then
      size=$(/usr/bin/wc -c < "$path" 2>/dev/null)
      size=${size// /}
      echo "INFO:  $bname = ${size} chars (no platform limit)"
    else
      echo "SKIP: $bname (not found)"
    fi
    return 0
  fi
  
  IFS='|' read -r _ hard soft remedy <<< "$limits"
  
  if [[ ! -f "$path" ]]; then
    echo "SKIP: $bname (not found)"
    return 0
  fi
  
  size=$(/usr/bin/wc -c < "$path" 2>/dev/null)
  size=${size// /}
  
  if [[ -z "$size" || "$size" -eq 0 ]]; then
    echo "SKIP: $bname (empty)"
    return 0
  fi
  
  hard_pct=$(( size * 100 / hard ))
  
  if (( size > hard )); then
    echo "BLOCK: $bname = ${size} chars (${hard_pct}% of HARD LIMIT ${hard})"
    echo "       ${remedy}"
    return 2
  elif (( size > soft )); then
    soft_pct=$(( size * 100 / soft ))
    echo "WARN:  $bname = ${size} chars (${soft_pct}% of soft limit ${soft}, ${hard_pct}% of hard limit ${hard})"
    echo "       ${remedy}"
    return 1
  else
    echo "OK:    $bname = ${size} chars (${hard_pct}% of hard limit ${hard})"
    return 0
  fi
}

# --- Main ---
MODE="check"
TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) MODE="check"; TARGET="$2"; shift 2 ;;
    --all)   MODE="all"; shift ;;
    --json)  MODE="json"; shift ;;
    -*) echo "Unknown: $1"; exit 1 ;;
    *) TARGET="$1"; shift ;;
  esac
done

CRITICAL_FILES=(
  "$WORKSPACE/SOUL.md"
  "$WORKSPACE/AGENTS.md"
  "$WORKSPACE/MEMORY.md"
  "$WORKSPACE/HEARTBEAT.md"
  "$WORKSPACE/USER.md"
  "$WORKSPACE/IDENTITY.md"
  "$WORKSPACE/TOOLS.md"
)

if [[ "$MODE" == "check" ]]; then
  if [[ -z "$TARGET" ]]; then
    echo "Usage: file-size-guard.sh <target> | --check <path> | --all | --json" >&2
    exit 1
  fi
  check_one "$TARGET"
elif [[ "$MODE" == "all" ]]; then
  echo "=== File Size Enforcement Report ==="
  echo ""
  worst=0
  for f in "${CRITICAL_FILES[@]}"; do
    set +e
    check_one "$f"
    rc=$?
    set -e
    [[ $rc -gt $worst ]] && worst=$rc
  done
  echo ""
  case $worst in
    0) echo "VERDICT: All files within limits ✅";;
    1) echo "VERDICT: Warnings — files approaching limits ⚠️";;
    2) echo "VERDICT: BLOCKED — file(s) exceed hard limits ❌";;
  esac
  exit $worst
elif [[ "$MODE" == "json" ]]; then
  # Build JSON silently — no check_one stdout
  worst=0
  json_files=""
  first=true
  for f in "${CRITICAL_FILES[@]}"; do
    bname="${f##*/}"
    limits=$(get_limits "$bname")
    hard=0; soft=0
    if [[ -n "$limits" ]]; then
      IFS='|' read -r _ hard soft _ <<< "$limits"
    fi
    
    if [[ -f "$f" ]]; then
      size=$(/usr/bin/wc -c < "$f" 2>/dev/null)
      size=${size// /}
    else
      size=0
    fi
    
    fstatus="OK"
    if (( hard > 0 && size > hard )); then
      fstatus="BLOCKED"
      worst=2
    elif (( soft > 0 && size > soft )); then
      fstatus="WARN"
      [[ $worst -lt 1 ]] && worst=1
    fi
    
    hard_pct=$(( hard > 0 ? size * 100 / hard : 0 ))
    
    if $first; then first=false; else json_files+=","; fi
    json_files+=$'\n'"    \"$bname\": {\"size\": $size, \"hardLimit\": $hard, \"softLimit\": $soft, \"status\": \"$fstatus\", \"hardPct\": $hard_pct}"
  done
  
  sev="OK"
  [[ $worst -eq 1 ]] && sev="WARN"
  [[ $worst -eq 2 ]] && sev="BLOCKED"
  
  echo "{"
  echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"severity\": \"$sev\","
  echo "  \"files\": {${json_files}"
  echo ""
  echo "  }"
  echo "}"
fi
