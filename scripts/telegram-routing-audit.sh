#!/bin/bash
# =============================================================================
# telegram-routing-audit.sh — AInchors Telegram Routing Integrity Check
# =============================================================================
# Validates that ALL outbound Telegram cron deliveries route through the
# correct bot account. Prevents cross-bot messaging (e.g. Yoda messaging Angie,
# or future Yoda/Aria messaging clients via the wrong bot).
#
# Routing policy (enforced):
#   chatId 8574109706 (Ken)    → accountId: "yoda"  or unset (yoda is default)
#   chatId 8141152780 (Angie)  → accountId: "aria"  REQUIRED — strict
#   Any other chatId           → warned (add to policy when using client bots)
#
# Exit codes:
#   0 — all routing checks pass
#   1 — one or more routing violations found
#
# Usage:
#   bash scripts/telegram-routing-audit.sh          # full output
#   bash scripts/telegram-routing-audit.sh --quiet  # silent unless violations
#   bash scripts/telegram-routing-audit.sh --fix    # auto-fix known violations
#
# State:  state/telegram-routing-audit.json
# Used by: pvt.sh (check 11), auto-heal.sh (check 13)
# =============================================================================

set -uo pipefail

WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
STATE_DIR="$WORKSPACE/state"
RESULT_FILE="$STATE_DIR/telegram-routing-audit.json"
QUIET="${1:-}"
FIX_MODE=""
[[ "${1:-}" == "--fix" || "${2:-}" == "--fix" ]] && FIX_MODE="yes"

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log() {
  [[ "$QUIET" != "--quiet" ]] && echo -e "$1"
}

log ""
log "${CYAN}${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
log "${CYAN}${BOLD}║  Telegram Routing Audit                          ║${RESET}"
log "${CYAN}${BOLD}╚══════════════════════════════════════════════════╝${RESET}"
log ""

# ── All logic in Python (avoids bash 3.x associative array limits) ────────────
AUDIT_RESULT=$(python3 << 'PYEOF'
import json, subprocess, sys

result = subprocess.run(['openclaw', 'cron', 'list', '--json'], capture_output=True, text=True)
if result.returncode != 0 or not result.stdout.strip():
    print(json.dumps({'error': 'cron list failed', 'violations': [], 'passes': [], 'warnings': []}))
    sys.exit(0)

try:
    cron_data = json.loads(result.stdout)
except json.JSONDecodeError as e:
    print(json.dumps({'error': f'JSON parse error: {e}', 'violations': [], 'passes': [], 'warnings': []}))
    sys.exit(0)

jobs = cron_data.get('jobs', [])

# Routing policy
# strict=True means the accountId MUST be set to this value
# CHG-0799: platform/cron/infra/business-impacting alerts may route via Yoda to Angie
routing_policy = {
    "8574109706": {"account": "yoda",  "strict": False},  # Ken  — yoda default ok
    "8141152780": {"account": "aria",  "strict": True,    # Angie — aria REQUIRED unless tagged
                   "except_on_tag": ["platform", "cron", "infra", "business"]},  # CHG-0799: Yoda ok if tagged
}

violations = []
passes = []
warnings = []

for job in jobs:
    delivery = job.get('delivery', {})
    if not delivery or delivery.get('mode') != 'announce':
        continue
    channel = str(delivery.get('channel', ''))
    if 'telegram' not in channel:
        continue

    to = str(delivery.get('to', ''))
    account_id = delivery.get('accountId') or None
    job_id = job.get('id', '')
    job_name = job.get('name', 'unnamed')

    if not to:
        warnings.append({'job': job_name, 'id': job_id,
                         'issue': 'Telegram delivery with no "to" field — cannot validate routing'})
        continue

    policy = routing_policy.get(to)

    if policy is None:
        warnings.append({'job': job_name, 'id': job_id, 'chatId': to,
                         'issue': f'chatId {to} not in routing policy — add entry when connecting client bots'})
        continue

    expected = policy['account']
    strict = policy['strict']

    # CHG-0799: Check if this job has a tag that exempts from strict routing
    exempt = False
    if strict and account_id != expected:
        except_tags = policy.get("except_on_tag", [])
        if except_tags:
            job_tags = job.get("tags", [])
            job_name_lower = job_name.lower()
            for tag in except_tags:
                if tag in str(job_tags) or tag in job_name_lower:
                    exempt = True
                    break
    if strict and account_id != expected and not exempt:
        violations.append({
            'job': job_name, 'id': job_id, 'chatId': to,
            'issue': f'Must use accountId="{expected}" for chatId {to} — got "{account_id}". Wrong bot will deliver.',
            'fix_accountId': expected,
            'fix_to': to
        })
    elif not strict and account_id not in (expected, None, ''):
        violations.append({
            'job': job_name, 'id': job_id, 'chatId': to,
            'issue': f'Unexpected accountId="{account_id}" for chatId {to} — expected "{expected}" or unset'
        })
    else:
        passes.append({'job': job_name, 'id': job_id, 'to': to,
                       'accountId': account_id or f'{expected}(default)'})

print(json.dumps({'violations': violations, 'passes': passes, 'warnings': warnings}))
PYEOF
)

