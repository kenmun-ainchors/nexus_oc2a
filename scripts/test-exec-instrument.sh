#!/bin/zsh
# test-exec-instrument.sh — Test harness for Yoda-only exec instrumentation (CHG-0861)
#
# Tests:
#   0. Non-Yoda session → pass-through (no instrumentation)
#   1. Empty-return command (exit 0, no stdout) → artifact in file + PG
#   2. Non-zero exit with stderr → artifact in file + PG
#   3. Normal success → no artifact (unless sampled)
#   4. Sampling: every 50th success logs lightweight sample
#   5. Process-count heartbeat populates rolling history
#   6. Latency: measure wrapper overhead
#   7. PG fallback: artifact logged to file when PG unavailable
#   8. Install/uninstall commands work
#
# Usage: bash scripts/test-exec-instrument.sh
#
# Exit: 0 = all tests pass, 1 = any test fails

set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
WRAPPER="$WORKSPACE/scripts/exec-wrapper.sh"
DEBUG_LOG="$WORKSPACE/state/exec-debug.log"
PROCESS_HISTORY="$WORKSPACE/state/process-count-history.json"
COUNTER_FILE="$WORKSPACE/state/.exec-wrapper-counter"
HOOK_FILE="$WORKSPACE/state/.exec-wrapper-hook-active"
DB_RAW="$WORKSPACE/scripts/db-raw.sh"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  ✅ PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ❌ FAIL: $1"; }

# ── Setup: clear previous state ─────────────────────────────────────────────
rm -f "$DEBUG_LOG" "$COUNTER_FILE" "$HOOK_FILE"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  CHG-0861 Yoda-Only Exec Instrumentation — Test Harness    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# TEST 0: Non-Yoda session → pass-through (no instrumentation)
# ═══════════════════════════════════════════════════════════════════════════
echo "─── Test 0: Non-Yoda pass-through (no instrumentation) ───"
# Run as forge — should NOT create any log
OPENCLAW_AGENT_ID="forge" bash "$WRAPPER" "exit 42" 2>&1 || EXIT=$?
EXIT=${EXIT:-0}
if [[ $EXIT -eq 42 ]]; then
    pass "Non-Yoda: exit code 42 preserved"
else
    fail "Non-Yoda: exit code $EXIT (expected 42)"
fi
if [[ ! -f "$DEBUG_LOG" ]]; then
    pass "Non-Yoda: no debug log created"
else
    fail "Non-Yoda: debug log was created (should not be)"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 1: Empty return (exit 0, no stdout) — Yoda mode
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "─── Test 1: Empty return (exit 0, no stdout) [Yoda mode] ───"
OPENCLAW_AGENT_ID="yoda" bash "$WRAPPER" "true" 2>&1 || true
EXIT=$?
if [[ $EXIT -eq 0 ]]; then
    pass "Yoda: exit code 0 for 'true'"
else
    fail "Yoda: exit code $EXIT for 'true' (expected 0)"
fi

if grep -q "\[empty\]" "$DEBUG_LOG" 2>/dev/null; then
    pass "Yoda: file log contains [empty] entry"
else
    fail "Yoda: file log missing [empty] entry"
fi

PG_COUNT=$(bash "$DB_RAW" -c "SELECT count(*) FROM state_exec_debug WHERE exit_code=0 AND command='true'" 2>/dev/null || echo 0)
if [[ "$PG_COUNT" -gt 0 ]]; then
    pass "Yoda: PG has entry for exit_code=0 command='true'"
else
    fail "Yoda: PG missing entry for exit_code=0 command='true'"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 2: Non-zero exit with stderr — Yoda mode
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "─── Test 2: Non-zero exit with stderr [Yoda mode] ───"
OUTPUT=$(OPENCLAW_AGENT_ID="yoda" bash "$WRAPPER" "echo error-msg >&2; exit 2" 2>&1) || EXIT=$?
EXIT=${EXIT:-0}
if [[ $EXIT -eq 2 ]]; then
    pass "Yoda: exit code 2 preserved"
else
    fail "Yoda: exit code $EXIT (expected 2)"
fi

if echo "$OUTPUT" | grep -q "error-msg"; then
    pass "Yoda: stderr 'error-msg' propagated"
else
    fail "Yoda: stderr not propagated"
fi

if grep -q "\[failure\]" "$DEBUG_LOG" 2>/dev/null; then
    pass "Yoda: file log contains [failure] entry"
else
    fail "Yoda: file log missing [failure] entry"
fi

PG_COUNT=$(bash "$DB_RAW" -c "SELECT count(*) FROM state_exec_debug WHERE exit_code=2" 2>/dev/null || echo 0)
if [[ "$PG_COUNT" -gt 0 ]]; then
    pass "Yoda: PG has entry for exit_code=2"
else
    fail "Yoda: PG missing entry for exit_code=2"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 3: Normal success — no artifact (unless sampled)
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "─── Test 3: Normal success (no artifact) [Yoda mode] ───"
echo "1" > "$COUNTER_FILE"
LOG_BEFORE=$(wc -l < "$DEBUG_LOG" 2>/dev/null || echo 0)
OUTPUT=$(OPENCLAW_AGENT_ID="yoda" bash "$WRAPPER" "echo normal-output" 2>&1)
EXIT=$?

if [[ "$OUTPUT" == "normal-output" ]]; then
    pass "Yoda: normal output preserved"
else
    fail "Yoda: normal output corrupted: got '$OUTPUT'"
fi

if [[ $EXIT -eq 0 ]]; then
    pass "Yoda: exit code 0 preserved for normal command"
