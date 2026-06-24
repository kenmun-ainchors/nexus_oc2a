#!/bin/bash
# tkt0764-verifier-corpus-regression.sh — TKT-0764 A5 Regression Tests
#
# Standalone regression test suite for the TKT-0764 CREST v1.3 execution pattern.
# Exercises the 10 verifier corpus checks and produces a TAP-like summary.
#
# Usage:
#   bash tests/regression/crest/tkt0764-verifier-corpus-regression.sh
#
# Exit 0 if all pass, exit 1 if any fail.
# Outputs: RESULT: PASS X/Y or RESULT: FAIL X/Y

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

JQ="/opt/homebrew/bin/jq"
PYTHON="/opt/homebrew/bin/python3"

FAIL=0
PASS=0
TOTAL=0

fail() { FAIL=$((FAIL + 1)); echo "not ok $TOTAL - $1"; }
pass() { PASS=$((PASS + 1)); echo "ok $TOTAL - $1"; }

# Run a test: check <description> <command...>
# The command is run in a subshell with set +e so failures don't kill the suite.
check() {
  local desc="$1"
  shift
  TOTAL=$((TOTAL + 1))
  if (set +e; "$@"); then
    pass "$desc"
  else
    fail "$desc"
  fi
}

# ── Test 1: SKILL.md contains "Canonical TKT-0761 Pattern" section ──
check "SKILL.md has Canonical TKT-0761 Pattern section" \
  grep -q "Canonical TKT-0761 Pattern" agent-skills/crest/SKILL.md

# ── Test 2: SKILL.md contains "Yoda Spot-Check" checklist ──
check "SKILL.md has Yoda Spot-Check checklist" \
  grep -q "Yoda Spot-Check" agent-skills/crest/SKILL.md

# ── Test 3: SKILL.md contains "Sage-as-Judge" checklist ──
check "SKILL.md has Sage-as-Judge checklist" \
  grep -q "Sage-as-Judge" agent-skills/crest/SKILL.md

# ── Test 4: dispatch-validate.sh rejects execute atom without verifier_corpus ──
check "dispatch-validate.sh rejects execute atom without verifier_corpus" \
  bash -c '
    BAD_DISPATCH='"'"'{"source_agent":"yoda","target_agent":"infra","discovery_atoms":[{"verb":"edit","target":"scripts/foo.sh","desc":"test"}],"sub_crest_plan":[{"verb":"edit","target":"scripts/foo.sh","phase":"execute","model":"ollama/deepseek-v4-flash:cloud","pre_conditions":["x"],"post_conditions":["y"]}]}'"'"'
    ! echo "$BAD_DISPATCH" | bash scripts/dispatch-validate.sh --stdin >/dev/null 2>&1
  '

# ── Test 5: dispatch-validate.sh accepts execute atom with valid verifier_corpus ──
# The verifier_corpus field itself must be accepted (even if CREST gate blocks for other reasons)
check "dispatch-validate.sh accepts valid verifier_corpus field" \
  bash -c '
    GOOD_DISPATCH='"'"'{"source_agent":"yoda","target_agent":"infra","discovery_atoms":[{"verb":"edit","target":"scripts/foo.sh","desc":"test"}],"verifier_corpus":"tests/regression/crest/tkt0764-verifier-corpus-regression.sh","sub_crest_plan":[{"verb":"edit","target":"scripts/foo.sh","phase":"execute","model":"ollama/deepseek-v4-flash:cloud","pre_conditions":["x"],"post_conditions":["y"]}]}'"'"'
    RESULT=$(echo "$GOOD_DISPATCH" | bash scripts/dispatch-validate.sh --stdin --verbose 2>&1) || true
    '"$PYTHON"' - "$RESULT" <<"PYEOF"
import json, re, sys
text = sys.argv[1]
objects = []
for m in re.finditer(r"\{", text):
    start = m.start()
    depth = 0
    for i in range(start, len(text)):
        if text[i] == "{": depth += 1
        elif text[i] == "}": depth -= 1
        if depth == 0:
            try:
                obj = json.loads(text[start:i+1])
                objects.append(obj)
            except Exception:
                pass
            break
if not objects:
    sys.exit(1)
final = objects[-1]
fails = [f.get("field","") for f in final.get("failures",[])]
if "verifier_corpus" in fails:
    sys.exit(1)
print("accepted")
PYEOF
  '

