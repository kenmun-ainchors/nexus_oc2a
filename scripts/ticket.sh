#!/bin/zsh
# ticket.sh — DEPRECATED (TKT-0535)
# This script is no longer supported. It previously created malformed tickets
# and did not write to PostgreSQL. Use the canonical pg-sprint-backlog skill
# and scripts/db-ticket.sh instead.
#
# Old functionality preserved at scripts/ticket.sh.deprecated-TKT-0535
# for reference/rollback only.

set -euo pipefail

echo "ERROR: scripts/ticket.sh is deprecated (TKT-0535)." >&2
echo "Use the canonical ticket operations instead:" >&2
echo "  1. Load the pg-sprint-backlog skill:" >&2
echo "     bash scripts/skill-load.sh pg-sprint-backlog" >&2
echo "  2. Use db-ticket.sh:" >&2
echo "     bash scripts/db-ticket.sh create" >&2
echo "     bash scripts/db-ticket.sh read TKT-NNNN" >&2
echo "     bash scripts/db-ticket.sh list --open" >&2
exit 7
