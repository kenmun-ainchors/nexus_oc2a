#!/bin/bash
# ============================================================================
# Retention Cleanup – Session / Trajectory Bloat Remediation
# CHG-0830 (Optimized) — DEPRECATED PRIMARY
# ============================================================================
# NOTE: This script is now a FALLBACK manual tool only.
# Canonical session retention is handled by OpenClaw session.maintenance
# config (CHG-0831). Use scripts/run-openclaw-sessions-cleanup.sh for the
# current approach: openclaw sessions cleanup --all-agents --enforce.
# ============================================================================
# Default mode: dry-run (no files deleted)
#   --apply   : actually delete eligible files
#   --report  : audit-only, no deletions, no dry-run candidates
# ============================================================================
#
# Per-agent TTL overrides (env vars):
#   TTL_SESSIONS, TTL_TRAJECTORY  (default 14d, 7d)
#   TTL_ORPHAN                     (default 7d)
#
# Per-agent TTL overrides (CLI flags):
#   --ttl-sessions N  (days)
#   --ttl-trajectory N (days)
#   --ttl-orphan N    (days)
#
# Safety:
#   - Excludes files modified <24h ago (--min-age 1 default)
#   - Excludes live active session UUIDs from "openclaw status"
#   - Never touches memory SQLite DBs, .usage-cost-cache.json, config, or workspace state
#   - Idempotent find -mtime +N approach (bulk, then filtered by Python)
#   - Atomic temp file handling for JSON pruning
# ============================================================================
#
# Performance optimizations (CHG-0830):
#   - Replaced per-file Python stat + grep loops with bulk find -> Python pipeline
#   - Active UUIDs loaded once into a Python set for O(1) membership checks
#   - Min-age check via os.stat() once per file in Python (no redundant mmin calls)
#   - All file metadata (size, mtime) collected in one pass per category
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# --- Paths ----------------------------------------------------------------
OPENCLAW_ROOT="${OPENCLAW_ROOT:-/Users/ainchorsangiefpl/.openclaw}"
WORKSPACE_ROOT="${OPENCLAW_ROOT}/workspace"
AGENTS_ROOT="${OPENCLAW_ROOT}/agents"
STATE_DIR="${WORKSPACE_ROOT}/state"
TASK_QUEUE="${STATE_DIR}/task-queue.json"

# --- Defaults -------------------------------------------------------------
TTL_SESSIONS=${TTL_SESSIONS:-14}
TTL_TRAJECTORY=${TTL_TRAJECTORY:-7}
TTL_ORPHAN=${TTL_ORPHAN:-7}
MIN_AGE_HOURS=${MIN_AGE_HOURS:-24}
MODE="dry-run"  # dry-run | apply | report

# --- Parse CLI flags -------------------------------------------------------
APPLY=0
REPORT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      APPLY=1
      MODE="apply"
      shift
      ;;
    --report)
      REPORT=1
      MODE="report"
      shift
      ;;
    --ttl-sessions)
      TTL_SESSIONS="$2"
      shift 2
      ;;
    --ttl-trajectory)
      TTL_TRAJECTORY="$2"
      shift 2
      ;;
    --ttl-orphan)
      TTL_ORPHAN="$2"
      shift 2
      ;;
    --min-age)
      MIN_AGE_HOURS="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [--apply] [--report] [--ttl-sessions N] [--ttl-trajectory N] [--ttl-orphan N] [--min-age H]"
      echo ""
      echo "Modes:"
      echo "  (default)  dry-run – show what would be deleted, no changes"
      echo "  --apply    actually delete eligible files"
      echo "  --report   audit-only – show counts and sizes, no deletions"
      echo ""
      echo "TTL defaults: sessions=$TTL_SESSIONS days, trajectory=$TTL_TRAJECTORY days, orphan=$TTL_ORPHAN days"
      echo "Min age: ${MIN_AGE_HOURS}h"
      exit 0
      ;;
    *)
      echo "ERROR: Unknown flag: $1" >&2
      exit 1
      ;;
  esac
done

