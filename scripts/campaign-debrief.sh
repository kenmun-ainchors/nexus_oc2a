#!/usr/bin/env bash
# campaign-debrief.sh — Post-execution campaign debrief prompt
# Aria calls this after a campaign completes. Prompts for all metrics.
# Outputs a structured debrief to campaigns.json and funnel-metrics.json.
# TKT-0021

export PATH="$PATH:/usr/local/bin:/opt/homebrew/bin"

CAMPAIGNS="$HOME/.openclaw/workspace-business/state/campaigns.json"
FUNNEL="$HOME/.openclaw/workspace-business/state/funnel-metrics.json"
TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S+10:00")
DATE=$(date +"%Y-%m-%d")
CAMP_ID="${1:-}"

[ -z "$CAMP_ID" ] && { echo "Usage: campaign-debrief.sh CAMP-NNNN"; exit 1; }

# Get campaign name
CAMP_NAME=$(python3 -c "
import json
d=json.load(open('$CAMPAIGNS'))
c=next((x for x in d['campaigns'] if x['id']=='$CAMP_ID'),None)
print(c['name'] if c else 'NOT FOUND')
")

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "  📊 CAMPAIGN DEBRIEF — $CAMP_ID"
echo "  $CAMP_NAME"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Aria: I'll guide you through capturing the campaign results."
echo "Answer each question — type 0 if unknown or N/A."
echo ""

# Awareness
echo "── AWARENESS ──────────────────────────────────────────────────"
read -rp "  Total reach (people who saw content): " REACH
read -rp "  Total impressions: " IMPRESSIONS
read -rp "  New followers gained: " FOLLOWERS

# Interest
echo ""
echo "── INTEREST ───────────────────────────────────────────────────"
read -rp "  Total clicks / link clicks: " CLICKS
read -rp "  Profile visits: " PROFILE_VISITS
read -rp "  Post saves: " SAVES
read -rp "  Post shares: " SHARES

# Consideration
echo ""
echo "── CONSIDERATION ──────────────────────────────────────────────"
read -rp "  DMs / direct inquiries received: " DMS
read -rp "  Email sign-ups generated: " EMAIL_SIGNUPS
read -rp "  Website visits attributed: " WEB_VISITS

# Intent
echo ""
echo "── INTENT ─────────────────────────────────────────────────────"
read -rp "  Discovery calls booked: " CALLS
read -rp "  Proposals requested: " PROPOSALS

# Conversion
echo ""
echo "── CONVERSION ─────────────────────────────────────────────────"
read -rp "  Enrollments / contracts signed: " CONVERSIONS
read -rp "  Revenue generated (A\$): " REVENUE

# Campaign cost
echo ""
echo "── COST & EFFORT ──────────────────────────────────────────────"
read -rp "  Angie's time spent on this campaign (hours): " ANGIE_HOURS
read -rp "  Any paid spend (A\$, e.g. ads): " PAID_SPEND
read -rp "  Overall: did this campaign achieve its goal? (yes/no/partial): " GOAL_MET
read -rp "  Key lesson from this campaign: " LESSON

# Log everything
bash "$(dirname "$0")/log-campaign.sh" metrics --id "$CAMP_ID" --stage awareness --metric reach --value "${REACH:-0}"
bash "$(dirname "$0")/log-campaign.sh" metrics --id "$CAMP_ID" --stage awareness --metric impressions --value "${IMPRESSIONS:-0}"
bash "$(dirname "$0")/log-campaign.sh" metrics --id "$CAMP_ID" --stage awareness --metric followers_gained --value "${FOLLOWERS:-0}"
bash "$(dirname "$0")/log-campaign.sh" metrics --id "$CAMP_ID" --stage interest --metric clicks --value "${CLICKS:-0}"
bash "$(dirname "$0")/log-campaign.sh" metrics --id "$CAMP_ID" --stage interest --metric profile_visits --value "${PROFILE_VISITS:-0}"
bash "$(dirname "$0")/log-campaign.sh" metrics --id "$CAMP_ID" --stage interest --metric saves --value "${SAVES:-0}"
bash "$(dirname "$0")/log-campaign.sh" metrics --id "$CAMP_ID" --stage interest --metric shares --value "${SHARES:-0}"
bash "$(dirname "$0")/log-campaign.sh" metrics --id "$CAMP_ID" --stage consideration --metric dms_received --value "${DMS:-0}"
bash "$(dirname "$0")/log-campaign.sh" metrics --id "$CAMP_ID" --stage consideration --metric email_signups --value "${EMAIL_SIGNUPS:-0}"
bash "$(dirname "$0")/log-campaign.sh" metrics --id "$CAMP_ID" --stage consideration --metric website_visits --value "${WEB_VISITS:-0}"
bash "$(dirname "$0")/log-campaign.sh" metrics --id "$CAMP_ID" --stage intent --metric discovery_calls_booked --value "${CALLS:-0}"
bash "$(dirname "$0")/log-campaign.sh" metrics --id "$CAMP_ID" --stage intent --metric proposals_requested --value "${PROPOSALS:-0}"
bash "$(dirname "$0")/log-campaign.sh" metrics --id "$CAMP_ID" --stage conversion --metric enrollments --value "${CONVERSIONS:-0}"
bash "$(dirname "$0")/log-campaign.sh" metrics --id "$CAMP_ID" --stage conversion --metric revenue_generated --value "${REVENUE:-0}"

# Update hours + paid spend + close
python3 << PYEOF
import json
d=json.load(open("$CAMPAIGNS"))
camp=next((c for c in d["campaigns"] if c["id"]=="$CAMP_ID"),None)
if camp:
    camp["angieHoursSpent"]=float("${ANGIE_HOURS:-0}")
    camp["spentAUD"]=float("${PAID_SPEND:-0}")
    camp["goalMet"]="${GOAL_MET:-unknown}"
    camp["notes"].append({"date":"$DATE","type":"debrief","lesson":"${LESSON}"})
open("$CAMPAIGNS","w").write(json.dumps(d,indent=2))
print("Campaign updated.")
PYEOF

# Close and compute ROI
bash "$(dirname "$0")/log-campaign.sh" close \
  --id "$CAMP_ID" \
  --revenue "${REVENUE:-0}" \
  --notes "Debrief completed $DATE. Goal: ${GOAL_MET}. Lesson: ${LESSON}"

echo ""
bash "$(dirname "$0")/log-campaign.sh" roi --id "$CAMP_ID"
echo ""
echo "✅ Debrief complete. Results logged to campaigns.json and funnel-metrics.json."
echo "   Run 'bash scripts/business-roi-report.sh' for full ROI view."
