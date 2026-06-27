#!/bin/bash
# scripts/model-policy-upsert.sh — PG Primary Write Pipeline for state_model_policy
# TKT-0344 / CRESTv2-P1 WS-3
#
# Upserts crest_phase_rules rules and manages policy_matrices active matrix.
# Triggers JSON export after mutation.
#
# Usage:
#   Upsert phase rules (from JSON array on stdin):
#     cat rules.json | bash scripts/model-policy-upsert.sh --upsert-rules --matrix-version v1.3.0
#
#   Activate a new policy matrix version (deactivates old first):
#     bash scripts/model-policy-upsert.sh --activate-matrix v1.3.1 --description "CREST v1.3.1"
#
#   Upsert rules then activate matrix (full pipeline):
#     cat rules.json | bash scripts/model-policy-upsert.sh --full-deploy \
#       --matrix-version v1.4.0 --description "CREST v1.4.0"
#
#   Rollback:
#     bash scripts/model-policy-upsert.sh --activate-matrix v1.3.0

set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsangiefpl/.openclaw/workspace}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_SCRIPT="$SCRIPT_DIR/model-policy-export.sh"
DB_SCRIPT="$SCRIPT_DIR/db.sh"
JQ="${JQ:-/opt/homebrew/bin/jq}"
TENANT_ID="${TENANT_ID:-ainchors}"

# --- Help ---
show_help() {
  cat <<'HELPEOF'
Usage:
  bash scripts/model-policy-upsert.sh --upsert-rules --matrix-version <ver> [--dry-run]
    Reads JSON array of rule objects from stdin, upserts to crest_phase_rules.

  bash scripts/model-policy-upsert.sh --activate-matrix <ver> --description "<desc>"
    Deactivates old active matrix, activates version <ver>. Creates row if new.

  bash scripts/model-policy-upsert.sh --full-deploy \
      --matrix-version <ver> --description "<desc>" [--dry-run]
    Reads rules from stdin, creates/activates matrix, upserts rules, exports JSON.

  bash scripts/model-policy-upsert.sh --export-only
    Runs model-policy-export.sh to refresh JSON mirror.

  bash scripts/model-policy-upsert.sh --rollback <prior-version>
    Activates prior version, removes new version's rules.

JSON input format (stdin):
  [
    {
      "role": "build",
      "phase": "Plan",
      "default_model": "ollama/deepseek-v4-flash:cloud",
      "fallback_model": "ollama/gemma4:31b-cloud",
      "override_allowed": false,
      "rationale": "Rationale string"
    },
    ...
  ]
HELPEOF
}

# --- Skill gate ---
if ! bash "$SCRIPT_DIR/skill-load.sh" pg-sprint-backlog >/dev/null 2>&1; then
  echo '{"status":"error","error":"failed to load pg-sprint-backlog skill"}' >&2
  exit 1
fi

# --- Args ---
ACTION=""
MATRIX_VERSION=""
MATRIX_DESC=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --upsert-rules)        ACTION="upsert_rules"; shift ;;
    --activate-matrix)     ACTION="activate_matrix"; MATRIX_VERSION="$2"; shift 2 ;;
    --full-deploy)         ACTION="full_deploy"; shift ;;
    --export-only)         ACTION="export_only"; shift ;;
    --rollback)            ACTION="rollback"; MATRIX_VERSION="$2"; shift 2 ;;
    --matrix-version)      MATRIX_VERSION="$2"; shift 2 ;;
    --description)         MATRIX_DESC="$2"; shift 2 ;;
    --dry-run)             DRY_RUN=true; shift ;;
    --help|-h)             show_help; exit 0 ;;
    *) echo '{"status":"error","error":"Unknown option: '"$1"'"}' >&2; show_help; exit 1 ;;
  esac
done

if [[ -z "$ACTION" ]]; then
  echo '{"status":"error","error":"No action specified"}' >&2
  show_help; exit 1
fi

# --- Helper: get active version ---
get_active_version() {
  bash "$DB_SCRIPT" -c "
    SELECT version FROM policy_matrices
    WHERE active = TRUE AND tenant_id = '$TENANT_ID'
    LIMIT 1;
  " 2>/dev/null | tail -1 | xargs
}

# --- Helper: deactivate all active matrices ---
deactivate_all_matrices() {
  bash "$DB_SCRIPT" -c "
    UPDATE policy_matrices SET active = false, updated_at = NOW()
    WHERE active = TRUE AND tenant_id = '$TENANT_ID';
  " > /dev/null 2>&1
}

# --- Helper: activate a matrix version ---
activate_matrix_version() {
  local ver="$1"
  local desc="$2"

  # First ensure the matrix row exists (upsert)
  bash "$DB_SCRIPT" -c "
    INSERT INTO policy_matrices (version, description, active, tenant_id)
    VALUES ('$ver', '${desc:-CREST matrix $ver}', false, '$TENANT_ID')
    ON CONFLICT (version) DO UPDATE SET
      description = EXCLUDED.description,
      updated_at = NOW();
  " > /dev/null 2>&1

  # Deactivate old
  deactivate_all_matrices

  # Activate new
  bash "$DB_SCRIPT" -c "
    UPDATE policy_matrices SET active = true, updated_at = NOW()
    WHERE version = '$ver' AND tenant_id = '$TENANT_ID';
  " > /dev/null 2>&1

  echo "  Activated matrix version: $ver"
}

