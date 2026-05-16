#!/bin/zsh
# tkt-acceptance-template.sh — Acceptance test template for ticket execution
# Usage: zsh scripts/tkt-acceptance-template.sh [TKT-NNNN] [ticket-title]
# Generates: tests/tkt-NNNN-acceptance.sh

set -u

TKT="${1:-}"
TITLE="${2:-Ticket work}"
WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"

if [[ -z "$TKT" ]]; then
  echo "Usage: zsh scripts/tkt-acceptance-template.sh [TKT-NNNN] '[ticket title]'"
  exit 1
fi

TEST_FILE="$WORKSPACE/tests/${TKT}-acceptance.sh"
mkdir -p "$WORKSPACE/tests"

cat > "$TEST_FILE" <<TEMPLATE
#!/bin/zsh
# Acceptance test for ${TKT}: ${TITLE}
# Generated: $(date '+%Y-%m-%d %H:%M %Z')
# Run after ticket completion to validate deliverables

set -euo pipefail

PASS=0
FAIL=0
WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"

test_pass() { echo "  ✅ PASS: \$1"; ((PASS++)); }
test_fail() { echo "  ❌ FAIL: \$1"; ((FAIL++)); }

echo "=== ${TKT} Acceptance Tests ==="
echo "Title: ${TITLE}"
echo ""

# TODO: Add specific tests for this ticket
# Example patterns:
#
# ## Test 1: File exists
# if [[ -f "\$WORKSPACE/state/new-file.json" ]]; then
#   test_pass "state/new-file.json exists"
# else
#   test_fail "state/new-file.json missing"
# fi
#
# ## Test 2: Config valid JSON
# if python3 -c "import json; json.load(open('\$WORKSPACE/state/new-file.json'))" 2>/dev/null; then
#   test_pass "new-file.json is valid JSON"
# else
#   test_fail "new-file.json is invalid JSON"
# fi
#
# ## Test 3: Script executable
# if [[ -x "\$WORKSPACE/scripts/new-script.sh" ]]; then
#   test_pass "new-script.sh is executable"
# else
#   test_fail "new-script.sh not executable"
# fi
#
# ## Test 4: State value check
# VALUE=\$(jq -r '.someField' \$WORKSPACE/state/some-state.json 2>/dev/null || echo "null")
# if [[ "\$VALUE" != "null" && -n "\$VALUE" ]]; then
#   test_pass "someField is set to: \$VALUE"
# else
#   test_fail "someField is not set"
# fi
#
# ## Test 5: Service running
# if pgrep -x "some-service" > /dev/null; then
#   test_pass "some-service is running"
# else
#   test_fail "some-service not running"
# fi

echo ""
echo "=== RESULTS ==="
echo "  Passed: \$PASS"
echo "  Failed: \$FAIL"

if ((FAIL > 0)); then
  echo "  ❌ Acceptance test FAILED"
  exit 1
else
  echo "  ✅ Acceptance test PASSED"
  exit 0
fi
TEMPLATE

echo "Acceptance test template created: $TEST_FILE"
echo "Edit the file to add specific tests for ${TKT}"
