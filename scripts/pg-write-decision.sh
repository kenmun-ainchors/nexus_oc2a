#!/bin/bash
# pg-write-decision.sh — Thin wrapper around pg-write-event.sh for decision events
# Emits event_type='decision' with structured decision payload.
# All event writes are best-effort: failures are logged but always exit 0.
#
# Usage:
#   pg-write-decision.sh \
#     --actor "yoda" \
#     --entity-id "<stable UUID>" \
#     --decision-kind "dispatch|phase_transition|routing|session_model" \
#     --payload '{"inputs":{...},"outputs":{...},"rationale":"..."}'
#
# Requires: scripts/pg-write-event.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PG_WRITE_EVENT="$SCRIPT_DIR/pg-write-event.sh"

# Parse args
ACTOR=""
ENTITY_ID=""
DECISION_KIND=""
PAYLOAD="{}"
ENTITY_TYPE="decision"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --actor)         ACTOR="$2"; shift 2 ;;
    --entity-id)     ENTITY_ID="$2"; shift 2 ;;
    --decision-kind) DECISION_KIND="$2"; shift 2 ;;
    --payload)       PAYLOAD="$2"; shift 2 ;;
    --entity-type)   ENTITY_TYPE="$2"; shift 2 ;;
    *) echo "pg-write-decision: Unknown arg: $1" >&2; exit 0 ;;
  esac
done

if [[ -z "$ACTOR" || -z "$ENTITY_ID" || -z "$DECISION_KIND" ]]; then
  echo "pg-write-decision: Missing required args: --actor, --entity-id, --decision-kind" >&2
  exit 0
fi

# Build enriched payload: merge user payload with decision_kind metadata
# Pipe user payload through python to add decision_kind field
FULL_PAYLOAD=$(printf '%s' "$PAYLOAD" | python3 -c "
import json, sys
raw = sys.stdin.read()
try:
    user = json.loads(raw) if raw.strip() else {}
except Exception:
    user = {}
user['decision_kind'] = '$DECISION_KIND'
print(json.dumps(user))
" 2>/dev/null || echo "{\"decision_kind\":\"$DECISION_KIND\"}")

# Delegate to pg-write-event.sh — best-effort, always exit 0
bash "$PG_WRITE_EVENT" \
  --actor "$ACTOR" \
  --event-type "decision" \
  --entity-type "$ENTITY_TYPE" \
  --entity-id "$ENTITY_ID" \
  --payload "$FULL_PAYLOAD" \
  2>/dev/null || true

exit 0