# ── Check for error ───────────────────────────────────────────────────────────
if echo "$AUDIT_RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if 'error' not in d else 1)" 2>/dev/null; then
  :
else
  ERR=$(echo "$AUDIT_RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('error','unknown'))" 2>/dev/null)
  log "${RED}❌ FAIL${RESET}  Audit error: $ERR"
  echo "{\"status\":\"error\",\"error\":\"$ERR\",\"at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > "$RESULT_FILE"
  exit 1
fi

VIOLATION_COUNT=$(echo "$AUDIT_RESULT" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['violations']))")
PASS_COUNT=$(echo "$AUDIT_RESULT" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['passes']))")
WARN_COUNT=$(echo "$AUDIT_RESULT" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['warnings']))")

# ── Print violations ──────────────────────────────────────────────────────────
if [[ "$VIOLATION_COUNT" -gt 0 ]]; then
  log "${RED}${BOLD}❌ VIOLATIONS ($VIOLATION_COUNT):${RESET}"
  echo "$AUDIT_RESULT" | python3 -c "
import json,sys
for v in json.load(sys.stdin)['violations']:
    print(f\"  \u274c  [{v['id'][:8]}] {v['job']}\")
    print(f\"      Issue: {v['issue']}\")
    print()
"
else
  log "${GREEN}✅ No routing violations found${RESET}"
fi

# ── Print passes ──────────────────────────────────────────────────────────────
if [[ "$PASS_COUNT" -gt 0 ]]; then
  log "${GREEN}${BOLD}✅ CORRECT ($PASS_COUNT):${RESET}"
  echo "$AUDIT_RESULT" | python3 -c "
import json,sys
for p in json.load(sys.stdin)['passes']:
    print(f\"  \u2705  [{p['id'][:8]}] {p['job']}  \u2192  chatId:{p['to']} via {p['accountId']}\")
"
fi

# ── Print warnings ────────────────────────────────────────────────────────────
if [[ "$WARN_COUNT" -gt 0 ]]; then
  log ""
  log "${YELLOW}${BOLD}⚠️  WARNINGS ($WARN_COUNT) — unknown chatIds (review when adding clients):${RESET}"
  echo "$AUDIT_RESULT" | python3 -c "
import json,sys
for w in json.load(sys.stdin)['warnings']:
    print(f\"  \u26a0\ufe0f   [{w['id'][:8]}] {w['job']}: {w['issue']}\")
"
fi

# ── Auto-fix mode ─────────────────────────────────────────────────────────────
if [[ "$FIX_MODE" == "yes" ]] && [[ "$VIOLATION_COUNT" -gt 0 ]]; then
  log ""
  log "${CYAN}${BOLD}🔧 Auto-fix mode — applying corrections...${RESET}"
  echo "$AUDIT_RESULT" | python3 -c "
import json, sys, subprocess

for v in json.load(sys.stdin)['violations']:
    fix_acct = v.get('fix_accountId')
    fix_to   = v.get('fix_to')
    if fix_acct and fix_to:
        job_id = v['id']
        patch = json.dumps({'delivery': {'mode': 'announce', 'channel': 'telegram',
                                          'accountId': fix_acct, 'to': fix_to}})
        r = subprocess.run(['openclaw', 'cron', 'update', '--id', job_id, '--patch', patch],
                           capture_output=True, text=True)
        status = '\u2705 Fixed' if r.returncode == 0 else f'\u274c Failed: {r.stderr[:100]}'
        print(f'  {status}  [{job_id[:8]}] {v[\"job\"]} \u2192 accountId=\"{fix_acct}\"')
    else:
        print(f'  \u26a0\ufe0f  No auto-fix for: {v[\"job\"]} — manual review required')
"
fi

# ── Write state file ──────────────────────────────────────────────────────────
RUN_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "$AUDIT_RESULT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['auditAt'] = '$RUN_ISO'
d['summary'] = {'violations': len(d['violations']), 'passes': len(d['passes']), 'warnings': len(d['warnings'])}
d['status'] = 'fail' if d['violations'] else 'pass'
print(json.dumps(d, indent=2))
" > "$RESULT_FILE"

# ── Check Aria ARIA_RULES.md for explicit accountId enforcement ──────────────
ARIA_RULES="/Users/ainchorsoc2a/.openclaw/workspace-business/ARIA_RULES.md"
if [[ -f "$ARIA_RULES" ]]; then
  if grep -q "accountId: aria\|--account aria" "$ARIA_RULES" 2>/dev/null; then
    log "${GREEN}✅ Aria in-session rules${RESET}  ARIA_RULES.md enforces accountId:aria for proactive sends"
  else
    log "${YELLOW}⚠️  Aria in-session rules${RESET}  ARIA_RULES.md missing accountId:aria directive — proactive sends may use wrong bot"
  fi
fi

# ── Exit ──────────────────────────────────────────────────────────────────────
log ""
if [[ "$VIOLATION_COUNT" -gt 0 ]]; then
  log "${RED}${BOLD}RESULT: FAIL — $VIOLATION_COUNT routing violation(s). Run with --fix to auto-correct.${RESET}"
  log ""
  exit 1
else
  log "${GREEN}${BOLD}RESULT: PASS — all Telegram routing correct ($PASS_COUNT checked).${RESET}"
  log ""
  exit 0
fi
