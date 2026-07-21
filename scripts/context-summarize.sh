#!/usr/bin/env bash
# TKT-0340: context-summarize.sh — auto-summarize oversized context via LLM
# Uses deepseek-v4-flash:cloud (cheap, fixed subscription) via ollama API.
# Input: stdin or file path argument. Output: summary to stdout.
# Idempotent: skips already-summarized content.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
STATE_DIR="$SCRIPT_DIR/../state"
LOG_FILE="$STATE_DIR/context-summary-log.json"
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
MODEL="${SUMMARIZE_MODEL:-deepseek-v4-flash:cloud}"

# ── Token-window thresholds (from TKT-0337) ──────────────────────────
# Claude/GPT tier:  262K window → trigger at 209K (80%)
# DeepSeek tier:    128K window → trigger at 102K
# Gemma tier:         8K window → trigger at 6.4K
# Haiku/Kimi tier:  200K window → trigger at 160K
# deepseek-v4-flash:cloud → 128K token window (conservative)
TRIGGER_THRESHOLD="${SUMMARIZE_TRIGGER:-102000}"

# CHG-0963 / TKT-1024 (2026-07-21): When --model gemma4* is passed, this is
# now an approved direct-call site per model-policy.json directCallLocalModels.
# Think:false is auto-injected for any gemma4* model below (THINK_FIELD case).
# Recommended direct-call gemma4 model: ollama/gemma4:26b (faster, persistent).
# Gateway-mediated use via OpenClaw plugin remains blocked.

# ── Help ─────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: context-summarize.sh [OPTIONS] [FILE]

Auto-summarize oversized context using deepseek-v4-flash:cloud via ollama.

Options:
  --model MODEL       Override model (default: $MODEL)
  --trigger TOKENS    Override trigger threshold (default: $TRIGGER_THRESHOLD)
  --force             Force summarization even if below threshold
  --enforce           Enable enforcement mode (summarize content above threshold)
  --dry-run           Log intent without calling LLM (prefix: [SUMMARY-DRY-RUN])
  --help              Show this help

Input:  stdin (default) or FILE path argument
Output: summarized text to stdout; JSON log to state/context-summary-log.json
EOF
    exit 0
}

# ── Parse args ───────────────────────────────────────────────────────
FORCE=false
ENFORCE=false
DRY_RUN=false
INPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --model)
            MODEL="$2"; shift 2 ;;
        --trigger)
            TRIGGER_THRESHOLD="$2"; shift 2 ;;
        --force)
            FORCE=true; shift ;;
        --enforce)
            ENFORCE=true; shift ;;
        --dry-run)
            DRY_RUN=true; shift ;;
        --help|-h)
            usage ;;
        --)
            shift; INPUT_FILE="$1"; shift ;;
        -*)
            echo "ERROR: unknown flag: $1" >&2; exit 2 ;;
        *)
            INPUT_FILE="$1"; shift ;;
    esac
done

# ── Read input ───────────────────────────────────────────────────────
if [[ -n "$INPUT_FILE" ]]; then
    if [[ ! -f "$INPUT_FILE" ]]; then
        echo "ERROR: file not found: $INPUT_FILE" >&2
        exit 1
    fi
    CONTENT="$(cat "$INPUT_FILE")"
else
    CONTENT="$(cat)"
fi

if [[ -z "$CONTENT" ]]; then
    echo "ERROR: no input provided" >&2
    exit 1
fi

# ── Idempotency guard ────────────────────────────────────────────────
# Content that starts with "[SUMMARY]" marker has already been summarized.
if [[ "$CONTENT" =~ ^\[SUMMARY\] ]] && [[ "$FORCE" != true ]]; then
    echo "$CONTENT"
    exit 0
fi

# ── Token estimation ─────────────────────────────────────────────────
# Rough estimate: ~4 chars per token (conservative for English text).
# More accurate: ~3.5 chars per token for code/heavy text, 4 for prose.
estimate_tokens() {
    local text="$1"
    local chars="${#text}"
    # Use bc if available, otherwise integer division
    if command -v bc &>/dev/null; then
        echo "$chars / 4" | bc
    else
        echo $(( chars / 4 ))
    fi
}

TOKEN_COUNT=$(estimate_tokens "$CONTENT")

# ── Threshold check ──────────────────────────────────────────────────
if [[ "$TOKEN_COUNT" -lt "$TRIGGER_THRESHOLD" ]] && [[ "$FORCE" != true ]]; then
    # Below threshold: pass through unchanged
    echo "$CONTENT"
    exit 0
fi

# ── Dry-run / enforce check ─────────────────────────────────────────
if [[ "$DRY_RUN" == true ]]; then
    echo "[SUMMARY-DRY-RUN] $CONTENT"
    exit 0
fi

# If enforce mode is off and force is off, pass through unchanged (report-only)
if [[ "$ENFORCE" != true ]] && [[ "$FORCE" != true ]]; then
    echo "$CONTENT"
    exit 0
fi

# ── Summarization ────────────────────────────────────────────────────
SUMMARIZE_PROMPT="You are a context summarizer. Summarize the following content concisely. Preserve: key decisions, facts, action items, dates, names, and any TODO/completed items. Omit: fluff, repetition, greetings, and filler. Output ONLY the summary, prefixed with \"[SUMMARY]\". Do not add commentary.

CONTENT:
$CONTENT"

