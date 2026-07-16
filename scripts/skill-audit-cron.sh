#!/usr/bin/env zsh
# skill-audit-cron.sh — Weekly automated skill security audit
# TKT-0141 | Shield 🛡️ | CHG-0301
# Schedule: Every Sunday 02:00 AEST
# LaunchAgent: com.ainchors.shield.skill-audit
#
# Behaviour:
#   - Reads all skills from state/skill-registry.json
#   - Runs audit-skill.sh --path <SKILL.md> for each skill
#   - Aggregates results into state/skill-audit-report-YYYY-MM-DD.json
#   - BLOCK found   → Telegram alert to Ken immediately
#   - FLAG found    → included in report (no immediate alert)
#   - All CLEAR     → log only, no alert
#   - Updates state/skill-audit-state.json after run

set -uo pipefail

# ── Paths ─────────────────────────────────────────────────────────────────────
# Derive WORKSPACE from the script's actual location (portable across usernames).
# Script lives at <WORKSPACE>/scripts/skill-audit-cron.sh, so go up one level.
# Allow env override: WORKSPACE.
if [[ -z "${WORKSPACE:-}" ]]; then
  # ${(%):-%x} gives the script path under zsh (direct invocation);
  # $0 is the fallback for `zsh <script>` style invocation.
  # Resolve relative paths against $PWD.
  _script_path="${(%):-%x}"
  [[ "$_script_path" == /* ]] || _script_path="$0"
  [[ "$_script_path" == /* ]] || _script_path="$PWD/$0"
  _script_dir="$(cd "$(dirname "$_script_path")" 2>/dev/null && pwd)"
  if [[ -z "$_script_dir" || "$_script_dir" == "/" ]]; then
    # Last-resort: assume we're invoked from <WORKSPACE>/scripts/
    _script_dir="$PWD"
  fi
  WORKSPACE="$(cd "$_script_dir/.." 2>/dev/null && pwd)"
  unset _script_path _script_dir
fi
AUDIT_SCRIPT="${WORKSPACE}/scripts/audit-skill.sh"
REGISTRY="${WORKSPACE}/state/skill-registry.json"
STATE_FILE="${WORKSPACE}/state/skill-audit-state.json"

DATE_STAMP="$(date '+%Y-%m-%d')"
RUN_TS="$(date -Iseconds)"
REPORT_FILE="${WORKSPACE}/state/skill-audit-report-${DATE_STAMP}.json"
RESULTS_TMPDIR="$(mktemp -d /tmp/shield-audit-XXXXXX)"
trap "rm -rf ${RESULTS_TMPDIR}" EXIT

TELEGRAM_SCRIPT="${WORKSPACE}/scripts/telegram-alert.sh"

# ── Validate prerequisites ────────────────────────────────────────────────────
if [[ ! -f "${AUDIT_SCRIPT}" ]]; then
  echo "❌ audit-skill.sh not found at ${AUDIT_SCRIPT}" >&2
  exit 1
fi

if [[ ! -f "${REGISTRY}" ]]; then
  echo "❌ skill-registry.json not found at ${REGISTRY}" >&2
  exit 1
fi

echo "🛡️  Shield Skill Audit — ${DATE_STAMP}"
echo "========================================="

# ── Read skills from registry ─────────────────────────────────────────────────
SKILL_PATHS=()
while IFS= read -r line; do
  SKILL_PATHS+=("$line")
done < <(python3 -c "
import json
with open('${REGISTRY}') as f:
    d = json.load(f)
for s in d.get('skills', []):
    p = s.get('path', '')
    if p:
        print(p)
")

TOTAL=${#SKILL_PATHS[@]}
echo "📋 Skills to audit: ${TOTAL}"
echo ""

# ── Audit each skill ──────────────────────────────────────────────────────────
BLOCKED=0
FLAGGED=0
CLEARED=0
MISSING=0
IDX=0

for SKILL_PATH in "${SKILL_PATHS[@]}"; do
  SKILL_NAME="$(basename $(dirname ${SKILL_PATH}) 2>/dev/null || echo unknown)"
  RESULT_FILE="${RESULTS_TMPDIR}/${IDX}.json"
  (( IDX += 1 ))

  if [[ ! -f "${SKILL_PATH}" ]]; then
    echo "  ❓ MISSING: ${SKILL_NAME}"
    echo "{\"name\":\"${SKILL_NAME}\",\"path\":\"${SKILL_PATH}\",\"verdict\":\"MISSING\",\"blocks\":0,\"flags\":0,\"findings\":[]}" > "${RESULT_FILE}"
    (( MISSING += 1 ))
    continue
  fi

  # Run audit — capture text output + exit code
  AUDIT_TEXT="$(zsh "${AUDIT_SCRIPT}" --path "${SKILL_PATH}" 2>/dev/null)"
  AUDIT_EXIT=$?

  case $AUDIT_EXIT in
    0) VERDICT="CLEAR";  (( CLEARED += 1 )) ;;
    1) VERDICT="FLAG";   (( FLAGGED += 1 )) ;;
    2) VERDICT="BLOCK";  (( BLOCKED += 1 )) ;;
    *) VERDICT="ERROR";  (( MISSING += 1 )) ;;
  esac

  STATUS_ICON="✅"
  [[ "$VERDICT" == "FLAG" ]]  && STATUS_ICON="⚠️ "
  [[ "$VERDICT" == "BLOCK" ]] && STATUS_ICON="🚫"
  [[ "$VERDICT" == "MISSING" || "$VERDICT" == "ERROR" ]] && STATUS_ICON="❓"

  echo "  ${STATUS_ICON} ${VERDICT}: ${SKILL_NAME}"

  # Parse text output into structured JSON
  SAFE_TEXT="${AUDIT_TEXT//\\/\\\\}"
  python3 << PYEOF > "${RESULT_FILE}"
import sys, re, json

text = """${AUDIT_TEXT}"""
skill_name = "${SKILL_NAME}"
skill_path = "${SKILL_PATH}"
verdict    = "${VERDICT}"
exit_code  = ${AUDIT_EXIT}

# Parse findings from text output format:
#   ⚠️  [FLAG] description (line N)
#   🚫 [BLOCK] description (line N)
#      Content: ...
#      Note: ...

findings = []
lines_list = text.split('\n')

i = 0
while i < len(lines_list):
    line = lines_list[i]
    # Match finding header lines
    m = re.search(r'\[(BLOCK|FLAG)\]\s+(.+?)\s+\(line\s+(\d+)\)', line)
    if m:
        severity    = m.group(1)
        description = m.group(2).strip()
        lineno      = int(m.group(3))
        content     = ""
        note        = ""
        # Look for Content/Note on next lines
        if i + 1 < len(lines_list):
            cn = lines_list[i + 1].strip()
            if cn.startswith('Content:'):
                content = cn[len('Content:'):].strip()
                i += 1
        if i + 1 < len(lines_list):
            nn = lines_list[i + 1].strip()
            if nn.startswith('Note:'):
                note = nn[len('Note:'):].strip()
                i += 1
        findings.append({
            'severity': severity,
            'description': description,
            'line': lineno,
            'content': content,
            'note': note
        })
    i += 1

block_findings = [f for f in findings if f['severity'] == 'BLOCK']
flag_findings  = [f for f in findings if f['severity'] == 'FLAG']

result = {
    'name': skill_name,
    'path': skill_path,
    'verdict': verdict,
    'blocks': len(block_findings),
    'flags': len(flag_findings),
    'findings': findings
}
print(json.dumps(result, indent=2))
PYEOF

done

echo ""
echo "─────────────────────────────────────────"
echo "📊 Summary: ${TOTAL} skills"
echo "  ✅ CLEAR:   ${CLEARED}"
echo "  ⚠️  FLAG:    ${FLAGGED}"
echo "  🚫 BLOCK:   ${BLOCKED}"
echo "  ❓ MISSING: ${MISSING}"
echo ""

# ── Aggregate all per-skill JSON results into final report ────────────────────
python3 << PYEOF
import json, os

results_dir = "${RESULTS_TMPDIR}"
report_file = "${REPORT_FILE}"
date_stamp  = "${DATE_STAMP}"
run_ts      = "${RUN_TS}"
total       = ${TOTAL}
cleared     = ${CLEARED}
flagged     = ${FLAGGED}
blocked     = ${BLOCKED}
missing     = ${MISSING}

skills_list = []
for i in range(total):
    result_path = os.path.join(results_dir, f"{i}.json")
    if os.path.isfile(result_path):
        try:
            with open(result_path) as f:
                content = f.read().strip()
                if content:
                    skills_list.append(json.loads(content))
                else:
                    skills_list.append({"index": i, "error": "empty result"})
        except Exception as e:
            skills_list.append({"index": i, "error": str(e)})

overall = "BLOCK" if blocked > 0 else ("FLAG" if flagged > 0 else "CLEAR")

report = {
    "runDate": date_stamp,
    "runTimestamp": run_ts,
    "tkt": "TKT-0141",
    "owner": "Shield",
    "overall": overall,
    "totalSkills": total,
    "cleared": cleared,
    "flagged": flagged,
    "blocked": blocked,
    "missing": missing,
    "skills": skills_list
}

with open(report_file, 'w') as f:
    json.dump(report, f, indent=2)

print(f"📄 Report written: {report_file}")
print(f"   Overall verdict: {overall}")

# Print blocked skills summary
blocks_found = [s for s in skills_list if s.get('verdict') == 'BLOCK']
if blocks_found:
    print(f"\n🚫 BLOCKED skills ({len(blocks_found)}):")
    for s in blocks_found:
        name = s.get('name', '?')
        for bf in [f for f in s.get('findings', []) if f.get('severity') == 'BLOCK']:
            print(f"   • {name}: [{bf.get('description','?')}] line {bf.get('line','?')}")
PYEOF

# ── Update state file ─────────────────────────────────────────────────────────
NEXT_RUN="$(python3 -c "
from datetime import datetime, timedelta
try:
    import pytz
    tz = pytz.timezone('Australia/Melbourne')
    now = datetime.now(tz)
    days_ahead = (6 - now.weekday()) % 7
    if days_ahead == 0:
        days_ahead = 7
    next_sunday = (now + timedelta(days=days_ahead)).replace(hour=2, minute=0, second=0, microsecond=0)
    print(next_sunday.isoformat())
except Exception:
    print('next-sunday-02:00-AEST')
" 2>/dev/null || echo "next-sunday-02:00-AEST")"

python3 << PYEOF2
import json, os

state_file  = "${STATE_FILE}"
report_file = "${REPORT_FILE}"
run_ts      = "${RUN_TS}"
next_run    = "${NEXT_RUN}"
total       = ${TOTAL}
cleared     = ${CLEARED}
flagged     = ${FLAGGED}
blocked     = ${BLOCKED}

existing = {}
if os.path.isfile(state_file):
    try:
        with open(state_file) as f:
            existing = json.load(f)
    except Exception:
        pass

reports = existing.get("reports", [])
if report_file not in reports:
    reports.append(report_file)

state = {
    "lastRun": run_ts,
    "nextRun": next_run,
    "totalSkills": total,
    "cleared": cleared,
    "flagged": flagged,
    "blocked": blocked,
    "reports": reports
}

with open(state_file, 'w') as f:
    json.dump(state, f, indent=2)

print(f"📝 State updated: {state_file}")
print(f"   Next scheduled: {next_run}")
PYEOF2

# ── Telegram alerts ───────────────────────────────────────────────────────────
OVERALL="$(python3 -c "import json; d=json.load(open('${REPORT_FILE}')); print(d['overall'])" 2>/dev/null || echo "UNKNOWN")"

if [[ "${BLOCKED}" -gt 0 ]]; then
  echo ""
  echo "🚨 BLOCK(S) FOUND — alerting Ken via Telegram..."

  BLOCKED_NAMES="$(python3 -c "
import json
d = json.load(open('${REPORT_FILE}'))
blocks = [s.get('name', '?') for s in d.get('skills', []) if s.get('verdict') == 'BLOCK']
print(', '.join(blocks))
" 2>/dev/null || echo "(see report)")"

  MSG="🚫 SHIELD ALERT — Skill Audit BLOCKED

Date: ${DATE_STAMP}
Skills audited: ${TOTAL}
🚫 BLOCKED: ${BLOCKED} — ${BLOCKED_NAMES}
⚠️ Flagged: ${FLAGGED}
✅ Cleared: ${CLEARED}

ACTION: Review report
state/skill-audit-report-${DATE_STAMP}.json

TKT: TKT-0141"

  # TKT-1004 (CHG-0898) + CHG-0799: route platform alert to BOTH Ken + Angie.
  zsh "${TELEGRAM_SCRIPT}" --message "${MSG}" --recipients "8574109706,8141152780" 2>&1 || echo "⚠️  Telegram alert failed (non-fatal)"

elif [[ "${FLAGGED}" -gt 0 ]]; then
  echo "⚠️  ${FLAGGED} FLAG(S) logged — no immediate alert (weekly summary only)"
else
  echo "✅ All skills CLEAR — no alert needed"
fi

echo ""
echo "═════════════════════════════════════════"
echo "🛡️  Shield Skill Audit complete — ${DATE_STAMP}"
echo "   Overall verdict : ${OVERALL}"
echo "   Report          : ${REPORT_FILE}"
echo "═════════════════════════════════════════"
