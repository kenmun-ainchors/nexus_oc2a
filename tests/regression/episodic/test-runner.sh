#!/bin/bash
# test-runner.sh — Run the full TKT-0390 episodic decision event test suite
#
# Usage: bash tests/regression/episodic/test-runner.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

PASS=0
FAIL=0
TOTAL=0
FAILED_TESTS=""

for t in test-*.sh; do
  if [[ "$t" == "test-runner.sh" ]]; then continue; fi
  TOTAL=$((TOTAL+1))
  echo ""
  echo "═══════════════════════════════════════════════"
  echo " RUNNING: $t"
  echo "═══════════════════════════════════════════════"
  if bash "./$t"; then
    PASS=$((PASS+1))
    echo " ✓ $t PASSED"
  else
    FAIL=$((FAIL+1))
    FAILED_TESTS="$FAILED_TESTS $t"
    echo " ✗ $t FAILED"
  fi
  echo ""
done

echo ""
echo "═══════════════════════════════════════════════"
echo " TKT-0390 EPISODIC TEST SUITE COMPLETE"
echo "═══════════════════════════════════════════════"
echo "  Total: $TOTAL"
echo "  Pass:  $PASS"
echo "  Fail:  $FAIL"

if [[ -n "$FAILED_TESTS" ]]; then
  echo "  Failed tests:$FAILED_TESTS"
fi

if [[ "$FAIL" -gt 0 ]]; then exit 1; fi
exit 0
