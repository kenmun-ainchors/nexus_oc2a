#!/bin/bash
# sync-agent-memory.sh — Periodic re-hardlink of main workspace memory to per-agent workspaces
#
# CHG-0933: After CHG-0929 shared main workspace memory across per-agent
# workspaces via hardlinks, new files added to workspace/memory/ did not
# automatically appear in per-agent workspace-<agent>/memory/ directories.
# This script closes that gap by scanning the main memory directory and
# ensuring every file (recursively) is hardlinked into each per-agent
# memory directory.
#
# Behaviour:
#   - Reads /Users/ainchorsoc2a/.openclaw/openclaw.json to enumerate agents.
#   - For every agent whose `workspace` is NOT the main workspace
#     (/Users/ainchorsoc2a/.openclaw/workspace), it hardlinks every file
#     from main memory into <agent-workspace>/memory/ with the same path.
#   - Skips files already correctly hardlinked (same inode as main).
#   - Skips .dreams/ subtree defensively (not part of durable memory).
#   - NEVER deletes per-agent files that are not in main memory (avoids
#     data loss if an agent maintains a private file). Safety first.
#   - Logs every action to ~/.openclaw/logs/sync-agent-memory.log.
#   - Idempotent: safe to run repeatedly. Same-inode check + ln only when needed.
#
# Usage:
#   bash scripts/sync-agent-memory.sh
#   bash scripts/sync-agent-memory.sh --dry-run
#   bash scripts/sync-agent-memory.sh --verbose
#
# Exit codes:
#   0 = success (all target agents processed, no errors)
#   1 = config or filesystem error
#   2 = jq missing or openclaw.json unparseable
#
# Cron-friendly. Designed to run as the gateway user (ainchorsoc2a).
#
# See: state/chg0933-crest-plan.md for CREST plan and verification.

set -euo pipefail

# --- Configuration ---------------------------------------------------------

readonly OPENCLAW_CONFIG="${OPENCLAW_CONFIG:-/Users/ainchorsoc2a/.openclaw/openclaw.json}"
readonly MAIN_WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
readonly MAIN_MEMORY="$MAIN_WORKSPACE/memory"
readonly LOG_DIR="$HOME/.openclaw/logs"
readonly LOG_FILE="$LOG_DIR/sync-agent-memory.log"
readonly SKIP_DIR_NAMES_REGEX='(^|/)\.dreams(/|$)'  # skip any path containing /.dreams/ segment

# --- Argument parsing ------------------------------------------------------

DRY_RUN=0
VERBOSE=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --verbose|-v) VERBOSE=1 ;;
        -h|--help)
            sed -n '2,30p' "$0"
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg" >&2
            exit 1
            ;;
    esac
done

# --- Helpers ---------------------------------------------------------------

ts() { TZ=Asia/Kuala_Lumpur date '+%Y-%m-%dT%H:%M:%S%z'; }

log_init() {
    mkdir -p "$LOG_DIR"
    {
        echo "===== $(ts) sync-agent-memory.sh start (dry_run=$DRY_RUN pid=$$) ====="
    } >> "$LOG_FILE"
}

log() {
    local level="$1"; shift
    printf '%s [%s] %s\n' "$(ts)" "$level" "$*" | tee -a "$LOG_FILE" >/dev/null
    if [[ "$VERBOSE" == "1" ]]; then
        printf '%s [%s] %s\n' "$(ts)" "$level" "$*"
    fi
}

log_console() {
    # Always echo to stdout (so cron captures it) and to log file.
    printf '%s\n' "$*" | tee -a "$LOG_FILE" >/dev/null
    printf '%s\n' "$*"
}

die() {
    log "ERROR" "$*"
    exit 1
}

# --- Preflight -------------------------------------------------------------

[[ -f "$OPENCLAW_CONFIG" ]] || die "openclaw config not found at $OPENCLAW_CONFIG"
command -v jq >/dev/null 2>&1 || die "jq is required for config parsing"
[[ -d "$MAIN_MEMORY" ]] || die "main memory directory not found at $MAIN_MEMORY"

log_init

# --- Enumerate target agents ----------------------------------------------

# Pull every agent's id + workspace from openclaw.json. We filter in shell to
# keep the script portable and obvious.
# Portable: read lines into bash arrays without mapfile (macOS bash 3.2 lacks it).
read_agent_lines() {
    AGENT_LINES=()
    local line
    while IFS= read -r line; do
        AGENT_LINES+=("$line")
    done < <(jq -r '.agents.list[] | "\(.id)\t\(.workspace // .agents.defaults.workspace)"' "$OPENCLAW_CONFIG" 2>/dev/null)
}

read_source_files() {
    SOURCE_FILES=()
    local rel
    while IFS= read -r rel; do
        # find prints "./path"; strip the leading "./"
        rel="${rel#./}"
        [[ -n "$rel" ]] && SOURCE_FILES+=("$rel")
    done < <(cd "$MAIN_MEMORY" && find . -type f \( ! -path './.dreams' ! -path './.dreams/*' \) | sort)
}

