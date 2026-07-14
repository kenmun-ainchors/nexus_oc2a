#!/usr/bin/env bash
# qwen3-benchmark.sh — Re-test qwen3 with /no_think via /api/chat (no token limit)
# US35 / TKT-0014 — Tier 3 candidate evaluation
export PATH="$PATH:/usr/local/bin:/opt/homebrew/bin"
set -euo pipefail

MODEL="${1:-qwen3:4b}"
WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"
RESULTS_DIR="$WORKSPACE/state/benchmark"
STAMP=$(date +"%Y%m%d-%H%M%S")
RESULT_FILE="$RESULTS_DIR/qwen3-bench-${MODEL//[:\/]/-}-$STAMP.json"
OLLAMA_URL="http://localhost:11434/api/chat"
mkdir -p "$RESULTS_DIR"

echo "🧪 qwen3 Benchmark (no_think) — $MODEL"
echo "Started: $(date '+%Y-%m-%d %H:%M %Z')"
echo "────────────────────────────────────────────────────────────"

RESULTS=()
TOTAL_PASS=0
TOTAL_FAIL=0

run_task() {
  local task_id="$1"
  local task_name="$2"
  local prompt="$3"
  local validator="$4"

  echo ""
  echo "[$task_id] $task_name"

  local start_ms end_ms duration_ms
  start_ms=$(python3 -c "import time; print(int(time.time()*1000))")

  # /no_think must be the very first token in the user message
  local full_prompt="/no_think
${prompt}"

  local output
  output=$(python3 - <<PYEOF
import json, urllib.request

payload = {
    "model": "$MODEL",
    "messages": [{"role": "user", "content": $(echo "$full_prompt" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}],
    "stream": False,
    "options": {"temperature": 0}
}
req = urllib.request.Request("$OLLAMA_URL", data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
with urllib.request.urlopen(req, timeout=120) as resp:
    d = json.loads(resp.read())
    print(d.get("message", {}).get("content", "").strip())
PYEOF
2>/dev/null || echo "ERROR: request failed")

  end_ms=$(python3 -c "import time; print(int(time.time()*1000))")
  duration_ms=$((end_ms - start_ms))

  local pass=0
  if [ "$validator" = "nonempty" ]; then
    [ -n "$output" ] && [ "$output" != "ERROR: request failed" ] && pass=1
  else
    local validator_result
    validator_result=$(echo "$output" | eval "$validator" 2>/dev/null || echo "")
    [ -n "$validator_result" ] && pass=1
  fi

  local status="PASS"
  [ $pass -eq 0 ] && status="FAIL"

  echo "  Status:   $status"
  echo "  Latency:  ${duration_ms}ms"
  echo "  Output:   $(echo "$output" | head -2 | tr '\n' ' ' | cut -c1-120)"

  [ $pass -eq 1 ] && TOTAL_PASS=$((TOTAL_PASS + 1)) || TOTAL_FAIL=$((TOTAL_FAIL + 1))
  RESULTS+=("{\"id\":\"$task_id\",\"name\":\"$(echo "$task_name" | sed 's/"/\\"/g')\",\"status\":\"$status\",\"latencyMs\":$duration_ms,\"model\":\"$MODEL\"}")
}

echo "Running 8 tasks with /no_think..."

run_task "T01" "Cost summary formatting" \
'You are a cost reporting agent. Given this JSON cost data, write a one-line summary under 20 words.
Data: {"date":"2026-04-28","totalCost":12.45,"totalTurns":143}
Output only the one-line summary, nothing else.' \
"grep -iE '\\\$12|12\.4|143'"

run_task "T02" "Health check: single word output" \
'Health status: {"gateway":"running","ollama":"running","consecutiveFailures":0,"diskUsagePercent":42}
Output exactly one word: OK, WARN, or CRITICAL — nothing else.' \
"grep -xE 'OK|WARN|CRITICAL'"

run_task "T03" "CHANGELOG entry formatting" \
'Format as a single markdown line matching this exact pattern: ## YYYY-MM-DD HH:MM AEST — [CHG-XXXX] Title
Input: Date=2026-04-28 08:15, ID=CHG-0047, Title=Update model policy to Sonnet-only
Output only the formatted line, nothing else.' \
"grep -E '## 2026-04-28.*\[CHG-0047\]'"

run_task "T04" "JSON field extraction: single word" \
'From this JSON, extract the "status" for the agent with id "business". Output only the value, nothing else.
{"agents":{"list":[{"id":"main","status":"active"},{"id":"business","status":"idle"},{"id":"governance","status":"active"}]}}' \
"grep -xE 'idle'"

run_task "T05" "Task routing classification: single word" \
"Classify this task into SIMPLE, MODERATE, or COMPLEX.
Task: 'Read cost-state.json and return the totalCost value for 2026-04-28'
Output only: SIMPLE, MODERATE, or COMPLEX — nothing else." \
"grep -xE 'SIMPLE|MODERATE|COMPLEX'"

run_task "T06" "Structured JSON output" \
'Generate a JSON object for a ticket update. Output only valid JSON, nothing else.
Ticket: TKT-0013, status: resolved, resolution: "Warden agent passing 9/9 checks", resolved_by: Yoda, date: 2026-04-28' \
"python3 -c \"import json,sys; d=json.loads(sys.stdin.read()); print('ok') if 'resolved' in str(d) else print('')\""

run_task "T07" "Backlog priority filter" \
'List only the High priority items by title, one per line. Nothing else.
- [Low] Set up Tailscale
- [High] Fix cost tracker parser (US22)
- [Medium] OC2 deployment planning
- [High] Resilient outage handling (US23)
- [Low] Voice message support' \
"grep -i 'US22\|US23\|cost tracker\|outage'"

run_task "T08" "Warm latency repeat (T01 variant)" \
'You are a cost reporting agent. Given this JSON cost data, write a one-line summary under 20 words.
Data: {"date":"2026-04-28","totalCost":14.20,"totalTurns":161}
Output only the one-line summary, nothing else.' \
"grep -iE '\\\$14|14\.2|161'"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "RESULTS — $MODEL"
echo "  PASS: $TOTAL_PASS / $((TOTAL_PASS + TOTAL_FAIL))"
echo "  FAIL: $TOTAL_FAIL / $((TOTAL_PASS + TOTAL_FAIL))"
echo "════════════════════════════════════════════════════════════"

RESULTS_JSON=$(IFS=,; echo "[${RESULTS[*]}]")
cat > "$RESULT_FILE" <<EOF
{
  "model": "$MODEL",
  "benchmark": "qwen3-nothink-v3",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "noThinkPrefix": true,
  "pass": $TOTAL_PASS,
  "fail": $TOTAL_FAIL,
  "total": $((TOTAL_PASS + TOTAL_FAIL)),
  "passRate": "$(echo "scale=0; $TOTAL_PASS * 100 / $((TOTAL_PASS + TOTAL_FAIL))" | bc)%",
  "results": $RESULTS_JSON
}
EOF
echo "Saved: $RESULT_FILE"
