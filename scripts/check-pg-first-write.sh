#!/bin/bash
# check-pg-first-write.sh — PG-First Write Enforcement Gate
# TKT-0976: Fast-follow from TKT-0359 enforcement gate.
#
# Reads state/pg-first-write-registry.json, checks Class 1 writers,
# returns JSON verdict, exits 1 on Class 1 violation.
#
# Supports:
#   CLASS_OVERRIDE=<table>[,<table>]  — Temporarily allow JSON-only writes for specific tables
#   PG_FIRST_BYPASS=1                 — Bypass all enforcement (emergency override)
#
# Usage:
#   scripts/check-pg-first-write.sh [--verbose] [--check-table <table>]
#
# Exit codes:
#   0 — All Class 1 writers compliant (or bypass active)
#   1 — Class 1 violation detected (JSON-only write without PG write)
#   2 — Registry file missing or unparseable
#   3 — Internal error

set -euo pipefail

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/.." && pwd)"
REGISTRY_FILE="${WORKSPACE}/state/pg-first-write-registry.json"
# Resolve jq via the same portable pattern as db.sh uses for psql (TKT-0406).
# Hard-coding /opt/homebrew/bin/jq (an OC1 path) breaks on machines where Homebrew lives
# elsewhere (e.g. /Users/.../homebrew) and was causing a false "Registry file
# is not valid JSON" verdict because a missing-binary exit was indistinguishable
# from a parse error. See CHG-0987 / TKT-1035.
JQ="${JQ:-$(command -v jq 2>/dev/null || true)}"
if [[ -z "$JQ" && -x "$(brew --prefix 2>/dev/null)/bin/jq" ]]; then
  JQ="$(brew --prefix)/bin/jq"
fi
if [[ -z "$JQ" ]]; then
  echo '{"status":"error","error":"jq binary not found in PATH or brew prefix","path":"'"$REGISTRY_FILE"'","violations":[],"exit_code":2}'
  exit 2
fi

# ── Parse args ────────────────────────────────────────────────────────────────
VERBOSE=false
CHECK_TABLE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose|-v) VERBOSE=true; shift ;;
    --check-table) CHECK_TABLE="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: $0 [--verbose] [--check-table <table>]"
      echo ""
      echo "Reads state/pg-first-write-registry.json and checks Class 1 writers."
      echo "Returns JSON verdict. Exits 1 on Class 1 violation."
      echo ""
      echo "Environment overrides:"
      echo "  CLASS_OVERRIDE=<table>[,<table>]  — Allow JSON-only writes for specific tables"
      echo "  PG_FIRST_BYPASS=1                 — Bypass all enforcement"
      exit 0
      ;;
    *) echo "ERROR: Unknown argument: $1" >&2; exit 3 ;;
  esac
done

# ── Bypass check ──────────────────────────────────────────────────────────────
if [[ "${PG_FIRST_BYPASS:-}" == "1" ]]; then
  if [[ "$VERBOSE" == "true" ]]; then
    echo '{"status":"bypassed","reason":"PG_FIRST_BYPASS=1","violations":[],"exit_code":0}'
  fi
  exit 0
fi

# ── Parse CLASS_OVERRIDE ──────────────────────────────────────────────────────
OVERRIDE_TABLES=""
if [[ -n "${CLASS_OVERRIDE:-}" ]]; then
  IFS=',' read -ra OVERRIDE_LIST <<< "$CLASS_OVERRIDE"
  for tbl in "${OVERRIDE_LIST[@]}"; do
    tbl_trimmed="$(echo "$tbl" | xargs)"
    if [[ -z "$OVERRIDE_TABLES" ]]; then
      OVERRIDE_TABLES="$tbl_trimmed"
    else
      OVERRIDE_TABLES="$OVERRIDE_TABLES $tbl_trimmed"
    fi
  done
  if [[ "$VERBOSE" == "true" ]]; then
    echo "[check-pg-first-write] CLASS_OVERRIDE active for: $OVERRIDE_TABLES" >&2
  fi
fi

# Helper: check if a table is in the override list
is_overridden() {
  local check_table="$1"
  local t
  for t in $OVERRIDE_TABLES; do
    if [[ "$t" == "$check_table" ]]; then
      return 0
    fi
  done
  return 1
}

# ── Load registry ─────────────────────────────────────────────────────────────
if [[ ! -f "$REGISTRY_FILE" ]]; then
  echo '{"status":"error","error":"Registry file not found","path":"'"$REGISTRY_FILE"'","violations":[],"exit_code":2}'
  exit 2
fi

REGISTRY=$(cat "$REGISTRY_FILE")

# Validate JSON
if ! echo "$REGISTRY" | "$JQ" empty 2>/dev/null; then
  echo '{"status":"error","error":"Registry file is not valid JSON","path":"'"$REGISTRY_FILE"'","violations":[],"exit_code":2}'
  exit 2
fi