# --- Helper: upsert rules from JSON stdin ---
upsert_rules_from_stdin() {
  local ver="$1"
  local rules_json

  # Read stdin — validate JSON array
  rules_json=$(cat)
  if ! echo "$rules_json" | "$JQ" -e '. | type == "array"' > /dev/null 2>&1; then
    echo '{"status":"error","error":"stdin must be a JSON array"}' >&2
    exit 1
  fi

  local count
  count=$(echo "$rules_json" | "$JQ" 'length')

  if [[ "$count" -eq 0 ]]; then
    echo '{"status":"error","error":"Empty rules array"}' >&2
    exit 1
  fi

  echo "  Processing $count phase rules for matrix version: $ver"

  if $DRY_RUN; then
    echo "  [DRY-RUN] Would upsert $count rules"
    echo "$rules_json" | "$JQ" -r '.[] | "  \(.role)/\(.phase) → \(.default_model) [fallback: \(.fallback_model)]"'
    return 0
  fi

  # Generate and execute upsert SQL via Python
  PY_SCRIPT=$(mktemp -t mpu_upsert.XXXXXX.py)
  trap 'rm -f "$PY_SCRIPT"' EXIT

  cat > "$PY_SCRIPT" <<'PYEOF'
import json, subprocess, sys, os

rules = json.loads(sys.stdin.read())
ver = os.environ['MATRIX_VERSION']
tenant = os.environ['TENANT_ID']

env = os.environ.copy()
env.update({"PGHOST": "/tmp", "PGPORT": "5432", "PGUSER": "ainchorsangiefpl", "PGDATABASE": "ainchors_nexus"})

errors = []
updated = 0

for rule in rules:
    role = rule.get('role', '')
    phase = rule.get('phase', '')
    default_model = rule.get('default_model', '')
    fallback_model = rule.get('fallback_model', '')
    override_allowed = rule.get('override_allowed', False)
    rationale = rule.get('rationale', '')

    if not role or not phase or not default_model or not fallback_model:
        errors.append(f"Missing required fields: role={role}, phase={phase}")
        continue

    rationale_safe = rationale.replace("'", "''")
    override_sql = 'true' if override_allowed else 'false'

    sql = f"""
    INSERT INTO crest_phase_rules
      (matrix_version, role, phase, default_model, fallback_model,
       override_allowed, rationale, tenant_id)
    VALUES
      ('{ver}', '{role}', '{phase}',
       '{default_model}', '{fallback_model}',
       {override_sql}, '{rationale_safe}', '{tenant}')
    ON CONFLICT (matrix_version, role, phase) WHERE data_class_whitelist IS NULL
    DO UPDATE SET
      default_model = EXCLUDED.default_model,
      fallback_model = EXCLUDED.fallback_model,
      override_allowed = EXCLUDED.override_allowed,
      rationale = EXCLUDED.rationale,
      updated_at = NOW();
    """

    try:
        result = subprocess.run(
            ["/opt/homebrew/bin/psql", "-t", "-A", "-c", sql],
            capture_output=True, text=True, timeout=10, env=env
        )
        if result.returncode != 0:
            err_msg = result.stderr.strip() or "unknown error"
            errors.append(f"PG error for {role}/{phase}: {err_msg}")
        else:
            updated += 1
    except subprocess.TimeoutExpired:
        errors.append(f"Timeout for {role}/{phase}")
    except Exception as e:
        errors.append(f"Exception for {role}/{phase}: {e}")

result = {"status": "ok" if not errors else "partial", "updated": updated, "errors": errors}
print(json.dumps(result))
PYEOF

  export MATRIX_VERSION TENANT_ID
  result=$(echo "$rules_json" | python3 "$PY_SCRIPT")
  py_exit=$?

  if [[ $py_exit -ne 0 ]]; then
    echo '{"status":"error","error":"Python SQL generation failed"}' >&2
    return 1
  fi

  echo "$result"
  local status
  status=$(echo "$result" | "$JQ" -r '.status')
  local up_count
  up_count=$(echo "$result" | "$JQ" -r '.updated // 0')

  if [[ "$status" == "error" ]] || [[ "$status" == "partial" ]]; then
    echo "$result" | "$JQ" -r '.errors[] // empty' >&2
    return 1
  fi

  echo "  Successfully upserted $up_count rules"
  return 0
}

# --- Helper: export JSON ---
export_json() {
  echo "  Exporting JSON mirror..."
  bash "$EXPORT_SCRIPT" 2>&1 || {
    echo '{"status":"error","error":"JSON export failed"}' >&2
    return 1
  }
  echo "  JSON export complete"
}

