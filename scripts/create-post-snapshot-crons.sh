#!/usr/bin/env zsh
# create-post-snapshot-crons.sh — Create 24h, 48h, and 7d snapshot crons for a LinkedIn post.
#
# Usage:
#   create-post-snapshot-crons.sh --content-id LI-W1-P1 --post-urn urn:li:activity:... --posted-at 2026-05-05T21:52:00Z
#
# Creates 3 agentTurn crons (24h / 48h / 7d) that call linkedin-metrics-snapshot.sh.
# 6h snapshot is assumed to be created manually at post time (as per Spark workflow).
# Each cron: deleteAfterRun=true, model=anthropic/claude-haiku-4-5

set -euo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
SNAPSHOT_SCRIPT="$WORKSPACE/scripts/linkedin-metrics-snapshot.sh"

# ── Parse args ────────────────────────────────────────────────────────────────

CONTENT_ID=""
POST_URN=""
POSTED_AT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --content-id)
      CONTENT_ID="$2"
      shift 2
      ;;
    --post-urn)
      POST_URN="$2"
      shift 2
      ;;
    --posted-at)
      POSTED_AT="$2"
      shift 2
      ;;
    *)
      echo "❌ Unknown argument: $1" >&2
      echo "Usage: create-post-snapshot-crons.sh --content-id ID --post-urn URN --posted-at ISO_TIMESTAMP" >&2
      exit 1
      ;;
  esac
done

[[ -z "$CONTENT_ID" ]] && { echo "❌ --content-id is required." >&2; exit 1; }
[[ -z "$POST_URN" ]]   && { echo "❌ --post-urn is required." >&2; exit 1; }
[[ -z "$POSTED_AT" ]]  && { echo "❌ --posted-at is required (ISO UTC, e.g. 2026-05-05T21:52:00Z)." >&2; exit 1; }

# ── Compute fire times ────────────────────────────────────────────────────────

python3 - <<PYEOF
from datetime import datetime, timezone, timedelta

posted_at_str = "$POSTED_AT"
content_id    = "$CONTENT_ID"
post_urn      = "$POST_URN"

# Parse posted_at (handle Z suffix)
posted_at = datetime.fromisoformat(posted_at_str.replace("Z", "+00:00"))

intervals = {
    "24h": timedelta(hours=24),
    "48h": timedelta(hours=48),
    "7d":  timedelta(days=7),
}

print("Computed fire times:")
for label, delta in intervals.items():
    fire_time = posted_at + delta
    print(f"  {label}: {fire_time.strftime('%Y-%m-%dT%H:%M:%SZ')}")
PYEOF

echo ""
echo "⏱  Creating snapshot crons for $CONTENT_ID..."
echo ""

# ── Create crons via openclaw cron tool (called by agent) ─────────────────────
# This script is designed to be called by an agent (Spark or Yoda) after posting.
# The agent reads the output and creates each cron using the cron tool.
#
# Output format (parseable by agent):
#   CRON_SPEC|fire_at|interval|payload

python3 - <<PYEOF
from datetime import datetime, timezone, timedelta
import sys

posted_at_str = "$POSTED_AT"
content_id    = "$CONTENT_ID"
post_urn      = "$POST_URN"
snapshot_script = "$SNAPSHOT_SCRIPT"

posted_at = datetime.fromisoformat(posted_at_str.replace("Z", "+00:00"))

intervals = [
    ("24h", timedelta(hours=24)),
    ("48h", timedelta(hours=48)),
    ("7d",  timedelta(days=7)),
]

print("CRON_SPECS_BEGIN")
for label, delta in intervals:
    fire_time = posted_at + delta
    fire_iso  = fire_time.strftime("%Y-%m-%dT%H:%M:%SZ")
    payload   = f"Run: zsh {snapshot_script} --content-id {content_id} --post-urn {post_urn} --interval {label} then confirm done."
    print(f"{label}|{fire_iso}|{payload}")
print("CRON_SPECS_END")
PYEOF

echo ""
echo "✅ Cron specs generated. Agent should create each cron using the cron tool with:"
echo "   - type: agentTurn"
echo "   - deleteAfterRun: true"
echo "   - model: ollama/deepseek-v4-pro:cloud"
echo ""
echo "   OR run the following openclaw cron add commands:"
echo ""

python3 - <<PYEOF
from datetime import datetime, timezone, timedelta

posted_at_str = "$POSTED_AT"
content_id    = "$CONTENT_ID"
post_urn      = "$POST_URN"
snapshot_script = "$SNAPSHOT_SCRIPT"

posted_at = datetime.fromisoformat(posted_at_str.replace("Z", "+00:00"))

intervals = [
    ("24h", timedelta(hours=24)),
    ("48h", timedelta(hours=48)),
    ("7d",  timedelta(days=7)),
]

for label, delta in intervals:
    fire_time = posted_at + delta
    fire_iso  = fire_time.strftime("%Y-%m-%dT%H:%M:%SZ")
    payload   = f"Run: zsh {snapshot_script} --content-id {content_id} --post-urn {post_urn} --interval {label} then confirm done."
    print(f'openclaw cron add --type agentTurn --fire-at "{fire_iso}" --model "ollama/deepseek-v4-pro:cloud" --delete-after-run --label "{content_id}-snapshot-{label}" --payload "{payload}"')
    print()
PYEOF