# ── Test 6: atom-validate.sh rejects execute/Execute atom missing verifier_corpus (case-insensitive) ──
check "atom-validate.sh rejects Execute atom missing verifier_corpus (Title Case)" \
  bash -c '
    BAD_ATOM='"'"'{"verb":"edit","target":"scripts/foo.sh","phase":"Execute","model":"ollama/deepseek-v4-flash:cloud","pre_conditions":["x"],"post_conditions":["y"],"atom":"edit-foo"}'"'"'
    ! echo "$BAD_ATOM" | bash scripts/atom-validate.sh --stdin >/dev/null 2>&1
  '

# ── Test 7: atom-validate.sh accepts execute/Execute atom with valid verifier_corpus ──
check "atom-validate.sh accepts Execute atom with valid verifier_corpus" \
  bash -c '
    GOOD_ATOM='"'"'{"verb":"edit","target":"scripts/foo.sh","phase":"Execute","model":"ollama/deepseek-v4-flash:cloud","pre_conditions":["x"],"post_conditions":["y"],"atom":"edit-foo","verifier_corpus":"tests/regression/crest/tkt0764-verifier-corpus-regression.sh"}'"'"'
    echo "$GOOD_ATOM" | bash scripts/atom-validate.sh --stdin >/dev/null 2>&1
  '

# ── Test 8: sage-verify.sh exists, is executable, and produces a raw results file ──
check "sage-verify.sh exists and is executable" \
  test -x scripts/sage-verify.sh

# Test 8b: sage-verify.sh produces raw results file
# Use a temp corpus written via printf to avoid heredoc-in-quoted-string issues
check "sage-verify.sh produces raw results file" \
  bash -c '
    TMP_CORPUS=$(mktemp)
    printf "#!/bin/bash\necho test-corpus-pass\nexit 0\n" > "$TMP_CORPUS"
    chmod +x "$TMP_CORPUS"
    RUN_ID="regression-test-$$"
    bash scripts/sage-verify.sh \
      --run-id "$RUN_ID" \
      --ticket "TKT-0764" \
      --corpus "$TMP_CORPUS" \
      --state-dir /tmp >/dev/null 2>&1 || true
    RAW_FILE="/tmp/sage-verify-${RUN_ID}.jsonl"
    RESULT=1
    if [[ -f "$RAW_FILE" ]]; then
      CONTENT=$(cat "$RAW_FILE")
      if echo "$CONTENT" | /opt/homebrew/bin/jq -e ".exit_code == 0" >/dev/null 2>&1; then
        RESULT=0
      fi
    fi
    rm -f "$TMP_CORPUS" "$RAW_FILE" "/tmp/sage-verify-${RUN_ID}-verdict.json"
    exit $RESULT
  '

# ── Test 9: warden-crest-compliance.sh exists, is executable, and can run in --dry-run mode ──
check "warden-crest-compliance.sh exists and is executable" \
  test -x scripts/warden-crest-compliance.sh

check "warden-crest-compliance.sh runs in --dry-run mode" \
  bash -c '
    OUTPUT=$(bash scripts/warden-crest-compliance.sh --dry-run 2>&1) || true
    echo "$OUTPUT" | grep -q "Warden CREST Compliance Check"
  '

# ── Test 10: Title Case phase values (Execute, Verify) are accepted by validators ──
check "atom-validate.sh accepts Title Case Execute phase with verifier_corpus" \
  bash -c '
    ATOM='"'"'{"verb":"edit","target":"scripts/foo.sh","phase":"Execute","model":"ollama/deepseek-v4-flash:cloud","pre_conditions":["x"],"post_conditions":["y"],"atom":"edit-foo","verifier_corpus":"tests/regression/crest/tkt0764-verifier-corpus-regression.sh"}'"'"'
    echo "$ATOM" | bash scripts/atom-validate.sh --stdin >/dev/null 2>&1
  '

check "atom-validate.sh accepts Title Case Verify phase with verifier_corpus" \
  bash -c '
    ATOM='"'"'{"verb":"read","target":"scripts/foo.sh","phase":"Verify","model":"ollama/deepseek-v4-flash:cloud","pre_conditions":["x"],"post_conditions":["y"],"atom":"verify-foo","verifier_corpus":"tests/regression/crest/tkt0764-verifier-corpus-regression.sh"}'"'"'
    echo "$ATOM" | bash scripts/atom-validate.sh --stdin >/dev/null 2>&1
  '

# ── Summary ──
echo ""
if [[ $FAIL -eq 0 ]]; then
  echo "RESULT: PASS $PASS/$TOTAL"
  exit 0
else
  echo "RESULT: FAIL $PASS/$TOTAL"
  exit 1
fi