# Escape the prompt for JSON
ESCAPED_PROMPT="$(echo "$SUMMARIZE_PROMPT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo "$SUMMARIZE_PROMPT" | sed 's/\\/\\\\/g; s/"/\\"/g')"

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
CONTENT_SHA="$(echo "$CONTENT" | shasum -a 256 | cut -d' ' -f1)"

# Try ollama API — write body + HTTP code to temp, then split
TMPFILE="/tmp/context-summarize-response.$$.txt"
HTTP_CODE=""
SUMMARY=""
SUCCESS=false

# TKT-1017 / CHG-0956: gemma4 family (Ollama 0.32.1) defaults thinking=true; chain-of-thought
# tokens consume the num_predict budget, leaving response="" with done_reason="length".
# Add think:false at the top level of the request body (not inside options) for gemma4.
# Generic gemma4-family check covers: gemma4, gemma4:latest, gemma4:8b/12b/26b/31b, etc.
# See state/gemma4-31b-empty-response-investigation-2026-07-21.json for full root cause.
THINK_FIELD=""
case "$MODEL" in
    gemma4*) THINK_FIELD=',"think":false' ;;
esac

# Use -w to append HTTP code on a new line at end of stdout; capture all stdout
FULL_OUTPUT="$(curl -s --connect-timeout 5 --max-time 60 \
    -w "\n__HTTP_CODE__%{http_code}" \
    "${OLLAMA_URL}/api/generate" \
    -d "{\"model\":\"$MODEL\",\"prompt\":$ESCAPED_PROMPT,\"stream\":false${THINK_FIELD}}" \
    2>/dev/null || echo "__HTTP_CODE__000")"

# Extract HTTP code (last line marker)
HTTP_CODE="$(echo "$FULL_OUTPUT" | grep '__HTTP_CODE__' | tail -1 | sed 's/.*__HTTP_CODE__//')"
# Extract body (everything before the marker line)
RESPONSE="$(echo "$FULL_OUTPUT" | sed '/__HTTP_CODE__/,$d')"

if [[ "$HTTP_CODE" == "200" ]] && [[ -n "$RESPONSE" ]]; then
    # Extract the "response" field from ollama's JSON output
    SUMMARY="$(echo "$RESPONSE" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get("response", "").strip())
except:
    print("")
' 2>/dev/null)"

    if [[ -n "$SUMMARY" ]]; then
        SUCCESS=true
        # Ensure [SUMMARY] prefix
        if [[ ! "$SUMMARY" =~ ^\[SUMMARY\] ]]; then
            SUMMARY="[SUMMARY] $SUMMARY"
        fi
    fi
fi

rm -f "$TMPFILE"

# ── Fallback ─────────────────────────────────────────────────────────
if [[ "$SUCCESS" != true ]]; then
    echo "WARNING: ollama summarization failed (HTTP $HTTP_CODE), passing through unchanged" >&2
    SUMMARY="$CONTENT"
    # Reset to success for logging — we're falling back, not failing
    SUCCESS="fallback"
fi

# ── Logging ──────────────────────────────────────────────────────────
mkdir -p "$STATE_DIR"

# Build log entry JSON — write to temp file via heredoc to avoid quoting hell
SUCCESS_STR="$SUCCESS" \
INPUT_CHARS="${#CONTENT}" \
OUTPUT_CHARS="${#SUMMARY}" \
TIMESTAMP="$TIMESTAMP" \
MODEL="$MODEL" \
CONTENT_SHA="$CONTENT_SHA" \
TOKEN_COUNT="$TOKEN_COUNT" \
TRIGGER_THRESHOLD="$TRIGGER_THRESHOLD" \
python3 << 'PYEOF' > /tmp/context-summarize-logentry.$$.json
import json, os
success_raw = os.environ.get('SUCCESS_STR', 'false')
if success_raw == 'true':
    success_str = 'true'
elif success_raw == 'fallback':
    success_str = 'fallback'
else:
    success_str = 'false'

input_chars = int(os.environ.get('INPUT_CHARS', 0))
output_chars = int(os.environ.get('OUTPUT_CHARS', 0))

entry = {
    'timestamp': os.environ.get('TIMESTAMP', ''),
    'model': os.environ.get('MODEL', ''),
    'content_sha256': os.environ.get('CONTENT_SHA', ''),
    'input_tokens_est': int(os.environ.get('TOKEN_COUNT', 0)),
    'input_chars': input_chars,
    'output_chars': output_chars,
    'trigger_threshold': int(os.environ.get('TRIGGER_THRESHOLD', 0)),
    'success': success_str,
    'truncated': output_chars < input_chars
}
print(json.dumps(entry))
PYEOF

LOG_ENTRY="$(cat /tmp/context-summarize-logentry.$$.json 2>/dev/null)"
rm -f /tmp/context-summarize-logentry.$$.json

# Append to log file
if [[ -n "$LOG_ENTRY" ]]; then
    if [[ ! -f "$LOG_FILE" ]]; then
        echo "[]" > "$LOG_FILE"
    fi
    python3 -c "
import json
log_path = '$LOG_FILE'
entry = json.loads(open('/dev/stdin').read())
try:
    with open(log_path, 'r') as f:
        log = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    log = []
log.append(entry)
with open(log_path, 'w') as f:
    json.dump(log, f, indent=2)
" <<< "$LOG_ENTRY" 2>/dev/null || true
fi

# ── Output ───────────────────────────────────────────────────────────
echo "$SUMMARY"
