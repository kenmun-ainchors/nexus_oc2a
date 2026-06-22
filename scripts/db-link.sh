#!/bin/bash
# db-link.sh — Shared entity_links helper library
# Source this from other scripts: source "$(dirname "$0")/db-link.sh"
#
# Functions:
#   insert_entity_links(from_type, from_id, link_type, source, ...to_pairs)
#     Inserts edges into entity_links. to_pairs are "to_type:to_id" strings.
#     Emits a single agent_events row per batch.
#
#   parse_linked_line(line_text)
#     Extracts canonical IDs from a "Linked:" line, prints "type:id" pairs.
#
#   resolve_from_entity(file_path, line_number)
#     Scans backward from line_number for nearest preceding heading with a
#     canonical ID. Returns "type:id" of first ID found, or empty string.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
DB_RAW="$SCRIPT_DIR/db-raw.sh"
PG_WRITE_EVENT="$SCRIPT_DIR/pg-write-event.sh"

# ──────────────────────────────────────────────
# insert_entity_links
# ──────────────────────────────────────────────
# Usage: insert_entity_links <from_type> <from_id> <link_type> <source> <to_pair1> [to_pair2 ...]
#
# Each to_pair is "to_type:to_id" (e.g. "chg:CHG-0719" "ticket:TKT-0720")
# Inserts via batch SQL with ON CONFLICT DO NOTHING.
# Emits a single agent_events row with event_type='linked'.
#
# Returns: number of edges inserted (0 if none or error)
insert_entity_links() {
  local from_type="$1"
  local from_id="$2"
  local link_type="$3"
  local source="$4"
  shift 4

  local to_pairs=("$@")
  if [[ ${#to_pairs[@]} -eq 0 ]]; then
    echo 0
    return 0
  fi

  # Build batch INSERT SQL
  local values=()
  local inserted_ids=()
  local pair=""
  for pair in "${to_pairs[@]}"; do
    # Split on first colon
    local to_type="${pair%%:*}"
    local to_id="${pair#*:}"
    # Skip if either part is empty
    if [[ -z "$to_type" || -z "$to_id" ]]; then
      continue
    fi
    # Escape single quotes
    to_type="${to_type//\'/\'\'}"
    to_id="${to_id//\'/\'\'}"
    values+=("(format_link_id(nextval('entity_links_link_id_seq')), '${from_type//\'/\'\'}', '${from_id//\'/\'\'}', '${to_type}', '${to_id}', '${link_type//\'/\'\'}', '${source//\'/\'\'}')")
    inserted_ids+=("${to_type}:${to_id}")
  done

  if [[ ${#values[@]} -eq 0 ]]; then
    echo 0
    return 0
  fi

  local sql=""
  printf -v sql "INSERT INTO entity_links (link_id, from_type, from_id, to_type, to_id, link_type, source)\nVALUES\n  %s\nON CONFLICT (from_type, from_id, to_type, to_id, link_type, source) DO NOTHING;" "$(IFS=$',\n'; echo "${values[*]}")"

  # Execute — best-effort
  local result=""
  result=$(bash "$DB_RAW" -c "$sql" 2>/dev/null) || true

  # Count inserted rows from INSERT result (e.g. "INSERT 0 5")
  local count=0
  if [[ "$result" =~ INSERT\ 0\ ([0-9]+) ]]; then
    count="${BASH_REMATCH[1]:-${match[1]:-0}}"
  fi

  # Emit agent_events row
  if [[ "$count" -gt 0 ]]; then
    local payload_json=""
    payload_json=$(printf '{"edges_inserted":%d,"link_type":"%s","source":"%s","targets":[%s]}' \
      "$count" \
      "$link_type" \
      "$source" \
      "$(printf '"%s",' "${inserted_ids[@]}" | sed 's/,$//')" 2>/dev/null) || payload_json='{}'

    bash "$PG_WRITE_EVENT" \
      --actor "system" \
      --event-type "linked" \
      --entity-type "$from_type" \
      --entity-id "$from_id" \
      --payload "$payload_json" \
      --tenant-id "ainchors" >/dev/null 2>&1 || true
  fi

  echo "$count"
}

# ──────────────────────────────────────────────
# _prefix_to_type (internal helper)
# ──────────────────────────────────────────────
_prefix_to_type() {
  local prefix="$1"
  case "$prefix" in
    TKT) echo "ticket" ;;
    CHG) echo "chg" ;;
    L)   echo "lesson" ;;
    WO*) echo "wo" ;;
    *)   echo "$prefix" ;;
  esac
}

# ──────────────────────────────────────────────
# parse_linked_line
# ──────────────────────────────────────────────
# Usage: parse_linked_line "**Linked:** TKT-0720, CHG-0604–CHG-0608"
#
# Strips markdown formatting, extracts canonical IDs, expands ranges.
# Prints one "type:id" per line to stdout.
# Returns 0 if any IDs found, 1 if none.
parse_linked_line() {
  local line="$1"

  # Strip leading whitespace, asterisks, "Linked:" label (case-insensitive)
  # Handles: **Linked:**, - **Linked:**, Linked:, **Linked:**
  line=$(echo "$line" | sed -E 's/^[[:space:]]*[-*]*[[:space:]]*\*{0,2}[Ll]inked:\*{0,2}[[:space:]]*//')

  # Strip markdown bold, inline links, backticks
  line=$(echo "$line" | sed 's/\*\*//g')
  line=$(echo "$line" | sed -E 's/\[([^\]]*)\]\([^)]*\)/\1/g')
  line=$(echo "$line" | sed 's/`//g')

  # Normalize en-dash and em-dash to regular hyphen for range detection
  line=$(echo "$line" | sed 's/–/-/g; s/—/-/g')

  # Handle "none" or empty
  if [[ -z "$line" || "$line" =~ ^[[:space:]]*none[[:space:]]*$ ]]; then
    return 1
  fi

  # Strategy: split on commas and spaces, process each token
  local found_any=0
  local raw_line="$line"

  # First, replace commas with newlines, then process each line
  # But we need to handle multi-word tokens like "Sprint 9"
  # Strategy: split on commas first, then for each comma-token, try to match
  # multi-word patterns before falling back to space-split
  local comma_token=""
  while IFS= read -r comma_token; do
    # Trim whitespace
    comma_token=$(echo "$comma_token" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
    [[ -z "$comma_token" ]] && continue

    # Strip parenthetical notes
    comma_token=$(echo "$comma_token" | sed -E 's/[[:space:]]*\([^)]*\)[[:space:]]*$//')
    comma_token=$(echo "$comma_token" | sed -E 's/\([^)]*\)//g')
    comma_token=$(echo "$comma_token" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
    [[ -z "$comma_token" ]] && continue

    # Try to match multi-word patterns first
    local multi_matched=0

    # Sprint N (e.g. "Sprint 9")
    local sprint_match=""
    sprint_match=""
    sprint_match=$(echo "$comma_token" | grep -oE '^Sprint[[:space:]]+[0-9]+$' | head -1)
    if [[ -n "$sprint_match" ]]; then
      local sprint_num=""
      sprint_num=$(echo "$sprint_match" | grep -oE '[0-9]+$')
      echo "sprint:${sprint_num}"
      found_any=1
      multi_matched=1
    fi

    # Sprint N planning (prose — skip)
    if [[ "$comma_token" =~ ^Sprint[[:space:]]+[0-9]+[[:space:]] ]]; then
      multi_matched=1
    fi

    if [[ "$multi_matched" -eq 1 ]]; then
      continue
    fi

    # Now split on spaces for individual tokens
    local token=""
    while IFS= read -r token; do
      # Trim whitespace
      token=$(echo "$token" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
      [[ -z "$token" ]] && continue

      # Check for range: CHG-0604-CHG-0608 (hyphen, already normalized)
      local range_full_match=""
      range_full_match=""
      range_full_match=$(echo "$token" | grep -oE '^(TKT|CHG|L|WO-[A-Z]+)-([0-9]+)-(TKT|CHG|L|WO-[A-Z]+)-([0-9]+)$' | head -1)
      if [[ -n "$range_full_match" ]]; then
        local p1="" s1="" p2="" e1=""
        p1=$(echo "$range_full_match" | sed -E 's/^((TKT|CHG|L|WO-[A-Z]+)-[0-9]+)-.*/\1/' | sed -E 's/-[0-9]+$//')
        s1=$(echo "$range_full_match" | sed -E 's/^[A-Z]+-([0-9]+)-.*/\1/')
        p2=$(echo "$range_full_match" | sed -E 's/.*-((TKT|CHG|L|WO-[A-Z]+)-[0-9]+)$/\1/' | sed -E 's/-[0-9]+$//')
        e1=$(echo "$range_full_match" | sed -E 's/.*-([0-9]+)$/\1/')
        if [[ "$p1" == "$p2" ]]; then
          local start=$((10#$s1))
          local end=$((10#$e1))
          local cnt=$((end - start + 1))
          [[ $cnt -gt 20 ]] && { cnt=20; end=$((start + 19)); }
          local type_name=""
          type_name=$(_prefix_to_type "$p1")
          for ((i = start; i <= end; i++)); do
            printf -v padded "%04d" "$i"
            echo "${type_name}:${p1}-${padded}"
            found_any=1
          done
        fi
        continue
      fi

      # Check for hyphen range: CHG-0660-0667
      local range_hyphen_match=""
      range_hyphen_match=""
      range_hyphen_match=$(echo "$token" | grep -oE '^(TKT|CHG|L|WO-[A-Z]+)-([0-9]+)-([0-9]+)$' | head -1)
      if [[ -n "$range_hyphen_match" ]]; then
        local p="" s="" e=""
        p=$(echo "$range_hyphen_match" | sed -E 's/^((TKT|CHG|L|WO-[A-Z]+))-.*/\1/')
        s=$(echo "$range_hyphen_match" | sed -E 's/^[A-Z]+-([0-9]+)-[0-9]+$/\1/')
        e=$(echo "$range_hyphen_match" | sed -E 's/^[A-Z]+-[0-9]+-([0-9]+)$/\1/')
        local start=$((10#$s))
        local end=$((10#$e))
        local cnt=$((end - start + 1))
        [[ $cnt -gt 20 ]] && { cnt=20; end=$((start + 19)); }
        local type_name=""
        type_name=$(_prefix_to_type "$p")
        for ((i = start; i <= end; i++)); do
          printf -v padded "%04d" "$i"
          echo "${type_name}:${p}-${padded}"
          found_any=1
        done
        continue
      fi

      # Individual IDs
      local matched=""
      matched=0

      # TKT-NNNN (including TKT-REC5 etc.)
      local tkt_match=""
      tkt_match=""
      tkt_match=$(echo "$token" | grep -oE '^TKT-[A-Z0-9]+$' | head -1)
      if [[ -n "$tkt_match" ]]; then
        echo "ticket:${tkt_match}"
        matched=1
      fi

      # CHG-NNNN
      if [[ "$matched" -eq 0 ]]; then
        local chg_match=""
        chg_match=$(echo "$token" | grep -oE '^CHG-[0-9]+$' | head -1)
        if [[ -n "$chg_match" ]]; then
          echo "chg:${chg_match}"
          matched=1
        fi
      fi

      # L-NNN
      if [[ "$matched" -eq 0 ]]; then
        local l_match=""
        l_match=$(echo "$token" | grep -oE '^L-[0-9]+$' | head -1)
        if [[ -n "$l_match" ]]; then
          echo "lesson:${l_match}"
          matched=1
        fi
      fi

      # WO-XXX-NNN (e.g. WO-002, WO-ABC-123)
      if [[ "$matched" -eq 0 ]]; then
        local wo_match=""
        wo_match=$(echo "$token" | grep -oE '^WO-[A-Z0-9]+(-[0-9]+)?$' | head -1)
        if [[ -n "$wo_match" ]]; then
          echo "wo:${wo_match}"
          matched=1
        fi
      fi

      # INC-YYYYMMDD-NNN
      if [[ "$matched" -eq 0 ]]; then
        local inc_match=""
        inc_match=$(echo "$token" | grep -oE '^INC-[0-9]{8}-[0-9]+$' | head -1)
        if [[ -n "$inc_match" ]]; then
          echo "incident:${inc_match}"
          matched=1
        fi
      fi

      # CR-NNN
      if [[ "$matched" -eq 0 ]]; then
        local cr_match=""
        cr_match=$(echo "$token" | grep -oE '^CR-[0-9]+$' | head -1)
        if [[ -n "$cr_match" ]]; then
          echo "cr:${cr_match}"
          matched=1
        fi
      fi

      # File paths (anything with / or .md, .json, .sh, etc.)
      if [[ "$matched" -eq 0 && "$token" =~ \. ]]; then
        echo "file:${token}"
        matched=1
      fi

      if [[ "$matched" -eq 1 ]]; then
        found_any=1
      fi
    done < <(echo "$comma_token" | tr ' ' '\n')
  done < <(echo "$raw_line" | tr ',' '\n')

  [[ "$found_any" -eq 1 ]] && return 0 || return 1
}

# ──────────────────────────────────────────────
# resolve_from_entity
# ──────────────────────────────────────────────
# Usage: resolve_from_entity <file_path> <line_number>
#
# Scans backward from line_number to find the nearest preceding markdown
# heading (## or #) that contains a canonical ID (TKT-NNNN, CHG-NNNN, L-NNN).
# Returns "type:id" of the first ID found, or empty string if none.
resolve_from_entity() {
  local file_path="$1"
  local line_number="$2"

  if [[ ! -f "$file_path" || -z "$line_number" ]]; then
    echo ""
    return 1
  fi

  # Read lines from top to line_number-1, then reverse and scan for headings
  local heading_line=""
  heading_line=$(head -n "$((line_number - 1))" "$file_path" 2>/dev/null | \
    grep -n '^##\? ' | \
    tail -1 | \
    sed 's/^[0-9]*://')

  if [[ -z "$heading_line" ]]; then
    echo ""
    return 1
  fi

  # Extract first canonical ID from the heading
  # Match TKT-NNNN, CHG-NNNN, L-NNN, WO-XXX-NNN
  local id=""
  id=$(echo "$heading_line" | grep -oE '(TKT-[A-Z0-9]+|CHG-[0-9]+|L-[0-9]+|WO-[A-Z]+-[0-9]+)' | head -1)

  if [[ -z "$id" ]]; then
    echo ""
    return 1
  fi

  # Map to type
  local type=""
  if [[ "$id" =~ ^TKT- ]]; then
    type="ticket"
  elif [[ "$id" =~ ^CHG- ]]; then
    type="chg"
  elif [[ "$id" =~ ^L- ]]; then
    type="lesson"
  elif [[ "$id" =~ ^WO- ]]; then
    type="wo"
  else
    echo ""
    return 1
  fi

  echo "${type}:${id}"
  return 0
}

# If sourced, just define functions. If executed directly, show help.
# Detect sourcing: works in both bash (BASH_SOURCE) and zsh (ZSH_EVAL_CONTEXT)
_is_sourced() {
  if [[ -n "${BASH_SOURCE:-}" ]]; then
    # bash: BASH_SOURCE[0] != $0 when sourced
    [[ "${BASH_SOURCE[0]}" != "${0}" ]]
  else
    # zsh: ZSH_EVAL_CONTEXT != toplevel when sourced
    [[ "${ZSH_EVAL_CONTEXT:-}" != toplevel ]]
  fi
}

if _is_sourced; then
  :  # being sourced, do nothing
else
  # Executed directly — show help
  echo "db-link.sh — Shared entity_links helper library"
  echo ""
  echo "Source this file in your scripts:"
  echo "  source \"\$(dirname \"\$0\")/db-link.sh\""
  echo ""
  echo "Functions:"
  echo "  insert_entity_links(from_type, from_id, link_type, source, ...to_pairs)"
  echo "  parse_linked_line(line_text)"
  echo "  resolve_from_entity(file_path, line_number)"
  echo ""
  echo "Example:"
  echo "  source db-link.sh"
  echo '  insert_entity_links "ticket" "TKT-0720" "relates-to" "migrated-from-md" "chg:CHG-0719" "ticket:TKT-0721"'
  echo '  parse_linked_line "**Linked:** TKT-0720, CHG-0604–CHG-0608"'
  echo '  resolve_from_entity "memory/CHANGELOG.md" 10'
fi
