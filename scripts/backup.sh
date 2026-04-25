#!/bin/zsh
# AInchors Backup Script
# Runs via cron. Backs up workspace + Obsidian vault + OpenClaw config.

TIMESTAMP=$(date +%Y-%m-%d-%H%M)
BACKUP_ROOT="$HOME/Backups/ainchors"
WORKSPACE="$HOME/.openclaw/workspace"
VAULT="$HOME/Documents/AInchors"
CONFIG="$HOME/.openclaw/openclaw.json"
LOG="$BACKUP_ROOT/logs/backup.log"
MAX_BACKUPS=30  # Keep 30 daily backups (~1 month)

mkdir -p "$BACKUP_ROOT/workspace" "$BACKUP_ROOT/obsidian" "$BACKUP_ROOT/config" "$BACKUP_ROOT/logs"

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

# 2. Git commit Obsidian vault
cd "$VAULT"
if [[ -n $(git status --porcelain) ]]; then
  git add -A
  git commit -m "chore: auto-backup $TIMESTAMP" >> "$LOG" 2>&1
  log "Obsidian vault: new changes committed"
else
  log "Obsidian vault: no changes since last commit"
fi

# 3. Snapshot workspace to timestamped tar
WORKSPACE_SNAP="$BACKUP_ROOT/workspace/workspace-$TIMESTAMP.tar.gz"
tar -czf "$WORKSPACE_SNAP" -C "$HOME/.openclaw" workspace 2>> "$LOG"
log "Workspace snapshot: $WORKSPACE_SNAP"

# 4. Snapshot Obsidian vault to timestamped tar
VAULT_SNAP="$BACKUP_ROOT/obsidian/ainchors-vault-$TIMESTAMP.tar.gz"
tar -czf "$VAULT_SNAP" --exclude=".git" -C "$HOME/Documents" AInchors 2>> "$LOG"
log "Obsidian snapshot: $VAULT_SNAP"

# 5. Backup OpenClaw config
cp "$CONFIG" "$BACKUP_ROOT/config/openclaw-$TIMESTAMP.json"
log "Config backup: openclaw-$TIMESTAMP.json"

# 6. Prune old backups (keep last MAX_BACKUPS)
for dir in "$BACKUP_ROOT/workspace" "$BACKUP_ROOT/obsidian" "$BACKUP_ROOT/config"; do
  COUNT=$(ls "$dir" | wc -l | tr -d ' ')
  if (( COUNT > MAX_BACKUPS )); then
    EXCESS=$((COUNT - MAX_BACKUPS))
    ls -t "$dir" | tail -$EXCESS | xargs -I{} rm "$dir/{}"
    log "Pruned $EXCESS old backups from $dir"
  fi
done

log "--- Backup complete: $TIMESTAMP ---"
echo ""
