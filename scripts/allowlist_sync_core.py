#!/usr/bin/env python3
"""
allowlist_sync_core.py - Core sync logic for allowlist-sync.sh
Reads model-policy.json, computes per-agent allowedInCrons updates based on
Tier 2 cloud eligibility matrix, outputs JSON result to stdout.

Usage: python3 allowlist_sync_core.py [--apply] [--policy PATH]
  --apply   Write changes to model-policy.json (default: dry-run)
  --policy  Path to model-policy.json (default: state/model-policy.json)
"""

import json
import sys
import copy
import os
import argparse

WORKSPACE = "/Users/ainchorsoc2a/.openclaw/workspace"

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="Write changes to policy file")
    parser.add_argument("--policy", default=f"{WORKSPACE}/state/model-policy.json")
    parser.add_argument("--timestamp", default="")
    parser.add_argument("--source", default="manual")
    args = parser.parse_args()

    with open(args.policy) as f:
        policy = json.load(f)

    # ------------------------------------------------------------------
    # ELIGIBILITY MATRIX
    # Defines which Ollama Cloud model categories each agent may use in crons.
    #   tier2_cloud_all   -> all approved Tier 2 Ollama Cloud models
    #   tier2_cloud_fast  -> kimi + deepseek-flash (speed-focused, not pro)
    #   tier2_cloud_flash -> deepseek-flash only (lightweight compliance checks)
    #   tier2_cloud_spark -> kimi + deepseek-pro (creative/content focus)
    #   none              -> no Ollama Cloud (sensitive content or infra)
    #
    # To update agent scope: change the value here. Script handles the rest.
    # ------------------------------------------------------------------
    ELIGIBILITY_MATRIX = {
        "main":       "tier2_cloud_all",    # Yoda: all cron types, non-sensitive
        "business":   "tier2_cloud_all",    # Aria: internal business ops crons
        "spark":      "tier2_cloud_spark",  # Spark: creative/content (kimi + pro)
        "qa":         "tier2_cloud_fast",   # Sage: non-sensitive content QA
        "governance": "tier2_cloud_flash",  # Warden: lightweight compliance checks
        "security":   "none",               # Shield: sensitive infra - no cloud
        "legal":      "none",               # Lex: sensitive legal content - no cloud
    }

    # Base Anthropic + local models that are always present per agent (never removed)
    ANTHROPIC_BASE_CRONS = {
        "main":       ["anthropic/claude-haiku-4-5", "anthropic/claude-sonnet-4-6", "ollama/gemma4:e2b"],
        "business":   ["anthropic/claude-haiku-4-5", "anthropic/claude-sonnet-4-6"],
        "spark":      ["ollama/kimi-k2.6:cloud", "anthropic/claude-sonnet-4-6", "anthropic/claude-haiku-4-5"],
        "qa":         ["anthropic/claude-haiku-4-5", "anthropic/claude-sonnet-4-6"],
        "governance": ["anthropic/claude-haiku-4-5", "anthropic/claude-sonnet-4-6"],
        "security":   ["anthropic/claude-haiku-4-5", "anthropic/claude-sonnet-4-6"],
        "legal":      ["anthropic/claude-haiku-4-5", "anthropic/claude-sonnet-4-6"],
    }

    # ------------------------------------------------------------------
    # Extract approved Tier 2 cloud models from tierStrategy
    # ------------------------------------------------------------------
    tier2 = policy.get("tierStrategy", {}).get("tiers", {}).get("tier2_subtasks", {})
    all_cloud = [m["model"] for m in tier2.get("ollamaCloudModels", [])]

    fast_cloud  = [m for m in all_cloud if "flash" in m or "kimi" in m]
    flash_cloud = [m for m in all_cloud if "flash" in m]
    spark_cloud = [m for m in all_cloud if "kimi" in m or "pro" in m]

    ELIGIBILITY_SETS = {
        "tier2_cloud_all":   all_cloud,
        "tier2_cloud_fast":  fast_cloud,
        "tier2_cloud_flash": flash_cloud,
        "tier2_cloud_spark": spark_cloud,
        "none":              [],
    }

    # ------------------------------------------------------------------
    # Compute changes
    # ------------------------------------------------------------------
    changes = []
    updated_policy = copy.deepcopy(policy)

    for agent_id, eligibility in ELIGIBILITY_MATRIX.items():
        agent = updated_policy.get("agents", {}).get(agent_id)
        if not agent:
            continue

        eligible_cloud = ELIGIBILITY_SETS.get(eligibility, [])
        base = list(ANTHROPIC_BASE_CRONS.get(agent_id, []))

        # Build target: base + eligible cloud (stable order, deduplicated)
        target = list(base)
        for m in eligible_cloud:
            if m not in target:
                target.append(m)

        current = agent.get("allowedInCrons", [])
        added   = [m for m in target if m not in current]
        removed = [m for m in current if m not in target]

        if added or removed:
            changes.append({
                "agent":   agent_id,
                "added":   added,
                "removed": removed,
                "before":  current,
                "after":   target,
            })
            updated_policy["agents"][agent_id]["allowedInCrons"] = target

        # Ensure Lex and Shield have all cloud models in prohibitedInCrons
        if eligibility == "none" and agent_id in ("legal", "security"):
            prohibited_crons = list(agent.get("prohibitedInCrons", []))
            newly_prohibited = []
            for m in all_cloud:
                if m not in prohibited_crons:
                    prohibited_crons.append(m)
                    newly_prohibited.append(m)
            if newly_prohibited:
                changes.append({
                    "agent": agent_id,
                    "added": [],
                    "removed": [],
                    "prohibitedAdded": newly_prohibited,
                })
                updated_policy["agents"][agent_id]["prohibitedInCrons"] = prohibited_crons

    # ------------------------------------------------------------------
    # Apply if requested
    # ------------------------------------------------------------------
    if args.apply and changes:
        if args.timestamp:
            updated_policy["lastUpdated"] = args.timestamp
            updated_policy["approvalContext"] = (
                f"allowlist-sync.sh auto-sync (source: {args.source}) -- {args.timestamp}"
            )
        with open(args.policy, "w") as f:
            json.dump(updated_policy, f, indent=2, ensure_ascii=False)

    # ------------------------------------------------------------------
    # Output result
    # ------------------------------------------------------------------
    result = {
        "hasChanges":          len(changes) > 0,
        "changeCount":         len(changes),
        "changes":             changes,
        "approvedCloudModels": all_cloud,
        "applied":             args.apply and len(changes) > 0,
    }
    print(json.dumps(result, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    main()
