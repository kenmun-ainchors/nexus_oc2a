#!/usr/bin/env bash
# nightly-gateway-restart.sh — Restart OpenClaw gateway (03:00 MYT daily)
# Created 2026-05-18 (CHG-0400)
# Updated 2026-05-19 (CHG-0411) — two-cron design: writes marker before restart,
#   post-restart verification cron (03:05) checks marker + gateway and sends Telegram.
# Updated 2026-05-19 (CHG-0416) — snapshot sessions before restart to prevent loss
#   (TKT-0234: May 18 afternoon session transcripts lost when gateway overwrote files)
# Updated 2026-06-09 (CHG-0474) — guard against dual-bind: check gateway is alive before
#   restarting. Prevents LaunchAgent + cron from spawning competing instances when
#   gateway is zombie/unresponsive (e.g. OOM — process alive but GC-crippled).
#   Root cause: Jun 9 OOM crash → LaunchAgent auto-restarted successfully at 07:29,
#   then this script's delayed restart fired at 07:36, creating a second instance.
#
# Design: this script will be killed by the gateway restart it triggers.
# The cron will report "interrupted by gateway restart" — that's EXPECTED.
# The marker file bridges the gap so the follow-up cron can verify success.

set -euo pipefail

MARKER="/Users/ainchorsoc2a/.openclaw/workspace/state/nightly-restart-marker.json"
LOG="/Users/ainchorsoc2a/Backups/ainchors/logs/nightly-restart.log"
SESSION_BACKUP_DIR="/Users/ainchorsoc2a/Backups/ainchors/sessions-pre-restart"
WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"

mkdir -p "$(dirname "$MARKER")" "$(dirname "$LOG")" "$SESSION_BACKUP_DIR"

# ── Step 0a: Lock — prevent concurrent execution ─────────────────────────
# CHG-0474: If weekly cron (Sun 02:55) and nightly cron (daily 03:00) both fire,
# the lock prevents a race. First to acquire lock wins; second exits silently.
# Uses mkdir as atomic operation (macOS-compatible; flock not available on macOS).
LOCKDIR="/tmp/openclaw-restart.lock"
if ! mkdir "$LOCKDIR" 2>/dev/null; then
    echo "[$(date -Iseconds)] ABORTING: Another restart is already in progress (lock held by $LOCKDIR)." | tee -a "$LOG"
    exit 0
fi
trap 'rm -rf "$LOCKDIR"' EXIT

# ── Step 0b: Guard — only restart if gateway is alive and responsive ────
# CHG-0474: Prevent dual-bind when LaunchAgent auto-restarts before this delayed cron.
# Check that gateway PID is healthy (not zombied) and responding on its health endpoint.
PORT=18789
HEALTH_URL="http://127.0.0.1:${PORT}/health"

if curl -s --max-time 5 "$HEALTH_URL" > /dev/null 2>&1; then
    echo "[$(date -Iseconds)] Gateway health check passed. Proceeding with restart..." | tee -a "$LOG"
else
    echo "[$(date -Iseconds)] ABORTING: Gateway not responding on port $PORT. " \
         "Likely already restarted by LaunchAgent or crashed. Nothing to do." | tee -a "$LOG"
    exit 0
fi

# ── Step 1: Snapshot all session transcripts before restart ──────────────
# CHG-0416: Prevents loss from gateway restart overwriting sessions
echo "[$(date -Iseconds)] Snapshotting session transcripts before restart..." | tee -a "$LOG"

# Create timestamped snapshot directory
SNAP_DIR="$SESSION_BACKUP_DIR/sessions-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SNAP_DIR"

