#!/bin/bash
# sandbox-guard.sh — Pre-flight check: refuse to run if in sandbox context
# TKT-0332-A2: Prevents sandbox scripts/steps from accidentally touching
# production config or resources. Source this at the top of any script
# that writes to production config, runs openclaw doctor --fix, or
# regenerates gateway tokens.
#
# Usage:
#   source "$WORKSPACE/scripts/sandbox-guard.sh"
#   ... (script continues only if OPENCLAW_SANDBOX != 1)
#
# When OPENCLAW_SANDBOX=1, this script exits with code 70 (EX_SOFTWARE)
# and a clear message to stderr.

set -euo pipefail

if [[ "${OPENCLAW_SANDBOX:-}" == "1" ]]; then
  echo "ERROR [sandbox-guard]: OPENCLAW_SANDBOX=1 detected. This operation is not allowed in sandbox context." >&2
  echo "  Script: ${0}" >&2
  echo "  Reason: Sandbox processes must not touch production config, regenerate gateway tokens, or write to prod DB." >&2
  echo "  Ref: TKT-0332, INC-20260608-001" >&2
  exit 70  # EX_SOFTWARE
fi

# Silent PASS when not in sandbox — allow script to continue
