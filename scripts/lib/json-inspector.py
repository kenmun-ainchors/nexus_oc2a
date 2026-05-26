#!/usr/bin/env python3
"""
AInchors JSON Inspector — Quick schema discovery for state files
CHG-0368/L-034: Prevents false "data lost" by verifying structure before querying
Usage: python3 json-inspector.py <file>
Output: Top-level keys, types, sample values
"""

import json, sys

FILE = sys.argv[1] if len(sys.argv) > 1 else None

if not FILE:
    print("Usage: python3 json-inspector.py <json-file>")
    print("Example: python3 json-inspector.py state/tickets.json")
    sys.exit(1)

try:
    with open(FILE) as f:
        data = json.load(f)
except FileNotFoundError:
    print(f"ERROR: File not found: {FILE}")
    sys.exit(1)
except json.JSONDecodeError as e:
    print(f"ERROR: Invalid JSON: {e}")
    sys.exit(1)

print(f"=== JSON Inspector: {FILE} ===")
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
print("If querying a dict, use: data['keyname'] not data.get('wrongkey')")