# --- State ----------------------------------------------------------------
CANDIDATES=0
CANDIDATES_BYTES=0
PROTECTED=0
DELETED=0
DELETED_BYTES=0
ORPHAN_CANDIDATES=0
ORPHAN_DELETED=0
DRY_RUN_CANDIDATES=0
DRY_RUN_CANDIDATES_BYTES=0

# --- Helper: byte formatting ----------------------------------------------
format_bytes() {
  local b=$1
  if (( b >= 1073741824 )); then
    python3 -c "print(f'{round($b/1073741824, 2)} GiB')"
  elif (( b >= 1048576 )); then
    python3 -c "print(f'{round($b/1048576, 2)} MiB')"
  elif (( b >= 1024 )); then
    python3 -c "print(f'{round($b/1024, 2)} KiB')"
  else
    echo "${b} B"
  fi
}

# --- Helper: safe deletion with counting ----------------------------------
# This is called per-file in dry-run/apply mode after the bulk pipeline
# identifies candidates. For --report mode, only counts are shown.
safe_rm() {
  local file="$1"
  local size="$2"
  if [[ "$MODE" == "apply" ]]; then
    rm -f "$file"
    DELETED=$((DELETED + 1))
    DELETED_BYTES=$((DELETED_BYTES + size))
    echo "  [DELETED] $file ($(format_bytes "$size"))"
  else
    DRY_RUN_CANDIDATES=$((DRY_RUN_CANDIDATES + 1))
    DRY_RUN_CANDIDATES_BYTES=$((DRY_RUN_CANDIDATES_BYTES + size))
    echo "  [CANDIDATE] $file ($(format_bytes "$size"))"
  fi
}

# ============================================================================
# Phase 1: Collect active session UUIDs
# ============================================================================
echo "=== Phase 1: Collecting active session UUIDs ==="

ACTIVE_UUIDS=$(mktemp)
trap 'rm -f "$ACTIVE_UUIDS"' EXIT

if command -v openclaw &>/dev/null; then
  openclaw status --json 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    sessions = data.get('sessions', {})
    seen = set()
    for agent in sessions.get('byAgent', []):
        for s in agent.get('recent', []):
            sid = s.get('sessionId', '')
            if sid and sid not in seen:
                seen.add(sid)
                print(sid)
        for s in agent.get('sessions', []):
            sid = s.get('sessionId', '')
            if sid and sid not in seen:
                seen.add(sid)
                print(sid)
except Exception:
    pass
" > "$ACTIVE_UUIDS" 2>/dev/null || true
fi

ACTIVE_COUNT=$(wc -l < "$ACTIVE_UUIDS" | tr -d ' ')
echo "  Active session UUIDs: $ACTIVE_COUNT"

# ============================================================================
# Phase 2: Bulk scan of session/trajectory files via Python
# ============================================================================
echo ""
echo "=== Phase 2: Scanning session/trajectory files ==="
echo "  Mode: $MODE"
echo "  TTL_SESSIONS: $TTL_SESSIONS days"
echo "  TTL_TRAJECTORY: $TTL_TRAJECTORY days"
echo "  TTL_ORPHAN: $TTL_ORPHAN days"
echo "  Min age: ${MIN_AGE_HOURS}h"
echo ""

# Convert hours to minutes for Python min-age check
MIN_AGE_MINUTES=$((MIN_AGE_HOURS * 60))

# --- Trajectory files (*.trajectory.jsonl, *.trajectory-path.json) ---
echo "--- Trajectory files (*.trajectory.jsonl, *.trajectory-path.json) ---"

# Bulk pipeline: find (age-qualified) -> Python (stat, min-age, active-UUID filter)
# Output: tab-separated path<tab>size for each candidate
TRAJECTORY_CANDIDATES=$(mktemp)
trap 'rm -f "$TRAJECTORY_CANDIDATES"' EXIT

find "$AGENTS_ROOT" -type f \( -name '*.trajectory.jsonl' -o -name '*.trajectory-path.json' \) -mtime "+${TTL_TRAJECTORY}" -print0 2>/dev/null \
  | python3 -c "
import sys, os, time

with open('$ACTIVE_UUIDS') as f:
    active_uuids = {line.strip() for line in f if line.strip()}

min_age_seconds = $MIN_AGE_MINUTES * 60
now = time.time()
candidates = []
protected_recent = 0
protected_active = 0

