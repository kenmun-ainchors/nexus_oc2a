#!/bin/zsh
# safe-path.sh: Normalizes ~ to absolute path for OpenClaw tool calls.
# Usage: safe-path.sh "/path/to/file"
# TKT-0336 / TKT-0327 / TKT-0310 — Platform Constraint Enforcement P0

if [[ -z "$1" ]]; then
  echo "Usage: safe-path.sh <path>" >&2
  exit 1
fi

TARGET_PATH="$1"
WORKSPACE_HOME="/Users/ainchorsangiefpl"

if [[ "$TARGET_PATH" == "~"* ]]; then
  # Replace leading ~ with workspace home (zsh-safe pattern)
  TARGET_PATH="${TARGET_PATH/#\~/$WORKSPACE_HOME}"
fi

echo "$TARGET_PATH"
