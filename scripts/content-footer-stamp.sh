#!/usr/bin/env bash
# content-footer-stamp.sh — Append governance triad footer stamp to content files
# Usage: content-footer-stamp.sh --file <path> --status <triad-cleared|internal|blocked>
# Supports: .html, .docx
# TKT-0033

set -uo pipefail
export PATH="$PATH:/usr/local/bin:/opt/homebrew/bin"

FILE=""
STATUS=""

while (( $# > 0 )); do
  case "$1" in
    --file)   FILE="$2"; shift 2 ;;
    --status) STATUS="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$FILE" ]]   && { echo "ERROR: --file required" >&2; exit 1; }
[[ -z "$STATUS" ]] && { echo "ERROR: --status required" >&2; exit 1; }
[[ ! -f "$FILE" ]] && { echo "ERROR: File not found: $FILE" >&2; exit 1; }

DATE=$(date '+%Y-%m-%d')

case "$STATUS" in
  triad-cleared)
    STAMP_TEXT="✅ Cleared for distribution — Governance triad reviewed ${DATE}"
    STAMP_CLASS="governance-cleared"
    ;;
  internal)
    STAMP_TEXT="⚠️ For internal use only — not reviewed for distribution. Check before sharing."
    STAMP_CLASS="governance-internal"
    ;;
  blocked)
    STAMP_TEXT="🚫 BLOCKED — Do not distribute. Governance issues pending resolution."
    STAMP_CLASS="governance-blocked"
    ;;
  *)
    echo "ERROR: --status must be triad-cleared|internal|blocked" >&2; exit 1 ;;
esac

EXT="${FILE##*.}"

# ── HTML handler ──────────────────────────────────────────────────────────────
if [[ "$EXT" == "html" || "$EXT" == "htm" ]]; then
  # Remove any existing governance stamp div
  python3 - "$FILE" "$STAMP_TEXT" "$STAMP_CLASS" << 'PYEOF'
import sys, re

file_path = sys.argv[1]
stamp_text = sys.argv[2]
stamp_class = sys.argv[3]

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove existing governance stamp if present
content = re.sub(r'<div[^>]*class="governance-stamp[^"]*"[^>]*>.*?</div>\s*', '', content, flags=re.DOTALL)

# Build stamp HTML
stamp_html = f'''
<div class="governance-stamp {stamp_class}" style="
  margin: 40px auto 0;
  padding: 12px 20px;
  max-width: 720px;
  border-radius: 6px;
  font-family: monospace;
  font-size: 12px;
  text-align: center;
  {'background: #0d2e0d; color: #4caf50; border: 1px solid #4caf50;' if stamp_class == 'governance-cleared' else
   'background: #2e2200; color: #ff9800; border: 1px solid #ff9800;' if stamp_class == 'governance-internal' else
   'background: #2e0000; color: #f44336; border: 1px solid #f44336;'}
  opacity: 0.85;
">
  {stamp_text}
</div>'''

# Try to insert before </body>, otherwise append
if '</body>' in content:
    content = content.replace('</body>', stamp_html + '\n</body>', 1)
elif '</html>' in content:
    content = content.replace('</html>', stamp_html + '\n</html>', 1)
else:
    content += stamp_html

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"  Stamp appended to HTML: {stamp_text}")
PYEOF
  echo "✅ Footer stamp applied (HTML): $FILE"

# ── DOCX handler ──────────────────────────────────────────────────────────────
elif [[ "$EXT" == "docx" ]]; then
  python3 - "$FILE" "$STAMP_TEXT" << 'PYEOF'
import sys

file_path = sys.argv[1]
stamp_text = sys.argv[2]

try:
    from docx import Document
    from docx.shared import Pt, RGBColor
    from docx.enum.text import WD_ALIGN_PARAGRAPH

    doc = Document(file_path)

    for section in doc.sections:
        footer = section.footer
        # Clear existing governance stamp paragraph if present
        for para in list(footer.paragraphs):
            if any(kw in para.text for kw in ['Governance triad', 'Cleared for distribution', 'BLOCKED', 'internal use only']):
                p = para._element
                p.getparent().remove(p)

        # Add new stamp paragraph
        para = footer.add_paragraph()
        para.alignment = WD_ALIGN_PARAGRAPH.CENTER
        run = para.add_run(stamp_text)
        run.font.size = Pt(8)
        if 'BLOCKED' in stamp_text:
            run.font.color.rgb = RGBColor(0xF4, 0x43, 0x36)
        elif 'internal use only' in stamp_text:
            run.font.color.rgb = RGBColor(0xFF, 0x98, 0x00)
        else:
            run.font.color.rgb = RGBColor(0x4C, 0xAF, 0x50)

    doc.save(file_path)
    print(f"  Stamp appended to DOCX footer: {stamp_text}")

except ImportError:
    print("WARNING: python-docx not installed. DOCX stamp skipped.", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f"ERROR stamping DOCX: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
  echo "✅ Footer stamp applied (DOCX): $FILE"

else
  echo "INFO: Footer stamp skipped for file type: .$EXT (supported: html, docx)"
  exit 0
fi
