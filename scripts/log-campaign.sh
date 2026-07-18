#!/usr/bin/env bash
# log-campaign.sh — Create or update a campaign in the AInchors campaign registry
# Usage:
#   log-campaign.sh new --name "Name" --type TYPE --goal GOAL --channels "Instagram,LinkedIn" [--budget N]
#   log-campaign.sh metrics --id CAMP-NNNN --stage STAGE --metric KEY --value N
#   log-campaign.sh close --id CAMP-NNNN [--revenue N] [--notes "..."]
#   log-campaign.sh list
#   log-campaign.sh show --id CAMP-NNNN
#   log-campaign.sh roi --id CAMP-NNNN
# TKT-0021

export PATH="$PATH:/usr/local/bin:/opt/homebrew/bin"

CAMPAIGNS="$HOME/.openclaw/workspace-business/state/campaigns.json"
FUNNEL="$HOME/.openclaw/workspace-business/state/funnel-metrics.json"
TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S+08:00")
DATE=$(date +"%Y-%m-%d")
CMD="${1:-help}"; shift || true

next_id() {
  python3 -c "
import json
d=json.load(open('$CAMPAIGNS'))
n=len(d.get('campaigns',[]))+1
print(f'CAMP-{n:04d}')
"
}

case "$CMD" in

  new)
    NAME=""; TYPE="content"; GOAL="awareness"; CHANNELS=""; BUDGET=0; DESC=""
    while (( $# > 0 )); do
      case "$1" in
        --name)     NAME="$2"; shift 2 ;;
        --type)     TYPE="$2"; shift 2 ;;
        --goal)     GOAL="$2"; shift 2 ;;
        --channels) CHANNELS="$2"; shift 2 ;;
        --budget)   BUDGET="$2"; shift 2 ;;
        --desc)     DESC="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    [ -z "$NAME" ] && { echo "ERROR: --name required" >&2; exit 1; }
    CAMP_ID=$(next_id)
    python3 << PYEOF
import json
d=json.load(open("$CAMPAIGNS"))
campaign = {
    "id": "$CAMP_ID",
    "name": "$NAME",
    "type": "$TYPE",
    "goal": "$GOAL",
    "channels": [c.strip() for c in "$CHANNELS".split(",") if c.strip()],
    "description": "$DESC",
    "status": "active",
    "createdAt": "$TIMESTAMP",
    "startDate": "$DATE",
    "endDate": None,
    "budgetAUD": float("$BUDGET"),
    "spentAUD": 0,
    "aiCostAUD": 0,
    "angieHoursSpent": 0,
    "revenueAttributedAUD": 0,
    "metrics": {
        "awareness": {"reach": 0, "impressions": 0, "views": 0, "followers_gained": 0},
        "interest": {"clicks": 0, "link_clicks": 0, "profile_visits": 0, "engagement_rate": 0, "saves": 0, "shares": 0},
        "consideration": {"email_signups": 0, "dms_received": 0, "inquiries": 0, "website_visits": 0},
        "intent": {"discovery_calls_booked": 0, "proposals_requested": 0},
        "conversion": {"enrollments": 0, "contracts_signed": 0, "revenue_generated": 0},
        "retention": {"repeat_purchases": 0, "referrals_generated": 0}
    },
    "conversionRates": {},
    "roi": None,
    "notes": [],
    "ariaActivities": []
}
d["campaigns"].append(campaign)
d["summary"]["total"] += 1
d["summary"]["active"] += 1
d["summary"]["totalBudgetAllocated"] = round(d["summary"]["totalBudgetAllocated"] + float("$BUDGET"), 2)
d["lastUpdated"] = "$DATE"
open("$CAMPAIGNS","w").write(json.dumps(d, indent=2))
print(f"✅ Campaign created: $CAMP_ID — $NAME")
print(f"   Type: $TYPE | Goal: $GOAL | Budget: A\$$BUDGET")
PYEOF
    ;;

  metrics)
    CAMP_ID=""; STAGE=""; METRIC=""; VALUE=0; NOTE=""
    while (( $# > 0 )); do
      case "$1" in
        --id)     CAMP_ID="$2"; shift 2 ;;
        --stage)  STAGE="$2"; shift 2 ;;
        --metric) METRIC="$2"; shift 2 ;;
        --value)  VALUE="$2"; shift 2 ;;
        --note)   NOTE="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    python3 << PYEOF
import json, math
d=json.load(open("$CAMPAIGNS"))
f=json.load(open("$FUNNEL"))
camp = next((c for c in d["campaigns"] if c["id"]=="$CAMP_ID"), None)
if not camp: print("ERROR: $CAMP_ID not found"); exit(1)
# Update metric
stage_metrics = camp["metrics"].setdefault("$STAGE", {})
old_val = stage_metrics.get("$METRIC", 0)
stage_metrics["$METRIC"] = float("$VALUE")
# Update aggregate funnel
agg = f["aggregateMetrics"]["allTime"]
metric_map = {"reach":"totalReach","impressions":"totalImpressions","clicks":"totalClicks",
              "inquiries":"totalInquiries","discovery_calls_booked":"totalDiscoveryCalls",
              "proposals_requested":"totalProposals","enrollments":"totalConversions"}
if "$METRIC" in metric_map:
    agg_key = metric_map["$METRIC"]
    agg[agg_key] = round(agg.get(agg_key,0) + (float("$VALUE") - old_val), 0)
