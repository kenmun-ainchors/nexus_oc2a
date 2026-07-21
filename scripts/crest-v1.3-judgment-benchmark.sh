#!/bin/bash
# crest-v1.3-judgment-benchmark.sh
# Runs 20 synthetic atoms through glm-5.1:cloud as Verify judge.
# 10 known-pass + 10 known-fail. Threshold: >=90% (18/20).
# Output: state/crest-v1.3-judgment-benchmark.json

set -euo pipefail

# CHG-0965 / TKT-1025 (2026-07-21): default model swapped to gemma4:26b. Ad-hoc
# comparison on 2026-07-19 showed gemma4:26b matches gemma4:31b-cloud 20/20 on
# this benchmark and is ~5x faster wall-clock with substantially lower jitter
# (1.98s vs 31.23s). See state/gemma4-26b-vs-31b-crest-benchmark-2026-07-21.json.
# Ken approved the swap (NEEDS-KEN-CREST-BENCHMARK-26B resolved 2026-07-21).
# think:false injection remains in place (TKT-1017 / CHG-0956). The MODEL and
# RESULT_FILE env vars still work — override MODEL=gemma4:31b-cloud to retest
# against the cloud baseline, e.g. for regression checks after gateway/think
# changes. Note: CHG-0963 / TKT-1024 (ad-hoc 2026-07-21) is the policy
# change that made gemma4:26b the approved direct-call model on OC2A; this
# benchmark default follows that policy.
MODEL="${MODEL:-gemma4:26b}"
RESULT_FILE="${RESULT_FILE:-state/crest-v1.3-judgment-benchmark.json}"
OLLAMA="http://localhost:11434"

echo "=== CREST v1.3 Judgment Benchmark ==="
echo "Model: $MODEL"
echo "Atoms: 20 (10 pass, 10 fail)"
echo "Threshold: >=90% (18/20)"
echo ""

# --- SYNTHETIC ATOMS (indexed array, 20 entries) ---
ATOMS=(
  '{"id":"P01","expected":"pass","pre":"file X must exist at path Y","post":"file X exists at path Y with content Z","evidence":"file X created at path Y. Content matches Z exactly. sha256 verified. No errors in creation log."}'
  '{"id":"P02","expected":"pass","pre":"PG table state_tickets must have column notionpageid","post":"ALTER TABLE ADD COLUMN notionpageid executed without errors","evidence":"d state_tickets shows notionpageid column. Migration log shows zero errors. 15 existing rows unchanged."}'
  '{"id":"P03","expected":"pass","pre":"cron job 85595417 must have delivery.to set","post":"delivery.to = 8574109706","evidence":"cron get 85595417 returns delivery.to=8574109706. Test message delivered successfully."}'
  '{"id":"P04","expected":"pass","pre":"script X must pass bash -n","post":"bash -n script X exits 0","evidence":"bash -n output: empty (no errors). ShellCheck: 0 warnings. Script executes without runtime errors."}'
  '{"id":"P05","expected":"pass","pre":"git commit must include all changed files","post":"git status shows clean working tree after commit","evidence":"git status: nothing to commit, working tree clean. git log -1 shows expected commit message and author."}'
  '{"id":"P06","expected":"pass","pre":"Notion page must be created in Backlog DB","post":"page exists with correct title and status","evidence":"curl GET page returns 200. Title matches expected. Status is Open. notionpageid stored in PG."}'
  '{"id":"P07","expected":"pass","pre":"health-check.sh must return exit 0","post":"all checks pass, health-state.json shows ok","evidence":"health-check.sh exit 0. health-state.json: overallStatus=ok, 0 issues. All 24 checks green."}'
  '{"id":"P08","expected":"pass","pre":"db-sprint.sh defer must remove ticket from source items","post":"source sprint items array does not contain deferred ticket","evidence":"db-sprint.sh current shows items array without TKT-0326. Ticket appears in target sprint only."}'
  '{"id":"P09","expected":"pass","pre":"model-policy.json must be valid JSON","post":"jq empty exits 0","evidence":"jq empty state/model-policy.json: exit 0. All required keys present. Warden drift check passes."}'
  '{"id":"P10","expected":"pass","pre":"sprint-review.sh must generate report for Sprint 8","post":"report file exists and is non-empty","evidence":"sprint-review-report-Sprint-8.md: 4598 bytes. Contains all 10 checklist sections. Generated without errors."}'
  '{"id":"F01","expected":"fail","pre":"file X must exist at path Y","post":"file X exists at path Y with content Z","evidence":"file X not found at path Y. Creation script exited with code 1: permission denied. No file created."}'
  '{"id":"F02","expected":"fail","pre":"PG table must have new column","post":"ALTER TABLE succeeded","evidence":"ALTER TABLE failed: column already exists. Error: duplicate column name. Migration rolled back."}'
  '{"id":"F03","expected":"fail","pre":"cron delivery.to must be numeric","post":"delivery.to = 8574109706","evidence":"delivery.to = +61403650578 (contains + and country code). Telegram API returns 400 Bad Request: invalid chat_id."}'
  '{"id":"F04","expected":"fail","pre":"script must pass bash -n","post":"bash -n exits 0","evidence":"bash -n: line 42: syntax error near unexpected token fi. Script cannot parse. 3 ShellCheck errors."}'
  '{"id":"F05","expected":"fail","pre":"all changed files must be committed","post":"git status clean","evidence":"git status: 3 modified files not staged. git diff shows uncommitted changes to critical config."}'
  '{"id":"F06","expected":"fail","pre":"Notion page must be created","post":"page exists with correct title","evidence":"curl POST returned 401 Unauthorized. API key invalid. No page created. PG notionpageid is null."}'
  '{"id":"F07","expected":"fail","pre":"health-check.sh must return exit 0","post":"all checks pass","evidence":"health-check.sh exit 1. health-state.json: overallStatus=degraded. CHECK 15 failed: file size limit exceeded."}'
  '{"id":"F08","expected":"fail","pre":"deferred ticket must not appear in source sprint","post":"source sprint items array clean","evidence":"db-sprint.sh current shows TKT-0326 still in Sprint 8 items array. Defer command ran but did not clean source items."}'
  '{"id":"F09","expected":"fail","pre":"JSON file must be valid","post":"jq empty exits 0","evidence":"jq empty: parse error: Invalid literal at line 42. File is truncated. Missing closing brace."}'
  '{"id":"F10","expected":"fail","pre":"sprint-review.sh must generate report","post":"report file exists","evidence":"sprint-review.sh exited with code 1: unbound variable error. No report file generated. Error log shows set -u violation."}'
)

