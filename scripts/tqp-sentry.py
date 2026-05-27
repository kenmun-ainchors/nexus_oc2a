import os, sys, json, time, subprocess, re

# CONFIGURATION
LOG_FILE = "/Users/ainchorsangiefpl/.openclaw/logs/gateway.log" # Adjust if actual path differs
WORKSPACE_ROOT = "/Users/ainchorsangiefpl/.openclaw/workspace"
CANVAS_ROOT = "/Users/ainchorsangiefpl/.openclaw/canvas"
TQP_TABLE = "state_task_queue"

# SMART FILTERING: Paths that do NOT trigger a violation
IGNORE_PATHS = [
    "/tmp",
    ".log",
    "cache",
    "tmp"
]

def is_protected_path(path):
    if not path: return False
    if any(p in path for p in IGNORE_PATHS): return False
    return path.startswith(WORKSPACE_ROOT) or path.startswith(CANVAS_ROOT)

def check_tqp_persistence(session_id, tkt_id):
    # Query PG to see if the current TKT has a 'completed' or 'pending' atom in the last 60 seconds
    # This is a simplified check; in production, we'd check for the specific atom index.
    query = f"SELECT count(*) FROM {TQP_TABLE} WHERE id='{tkt_id}' AND updated_at > now() - interval '1 minute';"
    try:
        res = subprocess.check_output(["/Users/ainchorsangiefpl/.openclaw/workspace/scripts/db.sh", "-c", query], text=True)
        return int(res.strip()) > 0
    except:
        return False

def send_alert(session_id, details):
    # Inject as a system event via the gateway API or a specialized script
    alert_text = f"🚩 [S-Sentry] TQP VIOLATION: {details}. REQUIRED ACTION: Call sc_persist_atom immediately."
    # Using the system event trigger via the gateway
    subprocess.run(["/Users/ainchorsangiefpl/.openclaw/workspace/scripts/telegram-alert.sh", "TQP_VIOLATION", alert_text])

def log_violation(session_id, tkt_id, tool, path):
    log_entry = {
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "session_id": session_id,
        "tkt_id": tkt_id,
        "tool": tool,
        "path": path
    }
    with open("/Users/ainchorsangiefpl/.openclaw/workspace/state/compliance-violations.jsonl", "a") as f:
        f.write(json.dumps(log_entry) + "\n")

def main():
    print("Sentry active. Monitoring for TQP violations...")
    # Simple tail -f simulation
    with open(LOG_FILE, "r") as f:
        f.seek(0, 2) # Go to end
        while True:
            line = f.readline()
            if not line:
                time.sleep(0.5)
                continue
            
            # L3 Mitigation: Watch for BOTH direct 'write' and 'exec' (which might hide writes)
            if "tool_call" in line and ("write" in line or "exec" in line):
                try:
                    data = json.loads(line)
                    tool = data.get("tool")
                    args = data.get("arguments", {})
                    path = args.get("path", "") if tool == "write" else ""
                    tkt_id = data.get("tkt_id", "UNKNOWN") # Assume TKT is passed in context
                    
                    if (tool == "write" and is_protected_path(path)) or (tool == "exec"):
                        if not check_tqp_persistence(data.get("session_id"), tkt_id):
                            details = f"Naked {tool} call to {path if path else 'shell'} without TQP gate"
                            send_alert(data.get("session_id"), details)
                            log_violation(data.get("session_id"), tkt_id, tool, path)
                except:
                    pass

if __name__ == "__main__":
    main()
