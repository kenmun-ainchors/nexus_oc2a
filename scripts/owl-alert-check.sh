#!/usr/bin/env python3
"""
owl-alert-check.sh — Heartbeat OWL Alert Checker
Checks for unacknowledged OWL drift alerts and surfaces to Ken.
Usage: zsh scripts/owl-alert-check.sh
"""
import json
import sys
from datetime import datetime, timedelta

ALERT_FILE = "/Users/ainchorsangiefpl/.openclaw/workspace/state/owl-drift-alert.json"

def main():
    try:
        with open(ALERT_FILE) as f:
            alerts = json.load(f)
        
        active = alerts.get("activeAlerts", [])
        now = datetime.now()
        
        # Filter unacknowledged alerts older than 2 hours
        unacknowledged = []
        for alert in active:
            if not alert.get("acknowledged", False):
                alert_time = datetime.fromisoformat(alert["timestamp"].replace('Z', '+00:00'))
                age_hours = (now - alert_time).total_seconds() / 3600
                
                if age_hours >= 2:
                    unacknowledged.append({
                        "id": alert["id"],
                        "type": alert["type"],
                        "severity": alert["severity"],
                        "age_hours": round(age_hours, 1),
                        "score": alert["details"]["complianceScore"],
                        "message": alert["message"]
                    })
        
        if not unacknowledged:
            print("✅ No unacknowledged OWL drift alerts")
            sys.exit(0)
        
        # Sort by severity
        severity_order = {"critical": 0, "high": 1, "medium": 2, "low": 3}
        unacknowledged.sort(key=lambda x: severity_order.get(x["severity"], 99))
        
        print(f"⚠️ UNACKNOWLEDGED OWL DRIFT ALERTS: {len(unacknowledged)}")
        for alert in unacknowledged:
            print(f"\n🚨 {alert['id']} [{alert['severity'].upper()}]")
            print(f"   Age: {alert['age_hours']}h unacknowledged")
            print(f"   Type: {alert['type']}")
            print(f"   Score: {alert['score']}%")
            print(f"   {alert['message'][:70]}")
            print(f"   Acknowledge: python3 scripts/owl-alert.py --ack {alert['id']}")
        
        # Return error code if any critical/high
        critical = any(a["severity"] == "critical" for a in unacknowledged)
        high = any(a["severity"] == "high" for a in unacknowledged)
        
        if critical:
            sys.exit(3)
        elif high:
            sys.exit(2)
        else:
            sys.exit(1)
            
    except Exception as e:
        print(f"ERROR: Could not check alerts: {e}")
        sys.exit(2)

if __name__ == "__main__":
    main()
