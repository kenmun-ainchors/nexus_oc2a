#!/usr/bin/env bash
# generate-standup.sh
# Shell-only Morning Stand-Up HTML generator.
# Reads deterministic state files and composer blocks, renders 8-section stand-up HTML,
# pipes to cron-write.sh.
# Supports: STANDUP_FORCE=1 (skip freshness check), STANDUP_DRY_RUN=1 (write to temp file).

set -euo pipefail

WORKSPACE="${WORKSPACE:-/Users/ainchorsoc2a/.openclaw/workspace}"
CANVAS_DIR="${HOME}/.openclaw/canvas/documents/standup-daily"
HTML_FILE="${CANVAS_DIR}/index.html"

# ── Env overrides ────────────────────────────────────────────────────────────
STANDUP_FORCE="${STANDUP_FORCE:-0}"
STANDUP_DRY_RUN="${STANDUP_DRY_RUN:-0}"

if [[ "$STANDUP_DRY_RUN" == "1" ]]; then
    HTML_FILE="${WORKSPACE}/.openclaw/tmp/standup-dryrun.html"
    mkdir -p "$(dirname "$HTML_FILE")"
fi

# ── File paths ───────────────────────────────────────────────────────────────
STATE_FILE="${WORKSPACE}/state/standup-state.json"
HEALTH_FILE="${WORKSPACE}/state/health-state.json"
COST_FILE="${WORKSPACE}/state/cost-state.json"
BACKUP_FILE="${WORKSPACE}/state/backup-state.json"
AUTOHEAL_FILE="${WORKSPACE}/state/auto-heal-current.json"
AUTOHEAL_FALLBACK_FILE="${WORKSPACE}/state/auto-heal-state.json"
AUTOHEAL_DATED_FILE="${WORKSPACE}/state/auto-heal-$(TZ=Asia/Kuala_Lumpur date -v-1d '+%Y-%m-%d').json"
CHANGELOG="${WORKSPACE}/memory/CHANGELOG.md"
DAILY_NOTE="${WORKSPACE}/state/daily-note.json"
COMPOSER_FILE="${WORKSPACE}/.openclaw/tmp/standup-composer-input.json"
COMPOSER_SCRIPT="${WORKSPACE}/scripts/standup-composer.sh"
COMPOSER_HASH_FILE="${WORKSPACE}/.openclaw/tmp/standup-composer-hash.txt"
COMPOSER_EXPORT_FILE="${WORKSPACE}/.openclaw/tmp/standup-composer-export.json"

# ── Freshness: content hash check ────────────────────────────────────────────
# Compute hash of current composer output (if it exists)
NEW_HASH=""
if [[ -f "$COMPOSER_FILE" ]]; then
    NEW_HASH=$(md5 -q "$COMPOSER_FILE" 2>/dev/null || shasum -a 256 "$COMPOSER_FILE" | cut -d' ' -f1)
fi

OLD_HASH=""
if [[ -f "$COMPOSER_HASH_FILE" ]]; then
    OLD_HASH=$(cat "$COMPOSER_HASH_FILE")
fi

COMPOSER_NEEDS_RUN=false

# Force flag skips freshness check
if [[ "$STANDUP_FORCE" == "1" ]]; then
    COMPOSER_NEEDS_RUN=true
    echo "[standup] STANDUP_FORCE=1 — forcing composer regeneration" >&2
elif [[ ! -f "$COMPOSER_FILE" ]]; then
    COMPOSER_NEEDS_RUN=true
elif [[ -n "$NEW_HASH" && "$NEW_HASH" == "$OLD_HASH" ]]; then
    # Same content as last run — force re-run by clearing
    echo "[standup] Composer content unchanged from previous run — forcing re-run" >&2
    rm -f "$COMPOSER_FILE"
    COMPOSER_NEEDS_RUN=true
else
    echo "[standup] Composer content fresh (hash differs from previous)" >&2
fi

# ── Run composer if needed ───────────────────────────────────────────────────
COMPOSER_STATUS="degraded"
SOURCE_LIST=""
COMPOSER_FAILED=false

if [[ -f "$COMPOSER_SCRIPT" ]]; then
    if [[ "$COMPOSER_NEEDS_RUN" == "true" ]] || [[ ! -f "$COMPOSER_FILE" ]]; then
        echo "[standup] Running standup-composer.sh..." >&2
        set +e
        bash "$COMPOSER_SCRIPT" 2>&1
        COMPOSER_EXIT=$?
        set -e
        if [[ $COMPOSER_EXIT -ne 0 ]]; then
            echo "[standup] Composer exited with code $COMPOSER_EXIT" >&2
            COMPOSER_FAILED=true
            COMPOSER_STATUS="degraded"
        fi
    fi
fi

# Parse composer output
COMPOSER_JSON="{}"
if [[ -f "$COMPOSER_FILE" ]]; then
    COMPOSER_JSON=$(cat "$COMPOSER_FILE")

    # Check if composer_status indicates degraded
    if echo "$COMPOSER_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
if d.get('composer_status') == 'degraded':
    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
        COMPOSER_STATUS="degraded"
        COMPOSER_FAILED=true
    else
        COMPOSER_STATUS="ok"
    fi

    # Update hash file
    NEW_HASH=$(md5 -q "$COMPOSER_FILE" 2>/dev/null || shasum -a 256 "$COMPOSER_FILE" | cut -d' ' -f1)
    echo "$NEW_HASH" > "$COMPOSER_HASH_FILE"
fi

# Build source list for footer
SOURCE_LIST="Aria brief $(head -1 "${WORKSPACE}/state/aria-daily-brief.md" 2>/dev/null | grep -oE '2026-[0-9][0-9]-[0-9][0-9]' || echo ''), "
for day in "$(TZ=Asia/Kuala_Lumpur date '+%Y-%m-%d')" "$(TZ=Asia/Kuala_Lumpur date -v-1d '+%Y-%m-%d')"; do
    if [[ -f "${WORKSPACE}/memory/journal-${day}.md" ]]; then
        SOURCE_LIST+="journal ${day}, "
    fi
