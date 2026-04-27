#!/usr/bin/env bash
export PATH="$PATH:/usr/local/bin:/opt/homebrew/bin"
# gemma4-benchmark.sh — Compare gemma4:e4b vs gemma4:26b on real AInchors delegation tasks
# TKT-0013 / Model Strategy
# Usage: bash gemma4-benchmark.sh [--model MODEL] [--all]

set -euo pipefail

MODEL="${1:-gemma4:e4b}"
WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
RESULTS_DIR="$WORKSPACE/state/benchmark"
TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S+10:00")
STAMP=$(date +"%Y%m%d-%H%M%S")
RESULT_FILE="$RESULTS_DIR/gemma4-bench-${MODEL//[:\/]/-}-$STAMP.json"

mkdir -p "$RESULTS_DIR"

echo "🧪 Gemma4 Benchmark — $MODEL"
echo "Started: $TIMESTAMP"
echo "────────────────────────────────────────────────────────────"

RESULTS=()
TOTAL_PASS=0
TOTAL_FAIL=0

# ── Helper: run a task, measure latency, check output ────────────────────────
run_task() {
  local task_id="$1"
  local task_name="$2"
  local prompt="$3"
  local validator="$4"   # bash expression: echo "$OUTPUT" | <validator>
  local max_tokens="${5:-200}"

  echo ""
  echo "[$task_id] $task_name"

  local start_ms end_ms duration_ms
  start_ms=$(python3 -c "import time; print(int(time.time()*1000))")

  local output
  output=$(ollama run "$MODEL" "$prompt" --nowordwrap 2>/dev/null | head -c 2000 || echo "ERROR: model failed")

  end_ms=$(python3 -c "import time; print(int(time.time()*1000))")
  duration_ms=$((end_ms - start_ms))

  # Run validator
  local pass=0
  local validator_result
  if [ "$validator" = "nonempty" ]; then
    [ -n "$output" ] && [ "$output" != "ERROR: model failed" ] && pass=1
  else
    validator_result=$(echo "$output" | eval "$validator" 2>/dev/null || echo "")
    [ -n "$validator_result" ] && pass=1
  fi

  local status="PASS"
  [ $pass -eq 0 ] && status="FAIL"

  echo "  Status:   $status"
  echo "  Latency:  ${duration_ms}ms"
  echo "  Output:   $(echo "$output" | head -3 | tr '\n' ' ' | cut -c1-120)..."

  if [ $pass -eq 1 ]; then
    TOTAL_PASS=$((TOTAL_PASS + 1))
  else
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
  fi

  RESULTS+=("{\"id\":\"$task_id\",\"name\":\"$(echo $task_name | sed 's/"/\\"/g')\",\"status\":\"$status\",\"latencyMs\":$duration_ms,\"model\":\"$MODEL\"}")
}

# ── Check model is available ─────────────────────────────────────────────────
if ! ollama list 2>/dev/null | grep -q "${MODEL}"; then
  echo "❌ Model $MODEL not found. Run: ollama pull $MODEL"
  exit 1
fi

echo ""
echo "Model loaded. Running tasks..."

