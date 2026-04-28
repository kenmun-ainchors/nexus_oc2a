#!/usr/bin/env bash
# frameworks-report.sh — /frameworks command handler
# Reads state/frameworks-maturity.json and produces a structured assessment.
# Includes: maturity, what's live, gaps, opportunities, priority focus.
# Locked 2026-04-28.

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
STATE="$WORKSPACE/state/frameworks-maturity.json"

python3 << PYEOF
import json
from datetime import datetime

with open("$STATE") as f:
    d = json.load(f)

fw = d["frameworks"]
assessed = d.get("lastAssessed","?")[:10]
overall = d.get("overallMaturity","?")

MATURITY_BAR = {
    "L1": "█░░░░", "L2": "██░░░", "L2-L3": "██▌░░",
    "L3": "███░░", "L3-L4": "███▌░", "L4": "████░", "L5": "█████"
}
PRIORITY_ICON = {"High":"🔴","Medium":"🟡","Low":"🟢"}

print(f"""
╔══════════════════════════════════════════════════════════════╗
  🏗️  AINCHORS FRAMEWORK MATURITY ASSESSMENT
  Assessed: {assessed}  ·  Overall: {overall}
╚══════════════════════════════════════════════════════════════╝
""")

order = ["agile","itsm","governance","tom","modelStrategy","knowledgeManagement","costManagement"]
names = {"agile":"AGILE","itsm":"ITIL / ITSM","governance":"GOVERNANCE",
         "tom":"TOM","modelStrategy":"MODEL STRATEGY",
         "knowledgeManagement":"KNOWLEDGE MGMT","costManagement":"COST MANAGEMENT"}

for key in order:
    f = fw[key]
    mat = f["maturity"]
    bar = MATURITY_BAR.get(mat, "?????")
    pri = PRIORITY_ICON.get(f["priorityFocus"],"·")
    print(f"  {pri} {names[key]:<22} [{mat:<5}] {bar}  {f['maturityLabel']}")

print()
print("─" * 62)
print()

for key in order:
    f = fw[key]
    mat = f["maturity"]
    pri = PRIORITY_ICON.get(f["priorityFocus"],"·")
    print(f"{pri} {names[key]} · {f['purpose']}")
    print(f"  Maturity: {mat} — {f['maturityLabel']}")
    print()

    gaps = f.get("gaps",[])
    if gaps:
        print(f"  Gaps ({len(gaps)}):")
        for g in gaps[:3]:
            print(f"    ✗ {g}")
        if len(gaps) > 3:
            print(f"    ... +{len(gaps)-3} more")

    opps = f.get("opportunities",[])
    if opps:
        print(f"  Opportunities:")
        for o in opps[:2]:
            print(f"    → {o}")

    print(f"  Next: {f.get('nextStep','—')}")
    print()

print("─" * 62)
print()
print("PRIORITY FOCUS ORDER:")
for i, item in enumerate(d.get("priorityFocusOrder",[]), 1):
    fw_key = item["framework"]
    fw_name = names.get(fw_key, fw_key)
    print(f"  {i}. [{fw_name}] {item['action']}")

print()
print(f"State file: state/frameworks-maturity.json  ·  Last assessed: {assessed}")
PYEOF