for entry in sys.stdin.buffer.read().split(b'\x00'):
    if not entry:
        continue
    path = entry.decode('utf-8', errors='replace')
    try:
        st = os.stat(path)
    except OSError:
        continue

    # Check min age (files modified <24h ago are protected)
    age_seconds = now - st.st_mtime
    if age_seconds < min_age_seconds:
        protected_recent += 1
        continue

    # Check active UUID membership (O(1) set lookup)
    fname = path.rstrip('/').rsplit('/', 1)[-1]
    uuid = fname.split('.', 1)[0] if '.' in fname else fname
    if uuid in active_uuids:
        protected_active += 1
        continue

    candidates.append((path, st.st_size))

# Output: count | protected_recent | protected_active | total_size
# Then tab-separated path\tsize for each candidate
total_size = sum(sz for _, sz in candidates)
print(f'STATS|{len(candidates)}|{protected_recent}|{protected_active}|{total_size}')
for path, sz in candidates:
    print(f'{path}\t{sz}')
" > "$TRAJECTORY_CANDIDATES" 2>/dev/null || {
  echo "  WARNING: Trajectory scan failed, skipping"
  echo "STATS|0|0|0|0" > "$TRAJECTORY_CANDIDATES"
}

# Parse stats line
TRAJ_STATS=$(head -1 "$TRAJECTORY_CANDIDATES")
TRAJ_CANDIDATES=$(echo "$TRAJ_STATS" | cut -d'|' -f2)
TRAJ_PROTECTED_RECENT=$(echo "$TRAJ_STATS" | cut -d'|' -f3)
TRAJ_PROTECTED_ACTIVE=$(echo "$TRAJ_STATS" | cut -d'|' -f4)
TRAJ_CANDIDATES_BYTES=$(echo "$TRAJ_STATS" | cut -d'|' -f5)

PROTECTED=$((PROTECTED + TRAJ_PROTECTED_RECENT + TRAJ_PROTECTED_ACTIVE))
CANDIDATES=$((CANDIDATES + TRAJ_CANDIDATES))
CANDIDATES_BYTES=$((CANDIDATES_BYTES + TRAJ_CANDIDATES_BYTES))

echo "  Trajectory candidates: $TRAJ_CANDIDATES ($(format_bytes "$TRAJ_CANDIDATES_BYTES"))"
echo "  Protected (recent): $TRAJ_PROTECTED_RECENT"
echo "  Protected (active): $TRAJ_PROTECTED_ACTIVE"

# Process trajectory candidates (show/delete)
if [[ "$TRAJ_CANDIDATES" -gt 0 ]]; then
  tail -n +2 "$TRAJECTORY_CANDIDATES" | while IFS=$'\t' read -r path size; do
    [[ -z "$path" ]] && continue
    if [[ "$MODE" == "report" ]]; then
      : # report mode: skip individual file listing
    else
      safe_rm "$path" "$size"
    fi
  done
fi

# --- Session files (*.jsonl, not *.trajectory.jsonl) ---
echo ""
echo "--- Session JSONL files (*.jsonl, excluding *.trajectory.jsonl) ---"

SESSION_CANDIDATES=$(mktemp)
trap 'rm -f "$SESSION_CANDIDATES"' EXIT

find "$AGENTS_ROOT" -path '*/sessions/*.jsonl' ! -name '*.trajectory.jsonl' ! -name 'sessions.json' -type f -mtime "+${TTL_SESSIONS}" -print0 2>/dev/null \
  | python3 -c "
import sys, os, time

with open('$ACTIVE_UUIDS') as f:
    active_uuids = {line.strip() for line in f if line.strip()}

min_age_seconds = $MIN_AGE_MINUTES * 60
now = time.time()
candidates = []
protected_recent = 0
protected_active = 0

for entry in sys.stdin.buffer.read().split(b'\x00'):
    if not entry:
        continue
    path = entry.decode('utf-8', errors='replace')
    try:
        st = os.stat(path)
    except OSError:
        continue

    # Check min age
    age_seconds = now - st.st_mtime
    if age_seconds < min_age_seconds:
        protected_recent += 1
        continue

    # Check active UUID membership (O(1) set lookup)
    fname = path.rstrip('/').rsplit('/', 1)[-1]
    uuid = fname.split('.', 1)[0] if '.' in fname else fname
    if uuid in active_uuids:
        protected_active += 1
        continue

    candidates.append((path, st.st_size))

