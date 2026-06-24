#!/bin/bash
# atom-validate.sh — Level 2 Atom Pre-Flight Gate (CREST v1.2 §8.2)
# Validates atom JSON before specialist dispatches to cheap executor.
# 6 machine checks: verb, target, pre_conditions, post_conditions, atom, model
#
# Usage:
#   echo '{...}' | bash scripts/atom-validate.sh
#   bash scripts/atom-validate.sh --json '{...}'
#   bash scripts/atom-validate.sh --json '{...}' --verbose
#   bash scripts/atom-validate.sh --help
#
# Exit 0: valid atom → {"status":"ok"}
# Exit 1: invalid   → {"status":"fail","failures":[...]}

set -euo pipefail

JQ="${JQ:-/opt/homebrew/bin/jq}"
VERBOSE=false

usage() {
  cat <<'EOF'
atom-validate.sh — CREST v1.2 §8.2 Level 2 Atom Pre-Flight Gate

Validates atom JSON against 6 structural checks before dispatch to cheap executor.

SYNTAX:
  atom-validate.sh --json '{"verb":"read",...}'     # atom as CLI argument
  atom-validate.sh --stdin                           # read atom from stdin
  cat atom.json | atom-validate.sh                   # stdin (default)
  atom-validate.sh --help                            # this message

FLAGS:
  --json '...'    Atom JSON string
  --stdin         Read JSON from stdin (default when no --json)
  --verbose       Include all field check results in output (pass + fail)
  --help          Show usage

CHECKS (CREST v1.2 §8.2):
  1. verb            Present and non-empty
  2. target          Present and non-empty
  3. pre_conditions  Array with ≥1 non-empty entry
  4. post_conditions Array with ≥1 non-empty entry
  5. atom            Non-null, non-whitespace
  6. model           Explicit (non-empty, not "auto", not "default")
  7. verifier_corpus Required when phase is execute or verify (non-empty string or array)

EXIT CODES:
  0  All checks passed → {"status":"ok"}
  1  One or more failures → {"status":"fail","failures":[{"field":"...","reason":"..."}]}

AUTHOR:
  Forge 🏗️ — TKT-0384 — 2026-06-10
EOF
  exit 0
}

# ── Parse flags ──────────────────────────────────────────────
JSON_INPUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      JSON_INPUT="$2"
      shift 2
      ;;
    --stdin)
      JSON_INPUT=""
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      usage
      ;;
    *)
      echo '{"status":"fail","failures":[{"field":"flags","reason":"unknown flag: '"$1"'"}]}'
      exit 1
      ;;
  esac
done

# ── Acquire JSON ─────────────────────────────────────────────
if [[ -z "$JSON_INPUT" ]]; then
  # Read from stdin
  JSON_INPUT=$(cat)
fi

if [[ -z "$JSON_INPUT" ]]; then
  echo '{"status":"fail","failures":[{"field":"input","reason":"no JSON provided (empty --json or stdin)"}]}'
  exit 1
fi

# ── Validate parseable JSON ──────────────────────────────────
if ! echo "$JSON_INPUT" | "$JQ" empty 2>/dev/null; then
  if ! echo "$JSON_INPUT" | "$JQ" -e . >/dev/null 2>&1; then
    echo '{"status":"fail","failures":[{"field":"input","reason":"invalid JSON: cannot parse"}]}'
    exit 1
  fi
fi

# ── Helper: report a single field check ──────────────────────
# Uses jq --arg to safely embed arbitrary reason text (no escaping issues)
check() {
  local field="$1" expr="$2" fail_reason="$3"
  local result
  result=$(echo "$JSON_INPUT" | "$JQ" -r "$expr" 2>/dev/null) || true
  if [[ "$result" == "pass" ]]; then
    if $VERBOSE; then
      "$JQ" -n --arg f "$field" '{"field":$f,"status":"pass"}'
    fi
    return 0
  else
    "$JQ" -n --arg f "$field" --arg r "$fail_reason" '{"field":$f,"reason":$r}'
    return 1
  fi
}

# ── 6 structural checks ──────────────────────────────────────
FAILURES=()
PASSES=0

# 1. verb: present and non-empty
if RESULT=$(check "verb" \
  'if .verb and (.verb | type == "string") and ((.verb | length) > 0) then "pass" else "fail" end' \
  "missing or empty"); then
  ((PASSES++))
else
  FAILURES+=("$RESULT")
fi

# 2. target: present and non-empty
if RESULT=$(check "target" \
  'if .target and (.target | type == "string") and ((.target | length) > 0) then "pass" else "fail" end' \
  "missing or empty"); then
  ((PASSES++))
else
  FAILURES+=("$RESULT")
fi

# 3. pre_conditions: array with ≥1 item
if RESULT=$(check "pre_conditions" \
  'if .pre_conditions and (.pre_conditions | type == "array") and ((.pre_conditions | length) > 0) then "pass" else "fail" end' \
  "must be non-empty array"); then
  ((PASSES++))
else
  FAILURES+=("$RESULT")
fi

# 4. post_conditions: array with ≥1 item
if RESULT=$(check "post_conditions" \
  'if .post_conditions and (.post_conditions | type == "array") and ((.post_conditions | length) > 0) then "pass" else "fail" end' \
  "must be non-empty array"); then
  ((PASSES++))
else
  FAILURES+=("$RESULT")
fi

# 5. atom: non-null, non-whitespace
if RESULT=$(check "atom" \
  'if .atom and (.atom | type == "string") and ((.atom | test("[^[:space:]]")) | not | not) then "pass" else "fail" end' \
  "missing, null, or whitespace-only"); then
  ((PASSES++))
else
  FAILURES+=("$RESULT")
fi

# 6. model: explicit — non-empty, not "auto", not "default"
if RESULT=$(check "model" \
  'if .model and (.model | type == "string") and ((.model | length) > 0) and (.model != "auto") and (.model != "default") then "pass" else "fail" end' \
  "must be explicit (not empty, not \"auto\", not \"default\")"); then
  ((PASSES++))
else
  FAILURES+=("$RESULT")
fi

# 7. verifier_corpus: required when phase is execute or verify
# Must be a non-empty string or non-empty array
if RESULT=$(check "verifier_corpus" \
  'if (.phase == "execute" or .phase == "verify") then
    if .verifier_corpus then
      if (.verifier_corpus | type == "string") and ((.verifier_corpus | length) > 0) then
        "pass"
      elif (.verifier_corpus | type == "array") and ((.verifier_corpus | length) > 0) then
        "pass"
      else
        "fail"
      end
    else
      "fail"
    end
  else
    "pass"
  end' \
  "must be non-empty string or array when phase is execute or verify"); then
  ((PASSES++))
else
  FAILURES+=("$RESULT")
fi

# ── Output ───────────────────────────────────────────────────
if [[ ${#FAILURES[@]} -eq 0 ]]; then
  if $VERBOSE; then
    echo '{"status":"ok","checks_passed":7}'
  else
    echo '{"status":"ok"}'
  fi
  exit 0
else
  # Build JSON array from failure entries
  FAIL_JSON=$(printf '%s\n' "${FAILURES[@]}" | "$JQ" -s '.')
  echo "{\"status\":\"fail\",\"failures\":$FAIL_JSON}"
  exit 1
fi