# Update campaign aggregate
byCamp = f["aggregateMetrics"]["byCampaign"].setdefault("$CAMP_ID", {})
byCamp["$METRIC"] = float("$VALUE")
# Compute conversion rates
m = camp["metrics"]
awareness_reach = m.get("awareness",{}).get("reach",0)
consideration_inquiries = m.get("consideration",{}).get("inquiries",0)
intent_calls = m.get("intent",{}).get("discovery_calls_booked",0)
conversion_revenue = m.get("conversion",{}).get("revenue_generated",0)
if awareness_reach > 0:
    camp["conversionRates"]["reach_to_inquiry"] = round(consideration_inquiries/awareness_reach*100,2)
if consideration_inquiries > 0:
    camp["conversionRates"]["inquiry_to_call"] = round(intent_calls/consideration_inquiries*100,2)
open("$CAMPAIGNS","w").write(json.dumps(d, indent=2))
open("$FUNNEL","w").write(json.dumps(f, indent=2))
print(f"✅ $CAMP_ID | $STAGE.$METRIC = $VALUE (was {old_val})")
PYEOF
    ;;

  close)
    CAMP_ID=""; REVENUE=0; NOTES=""
    while (( $# > 0 )); do
      case "$1" in
        --id)      CAMP_ID="$2"; shift 2 ;;
        --revenue) REVENUE="$2"; shift 2 ;;
        --notes)   NOTES="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    python3 << PYEOF
import json
d=json.load(open("$CAMPAIGNS"))
camp=next((c for c in d["campaigns"] if c["id"]=="$CAMP_ID"),None)
if not camp: print("ERROR: $CAMP_ID not found"); exit(1)
camp["status"]="completed"; camp["endDate"]="$DATE"
camp["revenueAttributedAUD"]=float("$REVENUE")
if "$NOTES": camp["notes"].append({"date":"$DATE","note":"$NOTES"})
# Compute ROI
total_cost = camp.get("budgetAUD",0) + camp.get("aiCostAUD",0) + camp.get("angieHoursSpent",0)*250
revenue = float("$REVENUE")
camp["roi"] = round(revenue/total_cost,2) if total_cost>0 else None
camp["roiPct"] = round((revenue-total_cost)/total_cost*100,1) if total_cost>0 else None
d["summary"]["active"]=max(0,d["summary"]["active"]-1)
d["summary"]["completed"]+=1
d["summary"]["totalRevenueAttributed"]=round(d["summary"].get("totalRevenueAttributed",0)+revenue,2)
open("$CAMPAIGNS","w").write(json.dumps(d,indent=2))
print(f"✅ $CAMP_ID closed | Revenue: A\$$REVENUE | ROI: {camp['roi']}x")
PYEOF
    ;;

  list)
    python3 -c "
import json
d=json.load(open('$CAMPAIGNS'))
camps=d.get('campaigns',[])
if not camps: print('No campaigns yet.'); exit()
print('{:<12} {:<30} {:<10} {:<15} {:>10} {:>6}'.format('ID','Name','Status','Goal','Revenue','ROI'))
print('-'*85)
for c in camps:
    roi=f'{c[\"roi\"]}x' if c.get('roi') else '-'
    rev=f'A\${c.get(\"revenueAttributedAUD\",0):.0f}'
    print(f'{c[\"id\"]:<12} {c[\"name\"][:29]:<30} {c[\"status\"]:<10} {c[\"goal\"]:<15} {rev:>10} {roi:>6}')
s=d['summary']
print(f'\nTotal: {s[\"total\"]} campaigns | Budget: A\${s[\"totalBudgetAllocated\"]:.0f} | Revenue: A\${s[\"totalRevenueAttributed\"]:.0f}')
"
    ;;

  roi)
    CAMP_ID=""
    while (( $# > 0 )); do case "$1" in --id) CAMP_ID="$2"; shift 2 ;; *) shift ;; esac; done
    python3 << PYEOF
import json
d=json.load(open("$CAMPAIGNS"))
camp=next((c for c in d["campaigns"] if c["id"]=="$CAMP_ID"),None)
if not camp: print("ERROR: not found"); exit(1)
m=camp["metrics"]
print(f"\n{'='*55}")
print(f"  {camp['id']} — {camp['name']}")
print(f"  Status: {camp['status']} | Goal: {camp['goal']}")
print(f"{'='*55}")
print(f"\n  FUNNEL PERFORMANCE:")
print(f"  Awareness:      Reach {m.get('awareness',{}).get('reach',0):,} | Impressions {m.get('awareness',{}).get('impressions',0):,}")
print(f"  Interest:       Clicks {m.get('interest',{}).get('clicks',0):,} | Engagements {m.get('interest',{}).get('saves',0)+m.get('interest',{}).get('shares',0):,}")
print(f"  Consideration:  Inquiries {m.get('consideration',{}).get('inquiries',0)} | Signups {m.get('consideration',{}).get('email_signups',0)}")
print(f"  Intent:         Discovery calls {m.get('intent',{}).get('discovery_calls_booked',0)} | Proposals {m.get('intent',{}).get('proposals_requested',0)}")
print(f"  Conversion:     Enrollments {m.get('conversion',{}).get('enrollments',0)} | Revenue A\${m.get('conversion',{}).get('revenue_generated',0):,.0f}")
cr=camp.get("conversionRates",{})
if cr:
    print(f"\n  CONVERSION RATES:")
    for k,v in cr.items(): print(f"  {k}: {v}%")
print(f"\n  FINANCIALS:")
print(f"  Budget: A\${camp.get('budgetAUD',0):.0f} | AI cost: A\${camp.get('aiCostAUD',0):.0f} | Revenue: A\${camp.get('revenueAttributedAUD',0):.0f}")
if camp.get('roi'): print(f"  ROI: {camp['roi']}x ({camp.get('roiPct',0):.0f}% return)")
print()
PYEOF
    ;;

  *)
    echo "Usage: log-campaign.sh [new|metrics|close|list|roi] [options]"
    ;;
esac
