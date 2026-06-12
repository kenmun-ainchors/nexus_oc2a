#!/bin/bash
# L-085: Long-ID Stub Detection
# Detects PG tickets with long-ID format (TKT-NNNN: <text>) that may be
# L-077 stub-victim duplicates of the short-ID (TKT-NNNN) ticket.
#
# Detection regex: ^TKT-([0-9]{4,5}):\s+\S
# Age threshold: 7 days (per Ken 2026-06-12)
# Action: NON-DESTRUCTIVE — write findings to state/long-id-stubs.json
#         Do NOT auto-close. Surface for Ken review via auto-heal report.
#
# Usage: bash scripts/long-id-stub-check.sh

set -euo pipefail
cd "$(dirname "$0")/.."

OUTPUT_FILE="state/long-id-stubs.json"
AGE_DAYS=7
DB_SCRIPT="scripts/db.sh"

log() { echo "[$(date '+%H:%M:%S')] $1"; }

log "L-085: Long-ID stub detection (threshold: ${AGE_DAYS} days)"

# Run detection in Python — handles all the JSON + PG parsing using row_to_json
python3 - "$OUTPUT_FILE" "$AGE_DAYS" "$DB_SCRIPT" <<'PYEOF'
import json, os, subprocess, sys
from datetime import datetime, timezone

output_file = sys.argv[1]
age_days = int(sys.argv[2])
db_script = sys.argv[3]

# Query PG for long-ID stubs using row_to_json (no pipe issues with titles)
sql = """
SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
FROM (
  SELECT
    t.id AS long_id,
    t.status,
    t.updated_at,
    EXTRACT(DAY FROM (NOW() - t.updated_at))::int AS age_days,
    split_part(t.id, ':', 1) AS candidate_short_id,
    (SELECT id FROM state_tickets WHERE id = split_part(t.id, ':', 1) LIMIT 1) AS short_id_exists,
    LEFT(t.title, 80) AS title_preview
  FROM state_tickets t
  WHERE t.id ~ '^TKT-[0-9]{4,5}:[[:space:]]+[^[:space:]]'
    AND t.status IN ('open','in-progress','pending','backlog','grooming','monitoring')
    AND EXTRACT(DAY FROM (NOW() - t.updated_at)) >= %d
  ORDER BY t.id
) t;
""" % age_days

r = subprocess.run(['bash', db_script, '-c', sql], capture_output=True, text=True)
raw = r.stdout.strip()

findings = []
if raw and not raw.startswith('ERROR') and raw != '[]':
    try:
        findings = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"WARN: JSON parse error: {e}", file=sys.stderr)
        print(f"Raw output: {raw[:200]}", file=sys.stderr)
        findings = []

# Add recommendation to each finding
for f in findings:
    if f.get('short_id_exists'):
        f['recommendation'] = f"Close as superseded by {f['short_id_exists']}"
    else:
        f['recommendation'] = "Review manually — no matching short-ID found"

result = {
    'check': 'L-085 long-id stub detection',
    'run_at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'age_threshold_days': age_days,
    'count': len(findings),
    'findings': findings,
    'recommendation': (
        f'Long-ID stubs older than {age_days} days may be L-077 duplicates of the '
        f'short-ID ticket. Review each finding. If short_id_exists matches an open '
        f'or done ticket, close the long stub with resolution="superseded by '
        f'<short_id>". Do NOT auto-close (non-destructive per L-085 decision).'
    ),
}

os.makedirs(os.path.dirname(output_file), exist_ok=True)
with open(output_file, 'w') as f:
    json.dump(result, f, indent=2)

print(f"[{datetime.now().strftime('%H:%M:%S')}] L-085: Found {len(findings)} long-ID stub(s) older than {age_days} days")
print(f"[{datetime.now().strftime('%H:%M:%S')}] L-085: Findings written to {output_file}")
for f in findings:
    match = f" [SHORT-ID EXISTS: {f['short_id_exists']}]" if f.get('short_id_exists') else " [no short-ID match]"
    print(f"  - {f['long_id']} (age {f['age_days']}d, status={f['status']}){match}")
PYEOF
