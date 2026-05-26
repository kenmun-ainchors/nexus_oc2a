#!/bin/bash
# gateway-restore.sh — AInchors Gateway Config Restore Tool
# Usage:
#   bash scripts/gateway-restore.sh              # restore latest snapshot
#   bash scripts/gateway-restore.sh --date YYYY-MM-DD  # specific date
#   bash scripts/gateway-restore.sh --yes        # skip confirmation
#   bash scripts/gateway-restore.sh --list       # list available snapshots
#   bash scripts/gateway-restore.sh --snapshot   # take a new snapshot of current config
#
# Owned by: Yoda (AI Ops Agent)
# Last updated: 2026-04-27

set -euo pipefail

BACKUP_BASE="$HOME/.openclaw/workspace/backups/gateway-config"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
ROLLBACK_DIR="/tmp/gateway-restore-rollback-$TIMESTAMP"
YES=false
DATE_ARG=""
SNAPSHOT_MODE=false
LIST_MODE=false

# ── Parse args ──────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)      YES=true; shift ;;
    --date)     DATE_ARG="$2"; shift 2 ;;
    --snapshot) SNAPSHOT_MODE=true; shift ;;
    --list)     LIST_MODE=true; shift ;;
    *) echo "❌ Unknown argument: $1"; exit 1 ;;
  esac
done

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

log()  { echo -e "${CYAN}[restore]${NC} $*"; }
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
err()  { echo -e "${RED}❌${NC} $*"; }

# ── List mode ────────────────────────────────────────────────────────────────
if $LIST_MODE; then
  echo ""
  echo "Available gateway config snapshots:"
  echo "────────────────────────────────────"
  if [ -d "$BACKUP_BASE" ]; then
    for d in "$BACKUP_BASE"/*/; do
      dname=$(basename "$d")
      manifest="$d/manifest.json"
      if [ -f "$manifest" ]; then
        ts=$(python3 -c "import json; d=json.load(open('$manifest')); print(d.get('snapshot_timestamp','?'))" 2>/dev/null || echo "?")
        count=$(python3 -c "import json; d=json.load(open('$manifest')); print(len([f for f in d['files'] if f.get('status')=='ok']))" 2>/dev/null || echo "?")
        echo "  $dname  (taken: $ts, files: $count)"
      else
        echo "  $dname  (no manifest)"
      fi
    done
  else
    echo "  No snapshots found at $BACKUP_BASE"
  fi
  echo ""
  exit 0
fi

# ── Snapshot mode ─────────────────────────────────────────────────────────────
if $SNAPSHOT_MODE; then
  TODAY=$(date +%Y-%m-%d)
  SNAP_DIR="$BACKUP_BASE/$TODAY"
  mkdir -p "$SNAP_DIR"
  log "Taking config snapshot → $SNAP_DIR"

  SOURCES=(
    "$HOME/.openclaw/openclaw.json"
    "$HOME/.openclaw/agents/main/agent/auth-profiles.json"
    "$HOME/.openclaw/agents/business/agent/auth-profiles.json"
    "$HOME/.openclaw/agents/security/agent/auth-profiles.json"
    "$HOME/.openclaw/agents/legal/agent/auth-profiles.json"
    "$HOME/.openclaw/agents/qa/agent/auth-profiles.json"
    "$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist"
    "$HOME/.openclaw/workspace/state/critical-config-baseline.json"
    # Note: baseline is also in PG (state_config_baseline) — file is the restore target
  )

  python3 - "$SNAP_DIR" "${SOURCES[@]}" <<'PYEOF'
import json, hashlib, os, sys
from datetime import datetime, timezone

snap_dir = sys.argv[1]
sources = sys.argv[2:]
home = os.path.expanduser("~")
timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
today = datetime.now().strftime("%Y-%m-%d")
entries = []

for src in sources:
    rel = src.replace(home + "/", "")
    dest_fname = rel.replace("/", "__")
    dest_path = os.path.join(snap_dir, dest_fname)
    if os.path.exists(src):
        with open(src, "rb") as f:
            data = f.read()
        sha256 = hashlib.sha256(data).hexdigest()
        with open(dest_path, "wb") as f:
            f.write(data)
        print(f"  ✓ {src}")
        entries.append({"file": dest_fname, "source": src, "sha256": sha256, "timestamp": timestamp, "status": "ok"})
    else:
        print(f"  ⚠ MISSING: {src}")
        entries.append({"file": None, "source": src, "sha256": None, "timestamp": timestamp, "status": "missing"})

manifest = {"snapshot_date": today, "snapshot_timestamp": timestamp, "snapshot_dir": snap_dir, "files": entries}
with open(os.path.join(snap_dir, "manifest.json"), "w") as f:
    json.dump(manifest, f, indent=2)
print(f"\n✓ Manifest written: {snap_dir}/manifest.json")
PYEOF

  ok "Snapshot complete: $SNAP_DIR"
  exit 0
fi

# ── Find snapshot dir ─────────────────────────────────────────────────────────
if [ -n "$DATE_ARG" ]; then
  SNAP_DIR="$BACKUP_BASE/$DATE_ARG"
  if [ ! -d "$SNAP_DIR" ]; then
    err "No snapshot found for date: $DATE_ARG"
    echo "Run with --list to see available snapshots."
    exit 1
  fi
else
  # Find latest
  SNAP_DIR=$(ls -d "$BACKUP_BASE"/*/ 2>/dev/null | sort -r | head -1)
  if [ -z "$SNAP_DIR" ]; then
    err "No snapshots found at $BACKUP_BASE"
    exit 1
  fi
  SNAP_DIR="${SNAP_DIR%/}"