# ════════════════════════════════════════════════════════════════════
# TASK 1 — Cost summary formatting (cost-tracker output → brief summary)
# ════════════════════════════════════════════════════════════════════
run_task "T01" "Cost summary formatting" \
"You are a cost reporting agent. Given this JSON cost data, write a one-line summary under 20 words.
Data: {\"date\":\"2026-04-28\",\"totalCost\":12.45,\"totalTurns\":143,\"byModel\":{\"claude-sonnet-4-6\":{\"cost\":12.45,\"turns\":143}}}
Output only the one-line summary, nothing else." \
"grep -iE '\\\$12|12\.4|143|sonnet'"

# ════════════════════════════════════════════════════════════════════
# TASK 2 — Health check interpretation (parse status → decision)
# ════════════════════════════════════════════════════════════════════
run_task "T02" "Health check interpretation" \
"You are a health monitoring agent. Given this health status JSON, output exactly one word: OK, WARN, or CRITICAL.
JSON: {\"gateway\":\"running\",\"ollama\":\"running\",\"consecutiveFailures\":0,\"lastCheck\":\"2026-04-28T07:55:00\",\"diskUsagePercent\":42}
Output only: OK, WARN, or CRITICAL — nothing else." \
"grep -E '^(OK|WARN|CRITICAL)$'"

# ════════════════════════════════════════════════════════════════════
# TASK 3 — CHANGELOG entry formatting
# ════════════════════════════════════════════════════════════════════
run_task "T03" "CHANGELOG entry formatting" \
"Format this change as a single markdown line matching exactly this pattern:
## 2026-04-28 08:15 AEST — [CHG-XXXX] Title

Input: Date=2026-04-28 08:15, ID=CHG-0047, Title=Update model policy to Sonnet-only across all agents
Output only the formatted line, nothing else." \
"grep -E '## 2026-04-28.*\[CHG-0047\]'"

# ════════════════════════════════════════════════════════════════════
# TASK 4 — JSON extraction (pull a value from JSON)
# ════════════════════════════════════════════════════════════════════
run_task "T04" "Structured JSON extraction" \
'Extract the value of the "status" field for the agent with id "business" from this JSON. Output only the value, nothing else.
{"agents":{"list":[{"id":"main","status":"active","model":"sonnet"},{"id":"business","status":"idle","model":"sonnet"},{"id":"governance","status":"active","model":"sonnet"}]}}' \
"grep -E '^idle$'"

# ════════════════════════════════════════════════════════════════════
# TASK 5 — Routing decision (classify a task)
# ════════════════════════════════════════════════════════════════════
run_task "T05" "Task routing classification" \
"Classify this task into exactly one category: SIMPLE, MODERATE, or COMPLEX.
Task: 'Read the cost-state.json file and return the totalCost value for 2026-04-28'
Output only: SIMPLE, MODERATE, or COMPLEX — nothing else." \
"grep -E '^(SIMPLE|MODERATE|COMPLEX)$'"

# ════════════════════════════════════════════════════════════════════
# TASK 6 — Ticket status update (structured output)
# ════════════════════════════════════════════════════════════════════
run_task "T06" "Ticket status update (structured)" \
'Generate a JSON object for a ticket status update. Output only valid JSON, nothing else.
Ticket: TKT-0013, new status: resolved, resolution: "Warden agent built and passing 9/9 checks", resolved_by: Yoda, date: 2026-04-28' \
"python3 -c \"import json,sys; d=json.loads(sys.stdin.read()); print('ok') if d.get('status')=='resolved' or d.get('new_status')=='resolved' or 'resolved' in str(d) else print('')\""

# ════════════════════════════════════════════════════════════════════
# TASK 7 — Backlog prioritisation summary
# ════════════════════════════════════════════════════════════════════
run_task "T07" "Backlog priority summary" \
"Given this backlog, list only the High priority items by title, one per line. Nothing else.
Items:
- [Low] Set up Tailscale
- [High] Fix cost tracker parser (US22)
- [Medium] OC2 deployment planning
- [High] Resilient outage handling (US23)
- [Low] Voice message support" \
"grep -i 'US22\|US23\|cost tracker\|outage'"

# ════════════════════════════════════════════════════════════════════
# TASK 8 — Cold-load timing (run a second time to test warm cache)
# ════════════════════════════════════════════════════════════════════
run_task "T08" "Warm response latency (repeat T01)" \
"You are a cost reporting agent. Given this JSON cost data, write a one-line summary under 20 words.
Data: {\"date\":\"2026-04-28\",\"totalCost\":14.20,\"totalTurns\":161,\"byModel\":{\"claude-sonnet-4-6\":{\"cost\":14.20,\"turns\":161}}}
Output only the one-line summary, nothing else." \
"grep -iE '\\\$14|14\.2|161|sonnet'"

# ════════════════════════════════════════════════════════════════════
# RESULTS
# ════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════"
echo "  RESULTS: $TOTAL_PASS PASS  $TOTAL_FAIL FAIL  ($(( TOTAL_PASS * 100 / (TOTAL_PASS + TOTAL_FAIL) ))%)"
echo "════════════════════════════════════════════════════════════"

# Memory footprint after benchmark
MEM_USED=$(curl -s http://localhost:11434/api/ps 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
for m in d.get('models',[]):
    if '$MODEL' in m.get('name',''):
        print(f'{round(m.get(\"size\",0)/1e9,1)} GB')
        exit()
print('unloaded')
" 2>/dev/null || echo "unknown")

echo "  Model memory footprint: $MEM_USED"
echo ""

# Save results JSON
RESULTS_JSON="["
for i in "${!RESULTS[@]}"; do
  [ $i -gt 0 ] && RESULTS_JSON+=","
  RESULTS_JSON+="${RESULTS[$i]}"
done
RESULTS_JSON+="]"

python3 -c "
import json
results = $RESULTS_JSON
summary = {
    'model': '$MODEL',
    'timestamp': '$TIMESTAMP',
    'passCount': $TOTAL_PASS,
    'failCount': $TOTAL_FAIL,
    'passRate': round($TOTAL_PASS * 100 / ($TOTAL_PASS + $TOTAL_FAIL), 1),
    'tasks': results
}
with open('$RESULT_FILE', 'w') as f:
    json.dump(summary, f, indent=2)
print(f'Results saved: $RESULT_FILE')
"
