#!/bin/bash
# regression-runner.sh — AInchors Regression Testing Framework
# Usage: regression-runner.sh [--suite <name>] [--phase <n>] [--verbose]
#
# Conventions:
#   tests/regression/<suite>/test-*-p{N}.sh  — test scripts (exit 0=PASS, 1=FAIL, 2=SKIP)
#   tests/regression/<suite>/suite.json      — suite metadata
#   Reports: state/regression-report-<suite>-<date>.json

WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
TESTS_DIR="$WORKSPACE/tests/regression"
STATE_DIR="$WORKSPACE/state"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
DATE=$(date +%Y-%m-%d)

SUITE="pg-foundation"
PHASE="all"
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --suite) SUITE="$2"; shift 2 ;;
    --phase) PHASE="$2"; shift 2 ;;
    --verbose|-v) VERBOSE=true; shift ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

SUITE_DIR="$TESTS_DIR/$SUITE"
[ -d "$SUITE_DIR" ] || { echo "ERROR: Suite '$SUITE' not found"; exit 1; }

# Load suite metadata
SUITE_NAME="$SUITE"
if [ -f "$SUITE_DIR/suite.json" ]; then
  SUITE_NAME=$(/opt/homebrew/bin/jq -r '.name // "'"$SUITE"'"' "$SUITE_DIR/suite.json")
fi

# Colors
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; NC='\033[0m'

echo "═══════════════════════════════════════════════════════════════"
echo " AInchors Regression Test Suite"
echo " Suite: $SUITE_NAME | Date: $DATE"
echo "═══════════════════════════════════════════════════════════════"

# Discover phases
if [ "$PHASE" = "all" ]; then
  PHASES=$(ls "$SUITE_DIR"/test-*-p*.sh 2>/dev/null | sed 's/.*-p\([0-9]*\).*/\1/' | sort -nu | tr '\n' ' ')
  [ -z "$PHASES" ] && { echo "ERROR: No test files found"; exit 1; }
else
  PHASES="$PHASE"
fi

TOTAL_PASSED=0; TOTAL_FAILED=0; TOTAL_SKIPPED=0
ALL_PHASE_RESULTS=""

for phase in $PHASES; do
  echo ""
  echo "━━━ Phase $phase ━━━"
  
  PASSED=0; FAILED=0; SKIPPED=0
  TEST_RESULTS=""
  FIRST_TEST=true
  
  for test_file in "$SUITE_DIR"/test-*-p${phase}.sh; do
    [ -f "$test_file" ] || continue
    
    test_id=$(basename "$test_file" .sh | sed 's/^test-//')
    test_title=$(head -1 "$test_file" 2>/dev/null | sed 's/^# //;s/^#!/bin/bash//')
    [ -z "$test_title" ] && test_title="$test_id"
    
    start_ns=$(date +%s%N 2>/dev/null || echo 0)
    
    printf "  [%-35s] %-45s " "$test_id" "${test_title:0:42}"
    
    output=$(bash "$test_file" 2>&1)
    exit_code=$?
    
    end_ns=$(date +%s%N 2>/dev/null || echo 0)
    duration_ms=$(( (end_ns - start_ns) / 1000000 ))
    
    case $exit_code in
      0)
        echo -e "${GREEN}PASS${NC} (${duration_ms}ms)"
        PASSED=$((PASSED + 1))
        result_json=$(printf '{"id":"%s","result":"PASS","duration_ms":%s}' "$test_id" "$duration_ms")
        ;;
      1)
        echo -e "${RED}FAIL${NC} (${duration_ms}ms)"
        FAILED=$((FAILED + 1))
        err=$(echo "$output" | tail -3 | /opt/homebrew/bin/jq -R -s . 2>/dev/null || echo '""')
        result_json=$(printf '{"id":"%s","result":"FAIL","duration_ms":%s,"error":%s}' "$test_id" "$duration_ms" "$err")
        $VERBOSE && echo "$output" | head -3 | sed 's/^/      │ /'
        ;;
      2)
        echo -e "${YELLOW}SKIP${NC} (${duration_ms}ms)"
        SKIPPED=$((SKIPPED + 1))
        result_json=$(printf '{"id":"%s","result":"SKIP","duration_ms":%s}' "$test_id" "$duration_ms")
        ;;
      *)
        echo -e "${RED}ERR($exit_code)${NC} (${duration_ms}ms)"
        FAILED=$((FAILED + 1))
        result_json=$(printf '{"id":"%s","result":"ERROR","duration_ms":%s,"exit_code":%s}' "$test_id" "$duration_ms" "$exit_code")
        ;;
    esac
    
    if $FIRST_TEST; then FIRST_TEST=false; else TEST_RESULTS+=","; fi
    TEST_RESULTS+="$result_json"
  done
  
  TOTAL_PASSED=$((TOTAL_PASSED + PASSED))
  TOTAL_FAILED=$((TOTAL_FAILED + FAILED))
  TOTAL_SKIPPED=$((TOTAL_SKIPPED + SKIPPED))
  
  phase_json=$(printf '{"phase":"%s","passed":%s,"failed":%s,"skipped":%s,"tests":[%s]}' "$phase" "$PASSED" "$FAILED" "$SKIPPED" "$TEST_RESULTS")
  [ -n "$ALL_PHASE_RESULTS" ] && ALL_PHASE_RESULTS+=","
  ALL_PHASE_RESULTS+="$phase_json"
  
  echo "  Phase $phase: $PASSED/$((PASSED+FAILED+SKIPPED)) passed"
done

TOTAL=$((TOTAL_PASSED + TOTAL_FAILED + TOTAL_SKIPPED))
PCT=$(( TOTAL_PASSED * 100 / TOTAL )) 2>/dev/null

echo ""
echo "═══════════════════════════════════════════════════════════════"
printf " TOTAL: ${GREEN}%s passed${NC}, ${RED}%s failed${NC}, ${YELLOW}%s skipped${NC} (%s%% pass rate)\n" \
  "$TOTAL_PASSED" "$TOTAL_FAILED" "$TOTAL_SKIPPED" "${PCT:-0}"
echo "═══════════════════════════════════════════════════════════════"

# Write report
REPORT="$STATE_DIR/regression-report-${SUITE}-${DATE}.json"
cat > "$REPORT" << EOF
{
  "suite": "$SUITE_NAME",
  "suiteId": "$SUITE",
  "date": "$DATE",
  "timestamp": "$TIMESTAMP",
  "totalTests": $TOTAL,
  "passed": $TOTAL_PASSED,
  "failed": $TOTAL_FAILED,
  "skipped": $TOTAL_SKIPPED,
  "passRate": ${PCT:-0},
  "go": $([ $TOTAL_FAILED -eq 0 ] && echo "true" || echo "false"),
  "phases": [$ALL_PHASE_RESULTS]
}
EOF

echo " Report: $REPORT"
[ $TOTAL_FAILED -eq 0 ] && echo " Verdict: ALL TESTS PASSING ✅" || echo " Verdict: $TOTAL_FAILED FAILURES ❌"

exit $TOTAL_FAILED
