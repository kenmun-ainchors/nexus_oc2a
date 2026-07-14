#!/bin/zsh
# safe-path.sh: Normalizes ~ to absolute path for OpenClaw tool calls.
# Usage: safe-path.sh "/path/to/file"
#        safe-path.sh --enforce [--dry-run] "/path/to/file"
# TKT-0336 / TKT-0327 / TKT-0310 — Platform Constraint Enforcement P0

ENFORCE_MODE=false
DRY_RUN=false
TARGET_PATH=""

# Parse flags
for arg in "$@"; do
  case "$arg" in
    --enforce) ENFORCE_MODE=true ;;
    --dry-run) DRY_RUN=true ;;
    -*)
      echo "Unknown flag: $arg" >&2
      exit 1
      ;;
    *)
      TARGET_PATH="$arg"
      ;;
  esac
done

if [[ -z "$TARGET_PATH" ]]; then
  echo "Usage: safe-path.sh [--enforce] [--dry-run] <path>" >&2
  exit 1
fi

# Resolve workspace home from script location; allow env override.
# For ~-expansion we use the actual user home (not workspace), falling back to $HOME.
# Migration 2026-07-14: no hard-coded user home.
_USER_HOME="${HOME:-$(eval echo ~$(id -un 2>/dev/null) 2>/dev/null || echo /tmp)}"
# WORKSPACE_HOME is the user home used for ~ expansion. It's derived from $HOME, not from
# the script's parent dir (which would be the workspace root, not the user home).
WORKSPACE_HOME="${WORKSPACE_HOME:-$_USER_HOME}"

# --- ENFORCE MODE: Block tilde-path writes ---
if [[ "$ENFORCE_MODE" == "true" ]]; then
  if [[ "$TARGET_PATH" == "~"* ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[DRY-RUN] WOULD BLOCK: tilde path '$TARGET_PATH' rejected by safe-path enforcement" >&2
      exit 0
    else
      echo "BLOCKED: tilde path '$TARGET_PATH' is not allowed — use absolute paths only" >&2
      exit 1
    fi
  fi
  # Path is clean under enforce mode — exit clean
  exit 0
fi

# --- NORMALIZE MODE (default) ---
if [[ "$TARGET_PATH" == "~"* ]]; then
  # Replace leading ~ with workspace home (zsh-safe pattern)
  TARGET_PATH="${TARGET_PATH/#\~/$WORKSPACE_HOME}"
fi

echo "$TARGET_PATH"
