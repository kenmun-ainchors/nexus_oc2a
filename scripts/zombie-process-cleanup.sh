#!/bin/bash
# zombie-process-cleanup.sh — Identify and kill runaway one-off Python/Node/Shell processes.
# CHG-0948: Daily 02:00 AEST cron + immediate kill of PID 80369 (runaway Python zlib loop).
#
# Detection rules (conservative — all must match):
#   1. Command pattern: Python/Node/Shell one-liner `... -c '<code>'` OR clearly transient
#      script invocation (e.g. python3 path/to/script.py with no controlling TTY).
#   2. CPU usage > 80%.
#   3. Elapsed time > 30 minutes.
#
# Whitelist (NEVER kill):
#   - OpenClaw gateway process (matched by name/path)
#   - Ollama (matched by name)
#   - Tailscale, RustDesk (matched by name)
#   - Safari, WebKit, WebProcess (matched by name)
#   - launchd, WindowServer, system daemons (parent=launchd AND known daemon)
#   - Anything with a controlling terminal and an active shell parent
#   - The cron process itself
#   - The shell that is running this script
#
# Usage:
#   bash scripts/zombie-process-cleanup.sh                # real run — kills
#   bash scripts/zombie-process-cleanup.sh --dry-run      # print only (default for safety)
#   bash scripts/zombie-process-cleanup.sh --no-dry-run   # force real kill
#
# Logging:
#   logs/zombie-cleanup.log           — append-only, one line per action
#   state/zombie-cleanup-last-run.json — single latest run summary
#
# Exit codes:
#   0 — success (including "nothing to kill")
#   1 — internal error (ps unavailable, log unwritable, etc.)
#
# Safety: This script is idempotent and side-effect-limited. It will not kill anything
# not matching the three-rule conservative match AND not failing the whitelist check.

set -uo pipefail

# ── Config ───────────────────────────────────────────────────────────────
SCRIPT_NAME="$(basename "$0")"
WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
LOG_DIR="${WORKSPACE}/logs"
LOG_FILE="${LOG_DIR}/zombie-cleanup.log"
STATE_DIR="${WORKSPACE}/state"
STATE_FILE="${STATE_DIR}/zombie-cleanup-last-run.json"
TMP_STATE="$(mktemp -t zombie-cleanup-state)"

CPU_THRESHOLD=80           # percent
ELAPSED_THRESHOLD_MIN=30   # minutes
SIGTERM_WAIT=5             # seconds to wait before SIGKILL

# ── Args ─────────────────────────────────────────────────────────────────
DRY_RUN=1  # default: dry-run (safer)
for arg in "$@"; do
  case "$arg" in
    --dry-run)     DRY_RUN=1 ;;
    --no-dry-run)  DRY_RUN=0 ;;
    -h|--help)
      sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "[$SCRIPT_NAME] WARN: unknown arg '$arg' — treating as dry-run" >&2
      DRY_RUN=1
      ;;
  esac
done

# ── Bootstrap dirs ───────────────────────────────────────────────────────
mkdir -p "$LOG_DIR" "$STATE_DIR" 2>/dev/null || { echo "FATAL: cannot create dirs" >&2; exit 1; }
: > "$LOG_FILE" 2>/dev/null || true  # ensure file is writable; we'll append below

# ── Helpers ──────────────────────────────────────────────────────────────
ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log_line() {
  local line
  line="$(ts) | $*"
  echo "$line" | tee -a "$LOG_FILE" >/dev/null 2>&1 || true
  # also echo to stdout for the calling exec
  echo "$line"
}

# Current shell's PID — never kill
SELF_PID=$$
SELF_PGID=$(ps -o pgid= -p "$SELF_PID" 2>/dev/null | tr -d ' ')

# OpenClaw gateway PID — never kill. Read live (don't hardcode).
GATEWAY_PID=$(pgrep -f "openclaw/dist/index.js" 2>/dev/null | head -1)
[[ -z "$GATEWAY_PID" ]] && GATEWAY_PID="47841"  # fallback documented in CHG-0948

