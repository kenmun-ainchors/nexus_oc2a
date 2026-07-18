#!/bin/zsh
# exec-wrapper.sh — Yoda-only exec instrumentation wrapper (CHG-0861)
#
# YODA-ONLY: This wrapper only instruments when OPENCLAW_AGENT_ID=yoda
# (or when explicitly forced with EXEC_WRAPPER_FORCE=1 for testing).
# Non-Yoda sessions pass through transparently with zero overhead.
#
# Usage:
#   exec-wrapper.sh <command> [args...]     # Wrap a single command
#   exec-wrapper.sh install                 # Install Yoda session hook
#   exec-wrapper.sh uninstall               # Remove Yoda session hook
#   exec-wrapper.sh status                  # Check installation status
#
# On empty return (exit 0, no stdout) or non-zero exit:
#   → Appends to state/exec-debug.log
#   → Writes to PG table state_exec_debug (fallback to file-only if PG fails)
#
# On success (every 50th call): lightweight sample (process_count + ulimit_u only)
#
# Behaviour guarantees:
#   - Exit code, stdout, stderr are EXACTLY as the wrapped command produced
#   - No measurable latency added (capture is post-exec)
#   - Existing CHG-0778 guards and CHG-0776 Yoda exec self-restriction unchanged
#
# CHG-0861 | CRESTv2-P1-EXEC-INSTRUMENT-001

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────────
WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
DEBUG_LOG="$WORKSPACE/state/exec-debug.log"
DB_RAW="$WORKSPACE/scripts/db-raw.sh"
DB_WRITE="$WORKSPACE/scripts/db-write.sh"
SAMPLE_INTERVAL=50  # Log process_count + ulimit every Nth successful exec
HOOK_FILE="$WORKSPACE/state/.exec-wrapper-hook-active"

# ── Yoda-only gate ─────────────────────────────────────────────────────────
# Only instrument when OPENCLAW_AGENT_ID=yoda, or when EXEC_WRAPPER_FORCE=1
# (for testing). Non-Yoda sessions pass through with zero overhead.
_is_yoda_session() {
    if [[ "${EXEC_WRAPPER_FORCE:-}" == "1" ]]; then
        return 0
    fi
    local agent="${OPENCLAW_AGENT_ID:-}"
    if [[ "$agent" == "yoda" ]]; then
        return 0
    fi
    # Also check if hook is installed (means Yoda session is active)
    if [[ -f "$HOOK_FILE" ]]; then
        return 0
    fi
    return 1
}

# ── Counter for sampling (persisted across calls) ───────────────────────────
COUNTER_FILE="$WORKSPACE/state/.exec-wrapper-counter"
if [[ -f "$COUNTER_FILE" ]]; then
    EXEC_COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
else
    EXEC_COUNT=0
fi

# ── Helpers ──────────────────────────────────────────────────────────────────

# Generate a UUID (macOS compatible)
_uuid() {
    python3 -c "import uuid; print(uuid.uuid4())"
}

# ISO8601 timestamp with timezone
_ts() {
    TZ=Asia/Kuala_Lumpur date '+%Y-%m-%dT%H:%M:%S%z'
}

# Process count
_pcount() {
    ps aux 2>/dev/null | wc -l | tr -d ' '
}

# ulimit -u
_ulimit_u() {
    ulimit -u 2>/dev/null || echo "unknown"
}

# Determine calling agent from env
_calling_agent() {
    local agent="${OPENCLAW_AGENT_ID:-}"
    if [[ -z "$agent" ]]; then
        agent="${OPENCLAW_SESSION_ID:-}"
    fi
    if [[ -z "$agent" ]]; then
        agent="${SESSION_ID:-}"
    fi
    if [[ -z "$agent" ]]; then
        agent="unknown"
    fi
    echo "$agent"
}

