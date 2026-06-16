#!/bin/bash
# Stale task cleanup – remove temp files > 48 hours old
# Returns count of removed items on stdout.

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
COUNT=0

clean_dir() {
  local dir="$1"
  if [ -d "$dir" ]; then
    while IFS= read -r -d '' f; do
      rm -f "$f"
      ((COUNT++))
    done < <(find "$dir" -type f -mtime +2 -print0 2>/dev/null)
  fi
}

clean_dir "$WORKSPACE/tmp"
clean_dir "$WORKSPACE/state/cache"

echo "$COUNT"