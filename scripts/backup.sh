#!/bin/zsh
# AInchors Backup Script — TKT-0146 incremental optimisation
# Strategy: incremental daily (rsync --link-dest) + full tar.gz weekly (Sunday)
# Obsidian vault retired TKT-0042 Phase 4 — no longer backed up.

TIMESTAMP=$(date +%Y-%m-%d-%H%M)
DOW=$(date +%u)  # 1=Monday, 7=Sunday
BACKUP_ROOT="$HOME/Backups/ainchors"
WORKSPACE="$HOME/.openclaw/workspace"
CONFIG="$HOME/.openclaw/openclaw.json"
LOG="$BACKUP_ROOT/logs/backup.log"

# Retention: 7 daily incrementals + 4 weekly fulls
MAX_INCREMENTAL=7
MAX_FULL=4
MAX_CONFIG=14

mkdir -p "$BACKUP_ROOT/workspace-incremental" "$BACKUP_ROOT/workspace-full" \
         "$BACKUP_ROOT/config" "$BACKUP_ROOT/logs"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"
}

log "--- Backup started: $TIMESTAMP (DOW=$DOW) ---"

# ── Step 1: Git commit workspace ──────────────────────────────────────────────
cd "$WORKSPACE"
if [[ -n $(git status --porcelain) ]]; then
  git add -A
  git commit -m "chore: auto-backup $TIMESTAMP" >> "$LOG" 2>&1
  log "Workspace: new changes committed"
else
  log "Workspace: no changes since last commit"
fi

# ── Step 2a: Full backup on Sunday (DOW=7) ────────────────────────────────────
if [[ "$DOW" == "7" ]]; then
  log "FULL backup (Sunday)"
  FULL_SNAP="$BACKUP_ROOT/workspace-full/workspace-full-$TIMESTAMP.tar.gz"
  tar -czf "$FULL_SNAP" \
    --exclude=".openclaw/agents/*/agent/auth-profiles.json" \
    --exclude=".openclaw/agents/*/agent/auth-state.json" \
    --exclude="**auth-profiles*.json" \
    --exclude="**auth-state*.json" \
    -C "$HOME/.openclaw" workspace 2>> "$LOG"
  log "Full snapshot: $FULL_SNAP ($(du -sh "$FULL_SNAP" | cut -f1))"

  # Prune old full backups
  FULL_COUNT=$(ls "$BACKUP_ROOT/workspace-full/"*.tar.gz 2>/dev/null | wc -l | tr -d ' ')
  if (( FULL_COUNT > MAX_FULL )); then
    EXCESS=$((FULL_COUNT - MAX_FULL))
    ls -t "$BACKUP_ROOT/workspace-full/"*.tar.gz | tail -$EXCESS | xargs rm -f
    log "Pruned $EXCESS old full backups (keeping $MAX_FULL)"
  fi
  BACKUP_TYPE="full"
  BACKUP_SNAP="$FULL_SNAP"

# ── Step 2b: Incremental backup Mon-Sat (rsync --link-dest) ───────────────────
else
  log "INCREMENTAL backup (Mon-Sat)"
  INCR_DEST="$BACKUP_ROOT/workspace-incremental/workspace-$TIMESTAMP"

  # Find the most recent incremental or full snapshot to link against
  PREV_INCR=$(ls -dt "$BACKUP_ROOT/workspace-incremental/workspace-"* 2>/dev/null | head -1)
  PREV_FULL_TAR=$(ls -t "$BACKUP_ROOT/workspace-full/"*.tar.gz 2>/dev/null | head -1)

  if [[ -n "$PREV_INCR" ]]; then
    LINK_DEST="$PREV_INCR"
    log "Linking against previous incremental: $(basename $LINK_DEST)"
  else
    # No previous incremental — this is the first run, do a full rsync without link-dest
    log "No previous incremental found — running first full rsync"
    LINK_DEST=""
  fi

  mkdir -p "$INCR_DEST"

  if [[ -n "$LINK_DEST" ]]; then
    rsync -a \
      --link-dest="$LINK_DEST/" \
      --exclude="agents/*/agent/auth-profiles.json" \
      --exclude="agents/*/agent/auth-state.json" \
      --exclude="**auth-profiles*.json" \
      --exclude="**auth-state*.json" \
      "$HOME/.openclaw/workspace/" \
      "$INCR_DEST/" >> "$LOG" 2>&1
  else
    rsync -a \
      --exclude="agents/*/agent/auth-profiles.json" \
      --exclude="agents/*/agent/auth-state.json" \
      --exclude="**auth-profiles*.json" \
      --exclude="**auth-state*.json" \
      "$HOME/.openclaw/workspace/" \
      "$INCR_DEST/" >> "$LOG" 2>&1
  fi

  INCR_SIZE=$(du -sh "$INCR_DEST" 2>/dev/null | cut -f1)
  log "Incremental snapshot: $INCR_DEST ($INCR_SIZE apparent, hard-links reduce actual usage)"

  # Prune old incrementals
  INCR_COUNT=$(ls -d "$BACKUP_ROOT/workspace-incremental/workspace-"* 2>/dev/null | wc -l | tr -d ' ')
  if (( INCR_COUNT > MAX_INCREMENTAL )); then
    EXCESS=$((INCR_COUNT - MAX_INCREMENTAL))
    ls -dt "$BACKUP_ROOT/workspace-incremental/workspace-"* | tail -$EXCESS | xargs rm -rf
    log "Pruned $EXCESS old incrementals (keeping $MAX_INCREMENTAL)"
  fi
  BACKUP_TYPE="incremental"
  BACKUP_SNAP="$INCR_DEST"
