#!/bin/bash
# scripts/main-session-resume-check.sh — TKT-0319 Atom 5
# Main-session / subagent resume registry check.
# Runs every heartbeat. Detects dead sessions for registered long-running
# non-TQP tasks and writes a NEEDS_KEN alert. The registry itself is updated
# with detected status so Yoda can present a resume decision to Ken.
#
# Registry: state/main-session-resume.json
# Needs-Ken alert: state/main-session-resume-needs-ken.json
#
# NOTE: Automatic re-spawn via sessions_spawn cannot be done from a shell
# script (no CLI spawn). Atom 5 therefore records the failure and surfaces it
# for HITL resume by Yoda in the main session.

set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsangiefpl/.openclaw/workspace}"
REGISTRY="$WORKSPACE_ROOT/state/main-session-resume.json"
NEEDS_KEN_FILE="$WORKSPACE_ROOT/state/main-session-resume-needs-ken.json"

now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Ensure registry exists
if [[ ! -f "$REGISTRY" ]]; then
  cat > "$REGISTRY" <<'JSON'
{"version":"1.0","tasks":[],"lastCheckAt":""}
JSON
fi

# Load current registry
REGISTRY_JSON=$(cat "$REGISTRY" 2>/dev/null || echo '{"version":"1.0","tasks":[],"lastCheckAt":""}')

# Fetch active sessions once per run
SESSIONS_JSON=$(openclaw sessions list --json 2>/dev/null || echo '{"sessions":[]}')

NEEDS_KEN=0
NEEDS_KEN_LIST="[]"

NOW=$(now_iso)

# Update registry via python. For each running task, check if its session is
# alive. If dead, mark status='session_lost' and add to NEEDS_KEN list.
python3 - "$REGISTRY" "$NEEDS_KEN_FILE" "$SESSIONS_JSON" "$NOW" <<'PY'
import json,sys,subprocess

registry_path=sys.argv[1]
needs_ken_path=sys.argv[2]
sessions_json=sys.argv[3]
now=sys.argv[4]

try:
    reg=json.load(open(registry_path))
except Exception:
    reg={"version":"1.0","tasks":[],"lastCheckAt":""}

try:
    sessions_data=json.loads(sessions_json)
except Exception:
    sessions_data={"sessions":[]}

active_keys=set()
for s in sessions_data.get("sessions",[]):
    active_keys.add(s.get("key"))
    active_keys.add(s.get("sessionKey"))
    active_keys.add(s.get("id"))

needs_ken=[]
for t in reg.get("tasks",[]):
    if t.get("status") != "running":
        continue
    session_key=t.get("sessionKey","")
    attempt=t.get("attempt",1)
    max_attempts=t.get("maxAttempts",3)

    if attempt >= max_attempts:
        t["status"]="failed"
        t["failure_reason"]="max_attempts_exceeded"
        t["updatedAt"]=now
        needs_ken.append({
            "id":t["id"],
            "reason":"max_attempts_exceeded",
            "description":t.get("description",""),
            "checkpoint":t.get("checkpoint",{})
        })
        continue

    if session_key in active_keys:
        continue

    # Session is dead
    t["status"]="session_lost"
    t["detectedDeadAt"]=now
    t["failure_reason"]="session_lost"
    needs_ken.append({
        "id":t["id"],
        "reason":"session_lost_requires_hitl_resume",
        "description":t.get("description",""),
        "agentId":t.get("agentId",""),
        "sessionKey":session_key,
        "checkpoint":t.get("checkpoint",{}),
        "requiresExecInParentWorkspace":t.get("requiresExecInParentWorkspace",False),
        "destructive":t.get("destructive",False)
    })

reg["lastCheckAt"]=now
json.dump(reg,open(registry_path,"w"),indent=2)

if needs_ken:
    json.dump({
        "generatedAt":now,
        "count":len(needs_ken),
        "tasks":needs_ken
    },open(needs_ken_path,"w"),indent=2)
    print(f"MAIN_SESSION_RESUME: {len(needs_ken)} task(s) need Ken approval -> {needs_ken_path}")
else:
    # Remove stale alert if present
    try:
        import os
        os.remove(needs_ken_path)
    except FileNotFoundError:
        pass
    print("MAIN_SESSION_RESUME: all registered sessions alive")
PY

exit 0