CORRECT=0
TOTAL=0
RESULTS_JSON='{"benchmark":"crest-v1.3-judgment","model":"'"$MODEL"'","timestamp":"'"$(date -Iseconds)"'","threshold":0.9,"atoms":[]}'

run_judge() {
  local atom_json="$1"
  local id=$(echo "$atom_json" | jq -r '.id')
  local expected=$(echo "$atom_json" | jq -r '.expected')
  local pre=$(echo "$atom_json" | jq -r '.pre')
  local post=$(echo "$atom_json" | jq -r '.post')
  local evidence=$(echo "$atom_json" | jq -r '.evidence')

  local prompt="You are a CREST Verify judge. Your job: read the atom pre-conditions, post-conditions, and evidence, then render a verdict.

Atom ID: $id
Pre-conditions: $pre
Post-conditions: $post
Evidence: $evidence

Does the evidence prove the post-conditions were met, given the pre-conditions?

Respond with EXACTLY one word: PASS or FAIL. Then on the next line, a one-sentence reason."

  # TKT-1017 / CHG-0956: gemma4 family (Ollama 0.32.1) defaults thinking=true; chain-of-thought
  # tokens consume the num_predict budget, leaving response="" with done_reason="length".
  # think:false at the top level of the request body (not inside options) disables it.
  # See state/gemma4-31b-empty-response-investigation-2026-07-21.json for full root cause.
  local resp=$(curl -s "$OLLAMA/api/generate" -d "$(jq -n --arg model "$MODEL" --arg prompt "$prompt" --argjson num_predict 100 --argjson think false '{model:$model, prompt:$prompt, stream:false, think:$think, options:{num_predict:$num_predict}}')")
  local verdict_raw=$(echo "$resp" | jq -r '.response // "ERROR"')
  local error=$(echo "$resp" | jq -r '.error // ""')

  if [[ -n "$error" ]]; then
    echo "  $id: ERROR — $error"
    TOTAL=$((TOTAL+1))
    local atom_result=$(jq -n --arg id "$id" --arg expected "$expected" --arg verdict "ERROR" --arg match "false" --arg reason "$error" '{id:$id, expected:$expected, verdict:$verdict, match:$match, reason:$reason}')
    RESULTS_JSON=$(echo "$RESULTS_JSON" | jq --argjson atom "$atom_result" '.atoms += [$atom]')
    return
  fi

  local verdict="ERROR"
  if echo "$verdict_raw" | grep -qi "^PASS"; then
    verdict="pass"
  elif echo "$verdict_raw" | grep -qi "^FAIL"; then
    verdict="fail"
  fi

  local match="false"
  if [[ "$verdict" == "$expected" ]]; then
    match="true"
    CORRECT=$((CORRECT+1))
  fi
  TOTAL=$((TOTAL+1))

  local reason=$(echo "$verdict_raw" | tail -1)
  echo "  $id: expected=$expected verdict=$verdict match=$match"
  echo "       reason: $reason"

  local atom_result=$(jq -n --arg id "$id" --arg expected "$expected" --arg verdict "$verdict" --arg match "$match" --arg reason "$reason" '{id:$id, expected:$expected, verdict:$verdict, match:$match, reason:$reason}')
  RESULTS_JSON=$(echo "$RESULTS_JSON" | jq --argjson atom "$atom_result" '.atoms += [$atom]')
}

echo "Running benchmark..."
for atom in "${ATOMS[@]}"; do
  run_judge "$atom"
  sleep 0.5
done

PCT=$(echo "scale=2; $CORRECT / $TOTAL" | bc)
PASSED="false"
if (( $(echo "$PCT >= 0.90" | bc -l) )); then
  PASSED="true"
fi

RESULTS_JSON=$(echo "$RESULTS_JSON" | jq --arg correct "$CORRECT" --arg total "$TOTAL" --arg pct "$PCT" --arg passed "$PASSED" '. + {correct:($correct|tonumber), total:($total|tonumber), pct:($pct|tonumber), passed:($passed|test("true"))}')

echo "$RESULTS_JSON" | jq '.' > "$RESULT_FILE"

echo ""
echo "=== BENCHMARK COMPLETE ==="
echo "Score: $CORRECT/$TOTAL ($PCT)"
echo "Passed: $PASSED"
echo "Result file: $RESULT_FILE"

if [[ "$PASSED" == "true" ]]; then
  echo "G4 PASSED — glm-5.1:cloud meets >=90% threshold"
  exit 0
else
  echo "G4 FAILED — glm-5.1:cloud below 90% threshold. Fallback to gemma4:31b-cloud."
  exit 1
fi
