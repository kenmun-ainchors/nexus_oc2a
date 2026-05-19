#!/usr/bin/env bash
# nightly-gateway-restart.sh — Restart OpenClaw gateway (03:00 AEST daily)
# Created 2026-05-18 (CHG-0400)
# Updated 2026-05-19 (CHG-0411) — two-cron design: writes marker before restart,
#   post-restart verification cron (03:05) checks marker + gateway and sends Telegram.
# Updated 2026-05-19 (CHG-0416) — snapshot sessions before restart to prevent loss
#   (TKT-0234: May 18 afternoon session transcripts lost when gateway overwrote files)
#
# Design: this script will be killed by the gateway restart it triggers.
# The cron will report "interrupted by gateway restart" — that's EXPECTED.
# The marker file bridges the gap so the follow-up cron can verify success.

set -euo pipefail

MARKER="/Users/ainchorsangiefpl/.openclaw/workspace/state/nightly-restart-marker.json"
LOG="/Users/ainchorsangiefpl/Backups/ainchors/logs/nightly-restart.log"
SESSION_BACKUP_DIR="/Users/ainchorsangiefpl/Backups/ainchors/sessions-pre-restart"
WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"

mkdir -p "$(dirname "$MARKER")" "$(dirname "$LOG")" "$SESSION_BACKUP_DIR"

# ── Step 1: Snapshot all session transcripts before restart ──────────────
# CHG-0416: Prevents loss from gateway restart overwriting sessions
echo "[$(date -Iseconds)] Snapshotting session transcripts before restart..." | tee -a "$LOG"

# Create timestamped snapshot directory
SNAP_DIR="$SESSION_BACKUP_DIR/sessions-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SNAP_DIR"

# Copy all agent session directories
for agent_dir in /Users/ainchorsangiefpl/.openclaw/agents/*/sessions; do
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
openclaw gateway restart 2>&1 | tee -a "$LOG" || true

# We will never reach here. The follow-up cron handles verification.
echo "[$(date -Iseconds)] WARNING: Script reached post-restart — restart may have been a no-op?" | tee -a "$LOG"