fi

# ── Step 3: Config backup (daily, auth scrubbed) ──────────────────────────────
/usr/bin/python3 - "$CONFIG" "$BACKUP_ROOT/config/openclaw-$TIMESTAMP.json" << 'PYEOF'
import json, sys, re
src, dst = sys.argv[1], sys.argv[2]
with open(src) as f:
    data = json.load(f)
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

# Prune old config backups
CONFIG_COUNT=$(ls "$BACKUP_ROOT/config/"*.json 2>/dev/null | wc -l | tr -d ' ')
if (( CONFIG_COUNT > MAX_CONFIG )); then
  EXCESS=$((CONFIG_COUNT - MAX_CONFIG))
  ls -t "$BACKUP_ROOT/config/"*.json | tail -$EXCESS | xargs rm -f
  log "Pruned $EXCESS old config backups (keeping $MAX_CONFIG)"
fi

# ── Step 4: iCloud offsite (workspace-full only on Sunday) ───────────────────
ICLOUD_BACKUP="$HOME/Library/Mobile Documents/com~apple~CloudDocs/AInchors-Backups"
ICLOUD_MAX=4
CLOUD_BACKUP_ENABLED=false

if [[ "$DOW" == "7" && -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs" ]]; then
  mkdir -p "$ICLOUD_BACKUP"
  ICLOUD_DEST="$ICLOUD_BACKUP/$(basename $FULL_SNAP)"
  cp "$FULL_SNAP" "$ICLOUD_DEST" 2>> "$LOG" && {
    log "iCloud backup: $(basename $FULL_SNAP) copied"
    CLOUD_BACKUP_ENABLED=true
  } || log "iCloud backup: FAILED"
  # Prune iCloud
  ICLOUD_COUNT=$(ls "$ICLOUD_BACKUP"/*.tar.gz 2>/dev/null | wc -l | tr -d ' ')
  if (( ICLOUD_COUNT > ICLOUD_MAX )); then
    ls -t "$ICLOUD_BACKUP"/*.tar.gz | tail -$((ICLOUD_COUNT - ICLOUD_MAX)) | xargs rm -f
    log "iCloud pruned to $ICLOUD_MAX copies"
  fi
elif [[ "$DOW" != "7" ]]; then
  log "iCloud backup: skipped (incremental day — iCloud only on full/Sunday)"
else
  log "iCloud backup: skipped — iCloud Drive not found"
fi

# ── Step 5: Write state file ──────────────────────────────────────────────────
STATE_FILE="$WORKSPACE/state/backup-state.json"
CLOUD_FLAG="False"
[[ "$CLOUD_BACKUP_ENABLED" == "true" ]] && CLOUD_FLAG="True"

/usr/bin/python3 -c "
import json
state = {
    'lastBackup': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'status': 'ok',
    'backupType': '$BACKUP_TYPE',
    'location': '$BACKUP_ROOT',
    'lastSnap': '$(basename $BACKUP_SNAP)',
    'nasConnected': False,
    'cloudBackupEnabled': $CLOUD_FLAG,
    'schedule': 'incremental Mon-Sat (rsync --link-dest), full Sun (tar.gz)'
}
with open('$STATE_FILE', 'w') as f:
    json.dump(state, f, indent=2)
"

log "--- Backup complete: $TIMESTAMP ($BACKUP_TYPE) ---"
echo ""
