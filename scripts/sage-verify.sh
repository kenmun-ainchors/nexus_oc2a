#!/bin/bash
# sage-verify.sh — Verifier Corpus Runner + Sage Verdict Dispatcher
# TKT-0764 A3 — CREST v1.3 External-Loop Discipline
#
# Runs verifier corpus file(s) in the parent workspace, captures raw results,
# and prepares a Sage verdict prompt for the orchestrator to dispatch.
#
# Usage:
#   bash scripts/sage-verify.sh --run-id <id> --ticket <TKT-XXXX> --corpus <file>
#   bash scripts/sage-verify.sh --run-id <id> --ticket <TKT-XXXX> --corpus <file1,file2,...>
#
# Flags:
#   --run-id <id>       Required. Unique identifier for this verification run.
#   --ticket <TKT-XXXX> Required. Ticket number being verified.
#   --corpus <file>     Required. Path to verifier corpus file, or comma-separated list.
#   --state-dir <dir>   Optional. Directory for output files (default: state/).
#   --help              Show this message.
#
# Output:
#   state/sage-verify-<run-id>.jsonl       — Raw results (one JSON object per corpus file)
#   state/sage-verify-<run-id>-verdict.json — Sage verdict (written by orchestrator after dispatch)
#
# Exit codes:
#   0  All corpus checks passed (verdict: pass)
#   1  One or more corpus checks failed (verdict: fail)
#   2  Verdict is needs_human (ambiguous results)
#
# Notes:
#   - Sage verdict is NOT dispatched inside this script. The orchestrator (Yoda)
#     dispatches Sage after this script returns, using the raw results file.
#   - This script prints a ready-to-use Sage prompt on stdout for the orchestrator.
#   - All corpus files are run regardless of failures (no early exit).

set -euo pipefail

JQ="${JQ:-$(command -v jq 2>/dev/null || echo /usr/bin/jq)}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Defaults ──────────────────────────────────────────────────
STATE_DIR="state"
RUN_ID=""
TICKET=""
CORPUS_FILES=()

# ── Usage ──────────────────────────────────────────────────────
usage() {
  cat <<'USAGE'
sage-verify.sh — Verifier Corpus Runner + Sage Verdict Dispatcher
TKT-0764 A3 — CREST v1.3 External-Loop Discipline

SYNTAX:
  sage-verify.sh --run-id <id> --ticket <TKT-XXXX> --corpus <file>
  sage-verify.sh --run-id <id> --ticket <TKT-XXXX> --corpus <file1,file2,...>

FLAGS:
  --run-id <id>       Required. Unique identifier for this verification run.
  --ticket <TKT-XXXX> Required. Ticket number being verified.
  --corpus <file>     Required. Path to verifier corpus file, or comma-separated list.
  --state-dir <dir>   Optional. Directory for output files (default: state/).
  --help              Show this message.

OUTPUT:
  state/sage-verify-<run-id>.jsonl       — Raw results (one JSON object per corpus file)
  state/sage-verify-<run-id>-verdict.json — Sage verdict (written by orchestrator after dispatch)

EXIT CODES:
  0  All corpus checks passed (verdict: pass)
  1  One or more corpus checks failed (verdict: fail)
  2  Verdict is needs_human (ambiguous results)

NOTES:
  - Sage verdict is NOT dispatched inside this script. The orchestrator (Yoda)
    dispatches Sage after this script returns, using the raw results file.
  - All corpus files are run regardless of failures (no early exit).
USAGE
  exit 0
}

# ── Parse flags ───────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      RUN_ID="$2"
      shift 2
      ;;
    --ticket)
      TICKET="$2"
      shift 2
      ;;
    --corpus)
      IFS=',' read -ra CORPUS_ARRAY <<< "$2"
      for f in "${CORPUS_ARRAY[@]}"; do
        CORPUS_FILES+=("$f")
      done
      shift 2
      ;;
    --state-dir)
      STATE_DIR="$2"
      shift 2
      ;;
    --help)
      usage
      ;;
    *)
      echo "ERROR: unknown flag: $1" >&2
      usage
      ;;
  esac
done

# ── Validate required flags ───────────────────────────────────
if [[ -z "$RUN_ID" ]]; then
  echo '{"status":"fail","reason":"--run-id is required"}' >&2
  exit 1
fi

if [[ -z "$TICKET" ]]; then
  echo '{"status":"fail","reason":"--ticket is required"}' >&2
  exit 1
fi

