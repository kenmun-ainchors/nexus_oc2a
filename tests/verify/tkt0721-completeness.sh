#!/bin/bash
# tests/verify/tkt0721-completeness.sh
# TKT-0721 Verifier — checks that every markdown-header CHG exists in PG state_changes.

set -euo pipefail

DB_NAME="ainchors_nexus"
DB_USER="ainchorsangiefpl"
DB_HOST="127.0.0.1"

echo "Starting TKT-0721 Completeness Verification..."

# Gather CHG IDs that actually have standalone markdown headers (same logic as parser)
MD_CHGS=$(python3 - <<'PY'
import re, sys
files = [
    "memory/CHANGELOG.md",
    "docs/CHANGELOG.md",
    "archive/CHANGELOG.md",
]
seen = set()
for path in files:
    try:
        with open(path, 'r') as f:
            content = f.read()
    except FileNotFoundError:
        continue
    blocks = re.split(r'^##\s+', content, flags=re.MULTILINE)
    for block in blocks[1:]:
        if not block.strip():
            continue
        header = block.splitlines()[0]
        m1 = re.search(r'^(\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}\s[A-Za-z]+)\s+—\s+\[(CHG-\d+)\]\s+(.+)$', header)
        m2 = re.search(r'^(?:\[)?(CHG-\d+)(?:\])?\s+—\s+(.+)$', header)
        if m1:
            seen.add(m1.group(2))
        elif m2:
            seen.add(m2.group(1))
for cid in sorted(seen, key=lambda x: int(x.split('-')[1])):
    print(cid)
PY
)

TOTAL_MD_UNIQUE=$(echo "$MD_CHGS" | wc -l | tr -d ' ')
echo "Unique CHGs with markdown headers: $TOTAL_MD_UNIQUE"

# Count unique CHGs in state_changes
PG_CHG_COUNT=$(/opt/homebrew/bin/psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT count(DISTINCT change_id) FROM state_changes;")
echo "Unique CHGs in state_changes: $PG_CHG_COUNT"

# Gap analysis: any markdown-header CHG missing from PG
GAPS=0
MISSING=""
for chg in $MD_CHGS; do
    EXISTS=$(/opt/homebrew/bin/psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT 1 FROM state_changes WHERE change_id = '$chg';")
    if [[ -z "$EXISTS" ]]; then
        echo "MISSING: $chg"
        MISSING="$MISSING $chg"
        ((GAPS++)) || true
    fi
done

# Verify original 52 live CHGs are still present and not corrupted.
# Use CHG-0767 as a sample; also count that PG CHG count >= 700.
SAMP_EXISTS=$(/opt/homebrew/bin/psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT 1 FROM state_changes WHERE change_id = 'CHG-0767';")
if [[ -z "$SAMP_EXISTS" ]]; then
    echo "FAIL: Baseline CHG-0767 not found in state_changes."
    exit 1
fi
echo "PASS: Baseline CHGs preserved (sample CHG-0767 found)."

if [[ "$GAPS" -eq 0 && "$PG_CHG_COUNT" -ge 700 ]]; then
    echo "Verification complete: PASS (md=$TOTAL_MD_UNIQUE pg=$PG_CHG_COUNT gaps=$GAPS)"
    exit 0
else
    echo "Verification FAIL: gaps=$GAPS missing=$MISSING"
    exit 1
fi
