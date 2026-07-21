#!/bin/zsh
# file-size-guard.sh: Pre-write file size validation with remediation guidance
# TKT-0338 / TKT-0310 — Platform Constraint Enforcement P1-B

export PATH="/usr/bin:/bin:/opt/homebrew/bin:$PATH"
set -euo pipefail

WORKSPACE="${WORKSPACE:-/Users/ainchorsoc2a/.openclaw/workspace}"
ROOT_MD_CAP=60000  # TKT-0341: total chars across all root .md files
CONTRACT_REGISTRY="$WORKSPACE/state/file-contracts.json"

# File size limits: hard|soft|bname|remedy
# Policy: hard limits per TKT-0310 (uninjected-context threshold). Soft limits
# match the documented policies in AGENTS.md and MEMORY.md:
#   - MEMORY.md: hard 15000, soft 12000 ("warn 12,000" — AGENTS.md line 54 + MEMORY.md line 30)
#   - AGENTS.md: hard 12000, soft 11000 (1K buffer, "catch at 11K" per P2 #5)
#   - HEARTBEAT.md: hard 15000, soft 12000 (matches MEMORY.md)
#   - SOUL.md: hard 10000, soft 6000 (no change — matches MEMORY.md line 29)
#   - TOOLS.md: hard 5000, soft 4000 (1K buffer, matches proportional pattern)
#   - USER.md / IDENTITY.md: no change
# Why: the previous MEMORY.md soft=10000 was 2K too early per documented policy,
# causing false-positive warnings that devalued the warning system. This aligns
# the script to the policy actually written down. L-133.
LIMITS_DATA=(
  "SOUL.md|10000|6000|Trim non-essential sections. Target: identity + traits + rules + cadences only."
  "AGENTS.md|12000|11000|Archive old procedural sections. Details belong in RULES.md (not injected). Soft at 11K = 1K buffer before hard 12K (P2 #5, L-133)."
  "MEMORY.md|15000|12000|Archive EOD sections to memory/MEMORY-archive-YYYY-MM-DD.md. Trim to ~10K. Soft 12K matches AGENTS.md line 54 + MEMORY.md line 30 (P2 #5, L-133)."
  "HEARTBEAT.md|15000|12000|Consolidate duplicate check descriptions. Keep names + state keys + thresholds only. Soft 12K matches MEMORY.md pattern (P2 #5, L-133)."
  "USER.md|2000|1000|Keep minimal — name, email, timezone, primary channel only."
  "IDENTITY.md|2000|1000|Keep to ~5 lines — name, role, vibe, emoji."
  "TOOLS.md|5000|4000|Device-specific config only. General usage in SKILL.md files. Soft 4K = 1K buffer before hard 5K (P2 #5, L-133)."
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
ENFORCE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) MODE="check"; TARGET="$2"; shift 2 ;;
    --all)   MODE="all"; shift ;;
    --root)  MODE="root"; shift ;;
    --json)  MODE="json"; shift ;;
    --enforce) ENFORCE=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
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
  "$WORKSPACE/DREAMS.md"
  "$WORKSPACE/yoda-daily-brief.md"
)

# TKT-1013-NEEDS-1: Load file-contracts.json so registered contracts are
# not flagged as untracked, and non-injected contracts (e.g. CHG live
# contracts) are exempt from the 60K injectable cap.
# CONTRACT_REGISTRY is set near the top of the script. Files listed under
# `files.<basename>` are considered registered. Audience field decides
# whether the file counts toward the 60K injectable cap.
REGISTERED_FILES=()      # basenames of files in file-contracts.json
REGISTERED_AUDIENCES=()  # parallel array: audience string for each file
if [[ -f "$CONTRACT_REGISTRY" ]] && command -v jq >/dev/null 2>&1; then
  while IFS=$'\t' read -r fcbname fcaudience; do
    [[ -n "$fcbname" ]] || continue
    REGISTERED_FILES+=("$fcbname")
    REGISTERED_AUDIENCES+=("${fcaudience:-}")
  done < <(jq -r '.files | to_entries[] | [.key, (.value.audience // "")] | @tsv' "$CONTRACT_REGISTRY" 2>/dev/null)
fi

# Return 0 (true) if the audience string indicates the file is injected
# into agent session context (and therefore counts toward the 60K cap).
# Any other audience (on-demand read, Forge/Code-review reference, scratch
# file, dreaming output, etc.) is treated as non-injected and exempt.
is_injected_audience() {
  local aud="${1:-}"
  case "$aud" in
    "Agent session context (injected)"|"Yoda main session only (injected)"|"Heartbeat runs only (lightContext=true)")
      return 0 ;;
  esac
  return 1
}

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
  # ENFORCE/DRY-RUN logic
  if [[ "$ENFORCE" == "true" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo ""
      echo "ENFORCE: Dry-run mode — violations LOGGED but NOT blocked."
      if [[ $worst -eq 2 ]]; then
        echo "DRY-RUN: Would BLOCK oversized file(s) if enforcement was live."
      elif [[ $worst -eq 1 ]]; then
        echo "DRY-RUN: Would WARN on files approaching limits if enforcement was live."
      fi
      exit 0
    else
      # Real enforce mode: exit non-zero to block
      echo ""
      echo "ENFORCE: Active enforcement — oversized files BLOCKED."
      exit $worst
    fi
  fi
  case $worst in
    0) echo "VERDICT: All files within limits ✅";;
    1) echo "VERDICT: Warnings — files approaching limits ⚠️";;
    2) echo "VERDICT: BLOCKED — file(s) exceed hard limits ❌";;
  esac
  exit $worst
