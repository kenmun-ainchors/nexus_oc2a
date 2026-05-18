#!/usr/bin/env bash
# warden-cron.sh — Warden compliance cron runner
# Runs model-drift-check.sh, logs outcome, writes escalation if needed.
# Designed for minimal LLM interaction — just run this one script.
# TKT-0013 / CHG-WARDEN / CHG-0394: Permanent baseline — no interim skip logic

set -uo pipefail

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
cd "$WORKSPACE"

# Step 1: Run compliance check (silent) against permanent baseline
bash scripts/model-drift-check.sh > /dev/null 2>&1
EXIT_CODE=$?

# Step 2: Log outcome
STATUS="pass"
NOTES="warden check (permanent baseline CHG-0394)"
if [[ $EXIT_CODE -ne 0 ]]; then
  STATUS="fail"
  NOTES="warden check: violations detected (exit $EXIT_CODE)"
fi

bash scripts/log-delegation.sh \
  --tier T2 \
  --task-type warden-check \
  --model "ollama/gemma4:31b-cloud" \
  --status "$STATUS" \
  --notes "$NOTES" > /dev/null 2>&1 || true

# Step 3: On violations (exit 2), write escalation file
if [[ $EXIT_CODE -eq 2 ]]; then
  /usr/bin/python3 << 'PYEOF'
import json
from datetime import datetime, timezone

ws = "/Users/ainchorsangiefpl/.openclaw/workspace"

with open(f"{ws}/state/model-drift-violations.json") as f:
    violations = json.load(f)

unresolved = [v for v in violations.get("violations", []) if v.get("status") not in ("resolved", "superseded")]

if unresolved:
    escalation = {
        "escalatedAt": datetime.now(timezone.utc).isoformat(),
        "status": "pending-yoda-action",
        "activeViolations": unresolved,
        "totalUnresolvedViolations": len(unresolved),
        "remediation": {
            "actionRequired": [f"Fix agent {v['agentId']}: expected {v.get('expected')} got {v.get('actual')}" for v in unresolved[:5]]
        }
    }
    with open(f"{ws}/state/warden-escalation-pending.json", "w") as f:
        json.dump(escalation, f, indent=2)

    # Mark escalated in violations file
    for v in violations.get("violations", []):
        if v.get("status") not in ("resolved", "superseded"):
            v["escalatedToYoda"] = True
    with open(f"{ws}/state/model-drift-violations.json", "w") as f:
        json.dump(violations, f, indent=2)

    print(f"ESCALATED: {len(unresolved)} violations")
else:
    print("CLEAN: no unresolved violations")
PYEOF
else
  echo "CLEAN: exit $EXIT_CODE"
fi

exit 0
