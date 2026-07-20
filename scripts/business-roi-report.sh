#!/usr/bin/env bash
# business-roi-report.sh — Generate Business ROI report
# Compares business value generated vs technology cost invested.
# TKT-0020

export PATH="$PATH:/usr/local/bin:/opt/homebrew/bin"

# Canonical business agent state — migrated from legacy workspace-business/state/ per CHG-0945.
ARIA_AGENT_STATE="/Users/ainchorsoc2a/.openclaw/agents/business/agent/state"
ROI_FILE="$ARIA_AGENT_STATE/business-roi.json"
COST_FILE="/Users/ainchorsoc2a/.openclaw/workspace/state/cost-state.json"

python3 << 'PYEOF'
import json, os
from datetime import datetime

roi  = json.load(open(os.path.expanduser(os.environ.get("ROI_FILE", "~/.openclaw/agents/business/agent/state/business-roi.json"))))
cost = json.load(open(os.path.expanduser(os.environ.get("COST_FILE", "~/.openclaw/workspace/state/cost-state.json"))))

AUD = 1.53
tech_usd = cost.get("allTimeTotalCost", 0)
tech_aud = round(tech_usd * AUD, 2)
bal_usd  = cost["apiBalance"].get("confirmedBalance", 0)

bv = roi["summary"]["totalEstimatedValueAUD"]
bv_confirmed = roi["summary"].get("totalConfirmedValueAUD", 0)
entries = roi["summary"]["totalEntriesLogged"]
roi_ratio = round(bv / tech_aud, 1) if tech_aud > 0 else 0

print(f"""
╔══════════════════════════════════════════════════════════════════╗
  💼  AINCHORS BUSINESS ROI REPORT
  Generated: {datetime.now().strftime('%Y-%m-%d %H:%M MYT')}
╚══════════════════════════════════════════════════════════════════╝

  ┌─ TECHNOLOGY INVESTMENT (what we spent) ────────────────────┐
  │  API spend to date:  USD ${tech_usd:>8.2f}  (A${tech_aud:>8.2f})        │
  │  Balance remaining:  USD ${bal_usd:>8.2f}                              │
  └────────────────────────────────────────────────────────────┘

  ┌─ BUSINESS VALUE GENERATED (what we got) ──────────────────┐
  │  Estimated value:    A${bv:>9.2f}  ({entries} activities logged)    │
  │  Confirmed value:    A${bv_confirmed:>9.2f}  (Angie-verified)              │
  │  Confidence note:    Unconfirmed estimates discounted 30%          │
  └────────────────────────────────────────────────────────────┘

  ┌─ ROI RATIO ────────────────────────────────────────────────┐
  │  Business Value ÷ Tech Cost  =  {roi_ratio}x return on AI investment   │
  │  Target: >10x                                              │
  └────────────────────────────────────────────────────────────┘
""")

# By category
cats = roi["summary"]["byCategory"]
cat_labels = {
    "revenue": "Revenue Pipeline",
    "timeEfficiency": "Time & Efficiency",
    "contentBrand": "Content & Brand",
    "riskCompliance": "Risk & Compliance",
    "clientValue": "Client Value"
}
print("  VALUE BY CATEGORY:")
for key, label in cat_labels.items():
    c = cats.get(key, {"estimated": 0, "entries": 0})
    bar_w = max(1, int(c["estimated"] / max(bv, 1) * 30)) if bv > 0 else 1
    bar = "█" * bar_w
    print(f"  {label:<22} A${c['estimated']:>8.0f}  {bar}  ({c['entries']} items)")

# Recent entries
print(f"\n  RECENT ACTIVITIES:")
entries_list = roi.get("entries", [])
for e in entries_list[-5:][::-1]:
    status = "✓" if e.get("confirmed") else "~"
    print(f"  {status} [{e['date']}] {e['subcategoryLabel']}: {e['units']} × A${e['valuePerUnit']} = A${e['estimatedValueAUD']:.0f}")

if not entries_list:
    print("  (No activities logged yet — Aria logs as business work begins)")

print(f"""
  ──────────────────────────────────────────────────────────────
  ~ = estimated (pending Angie confirmation)
  ✓ = confirmed by Angie
  Log new activity: bash scripts/log-business-value.sh --category X --subcategory Y --units N
  Tracking started: {roi['trackingStarted']}
""")
PYEOF