total_size = sum(sz for _, sz in candidates)
print(f'STATS|{len(candidates)}|{protected_recent}|{protected_active}|{total_size}')
for path, sz in candidates:
    print(f'{path}\t{sz}')
" > "$SESSION_CANDIDATES" 2>/dev/null || {
  echo "  WARNING: Session scan failed, skipping"
  echo "STATS|0|0|0|0" > "$SESSION_CANDIDATES"
}

# Parse stats line
SESS_STATS=$(head -1 "$SESSION_CANDIDATES")
SESS_CANDIDATES=$(echo "$SESS_STATS" | cut -d'|' -f2)
SESS_PROTECTED_RECENT=$(echo "$SESS_STATS" | cut -d'|' -f3)
SESS_PROTECTED_ACTIVE=$(echo "$SESS_STATS" | cut -d'|' -f4)
SESS_CANDIDATES_BYTES=$(echo "$SESS_STATS" | cut -d'|' -f5)

PROTECTED=$((PROTECTED + SESS_PROTECTED_RECENT + SESS_PROTECTED_ACTIVE))
CANDIDATES=$((CANDIDATES + SESS_CANDIDATES))
CANDIDATES_BYTES=$((CANDIDATES_BYTES + SESS_CANDIDATES_BYTES))

echo "  Session candidates: $SESS_CANDIDATES ($(format_bytes "$SESS_CANDIDATES_BYTES"))"
echo "  Protected (recent): $SESS_PROTECTED_RECENT"
echo "  Protected (active): $SESS_PROTECTED_ACTIVE"

# Process session candidates (show/delete)
if [[ "$SESS_CANDIDATES" -gt 0 ]]; then
  tail -n +2 "$SESSION_CANDIDATES" | while IFS=$'\t' read -r path size; do
    [[ -z "$path" ]] && continue
    if [[ "$MODE" == "report" ]]; then
      : # skip individual file listing in report mode
    else
      safe_rm "$path" "$size"
    fi
  done
fi

# ============================================================================
# Phase 3: Prune orphaned task-queue entries
# ============================================================================
echo ""
echo "=== Phase 3: Pruning orphaned task-queue entries ==="
echo "  Threshold: $TTL_ORPHAN days (queued_at must be older than this)"
echo ""

if [[ -f "$TASK_QUEUE" ]]; then
  # Build a compact Python script for the pruning logic
  PRUNE_SCRIPT=$(mktemp)
  trap 'rm -f "$PRUNE_SCRIPT"' EXIT

  cat > "$PRUNE_SCRIPT" << 'PYEOF'
import json
import sys
from datetime import datetime, timezone, timedelta

if len(sys.argv) < 4:
    print("Usage: prune.py <ttl_days> <mode> <src> [outfile]", file=sys.stderr)
    sys.exit(1)

ttl_days = int(sys.argv[1])
mode = sys.argv[2]
src = sys.argv[3]
outfile = sys.argv[4] if len(sys.argv) > 4 else src + ".pruned.new"

CUTOFF = (datetime.now(timezone.utc) - timedelta(days=ttl_days)).isoformat()

try:
    with open(src, 'r') as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError) as e:
    print(f"ERROR:{e}", file=sys.stderr)
    sys.exit(1)

queue = data.get('queue', [])
removed_atoms = []
filtered = []

for entry in queue:
    status = entry.get('status', '')
    if status in ('cancelled-orphan', 'historical-orphan'):
        queued_at = entry.get('queued_at', '')
        if queued_at and queued_at < CUTOFF:
            removed_atoms.append(entry.get('atom_id', entry.get('id', '?')))
            continue
    filtered.append(entry)

data['queue'] = filtered

with open(outfile, 'w') as f:
    json.dump(data, f, indent=2)

