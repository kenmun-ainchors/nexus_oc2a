#!/bin/bash
# tests/regression/model-routing/test-consumer-consistency.sh
# TKT-0540 A8
# Verifies that dispatch-validate.sh and crest-execute-gate.sh agree with
# scripts/model-policy-query.sh for sample dispatches.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
JQ="${JQ:-/usr/bin/jq}"
DISPATCH="$WORKSPACE_ROOT/scripts/dispatch-validate.sh"
GATE="$WORKSPACE_ROOT/scripts/crest-execute-gate.sh"

# Load pg-sprint-backlog skill so any downstream DB-using helpers pass the skill gate
if ! bash "$WORKSPACE_ROOT/scripts/skill-load.sh" pg-sprint-backlog >/dev/null 2>&1; then
  echo "FAIL: failed to load pg-sprint-backlog skill" >&2
  exit 1
fi

PASS=0
FAIL=0
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
pass() { echo "PASS: $1"; PASS=$((PASS+1)); }

mkdispatch() {
  local target="$1" phase="$2" model="$3"
  "$JQ" -n \
    --arg target "$target" \
    --arg phase "$phase" \
    --arg model "$model" \
    '{
      source_agent: "yoda",
      target_agent: $target,
      discovery_atoms: [{verb: "assess", target: "test", desc: "test"}],
      sub_crest_plan: [{
        verb: "assess",
        target: "test",
        pre_conditions: ["x"],
        post_conditions: ["y"],
        model: $model,
        phase: $phase
      }],
      verifier_corpus: "/tmp/test-corpus.txt"
    }'
}

# Setup corpus
touch /tmp/test-corpus.txt

check_dispatch() {
  local target="$1" phase="$2" model="$3" expect_ok="$4"
  local out status
  out=$(mkdispatch "$target" "$phase" "$model" | bash "$DISPATCH" 2>/dev/null) || true
  status=$(echo "$out" | "$JQ" -r '.status // "error"')
  if [[ "$expect_ok" == "ok" && "$status" == "ok" ]]; then
    pass "dispatch-validate $target/$phase/$model → ok"
  elif [[ "$expect_ok" == "fail" && "$status" == "fail" ]]; then
    pass "dispatch-validate $target/$phase/$model → fail (expected)"
  else
    fail "dispatch-validate $target/$phase/$model expected $expect_ok, got $status"
    echo "$out" | "$JQ" -c '.failures[]?' >&2 || true
  fi
}

check_gate() {
  local op="$1" phase="$2" model="$3" expect="$4"
  local out status
  out=$(CREST_OPERATOR="$op" CREST_PHASE="$phase" CREST_MODEL="$model" CREST_ATOM_DESC="test" bash "$GATE" 2>/dev/null) || true
  status=$(echo "$out" | "$JQ" -r '.status // "error"')
  if [[ "$status" == "$expect" ]]; then
    pass "crest-gate $op/$phase/$model → $expect"
  else
    fail "crest-gate $op/$phase/$model expected $expect, got $status"
  fi
}

# dispatch-validate: correct models should pass
check_dispatch platform-arch execute ollama/deepseek-v4-flash:cloud ok
check_dispatch infra plan ollama/deepseek-v4-flash:cloud ok
check_dispatch infra verify ollama/gemma4:31b-cloud ok
check_dispatch social execute ollama/deepseek-v4-flash:cloud ok

# dispatch-validate: incorrect models should fail
check_dispatch platform-arch execute ollama/minimax-m3:cloud fail
check_dispatch infra verify ollama/deepseek-v4-flash:cloud fail

# crest-execute-gate
check_gate main execute ollama/kimi-k2.7-code:cloud block
check_gate infra execute ollama/deepseek-v4-flash:cloud block
check_gate infra verify ollama/gemma4:31b-cloud allow
check_gate platform-arch execute ollama/deepseek-v4-flash:cloud allow

rm -f /tmp/test-corpus.txt

TOTAL=$((PASS+FAIL))
echo ""
echo "RESULT: $PASS/$TOTAL passed"
[[ $FAIL -eq 0 ]] || exit 1
