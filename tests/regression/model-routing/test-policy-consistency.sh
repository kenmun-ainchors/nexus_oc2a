#!/bin/bash
# tests/regression/model-routing/test-policy-consistency.sh
# TKT-0540 A8
# Verifies that scripts/model-policy-query.sh returns the expected model for
# a representative set of agent+phase combinations per the confirmed policy.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
QUERY="$WORKSPACE_ROOT/scripts/model-policy-query.sh"
JQ="${JQ:-/usr/bin/jq}"

# Load pg-sprint-backlog skill so the policy query (which calls db.sh) passes the skill gate
if ! bash "$WORKSPACE_ROOT/scripts/skill-load.sh" pg-sprint-backlog >/dev/null 2>&1; then
  echo "FAIL: failed to load pg-sprint-backlog skill" >&2
  exit 1
fi

PASS=0
FAIL=0
fail() {
  echo "FAIL: $1"
  FAIL=$((FAIL+1))
}
pass() {
  echo "PASS: $1"
  PASS=$((PASS+1))
}

expect_model() {
  local agent="$1" phase="$2" expected="$3"
  local actual
  actual=$(bash "$QUERY" --agent "$agent" --phase "$phase" 2>/dev/null | "$JQ" -r '.model // .error // empty')
  if [[ "$actual" == "$expected" ]]; then
    pass "$agent $phase → $expected"
  else
    fail "$agent $phase expected $expected, got $actual"
  fi
}

expect_not_allowed() {
  local agent="$1" phase="$2"
  if ! bash "$QUERY" --agent "$agent" --phase "$phase" >/dev/null 2>&1; then
    pass "$agent $phase → not allowed"
  else
    fail "$agent $phase expected not-allowed, got allowed"
  fi
}

# T2 Backend design-only specialists: strong default, cheap execute/synthesize
expect_model architect plan ollama/deepseek-v4-pro:cloud
expect_model architect execute ollama/deepseek-v4-flash:cloud
expect_model architect verify ollama/gemma4:31b-cloud
expect_model architect synthesize ollama/deepseek-v4-pro:cloud
expect_model platform-arch execute ollama/deepseek-v4-flash:cloud

# T2 Governance: strong default, cheap available
expect_model security plan ollama/gemma4:31b-cloud
expect_model security execute ollama/deepseek-v4-flash:cloud
expect_model qa verify ollama/gemma4:31b-cloud

# T3 Technical: Forge exception
expect_model infra plan ollama/deepseek-v4-flash:cloud
expect_model infra execute ollama/minimax-m3:cloud
expect_model infra verify ollama/gemma4:31b-cloud
expect_model infra synthesize ollama/deepseek-v4-flash:cloud

# T3 Business
expect_model social plan ollama/kimi-k2.6:cloud
expect_model social execute ollama/deepseek-v4-flash:cloud
expect_model ahsoka execute ollama/deepseek-v4-flash:cloud
expect_model luthen verify ollama/gemma4:31b-cloud

# User-facing
expect_model main plan ollama/kimi-k2.7-code:cloud
expect_model main execute ollama/deepseek-v4-flash:cloud
expect_model business execute ollama/deepseek-v4-flash:cloud
expect_model business verify ollama/gemma4:31b-cloud

# JSON validity of --all
if bash "$QUERY" --all 2>/dev/null | "$JQ" -e '.effectiveMap' >/dev/null; then
  pass "--all returns valid JSON effectiveMap"
else
  fail "--all JSON invalid or missing effectiveMap"
fi

TOTAL=$((PASS+FAIL))
echo ""
echo "RESULT: $PASS/$TOTAL passed"
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