else
    fail "Yoda: exit code $EXIT for normal command (expected 0)"
fi

NEW_FAILURES=$(grep -c '\[failure\]\|\[empty\]' "$DEBUG_LOG" 2>/dev/null || echo 0)
if [[ "$NEW_FAILURES" -le 2 ]]; then
    pass "Yoda: no spurious failure/empty entries for normal command"
else
    fail "Yoda: unexpected failure/empty entries: $NEW_FAILURES"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 4: Sampling — every 50th success logs lightweight sample
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "─── Test 4: Sampling (every 50th success) [Yoda mode] ───"
echo "49" > "$COUNTER_FILE"
OPENCLAW_AGENT_ID="yoda" bash "$WRAPPER" "echo sample-test" > /dev/null 2>&1 || true

if grep -q "\[SAMPLE\]" "$DEBUG_LOG" 2>/dev/null; then
    pass "Yoda: sample entry logged at 50th call"
else
    fail "Yoda: no sample entry at 50th call"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 5: Process-count heartbeat
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "─── Test 5: Process-count heartbeat ───"
if [[ -f "$PROCESS_HISTORY" ]]; then
    SAMPLE_COUNT=$(python3 -c "import json; d=json.load(open('$PROCESS_HISTORY')); print(len(d.get('samples',[])))" 2>/dev/null || echo 0)
    if [[ "$SAMPLE_COUNT" -gt 0 ]]; then
        pass "Process-count history has $SAMPLE_COUNT sample(s)"
    else
        fail "Process-count history has 0 samples"
    fi

    SCHEMA=$(python3 -c "import json; d=json.load(open('$PROCESS_HISTORY')); print(d.get('schema',''))" 2>/dev/null || echo "")
    if [[ "$SCHEMA" == "1.0" ]]; then
        pass "Process-count history schema is 1.0"
    else
        fail "Process-count history schema mismatch: '$SCHEMA'"
    fi

    SAMPLE_OK=$(python3 -c "
import json
d=json.load(open('$PROCESS_HISTORY'))
s = d.get('samples', [])
if s and 'ts' in s[0] and 'process_count' in s[0] and 'ulimit_u' in s[0]:
    print('ok')
else:
    print('bad')
" 2>/dev/null || echo "bad")
    if [[ "$SAMPLE_OK" == "ok" ]]; then
        pass "Sample structure valid (ts, process_count, ulimit_u)"
    else
        fail "Sample structure invalid"
    fi
else
    fail "Process-count history file not found"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 6: Latency measurement
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "─── Test 6: Latency measurement [Yoda mode] ───"
TIMES=10
START=$(date +%s%N)
for i in $(seq 1 $TIMES); do
    OPENCLAW_AGENT_ID="yoda" bash "$WRAPPER" "echo fast" > /dev/null 2>&1 || true
done
END=$(date +%s%N)
DURATION_MS=$(( (END - START) / 1000000 ))
AVG_MS=$(( DURATION_MS / TIMES ))

START=$(date +%s%N)
for i in $(seq 1 $TIMES); do
    echo "fast" > /dev/null 2>&1
done
END=$(date +%s%N)
BASELINE_MS=$(( (END - START) / 1000000 ))
AVG_BASELINE=$(( BASELINE_MS / TIMES ))

OVERHEAD=$(( AVG_MS - AVG_BASELINE ))
echo "  Average wrapper call: ${AVG_MS}ms"
echo "  Average direct call:  ${AVG_BASELINE}ms"
echo "  Overhead per call:    ${OVERHEAD}ms"

if [[ "$OVERHEAD" -lt 100 ]]; then
    pass "Latency overhead ${OVERHEAD}ms (acceptable: <100ms)"
else
    fail "Latency overhead ${OVERHEAD}ms (exceeds 100ms threshold)"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 7: PG fallback — simulate PG failure
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "─── Test 7: PG fallback (simulate PG failure) [Yoda mode] ───"
LOG_BEFORE=$(wc -l < "$DEBUG_LOG" 2>/dev/null || echo 0)
PGHOST_SAVE="${PGHOST:-}"
export PGHOST="/nonexistent"
OPENCLAW_AGENT_ID="yoda" bash "$WRAPPER" "exit 3" > /dev/null 2>&1 || true
export PGHOST="${PGHOST_SAVE}"
LOG_AFTER=$(wc -l < "$DEBUG_LOG" 2>/dev/null || echo 0)

if [[ "$LOG_AFTER" -gt "$LOG_BEFORE" ]]; then
    pass "Yoda: artifact logged to file even when PG write fails"
else
    fail "Yoda: no artifact logged when PG write fails"
fi

if grep -q "PG_WRITE_FAILED" "$DEBUG_LOG" 2>/dev/null; then
    pass "Yoda: PG_WRITE_FAILED note appended to log"
else
    fail "Yoda: missing PG_WRITE_FAILED note in log"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TEST 8: Install/uninstall commands
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "─── Test 8: Install/uninstall commands ───"
rm -f "$HOOK_FILE"
bash "$WRAPPER" install 2>/dev/null
if [[ -f "$HOOK_FILE" ]]; then
    pass "Install creates hook file"
else
    fail "Install did not create hook file"
fi

bash "$WRAPPER" uninstall 2>/dev/null
if [[ ! -f "$HOOK_FILE" ]]; then
    pass "Uninstall removes hook file"
else
    fail "Uninstall did not remove hook file"
fi

# ═══════════════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Results: $PASS passed, $FAIL failed"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
exit 0
