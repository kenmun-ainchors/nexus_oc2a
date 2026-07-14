#!/usr/bin/env zsh
# linkedin-metrics-snapshot.sh — Fetch metrics for a LinkedIn post and append to state/linkedin-metrics.json
#
# CHG-0743: Added --account argument. Passed through to linkedin-metrics.sh.
#
# Usage:
#   linkedin-metrics-snapshot.sh --content-id LI-W1-P1 --post-urn urn:li:activity:... --interval 24h [--account ken|angie|business]
#
# Intervals: 6h, 24h, 48h, 7d (or any label)
# Appends a new snapshot entry to the matching post in state/linkedin-metrics.json.
# If the post does not exist in state, it creates a new entry.

set -euo pipefail

WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
METRICS_STATE="$WORKSPACE/state/linkedin-metrics.json"
METRICS_SCRIPT="$WORKSPACE/scripts/linkedin-metrics.sh"

# ── Parse args ────────────────────────────────────────────────────────────────

CONTENT_ID=""
POST_URN=""
INTERVAL=""
ACCOUNT=""

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
    --interval)
      INTERVAL="$2"
      shift 2
      ;;
    --account)
      ACCOUNT="$2"
      shift 2
      ;;
    *)
      echo "❌ Unknown argument: $1" >&2
      echo "Usage: linkedin-metrics-snapshot.sh --content-id ID --post-urn URN --interval LABEL [--account ken|angie|business]" >&2
      exit 1
      ;;
  esac
done

# ── Validate required args ────────────────────────────────────────────────────

[[ -z "$CONTENT_ID" ]] && { echo "❌ --content-id is required." >&2; exit 1; }
[[ -z "$POST_URN" ]]   && { echo "❌ --post-urn is required." >&2; exit 1; }
[[ -z "$INTERVAL" ]]   && { echo "❌ --interval is required." >&2; exit 1; }

echo "📊 Fetching metrics for $CONTENT_ID ($POST_URN) — interval: $INTERVAL${ACCOUNT:+ account: $ACCOUNT}" >&2

# ── Fetch metrics ─────────────────────────────────────────────────────────────

if [[ -n "$ACCOUNT" ]]; then
  METRICS_JSON=$(zsh "$METRICS_SCRIPT" --post-urn "$POST_URN" --account "$ACCOUNT") \
    || { echo "❌ linkedin-metrics.sh failed." >&2; exit 1; }
else
  METRICS_JSON=$(zsh "$METRICS_SCRIPT" --post-urn "$POST_URN") \
    || { echo "❌ linkedin-metrics.sh failed." >&2; exit 1; }
fi

REACTIONS=$(echo "$METRICS_JSON"  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('reactions', 0))")
COMMENTS=$(echo "$METRICS_JSON"   | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('comments', 0))")
SHARES=$(echo "$METRICS_JSON"     | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('shares', 0))")
IMPRESSIONS=$(echo "$METRICS_JSON"| python3 -c "import sys,json; d=json.load(sys.stdin); v=d.get('impressions'); print('null' if v is None else v)")
FETCHED_AT=$(echo "$METRICS_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('fetchedAt', ''))")

echo "  reactions=$REACTIONS  comments=$COMMENTS  shares=$SHARES  impressions=$IMPRESSIONS  fetchedAt=$FETCHED_AT" >&2

# ── Append snapshot to state file ────────────────────────────────────────────

python3 - <<PYEOF
import json, sys, os

state_file = "$METRICS_STATE"
content_id = "$CONTENT_ID"
post_urn   = "$POST_URN"
interval   = "$INTERVAL"
fetched_at = "$FETCHED_AT"
reactions  = $REACTIONS
comments   = $COMMENTS
shares     = $SHARES
impressions_raw = "$IMPRESSIONS"
impressions = None if impressions_raw == "null" else int(impressions_raw)

snapshot = {
    "interval":    interval,
    "fetchedAt":   fetched_at,
    "reactions":   reactions,
    "comments":    comments,
    "shares":      shares,
    "impressions": impressions
}

# Load or initialise state
if os.path.exists(state_file):
    with open(state_file, "r") as f:
        state = json.load(f)
else:
    state = {"schema": "1.0", "posts": []}

# Find or create post entry
posts = state.get("posts", [])
post_entry = next((p for p in posts if p.get("contentId") == content_id), None)

if post_entry is None:
    post_entry = {
        "contentId": content_id,
        "postUrn":   post_urn,
        "snapshots": []
    }
    posts.append(post_entry)
    state["posts"] = posts

post_entry.setdefault("snapshots", []).append(snapshot)

with open(state_file, "w") as f:
    json.dump(state, f, indent=2)

print(f"✅ Snapshot appended: {content_id} / {interval} / reactions={reactions} comments={comments} shares={shares}")
PYEOF
