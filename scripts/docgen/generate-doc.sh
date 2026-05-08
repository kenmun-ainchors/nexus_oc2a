#!/usr/bin/env zsh
# generate-doc.sh — AInchors Document Generation Pipeline
# Usage: generate-doc.sh --type [proposal|report|data|slides] --title "Title" --output /path/to/out.docx [--data /path/to/data.json]

SCRIPT_DIR="${0:A:h}"
TYPE=""
TITLE=""
OUTPUT=""
DATA=""

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --type)   TYPE="$2";   shift 2 ;;
    --title)  TITLE="$2";  shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --data)   DATA="$2";   shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# Validate required args
if [[ -z "$TYPE" || -z "$TITLE" || -z "$OUTPUT" ]]; then
  echo "Usage: generate-doc.sh --type [proposal|report|data|slides] --title \"Title\" --output /path/to/output [--data /path/to/data.json]"
  exit 1
fi

# Ensure output directory exists
mkdir -p "${OUTPUT:h}"

# Build python args
PY_ARGS=(--title "$TITLE" --output "$OUTPUT")
[[ -n "$DATA" ]] && PY_ARGS+=(--data "$DATA")

case "$TYPE" in
  proposal)
    /usr/bin/python3 "$SCRIPT_DIR/proposal.py" "${PY_ARGS[@]}"
    ;;
  report)
    /usr/bin/python3 "$SCRIPT_DIR/report.py" "${PY_ARGS[@]}"
    ;;
  data)
    /usr/bin/python3 "$SCRIPT_DIR/data-export.py" "${PY_ARGS[@]}"
    ;;
  slides)
    /usr/bin/python3 "$SCRIPT_DIR/slides.py" "${PY_ARGS[@]}"
    ;;
  *)
    echo "Unknown type: $TYPE. Must be one of: proposal, report, data, slides"
    exit 1
    ;;
esac

STATUS=$?
if [[ $STATUS -eq 0 ]]; then
  echo "✓ Generated: $OUTPUT"
else
  echo "✗ Failed with status $STATUS"
  exit $STATUS
fi
