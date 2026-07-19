#!/bin/bash
# pg-safe-start.sh — TKT-1008: PG startup wrapper that auto-recovers from stale postmaster.pid
#
# Purpose: Make PostgreSQL startup resilient to stale pidfiles left over from a crash
# where PG died before it could remove its lock file. Without this wrapper, launchd's
# KeepAlive=true retry loop deadlocks: launchd restarts PG, PG refuses to start because
# the lock exists, launchd restarts again, repeat. (See state/oc2a-post-move-health-2026-07-18.json F1.)
#
# Algorithm:
#   1. Locate the postmaster.pid file based on the data directory passed in $1.
#   2. If present:
#        a. Read the first line (the PID).
#        b. Check if a process with that PID is alive.
#        c. Check if the live process is a postgres postmaster (comm == "postgres" or
#           argv0 contains "postgres"). This is the safe guard: only remove the lock
#           if the referenced process is dead OR clearly not a postgres postmaster.
#        d. If dead OR not-postgres: log the recovery, remove the stale lock, then start.
#        e. If alive AND is a postmaster: another PG instance owns the data dir; abort
#           cleanly so we never clobber a live cluster.
#   3. If no pidfile: proceed normally.
#   4. exec the real postgres binary so signals (SIGTERM from launchd) reach it directly.
#
# Usage (in launchd plist ProgramArguments, replacing direct postgres invocation):
#   /Users/ainchorsoc2a/.openclaw/workspace/scripts/pg-safe-start.sh \
#     /Users/ainchorsoc2a/homebrew/opt/postgresql@16/bin/postgres \
#     -D /Users/ainchorsoc2a/homebrew/var/postgresql@16
#
# Or via env wrapper (recommended for OC2A — see ai.openclaw.gateway-env-wrapper.sh pattern).
#
# Security:
#   - Does NOT disable launchd KeepAlive. It works WITH KeepAlive, just heals the lock.
#   - Validates the referenced process before removing the lock. Will never remove a
#     live postmaster's lock by accident.
#   - Logs every action to PG_LOG and to a dedicated recovery log for auditability.
#
# Exit codes:
#   0  normal startup or recovery succeeded
#   10 no postgres binary found
#   11 data dir not provided
#   12 stale lock could not be removed (permissions)
#   13 data dir appears owned by a live postmaster (refusing to clobber)
#
# CHG-0912 — TKT-1008 permanent fix (Ken approved 2026-07-18 13:16 AEST)

set -uo pipefail

RECOVERY_LOG="${PG_SAFE_START_LOG:-/Users/ainchorsoc2a/homebrew/var/log/postgresql@16.safe-start.log}"
PG_BIN="${1:-}"
shift || true

if [[ -z "$PG_BIN" ]]; then
  echo "[pg-safe-start] FATAL: postgres binary path not provided as \$1" >&2
  echo "[pg-safe-start] FATAL:   usage: pg-safe-start.sh <postgres-bin> -D <data-dir> [args...]" >&2
  exit 10
fi

if [[ ! -x "$PG_BIN" ]]; then
  echo "[pg-safe-start] FATAL: postgres binary not executable: $PG_BIN" >&2
  exit 10
fi

# Parse -D <datadir> out of remaining args (postgres requires -D before any other data-dir-touching flags)
DATA_DIR=""
ARGS=("$@")
for ((i=0; i<${#ARGS[@]}; i++)); do
  if [[ "${ARGS[$i]}" == "-D" ]]; then
    DATA_DIR="${ARGS[$((i+1))]:-}"
    break
  fi
done

if [[ -z "$DATA_DIR" ]]; then
  echo "[pg-safe-start] FATAL: -D <data-dir> not provided in args" >&2
  exit 11
fi

PIDFILE="$DATA_DIR/postmaster.pid"
mkdir -p "$(dirname "$RECOVERY_LOG")"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] $*" | tee -a "$RECOVERY_LOG" ; }

log "pg-safe-start invoked: bin=$PG_BIN data_dir=$DATA_DIR"

# ── Stale pidfile recovery ──────────────────────────────────────────────────
if [[ -f "$PIDFILE" ]]; then
  STALE_PID="$(head -n 1 "$PIDFILE" 2>/dev/null | tr -d '[:space:]')"
  if [[ -z "$STALE_PID" ]]; then
    log "WARN: pidfile $PIDFILE exists but is empty — treating as stale, removing"
    if ! rm -f "$PIDFILE"; then
      log "ERROR: failed to remove empty pidfile (permissions?)"
      exit 12
    fi
    log "RECOVERED: removed empty pidfile"
  else
    # Is the referenced PID alive?
    if kill -0 "$STALE_PID" 2>/dev/null; then
      # PID is alive — is it actually a postgres postmaster?
      # ps -o comm= on macOS can return the full path of the executable
      # (e.g. /Users/.../opt/postgresql@16/bin/postgres) when the process
      # was launched with an absolute path. Use basename for a stable match.
      PROC_COMM_FULL="$(ps -p "$STALE_PID" -o comm= 2>/dev/null | tr -d '[:space:]')"
      PROC_COMM="$(basename "$PROC_COMM_FULL" 2>/dev/null || echo "$PROC_COMM_FULL")"
      PROC_ARGV="$(ps -p "$STALE_PID" -o args= 2>/dev/null | head -c 200)"
      if [[ "$PROC_COMM" == "postgres" ]] && [[ "$PROC_ARGV" == *postgres* ]]; then
        log "ABORT: pidfile references LIVE postmaster PID $STALE_PID (comm=$PROC_COMM_FULL) — refusing to remove"
        log "  another postgres process owns $DATA_DIR; investigate before restart"
        exit 13
      else
        log "RECOVERED: pidfile references PID $STALE_PID but process is '$PROC_COMM_FULL' (basename=$PROC_COMM, not postgres) — stale, removing"
        if ! rm -f "$PIDFILE"; then
          log "ERROR: failed to remove stale pidfile (permissions?)"
          exit 12
        fi
        log "RECOVERED: removed stale pidfile (PID $STALE_PID was $PROC_COMM_FULL, not postgres)"
      fi
    else
      log "RECOVERED: pidfile references dead PID $STALE_PID — stale, removing"
      if ! rm -f "$PIDFILE"; then
        log "ERROR: failed to remove stale pidfile (permissions?)"
        exit 12
      fi
      log "RECOVERED: removed stale pidfile (PID $STALE_PID was dead)"
    fi
  fi
else
  log "OK: no pidfile at $PIDFILE — clean start"
fi

# ── exec the real postgres (signals reach it directly) ─────────────────────
log "START: exec $PG_BIN $*"
exec "$PG_BIN" "$@"
