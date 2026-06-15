#!/bin/bash
# install-pre-commit-hooks.sh — one-time installer for pre-commit hooks (L-129).
# Symlinks scripts/hooks/* into .git/hooks/. Safe to re-run.
# Safety: prompts before overwriting a non-symlink pre-commit that already exists.
set -e

WORKSPACE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$WORKSPACE"

HOOKS_DIR="$WORKSPACE/scripts/hooks"
GIT_HOOKS_DIR="$WORKSPACE/.git/hooks"

if [[ ! -d "$HOOKS_DIR" ]]; then
  echo "ERROR: $HOOKS_DIR does not exist" >&2
  exit 1
fi

mkdir -p "$GIT_HOOKS_DIR"

INSTALLED=0
SKIPPED=0
for src in "$HOOKS_DIR"/*; do
  name=$(basename "$src")
  dest="$GIT_HOOKS_DIR/$name"
  
  if [[ -e "$dest" ]] && [[ ! -L "$dest" ]]; then
    # File exists and is not a symlink — safety check
    echo "WARN: $dest already exists (not a symlink). Skipping." >&2
    echo "  To force: rm $dest && re-run this installer" >&2
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  
  rm -f "$dest"
  ln -s "../../scripts/hooks/$name" "$dest"
  chmod +x "$dest"
  echo "  Installed: $dest -> scripts/hooks/$name"
  INSTALLED=$((INSTALLED + 1))
done

echo ""
echo "  Installed: $INSTALLED, Skipped: $SKIPPED"
echo "  Test: try 'git commit' on a known-bad .sh file (should block)"
echo "  Bypass: git commit --no-verify (NOT recommended)"
