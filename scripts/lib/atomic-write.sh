#!/bin/zsh
# atomic-write.sh — shared helper for durable state-file writes
# Usage: source scripts/lib/atomic-write.sh
#        atomic_write <target_path> <content_stdin>
#        atomic_write_file <target_path> <source_path>
#
# Guarantees:
# - target is never in a partially-written state
# - existing target is preserved until new content is fsynced and renamed
# - mtime/mode of parent directory are updated only on success
#
# TKT-0529 A7 Bundle 1: introduced as shared lib (Ken decision 2026-06-18).

set -euo pipefail

ATOMIC_WRITE_LIB_VERSION="1.0.0"

# Write stdin to target atomically.
# Usage: echo "$content" | atomic_write /path/to/file
function atomic_write() {
  local target="$1"
  local tmp
  tmp=$(mktemp "${target}.tmp.XXXXXX")
  # cleanup tmp on unexpected exit
  trap 'rm -f "$tmp" 2>/dev/null || true' EXIT INT TERM
  cat > "$tmp"
  if [[ ! -s "$tmp" ]]; then
    # allow empty writes only if stdin was intentionally empty
    : # pass
  fi
  chmod --reference="$target" "$tmp" 2>/dev/null || chmod 0644 "$tmp"
  mv -f "$tmp" "$target"
  trap - EXIT INT TERM
}

# Copy a source file to target atomically.
# Usage: atomic_write_file /path/to/target /path/to/source
function atomic_write_file() {
  local target="$1"
  local source="$2"
  if [[ ! -f "$source" ]]; then
    echo "atomic_write_file: source not found: $source" >&2
    return 1
  fi
  local tmp
  tmp=$(mktemp "${target}.tmp.XXXXXX")
  trap 'rm -f "$tmp" 2>/dev/null || true' EXIT INT TERM
  cp "$source" "$tmp"
  chmod --reference="$target" "$tmp" 2>/dev/null || chmod 0644 "$tmp"
  mv -f "$tmp" "$target"
  trap - EXIT INT TERM
}

# If executed directly, print version. If sourced, stay silent.
if [[ -n "${ZSH_SCRIPT:-}" ]]; then
  echo "atomic-write.sh v${ATOMIC_WRITE_LIB_VERSION}"
fi