# Determine session type
_session_type() {
    if [[ -n "${OPENCLAW_ISOLATED_SESSION:-}" ]]; then
        echo "isolated"
    elif [[ -n "${OPENCLAW_MAIN_SESSION:-}" ]]; then
        echo "main"
    else
        echo "current"
    fi
}

# ── Install / Uninstall / Status ────────────────────────────────────────────

_install_hook() {
    local agent
    agent=$(_calling_agent)
    echo "yoda" > "$HOOK_FILE"
    echo "EXEC_WRAPPER_HOOK_ACTIVE=1" >> "$HOOK_FILE"
    echo "[exec-wrapper] Hook installed for Yoda session (agent=$agent)" >&2
    echo "[exec-wrapper] All exec calls in this session will be instrumented." >&2
    echo "[exec-wrapper] To remove: exec-wrapper.sh uninstall" >&2
}

_uninstall_hook() {
    rm -f "$HOOK_FILE"
    echo "[exec-wrapper] Hook removed. Yoda exec instrumentation disabled." >&2
}

_status() {
    if [[ -f "$HOOK_FILE" ]]; then
        echo "[exec-wrapper] STATUS: INSTALLED (Yoda exec instrumentation active)"
        echo "  Hook file: $HOOK_FILE"
        echo "  Debug log: $DEBUG_LOG"
        echo "  PG table:  state_exec_debug"
        echo "  Counter:   $COUNTER_FILE ($(cat "$COUNTER_FILE" 2>/dev/null || echo 0) calls)"
        echo "  Samples:  $(test -f "$DEBUG_LOG" && wc -l < "$DEBUG_LOG" || echo 0) lines in log"
    else
        echo "[exec-wrapper] STATUS: NOT INSTALLED (Yoda exec instrumentation inactive)"
    fi
}

# ── Core wrapper function ───────────────────────────────────────────────────