if [[ ${#CORPUS_FILES[@]} -eq 0 ]]; then
  echo '{"status":"fail","reason":"--corpus is required (one or more file paths)"}' >&2
  exit 1
fi

# ── Resolve paths ─────────────────────────────────────────────
# Ensure state directory exists
mkdir -p "$STATE_DIR"

# Resolve corpus files relative to workspace
RESOLVED_CORPUS=()
for f in "${CORPUS_FILES[@]}"; do
  if [[ "$f" = /* ]]; then
    RESOLVED_CORPUS+=("$f")
  else
    RESOLVED_CORPUS+=("$WORKSPACE_DIR/$f")
  fi
done

# ── Run corpus files ──────────────────────────────────────────
RAW_RESULTS_FILE="${STATE_DIR}/sage-verify-${RUN_ID}.jsonl"
VERDICT_FILE="${STATE_DIR}/sage-verify-${RUN_ID}-verdict.json"

# Clear previous results
: > "$RAW_RESULTS_FILE"

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

for corpus_file in "${RESOLVED_CORPUS[@]}"; do
  if [[ ! -f "$corpus_file" ]]; then
    # Corpus file not found — record as failure
    RESULT_JSON=$("$JQ" -n \
      --arg file "$corpus_file" \
      --arg exit_code "127" \
      --arg stdout "" \
      --arg stderr "ERROR: corpus file not found: ${corpus_file}" \
      --arg duration_ms "0" \
      '{
        file: $file,
        exit_code: ($exit_code | tonumber),
        stdout: $stdout,
        stderr: $stderr,
        duration_ms: ($duration_ms | tonumber)
      }')
    echo "$RESULT_JSON" >> "$RAW_RESULTS_FILE"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    continue
  fi

  # Run the corpus file and capture results
  START_MS=$(date +%s%N 2>/dev/null || echo 0)
  START_MS=${START_MS%??????}  # Convert nanoseconds to milliseconds

  # Create temp files for stdout/stderr
  STDOUT_FILE=$(mktemp)
  STDERR_FILE=$(mktemp)
  EXIT_CODE=0

  # Run the corpus file — capture stdout and stderr separately
  # Use bash to execute the corpus file (it may be a script or sourced)
  set +e
  bash "$corpus_file" > "$STDOUT_FILE" 2> "$STDERR_FILE"
  EXIT_CODE=$?
  set -e

  END_MS=$(date +%s%N 2>/dev/null || echo 0)
  END_MS=${END_MS%??????}  # Convert nanoseconds to milliseconds

  DURATION_MS=$((END_MS - START_MS))
  if [[ $DURATION_MS -lt 0 ]]; then
    DURATION_MS=0
  fi

  # Read captured output (trim to last 2000 chars)
  STDOUT_CONTENT=$(tail -c 2000 "$STDOUT_FILE" 2>/dev/null || echo "")
  STDERR_CONTENT=$(tail -c 2000 "$STDERR_FILE" 2>/dev/null || echo "")

  # Clean up temp files
  rm -f "$STDOUT_FILE" "$STDERR_FILE"

  # Build result JSON
  RESULT_JSON=$("$JQ" -n \
    --arg file "$corpus_file" \
    --argjson exit_code "$EXIT_CODE" \
    --arg stdout "$STDOUT_CONTENT" \
    --arg stderr "$STDERR_CONTENT" \
    --argjson duration_ms "$DURATION_MS" \
    '{
      file: $file,
      exit_code: $exit_code,
      stdout: $stdout,
      stderr: $stderr,
      duration_ms: $duration_ms
    }')

  echo "$RESULT_JSON" >> "$RAW_RESULTS_FILE"

  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  if [[ $EXIT_CODE -eq 0 ]]; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
  else
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
  fi
done

# ── Determine preliminary verdict ─────────────────────────────
# Preliminary verdict based on raw results:
#   - All exit 0 → pass
#   - Some exit non-zero → fail
#   - needs_human is only set by Sage; we default to pass/fail here
if [[ $FAILED_CHECKS -eq 0 ]]; then
  PRELIMINARY_VERDICT="pass"
  PRELIMINARY_EXIT=0
else
  PRELIMINARY_VERDICT="fail"
  PRELIMINARY_EXIT=1
fi

# ── Print summary to stderr ───────────────────────────────────
echo "=== sage-verify.sh — Run Summary ===" >&2
echo "  Run ID:      ${RUN_ID}" >&2
echo "  Ticket:      ${TICKET}" >&2
echo "  Corpus:      ${CORPUS_FILES[*]}" >&2
echo "  Total:       ${TOTAL_CHECKS}" >&2
echo "  Passed:      ${PASSED_CHECKS}" >&2
echo "  Failed:      ${FAILED_CHECKS}" >&2
echo "  Verdict:     ${PRELIMINARY_VERDICT} (preliminary — Sage will confirm)" >&2
echo "  Raw results: ${RAW_RESULTS_FILE}" >&2
echo "" >&2

# ── Print Sage dispatch prompt to stdout ──────────────────────
# The orchestrator (Yoda) should use this to dispatch Sage for the final verdict.
cat <<PROMPT
=== SAGE VERDICT PROMPT ===
Run ID: ${RUN_ID}
Ticket: ${TICKET}
Raw results file: ${RAW_RESULTS_FILE}

To dispatch Sage for final verdict, use:

sessions_spawn(
  agentId="qa",
  task="Render verdict for verification run ${RUN_ID} (${TICKET}).
Read raw results from: ${RAW_RESULTS_FILE}
Analyze each corpus file result (exit_code, stdout, stderr, duration_ms).
Return verdict as JSON: {\"verdict\":\"pass|fail|needs_human\",\"summary\":\"one-paragraph evidence summary\"}
Write verdict to: ${VERDICT_FILE}",
  timeoutSeconds=120
)

After Sage returns, read ${VERDICT_FILE} and exit accordingly:
  verdict=pass → exit 0
  verdict=fail → exit 1
  verdict=needs_human → exit 2
=== END SAGE PROMPT ===
PROMPT

# ── Exit with preliminary verdict ─────────────────────────────
exit $PRELIMINARY_EXIT
