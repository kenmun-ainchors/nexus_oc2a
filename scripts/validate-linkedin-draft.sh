#!/usr/bin/env zsh
# validate-linkedin-draft.sh
# Standalone validator for LinkedIn draft format.
# Returns exit 0 if valid, exit 1 if invalid. Prints errors/warnings to stderr.
#
# Contract (see docs/LinkedIn-Draft-Format-Contract.md):
#   1. Mandatory `## Draft` heading.
#   2. Body text (between ## Draft and --- separator) > 100 characters.
#   3. `---` separator after body.
#   4. Hashtag line starting with `#` (and not a markdown heading).
#   5. `## Image Prompt` heading present.
#   6. No em-dashes (—) in body (existing rule from CHG-0421).
#
# Legacy `---`-only drafts (Format A) PASS with a warning.
# CHG-0832 / SSOT Phase 1.
set -euo pipefail

DRAFT_FILE=""

usage() {
  cat <<EOF
Usage: zsh scripts/validate-linkedin-draft.sh <path/to/draft.md>

Validates a LinkedIn draft markdown file against the agreed format contract.
EOF
}

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 1
fi

DRAFT_FILE="$1"

if [[ ! -f "$DRAFT_FILE" ]]; then
  echo "❌ File not found: $DRAFT_FILE" >&2
  exit 1
fi

python3 - "$DRAFT_FILE" <<'PYEOF'
import sys, re

path = sys.argv[1]
text = open(path, encoding='utf-8').read()
lines = text.split('\n')

errors = []
warnings = []

# 1. Mandatory ## Draft heading
draft_headings = [i for i, line in enumerate(lines) if re.match(r'^##\s+Draft\s*$', line, re.I)]
if not draft_headings:
    errors.append("Missing mandatory '## Draft' heading.")
    draft_idx = None
else:
    draft_idx = draft_headings[0]

# 2. Body text > 100 chars, 3. --- separator, 4. hashtag line, 5. ## Image Prompt
image_prompt_headings = [i for i, line in enumerate(lines) if re.match(r'^##\s+Image Prompt\s*$', line, re.I)]
if not image_prompt_headings:
    errors.append("Missing mandatory '## Image Prompt' heading.")
else:
    # If multiple, use the first
    pass

hashtag_lines = [line.strip() for line in lines if line.startswith('#') and not line.startswith('##') and line.strip() != '#']
if not hashtag_lines:
    errors.append("Missing hashtag line starting with '#'.")

separator_indices = [i for i, line in enumerate(lines) if line.strip() == '---']
if not separator_indices:
    errors.append("Missing '---' separator.")

if draft_idx is not None:
    # Collect body lines: from after ## Draft until the first --- that precedes hashtags or ## Image Prompt
    body_lines = []
    collecting = False
    separator_before_hashtags = None
    for i in range(draft_idx + 1, len(lines)):
        s = lines[i].strip()
        if not collecting and not s:
            continue
        if s == '---':
            # Peek ahead for hashtag or ## Image Prompt
            peek = None
            for j in range(i + 1, len(lines)):
                ps = lines[j].strip()
                if ps:
                    peek = ps
                    break
            if peek and (peek.startswith('#') and not peek.startswith('## ')):
                separator_before_hashtags = i
                break
            if peek and re.match(r'^##\s+Image Prompt\s*$', peek, re.I):
                break
            # Otherwise treat as a body delimiter (legacy format C style)
            collecting = not collecting
            continue
        if re.match(r'^##\s+', s):
            if collecting:
                break
            continue
        collecting = True
        body_lines.append(lines[i])

    body_text = '\n'.join(body_lines).strip()
    if len(body_text) <= 100:
        errors.append(f"Body text is too short ({len(body_text)} chars); must be > 100 chars.")

    # 6. No em-dashes in body
    if '\u2014' in body_text:
        positions = [str(i) for i, c in enumerate(body_text) if c == '\u2014'][:5]
        errors.append(f"Em dash (—) found in body at positions: {', '.join(positions)}. Replace with hyphen (-).")
else:
    # Legacy format A: body wrapped in --- delimiters
    warnings.append("Legacy format (--- delimiters) detected. Passes with warning.")
    in_body = False
    found_delimiters = False
    body_lines = []
    for line in lines:
        s = line.strip()
        if s == '---':
            in_body = not in_body
            found_delimiters = True
            continue
        if in_body:
            if re.match(r'^##\s+(Hashtags|Metadata)\s*$', s):
                break
            if re.match(r'^##\s+', s):
                continue
            body_lines.append(line)
    if not found_delimiters:
        errors.append("No '---' delimiters found for legacy format.")
        body_text = ''
    else:
        body_text = '\n'.join(body_lines).strip()
    if found_delimiters and len(body_text) <= 100:
        errors.append(f"Legacy body text is too short ({len(body_text)} chars); must be > 100 chars.")
    if '\u2014' in body_text:
        positions = [str(i) for i, c in enumerate(body_text) if c == '\u2014'][:5]
        errors.append(f"Em dash (—) found in legacy body at positions: {', '.join(positions)}. Replace with hyphen (-).")

# Legacy format must not be failed for missing ## Draft / ## Image Prompt headings.
# If the only errors are missing headings and we detected a legacy body, downgrade them to warnings.
legacy_heading_errors = [
    "Missing mandatory '## Draft' heading.",
    "Missing mandatory '## Image Prompt' heading."
]
if not draft_headings and all(e in legacy_heading_errors for e in errors) and found_delimiters:
    warnings.extend([e + " (legacy format)" for e in errors])
    errors = []

if errors:
    print("FAIL: " + path, file=sys.stderr)
    for e in errors:
        print(f"  ❌ {e}", file=sys.stderr)
    if warnings:
        for w in warnings:
            print(f"  ⚠️  {w}", file=sys.stderr)
    sys.exit(1)
else:
    print(f"PASS: {path}")
    for w in warnings:
        print(f"  ⚠️  {w}", file=sys.stderr)
    sys.exit(0)
PYEOF