fi

MANIFEST="$SNAP_DIR/manifest.json"
if [ ! -f "$MANIFEST" ]; then
  err "No manifest.json found in $SNAP_DIR"
  exit 1
fi

SNAP_DATE=$(basename "$SNAP_DIR")
log "Using snapshot: $SNAP_DATE ($SNAP_DIR)"

# ── Build file mapping from manifest ─────────────────────────────────────────
python3 - "$MANIFEST" "$SNAP_DIR" <<'PYEOF' > /tmp/gateway-restore-filemap-$$.txt
import json, sys
manifest_path, snap_dir = sys.argv[1], sys.argv[2]
with open(manifest_path) as f:
    manifest = json.load(f)
for entry in manifest["files"]:
    if entry.get("status") == "ok" and entry.get("file"):
        dest = f"{snap_dir}/{entry['file']}"
        print(f"{entry['source']}||{dest}||{entry['sha256']}")
PYEOF
FILEMAP="/tmp/gateway-restore-filemap-$$.txt"

# ── Show diff summary ─────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════"
echo "  Gateway Config Restore — Diff Summary"
echo "  Snapshot: $SNAP_DATE"
echo "══════════════════════════════════════════════"

CHANGES=0
while IFS='||' read -r src_path snap_file sha256; do
  if [ -f "$src_path" ]; then
    current_hash=$(shasum -a 256 "$src_path" | awk '{print $1}')
    if [ "$current_hash" = "$sha256" ]; then
      echo "  UNCHANGED  $(basename "$src_path")"
    else
      echo "  CHANGED    $(basename "$src_path")  (current differs from snapshot)"
      CHANGES=$((CHANGES + 1))
    fi
  else
    echo "  MISSING    $(basename "$src_path")  (will be restored from snapshot)"
    CHANGES=$((CHANGES + 1))
  fi
done < "$FILEMAP"

echo ""
echo "  $CHANGES file(s) will be updated"
echo "  Rollback backup: $ROLLBACK_DIR"
echo "══════════════════════════════════════════════"
echo ""

# ── Confirmation ──────────────────────────────────────────────────────────────
if ! $YES; then
  read -r -p "Proceed with restore? [y/N] " CONFIRM
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    rm -f "$FILEMAP"
    exit 0
  fi
fi

# ── Stop gateway ──────────────────────────────────────────────────────────────
log "Stopping gateway..."
openclaw gateway stop 2>/dev/null || true
sleep 2

