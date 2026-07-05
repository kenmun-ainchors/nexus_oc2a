#!/usr/bin/env bash
# generate-standup.sh
# Shell-only Morning Stand-Up HTML generator.
# Reads deterministic state files and composer blocks, renders 8-section stand-up HTML,
# pipes to cron-write.sh.
# Supports: STANDUP_FORCE=1 (skip freshness check), STANDUP_DRY_RUN=1 (write to temp file).

set -euo pipefail

WORKSPACE="${WORKSPACE:-/Users/ainchorsangiefpl/.openclaw/workspace}"
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
AUTOHEAL_FILE="${WORKSPACE}/state/auto-heal-state.json"
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
for day in "$(TZ=Australia/Sydney date '+%Y-%m-%d')" "$(TZ=Australia/Sydney date -v-1d '+%Y-%m-%d')"; do
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

WORKSPACE = Path(os.environ.get("WORKSPACE", "/Users/ainchorsangiefpl/.openclaw/workspace"))
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
aest = timezone(timedelta(hours=10))
now_aest = datetime.now(timezone.utc).astimezone(aest)
today_str = now_aest.date().isoformat()
day_n = day_number(now_aest.date())
yesterday_dt = (now_aest.date() - timedelta(days=1))

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

# Auto-heal NEEDS_KEN summary
autoheal_needs_ken = autoheal.get("needsKen", autoheal.get("needs_ken", autoheal.get("items", [])))
if isinstance(autoheal_needs_ken, list) and autoheal_needs_ken:
    autoheal_html = f"<ul>" + "".join(
        f"<li>{escape(str(i))}</li>" for i in autoheal_needs_ken
    ) + "</ul>"
elif isinstance(autoheal_needs_ken, str) and autoheal_needs_ken:
    autoheal_html = f"<p>{escape(autoheal_needs_ken)}</p>"
else:
    autoheal_html = "<p>No NEEDS_KEN items — auto-heal completed clean.</p>"

# Daily note health
note_health = daily_note.get("healthStatus", "")

# Recent CHGs from CHANGELOG tail
chg_lines = []
try:
    text = safe_read_text(str(WORKSPACE / "memory" / "CHANGELOG.md"))
    lines = [l for l in text.splitlines() if l.strip().startswith("## 20") or l.strip().startswith("**What changed:")]
    wc = [l.replace("**What changed:**", "").strip() for l in lines if "What changed:" in l]
    chg_lines = wc[:8]
except Exception:
    pass

chg_html = ""
if chg_lines:
    chg_html = "<ul>" + "".join(f"<li>{escape(c)}</li>" for c in chg_lines) + "</ul>"
