#!/bin/bash

# Anchored to workspace root
WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"

# Default values
AUTHOR="AInchors"
TITLE="Untitled Document"
SUBTITLE="Placeholder Subtitle"
OUTPUT=""
TYPE=""
TEMPLATE=""
DATA=""

# Usage function
usage() {
    echo "Usage: $0 --type <docx|xlsx|pptx|pdf> --title \"Title\" --output /path/to/output"
    echo "Options:"
    echo "  --type     Document type: docx, xlsx, pptx, pdf"
    echo "  --title    Title of the document"
    echo "  --subtitle Subtitle of the document"
    echo "  --author   Author name (default: AInchors)"
    echo "  --output   Output file path"
    echo "  --template Path to branded template (optional)"
    echo "  --data     JSON input for data-driven docs (optional)"
    exit 1
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --type) TYPE="$2"; shift ;;
        --title) TITLE="$2"; shift ;;
        --subtitle) SUBTITLE="$2"; shift ;;
        --author) AUTHOR="$2"; shift ;;
        --output) OUTPUT="$2"; shift ;;
        --template) TEMPLATE="$2"; shift ;;
        --data) DATA="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Validation
if [[ -z "$TYPE" ]] || [[ -z "$OUTPUT" ]]; then
    echo "Error: --type and --output are required."
    usage
fi

# Route to specific generators (use forge venv for dependencies)
PYTHON="$WORKSPACE/forge/venv/bin/python3"
case $TYPE in
    docx)
        "$PYTHON" "$WORKSPACE/scripts/gen_docx.py" "$OUTPUT" "$TITLE" "$SUBTITLE" "$AUTHOR"
        ;;
    xlsx)
        "$PYTHON" "$WORKSPACE/scripts/gen_xlsx.py" "$OUTPUT" "$TITLE"
        ;;
    pptx)
        "$PYTHON" "$WORKSPACE/scripts/gen_pptx.py" "$OUTPUT" "$TITLE" "$SUBTITLE"
        ;;
    pdf)
        "$PYTHON" "$WORKSPACE/scripts/gen_pdf.py" "$OUTPUT" "$TITLE" "$SUBTITLE" "$AUTHOR"
        ;;
    *)
        echo "Error: Unsupported type $TYPE. Use docx, xlsx, pptx, or pdf."
        exit 1
        ;;
esac

if [ $? -eq 0 ]; then
    echo "Successfully generated $TYPE document at: $OUTPUT"
else
    echo "Error: Failed to generate $TYPE document."
    exit 1
fi