# ── Check enforcement gate status ──────────────────────────────────────────────
GATE_STATUS=$(echo "$REGISTRY" | "$JQ" -r '.enforcement_gate.status // "unknown"')
if [[ "$GATE_STATUS" != "live" ]]; then
  if [[ "$VERBOSE" == "true" ]]; then
    echo "[check-pg-first-write] Enforcement gate status: $GATE_STATUS (not live — skipping checks)" >&2
  fi
  echo '{"status":"gate_not_live","gate_status":"'"$GATE_STATUS"'","violations":[],"exit_code":0}'
  exit 0
fi

# ── Check Class 1 writers ─────────────────────────────────────────────────────
VIOLATIONS=()
CLASS_1_COUNT=$(echo "$REGISTRY" | "$JQ" '.class_1_writers | length')

for i in $(seq 0 $((CLASS_1_COUNT - 1))); do
  WRITER=$(echo "$REGISTRY" | "$JQ" -c ".class_1_writers[$i]")
  TABLE=$(echo "$WRITER" | "$JQ" -r '.table // "unknown"')
  WRITER_SCRIPT=$(echo "$WRITER" | "$JQ" -r '.writer_script // ""')
  PG_STATUS=$(echo "$WRITER" | "$JQ" -r '.pg_first_status // "unknown"')
  JSON_RETIRED=$(echo "$WRITER" | "$JQ" -r '.json_retired // false')

  # If --check-table specified, skip non-matching tables
  if [[ -n "$CHECK_TABLE" && "$TABLE" != "$CHECK_TABLE" ]]; then
    continue
  fi

  # Skip if table is in CLASS_OVERRIDE
  if is_overridden "$TABLE"; then
    if [[ "$VERBOSE" == "true" ]]; then
      echo "[check-pg-first-write] Table $TABLE overridden via CLASS_OVERRIDE — skipping" >&2
    fi
    continue
  fi

  # Only enforce on live Class 1 writers
  if [[ "$PG_STATUS" != "live" ]]; then
    continue
  fi

  # If json_retired is true, no JSON write should happen at all — skip (not our concern)
  if [[ "$JSON_RETIRED" == "true" ]]; then
    continue
  fi

  # ── Check 1: Does the writer script exist? ──
  if [[ -n "$WRITER_SCRIPT" && ! -f "$WORKSPACE/$WRITER_SCRIPT" ]]; then
    VIOLATIONS+=("{\"table\":\"$TABLE\",\"writer_script\":\"$WRITER_SCRIPT\",\"check\":\"script_exists\",\"status\":\"violation\",\"detail\":\"Writer script not found at $WRITER_SCRIPT\"}")
    continue
  fi

  # ── Check 2: Does the writer script contain a PG write? ──
  # We check for known PG write patterns in the script
  if [[ -n "$WRITER_SCRIPT" && -f "$WORKSPACE/$WRITER_SCRIPT" ]]; then
    HAS_PG_WRITE=false
    HAS_JSON_WRITE=false

    # Check for PG write patterns
    if grep -qE '(psql|db\.sh|db-raw\.sh|db-write\.sh|INSERT INTO|UPDATE.*'$TABLE'|pg_query|PG primary write)' "$WORKSPACE/$WRITER_SCRIPT" 2>/dev/null; then
      HAS_PG_WRITE=true
    fi

    # Check for JSON file write patterns (state/ files)
    if grep -qE "(state/$TABLE\.json|json\.dump|json\.dumps|>.*$TABLE\.json)" "$WORKSPACE/$WRITER_SCRIPT" 2>/dev/null; then
      HAS_JSON_WRITE=true
    fi

    # Violation: JSON write without PG write
    if [[ "$HAS_JSON_WRITE" == "true" && "$HAS_PG_WRITE" == "false" ]]; then
      VIOLATIONS+=("{\"table\":\"$TABLE\",\"writer_script\":\"$WRITER_SCRIPT\",\"check\":\"pg_first_write\",\"status\":\"violation\",\"detail\":\"JSON-only write detected — no PG write found in $WRITER_SCRIPT\"}")
    fi
  fi
done

# ── Build verdict ─────────────────────────────────────────────────────────────
VIOLATION_COUNT=${#VIOLATIONS[@]}

if [[ $VIOLATION_COUNT -gt 0 ]]; then
  # Build JSON array of violations
  VIOLATIONS_JSON="["
  for j in $(seq 0 $((VIOLATION_COUNT - 1))); do
    if [[ $j -gt 0 ]]; then
      VIOLATIONS_JSON+=","
    fi
    VIOLATIONS_JSON+="${VIOLATIONS[$j]}"
  done
  VIOLATIONS_JSON+="]"

  echo "{\"status\":\"violation\",\"violation_count\":$VIOLATION_COUNT,\"violations\":$VIOLATIONS_JSON,\"exit_code\":1}"
  exit 1
fi

echo '{"status":"compliant","violation_count":0,"violations":[],"exit_code":0}'
exit 0