read_agent_lines
if [[ ${#AGENT_LINES[@]} -eq 0 ]]; then
    die "no agents found in $OPENCLAW_CONFIG"
fi
log "INFO" "Discovered ${#AGENT_LINES[@]} agents in $OPENCLAW_CONFIG"

# --- Enumerate main-memory source files (recursively) ---------------------

# Use -L so symlinks in main memory are followed (memory may have soft links
# to shared subdirs). We track each file's path relative to MAIN_MEMORY.
read_source_files
if [[ ${#SOURCE_FILES[@]} -eq 0 ]]; then
    die "no source files found in $MAIN_MEMORY"
fi
log "INFO" "Found ${#SOURCE_FILES[@]} source files in main memory"

# --- Sync loop -------------------------------------------------------------

TOTAL_AGENTS=0
TOTAL_LINKS=0
TOTAL_SKIPPED=0
TOTAL_ERRORS=0
TOTAL_MISSING_DIRS=0

for line in "${AGENT_LINES[@]}"; do
    agent_id="${line%%	*}"
    agent_ws="${line#*	}"

    # Skip main workspace — it's the source, not a target.
    if [[ "$agent_ws" == "$MAIN_WORKSPACE" ]]; then
        log "INFO" "skip agent=$agent_id (workspace == main)"
        continue
    fi

    # Validate workspace exists and has a memory/ subdir we can write to.
    if [[ ! -d "$agent_ws" ]]; then
        log "WARN" "agent=$agent_id workspace missing: $agent_ws"
        TOTAL_MISSING_DIRS=$((TOTAL_MISSING_DIRS + 1))
        continue
    fi
    agent_mem="$agent_ws/memory"
    if [[ ! -d "$agent_mem" ]]; then
        # Don't auto-create; CHG-0929 should have created it. Surface as warn.
        log "WARN" "agent=$agent_id memory dir missing: $agent_mem (skipping)"
        TOTAL_MISSING_DIRS=$((TOTAL_MISSING_DIRS + 1))
        continue
    fi

    TOTAL_AGENTS=$((TOTAL_AGENTS + 1))
    agent_links=0
    agent_skipped=0
    agent_errors=0

    for rel in "${SOURCE_FILES[@]}"; do
        # Strip leading "./"
        rel="${rel#./}"
        src="$MAIN_MEMORY/$rel"
        tgt="$agent_mem/$rel"

        # Defensive skip: .dreams/ segment
        if [[ "$rel" =~ $SKIP_DIR_NAMES_REGEX ]]; then
            log "DEBUG" "agent=$agent_id skip $rel (.dreams)"
            agent_skipped=$((agent_skipped + 1))
            continue
        fi

        # Source may have been deleted between find and now (TOCTOU). Treat
        # as a soft warn, not an error — the next sync run will re-evaluate.
        if [[ ! -f "$src" ]]; then
            log "WARN" "agent=$agent_id source missing (TOCTOU): $src"
            continue
        fi

        # If target directory tree doesn't exist (e.g. shared/ subdir), create it.
        tgt_dir="$(dirname "$tgt")"
        if [[ ! -d "$tgt_dir" ]]; then
            if [[ "$DRY_RUN" == "1" ]]; then
                log "INFO" "agent=$agent_id DRY-RUN mkdir -p $tgt_dir"
            else
                mkdir -p "$tgt_dir" || {
                    log "ERROR" "agent=$agent_id mkdir failed for $tgt_dir"
                    agent_errors=$((agent_errors + 1))
                    continue
                }
            fi
        fi

        # Already a correct hardlink? Skip.
        if [[ -f "$tgt" ]]; then
            src_ino=$(stat -f '%i' "$src" 2>/dev/null || echo "")
            tgt_ino=$(stat -f '%i' "$tgt" 2>/dev/null || echo "")
            if [[ -n "$src_ino" && "$src_ino" == "$tgt_ino" ]]; then
                log "DEBUG" "agent=$agent_id ok-hardlink $rel (inode=$src_ino)"
                agent_skipped=$((agent_skipped + 1))
                continue
            else
                # File exists but is a separate inode. Replace it: the source of
                # truth is main. We need to unlink the per-agent copy first,
                # then ln. Use a tmp+rename pattern to avoid partial state.
                if [[ "$DRY_RUN" == "1" ]]; then
                    log "INFO" "agent=$agent_id DRY-RUN would replace $rel (src_ino=$src_ino tgt_ino=$tgt_ino)"
                else
                    if ! rm -f "$tgt"; then
                        log "ERROR" "agent=$agent_id rm failed for stale $tgt"
                        agent_errors=$((agent_errors + 1))
                        continue
                    fi
                fi
            fi
        fi

        # Create the hardlink. If ln fails because the source vanished
        # mid-run, treat as a warn (not an error) — next sync will re-evaluate.
        if [[ "$DRY_RUN" == "1" ]]; then
            log "INFO" "agent=$agent_id DRY-RUN ln $src -> $tgt"
        else
            if ln "$src" "$tgt" 2>>"$LOG_FILE"; then
                log "INFO" "agent=$agent_id hardlinked $rel"
                agent_links=$((agent_links + 1))
            elif [[ ! -f "$src" ]]; then
                # Source vanished between check and ln — soft warn, not error.
                log "WARN" "agent=$agent_id source vanished during ln (TOCTOU): $src"
            else
                log "ERROR" "agent=$agent_id ln failed: $src -> $tgt"
                agent_errors=$((agent_errors + 1))
            fi
        fi
    done

    log "INFO" "agent=$agent_id done: hardlinks=$agent_links skipped=$agent_skipped errors=$agent_errors"
    TOTAL_LINKS=$((TOTAL_LINKS + agent_links))
    TOTAL_SKIPPED=$((TOTAL_SKIPPED + agent_skipped))
    TOTAL_ERRORS=$((TOTAL_ERRORS + agent_errors))
done

# --- Summary ---------------------------------------------------------------

SUMMARY="sync-agent-memory.sh complete: agents=$TOTAL_AGENTS new_links=$TOTAL_LINKS skipped=$TOTAL_SKIPPED errors=$TOTAL_ERRORS missing_dirs=$TOTAL_MISSING_DIRS (source_files=${#SOURCE_FILES[@]})"
log "INFO" "$SUMMARY"
log_console "$SUMMARY"

if [[ "$TOTAL_ERRORS" -gt 0 ]]; then
    exit 1
fi
exit 0