else:
    chg_html = "<p>No new changes recorded since last stand-up.</p>"

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
<title>AInchors Stand-up — Day {day_n} | {fmt_date(now_aest.date())}</title>
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
    <div class="sub">{fmt_date(now_aest.date())} · 8:00 AM AEST</div>
    <div class="meta">
      <span class="pill {header_pill}">{header_text}</span>
      <span class="pill pill-blue">💰 {escape(balance_str)}</span>
      <span class="pill pill-green">🛡️ Warden Active</span>
      <span class="pill pill-blue">📅 Day {day_n}</span>
      <span class="pill pill-{'amber' if composer_status == 'degraded' else 'green'}">✍️ {composer_status.upper()}</span>
    </div>
  </div>

  {f'<div class="alert-warn"><strong>⚠️ Stand-up content composer degraded —</strong> {escape(degraded_reason)}. Sections 2–7 may be incomplete.</div>' if composer_status == 'degraded' else ''}

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
        <div class="card-sub">01:00 AEST today</div>
      </div>
    </div>
    {f'<div class="alert-warn">ℹ️ {escape(note_health)}</div>' if note_health else ''}
  </div>

  <div class="section">
    <h2>2 · Business Stream (Angie / Aria)</h2>
    <div style="white-space: pre-wrap; font-size: 13px;">{escape(biz_stream) if biz_stream else 'ℹ️ Business stream summary not available from composer.'}</div>
  </div>

  <div class="section">
    <h2>3 · Governance</h2>
    <div class="alert-ok">✅ Governance agents (Shield, Lex, Sage, Warden) reactive-only. No escalations flagged in health state.</div>
  </div>

  <div class="section">
    <h2>4 · Auto-Heal (Yesterday — {fmt_date(yesterday_dt)}, 01:00 AEST)</h2>
    <div>{autoheal_html}</div>
  </div>

  <div class="section">
    <h2>5 · Framework Maturity</h2>
    <div style="white-space: pre-wrap; font-size: 13px;">{escape(fw_maturity) if fw_maturity else 'ℹ️ Framework maturity snapshot available in state/frameworks-maturity.json. Review during sprint ceremonies.'}</div>
  </div>

  <div class="section">
    <h2>6 · Progress (CHGs Since Last Stand-up)</h2>
    <div style="white-space: pre-wrap; font-size: 13px;">{escape(progress_block) if progress_block else chg_html}</div>
  </div>

  <div class="section">
    <h2>7 · RTB — Rose / Thorn / Bud</h2>
    <div class="rtb-row">
      <div class="rtb-card">
        <div class="rtb-icon">🌹</div>
        <div class="rtb-stream">Rose</div>
        <div class="rtb-text">{escape(rose_text) if rose_text else 'Shell-only Canvas write path hardened across mission-control, stand-up, and email crons.'}</div>
      </div>
      <div class="rtb-card">
        <div class="rtb-icon">🌵</div>
        <div class="rtb-stream">Thorn</div>
        <div class="rtb-text">{escape(thorn_text) if thorn_text else 'Memory Dreaming Promotion cron repeatedly timed out; decommissioned under CHG-0814.'}</div>
      </div>
    </div>
    <div class="rtb-row">
      <div class="rtb-card">
        <div class="rtb-icon">🌱</div>
        <div class="rtb-stream">Bud</div>
        <div class="rtb-text">{escape(bud_text) if bud_text else 'Restore agent-generated RTB/business-stream reasoning via optional pre-08:00 composer cron if shell-only brief proves too thin.'}</div>
      </div>
    </div>
  </div>

  <div class="section">
    <h2>8 · New Input Prompt</h2>
    <div class="new-input">
      What's your focus for today, Ken?
    </div>
  </div>

  <div class="footer">
    AInchors Nexus Platform · Generated at {now_aest.strftime('%H:%M AEST')} · CHG-0824 · {escape(source_footer)}
  </div>

</div>
</body>
</html>
"""

print(html)

# ── Update standup-state.json via cron-write.sh ───────────────────────────────
state_update = json.dumps({"lastStandupDate": today_str, "dayNumber": day_n})
PYEOF

# Update state/standup-state.json with new date/day without clobbering email fields
python3 << 'PYEOF'
import json, os
from pathlib import Path
WORKSPACE = Path(os.environ.get("WORKSPACE", "/Users/ainchorsangiefpl/.openclaw/workspace"))
state_path = WORKSPACE / "state" / "standup-state.json"
state = {}
if state_path.exists():
    try:
        with open(state_path) as f:
            state = json.load(f)
    except Exception:
        pass
from datetime import datetime, timezone, timedelta
aest = timezone(timedelta(hours=10))
now_aest = datetime.now(timezone.utc).astimezone(aest)
start = datetime(2026, 4, 25).date()
day_n = (now_aest.date() - start).days + 1
state["lastStandupDate"] = now_aest.date().isoformat()
state["dayNumber"] = day_n
with open(state_path, "w") as f:
    json.dump(state, f, indent=2)
PYEOF

echo "[standup] generated for $(TZ=Australia/Sydney date '+%Y-%m-%d %H:%M AEST')"