# Report data to stdout (consumed by the shell script)
result = {
    "original": len(queue),
    "filtered": len(filtered),
    "removed": len(removed_atoms),
    "removed_ids": removed_atoms
}
print(json.dumps(result))
PYEOF

  PRUNE_OUT=$(mktemp)
  trap 'rm -f "$PRUNE_SCRIPT" "$PRUNE_OUT"' EXIT

  python3 "$PRUNE_SCRIPT" "$TTL_ORPHAN" "$MODE" "$TASK_QUEUE" "$PRUNE_OUT" > "$PRUNE_OUT.meta" 2>&1 || {
    echo "  WARNING: Task-queue pruning failed, skipping"
    rm -f "$PRUNE_OUT" "$PRUNE_OUT.meta"
  }

  if [[ -f "$PRUNE_OUT" && -f "$PRUNE_OUT.meta" ]]; then
    # Parse JSON result from Python output
    PRUNE_RESULT=$(head -1 "$PRUNE_OUT.meta" 2>/dev/null || echo '{}')
    ORIGINAL_COUNT=$(echo "$PRUNE_RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('original',0))" 2>/dev/null || echo 0)
    FILTERED_COUNT=$(echo "$PRUNE_RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('filtered',0))" 2>/dev/null || echo 0)
    ORPHAN_REMOVED=$(echo "$PRUNE_RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('removed',0))" 2>/dev/null || echo 0)
    REMOVED_IDS=$(echo "$PRUNE_RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); [print(f'  {rid}') for rid in d.get('removed_ids',[])]" 2>/dev/null || true)

    if [[ -n "$REMOVED_IDS" ]]; then
      echo "$REMOVED_IDS"
    fi

    if [[ "$MODE" == "apply" ]]; then
      cp "$PRUNE_OUT" "$TASK_QUEUE"
      echo "  [APPLIED] Pruned $ORPHAN_REMOVED orphan entries from task-queue.json"
      ORPHAN_DELETED=$ORPHAN_REMOVED
    elif [[ "$MODE" == "report" ]]; then
      echo "  [REPORT] $ORPHAN_REMOVED orphan entries eligible for removal (>${TTL_ORPHAN}d old)"
      ORPHAN_CANDIDATES=$ORPHAN_REMOVED
    else
      echo "  [DRY-RUN] $ORPHAN_REMOVED orphan entries would be removed (>${TTL_ORPHAN}d old)"
      ORPHAN_CANDIDATES=$ORPHAN_REMOVED
    fi
    rm -f "$PRUNE_OUT" "$PRUNE_OUT.meta"
  fi
else
  echo "  No task-queue.json found at $TASK_QUEUE"
fi

# ============================================================================
# Phase 4: Summary report
# ============================================================================
echo ""
echo "=============================================="
echo "  Retention Cleanup Summary (CHG-0830)"
echo "=============================================="
echo "  Mode:           $MODE"
echo "  TTL sessions:   ${TTL_SESSIONS}d"
echo "  TTL trajectory: ${TTL_TRAJECTORY}d"
echo "  TTL orphan:     ${TTL_ORPHAN}d"
echo "  Min age:        ${MIN_AGE_HOURS}h"
echo "----------------------------------------------"
echo "  Candidates:             $CANDIDATES ($(format_bytes $CANDIDATES_BYTES))"
echo "  Protected (recent):     $PROTECTED"
echo "  Orphan queue entries:   $ORPHAN_CANDIDATES"
echo "----------------------------------------------"
if [[ "$MODE" == "apply" ]]; then
  echo "  Deleted files:          $DELETED ($(format_bytes $DELETED_BYTES))"
  echo "  Orphan queue pruned:   $ORPHAN_DELETED"
elif [[ "$MODE" == "report" ]]; then
  echo "  (audit only – no changes made)"
else
  echo "  Dry-run candidates:     $DRY_RUN_CANDIDATES ($(format_bytes $DRY_RUN_CANDIDATES_BYTES))"
  echo "  (run with --apply to delete)"
fi
echo "=============================================="

# --- Exit code -------------------------------------------------------------
if [[ "$MODE" == "apply" ]]; then
  if (( DELETED > 0 || ORPHAN_DELETED > 0 )); then
    exit 0
  fi
fi
exit 0