#!/bin/zsh
# cron-write.sh: Atomic file writer for isolated cron sessions
# Solves the ~ tilde-path bug (TKT-0327) — models in isolated sessions
# can't expand ~, so they pipe content to this script instead.
#
# Usage:
#   echo "content" | cron-write.sh <target_path>
#   cron-write.sh <target_path> <content_string>
#   cron-write.sh --file <content_file> <target_path>
#
# All paths are normalized to absolute before writing.
# Creates parent directories if needed.
# Writes atomically via temp file + mv.

set -euo pipefail

WORKSPACE="/Users/ainchorsoc2a"

normalize_path() {
  local path="$1"
  # Expand ~ to absolute
  path="${path/#\~/$WORKSPACE}"
  # If relative (no leading /), prefix workspace
  if [[ "$path" != /* ]]; then
    path="$WORKSPACE/$path"
  fi
  echo "$path"
}

atomic_write() {
  local target="$1"
  local target_dir
  target_dir="$(dirname "$target")"
  
  mkdir -p "$target_dir"
  
  local tmpfile="${target}.tmp.$$"
  
  # Write stdin to temp file
  cat > "$tmpfile"
  
  # Atomic move
  mv "$tmpfile" "$target"
  
  echo "OK: $(wc -c < "$target") bytes → $target"
}

# --- Main ---

if [[ $# -eq 0 ]]; then
  echo "Usage: cron-write.sh <target_path> [content]"
  echo "       echo 'content' | cron-write.sh <target_path>"
  echo "       cron-write.sh --file <content_file> <target_path>"
  exit 1
fi

TARGET=""

if [[ "$1" == "--file" ]]; then
  # cron-write.sh --file /tmp/content.html /target/path
  if [[ $# -ne 3 ]]; then
    echo "ERROR: --file requires <content_file> <target_path>"
    exit 1
  fi
  CONTENT_FILE="$2"
  TARGET="$(normalize_path "$3")"
  if [[ ! -f "$CONTENT_FILE" ]]; then
    echo "ERROR: content file not found: $CONTENT_FILE"
    exit 1
  fi
  cat "$CONTENT_FILE" | atomic_write "$TARGET"
elif [[ $# -eq 2 ]]; then
  # cron-write.sh /target/path "content string"
  TARGET="$(normalize_path "$1")"
  echo "$2" | atomic_write "$TARGET"
elif [[ $# -eq 1 ]]; then
  # echo "content" | cron-write.sh /target/path
  TARGET="$(normalize_path "$1")"
  atomic_write "$TARGET"
else
  echo "ERROR: too many arguments"
  exit 1
fi
