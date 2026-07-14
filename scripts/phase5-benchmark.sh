#!/usr/bin/env zsh
# Phase 5 — Ollama Cloud Benchmark Script
# Tests kimi-k2.6:cloud, glm-5.1:cloud, qwen3.5:cloud across B1-B5
# Usage: zsh phase5-benchmark.sh

zmodload zsh/datetime 2>/dev/null || true

OUT_DIR="/Users/ainchorsoc2a/.openclaw/workspace/state/phase5-results"
mkdir -p "$OUT_DIR"

run_task() {
  local MODEL="$1"
  local TASK="$2"
  local PROMPT="$3"
  local MODEL_SLUG="${MODEL//[:.\/]/_}"

  # For qwen3.5:cloud, prepend /no_think to disable thinking mode
  local FULL_PROMPT="$PROMPT"
  if [[ "$MODEL" == "qwen3.5:cloud" ]]; then
    FULL_PROMPT="/no_think ${PROMPT}"
  fi

  local OUT_FILE="$OUT_DIR/${MODEL_SLUG}_${TASK}.txt"

  echo "--- MODEL: $MODEL | TASK: $TASK ---"
  local START_TIME=$EPOCHREALTIME
  ollama run "$MODEL" "$FULL_PROMPT" > "$OUT_FILE" 2>&1
  local STATUS=$?
  local END_TIME=$EPOCHREALTIME
  local ELAPSED=$(printf "%.1f" $(( END_TIME - START_TIME )))

  echo "Latency: ${ELAPSED}s | ExitCode: $STATUS"
  echo "TIMING:${MODEL}:${TASK}:${ELAPSED}s"
  echo "Preview:"
  head -6 "$OUT_FILE"
  echo "---END---"
  echo ""
}

B1="You are an AI ops agent. List the top 3 risks of running frontier LLMs on shared cloud infrastructure for a small business. Be concise."
B2="Write a 20-line Python function that routes a task to either local or cloud model based on data_sensitivity (high=local, low=cloud) and task_complexity (high=cloud, low=local)."
B3="Write a 3-sentence LinkedIn post from an Australian AI consulting firm announcing they use local + cloud AI routing to cut costs by 60%."
B4="You have a tool called get_calendar_events(date: str). Write the exact JSON tool call to check events for 2026-05-02."
B5="A client asks you to store their medical records in a cloud AI system. What is the correct response from a data sovereignty perspective? Be concise."

for MODEL in "kimi-k2.6:cloud" "glm-5.1:cloud" "qwen3.5:cloud"; do
  echo "========================================"
  echo "STARTING MODEL: $MODEL"
  echo "========================================"

  run_task "$MODEL" "B1" "$B1"
  run_task "$MODEL" "B2" "$B2"
  run_task "$MODEL" "B3" "$B3"
  run_task "$MODEL" "B4" "$B4"
  run_task "$MODEL" "B5" "$B5"

  echo "======== DONE: $MODEL ========"
  echo ""
done

echo "Phase 5 benchmark COMPLETE."
echo "Results in: $OUT_DIR"
