#!/usr/bin/env bash
# governance-report.sh — Ad-hoc Governance Gate Runner + Executive Summary
# Triggered by /governance keyword (Ken or Angie)
# Usage: bash governance-report.sh [--asset-path PATH] [--asset-type TYPE] [--brief "..."] [--intended-for "..."] [--produced-by AGENT]
# If no asset-path given: reports on the last governance run from state files.
# TKT-0017

export PATH="$PATH:/usr/local/bin:/opt/homebrew/bin"

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
RESULTS_FILE="$WORKSPACE/state/governance-results.json"
TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S+10:00")
AEST=$(date +"%Y-%m-%d %H:%M AEST")

ASSET_PATH=""; ASSET_TYPE=""; BRIEF=""; INTENDED_FOR=""; PRODUCED_BY="yoda"
REPORT_ONLY=false

while (( $# > 0 )); do
  case "$1" in
    --asset-path)   ASSET_PATH="$2"; shift 2 ;;
    --asset-type)   ASSET_TYPE="$2"; shift 2 ;;
    --brief)        BRIEF="$2"; shift 2 ;;
    --intended-for) INTENDED_FOR="$2"; shift 2 ;;
    --produced-by)  PRODUCED_BY="$2"; shift 2 ;;
    --report-only)  REPORT_ONLY=true; shift ;;
    *) echo "Unknown: $1" >&2; exit 2 ;;
  esac
done

# ── If no asset given, report on last run ────────────────────────────────────
if [ -z "$ASSET_PATH" ] || [ "$REPORT_ONLY" = true ]; then
  if [ -f "$RESULTS_FILE" ]; then
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  🏛️  GOVERNANCE GATE — EXECUTIVE SUMMARY"
    echo "  Last run: $(python3 -c "import json; d=json.load(open('$RESULTS_FILE')); print(d.get('timestamp','unknown'))" 2>/dev/null)"
    echo "════════════════════════════════════════════════════════════════"
    python3 << 'PYEOF'
import json, os

WORKSPACE = os.path.expanduser("~/.openclaw/workspace")
r_file = f"{WORKSPACE}/state/governance-results.json"

if not os.path.exists(r_file):
    print("  No governance results found. Run /governance with an asset to begin.")
    exit(0)

with open(r_file) as f:
    r = json.load(f)

print(f"\n  Asset:        {r.get('asset','unknown')}")
print(f"  Type:         {r.get('assetType','unknown')}")
print(f"  Produced by:  {r.get('producedBy','unknown')}")
print(f"  Intended for: {r.get('intendedFor','unknown')}")
print(f"  Brief:        {r.get('brief','unknown')[:80]}")

overall = r.get('overall','UNKNOWN')
overall_icon = "✅" if overall == "PASS" else "❌"
print(f"\n  OVERALL VERDICT: {overall_icon} {overall}")
print()

agents = [
    ("SHIELD 🛡️", "security", "shield", r.get('shield',{})),
    ("LEX ⚖️",    "legal",    "lex",    r.get('lex',{})),
    ("SAGE 🧪",   "qa",       "sage",   r.get('sage',{})),
]

for title, agent_id, key, result in agents:
    verdict = result.get('verdict','UNKNOWN')
    icon = "✅" if verdict == "PASS" else "❌"
    print(f"  ┌─ {title} — {icon} {verdict}")
    checks = result.get('checks', [])
    for check in checks:
        c_icon = "✓" if check.get('result') == 'PASS' else "✗" if check.get('result') == 'FAIL' else "⚠"
        print(f"  │  {c_icon} {check.get('id','?')} — {check.get('name','?')}: {check.get('result','?')}")
        if check.get('finding'):
            print(f"  │    → {check.get('finding')}")
    issues = result.get('issues', [])
    if issues:
        print(f"  │  Issues:")
        for i in issues:
            print(f"  │    • {i}")
    deferred = result.get('llmDeferred', [])
    if deferred:
        print(f"  │  Deferred (LLM review):")
        for d in deferred:
            print(f"  │    ↳ {d}")
    rec = result.get('recommendation','')
    if rec:
        print(f"  │  Recommendation: {rec}")
    print(f"  └{'─'*52}")
    print()

recs = r.get('recommendations', [])
if recs:
    print("  ACTIONS REQUIRED:")
    for i, rec in enumerate(recs, 1):
        print(f"  {i}. {rec}")
