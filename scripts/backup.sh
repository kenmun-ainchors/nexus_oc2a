#!/bin/zsh
# AInchors Backup Script
# Runs via cron. Backs up workspace + OpenClaw config.
# Obsidian vault retired TKT-0042 Phase 4 — no longer backed up here.

TIMESTAMP=$(date +%Y-%m-%d-%H%M)
BACKUP_ROOT="$HOME/Backups/ainchors"
WORKSPACE="$HOME/.openclaw/workspace"
CONFIG="$HOME/.openclaw/openclaw.json"
LOG="$BACKUP_ROOT/logs/backup.log"
MAX_BACKUPS=30  # Keep 30 daily backups (~1 month)

mkdir -p "$BACKUP_ROOT/workspace" "$BACKUP_ROOT/config" "$BACKUP_ROOT/logs"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"
}

log "--- Backup started: $TIMESTAMP ---"

# 1. Git commit workspace (capture any changes since last commit)
cd "$WORKSPACE"
if [[ -n $(git status --porcelain) ]]; then
  git add -A
  git commit -m "chore: auto-backup $TIMESTAMP" >> "$LOG" 2>&1
  log "Workspace: new changes committed"
else
  log "Workspace: no changes since last commit"
fi

# 2. Snapshot workspace to timestamped tar
# Exclude auth files (S5 fix: CHG-0152 followup — prevent API keys leaking into backups)
WORKSPACE_SNAP="$BACKUP_ROOT/workspace/workspace-$TIMESTAMP.tar.gz"
tar -czf "$WORKSPACE_SNAP" \
  --exclude="workspace/.openclaw/agents/*/agent/auth-profiles.json" \
  --exclude="workspace/.openclaw/agents/*/agent/auth-state.json" \
  --exclude="workspace/**/auth-profiles*.json" \
  --exclude="workspace/**/auth-state*.json" \
  -C "$HOME/.openclaw" workspace 2>> "$LOG"
log "Workspace snapshot: $WORKSPACE_SNAP (auth files excluded)"

# 3. Backup OpenClaw config (strip auth fields before saving)
# Use python3 to scrub any authProfiles/authState keys from the config snapshot
python3 - "$CONFIG" "$BACKUP_ROOT/config/openclaw-$TIMESTAMP.json" << 'PYEOF'
import json, sys, re
src, dst = sys.argv[1], sys.argv[2]
with open(src) as f:
    data = json.load(f)
# Remove auth-sensitive keys recursively
def scrub(obj):
    if isinstance(obj, dict):
        return {k: scrub(v) for k, v in obj.items()
                if not re.match(r'auth(Profiles?|State|Key|Token|Secret)', k, re.IGNORECASE)}
    elif isinstance(obj, list):
        return [scrub(i) for i in obj]
    return obj
with open(dst, 'w') as f:
    json.dump(scrub(data), f, indent=2)
PYEOF
log "Config backup: openclaw-$TIMESTAMP.json (auth fields scrubbed)"

# 5b. iCloud offsite backup (TKT-0093 — 3-2-1+1 cloud copy)
ICLOUD_BACKUP="$HOME/Library/Mobile Documents/com~apple~CloudDocs/AInchors-Backups"
ICLOUD_MAX=7  # Keep 7 copies in iCloud (storage cost)

if [[ -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs" ]]; then
  mkdir -p "$ICLOUD_BACKUP"
  ICLOUD_DEST="$ICLOUD_BACKUP/$(basename $WORKSPACE_SNAP)"
  cp "$WORKSPACE_SNAP" "$ICLOUD_DEST" 2>> "$LOG" && log "iCloud backup: $(basename $WORKSPACE_SNAP) copied" || log "iCloud backup: FAILED to copy"
  # Prune iCloud copies (keep last ICLOUD_MAX)
  ICLOUD_COUNT=$(ls "$ICLOUD_BACKUP"/*.tar.gz 2>/dev/null | wc -l | tr -d ' ')
  if (( ICLOUD_COUNT > ICLOUD_MAX )); then
    ICLOUD_EXCESS=$((ICLOUD_COUNT - ICLOUD_MAX))
    ls -t "$ICLOUD_BACKUP"/*.tar.gz 2>/dev/null | tail -$ICLOUD_EXCESS | xargs rm -f
    log "iCloud pruned $ICLOUD_EXCESS old copies (keeping $ICLOUD_MAX)"
  fi
  CLOUD_BACKUP_ENABLED=true
else
  # TODO: iCloud not accessible — set up alternative cloud sync (rclone, S3, etc.)
  log "iCloud backup: SKIPPED — iCloud Drive not found at ~/Library/Mobile Documents/com~apple~CloudDocs"
  CLOUD_BACKUP_ENABLED=false
fi

# 6. Prune old backups (keep last MAX_BACKUPS)
for dir in "$BACKUP_ROOT/workspace" "$BACKUP_ROOT/config"; do
  COUNT=$(ls "$dir" | wc -l | tr -d ' ')
  if (( COUNT > MAX_BACKUPS )); then
    EXCESS=$((COUNT - MAX_BACKUPS))
    ls -t "$dir" | tail -$EXCESS | xargs -I{} rm "$dir/{}"
    log "Pruned $EXCESS old backups from $dir"
  fi
done

log "--- Backup complete: $TIMESTAMP ---"
echo ""

# 7. Write backup state file (TKT-0093 format — for heartbeat + auto-heal checks)
STATE_FILE="$HOME/.openclaw/workspace/state/backup-state.json"
WS_SNAP_BASENAME=$(basename "$WORKSPACE_SNAP")
CONFIG_SNAP_BASENAME=$(basename "$BACKUP_ROOT/config/openclaw-$TIMESTAMP.json")
BACKUP_COUNT=$(ls "$BACKUP_ROOT/workspace"/*.tar.gz 2>/dev/null | wc -l | tr -d ' ')
SIZE_BYTES=$(stat -f%z "$WORKSPACE_SNAP" 2>/dev/null || echo 0)

python3 -c "
import json, os
state = {
    'lastBackup': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'status': 'ok',
    'location': '$BACKUP_ROOT',
    'lastWorkspaceSnap': '$WS_SNAP_BASENAME',
    'lastConfigSnap': '$CONFIG_SNAP_BASENAME',
    'nasConnected': False,
    'cloudBackupEnabled': ${CLOUD_BACKUP_ENABLED:-false},
    'sizeBytes': $SIZE_BYTES,
    'backupCount': $BACKUP_COUNT
}
with open('$STATE_FILE', 'w') as f:
    json.dump(state, f, indent=2)
"
log "State file written: $STATE_FILE"
