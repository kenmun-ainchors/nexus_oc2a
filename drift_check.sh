#!/bin/bash
BASELINE_FILE="/Users/ainchorsangiefpl/.openclaw/workspace/state/archive/critical-config-baseline.json"
CONFIG_FILE="/Users/ainchorsangiefpl/.openclaw/openclaw.json"

# Extract the checks from baseline
CHECKS=$(jq -c '.checks[]' "$BASELINE_FILE")

DRIFT_DETECTED=0
DRIFT_FIELDS=()

while read -r check; do
    ID=$(echo "$check" | jq -r '.id')
    FILE=$(echo "$check" | jq -r '.file')
    QUERY=$(echo "$check" | jq -r '.jq_query')
    EXPECTED=$(echo "$check" | jq -r '.expected_value')

    # Only check files that exist
    if [ ! -f "$FILE" ]; then
        continue
    fi

    ACTUAL=$(jq -r "$QUERY" "$FILE")
    if [ "$ACTUAL" != "$EXPECTED" ]; then
        DRIFT_DETECTED=1
        DRIFT_FIELDS+=("$ID")
    fi
done <<< "$CHECKS"

if [ $DRIFT_DETECTED -eq 1 ]; then
    echo "DRIFT: ${DRIFT_FIELDS[*]}"
else
    echo "OK: no drift"
fi