else:
    print("  No actions required. Asset cleared for delivery.")
print()
PYEOF
    exit 0
  else
    echo "  No governance results on file. Provide --asset-path to run checks."
    exit 1
  fi
fi

# ── Run full governance gate ──────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  🏛️  GOVERNANCE GATE — RUNNING CHECKS"
echo "  Asset: $(basename "$ASSET_PATH")"
echo "  Time:  $AEST"
echo "════════════════════════════════════════════════════════════════"

SHIELD_PASS=0; LEX_PASS=0; SAGE_PASS=0
SHIELD_OUTPUT=""; LEX_OUTPUT=""; SAGE_OUTPUT=""

# Run Shield
echo ""
SHIELD_OUTPUT=$(bash "$WORKSPACE/scripts/shield-check.sh" \
  --asset-path "$ASSET_PATH" --asset-type "$ASSET_TYPE" \
  --brief "$BRIEF" --intended-for "$INTENDED_FOR" --produced-by "$PRODUCED_BY" 2>&1)
SHIELD_EXIT=$?
echo "$SHIELD_OUTPUT"
[ $SHIELD_EXIT -eq 0 ] && SHIELD_PASS=1

# Run Lex
echo ""
LEX_OUTPUT=$(bash "$WORKSPACE/scripts/lex-check.sh" \
  --asset-path "$ASSET_PATH" --asset-type "$ASSET_TYPE" \
  --brief "$BRIEF" --intended-for "$INTENDED_FOR" --produced-by "$PRODUCED_BY" 2>&1)
LEX_EXIT=$?
echo "$LEX_OUTPUT"
[ $LEX_EXIT -eq 0 ] && LEX_PASS=1

# Run Sage
echo ""
SAGE_OUTPUT=$(bash "$WORKSPACE/scripts/sage-qa.sh" \
  --asset-path "$ASSET_PATH" --asset-type "$ASSET_TYPE" \
  --brief "$BRIEF" --intended-for "$INTENDED_FOR" --produced-by "$PRODUCED_BY" 2>&1)
SAGE_EXIT=$?
echo "$SAGE_OUTPUT"
[ $SAGE_EXIT -eq 0 ] && SAGE_PASS=1

# Overall
OVERALL="PASS"
([ "$SHIELD_PASS" = "1" ] && [ "$LEX_PASS" = "1" ] && [ "$SAGE_PASS" = "1" ]) || OVERALL="FAIL"

