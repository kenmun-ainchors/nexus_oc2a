#!/usr/bin/env bash
# eod-blog-generate.sh — EOD blog HTML generator (CHG-0927)
# Renders a deterministic "Day N — AInchors Recap" blog for the given date
# based on the journal + CHANGELOG. Writes to:
#   ~/.openclaw/canvas/documents/ainchors-YYYY-MM-DD/index.html
#
# Usage:
#   bash scripts/eod-blog-generate.sh                # today (MYT)
#   bash scripts/eod-blog-generate.sh 2026-07-18     # explicit date
#
# CHG-0927: replaces the deleted a027fd60 EOD blog cron. No LLM tokens
# required — purely deterministic from existing state files. Output is
# deliberately more utilitarian than the Aria-narrative Day 81 blog
# (which is hand-crafted prose). The intent is to ensure a Drive-synced
# blog exists every day, with the editorially-rich version layered on
# top later (Aria cron) when it stabilises.
set -euo pipefail

WORKSPACE="${WORKSPACE:-/Users/ainchorsoc2a/.openclaw/workspace}"
CANVAS_ROOT="$HOME/.openclaw/canvas/documents"
TARGET_DATE="${1:-$(TZ=Asia/Kuala_Lumpur date +%Y-%m-%d)}"

# Validate date
if ! [[ "$TARGET_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "ERROR: invalid date '$TARGET_DATE' (want YYYY-MM-DD)" >&2
  exit 1
fi

# Day number (epoch 2026-04-25 = Day 1)
EPOCH_SEC=$(TZ=Asia/Kuala_Lumpur date -j -f "%Y-%m-%d" "2026-04-25" "+%s" 2>/dev/null || date -d "2026-04-25" +%s)
TARGET_SEC=$(TZ=Asia/Kuala_Lumpur date -j -f "%Y-%m-%d" "$TARGET_DATE" "+%s" 2>/dev/null || date -d "$TARGET_DATE" +%s)
if [[ "$EPOCH_SEC" -gt 0 && "$TARGET_SEC" -gt 0 ]]; then
  DAY_N=$(( (TARGET_SEC - EPOCH_SEC) / 86400 + 1 ))
else
  DAY_N="?"
fi

JOURNAL_FILE="$WORKSPACE/memory/journal-$TARGET_DATE.md"
CHANGELOG="$WORKSPACE/memory/CHANGELOG.md"
DEST_DIR="$CANVAS_ROOT/ainchors-$TARGET_DATE"
DEST_FILE="$DEST_DIR/index.html"

# Read journal entries (## HH:MM ... lines) for the TOC
TOC_HTML=""
ENTRY_COUNT=0
if [[ -f "$JOURNAL_FILE" ]]; then
  while IFS= read -r line; do
    # match "## HH:MM" headers
    if [[ "$line" =~ ^##\ +([0-9]{1,2}:[0-9]{2})\ +—\ +(.+)$ ]]; then
      t="${BASH_REMATCH[1]}"
      title="${BASH_REMATCH[2]}"
      # truncate long titles
      if [[ ${#title} -gt 90 ]]; then
        title="${title:0:87}…"
      fi
      # HTML-escape
      esc_title=$(printf '%s' "$title" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
      TOC_HTML+="<li><code>$t</code> — $esc_title</li>"
      ENTRY_COUNT=$((ENTRY_COUNT+1))
    fi
  done < "$JOURNAL_FILE"
fi

if [[ -z "$TOC_HTML" ]]; then
  TOC_HTML="<li><em>No journal entries captured for $TARGET_DATE.</em></li>"
fi

# Recent CHGs from CHANGELOG (top 5 since target date)
CHG_HTML="<p>No recent change records.</p>"
if [[ -f "$CHANGELOG" ]]; then
  chg_summary=$(python3 <<PYEOF
import re, sys
text = open("$CHANGELOG").read()
target = "$TARGET_DATE"
# Find CHG headers with date >= target, capped at 5
sections = re.split(r'^## ', text, flags=re.MULTILINE)[1:]
items = []
for sec in sections:
    lines = sec.strip().split('\n')
    if not lines: continue
    header = lines[0]
    body = '\n'.join(lines[1:])
    m_date = re.search(r'(\d{4}-\d{2}-\d{2})', header)
    if not m_date: continue
    chg_date = m_date.group(1)
    if chg_date > target: continue
    m_chg = re.search(r'(CHG-\d+)', header)
    if not m_chg: continue
    m_title = re.search(r'\*\*What changed:\*\*\s*(.*?)(?:\n|$)', body)
    title = m_title.group(1).strip()[:90] if m_title else '(no title)'
    items.append((chg_date, m_chg.group(1), title))
# Take 5 most recent
items.sort(reverse=True)
out = []
for d, c, t in items[:5]:
    d_e = t.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;')
    t_e = d_e  # already escaped above; rename to avoid confusion
    out.append(f"<li><strong>{c}</strong> — {d} — {t}</li>")
print('<ul>' + ''.join(out) + '</ul>' if out else '<p>No recent change records.</p>')
PYEOF
)
  CHG_HTML="$chg_summary"
fi

# Build the day title — pull first prominent heading from journal if available
DAY_TITLE="Day $DAY_N — AInchors Daily Recap"
DAY_SUBTITLE="$TARGET_DATE · Platform build journal"
if [[ -f "$JOURNAL_FILE" ]]; then
  # Use the first '## HH:MM — ...' line as subtitle hint
  first=$(grep -m1 '^## ' "$JOURNAL_FILE" || true)
  if [[ -n "$first" ]]; then
    # Strip the leading '## HH:MM — '
    cleaned=$(echo "$first" | sed -E 's/^## +[0-9]{1,2}:[0-9]{2}\ +—\ +//' | head -c 100)
    if [[ -n "$cleaned" ]]; then
      DAY_SUBTITLE="$TARGET_DATE · $cleaned"
    fi
  fi
fi

# Read first ~3000 chars of journal for an "excerpt" block
EXCERPT_HTML="<p><em>No journal for $TARGET_DATE.</em></p>"
if [[ -f "$JOURNAL_FILE" ]]; then
  # Extract first 3 sections' bodies
  excerpt=$(python3 <<PYEOF
import re, html
text = open("$JOURNAL_FILE").read()
# Split on ## headers
parts = re.split(r'(?m)^## ', text)[1:4]
out = []
for p in parts:
    # Each part: "HH:MM — title\nbody"
    lines = p.split('\n', 1)
    if len(lines) < 2:
        continue
    hdr = lines[0]
    body = lines[1].strip()
    # First paragraph only, up to 600 chars
    para = body.split('\n\n')[0] if '\n\n' in body else body
    para = para[:600]
    e_para = html.escape(para).replace('\n', '<br>')
    e_hdr = html.escape(hdr.strip())
    out.append(f'<h3>{e_hdr}</h3><p>{e_para}</p>')
print('\n'.join(out) if out else '<p><em>No journal for $TARGET_DATE.</em></p>')
PYEOF
)
  EXCERPT_HTML="$excerpt"
fi

# Build the full HTML
NOW_ISO=$(TZ=Asia/Kuala_Lumpur date -Iseconds)
mkdir -p "$DEST_DIR"

cat > "$DEST_FILE" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Day ${DAY_N} — AInchors Recap (${TARGET_DATE})</title>
<style>
  :root { --bg:#0f1117; --surface:#181c24; --surface2:#1e2330; --border:#2a2f3d; --text:#d8dce8; --muted:#7a8099; --accent:#4fa3e0; --accent2:#6ee7b7; --warn:#f59e0b; --danger:#ef4444; --success:#22c55e; --tag:#2563eb; }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: var(--bg); color: var(--text); font-family: Georgia, 'Times New Roman', serif; font-size: 17px; line-height: 1.75; }
  .page { max-width: 760px; margin: 0 auto; padding: 32px 24px 80px; }
  header.hero { border-bottom: 1px solid var(--border); padding-bottom: 20px; margin-bottom: 28px; }
  .day-badge { display: inline-block; padding: 4px 10px; border: 1px solid var(--border); border-radius: 20px; font-family: -apple-system, sans-serif; font-size: 12px; color: var(--muted); letter-spacing: 0.5px; }
  h1 { font-size: 32px; line-height: 1.2; margin: 12px 0 8px; color: #fff; }
  .subtitle { color: var(--muted); font-size: 16px; }
  .hero-meta { margin-top: 14px; display: flex; gap: 18px; flex-wrap: wrap; font-family: -apple-system, sans-serif; font-size: 12px; color: var(--muted); }
  .hero-meta .dot { color: var(--accent2); }
  main.article h2 { font-size: 22px; margin: 32px 0 12px; padding-bottom: 6px; border-bottom: 1px solid var(--border); }
  main.article h3 { font-size: 18px; margin: 20px 0 8px; color: var(--accent); }
  main.article p { margin: 8px 0; }
  main.article code { font-family: 'SF Mono', Menlo, monospace; font-size: 13px; background: var(--surface); padding: 1px 6px; border-radius: 4px; color: var(--accent2); }
  main.article ul { padding-left: 22px; margin: 8px 0; }
  main.article li { margin: 4px 0; font-size: 15px; }
  .toc { background: var(--surface); border: 1px solid var(--border); border-radius: 8px; padding: 16px 20px; margin: 20px 0; font-family: -apple-system, sans-serif; font-size: 14px; }
  .toc h2 { margin: 0 0 8px; font-size: 14px; text-transform: uppercase; letter-spacing: 0.5px; color: var(--muted); border: 0; padding: 0; }
  .toc ol { padding-left: 20px; }
  .toc code { font-size: 12px; }
  .governance { margin-top: 40px; padding: 16px 20px; border: 1px solid var(--border); border-radius: 8px; background: var(--surface); font-family: -apple-system, sans-serif; font-size: 12px; color: var(--muted); }
  .governance .g-title { color: var(--accent2); font-weight: 700; letter-spacing: 0.5px; text-transform: uppercase; margin-bottom: 6px; }
  .brand { margin-top: 24px; text-align: center; font-size: 12px; color: var(--muted); font-family: -apple-system, sans-serif; }
</style>
</head>
<body>
<div class="page">

<header class="hero">
  <span class="day-badge">Day ${DAY_N} · ${TARGET_DATE}</span>
  <h1>${DAY_TITLE}</h1>
  <p class="subtitle">${DAY_SUBTITLE}</p>
  <div class="hero-meta">
    <span><span class="dot">●</span> ${ENTRY_COUNT} journal entries</span>
    <span><span class="dot">●</span> Generated ${NOW_ISO}</span>
    <span><span class="dot">●</span> AInchors Nexus Platform</span>
  </div>
</header>

<main class="article">

  <section class="toc">
    <h2>Today's Journal — Table of Contents</h2>
    <ol>
${TOC_HTML}
    </ol>
  </section>

  <h2>Day Excerpt</h2>
${EXCERPT_HTML}

  <h2>Recent Change Records (CHG-)</h2>
  ${CHG_HTML}

  <div class="governance">
    <div class="g-title">Governance Stamp</div>
    Content ID: BLOG-DAY${DAY_N}-${TARGET_DATE}<br>
    Source: memory/journal-${TARGET_DATE}.md · memory/CHANGELOG.md<br>
    Generated: ${NOW_ISO}<br>
    Pipeline: scripts/eod-blog-generate.sh (CHG-0927 deterministic generator)<br>
    <em>Note: this is the deterministic baseline blog. The Aria-edited narrative version (when available) supersedes it for public posting. This file is sufficient for Drive sync and the daily recap email.</em>
  </div>

</main>

<p class="brand">AInchors · ainchors.com · Day ${DAY_N} of the Nexus platform build</p>

</div>
</body>
</html>
HTML

# Report
SIZE=$(wc -c < "$DEST_FILE" | tr -d ' ')
echo "EOD-BLOG: Day $DAY_N blog written to $DEST_FILE (${SIZE} bytes, ${ENTRY_COUNT} journal entries)"