done
if [[ -f "${WORKSPACE}/state/sprint-current.json" ]]; then
    sprint_name=$(python3 -c "
import json; d=json.load(open('${WORKSPACE}/state/sprint-current.json')); print(d.get('sprint','?'))
" 2>/dev/null)
    SOURCE_LIST+="sprint ${sprint_name}, "
fi
SOURCE_LIST="${SOURCE_LIST%, }"

if [[ -f "$COMPOSER_FILE" ]]; then
    SOURCE_LIST+=", composer ${COMPOSER_STATUS}"
else
    SOURCE_LIST+=", composer unavailable"
fi

# ── Export composer data for Python heredoc ──────────────────────────────────
echo "$COMPOSER_JSON" > "$COMPOSER_EXPORT_FILE"

# ── Generate HTML ────────────────────────────────────────────────────────────
mkdir -p "$CANVAS_DIR"

python3 << 'PYEOF' | bash "${WORKSPACE}/scripts/cron-write.sh" "$HTML_FILE"
import json, os, subprocess, sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

WORKSPACE = Path(os.environ.get("WORKSPACE", "/Users/ainchorsoc2a/.openclaw/workspace"))
TMP_DIR = WORKSPACE / ".openclaw" / "tmp"
COMPOSER_EXPORT = TMP_DIR / "standup-composer-export.json"

def safe_read_json(path, default=None):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return default if default is not None else {}

def safe_read_text(path, default=""):
    try:
        with open(path) as f:
            return f.read()
    except Exception:
        return default

def fmt_date(d):
    return d.strftime("%A, %-d %B %Y")

def day_number(today):
    start = datetime(2026, 4, 25).date()
    return (today - start).days + 1

def escape(s):
    return str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

# ── Date / day ───────────────────────────────────────────────────────────────
local_tz = timezone(timedelta(hours=8))
now_local = datetime.now(timezone.utc).astimezone(local_tz)
today_str = now_local.date().isoformat()
day_n = day_number(now_local.date())
yesterday_dt = (now_local.date() - timedelta(days=1))

# ── Idempotency ──────────────────────────────────────────────────────────────
state = safe_read_json(WORKSPACE / "state" / "standup-state.json", {})
force_flag = os.environ.get("STANDUP_FORCE") == "1"
if state.get("lastStandupDate") == today_str and not force_flag:
    print(f"[standup] already generated for {today_str}; set STANDUP_FORCE=1 to override", file=sys.stderr)
    html = safe_read_text(os.path.expanduser("~/.openclaw/canvas/documents/standup-daily/index.html"), "")
    print(html)
    sys.exit(0)

# ── Data collection ──────────────────────────────────────────────────────────
health = safe_read_json(WORKSPACE / "state" / "health-state.json", {})
cost = safe_read_json(WORKSPACE / "state" / "cost-state.json", {})
backup = safe_read_json(WORKSPACE / "state" / "backup-state.json", {})
autoheal = safe_read_json(WORKSPACE / "state" / "auto-heal-state.json", {})
daily_note = safe_read_json(WORKSPACE / "state" / "daily-note.json", {})
# New health/status cards
budget = safe_read_json(WORKSPACE / "state" / "request-budget-alert-state.json", {})
latency = safe_read_json(WORKSPACE / "state" / "latency-summary.json", {})
drift = safe_read_json(WORKSPACE / "state" / "model-drift-state.json", {})
cron_health = safe_read_json(WORKSPACE / "state" / "cron-health-state.json", {})
crest_compliance = safe_read_json(WORKSPACE / "state" / "aria-crest-compliance.json", {})
fw_maturity_data = safe_read_json(WORKSPACE / "state" / "frameworks-maturity.json", {})
open_decisions = safe_read_json(WORKSPACE / "state" / "open-decisions.json", {})
draft_docs = safe_read_json(WORKSPACE / "state" / "draft-docs.json", {})

overall = health.get("overallStatus", health.get("status", "unknown"))
gateway_ok = overall.lower() in ("ok", "good")
last_check = health.get("lastCheck", "")

# Cost
balance = cost.get("confirmedBalance") or cost.get("apiBalance", {}).get("remainingEstimate", 0.0)
try:
    balance = float(balance)
except Exception:
    balance = 0.0
balance_str = f"${balance:.2f}" if balance else "N/A"

# Backup
last_snap = backup.get("lastSnap", backup.get("lastSnapshot", "N/A"))
backup_fresh = bool(last_snap and today_str in str(last_snap))

# MEMORY.md size
mem_path = WORKSPACE / "MEMORY.md"
try:
    mem_size = mem_path.stat().st_size
except Exception:
    mem_size = 0
mem_status = "🟢 Under limit" if mem_size < 15000 else "🟡 Over 15KB"

# ── New auto-heal: try auto-heal-current.json first, fall back to auto-heal-state.json, then dated ──
autoheal_current = safe_read_json(WORKSPACE / "state" / "auto-heal-current.json", {})
if autoheal_current and autoheal_current.get("exit_status"):
    # Use auto-heal-current.json as canonical
    autoheal_current_source = "state/auto-heal-current.json"
    checks_count = autoheal_current.get("checks_count", 0)
    issues_count = autoheal_current.get("issues_count", 0)
    issues_found = autoheal_current.get("issues_found", [])
    auto_fixed_count = autoheal_current.get("auto_fixed_count", 0)
    checks_run_count = autoheal_current.get("checks_count", 0)
    checks_passed = checks_run_count - issues_count
    exit_status = autoheal_current.get("exit_status", "unknown")
    autoheal_needs_ken = autoheal_current.get("needs_ken", [])
elif autoheal and autoheal.get("needsKen") is not None:
    autoheal_current_source = "state/auto-heal-state.json"
    checks_count = autoheal.get("checksCount", 0)
    issues_count = autoheal.get("issuesCount", 0)
    issues_found = autoheal.get("issues", [])
    auto_fixed_count = autoheal.get("autoFixedCount", 0)
    checks_run_count = autoheal.get("checkCount", 0)
    checks_passed = checks_run_count - issues_count
    exit_status = autoheal.get("exitStatus", "unknown")
    autoheal_needs_ken = autoheal.get("needsKen", autoheal.get("needs_ken", []))
else:
    # Try yesterday's dated file
    yesterday_str = yesterday_dt.isoformat()
    autoheal_current_source = f"state/auto-heal-{yesterday_str}.json"
    autoheal_yesterday = safe_read_json(WORKSPACE / f"state/auto-heal-{yesterday_str}.json", {})
    if autoheal_yesterday and autoheal_yesterday.get("exit_status"):
        checks_count = autoheal_yesterday.get("checks_count", 0)
        issues_count = autoheal_yesterday.get("issues_count", 0)
        issues_found = autoheal_yesterday.get("issues_found", [])
        auto_fixed_count = autoheal_yesterday.get("auto_fixed_count", 0)
        checks_run_count = autoheal_yesterday.get("checks_count", 0)
        checks_passed = checks_run_count - issues_count
        exit_status = autoheal_yesterday.get("exit_status", "unknown")
        autoheal_needs_ken = autoheal_yesterday.get("needs_ken", [])
    else:
        autoheal_needs_ken = autoheal.get("needsKen", autoheal.get("needs_ken", []))
        checks_count = 0
        issues_count = 0
        issues_found = []
        auto_fixed_count = 0
        checks_run_count = 0
        checks_passed = 0
        exit_status = "unknown"

# Build autoheal HTML
autoheal_html_parts = []

# Summary
if checks_run_count > 0:
    autoheal_html_parts.append(
        f'<div class="card-grid">'
        f'<div class="card card-{"ok" if exit_status == "complete" else "warn"}"><div class="card-label">Checks</div><div class="card-value">{checks_run_count}</div><div class="card-sub">total checks run</div></div>'
        f'<div class="card card-{"ok" if issues_count == 0 else "warn"}"><div class="card-label">Passed / Failed</div><div class="card-value">{checks_passed} / {issues_count}</div><div class="card-sub">issues found</div></div>'
        f'<div class="card card-info"><div class="card-label">Auto-Fixed</div><div class="card-value">{auto_fixed_count}</div><div class="card-sub">items auto-remedied</div></div>'
        f'<div class="card card-{"ok" if exit_status == "complete_with_needs_ken" else "info"}"><div class="card-label">Exit Status</div><div class="card-value">{escape(exit_status.upper())}</div><div class="card-sub">{escape(autoheal_current_source)}</div></div>'
        f'</div>'
    )
    if issues_found:
        autoheal_html_parts.append('<div class="alert-warn"><strong>Issues Found:</strong><ul>' + "".join(f'<li>{escape(str(i))}</li>' for i in issues_found) + '</ul></div>')

# NEEDS_KEN rendering
if isinstance(autoheal_needs_ken, list) and autoheal_needs_ken:
    # Check if items are dicts or strings
    if isinstance(autoheal_needs_ken[0], dict):
        autoheal_html_parts.append('<h3>NEEDS_KEN Items</h3>')
        autoheal_html_parts.append('<table style="width:100%;border-collapse:collapse;font-size:12px;margin:6px 0;">')
        autoheal_html_parts.append('<tr style="background:#f0f2f4;"><th style="padding:4px 8px;text-align:left;border:1px solid #d0d7de;">Check</th><th style="padding:4px 8px;text-align:left;border:1px solid #d0d7de;">Reason</th><th style="padding:4px 8px;text-align:left;border:1px solid #d0d7de;">Severity</th></tr>')
        for item in autoheal_needs_ken:
            if isinstance(item, dict):
                check = escape(item.get("check", ""))
                reason = escape(item.get("reason", ""))
                severity = escape(item.get("severity", "medium"))
            else:
                # Object-like string, attempt to parse
                parts = str(item).split(":", 2)
                check = escape(parts[0]) if len(parts) > 0 else ""
                reason = escape(parts[1]) if len(parts) > 1 else ""
                severity = "warn"
            autoheal_html_parts.append(f'<tr><td style="padding:4px 8px;border:1px solid #d0d7de;">{check}</td><td style="padding:4px 8px;border:1px solid #d0d7de;">{reason}</td><td style="padding:4px 8px;border:1px solid #d0d7de;color:#cf222e;">{severity}</td></tr>')
        autoheal_html_parts.append('</table>')
    else:
        autoheal_html_parts.append('<h3>NEEDS_KEN Items</h3>')
        autoheal_html_parts.append("<ul>" + "".join(
            f"<li>{escape(str(i))}</li>" for i in autoheal_needs_ken
        ) + "</ul>")
elif isinstance(autoheal_needs_ken, list) and not autoheal_needs_ken:
    autoheal_html_parts.append('<div class="alert-ok">✅ No NEEDS_KEN items — auto-heal clean.</div>')
elif isinstance(autoheal_needs_ken, str) and autoheal_needs_ken:
    autoheal_html_parts.append(f"<p>{escape(autoheal_needs_ken)}</p>")
else:
    autoheal_html_parts.append('<div class="alert-ok">✅ No NEEDS_KEN items — auto-heal clean.</div>')

autoheal_html = "\n".join(autoheal_html_parts)

# Daily note health
note_health = daily_note.get("healthStatus", "")

# ── Recent CHGs from CHANGELOG — parse structured entries ────────────────────
import re as _re
chg_entries = []
try:
    text = safe_read_text(str(WORKSPACE / "memory" / "CHANGELOG.md"))
    # Split by ## headers
    sections = _re.split(r'^## ', text, flags=_re.MULTILINE)
    for sec in sections[1:]:
        lines = sec.strip().split('\n')
        header_line = lines[0].strip()
        body = '\n'.join(lines[1:])
        # Date from header
        date_match = _re.search(r'(\d{4}-\d{2}-\d{2})', header_line)
        date = date_match.group(1) if date_match else ''
        # CHG ID from header or body
        chg_match = _re.search(r'\[(CHG-\d+)\]', header_line + body)
        chg_id = chg_match.group(1) if chg_match else ''
        # Title from **What changed:**
        title_match = _re.search(r'\*\*What changed:\*\*\s*(.*?)(?:\n|$)', body)
        title = title_match.group(1).strip() if title_match else ''
        if not title and chg_match:
            # Try from the [CHG-XXXX] text in header
            title_from_header = _re.sub(r'^.*\[CHG-\d+\]\s*', '', header_line).strip()
            title = title_from_header if title_from_header else ''
        # Type
        type_match = _re.search(r'\*\*Type:\*\*\s*(.*?)(?:\n|$)', body)
        typ = type_match.group(1).strip() if type_match else ''
        if date and chg_id:
            chg_entries.append({'date': date, 'chg_id': chg_id, 'title': title[:100], 'type': typ})
    chg_entries = chg_entries[:8]
except Exception:
    pass

chg_html = ""
if chg_entries:
    items = []
    for e in chg_entries:
        t = escape(e['title']) if e['title'] else '?'
        tp = escape(e['type']) if e['type'] else '?'
        d = escape(e['date'])
        items.append(f'<li><strong>{escape(e["chg_id"])}</strong> — {t} · {tp} · {d}</li>')
    chg_html = "<ul>" + "\n".join(items) + "</ul>"
else:
    chg_html = "<p>No new changes recorded since last stand-up.</p>"

# ── CREST compliance block ────────────────────────────────────────────────────
creST_html_parts = []
if crest_compliance and crest_compliance.get("status"):
    c_status = escape(crest_compliance["status"])
    c_time = escape(crest_compliance.get("checked_at", ""))
    c_violations = crest_compliance.get("violations", [])
    c_violation_count = crest_compliance.get("violation_count", len(c_violations))
    c_pill = "pill-green" if c_status.lower() in ("compliant", "ok", "passed") else "pill-red"
    creST_html_parts.append(f'<div><span class="pill {c_pill}">{escape(c_status)}</span> <span style="font-size:12px;color:#57606a;">Last check: {c_time}</span></div>')
    if c_violations:
        creST_html_parts.append('<h3>Violations</h3><ul>' + "".join(f'<li>{escape(str(v))}</li>' for v in c_violations) + '</ul>')
    else:
        creST_html_parts.append('<div class="alert-ok" style="margin-top:6px;">✅ No violations — CREST compliance clean.</div>')
else:
    creST_html_parts.append('<div class="alert-info">ℹ️ No CREST compliance data available.</div>')
crest_html = "\n".join(creST_html_parts)

# ── Framework Maturity (table) ───────────────────────────────────────────────
fw_items = fw_maturity_data.get("frameworks", [])
if fw_items:
    # Sort by score descending, take top 5
    scored = []
    for fw in fw_items:
        level = fw.get("maturity", "L1")
        try:
            score = int(level[1]) if len(level) >= 2 else 0
        except Exception:
            score = 0
        scored.append((score, fw))
    scored.sort(key=lambda x: -x[0])
    top5 = scored[:5]
    fw_html = '<table style="width:100%;border-collapse:collapse;font-size:12px;margin:6px 0;">'
    fw_html += '<tr style="background:#f0f2f4;"><th style="padding:4px 8px;text-align:left;border:1px solid #d0d7de;">Framework</th><th style="padding:4px 8px;text-align:left;border:1px solid #d0d7de;">Level</th><th style="padding:4px 8px;text-align:left;border:1px solid #d0d7de;">Status</th></tr>'
    for score, fw in top5:
        fname = escape(fw.get("name", "?"))
        flevel = escape(fw.get("maturity", "?"))
        fstatus = escape(fw.get("label", "?"))
        fw_html += f'<tr><td style="padding:4px 8px;border:1px solid #d0d7de;">{fname}</td><td style="padding:4px 8px;border:1px solid #d0d7de;">{flevel}</td><td style="padding:4px 8px;border:1px solid #d0d7de;">{fstatus}</td></tr>'
    fw_html += '</table>'
else:
    fw_html = '<div class="alert-info">ℹ️ Framework maturity data not available.</div>'

# ── Open Decisions ────────────────────────────────────────────────────────────
od_items = []
if isinstance(open_decisions, list):
    od_items = open_decisions[:3]
elif isinstance(open_decisions, dict):
    od_items = open_decisions.get("decisions", open_decisions.get("items", []))[:3]
od_html = ""
if od_items:
    od_html = f'<p>{len(od_items)} open decision(s):</p><ul>' + "".join(
        f'<li>{escape(i.get("title", i) if isinstance(i, dict) else str(i))}</li>' for i in od_items
    ) + '</ul>'
else:
    od_html = '<div class="alert-info">ℹ️ No open decisions.</div>'

# ── Draft Docs ────────────────────────────────────────────────────────────────
dd_items = []
if isinstance(draft_docs, list):
    dd_items = draft_docs[:3]
elif isinstance(draft_docs, dict):
    dd_items = draft_docs.get("docs", draft_docs.get("items", []))[:3]
dd_html = ""
if dd_items:
    dd_html = f'<p>{len(dd_items)} draft doc(s):</p><ul>' + "".join(
        f'<li>{escape(i.get("title", i) if isinstance(i, dict) else str(i))}</li>' for i in dd_items
    ) + '</ul>'
else:
    dd_html = '<div class="alert-info">ℹ️ No draft docs.</div>'

# ── Sprint items (for Section 8 prompt bullets) ──────────────────────────────
sprint_data = safe_read_json(WORKSPACE / "state" / "sprint-current.json", {})
sprint_tickets = safe_read_json(WORKSPACE / "state" / "sprint-items.json", {})
sprint_items_top = []
if isinstance(sprint_tickets, dict) and sprint_tickets.get("items"):
    for item in sprint_tickets["items"][:3]:
        if isinstance(item, dict) and item.get("title"):
            sprint_items_top.append(escape(item["title"]))
elif isinstance(sprint_tickets, list):
    for item in sprint_tickets[:3]:
        if isinstance(item, dict) and item.get("title"):
            sprint_items_top.append(escape(item["title"]))
        else:
            sprint_items_top.append(escape(str(item)))

# Build focus area suggestions for Section 8
focus_bullets = []
if sprint_items_top:
    focus_bullets.append(f'<strong>Sprint 11 items:</strong> {"; ".join(sprint_items_top)}')
if isinstance(autoheal_needs_ken, list) and autoheal_needs_ken:
    if isinstance(autoheal_needs_ken[0], dict):
        need_items = [autoheal_needs_ken[0].get("check", str(autoheal_needs_ken[0]))]
    else:
        need_items = [str(n)[:60] for n in autoheal_needs_ken[:2]]
    focus_bullets.append(f'<strong>Auto-heal:</strong> {"; ".join(need_items)}')
if od_items:
    first_od = od_items[0]
    first_od_title = first_od.get("title", str(first_od)) if isinstance(first_od, dict) else str(first_od)
    focus_bullets.append(f'<strong>Open decision:</strong> {escape(first_od_title[:80])}')

focus_html = ""
if focus_bullets:
    focus_html = "<ul style=\"margin-top:8px;text-align:left;\">" + "".join(
        f"<li>{b}</li>" for b in focus_bullets
    ) + "</ul>"

# ── Source file list for footer ──────────────────────────────────────────────
source_files = [
    "state/standup-state.json",
    "state/health-state.json",
    "state/cost-state.json",
    "state/backup-state.json",
    "state/request-budget-alert-state.json",
    "state/latency-summary.json",
    "state/model-drift-state.json",
    "state/cron-health-state.json",
    "state/aria-crest-compliance.json",
    "state/frameworks-maturity.json",
    autoheal_current_source,
    "memory/CHANGELOG.md",
    "memory/MEMORY.md"
]
source_file_list = ", ".join(source_files)

# ── Recent Journal Snippets ──────────────────────────────────────────────────
journal_snippets = []
recent_dates = [
    (now_local.date() - timedelta(days=i)).isoformat()
    for i in range(1, 4)
]
for jdate in recent_dates:
    jpath = WORKSPACE / "memory" / f"journal-{jdate}.md"
    if jpath.exists():
        try:
            jtext = safe_read_text(str(jpath))
            # Get first entry title (line starting with ##)
            for line in jtext.split("\n"):
                line = line.strip()
                if line.startswith("## ") and len(line) > 3:
                    snippet = line.replace("## ", "").strip()
                    if len(snippet) > 20:
                        journal_snippets.append({"date": jdate, "title": snippet[:100]})
                        break
        except Exception:
            pass

# ── Latency by Model table ───────────────────────────────────────────────────
latency_by_model = latency.get("byModel", {})
latency_model_rows = []
for model_name, model_data in sorted(latency_by_model.items(), key=lambda x: -x[1].get("sampleCount", 0)):
    samples = model_data.get("sampleCount", 0)
    p50 = model_data.get("p50Ms", "?")
    p95 = model_data.get("p95Ms", "?")
    avg_s = round(model_data.get("avgMs", 0) / 1000, 1)
    latency_model_rows.append({"name": model_name[:50], "samples": samples, "p50": p50, "p95": p95, "avg": avg_s})

# ── Load composer blocks from exported file ──────────────────────────────────
composer = {}
try:
    if COMPOSER_EXPORT.exists():
        with open(COMPOSER_EXPORT) as f:
            composer = json.load(f)
except Exception:
    pass

# Determine composer status
composer_status = "ok"
degraded_reason = ""
if composer.get("composer_status") == "degraded":
    composer_status = "degraded"
    degraded_reason = composer.get("degraded_reason", "Unknown reason")

# Extract blocks with fallbacks
biz_stream = composer.get("businessStream", "")
fw_maturity = composer.get("frameworkMaturity", "")
progress_block = composer.get("progress", "")
rtb = composer.get("rtb", {})
rose_text = rtb.get("rose", "")
thorn_text = rtb.get("thorn", "")
bud_text = rtb.get("bud", "")

header_pill = "pill-green" if gateway_ok else "pill-yellow"
header_text = "🟢 System OK" if gateway_ok else "🟡 System Needs Attention"

# ── Composer model ────────────────────────────────────────────────────────────
composer_model = composer.get("composer_model", "")
if not composer_model:
    composer_model = "ollama/deepseek-v4-flash:cloud"

# Source list from env
source_list = os.environ.get("STANDUP_SOURCE_LIST", "")
if source_list:
    source_list = f" | Sources: {source_list}"
source_footer = f"Composer: {composer_status}{source_list}"

# ── Build HTML ───────────────────────────────────────────────────────────────
html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>AInchors Stand-up — Day {day_n} | {fmt_date(now_local.date())}</title>
<style>
  *, *::before, *::after {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{ background: #ffffff; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; font-size: 14px; color: #24292f; line-height: 1.5; }}
  .page {{ background: #f6f8fa; max-width: 760px; margin: 0 auto; padding: 24px; }}
  .header {{ background: #0969da; color: #ffffff; border-radius: 8px; padding: 20px 24px; margin-bottom: 20px; }}
  .header h1 {{ font-size: 20px; font-weight: 700; }}
  .header .sub {{ font-size: 13px; opacity: 0.85; margin-top: 4px; }}
  .header .meta {{ display: flex; gap: 12px; margin-top: 12px; flex-wrap: wrap; }}
  .pill {{ display: inline-flex; align-items: center; gap: 4px; padding: 4px 10px; border-radius: 20px; font-size: 12px; font-weight: 600; }}
  .pill-green {{ background: #dafbe1; color: #1a7f37; border: 1px solid #2da44e; }}
  .pill-blue {{ background: #ddf4ff; color: #0969da; border: 1px solid #54aeff; }}
  .pill-yellow {{ background: #fff8c5; color: #9a6700; border: 1px solid #d4a72c; }}
  .pill-red {{ background: #ffebe9; color: #cf222e; border: 1px solid #f85149; }}
  .pill-amber {{ background: #fff8c5; color: #9a6700; border: 1px solid #d4a72c; }}
  .section {{ background: #ffffff; border: 1px solid #d0d7de; border-radius: 8px; padding: 16px; margin-bottom: 16px; }}
  h2 {{ color: #0969da; font-size: 16px; font-weight: 700; border-bottom: 1px solid #d0d7de; padding-bottom: 8px; margin-bottom: 12px; }}
  h3 {{ color: #57606a; font-size: 13px; text-transform: uppercase; letter-spacing: 0.5px; margin: 12px 0 6px; font-weight: 600; }}
  .card-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 10px; margin-bottom: 12px; }}
  .card {{ background: #f6f8fa; border: 1px solid #d0d7de; border-radius: 8px; padding: 14px; }}
  .card-label {{ font-size: 11px; color: #57606a; text-transform: uppercase; letter-spacing: 0.5px; }}
  .card-value {{ font-size: 20px; font-weight: 700; color: #24292f; margin: 2px 0; }}
  .card-sub {{ font-size: 12px; color: #57606a; }}
  .card-ok {{ border-left: 3px solid #2da44e; }}
  .card-warn {{ border-left: 3px solid #d4a72c; }}
  .card-info {{ border-left: 3px solid #54aeff; }}
  .alert-warn {{ background: #fff8c5; border: 1px solid #d4a72c; border-radius: 6px; padding: 10px 14px; margin: 8px 0; font-size: 13px; color: #9a6700; }}
  .alert-ok {{ background: #dafbe1; border: 1px solid #2da44e; border-radius: 6px; padding: 10px 14px; margin: 8px 0; font-size: 13px; color: #1a7f37; }}
  .alert-info {{ background: #ddf4ff; border: 1px solid #54aeff; border-radius: 6px; padding: 10px 14px; margin: 8px 0; font-size: 13px; color: #0969da; }}
  ul {{ padding-left: 20px; margin: 6px 0; }}
  li {{ margin: 3px 0; font-size: 13px; }}
  .rtb-row {{ display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 10px; }}
  .rtb-card {{ background: #f6f8fa; border: 1px solid #d0d7de; border-radius: 8px; padding: 12px; }}
  .rtb-icon {{ font-size: 18px; margin-bottom: 4px; }}
  .rtb-stream {{ font-size: 11px; color: #57606a; text-transform: uppercase; letter-spacing: 0.5px; font-weight: 600; }}
  .rtb-text {{ font-size: 13px; color: #24292f; margin-top: 4px; }}
  .footer {{ color: #57606a; font-size: 12px; border-top: 1px solid #d0d7de; padding-top: 14px; margin-top: 16px; text-align: center; }}
  .new-input {{ background: #f6f8fa; border: 1px dashed #0969da; border-radius: 8px; padding: 16px; text-align: center; color: #57606a; font-size: 13px; }}
  @media (max-width: 600px) {{ .rtb-row {{ grid-template-columns: 1fr; }} .card-grid {{ grid-template-columns: 1fr 1fr; }} }}
</style>
</head>
<body>
<div class="page">

  <div class="header">
    <h1>☀️ AInchors Morning Stand-Up — Day {day_n}</h1>
    <div class="sub">{fmt_date(now_local.date())} · 8:00 AM MYT</div>
    <div class="meta">
      <span class="pill {header_pill}">{header_text}</span>
      <span class="pill pill-blue">💰 {escape(balance_str)}</span>
      <span class="pill pill-green">🛡️ Warden Active</span>
      <span class="pill pill-blue">📅 Day {day_n}</span>
      <span class="pill pill-{'amber' if composer_status == 'degraded' else 'green'}">✍️ {composer_status.upper()}</span>
    </div>
  </div>

  {f'<div class="alert-warn" style="border:2px solid #cf222e;background:#ffebe9;padding:14px;margin-bottom:16px;"><strong>⚠️ STAND-UP CONTENT COMPOSER DEGRADED</strong><br><span style="font-size:13px;">{escape(degraded_reason)}</span><br><span style="font-size:12px;color:#cf222e;">Sections 2, 5, 6, 7 contain placeholder text only — do not present as authoritative. Manual update required before sending.</span></div>' if composer_status == 'degraded' else ''}

  <div class="section">
    <h2>1 · System Health</h2>
    <div class="card-grid">
      <div class="card card-{'ok' if gateway_ok else 'warn'}">
        <div class="card-label">Gateway</div>
        <div class="card-value">{escape(overall.upper())}</div>
        <div class="card-sub">Last check {escape(last_check)}</div>
      </div>
      <div class="card card-{'ok' if backup_fresh else 'warn'}">
        <div class="card-label">Backup</div>
        <div class="card-value">{'🟢 Fresh' if backup_fresh else '🟡 Stale'}</div>
        <div class="card-sub">{escape(last_snap)}</div>
      </div>
      <div class="card card-{'ok' if mem_size < 15000 else 'warn'}">
        <div class="card-label">MEMORY.md</div>
        <div class="card-value">{mem_size:,} chars</div>
        <div class="card-sub">{escape(mem_status)}</div>
      </div>
      <div class="card card-info">
        <div class="card-label">Auto-Heal</div>
        <div class="card-value">🟢 Ran</div>
        <div class="card-sub">01:00 MYT today</div>
      </div>
    </div>
    <div class="card-grid">
      <div class="card card-{'warn' if budget.get('currentPct', 0) > 50 else 'ok'}">
        <div class="card-label">Ollama Budget</div>
        <div class="card-value">{escape(str(budget.get('requestsUsed', '?')))}
        /{escape(str(budget.get('requestsRemaining', '?')))}
        ({escape(str(budget.get('currentPct', '?')))}%)</div>
        <div class="card-sub">{escape(str(budget.get('requestsRemaining', '?')))} remaining · burn rate ~{escape(str(round(budget.get('requestsUsed', 0) / 24)))} req/hr</div>
        {f'<div class="alert-warn" style="margin-top:6px;font-size:11px;">⚠️ Budget alert level: {escape(str(budget.get("alertLevel", "")))}</div>' if budget.get('currentPct', 0) > 50 else ''}
      </div>
      <div class="card card-info">
        <div class="card-label">Gateway Latency</div>
        <div class="card-value">{escape(str(latency.get('overall', {}).get('avgMs', '?')))}ms</div>
        <div class="card-sub">peak {escape(str(latency.get('overall', {}).get('peakMs', '?')))}ms · {escape(str(latency.get('overall', {}).get('sampleCount', 0)))} samples</div>
      </div>
      <div class="card card-{'warn' if drift.get('lastStatus','').lower() != 'clean' else 'ok'}">
        <div class="card-label">Model Drift</div>
        <div class="card-value">{escape(drift.get('lastStatus', 'UNKNOWN').upper())}</div>
        <div class="card-sub">{escape(str(drift.get('totalViolationsFound', 0)))} violations · {escape(str(drift.get('consecutiveClean', 0)))} clean</div>
        {f'<div class="alert-warn" style="margin-top:6px;font-size:11px;">⚠️ Drift alerts: {escape(str(drift.get("totalViolationsFound", "")))}</div>' if drift.get('lastStatus','').lower() != 'clean' else ''}
      </div>
      <div class="card card-{'warn' if not cron_health.get('healthy', True) else 'ok'}">
        <div class="card-label">Cron Health</div>
        <div class="card-value">{'OK' if cron_health.get('healthy', True) else str(len(cron_health.get('failures', []))) + ' errors'}</div>
        <div class="card-sub">{'All crons healthy' if cron_health.get('healthy', True) else str(len(cron_health.get('failures', []))) + ' failures'}</div>
        {f'<div class="alert-warn" style="margin-top:6px;font-size:11px;">⚠️ Failures: {escape(str(cron_health.get("failures", [])))}</div>' if not cron_health.get('healthy', True) else ''}
      </div>
    </div>
    {f'<div class="alert-warn">ℹ️ {escape(note_health)}</div>' if note_health else ''}

    <div style="background:#f6f8fa;border:1px solid #d0d7de;border-radius:6px;padding:10px 14px;margin:8px 0;font-size:12px;color:#57606a;">
      <strong>Budget Trend:</strong> {escape(str(budget.get('currentPct', '?')))}% of Ollama daily quota used ({escape(str(budget.get('requestsUsed', 0)))}) of {escape(str(budget.get('requestsRemaining', 0) + budget.get('requestsUsed', 0)))} total. Burn rate ~{escape(str(round(budget.get('requestsUsed', 0) / 24)))} req/hr. Thresholds: warn {escape(str(budget.get('thresholds',{}).get('warn',{}).get('pct',50)))}% · alert {escape(str(budget.get('thresholds',{}).get('alert',{}).get('pct',70)))}% · critical {escape(str(budget.get('thresholds',{}).get('critical',{}).get('pct',85)))}%.
      Latency sample: {escape(str(latency.get('overall',{}).get('sampleCount',0)))} tasks over {escape(str(latency.get('windowDays',7)))}d — avg {escape(str(round(latency.get('overall',{}).get('avgMs',0)/1000,1)))}s, peak {escape(str(round(latency.get('overall',{}).get('peakMs',0)/1000,1)))}s.
    </div>

    <h3 style="margin-top:4px;margin-bottom:2px;">Latency by Model</h3>
    <table style="width:100%;border-collapse:collapse;font-size:11px;margin:4px 0;">
      <tr style="background:#f0f2f4;"><th style="padding:3px 6px;text-align:left;border:1px solid #d0d7de;">Model</th><th style="padding:3px 6px;text-align:right;border:1px solid #d0d7de;">Samples</th><th style="padding:3px 6px;text-align:right;border:1px solid #d0d7de;">p50</th><th style="padding:3px 6px;text-align:right;border:1px solid #d0d7de;">p95</th><th style="padding:3px 6px;text-align:right;border:1px solid #d0d7de;">Avg</th></tr>
{''.join(f'<tr><td style="padding:3px 6px;border:1px solid #d0d7de;">{escape(r["name"])}</td><td style="padding:3px 6px;text-align:right;border:1px solid #d0d7de;">{r["samples"]}</td><td style="padding:3px 6px;text-align:right;border:1px solid #d0d7de;">{r["p50"]}ms</td><td style="padding:3px 6px;text-align:right;border:1px solid #d0d7de;">{r["p95"]}ms</td><td style="padding:3px 6px;text-align:right;border:1px solid #d0d7de;">{r["avg"]}s</td></tr>' for r in latency_model_rows)}
    </table>

  <div class="section">
    <h2>2 · Business Stream (Angie / Aria)</h2>
    <div style="white-space: pre-wrap; font-size: 13px;">{escape(biz_stream) if biz_stream else 'ℹ️ Business stream summary not available from composer.'}</div>
  </div>

  <div class="section">
    <h2>3 · Governance</h2>

    <h3>CREST Compliance</h3>
    {crest_html}

    <h3>Framework Maturity (Top 5)</h3>
    {fw_html}

    <h3>Open Decisions</h3>
    {od_html}

    <h3>Draft Docs</h3>
    {dd_html}
  </div>

  <div class="section">
    <h2>4 · Auto-Heal (Yesterday — {fmt_date(yesterday_dt)}, 01:00 MYT)</h2>
    <div class="alert-info" style="margin-bottom:8px;font-size:12px;">
      <strong>Schedule:</strong> Daily 01:00 MYT · {escape(str(autoheal_current.get('checks_count',0)))} checks · Source: {escape(autoheal_current_source)}
    </div>
    <div>{autoheal_html}</div>
  </div>

  <div class="section">
    <h2>5 · Framework Maturity (Top 5)</h2>
    {fw_html}
    <div style="font-size:11px;color:#57606a;margin-top:6px;">Source: state/frameworks-maturity.json · Last assessed: {escape(fw_maturity_data.get("lastAssessed", "N/A"))} by {escape(fw_maturity_data.get("assessedBy", "unknown"))}</div>
  </div>

  <div class="section">
    <h2>6 · Progress (CHGs Since Last Stand-up)</h2>
    <div style="white-space: pre-wrap; font-size: 13px;">{escape(progress_block) if progress_block else 'No progress summary from composer.'}</div>

    <h3>Recent CHG Log</h3>
    {chg_html}

    <h3>Recent Journal Entries</h3>
    <ul>
{''.join(f'<li><strong>{escape(s["date"])}</strong> — {escape(s["title"])}</li>' for s in journal_snippets) if journal_snippets else '<li>No recent journal entries found (last 3 days).</li>'}
    </ul>
    <div style="font-size:11px;color:#57606a;margin-top:4px;">Source: memory/journal-*.md files from last 3 days</div>

    <h3>Sprint Summary</h3>
    <div style="background:#f6f8fa;border:1px solid #d0d7de;border-radius:6px;padding:10px 14px;font-size:12px;">
      <strong>{escape(sprint_data.get('name', 'Sprint 11'))}</strong> — {escape(sprint_data.get('dates', 'TBD'))} · Status: {escape(sprint_data.get('status', 'unknown'))}
    </div>
  </div>

  <div class="section">
    <h2>7 · RTB — Rose / Thorn / Bud</h2>
    <div class="rtb-row">
      <div class="rtb-card">
        <div class="rtb-icon">🌹</div>
        <div class="rtb-stream">Rose</div>
        <div class="rtb-text">{escape(rose_text) if rose_text else '[Composer degraded — no live composition available. Manual update needed.]'}</div>
      </div>
      <div class="rtb-card">
        <div class="rtb-icon">🌵</div>
        <div class="rtb-stream">Thorn</div>
        <div class="rtb-text">{escape(thorn_text) if thorn_text else '[Composer degraded — no live composition available. Manual update needed.]'}</div>
      </div>
    </div>
    <div class="rtb-row">
      <div class="rtb-card">
        <div class="rtb-icon">🌱</div>
        <div class="rtb-stream">Bud</div>
        <div class="rtb-text">{escape(bud_text) if bud_text else '[Composer degraded — no live composition available. Manual update needed.]'}</div>
      </div>
    </div>
  </div>

  <div class="section">
    <h2>8 · New Input Prompt</h2>
    <div class="new-input">
      <p>What's your focus for today, Ken?</p>
      {focus_html}
    </div>
  </div>

  <div class="section">
    <h2>9 · State Summary</h2>
    <div style="font-size:12px;color:#57606a;">
      <p><strong>Stand-up:</strong> Day {day_n} · Last generated {escape(state.get('lastStandupDate', 'N/A'))} · Email sent: {escape(state.get('emailSentAt', 'N/A'))}</p>
      <p><strong>MEMORY.md:</strong> {mem_size:,} chars · {escape(mem_status)}</p>
      <p><strong>Frameworks assessed:</strong> {escape(str(len(fw_maturity_data.get('frameworks', []))))} frameworks · Last: {escape(fw_maturity_data.get('lastAssessed', 'N/A'))}</p>
      <p><strong>Auto-heal checks:</strong> {escape(str(autoheal_current.get('checks_count',0)))} total · {escape(str(autoheal_current.get('issues_count',0)))} issues · {escape(str(autoheal_current.get('auto_fixed_count',0)))} auto-fixed · exit: {escape(autoheal_current.get('exit_status','unknown'))}</p>
    </div>
  </div>

  <div class="footer">
    AInchors Nexus Platform · Generated at {now_local.strftime('%H:%M MYT')} · Day {day_n}<br>
    Composer model: {escape(composer_model)} · {escape(source_footer)}<br>
    <span style="font-size:11px;opacity:0.7;">Sources: {escape(source_file_list)}</span>
  </div>

</div>
</body>
</html>
"""

print(html)

# ── Update standup-state.json via cron-write.sh ───────────────────────────────
state_update = json.dumps({"lastStandupDate": today_str, "dayNumber": day_n})
PYEOF

# ── PG-First Write Enforcement Gate (TKT-0976) ────────────────────────────────
# Check that Class 1 writer (state_standups) has a corresponding PG write
# before the JSON/derived write proceeds.
CHECK_SCRIPT="${WORKSPACE}/scripts/check-pg-first-write.sh"
if [[ -x "$CHECK_SCRIPT" ]]; then
  GATE_RESULT=$(bash "$CHECK_SCRIPT" --check-table state_standups 2>/dev/null || true)
  GATE_STATUS=$(echo "$GATE_RESULT" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('status','unknown'))" 2>/dev/null || echo "unknown")
  if [[ "$GATE_STATUS" == "violation" ]]; then
    echo "[standup] PG-FIRST WRITE GATE: VIOLATION — state_standups JSON write blocked" >&2
    echo "[standup] Gate verdict: $GATE_RESULT" >&2
    echo "[standup] Set PG_FIRST_BYPASS=1 or CLASS_OVERRIDE=state_standups to override" >&2
    exit 1
  fi
  echo "[standup] PG-FIRST WRITE GATE: $GATE_STATUS — proceeding" >&2
fi

# ── Update state/standup-state.json + PG primary write ────────────────────────
# PG is the primary write target; JSON is derived/dual-write until TKT-0359 gate
#
# Resolve psql binary + PG connection params on the BASH side using the same
# pattern as scripts/db.sh / scripts/db-raw.sh (TKT-0406 migration). The
# Python heredoc must NOT contain shell-expansion syntax (it is a literal
# Python string with 'PYEOF' quoted). These env vars are exported so the
# Python subprocess can read them via os.environ.
PSQL_BIN="${PSQL_BIN:-$(command -v psql 2>/dev/null || true)}"
if [[ -z "$PSQL_BIN" && -x "$(brew --prefix 2>/dev/null)/bin/psql" ]]; then
  PSQL_BIN="$(brew --prefix)/bin/psql"
fi
if [[ -z "$PSQL_BIN" ]]; then
  echo "[standup] PG write SKIPPED: psql not found in PATH or brew prefix" >&2
  PSQL_BIN=""
fi
export PSQL_BIN
export PGHOST="${PGHOST:-/tmp}"
export PGPORT="${PGPORT:-5432}"
export PGUSER="${PGUSER:-$(whoami)}"
export PGDATABASE="${PGDATABASE:-ainchors_nexus}"
export PGOPTIONS="${PGOPTIONS:---client-min-messages=warning}"

python3 << 'PYEOF'
import json, os, subprocess, sys
from pathlib import Path
from datetime import datetime, timezone, timedelta

WORKSPACE = Path(os.environ.get("WORKSPACE", "/Users/ainchorsoc2a/.openclaw/workspace"))
# Read psql binary + connection params from env (resolved in bash above).
# Falling back to None so subprocess.run([] + ...) raises a clean error if
# psql is missing, rather than a NameError on a literal PSQL list.
PSQL_BIN = os.environ.get("PSQL_BIN") or ""
PG_CONN = {
    "host": os.environ.get("PGHOST", "/tmp"),
    "port": os.environ.get("PGPORT", "5432"),
    "user": os.environ.get("PGUSER", ""),
    "dbname": os.environ.get("PGDATABASE", "ainchors_nexus"),
}

local_tz = timezone(timedelta(hours=8))
now_local = datetime.now(timezone.utc).astimezone(local_tz)
today_str = now_local.date().isoformat()
start = datetime(2026, 4, 25).date()
day_n = (now_local.date() - start).days + 1

# ── 1. Update JSON state file (dual-write, derived) ──
state_path = WORKSPACE / "state" / "standup-state.json"
state = {}
if state_path.exists():
    try:
        with open(state_path) as f:
            state = json.load(f)
    except Exception:
        pass
state["lastStandupDate"] = today_str
state["dayNumber"] = day_n
with open(state_path, "w") as f:
    json.dump(state, f, indent=2)

# ── 2. PG primary write: upsert operational columns ──
email_sent_at = "NULL"
email_sent_confirmed = "NULL"
if state.get("emailSentAt"):
    email_sent_at = f"'{state['emailSentAt']}'::timestamptz"
if state.get("emailSentConfirmed"):
    email_sent_confirmed = f"'{state['emailSentConfirmed']}'::date"

sql = f"""
INSERT INTO state_standups (standup_date, last_standup_date, day_number, email_sent_at, email_sent_confirmed, generated_by, standup_data)
VALUES (
  '{today_str}'::date,
  '{today_str}'::date,
  {day_n},
  {email_sent_at},
  {email_sent_confirmed},
  'yoda',
  '{{"generatedAt": "{now_local.isoformat()}", "dayNumber": {day_n}, "lastStandupDate": "{today_str}"}}'::jsonb
)
ON CONFLICT (standup_date) DO UPDATE SET
  last_standup_date = EXCLUDED.last_standup_date,
  day_number = EXCLUDED.day_number,
  email_sent_at = COALESCE(EXCLUDED.email_sent_at, state_standups.email_sent_at),
  email_sent_confirmed = COALESCE(EXCLUDED.email_sent_confirmed, state_standups.email_sent_confirmed),
  generated_by = EXCLUDED.generated_by,
  standup_data = EXCLUDED.standup_data,
  created_at = now();
"""

try:
    if not PSQL_BIN:
        print(f"[standup] PG write SKIPPED: psql binary not available (set PSQL_BIN)", file=sys.stderr)
    else:
        # Build argv from env (no shell, so no expansion). psycopg-style
        # connection params via -h/-p/-U/-d; password comes from .pgpass or env.
        pg_argv = [PSQL_BIN]
        if PG_CONN.get("host"):
            pg_argv += ["-h", PG_CONN["host"]]
        if PG_CONN.get("port"):
            pg_argv += ["-p", PG_CONN["port"]]
        if PG_CONN.get("user"):
            pg_argv += ["-U", PG_CONN["user"]]
        if PG_CONN.get("dbname"):
            pg_argv += ["-d", PG_CONN["dbname"]]
        pg_argv += ["-c", sql]
        result = subprocess.run(pg_argv, capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print(f"[standup] PG primary write: state_standups upserted for {today_str} (day {day_n})", file=sys.stderr)
        else:
            print(f"[standup] PG write WARNING: {result.stderr.strip()}", file=sys.stderr)
except Exception as e:
    print(f"[standup] PG write ERROR: {e}", file=sys.stderr)
PYEOF

echo "[standup] generated for $(TZ=Asia/Kuala_Lumpur date '+%Y-%m-%d %H:%M MYT')"

echo "[standup] generated for $(TZ=Asia/Kuala_Lumpur date '+%Y-%m-%d %H:%M MYT')"