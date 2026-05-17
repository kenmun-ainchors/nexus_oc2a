#!/usr/bin/env python3
"""
owl-check.sh — OWL Compliance Heartbeat Check
Returns current compliance status for heartbeat monitoring.
Usage: zsh scripts/owl-check.sh
"""
import json
import sys

STATE_FILE = "/Users/ainchorsangiefpl/.openclaw/workspace/state/owl-compliance-state.json"

def main():
    try:
        with open(STATE_FILE) as f:
            state = json.load(f)
        
        score = state.get("complianceScore", 100)
        total = state.get("totalResponses", 0)
        drifts = state.get("driftIncidents", 0)
        
        daily = state.get("history", {}).get("dailySummary", {})
        daily_score = daily.get("complianceScore", 100)
        daily_drifts = daily.get("driftIncidents", 0)
        
        # Output for heartbeat parsing
        print(f"OWL Compliance: {score}% (daily: {daily_score}%)")
        print(f"Responses today: {daily.get('totalResponses', 0)} | Drifts: {daily_drifts}")
        
        # Warning thresholds
        if daily_score < 70:
            print("⚠️ LOW COMPLIANCE — Review needed")
            sys.exit(1)
        elif daily_drifts >= 3:
            print("⚠️ MULTIPLE DRIFTS — OWL review required")
            sys.exit(1)
        else:
            print("✅ OWL compliant")
            sys.exit(0)
            
    except Exception as e:
        print(f"ERROR: Could not check OWL state: {e}")
        sys.exit(2)

if __name__ == "__main__":
    main()
