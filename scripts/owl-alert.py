#!/usr/bin/env python3
"""
owl-alert.py — OWL Drift Alert Generator
Monitors owl-compliance-state.json and generates alerts when drift detected.
Usage: python3 owl-alert.py [--check-only | --ack ID | --list]
"""
import json
import sys
import argparse
from datetime import datetime, timedelta

COMPLIANCE_FILE = "/Users/ainchorsangiefpl/.openclaw/workspace/state/owl-compliance-state.json"
ALERT_FILE = "/Users/ainchorsangiefpl/.openclaw/workspace/state/owl-drift-alert.json"

def load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception as e:
        print(f"ERROR: Could not load {path}: {e}", file=sys.stderr)
        return None

def save_json(path, data):
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)

def generate_alert_id():
    now = datetime.now()
    return f"OWL-{now.strftime('%Y%m%d-%H%M%S')}"

def get_severity(drift_flags, compliance_score):
    """Determine alert severity based on drift pattern."""
    active_flags = [k for k, v in drift_flags.items() if v]
    
    if compliance_score < 20:
        return "critical"
    elif compliance_score < 50:
        return "high"
    elif "errorNotStopped" in active_flags or "chainReactionDetected" in active_flags:
        return "high"
    elif len(active_flags) >= 3:
        return "medium"
    else:
        return "low"

def generate_message(alert_type, compliance_score, flags):
    """Generate human-readable alert message."""
    messages = {
        "chain-reaction": "⚠️ Chain reaction detected: Error occurred but execution continued without assessment",
        "insufficient-pause": "⚠️ Insufficient pause between atoms: Tier 2/3 work requires 3min+ pause",
        "no-thinking-shown": "⚠️ Thinking process not shown: Ken cannot verify deliberation occurred",
        "no-risk-assessment": "⚠️ Risk assessment missing: Execution proceeded without risk evaluation",
        "error-not-stopped": "⚠️ Error not stopped: Immediate fix attempted without pause/assessment",
        "multiple-drift-patterns": "⚠️ Multiple OWL violations detected in single response"
    }
    
    return messages.get(alert_type, f"⚠️ OWL drift detected: {alert_type}")

def check_and_generate():
    """Main monitoring function — check compliance state and generate alerts."""
    compliance = load_json(COMPLIANCE_FILE)
    alerts = load_json(ALERT_FILE)
    
    if not compliance or not alerts:
        return
    
    now = datetime.now()
    
    # Get current response data
    current = compliance.get("currentResponse", {})
    drift_flags = current.get("driftFlags", {})
    compliance_score = current.get("complianceScore", 100)
    
    # Check if any drift detected
    active_flags = {k: v for k, v in drift_flags.items() if v}
    
    if not active_flags:
        # No drift — clean up old alerts
        cleanup_old_alerts(alerts)
        save_json(ALERT_FILE, alerts)
        print("✅ No drift detected. Compliance OK.")
        return
    
    # Determine alert type
    if len(active_flags) >= 3:
        alert_type = "multiple-drift-patterns"
    elif "errorNotStopped" in active_flags:
        alert_type = "error-not-stopped"
    elif "chainReactionDetected" in active_flags:
        alert_type = "chain-reaction"
    elif "insufficientPause" in active_flags:
        alert_type = "insufficient-pause"
    elif "noThinkingShown" in active_flags:
        alert_type = "no-thinking-shown"
    elif "noRiskAssessment" in active_flags:
        alert_type = "no-risk-assessment"
    else:
        alert_type = "unknown"
    
    # Check if similar alert already active (deduplication)
    active_alerts = alerts.get("activeAlerts", [])
    for existing in active_alerts:
        if existing.get("type") == alert_type and not existing.get("acknowledged", False):
            # Update existing alert with latest data
            existing["details"] = {
                "tier": current.get("tier", "unknown"),
                "thinkingTimeSeconds": current.get("thinkingTimeSeconds", 0),
                "expectedThinkingMin": 180 if current.get("tier") == "2" else (300 if current.get("tier") == "3" else 10),
                "atomCount": current.get("atomCount", 0),
                "pauseBetweenAtoms": current.get("pauseBetweenAtoms", []),
                "complianceScore": compliance_score,
                "driftFlags": drift_flags
            }
            existing["timestamp"] = now.isoformat()
            save_json(ALERT_FILE, alerts)
            print(f"⚠️ Updated existing alert: {existing['id']} ({alert_type})")
            return
    
    # Generate new alert
    severity = get_severity(drift_flags, compliance_score)
    message = generate_message(alert_type, compliance_score, drift_flags)
    
    new_alert = {
        "id": generate_alert_id(),
        "timestamp": now.isoformat(),
        "sessionId": compliance.get("sessionId", "unknown"),
        "type": alert_type,
        "severity": severity,
        "message": message,
        "details": {
            "tier": current.get("tier", "unknown"),
            "thinkingTimeSeconds": current.get("thinkingTimeSeconds", 0),
            "expectedThinkingMin": 180 if current.get("tier") == "2" else (300 if current.get("tier") == "3" else 10),
            "atomCount": current.get("atomCount", 0),
            "pauseBetweenAtoms": current.get("pauseBetweenAtoms", []),
            "complianceScore": compliance_score,
            "driftFlags": drift_flags
        },
        "acknowledged": False,
        "acknowledgedAt": None,
        "acknowledgedBy": None,
        "autoClearAt": (now + timedelta(hours=24)).isoformat(),
        "escalated": False
    }
    
    active_alerts.append(new_alert)
    alerts["activeAlerts"] = active_alerts
    alerts["lastUpdated"] = now.isoformat()
    
    # Add to history
    history = alerts.setdefault("alertHistory", [])
    history.append({
        "id": new_alert["id"],
        "timestamp": new_alert["timestamp"],
        "type": alert_type,
        "severity": severity,
        "acknowledged": False
    })
    # Keep last 50 history entries
    if len(history) > 50:
        history = history[-50:]
    alerts["alertHistory"] = history
    
    save_json(ALERT_FILE, alerts)
    
    # Output alert
    print(f"🚨 OWL DRIFT ALERT: {new_alert['id']}")
    print(f"   Type: {alert_type}")
    print(f"   Severity: {severity.upper()}")
    print(f"   Score: {compliance_score}%")
    print(f"   Message: {message}")
    print(f"   Auto-clear: {new_alert['autoClearAt'][:16]}")
    
    # Return exit code based on severity
    if severity == "critical":
        sys.exit(3)
    elif severity == "high":
        sys.exit(2)
    elif severity == "medium":
        sys.exit(1)
    else:
        sys.exit(0)

