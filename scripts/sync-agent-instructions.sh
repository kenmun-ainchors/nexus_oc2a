#!/usr/bin/env zsh
# sync-agent-instructions.sh
# Single-source-of-truth (SSOT) sync for per-agent instruction files.
#
# For every agent in ~/.openclaw/openclaw.json (except main), ensure
# ~/.openclaw/workspace/agents/<id>/ exists and contains symlinks to the
# canonical instruction files from the agent's workspace-<name>/ directory:
#   AGENTS.md, SOUL.md, USER.md, TOOLS.md
#
# Runtime-only files (DREAMS.md, HEARTBEAT.md, memory/, state/) in
# workspace/agents/<id>/ are preserved if they already exist; they are NOT
# overwritten or removed by this script.
#
# CHG-0832 / SSOT Phase 1.
set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsoc2a/.openclaw/workspace}"
OPENCLAW_CONFIG="${OPENCLAW_CONFIG:-/Users/ainchorsoc2a/.openclaw/openclaw.json}"
AGENTS_DIR="${WORKSPACE_ROOT}/agents"
DRY_RUN=false
FIX=false

INSTRUCTION_FILES=(AGENTS.md SOUL.md USER.md TOOLS.md)
PRESERVE_PATTERNS=(DREAMS.md HEARTBEAT.md memory state)

usage() {
  cat <<EOF
Usage: zsh scripts/sync-agent-instructions.sh [options]

Options:
  --dry-run    Show what would be created/changed without touching the filesystem.
  --fix        Apply changes (create directories, update symlinks).
  --help, -h   Show this help.

Examples:
  zsh scripts/sync-agent-instructions.sh --dry-run
  zsh scripts/sync-agent-instructions.sh --fix
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --fix)     FIX=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "❌ Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "$DRY_RUN" == "false" && "$FIX" == "false" ]]; then
  echo "❌ No action specified. Use --dry-run or --fix." >&2
  usage >&2
  exit 1
fi

if [[ ! -f "$OPENCLAW_CONFIG" ]]; then
  echo "❌ openclaw.json not found: $OPENCLAW_CONFIG" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "❌ jq is required but not installed" >&2
  exit 1
fi

aesthetic_now() {
  TZ=Australia/Melbourne date '+%Y-%m-%dT%H:%M:%S%z'
}

NOW=$(aesthetic_now)

changes=()
warnings=()
unchanged=()

while IFS=$'\t' read -r aid ws_path _name; do
  [[ -z "$aid" ]] && continue
  [[ "$aid" == "main" ]] && continue

  if [[ "$ws_path" != /* ]]; then
    ws_path="${WORKSPACE_ROOT}/${ws_path}"
  fi

  target_dir="${AGENTS_DIR}/${aid}"

  # Ensure target directory exists (unless dry-run)
  if [[ ! -d "$target_dir" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      changes+=("would create directory: ${target_dir}")
    else
      mkdir -p "$target_dir"
      changes+=("created directory: ${target_dir}")
    fi
  fi

  for file in "${INSTRUCTION_FILES[@]}"; do
    src="${ws_path}/${file}"
    dst="${target_dir}/${file}"

    if [[ ! -f "$src" ]]; then
      warnings+=("source missing for ${aid}: ${src}")
      # Remove stale symlink if target source no longer exists
      if [[ -L "$dst" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
          changes+=("would remove stale symlink: ${dst}")
        else
          rm "$dst"
          changes+=("removed stale symlink: ${dst}")
        fi
      fi
      continue
    fi

    # Create or update symlink to point at the current source
    src_rel="$(realpath --relative-to="$target_dir" "$src" 2>/dev/null || true)"
    if [[ -z "$src_rel" ]]; then
      # Fallback to absolute symlink if relative path fails
      src_rel="$src"
    fi

    if [[ -L "$dst" ]]; then
      current_target="$(readlink "$dst" 2>/dev/null || true)"
      if [[ "$current_target" != "$src_rel" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
          changes+=("would update symlink: ${dst} → ${src_rel} (currently → ${current_target})")
        else
          ln -sfn "$src_rel" "$dst"
          changes+=("updated symlink: ${dst} → ${src_rel}")
        fi
      else
        unchanged+=("symlink OK: ${dst} → ${src_rel}")
      fi
    elif [[ -e "$dst" ]]; then
      # A regular file (or other non-symlink) exists where the symlink should be.
      # Back it up and replace with the canonical symlink toward SSOT.
      backup_name="${dst}.localbackup.$(date +%Y%m%d%H%M%S)"
      if [[ "$DRY_RUN" == "true" ]]; then
        changes+=("would back up existing file: ${dst} → ${backup_name}, then symlink → ${src_rel}")
      else
        mv "$dst" "$backup_name"
        ln -s "$src_rel" "$dst"
        changes+=("backed up existing file: ${dst} → ${backup_name}, created symlink → ${src_rel}")
      fi
    else
      if [[ "$DRY_RUN" == "true" ]]; then
        changes+=("would create symlink: ${dst} → ${src_rel}")
      else
        ln -s "$src_rel" "$dst"
        changes+=("created symlink: ${dst} → ${src_rel}")
      fi
    fi
  done

  # Preserve runtime-only files if they already exist
  for pattern in "${PRESERVE_PATTERNS[@]}"; do
    runtime_item="${target_dir}/${pattern}"
    if [[ -e "$runtime_item" ]]; then
      unchanged+=("preserved runtime file: ${runtime_item}")
    fi
  done
done < <(jq -r '.agents.list[] | [.id, .workspace, .name] | @tsv' "$OPENCLAW_CONFIG")

# Report
cat <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  sync-agent-instructions — ${DRY_RUN:+dry-run}${FIX:+fix} @ ${NOW}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

if (( ${#changes[@]} > 0 )); then
  echo ""
  echo "Changes (${#changes[@]}):"
  for c in "${changes[@]}"; do echo "  • $c"; done
else
  echo ""
  echo "No changes needed."
fi

if (( ${#warnings[@]} > 0 )); then
  echo ""
  echo "Warnings (${#warnings[@]}):"
  for w in "${warnings[@]}"; do echo "  ⚠️ $w"; done
fi

if (( ${#unchanged[@]} > 0 )); then
  echo ""
  echo "Unchanged / preserved (${#unchanged[@]}):"
  for u in "${unchanged[@]}"; do echo "  ✓ $u"; done
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$DRY_RUN" == "true" ]]; then
  if (( ${#changes[@]} > 0 )); then
    echo "  Dry-run complete. Use --fix to apply the ${#changes[@]} change(s) above."
    exit 0
  else
    echo "  Dry-run complete. Nothing to change."
    exit 0
  fi
fi

if (( ${#changes[@]} > 0 )); then
  echo "  ✅ Sync complete: ${#changes[@]} change(s) applied."
  exit 0
else
  echo "  ✅ Sync complete: nothing to do."
  exit 0
fi
