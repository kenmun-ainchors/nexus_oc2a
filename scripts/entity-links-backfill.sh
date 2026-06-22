#!/bin/bash
# entity-links-backfill.sh — Backfill entity_links from markdown "Linked:" mentions
#
# Usage:
#   entity-links-backfill.sh --dry-run [--source-dir DIR]
#   entity-links-backfill.sh --commit [--source-dir DIR]
#
# Options:
#   --dry-run       Print what would be inserted without writing to DB
#   --commit        Actually insert edges into entity_links
#   --source-dir DIR  Root directory to scan (default: workspace root)
#   --help          Show this help

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/db-link.sh"

# Defaults
DRY_RUN=false
COMMIT=false
SOURCE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"  # workspace root
SKIPPED_LOG="$SOURCE_DIR/.openclaw/tmp/entity-links-backfill-skipped.log"

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)    DRY_RUN=true; shift ;;
    --commit)     COMMIT=true; shift ;;
    --source-dir) SOURCE_DIR="$2"; shift 2 ;;
    --help|-h)
      echo "entity-links-backfill.sh — Backfill entity_links from markdown Linked: mentions"
      echo ""
      echo "Usage:"
      echo "  $0 --dry-run [--source-dir DIR]"
      echo "  $0 --commit [--source-dir DIR]"
      echo ""
      echo "Options:"
      echo "  --dry-run       Print what would be inserted without writing to DB"
      echo "  --commit        Actually insert edges into entity_links"
      echo "  --source-dir DIR  Root directory to scan (default: workspace root)"
      echo "  --help          Show this help"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if ! $DRY_RUN && ! $COMMIT; then
  echo "ERROR: Must specify --dry-run or --commit" >&2
  exit 1
fi

# Initialize counters
FILES_SCANNED=0
LINKED_LINES_FOUND=0
EDGES_WRITTEN=0
EDGES_SKIPPED=0
FILE_EDGES=0  # Track file-type edges separately

# Clear skipped log
: > "$SKIPPED_LOG"

echo "=== entity-links-backfill.sh ==="
echo "Mode: $($DRY_RUN && echo 'DRY-RUN' || echo 'COMMIT')"
echo "Source dir: $SOURCE_DIR"
echo ""

# Scan files
# Pattern: memory/CHANGELOG.md, memory/*.md, docs/*.md
FILES=()
for pattern in "memory/CHANGELOG.md" "memory/*.md" "docs/*.md"; do
  while IFS= read -r -d '' f; do
    FILES+=("$f")
  done < <(find "$SOURCE_DIR" -path "$SOURCE_DIR/$pattern" -type f -print0 2>/dev/null)
done

# Remove duplicates
IFS=$'\n' FILES=($(printf "%s\n" "${FILES[@]}" | sort -u))
unset IFS

echo "Files to scan: ${#FILES[@]}"
echo ""

for file_path in "${FILES[@]}"; do
  # Get relative path for source field
  rel_path="${file_path#$SOURCE_DIR/}"

  # Find all Linked: lines in this file
  # Pattern: lines starting with optional whitespace, optional - or *, optional **, "Linked:", optional **
  # We use grep -n to get line numbers
  linked_lines=
  linked_lines=$(grep -n -E '^\s*[-*]*\s*\*{0,2}[Ll]inked:\*{0,2}' "$file_path" 2>/dev/null) || continue

  FILES_SCANNED=$((FILES_SCANNED + 1))

  while IFS= read -r match_line; do
    line_num="${match_line%%:*}"
    line_text="${match_line#*:}"

    LINKED_LINES_FOUND=$((LINKED_LINES_FOUND + 1))

    # Resolve from-entity
    from_entity=$(resolve_from_entity "$file_path" "$line_num")

    if [[ -z "$from_entity" ]]; then
      echo "  SKIP (no from-entity): $rel_path:$line_num" >> "$SKIPPED_LOG"
      EDGES_SKIPPED=$((EDGES_SKIPPED + 1))
      continue
    fi

    # Parse linked line
    to_pairs=()
    while IFS= read -r pair; do
      to_pairs+=("$pair")
    done < <(parse_linked_line "$line_text")

    if [[ ${#to_pairs[@]} -eq 0 ]]; then
      echo "  SKIP (no to-pairs): $rel_path:$line_num" >> "$SKIPPED_LOG"
      EDGES_SKIPPED=$((EDGES_SKIPPED + 1))
      continue
    fi

    # Separate file-type edges from entity edges
    entity_pairs=()
    file_pairs=()
    for pair in "${to_pairs[@]}"; do
      if [[ "$pair" == file:* ]]; then
        file_pairs+=("$pair")
      else
        entity_pairs+=("$pair")
      fi
    done

    # Build source string
    source="migrated-from-md:${rel_path}"

    if $DRY_RUN; then
      echo "  [$rel_path:$line_num] $from_entity ->"
      for pair in "${entity_pairs[@]}" "${file_pairs[@]}"; do
        echo "    $pair"
      done
    else
      # Insert entity edges
      if [[ ${#entity_pairs[@]} -gt 0 ]]; then
        count=$(insert_entity_links "${from_entity%%:*}" "${from_entity#*:}" "relates-to" "$source" "${entity_pairs[@]}")
        EDGES_WRITTEN=$((EDGES_WRITTEN + count))
      fi

      # Insert file edges (tracked separately)
      if [[ ${#file_pairs[@]} -gt 0 ]]; then
        count=$(insert_entity_links "${from_entity%%:*}" "${from_entity#*:}" "relates-to" "$source" "${file_pairs[@]}")
        FILE_EDGES=$((FILE_EDGES + count))
      fi
    fi
  done < <(echo "$linked_lines")
done

echo ""
echo "=== Summary ==="
echo "Files scanned:     $FILES_SCANNED"
echo "Linked: lines:    $LINKED_LINES_FOUND"
echo "Edges written:    $EDGES_WRITTEN (entity edges)"
echo "File edges:       $FILE_EDGES (file-type edges, excluded from completeness)"
echo "Edges skipped:    $EDGES_SKIPPED"
echo "Skipped log:      $SKIPPED_LOG"

if $DRY_RUN; then
  echo ""
  echo "This was a dry run. Run with --commit to write to database."
fi