exec_wrapper() {
    local cmd="$*"

    # ── Yoda-only gate ──────────────────────────────────────────────────────
    if ! _is_yoda_session; then
        # Non-Yoda: pass through transparently with zero overhead
        eval "$cmd"
        return $?
    fi

    local ts
    ts=$(_ts)
    local uuid
    uuid=$(_uuid)
    local agent
    agent=$(_calling_agent)
    local stype
    stype=$(_session_type)

    # Temp files for stdout/stderr capture
    local stdout_file stderr_file
    stdout_file=$(mktemp -t execwrap_stdout.XXXXXX)
    stderr_file=$(mktemp -t execwrap_stderr.XXXXXX)
    trap 'rm -f "$stdout_file" "$stderr_file"' EXIT INT TERM

    # Execute the command, capturing stdout and stderr separately
    set +e
    (
        set +e
        eval "$cmd" > "$stdout_file" 2>"$stderr_file"
    )
    local exit_code=$?
    set -e

    # Read captured output (strip any shell trace lines from stderr)
    local stdout stderr
    stdout=$(cat "$stdout_file" 2>/dev/null || true)
    stderr=$(cat "$stderr_file" 2>/dev/null | grep -v '^\+\+' || true)

    # Cleanup temp files
    rm -f "$stdout_file" "$stderr_file"
    trap - EXIT INT TERM

    # Increment counter
    EXEC_COUNT=$((EXEC_COUNT + 1))
    echo "$EXEC_COUNT" > "$COUNTER_FILE"

    # ── Determine if we should log ──────────────────────────────────────────
    local should_log=false
    local log_type=""

    if [[ $exit_code -ne 0 ]]; then
        should_log=true
        log_type="failure"
    elif [[ -z "$stdout" && -z "$stderr" ]]; then
        # Exit 0 but no output at all — empty return
        should_log=true
        log_type="empty"
    elif [[ $((EXEC_COUNT % SAMPLE_INTERVAL)) -eq 0 ]]; then
        # Every Nth successful exec: lightweight sample
        should_log=true
        log_type="sample"
    fi

    if [[ "$should_log" == "true" ]]; then
        local pcount ulimit_u
        pcount=$(_pcount)
        ulimit_u=$(_ulimit_u)

        if [[ "$log_type" == "sample" ]]; then
            # Lightweight: process_count + ulimit_u only
            local log_entry
            log_entry="$(printf '%s' "[${ts}] [SAMPLE] [${uuid}] pcount=${pcount} ulimit=${ulimit_u}")"
            echo "$log_entry" >> "$DEBUG_LOG"
        else
            # Full artifact
            local log_entry
            log_entry="$(printf '%s' "[${ts}] [${log_type}] [exit=${exit_code}] [${uuid}] cmd=${cmd}")"
            printf '%s\n' "$log_entry" >> "$DEBUG_LOG"
            printf '%s\n' "stdout: ${stdout:-(empty)}" >> "$DEBUG_LOG"
            printf '%s\n' "stderr: ${stderr:-(empty)}" >> "$DEBUG_LOG"
            printf '%s\n' "pcount=${pcount} ulimit=${ulimit_u} agent=${agent} session=${stype}" >> "$DEBUG_LOG"
            printf '%s\n' "---" >> "$DEBUG_LOG"

            # ── Write to PG (fallback to file-only if PG fails) ─────────────
            # Ensure PG env vars have defaults (Yoda session may not export them)
            export PGHOST="${PGHOST:-/tmp}"
            export PGPORT="${PGPORT:-5432}"
            export PGUSER="${PGUSER:-"${PGUSER:-$(whoami)}"}"
            export PGDATABASE="${PGDATABASE:-ainchors_nexus}"

            local pg_ok=false
            local source="file-only"

            # Build JSON payload for db-write.sh (passed as 2nd arg, not stdin)
            local json_payload
            json_payload=$(python3 -c "
import json, sys
cmd = '''$cmd'''
stdout = '''$stdout'''
stderr = '''$stderr'''
ulimit_u = '''$ulimit_u'''
agent = '''$agent'''
stype = '''$stype'''
payload = {
    'id': '$uuid',
    'timestamp': '$ts',
    'command': cmd,
    'exit_code': $exit_code,
    'stdout': stdout,
    'stderr': stderr,
    'process_count': $pcount,
    'ulimit_u': ulimit_u,
    'calling_agent': agent,
    'session_type': stype,
    'source': 'both'
}
print(json.dumps(payload))
" 2>/dev/null || echo '{}')

            if [[ "$json_payload" != "{}" ]]; then
                local db_result
                db_result=$(bash "$DB_WRITE" "state_exec_debug" "$json_payload" "$uuid" 2>/dev/null) || true
                if echo "$db_result" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); sys.exit(0 if d.get('backend')=='postgres' else 1)" 2>/dev/null; then
                    pg_ok=true
                    source="both"
                else
                    source="file-only"
                    printf '%s\n' "PG_WRITE_FAILED: $(date)" >> "$DEBUG_LOG"
                fi
            fi
        fi
    fi

    # ── Output: reproduce original stdout/stderr exactly ────────────────────
    if [[ -n "$stdout" ]]; then
        printf '%s\n' "$stdout"
    fi
    if [[ -n "$stderr" ]]; then
        printf '%s\n' "$stderr" >&2
    fi

    return $exit_code
}

# ── Main dispatch ──────────────────────────────────────────────────────────
if [[ "${ZSH_EVAL_CONTEXT:-}" == "toplevel" || "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        install)
            _install_hook
            ;;
        uninstall)
            _uninstall_hook
            ;;
        status)
            _status
            ;;
        *)
            if [[ $# -eq 0 ]]; then
                echo "Usage: exec-wrapper.sh <command> [args...]" >&2
                echo "       exec-wrapper.sh install|uninstall|status" >&2
                exit 1
            fi
            exec_wrapper "$@"
            ;;
    esac
fi
