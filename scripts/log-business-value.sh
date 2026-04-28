#!/usr/bin/env bash
# log-business-value.sh — Log a business value event to the Business ROI tracker
# Called by Aria after completing any value-generating activity.
# Usage: bash log-business-value.sh --category CAT --subcategory SUB --units N [--notes "..."] [--confirmed]
# TKT-0020 | Business ROI Framework

export PATH="$PATH:/usr/local/bin:/opt/homebrew/bin"

ROI_FILE="$HOME/.openclaw/workspace-business/state/business-roi.json"
RUBRIC="$HOME/.openclaw/workspace-business/state/business-value-rubric.json"
TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S+10:00")
DATE=$(date +"%Y-%m-%d")

CATEGORY=""; SUBCATEGORY=""; UNITS=1; NOTES=""; CONFIRMED=false; DESCRIPTION=""

while (( $# > 0 )); do
  case "$1" in
    --category)    CATEGORY="$2"; shift 2 ;;
    --subcategory) SUBCATEGORY="$2"; shift 2 ;;
    --units)       UNITS="$2"; shift 2 ;;
    --notes)       NOTES="$2"; shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --confirmed)   CONFIRMED=true; shift ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

[ -z "$CATEGORY" ] && { echo "ERROR: --category required" >&2; exit 1; }
[ -z "$SUBCATEGORY" ] && { echo "ERROR: --subcategory required" >&2; exit 1; }

python3 << PYEOF
import json, os

rubric = json.load(open("$RUBRIC"))
roi = json.load(open("$ROI_FILE"))

cat = rubric["valueCategories"].get("$CATEGORY", {})
subcat = cat.get("subcategories", {}).get("$SUBCATEGORY", {})
value_per_unit = subcat.get("valuePerUnit", 0)
units = float("$UNITS")
cat_label = cat.get("label", "$CATEGORY")
subcat_label = subcat.get("label", "$SUBCATEGORY")

confirmed = "$CONFIRMED" == "True" or "$CONFIRMED" == "true"
multiplier = rubric["valueVerification"]["confirmedMultiplier"] if confirmed else rubric["valueVerification"]["estimatedMultiplier"]
estimated_value = value_per_unit * units
reported_value = round(estimated_value * multiplier, 2)

entry = {
    "id": f"BV-{len(roi['entries'])+1:04d}",
    "timestamp": "$TIMESTAMP",
    "date": "$DATE",
    "category": "$CATEGORY",
    "categoryLabel": cat_label,
    "subcategory": "$SUBCATEGORY",
    "subcategoryLabel": subcat_label,
    "units": units,
    "valuePerUnit": value_per_unit,
    "estimatedValueAUD": estimated_value,
    "reportedValueAUD": reported_value,
    "confirmed": confirmed,
    "notes": "$NOTES",
    "description": "$DESCRIPTION"
}

roi["entries"].append(entry)

# Update summary
s = roi["summary"]
s["totalEntriesLogged"] += 1
s["totalEstimatedValueAUD"] = round(s["totalEstimatedValueAUD"] + estimated_value, 2)
if confirmed:
    s["totalConfirmedValueAUD"] = round(s.get("totalConfirmedValueAUD", 0) + estimated_value, 2)

cat_s = s["byCategory"].setdefault("$CATEGORY", {"estimated": 0, "confirmed": 0, "entries": 0})
cat_s["estimated"] = round(cat_s["estimated"] + estimated_value, 2)
cat_s["entries"] += 1
if confirmed:
    cat_s["confirmed"] = round(cat_s["confirmed"] + estimated_value, 2)

roi["lastUpdated"] = "$DATE"

with open("$ROI_FILE", "w") as f:
    json.dump(roi, f, indent=2)

status = "CONFIRMED" if confirmed else "ESTIMATED"
print(f"✅ {entry['id']} [{status}] {subcat_label}: {units} unit(s) = A\${reported_value:.0f} (est A\${estimated_value:.0f})")
print(f"   Category: {cat_label} | Running total: A\${roi['summary']['totalEstimatedValueAUD']:.0f} estimated")
PYEOF