# ── Backup current files → rollback dir ──────────────────────────────────────
log "Backing up current files → $ROLLBACK_DIR"
mkdir -p "$ROLLBACK_DIR"

while IFS='||' read -r src_path snap_file sha256; do
  if [ -f "$src_path" ]; then
    rel=$(echo "$src_path" | sed "s|$HOME/||")
    rb_dest="$ROLLBACK_DIR/${rel//\//__}"
    cp "$src_path" "$rb_dest"
    ok "Backed up: $(basename "$src_path")"
  fi
done < "$FILEMAP"

# ── Restore files ──────────────────────────────────────────────────────────────
log "Restoring files from snapshot..."
RESTORE_ERRORS=0

while IFS='||' read -r src_path snap_file sha256; do
  if [ -f "$snap_file" ]; then
    # Ensure parent dir exists
    mkdir -p "$(dirname "$src_path")"
    cp "$snap_file" "$src_path"
    verify_hash=$(shasum -a 256 "$src_path" | awk '{print $1}')
    if [ "$verify_hash" = "$sha256" ]; then
      ok "Restored: $(basename "$src_path")"
    else
      err "Hash mismatch after restore: $(basename "$src_path")"
      RESTORE_ERRORS=$((RESTORE_ERRORS + 1))
    fi
  else
    err "Snapshot file missing: $snap_file"
    RESTORE_ERRORS=$((RESTORE_ERRORS + 1))
  fi
done < "$FILEMAP"

# ── Reload LaunchAgent ────────────────────────────────────────────────────────
PLIST="$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist"
if [ -f "$PLIST" ]; then
  log "Reloading LaunchAgent..."
  launchctl unload "$PLIST" 2>/dev/null || true
  sleep 1
  launchctl load "$PLIST" 2>/dev/null || true
  ok "LaunchAgent reloaded"
fi

# ── Start gateway ──────────────────────────────────────────────────────────────
log "Starting gateway..."
openclaw gateway start 2>/dev/null || true

# ── Wait for connectivity (up to 15s) ────────────────────────────────────────
log "Waiting for gateway connectivity (up to 15s)..."
CONNECTED=false
for i in $(seq 1 15); do
  sleep 1
  STATUS=$(openclaw gateway status 2>/dev/null | grep -i "connectivity" || true)
  if echo "$STATUS" | grep -qi "ok\|connected\|running"; then
    CONNECTED=true
    break
  fi
done

# ── Verify Telegram bots ──────────────────────────────────────────────────────
PROBE_OK=false
if $CONNECTED; then
  log "Running channel probe..."
  PROBE_OUT=$(openclaw channels status --probe 2>&1 || true)
  if echo "$PROBE_OUT" | grep -qi "ok\|connected\|online"; then
    PROBE_OK=true
  fi
fi

# ── Final report ──────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════"
if $CONNECTED && [ $RESTORE_ERRORS -eq 0 ]; then
  echo -e "  ${GREEN}RESTORED OK${NC}"
  ok "Gateway connectivity: OK"
  if $PROBE_OK; then
    ok "Telegram bots: Connected"
  else
    warn "Telegram probe: Could not confirm (check manually)"
    echo "    Run: openclaw channels status --probe"
  fi
else
  echo -e "  ${RED}RESTORED FAILED${NC}"
  if ! $CONNECTED; then
    err "Gateway did not connect within 15s"
  fi
  if [ $RESTORE_ERRORS -gt 0 ]; then
    err "$RESTORE_ERRORS file(s) failed to restore"
  fi
  echo ""
  echo "  ── Rollback command ──"
  echo "  To undo this restore, run:"
  echo ""
  echo "    bash $HOME/.openclaw/workspace/scripts/gateway-restore-rollback.sh $ROLLBACK_DIR"
  echo ""
  echo "  Or manually copy files from: $ROLLBACK_DIR"
fi
echo ""
echo "  Run PVT: bash $HOME/.openclaw/workspace/scripts/pvt.sh"
echo "══════════════════════════════════════════════"

rm -f "$FILEMAP"

$CONNECTED && [ $RESTORE_ERRORS -eq 0 ]