OVERALL_ICON="✅"; [ "$OVERALL" = "FAIL" ] && OVERALL_ICON="❌"
SHIELD_ICON="✅"; [ "$SHIELD_PASS" = "1" ] || SHIELD_ICON="❌"
LEX_ICON="✅"; [ "$LEX_PASS" = "1" ] || LEX_ICON="❌"
SAGE_ICON="✅"; [ "$SAGE_PASS" = "1" ] || SAGE_ICON="❌"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  GOVERNANCE GATE COMPLETE — $AEST"
echo "  $OVERALL_ICON OVERALL: $OVERALL"
echo "  $SHIELD_ICON Shield (Security)  $LEX_ICON Lex (Legal)  $SAGE_ICON Sage (QA)"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Build RECS
RECS=()
[ "$SHIELD_PASS" = "1" ] || RECS+=("Security issues detected — fix before delivery. See Shield output above.")
[ "$LEX_PASS" = "1" ] || RECS+=("Legal issues detected — fix before delivery. See Lex output above.")
[ "$SAGE_PASS" = "1" ] || RECS+=("QA issues detected — fix before delivery. See Sage output above.")
[ ${#RECS[@]} -eq 0 ] && echo "  ✅ Asset cleared. All three governance gates passed." || \
  { echo "  Actions required:"; for r in "${RECS[@]}"; do echo "  • $r"; done; }
echo ""

# Parse check details from output for structured results
parse_shield() {
  python3 -c "
import re, json, sys
out = '''$(echo "$SHIELD_OUTPUT" | sed "s/'/\\\'/g")'''
checks = []
for line in out.split('\n'):
    for code in ['S1','S2','S3','S4','S5']:
        if f'[ {code}' in line or f'{code} —' in line or f'PASS — ' in line or f'FAIL — ' in line:
            pass
checks_raw = re.findall(r'\[ (S\d) [^\]]+\](.*?)(?=\n\[|\Z)', out, re.DOTALL)
results = []
for code, body in [('S1','Secrets/Credentials'),('S2','Internal Exposure'),('S3','PII'),('S4','Classification'),('S5','Send Risk')]:
    result = 'PASS' if f'PASS — No' in out or 'PASS' in out else 'UNKNOWN'
    # Find specific result for this check
    section = re.search(rf'\[ {code}[^\]]*\](.*?)(?=\n\[|═|\Z)', out, re.DOTALL)
    if section:
        block = section.group(1)
        if 'FAIL' in block: result = 'FAIL'
        elif 'PASS' in block: result = 'PASS'
        elif 'WARN' in block: result = 'WARN'
    results.append({'id': code, 'name': body, 'result': result})
print(json.dumps(results))
" 2>/dev/null || echo "[]"
}

# Build state JSON using jq-free Python — pass values as args not env
_SP=$([ "$SHIELD_PASS" = "1" ] && echo PASS || echo FAIL)
_LP=$([ "$LEX_PASS" = "1" ] && echo PASS || echo FAIL)
_SgP=$([ "$SAGE_PASS" = "1" ] && echo PASS || echo FAIL)
_OV="$OVERALL"

# Write state file via temp Python script
_GR_TMP=$(mktemp /tmp/gov_report_XXXXXX.py)
cat > "$_GR_TMP" << 'GREOF'
import json, sys, os
sp, lp, sgp, ov = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
aest = sys.argv[5]
asset = sys.argv[6]
atype = sys.argv[7]
brief = sys.argv[8]
ifor = sys.argv[9]
pby = sys.argv[10]
tail_str = ("Governance: " + ("PASS" if ov=="PASS" else "FAIL") +
    " (Shield " + ("OK" if sp=="PASS" else "FAIL") +
    " | Lex " + ("OK" if lp=="PASS" else "FAIL") +
    " | Sage " + ("OK" if sgp=="PASS" else "FAIL") + ")")
results = {
    "timestamp": aest, "asset": asset, "assetType": atype,
    "brief": brief, "intendedFor": ifor, "producedBy": pby,
    "overall": ov, "tail": tail_str,
    "shield": {"verdict": sp, "issues": [], "recommendation": "" if sp=="PASS" else "Fix security issues."},
    "lex":    {"verdict": lp, "issues": [], "llmDeferred": ["L2-L4 require LLM review"], "recommendation": "" if lp=="PASS" else "Fix legal issues."},
    "sage":   {"verdict": sgp, "issues": [], "llmDeferred": ["C1-C3 require LLM review"], "recommendation": "" if sgp=="PASS" else "Fix QA issues."},
    "recommendations": [r for r in ["Fix Shield failures." if sp!="PASS" else "", "Fix Lex failures." if lp!="PASS" else "", "Fix Sage failures." if sgp!="PASS" else ""] if r]
}
outfile = os.path.expanduser("~/.openclaw/workspace/state/governance-results.json")
with open(outfile, "w") as f:
    json.dump(results, f, indent=2)
print()
print("  GOVERNANCE TAIL (append to Aria response):")
icon = "checkmark" if ov == "PASS" else "X"
s_icon = "OK" if sp=="PASS" else "FAIL"
l_icon = "OK" if lp=="PASS" else "FAIL"
sg_icon = "OK" if sgp=="PASS" else "FAIL"
print(f"  Model: [model] | Governance: {ov} (Shield:{s_icon} Lex:{l_icon} Sage:{sg_icon}) | /governance for report")
GREOF

python3 "$_GR_TMP" "$_SP" "$_LP" "$_SgP" "$_OV" "$AEST" "$ASSET_PATH" "$ASSET_TYPE" "$BRIEF" "$INTENDED_FOR" "$PRODUCED_BY"
rm -f "$_GR_TMP"

# Log to delegation log
bash "$WORKSPACE/scripts/log-delegation.sh" \
  --tier T2 --task-type governance-check --model anthropic/claude-haiku-4-5 \
  --status $([ "$OVERALL" = "PASS" ] && echo pass || echo fail) \
  --notes "Governance gate: $OVERALL | Asset: $(basename $ASSET_PATH)" 2>/dev/null || true

[ "$OVERALL" = "PASS" ] && exit 0 || exit 1
