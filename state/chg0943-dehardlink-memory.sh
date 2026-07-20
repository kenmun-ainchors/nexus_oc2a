#!/bin/zsh
set -euo pipefail

MAIN_WS="/Users/ainchorsoc2a/.openclaw/workspace"
SOURCE="$MAIN_WS/MEMORY.md"
BACKUP_DIR="$MAIN_WS/state/chg0943-backup"
LOG="$BACKUP_DIR/chg0943.log"

mkdir -p "$BACKUP_DIR"
{
  echo "===== $(date +%Y-%m-%dT%H:%M:%S%z) CHG-0943 de-hardlink start ====="
  echo "source=$SOURCE"
  echo "source links before: $(stat -f '%l' "$SOURCE")"
  echo "source inode before: $(stat -f '%i' "$SOURCE")"

  # Back up the pre-change content once (from source; all 13 are identical)
  if [[ ! -f "$BACKUP_DIR/MEMORY.md.before" ]]; then
    # Read via cat to avoid same-file cp restriction
    cat "$SOURCE" > "$BACKUP_DIR/MEMORY.md.before"
    chmod 600 "$BACKUP_DIR/MEMORY.md.before"
  fi

  for ws in \
    "$MAIN_WS" \
    "$MAIN_WS-business" \
    "$MAIN_WS-architect" \
    "$MAIN_WS-platform-arch" \
    "$MAIN_WS-ahsoka" \
    "$MAIN_WS-social" \
    "$MAIN_WS-bpm" \
    "$MAIN_WS-dtcm" \
    "$MAIN_WS-security" \
    "$MAIN_WS-legal" \
    "$MAIN_WS-qa" \
    "$MAIN_WS-governance" \
    "$MAIN_WS-luthen"; do

    target="$ws/MEMORY.md"
    if [[ ! -f "$target" ]]; then
      echo "WARN: $target missing, copying fresh"
    else
      echo "processing $target (links=$(stat -f '%l' "$target"), inode=$(stat -f '%i' "$target"))"
    fi

    # Read content into a temp file to avoid same-file cp refusal, then
    # atomically replace the target. This unlinks the hardlink first,
    # creating an independent inode on the target path.
    tmp="$(mktemp -t chg0943-XXXXXX)"
    cat "$SOURCE" > "$tmp"
    chmod 600 "$tmp"
    # mv will rename over existing target; on same FS this unlinks old hardlink
    mv -f "$tmp" "$target"
    chmod 600 "$target"
    echo "  -> replaced, links=$(stat -f '%l' "$target"), inode=$(stat -f '%i' "$target")"
  done

  echo "source links after: $(stat -f '%l' "$SOURCE")"
  echo "source inode after: $(stat -f '%i' "$SOURCE")"
  echo "===== CHG-0943 de-hardlink complete ====="
} | tee "$LOG" >/dev/null