def cleanup_old_alerts(alerts):
    """Remove acknowledged alerts older than 24h."""
    now = datetime.now()
    active = alerts.get("activeAlerts", [])
    
    cleaned = []
    for alert in active:
        if alert.get("acknowledged", False):
            # Keep acknowledged for 24h then remove
            ack_time = alert.get("acknowledgedAt", "")
            if ack_time:
                ack_dt = datetime.fromisoformat(ack_time.replace('Z', '+00:00'))
                if now - ack_dt < timedelta(hours=24):
                    cleaned.append(alert)
        else:
            # Check auto-clear
            clear_time = alert.get("autoClearAt", "")
            if clear_time:
                clear_dt = datetime.fromisoformat(clear_time.replace('Z', '+00:00'))
                if now < clear_dt:
                    cleaned.append(alert)
    
    alerts["activeAlerts"] = cleaned

def acknowledge_alert(alert_id, user="ken"):
    """Acknowledge an alert."""
    alerts = load_json(ALERT_FILE)
    if not alerts:
        return
    
    for alert in alerts.get("activeAlerts", []):
        if alert.get("id") == alert_id:
            alert["acknowledged"] = True
            alert["acknowledgedAt"] = datetime.now().isoformat()
            alert["acknowledgedBy"] = user
            save_json(ALERT_FILE, alerts)
            print(f"✅ Acknowledged alert: {alert_id}")
            return
    
    print(f"⚠️ Alert not found: {alert_id}")

def list_alerts():
    """List all active alerts."""
    alerts = load_json(ALERT_FILE)
    if not alerts:
        return
    
    active = alerts.get("activeAlerts", [])
    
    if not active:
        print("✅ No active OWL drift alerts")
        return
    
    print(f"=== ACTIVE ALERTS ({len(active)}) ===")
    for alert in active:
        status = "✅ ACK" if alert.get("acknowledged") else "⏳ PENDING"
        print(f"\n{alert['id']} [{status}]")
        print(f"  Type: {alert['type']}")
        print(f"  Severity: {alert['severity'].upper()}")
        print(f"  Score: {alert['details']['complianceScore']}%")
        print(f"  Time: {alert['timestamp'][:16]}")
        print(f"  Message: {alert['message'][:70]}")
        if not alert.get("acknowledged"):
            print(f"  Auto-clear: {alert['autoClearAt'][:16]}")

def main():
    parser = argparse.ArgumentParser(description='OWL Drift Alert System')
    parser.add_argument('--check-only', action='store_true', help='Check for drift without generating alert')
    parser.add_argument('--ack', type=str, help='Acknowledge alert by ID')
    parser.add_argument('--list', action='store_true', help='List all active alerts')
    parser.add_argument('--user', type=str, default='ken', help='User acknowledging alert')
    
    args = parser.parse_args()
    
    if args.ack:
        acknowledge_alert(args.ack, args.user)
    elif args.list:
        list_alerts()
    else:
        check_and_generate()

if __name__ == "__main__":
    main()
