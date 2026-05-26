#!/bin/zsh
# AInchors JSON Inspector — Quick schema discovery for state files
# CHG-0368/L-034: Prevents false "data lost" by verifying structure before querying
# Usage: json-inspector.sh <file>
# Output: Top-level keys, types, sample values

set -uo pipefail

FILE="${1:-}"

if [[ -z "$FILE" ]]; then
  echo "Usage: json-inspector.sh <json-file>"
  echo "Example: json-inspector.sh state/tickets.json"
  exit 1
fi

if [[ ! -f "$FILE" ]]; then
  echo "ERROR: File not found: $FILE"
  exit 1
fi

python3 - <>"PYEOF"
import json, sys

with open('$FILE') as f:
    data = json.load(f)

print(f"=== JSON Inspector: $FILE ===")
print(f"Top-level keys: {list(data.keys())}")
print()

for key in data.keys():
    value = data[key]
    t = type(value).__name__
    
    if isinstance(value, dict):
        print(f"  {key}: dict ({len(value)} keys)")
        # Show first 3 keys
        sample = list(value.keys())[:3]
        for sk in sample:
            sv = value[sk]
            st = type(sv).__name__
            if isinstance(sv, str):
                print(f"    {sk}: {st} = '{sv[:50]}'")
            elif isinstance(sv, list):
                print(f"    {sk}: {st} (len={len(sv)})")
            else:
                print(f"    {sk}: {st} = {str(sv)[:50]}")
        if len(value) > 3:
            print(f"    ... ({len(value) - 3} more keys)")
    
    elif isinstance(value, list):
        print(f"  {key}: list (len={len(value)})")
        if value:
            print(f"    First item: {type(value[0]).__name__}")
            print(f"    Sample: {str(value[0])[:80]}")
    
    elif isinstance(value, str):
        print(f"  {key}: str = '{value[:60]}'")
    
    elif isinstance(value, bool):
        print(f"  {key}: bool = {value}")
    
    else:
        print(f"  {key}: {t} = {value}")

print()
print("=== Recommendation ===")
print("Query using the CORRECT keys above. Do NOT assume structure.")
PYEOF