# Copy all agent session directories
for agent_dir in /Users/ainchorsoc2a/.openclaw/agents/*/sessions; do
    if [[ -d "$agent_dir" ]]; then
        agent_name=$(basename "$(dirname "$agent_dir")")
        cp -r "$agent_dir" "$SNAP_DIR/$agent_name" 2>/dev/null || true
    fi
done

# Also snapshot workspace state files that could be overwritten
cp "$WORKSPACE/state/journal-write-state.json" "$SNAP_DIR/" 2>/dev/null || true
cp "$WORKSPACE/memory/journal-"*.md "$SNAP_DIR/" 2>/dev/null || true

# Record snapshot metadata
cat > "$SNAP_DIR/snapshot-meta.json" <<EOF
{
  "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "reason": "pre-restart safety snapshot",
  "cronId": "20f59555-781a-4863-a8bf-c90a088317d4",
  "chgRef": "CHG-0416"
}
EOF

echo "[$(date -Iseconds)] Snapshot saved to $SNAP_DIR ($(du -sh "$SNAP_DIR" 2>/dev/null | cut -f1))" | tee -a "$LOG"


# ── Step 1a: Retention prune — remove snapshots older than RETENTION_DAYS ──
# CHG-0767: Prevent unbounded disk growth. Prune only within SESSION_BACKUP_DIR.
RETENTION_DAYS=7
PRUNE_TARGET="$SESSION_BACKUP_DIR"
if [[ -d "$PRUNE_TARGET" ]]; then
    OLD_SNAPSHOTS=$(find "$PRUNE_TARGET" -maxdepth 1 -type d -name 'sessions-*' -mtime +$RETENTION_DAYS 2>/dev/null || true)
    OLD_COUNT=$(echo "$OLD_SNAPSHOTS" | grep -c . 2>/dev/null || echo 0)
    if [[ "$OLD_COUNT" -gt 0 ]]; then
        FREED_BYTES=$(du -sb $OLD_SNAPSHOTS 2>/dev/null | tail -1 | awk '{print $1}' || echo 0)
        echo "[$(date -Iseconds)] Pruning $OLD_COUNT snapshot(s) older than $RETENTION_DAYS days..." | tee -a "$LOG"
        echo "$OLD_SNAPSHOTS" | xargs -I{} rm -rf "{}" 2>/dev/null || true
        echo "[$(date -Iseconds)] Prune complete. Freed approximately $(echo "scale=2; $FREED_BYTES/1073741824" | bc 2>/dev/null || echo "$FREED_BYTES bytes") GB." | tee -a "$LOG"
    else
        echo "[$(date -Iseconds)] No stale snapshots to prune (all within $RETENTION_DAYS days)." | tee -a "$LOG"
    fi
fi


# ── Step 1b: Sync model context before restart ──────────────────────────
# CHG-0756: Sync model context from Ollama API and apply to config
echo "[2026-06-24T20:41:51+10:00] Syncing model context before restart..." | tee -a "$LOG"
bash "$WORKSPACE/scripts/sync-model-context.sh" >> "$LOG" 2>&1 || true
bash "$WORKSPACE/scripts/apply-model-context.sh" >> "$LOG" 2>&1 || true
echo "[2026-06-24T20:41:51+10:00] Model context sync complete." | tee -a "$LOG"


# ── Step 2: Write marker ────────────────────────────────────────────────
cat > "$MARKER" <<EOF
{
  "triggeredAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "triggeredAtMs": $(date +%s000),
  "status": "restarting",
  "cronId": "20f59555-781a-4863-a8bf-c90a088317d4",
  "snapshotDir": "$SNAP_DIR"
}
EOF

echo "[$(date -Iseconds)] Marker written. Restarting gateway..." | tee -a "$LOG"

# ── Step 3: Add snapshot to marker so verify script can check it ────────
# (verify script already checks marker exists + gateway health)

# ── Step 4: Restart (this kills this process) ───────────────────────────
echo "[$(date -Iseconds)] Gateway confirmed alive at $HEALTH_URL — now restarting..." | tee -a "$LOG"
openclaw gateway restart 2>&1 | tee -a "$LOG" || true

# We will never reach here. The follow-up cron handles verification.
echo "[$(date -Iseconds)] WARNING: Script reached post-restart — restart may have been a no-op?" | tee -a "$LOG"

