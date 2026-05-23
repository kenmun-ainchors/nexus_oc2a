#!/usr/bin/env zsh
# =============================================================================
# incident-log.sh -- AInchors Incident Persistence Tool
# Usage: incident-log.sh --id INC-YYYYMMDD-NNN --title "..." --severity P1|P2|P3|P4 \
#                        --start "ISO" --end "ISO" --cause "..." --resolution "..." \
#                        [--chg CHG-XXXX] [--preventable true|false] [--impact "..."] \
#                        [--detected-by "..."] [--related-us "US1 US2"]
# Writes state/incidents/INC-YYYYMMDD-NNN.json
# =============================================================================
set -euo pipefail

WORKSPACE="${0:A:h:h}"
INCIDENTS_DIR="$WORKSPACE/state/incidents"

# -- Parse args ---------------------------------------------------------------
id=""
title=""
severity=""
start_at=""
end_at=""
cause=""
resolution=""
chg=""
preventable="false"
impact=""
detected_by="Yoda (automated)"
related_us=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id)           id="$2";           shift 2 ;;
    --title)        title="$2";        shift 2 ;;
    --severity)     severity="$2";     shift 2 ;;
    --start)        start_at="$2";     shift 2 ;;
    --end)          end_at="$2";       shift 2 ;;
    --cause)        cause="$2";        shift 2 ;;
    --resolution)   resolution="$2";   shift 2 ;;
    --chg)          chg="$2";          shift 2 ;;
    --preventable)  preventable="$2";  shift 2 ;;
    --impact)       impact="$2";       shift 2 ;;
    --detected-by)  detected_by="$2";  shift 2 ;;
    --related-us)   related_us="$2";   shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# -- Validate required --------------------------------------------------------
if [[ -z "$id" || -z "$title" || -z "$severity" || -z "$start_at" || -z "$end_at" ]]; then
  echo "ERROR: --id, --title, --severity, --start, --end are required." >&2
  echo "Usage: $0 --id INC-YYYYMMDD-NNN --title '...' --severity P1 --start 'ISO' --end 'ISO' [--cause '...'] [--resolution '...'] [--chg CHG-XXXX]" >&2
  exit 1
fi

case "$severity" in
  P1|P2|P3|P4) ;;
  *) echo "ERROR: --severity must be P1, P2, P3, or P4." >&2; exit 1 ;;
esac

# -- Calculate duration -------------------------------------------------------
duration_minutes=$(python3 -c "
from datetime import datetime
try:
    s = datetime.fromisoformat('$start_at')
    e = datetime.fromisoformat('$end_at')
    delta = e - s
    print(int(delta.total_seconds() / 60))
except Exception as ex:
    print('0')
")

# -- Build related_us array ---------------------------------------------------
related_us_json="[]"
if [[ -n "$related_us" ]]; then
  related_us_json=$(python3 -c "
import json
items = '$related_us'.split()
print(json.dumps(items))
")
fi

# -- Build linked_chg value ---------------------------------------------------
linked_chg_json="null"
if [[ -n "$chg" ]]; then
  linked_chg_json="\"$chg\""
fi

# -- Preventable logic --------------------------------------------------------
preventable_json="false"
prevention_field=""
if [[ "$preventable" == "true" || "$preventable" == "1" ]]; then
  preventable_json="true"
  prevention_field="\"prevention\": \"Documented in incident resolution. Apply pre-risky-op checkpoint.\","
fi

# -- Auto-create dir ----------------------------------------------------------
mkdir -p "$INCIDENTS_DIR"

OUT_FILE="$INCIDENTS_DIR/${id}.json"

if [[ -f "$OUT_FILE" ]]; then
  echo "WARNING: $OUT_FILE already exists. Overwriting." >&2
fi

# -- Write JSON ---------------------------------------------------------------
python3 - <<PYEOF
import json
from datetime import datetime

data = {
    "id": "$id",
    "title": "$title",
    "severity": "$severity",
    "startedAt": "$start_at",
    "resolvedAt": "$end_at",
    "durationMinutes": $duration_minutes,
    "rootCause": "$cause",
    "impact": "$impact",
    "resolution": "$resolution",
    "preventable": $preventable_json,
    "linkedChg": $linked_chg_json,
    "detectedBy": "$detected_by",
    "relatedUS": $related_us_json
}

if $preventable_json:
    data["prevention"] = "Documented in incident resolution. Apply pre-risky-op checkpoint."

out = "$OUT_FILE"
with open(out, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print(f"[incident-log] Written: {out}")
print(f"  ID:       $id")
print(f"  Severity: $severity")
print(f"  Duration: $duration_minutes min")
PYEOF
[2026-05-23 02:05] WARNING: Daily backup script returned non-zero exit code. Error: 'atlas/' does not have a commit checked out; fatal: adding files failed.