# ============================================================
# ACTION DISPATCH
# ============================================================

case "$ACTION" in
  upsert_rules)
    if [[ -z "$MATRIX_VERSION" ]]; then
      echo '{"status":"error","error":"--matrix-version required for upsert-rules"}' >&2
      exit 1
    fi
    echo '{"action":"upsert_rules","matrix_version":"'"$MATRIX_VERSION"'","dry_run":'"$DRY_RUN"'}'
    if upsert_rules_from_stdin "$MATRIX_VERSION"; then
      export_json
      echo '{"status":"ok","action":"upsert_rules","matrix_version":"'"$MATRIX_VERSION"'"}'
    else
      echo '{"status":"error","action":"upsert_rules"}'
      exit 1
    fi
    ;;

  activate_matrix)
    if [[ -z "$MATRIX_VERSION" ]]; then
      echo '{"status":"error","error":"--activate-matrix requires matrix version argument"}' >&2
      exit 1
    fi
    echo '{"action":"activate_matrix","version":"'"$MATRIX_VERSION"'"}'
    if $DRY_RUN; then
      echo "  [DRY-RUN] Would activate matrix: $MATRIX_VERSION"
    else
      activate_matrix_version "$MATRIX_VERSION" "$MATRIX_DESC"
      export_json
    fi
    echo '{"status":"ok","action":"activate_matrix","version":"'"$MATRIX_VERSION"'"}'
    ;;

  full_deploy)
    if [[ -z "$MATRIX_VERSION" ]]; then
      echo '{"status":"error","error":"--matrix-version required for full-deploy"}' >&2
      exit 1
    fi
    echo '{"action":"full_deploy","matrix_version":"'"$MATRIX_VERSION"'","dry_run":'"$DRY_RUN"'}'

    if $DRY_RUN; then
      echo "  [DRY-RUN] Would activate matrix: $MATRIX_VERSION"
      echo "  [DRY-RUN] Would upsert rules:"
      upsert_rules_from_stdin "$MATRIX_VERSION"
      echo "  [DRY-RUN] Would export JSON"
      echo '{"status":"ok","action":"full_deploy","dry_run":true}'
      exit 0
    fi

    # Step 1: Activate matrix
    activate_matrix_version "$MATRIX_VERSION" "$MATRIX_DESC"

    # Step 2: Upsert rules
    if ! upsert_rules_from_stdin "$MATRIX_VERSION"; then
      echo '{"status":"error","action":"full_deploy","step":"upsert_rules"}' >&2
      exit 1
    fi

    # Step 3: Export JSON
    export_json

    echo '{"status":"ok","action":"full_deploy","matrix_version":"'"$MATRIX_VERSION"'"}'
    ;;

  export_only)
    echo '{"action":"export_only"}'
    export_json
    echo '{"status":"ok","action":"export_only"}'
    ;;

  rollback)
    if [[ -z "$MATRIX_VERSION" ]]; then
      echo '{"status":"error","error":"--rollback requires prior version argument"}' >&2
      exit 1
    fi

    local current_ver
    current_ver=$(get_active_version)
    echo '{"action":"rollback","from":"'"$current_ver"'","to":"'"$MATRIX_VERSION"'"}'

    if $DRY_RUN; then
      echo "  [DRY-RUN] Would rollback from $current_ver to $MATRIX_VERSION:"
      echo "    - Activate $MATRIX_VERSION"
      echo "    - Delete rules for $current_ver from crest_phase_rules"
      echo "    - Export JSON"
      echo '{"status":"ok","action":"rollback","dry_run":true}'
      exit 0
    fi

    # Verify target version exists
    local ver_exists
    ver_exists=$(bash "$DB_SCRIPT" -c "
      SELECT 1 FROM policy_matrices WHERE version = '$MATRIX_VERSION' AND tenant_id = '$TENANT_ID' LIMIT 1;
    " 2>/dev/null | tail -1 | xargs)

    if [[ -z "$ver_exists" ]]; then
      echo '{"status":"error","error":"Rollback target version not found: '"$MATRIX_VERSION"'"}' >&2
      exit 1
    fi

    # Activate target version
    deactivate_all_matrices
    bash "$DB_SCRIPT" -c "
      UPDATE policy_matrices SET active = true, updated_at = NOW()
      WHERE version = '$MATRIX_VERSION' AND tenant_id = '$TENANT_ID';
    " > /dev/null 2>&1

    # Remove rules for the rolled-back version
    if [[ -n "$current_ver" ]]; then
      bash "$DB_SCRIPT" -c "
        DELETE FROM crest_phase_rules
        WHERE matrix_version = '$current_ver' AND tenant_id = '$TENANT_ID';
      " > /dev/null 2>&1
    fi

    export_json

    echo '{"status":"ok","action":"rollback","from":"'"$current_ver"'","to":"'"$MATRIX_VERSION"'"}'
    ;;

  *)
    echo '{"status":"error","error":"Unknown action: '"$ACTION"'"}' >&2
    exit 1
    ;;
esac
