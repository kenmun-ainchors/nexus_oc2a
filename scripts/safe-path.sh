#!/bin/zsh
# safe-path.sh: Normalizes ~ to absolute path for OpenClaw tool calls.
# Usage: safe-path.sh "/path/to/file"

if [[ -z "$1" ]]; then
  echo "Usage: safe-path.sh <path>"
  exit 1
fi

TARGET_PATH=$1
if [[ "$TARGET_PATH" == "~"* ]]; then
  TARGET_PATH="${TARGET_PATH/~/\/Users/ainchorsangiefpl}"
fi

echo "$TARGET_PATH"
