#!/usr/bin/env zsh
# linkedin-metrics-batch.sh — run linkedin-metrics-snapshot.sh for all valid published/queued posts
set -euo pipefail
WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
SCRIPT="$WORKSPACE/scripts/linkedin-metrics-snapshot.sh"
STATE="$WORKSPACE/state/linkedin-campaign.json"
ERRORS_FILE="$WORKSPACE/state/linkedin-metrics-errors.json"
SUMMARY_FILE="$WORKSPACE/state/linkedin-metrics-summary.json"

ERRORS=()
SUMMARY=()
TOTAL_REACTIONS=0
TOTAL_COMMENTS=0
TOTAL_SHARES=0

# Build list of posts with valid URN
POSTS=$(jq -r '[.published[], .queued[]] | map(select(.postUrn != null and .postUrn != "N/A" and .postUrn != "pending-urn-check")) | .[] | "\(.id)\t\(.postUrn)\t\(.account // "ken")\t\(.title // "")"' "$STATE")

while IFS=$'\t' read -r ID URN ACCOUNT TITLE; do
  echo "→ $ID"
  SNAP=$(zsh "$SCRIPT" --content-id "$ID" --post-urn "$URN" --interval 24h --account "$ACCOUNT" 2>&1) || {
    ERR_CODE=""
    [[ "$SNAP" == *"401"* ]] && ERR_CODE="401"
    [[ "$SNAP" == *"404"* ]] && ERR_CODE="404"
    [[ -z "$ERR_CODE" ]] && ERR_CODE="unknown"
    ERRORS+=("{\"contentId\":\"$ID\",\"postUrn\":\"$URN\",\"error\":\"$ERR_CODE\",\"time\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}")
    echo "  ❌ $ERR_CODE error for $ID"
    continue
  }
  # Parse last line for reactions/comments/shares/impressions
  LAST=$(echo "$SNAP" | tail -n1)
  REACTIONS=$(echo "$LAST" | grep -oP 'reactions=\K[0-9]+' || echo 0)
  COMMENTS=$(echo "$LAST" | grep -oP 'comments=\K[0-9]+' || echo 0)
  SHARES=$(echo "$LAST" | grep -oP 'shares=\K[0-9]+' || echo 0)
  IMPRESSIONS=$(echo "$LAST" | grep -oP 'impressions=\K[0-9]+' || echo "N/A")
  SUMMARY+=("{\"contentId\":\"$ID\",\"title\":\"${TITLE//\"/\\\"}\",\"reactions\":$REACTIONS,\"comments\":$COMMENTS,\"shares\":$SHARES,\"impressions\":\"$IMPRESSIONS\"}")
  TOTAL_REACTIONS=$((TOTAL_REACTIONS + REACTIONS))
  TOTAL_COMMENTS=$((TOTAL_COMMENTS + COMMENTS))
  TOTAL_SHARES=$((TOTAL_SHARES + SHARES))
done <<< "$POSTS"

# Write errors
if (( ${#ERRORS[@]} )); then
  python3 -c "
import json
errors = [json.loads(x) for x in '''$(printf '%s\n' "${ERRORS[@]}")'''.splitlines() if x.strip()]
with open('$ERRORS_FILE', 'w') as f:
    json.dump({'schema':'1.0','errors':errors,'generatedAt':'$(date -u +%Y-%m-%dT%H:%M:%SZ)'}, f, indent=2)
"
else
  python3 -c "import json; json.dump({'schema':'1.0','errors':[],'generatedAt':'$(date -u +%Y-%m-%dT%H:%M:%SZ)'}, open('$ERRORS_FILE','w'), indent=2)"
fi

# Write summary
python3 -c "
import json
summary = [json.loads(x) for x in '''$(printf '%s\n' "${SUMMARY[@]}")'''.splitlines() if x.strip()]
out = {
    'schema': '1.0',
    'generatedAt': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'totalPosts': len(summary),
    'totalReactions': $TOTAL_REACTIONS,
    'totalComments': $TOTAL_COMMENTS,
    'totalShares': $TOTAL_SHARES,
    'posts': summary
}
with open('$SUMMARY_FILE', 'w') as f:
    json.dump(out, f, indent=2)
"

echo "✅ Done. Posts=$((${#SUMMARY[@]})) Errors=$((${#ERRORS[@]}))"