elif [[ "$MODE" == "root" ]]; then
  # TKT-0341: workspace-root total cap check
  # TKT-1013-NEEDS-1: also consult state/file-contracts.json so registered
  # files are not flagged as untracked. Non-injected contracts (Forge
  # execution references, code-review references, on-demand reads,
  # scratchpads) are exempt from the 60K cap.
  echo "=== Workspace Root .md Total Cap Check ==="
  echo ""
  total=0
  total_root_md=0
  untracked=""
  for f in "$WORKSPACE"/*.md; do
    [[ -f "$f" ]] || continue
    bname="${f##*/}"
    size=$(/usr/bin/wc -c < "$f" 2>/dev/null)
    size=${size// /}
    total=$((total + size))
    # tracked codes:
    #   0 = untracked (reported in UNTRACKED FILES, counts toward cap)
    #   1 = tracked, counts toward injectable cap
    #   2 = tracked, exempt from cap (non-injected)
    tracked=0
    # 1. Hardcoded critical files (legacy path — still authoritative for
    #    per-file size limit enforcement in --all/--json modes).
    for t in "${CRITICAL_FILES[@]}"; do
      [[ "$f" == "$t" ]] && tracked=1 && break
    done
    # 2. Explicit non-injected exemptions (also in registry, but kept here
    #    so the script still behaves correctly if file-contracts.json is
    #    missing or malformed).
    [[ "$bname" == "RULES.md" ]] && tracked=2  # explicitly exempted — not injected, doesn't count toward cap
    [[ "$bname" == "DREAMS.md" ]] && tracked=2  # exempt — non-injected dreaming scratchpad
    [[ "$bname" == "yoda-daily-brief.md" ]] && tracked=2  # exempt — non-injected daily brief
    # 3. Contract registry lookup. If a file is registered in
    #    state/file-contracts.json it is considered tracked; its audience
    #    decides whether it counts toward the cap.
    if [[ $tracked -eq 0 ]]; then
      for i in $(seq 1 ${#REGISTERED_FILES[@]}); do
        if [[ "${REGISTERED_FILES[$i]}" == "$bname" ]]; then
          if is_injected_audience "${REGISTERED_AUDIENCES[$i]}"; then
            tracked=1
          else
            tracked=2
          fi
          break
        fi
      done
    fi
    if [[ $tracked -eq 0 ]]; then
      [[ -n "$untracked" ]] && untracked+=", "
      untracked+="$bname"
    fi
    # RULES.md is exempt from cap (not injected, on-demand reference)
    if [[ $tracked -ne 2 ]]; then
      total_root_md=$((total_root_md + size))
    fi
    echo "  $( [[ $tracked -ne 0 ]] && echo '✅' || echo '⚠️' ) $bname: $size chars$( [[ $tracked -eq 2 ]] && echo ' [exempt — not injected]' || echo '')"
  done
  echo ""
  total_pct=$(( total_root_md * 100 / ROOT_MD_CAP ))
  echo "Injectable total: $total_root_md chars / $ROOT_MD_CAP cap (${total_pct}%)"
  echo "With RULES.md (reference only): $total chars"
  if [[ -n "$untracked" ]]; then
    echo ""
    echo "⚠️ UNTRACKED FILES: $untracked"
    echo "   These files have no contract in state/file-contracts.json."
    echo "   Add contract or move to appropriate subdirectory (docs/, archive/, agents/<id>/)."
    rc=1
  else
    echo "All files tracked ✅"
    rc=0
  fi
  if (( total_root_md > ROOT_MD_CAP )); then
    echo "BLOCKED: Injectable root .md total exceeds ${ROOT_MD_CAP} cap ❌"
    rc=2
  fi
  # ENFORCE/DRY-RUN logic for root mode
  if [[ "$ENFORCE" == "true" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo ""
      echo "ENFORCE: Dry-run mode — violations LOGGED but NOT blocked."
      if [[ $rc -eq 2 ]]; then
        echo "DRY-RUN: Would BLOCK oversize root .md cap if enforcement was live."
      elif [[ $rc -eq 1 ]]; then
        echo "DRY-RUN: Would WARN on untracked files if enforcement was live."
      fi
      exit 0
    else
      echo ""
      echo "ENFORCE: Active enforcement — root .md cap enforced."
      exit $rc
    fi
  fi
  exit $rc
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
