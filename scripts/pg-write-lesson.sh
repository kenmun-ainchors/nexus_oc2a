#!/bin/bash
# pg-write-lesson.sh — Insert/update a single lesson row in state_lessons.
# Best-effort: failures are logged to stderr, exits 0 always.
#
# Usage:
#   pg-write-lesson.sh --lesson-id L-NNN \
#     [--title "Title"] [--body "..."] [--source "TKT-NNN"] \
#     [--category "Category"] [--status active|stub] \
#     [--fix "..."] [--evidence "..."] [--prevention "..."] \
#     [--linked "TKT-...,CHG-..."]
#
# Idempotent: upserts by lesson_id (ON CONFLICT DO UPDATE).
# Can be called from journal-append.sh or changelog-append.sh as a hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_RAW="$SCRIPT_DIR/db-raw.sh"

LESSON_ID=""; TITLE=""; BODY=""; SOURCE=""; CATEGORY=""; STATUS="active"
FIX=""; EVIDENCE=""; PREVENTION=""; LINKED=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lesson-id)   LESSON_ID="$2";  shift 2 ;;
    --title)       TITLE="$2";      shift 2 ;;
    --body)        BODY="$2";       shift 2 ;;
    --source)      SOURCE="$2";     shift 2 ;;
    --category)    CATEGORY="$2";   shift 2 ;;
    --status)      STATUS="$2";     shift 2 ;;
    --fix)         FIX="$2";        shift 2 ;;
    --evidence)    EVIDENCE="$2";   shift 2 ;;
    --prevention)  PREVENTION="$2"; shift 2 ;;
    --linked)      LINKED="$2";     shift 2 ;;
    *) echo "pg-write-lesson: Unknown arg: $1" >&2; exit 0 ;;
  esac
done

if [[ -z "$LESSON_ID" ]]; then
  echo "pg-write-lesson: --lesson-id is required" >&2
  exit 0
fi

# Escape single quotes
sq() { echo "$1" | sed "s/'/''/g"; }

LESSON_ID_S=$(sq "$LESSON_ID")
TITLE_S=$(sq "$TITLE")
BODY_S=$(sq "$BODY")
SOURCE_S=$(sq "$SOURCE")
CATEGORY_S=$(sq "$CATEGORY")
FIX_S=$(sq "$FIX")
EVIDENCE_S=$(sq "$EVIDENCE")
PREVENTION_S=$(sq "$PREVENTION")

SQL="INSERT INTO state_lessons (lesson_id, title, body, source, category, status, fix, evidence, prevention)
VALUES ('$LESSON_ID_S', '$TITLE_S', '$BODY_S', '$SOURCE_S', '$CATEGORY_S', '$STATUS', '$FIX_S', '$EVIDENCE_S', '$PREVENTION_S')
ON CONFLICT (lesson_id) DO UPDATE SET
  title = EXCLUDED.title,
  body = EXCLUDED.body,
  source = EXCLUDED.source,
  category = EXCLUDED.category,
  status = EXCLUDED.status,
  fix = EXCLUDED.fix,
  evidence = EXCLUDED.evidence,
  prevention = EXCLUDED.prevention,
  ts = now();"

bash "$DB_RAW" -c "$SQL" >/dev/null 2>&1 || echo "pg-write-lesson: WARNING PG insert failed for $LESSON_ID" >&2

# Insert entity_links for --linked value (best-effort)
if [[ -n "$LINKED" ]]; then
  source "$SCRIPT_DIR/db-link.sh"
  linked_pairs=$(parse_linked_line "$LINKED" 2>/dev/null) || true
  if [[ -n "$linked_pairs" ]]; then
    to_pairs=()
    while IFS= read -r pair; do
      [[ -n "$pair" ]] && to_pairs+=("$pair")
    done <<< "$linked_pairs"
    if [[ ${#to_pairs[@]} -gt 0 ]]; then
      insert_entity_links "lesson" "$LESSON_ID" "relates-to" "live-write:pg-write-lesson" "${to_pairs[@]}" >/dev/null 2>&1 || true
    fi
  fi
fi

exit 0
