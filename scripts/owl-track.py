#!/usr/bin/env python3
"""
owl-track.py — OWL Compliance Tracker
Updates owl-compliance-state.json after each response.
Usage: python3 owl-track.py --tier [1|2|3] --atoms N --thinking N --paused [true|false] --risk [true|false] --verified [true|false] --stopped [true|false]
"""
import json
import sys
import os
import argparse
from datetime import datetime

# Add lib to path for atomic_write import
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'lib'))
from atomic_write import atomic_write_json as atomic_write

STATE_FILE = "/Users/ainchorsangiefpl/.openclaw/workspace/state/owl-compliance-state.json"

def load_state():
    try:
        with open(STATE_FILE) as f:
            return json.load(f)
    except:
        return None

def save_state(state):
    return atomic_write(STATE_FILE, state)

def calculate_compliance(response):
    """Calculate compliance score 0-100 for a single response."""
    score = 100
    
    # Tier-specific minimum thinking time
    tier_mins = {
        "1": 10,   # 10 seconds
        "2": 180,  # 3 minutes
        "3": 300   # 5 minutes
    }
    
    tier = str(response.get('tier', '1'))
    thinking = response.get('thinkingTimeSeconds', 0)
    
    # Deduct for insufficient thinking
    min_thinking = tier_mins.get(tier, 10)
    if thinking < min_thinking:
        deduction = int((min_thinking - thinking) / min_thinking * 30)
        score -= min(deduction, 30)
    
    # Deduct for missing pause between atoms (Tier 2/3)
    if tier in ["2", "3"] and not response.get('hasPause', False):
        score -= 20
    
    # Deduct for not showing thinking
    if not response.get('hasShownThinking', False):
        score -= 15
    
    # Deduct for no risk assessment
    if not response.get('hasAssessedRisk', False):
        score -= 15
    
    # Deduct for not verifying atoms
    if not response.get('hasVerifiedAtoms', False):
        score -= 10
    
    # Deduct for error chain-reaction
    if not response.get('stoppedOnError', True):
        score -= 25
    
    return max(0, min(100, score))

def detect_drift(response, state):
    """Detect OWL drift patterns."""
    flags = {
        "chainReactionDetected": False,
        "insufficientPause": False,
        "noThinkingShown": False,
        "noRiskAssessment": False,
        "errorNotStopped": False
    }
    
    tier = str(response.get('tier', '1'))
    
    # Chain reaction: error not stopped
    if not response.get('stoppedOnError', True):
        flags["errorNotStopped"] = True
        flags["chainReactionDetected"] = True
    
    # Insufficient pause for Tier 2/3
    if tier in ["2", "3"] and not response.get('hasPause', False):
        flags["insufficientPause"] = True
    
    # No thinking shown
    if not response.get('hasShownThinking', False):
        flags["noThinkingShown"] = True
    
    # No risk assessment
    if not response.get('hasAssessedRisk', False):
        flags["noRiskAssessment"] = True
    
    return flags

def main():
    parser = argparse.ArgumentParser(description='OWL Compliance Tracker')
    parser.add_argument('--tier', type=str, default='1', help='Tier level (1|2|3)')
    parser.add_argument('--atoms', type=int, default=1, help='Number of atoms executed')
    parser.add_argument('--thinking', type=int, default=0, help='Thinking time in seconds')
    parser.add_argument('--paused', type=str, default='true', help='Had pause between atoms (true|false)')
    parser.add_argument('--risk', type=str, default='true', help='Assessed risk (true|false)')
    parser.add_argument('--verified', type=str, default='true', help='Verified atoms (true|false)')
    parser.add_argument('--stopped', type=str, default='true', help='Stopped on error (true|false)')
    parser.add_argument('--thinking-shown', type=str, default='true', help='Showed thinking (true|false)')
    
    args = parser.parse_args()
    
    state = load_state()
    if not state:
        print("ERROR: Could not load state file", file=sys.stderr)
        sys.exit(1)
    
    now = datetime.now().isoformat()
    
    # Build response record
    response = {
        "startedAt": now,
        "tier": args.tier,
        "thinkingTimeSeconds": args.thinking,
        "atomCount": args.atoms,
        "atoms": [],
        "pauseBetweenAtoms": [],
        "hasPause": args.paused.lower() == 'true',
        "hasShownThinking": args.thinking_shown.lower() == 'true',
        "hasAssessedRisk": args.risk.lower() == 'true',
        "hasVerifiedAtoms": args.verified.lower() == 'true',
        "stoppedOnError": args.stopped.lower() == 'true'
    }
    
    # Calculate compliance
    compliance = calculate_compliance(response)
    response["complianceScore"] = compliance
    
    # Detect drift
    flags = detect_drift(response, state)
    response["driftFlags"] = flags
    
    # Update state
    state["lastUpdated"] = now
    state["totalResponses"] = state.get("totalResponses", 0) + 1
    state["currentTier"] = args.tier
    state["currentResponse"] = response
    
    # Check for drift incidents
    is_drift = any(flags.values())
    if is_drift:
        state["driftIncidents"] = state.get("driftIncidents", 0) + 1
    
    # Update compliance score (rolling average)
    total = state["totalResponses"]
    current_avg = state.get("complianceScore", 100)
    new_avg = int((current_avg * (total - 1) + compliance) / total)
    state["complianceScore"] = new_avg
    
    # Add to history
    history = state.setdefault("history", {})
    last10 = history.setdefault("last10Responses", [])
    last10.append({
        "timestamp": now,
        "tier": args.tier,
        "compliance": compliance,
        "drift": is_drift
    })
    if len(last10) > 10:
        last10.pop(0)
    
    # Update daily summary
    today = datetime.now().strftime("%Y-%m-%d")
    daily = history.setdefault("dailySummary", {})
    if daily.get("date") != today:
        # New day — reset daily counters
        daily = {
            "date": today,
            "totalResponses": 0,
            "complianceScore": 100,
            "driftIncidents": 0,
            "selfCorrections": 0,
            "tierBreakdown": {"tier1": 0, "tier2": 0, "tier3": 0}
        }
    
    daily["totalResponses"] = daily.get("totalResponses", 0) + 1
    daily["driftIncidents"] = daily.get("driftIncidents", 0) + (1 if is_drift else 0)
    
    # Update tier breakdown
    tier_key = f"tier{args.tier}"
    daily["tierBreakdown"][tier_key] = daily["tierBreakdown"].get(tier_key, 0) + 1
    
    # Recalculate daily compliance
    daily_total = daily["totalResponses"]
    if daily_total > 0:
        daily["complianceScore"] = int(
            (daily["complianceScore"] * (daily_total - 1) + compliance) / daily_total
        )
    
    history["dailySummary"] = daily
    
    # Update drift flags
    state["driftFlags"] = flags
    
    save_state(state)
    
    # Output summary
    print(f"OWL Compliance: {compliance}% (Tier {args.tier}, {args.atoms} atoms)")
    if is_drift:
        drift_types = [k for k, v in flags.items() if v]
        print(f"⚠️ DRIFT DETECTED: {', '.join(drift_types)}")
    else:
        print("✅ Compliant")
    
    print(f"Daily: {daily['complianceScore']}% | Drifts today: {daily['driftIncidents']}")

if __name__ == "__main__":
    main()
