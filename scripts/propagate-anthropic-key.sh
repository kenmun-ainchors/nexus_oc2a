#!/usr/bin/env python3
"""
propagate-anthropic-key.sh
Copies the anthropic:default auth profile from the main agent to all other agents.
Run this after every Anthropic API key rotation.

Usage:
  python3 scripts/propagate-anthropic-key.sh
  # or make it executable: chmod +x scripts/propagate-anthropic-key.sh && ./scripts/propagate-anthropic-key.sh
"""

import json, os, sys

AGENTS_DIR = "/Users/ainchorsoc2a/.openclaw/agents"
MAIN_AUTH = f"{AGENTS_DIR}/main/agent/auth-profiles.json"

# Read the anthropic key from main
if not os.path.exists(MAIN_AUTH):
    print(f"ERROR: main auth profiles not found at {MAIN_AUTH}")
    sys.exit(1)

with open(MAIN_AUTH) as f:
    main_profiles = json.load(f)

anthropic_profile = main_profiles.get("profiles", {}).get("anthropic:default")
if not anthropic_profile:
    print("ERROR: anthropic:default not found in main auth profiles.")
    print("Run: openclaw models auth  — then re-run this script.")
    sys.exit(1)

key_preview = anthropic_profile["key"][:14] + "…"
print(f"✅ Anthropic key found in main: {key_preview}")
print()

# Propagate to all other agents
agents = sorted([
    d for d in os.listdir(AGENTS_DIR)
    if d != "main" and os.path.isdir(f"{AGENTS_DIR}/{d}")
])

updated = []
already_ok = []
errors = []

for agent in agents:
    auth_path = f"{AGENTS_DIR}/{agent}/agent/auth-profiles.json"
    try:
        if not os.path.exists(auth_path):
            os.makedirs(os.path.dirname(auth_path), exist_ok=True)
            data = {"version": 1, "profiles": {"anthropic:default": anthropic_profile}}
            with open(auth_path, "w") as f:
                json.dump(data, f, indent=2)
            updated.append(f"{agent} (created)")
        else:
            with open(auth_path) as f:
                data = json.load(f)
            current_key = data.get("profiles", {}).get("anthropic:default", {}).get("key", "")
            if current_key == anthropic_profile["key"]:
                already_ok.append(agent)
            else:
                data.setdefault("profiles", {})["anthropic:default"] = anthropic_profile
                with open(auth_path, "w") as f:
                    json.dump(data, f, indent=2)
                updated.append(f"{agent} (updated)")
    except Exception as e:
        errors.append(f"{agent}: {e}")

# Report
if updated:
    print(f"Updated ({len(updated)}):")
    for a in updated:
        print(f"  ✅ {a}")
    print()

if already_ok:
    print(f"Already correct ({len(already_ok)}): {', '.join(already_ok)}")
    print()

if errors:
    print(f"Errors ({len(errors)}):")
    for e in errors:
        print(f"  ❌ {e}")
    sys.exit(1)

print("Done. All agents have the current Anthropic key.")
print()

# Sync keychain entries to match auth-profiles.json (keeps diagnostic scripts in sync)
import subprocess
new_key = anthropic_profile["key"]
keychain_entries = [
    ("ainchors-anthropic-api-key", "anthropic"),
    ("anthropic-api-key", "ainchors"),
    ("anthropic-api-key", "anthropic"),
]
print("Syncing keychain entries...")
for svc, acct in keychain_entries:
    result = subprocess.run(
        ["security", "add-generic-password", "-U", "-s", svc, "-a", acct, "-w", new_key],
        capture_output=True
    )
    if result.returncode == 0:
        print(f"  \u2705 Keychain updated: {svc} (account: {acct})")
    else:
        # Entry may not exist yet — try creating it
        result2 = subprocess.run(
            ["security", "add-generic-password", "-s", svc, "-a", acct, "-w", new_key],
            capture_output=True
        )
        if result2.returncode == 0:
            print(f"  \u2705 Keychain created: {svc} (account: {acct})")
        else:
            print(f"  \u26a0\ufe0f  Keychain skip: {svc} (account: {acct}) — {result.stderr.decode().strip()}")
print()
print("Next steps:")
print("  1. Verify crons recover on next scheduled run")
print("  2. Or manually trigger: openclaw crons run <jobId>")