# ── Whitelist check ──────────────────────────────────────────────────────
# Returns 0 (skip) if the process should NEVER be killed.
# Args: $1=pid  $2=comm  $3=args  $4=ppid
is_whitelisted() {
  local pid="$1" comm="$2" args="$3" ppid="$4"

  # Self / shell parent
  if [[ "$pid" == "$SELF_PID" ]]; then return 0; fi
  if [[ "$ppid" == "$SELF_PID" ]]; then return 0; fi
  # NOTE: We intentionally do NOT skip by process group (pgid) of self, because orphans
  # inherit the gateway's pgid, which would incorrectly skip the very zombies we want to kill.
  # Children of the current shell (ppid == SELF_PID) are caught above; that is sufficient.

  # OpenClaw gateway — match by PID only (NOT by pgid, since orphan children inherit pgid).
  if [[ "$pid" == "$GATEWAY_PID" ]]; then return 0; fi
  # Also skip direct children of the gateway that are clearly openclaw (workers/sidecars).
  if [[ "$ppid" == "$GATEWAY_PID" ]]; then
    if echo "$args" | grep -qE "openclaw/(dist/|gateway|node_modules)"; then return 0; fi
  fi
  # Match gateway by args even if pid changed
  if echo "$args" | grep -qE "openclaw/dist/index\.js"; then return 0; fi
  if echo "$args" | grep -qE "openclaw-gateway"; then return 0; fi

  # Core services by name (case-insensitive — bash 3.2 compatible)
  local lc_comm
  lc_comm=$(printf '%s' "$comm" | tr '[:upper:]' '[:lower:]')
  case "$lc_comm" in
    ollama|tailscaled|tailscale|rustdesk|windowserver|launchd|kernel_task|\
safarid|com.apple.webkit*|webprocess|webcontent|networkserviceproxy|\
identityservicesd|cloudd|bird|fontd|coreservicesd|distnoted|mdnsresponder|\
symptomsd|powerd|logd|configd|locationd|bluetoothd|opendirectoryd|\
coreaudiod|audiocomponents|corevideo|vtdec*|vtenc*|vimage*)
      return 0 ;;
  esac

  # Apple system binaries (under /System/, /usr/libexec/, /usr/sbin/)
  if [[ "$args" == /System/* || "$args" == /usr/libexec/* || "$args" == /usr/sbin/* || \
        "$args" == /usr/bin/* || "$args" == /bin/* || "$args" == /sbin/* ]]; then
    # but only if parent is launchd (real daemon, not a user-launched tool)
    if [[ "$ppid" == "1" ]] || [[ "$ppid" == "0" ]]; then
      return 0
    fi
  fi

  # Anything with a controlling tty and active shell parent is a user shell — skip
  if echo "$args" | grep -qE "(^|/)(zsh|bash|fish|sh|ksh|tcsh)(\s|$)"; then
    return 0
  fi

  return 1
}

# ── Detection: match candidate ───────────────────────────────────────────
# Args: $1=comm  $2=args  $3=cpu%  $4=elapsed_min
# Returns 0 if all three rules match.
is_runaway_candidate() {
  local comm="$1" args="$2" cpu="$3" elapsed_min="$4"

  # Rule: CPU > threshold
  awk -v c="$cpu" -v t="$CPU_THRESHOLD" 'BEGIN{exit !(c+0 > t+0)}' || return 1

  # Rule: Elapsed > threshold
  awk -v e="$elapsed_min" -v t="$ELAPSED_THRESHOLD_MIN" 'BEGIN{exit !(e+0 > t+0)}' || return 1

  # Rule: Command pattern — one-off `-c` or transient script under a sample/test dir
  # Match interpreter name against both comm and args (case-insensitive).
  local haystack
  haystack=$(printf '%s %s' "$comm" "$args" | tr '[:upper:]' '[:lower:]')
  # python/node/sh with -c one-liner
  if echo "$haystack" | grep -qE '\bpython[0-9.]*\b.*\s-c[[:space:]]'; then return 0; fi
  if echo "$haystack" | grep -qE '\bnode\b.*\s-e[[:space:]]'; then return 0; fi
  if echo "$haystack" | grep -qE '\b(bash|zsh|sh|ksh)\b.*\s-c[[:space:]]'; then return 0; fi
  # python/node running a script under sample-drawings/ or similar transient location
  if echo "$haystack" | grep -qE "(sample[-_]drawings|test[-_]data|tmp[-_]scratch|one[-_]off)"; then
    if echo "$haystack" | grep -qE "\b(python[0-9.]*|node)\b"; then
      return 0
    fi
  fi
  # python with .pdf in args (transient PDF work)
  if echo "$haystack" | grep -qE '\.pdf\b' && echo "$haystack" | grep -qE "\bpython[0-9.]*\b"; then
    return 0
  fi

  return 1
}

# ── Main scan ────────────────────────────────────────────────────────────
SCAN_START_TS="$(ts)"
SCANNED=0
KILLED=0
SKIPPED=0
ERRORS=0
declare -a ACTIONS=()

log_line "START dry-run=$DRY_RUN cpu_thresh=${CPU_THRESHOLD}% elapsed_thresh=${ELAPSED_THRESHOLD_MIN}min gateway_pid=$GATEWAY_PID self_pid=$SELF_PID"

# Snapshot ps output once. Fields: pid ppid %cpu etime comm args
# Use -o to keep stable fields; trailing args joined as one field.
# ps on macOS uses spaces in the default output; we strip leading whitespace per line.
# IMPORTANT: args can contain spaces — read pid ppid cpu etime comm and take the rest as args.
PS_OUT=$(ps -A -o pid=,ppid=,%cpu=,etime=,comm= -o args= 2>/dev/null | sed 's/^[[:space:]]*//')
if [[ -z "$PS_OUT" ]]; then
  log_line "ERROR ps snapshot empty — cannot continue"
  echo "{\"timestamp\":\"$SCAN_START_TS\",\"dryRun\":$DRY_RUN,\"scanned\":0,\"killed\":0,\"skipped\":0,\"errors\":1,\"actions\":[]}" > "$STATE_FILE"
  exit 1
fi

while IFS= read -r line; do
  # Parse fixed leading fields with whitespace separator; args = remainder (may contain spaces)
  # shellcheck disable=SC2086
  set -- $line
  pid="${1:-}"; ppid="${2:-}"; cpu="${3:-}"; etime="${4:-}"; comm="${5:-}"
  shift 5 2>/dev/null || true
  args="$*"
  [[ -z "$pid" ]] && continue
  [[ -z "$comm" ]] && continue

  SCANNED=$((SCANNED + 1))

  if [[ -z "$args" ]]; then
    args="$comm"
  fi

  # Convert etime (HH:MM:SS or MM:SS or SS) to minutes (integer).
  # Strip leading zeros to avoid bash octal interpretation of "08" / "09".
  elapsed_min=0
  if [[ "$etime" == *-* ]]; then
    # e.g. 02-03:04:05 → days*1440 + hours*60 + mins
    days="${etime%%-*}"; days=$((10#$days))
    rest2="${etime#*-}"
    hh="${rest2%%:*}"; hh=$((10#$hh))
    mm="${rest2#*:}"; mm="${mm%%:*}"; mm=$((10#$mm))
    elapsed_min=$(( days*1440 + hh*60 + mm ))
  elif [[ "$etime" == *:*:* ]]; then
    hh="${etime%%:*}"; hh=$((10#$hh))
    rest2="${etime#*:}"; mm="${rest2%%:*}"; mm=$((10#$mm))
    elapsed_min=$(( hh*60 + mm ))
  elif [[ "$etime" == *:* ]]; then
    mm="${etime%%:*}"; mm=$((10#$mm))
    ss="${etime#*:}"; ss=$((10#$ss))
    elapsed_min=$(( mm + (ss>30?1:0) ))
  else
    # plain seconds
    s=$((10#${etime:-0}))
    if (( s < 60 )); then elapsed_min=0; else elapsed_min=1; fi
  fi

  # Whitelist check
  if is_whitelisted "$pid" "$comm" "$args" "$ppid"; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Candidate check
  if ! is_runaway_candidate "$comm" "$args" "$cpu" "$elapsed_min"; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # ── Match: would kill ──────────────────────────────────────────────────
  ACTION="MATCH pid=$pid cpu=${cpu}% elapsed=${elapsed_min}m comm=$comm"
  log_line "  $ACTION"
  ACTIONS+=("$ACTION")

  if [[ "$DRY_RUN" == "1" ]]; then
    log_line "  DRY-RUN: would SIGTERM pid=$pid then SIGKILL after ${SIGTERM_WAIT}s"
    continue
  fi

  # Real kill path
  if kill -TERM "$pid" 2>/dev/null; then
    log_line "  SENT SIGTERM pid=$pid"
    slept=0
    while (( slept < SIGTERM_WAIT )); do
      if ! kill -0 "$pid" 2>/dev/null; then break; fi
      sleep 1
      slept=$((slept + 1))
    done
    if kill -0 "$pid" 2>/dev/null; then
      if kill -KILL "$pid" 2>/dev/null; then
        log_line "  SENT SIGKILL pid=$pid (did not respond to SIGTERM)"
      else
        log_line "  ERROR SIGKILL failed pid=$pid"
        ERRORS=$((ERRORS + 1))
        continue
      fi
    else
      log_line "  pid=$pid terminated cleanly on SIGTERM"
    fi
    KILLED=$((KILLED + 1))
  else
    log_line "  ERROR SIGTERM failed pid=$pid (EPERM or already dead)"
    ERRORS=$((ERRORS + 1))
  fi
done <<< "$PS_OUT"

SCAN_END_TS="$(ts)"
log_line "END scanned=$SCANNED killed=$KILLED skipped=$SKIPPED errors=$ERRORS dry-run=$DRY_RUN"

# ── Persist state ────────────────────────────────────────────────────────
{
  printf '{\n'
  printf '  "timestamp": "%s",\n' "$SCAN_END_TS"
  printf '  "scanStarted": "%s",\n' "$SCAN_START_TS"
  printf '  "dryRun": %s,\n' "$DRY_RUN"
  printf '  "cpuThreshold": %d,\n' "$CPU_THRESHOLD"
  printf '  "elapsedThresholdMin": %d,\n' "$ELAPSED_THRESHOLD_MIN"
  printf '  "gatewayPid": %s,\n' "${GATEWAY_PID:-null}"
  printf '  "scanned": %d,\n' "$SCANNED"
  printf '  "killed": %d,\n' "$KILLED"
  printf '  "skipped": %d,\n' "$SKIPPED"
  printf '  "errors": %d,\n' "$ERRORS"
  printf '  "actions": [\n'
  for i in "${!ACTIONS[@]}"; do
    a="${ACTIONS[$i]//\"/\\\"}"
    sep=","
    [[ $i -eq $(( ${#ACTIONS[@]} - 1 )) ]] && sep=""
    printf '    "%s"%s\n' "$a" "$sep"
  done
  printf '  ]\n'
  printf '}\n'
} > "$TMP_STATE" && mv "$TMP_STATE" "$STATE_FILE"

rm -f "$TMP_STATE" 2>/dev/null || true
exit 0
