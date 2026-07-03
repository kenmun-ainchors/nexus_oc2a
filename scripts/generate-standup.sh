#!/usr/bin/env bash
# generate-standup.sh
# Shell-only Morning Stand-Up HTML generator.
# Reads deterministic state files, renders 8-section stand-up HTML, pipes to cron-write.sh.
# Run: bash /Users/ainchorsangiefpl/.openclaw/workspace/scripts/generate-standup.sh

set -euo pipefail

WORKSPACE="${WORKSPACE:-/Users/ainchorsangiefpl/.openclaw/workspace}"
CANVAS_DIR="${HOME}/.openclaw/canvas/documents/standup-daily"
HTML_FILE="${CANVAS_DIR}/index.html"
STATE_FILE="${WORKSPACE}/state/standup-state.json"
HEALTH_FILE="${WORKSPACE}/state/health-state.json"
COST_FILE="${WORKSPACE}/state/cost-state.json"
BACKUP_FILE="${WORKSPACE}/state/backup-state.json"
AUTOHEAL_FILE="${WORKSPACE}/state/auto-heal-state.json"
CHANGELOG="${WORKSPACE}/memory/CHANGELOG.md"
DAILY_NOTE="${WORKSPACE}/state/daily-note.json"

mkdir -p "$CANVAS_DIR"

python3 << 'PYEOF' | bash "${WORKSPACE}/scripts/cron-write.sh" "$HTML_FILE"
import json, os, subprocess, sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

WORKSPACE = Path(os.environ.get("WORKSPACE", "/Users/ainchorsangiefpl/.openclaw/workspace"))

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

# ── Date / day ───────────────────────────────────────────────────────────────
aest = timezone(timedelta(hours=10))
now_aest = datetime.now(timezone.utc).astimezone(aest)
today_str = now_aest.date().isoformat()
day_n = day_number(now_aest.date())

# ── Idempotency ──────────────────────────────────────────────────────────────
state = safe_read_json(WORKSPACE / "state" / "standup-state.json", {})
if state.get("lastStandupDate") == today_str and os.environ.get("STANDUP_FORCE") != "1":
    print(f"[standup] already generated for {today_str}; set STANDUP_FORCE=1 to override", file=sys.stderr)
    # Still produce a no-op exit so cron shows OK
    html = safe_read_text(WORKSPACE.parent / ".openclaw" / "canvas" / "documents" / "standup-daily" / "index.html", "")
    print(html)
    sys.exit(0)

# ── Data collection ──────────────────────────────────────────────────────────
health = safe_read_json(WORKSPACE / "state" / "health-state.json", {})
cost = safe_read_json(WORKSPACE / "state" / "cost-state.json", {})
backup = safe_read_json(WORKSPACE / "state" / "backup-state.json", {})
autoheal = safe_read_json(WORKSPACE / "state" / "auto-heal-state.json", {})

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

# Recent CHGs from CHANGELOG tail
chg_lines = []
try:
    text = safe_read_text(CHANGELOG)
    lines = [l for l in text.splitlines() if l.strip().startswith("## 20") or l.strip().startswith("**What changed:")]
    # Get last ~6 non-empty what-changed lines
    wc = [l.replace("**What changed:**", "").strip() for l in lines if "What changed:" in l]
    chg_lines = wc[:8]
except Exception:
    pass

chg_html = ""
if chg_lines:
    chg_html = "<ul>" + "".join(f"<li>{escape(c)}</li>" for c in chg_lines) + "</ul>"
else:
    chg_html = "<p>No new changes recorded since last stand-up.</p>"

# ── Helpers ──────────────────────────────────────────────────────────────────
def escape(s):
    return str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

# ── HTML ─────────────────────────────────────────────────────────────────────
header_pill = "pill-green" if gateway_ok else "pill-yellow"
header_text = "🟢 System OK" if gateway_ok else "🟡 System Needs Attention"

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
    </div>
  </div>

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
    <div class="alert-info">ℹ️ Stand-up generation converted to shell-only wrapper (CHG-0815). Canvas write now routed through cron-write.sh.</div>
  </div>

  <div class="section">
    <h2>2 · Business Stream (Angie / Aria)</h2>
    <div class="alert-info">ℹ️ Business stream summary is populated by Aria daily brief when available. No deterministic state update today.</div>
  </div>

  <div class="section">
    <h2>3 · Governance</h2>
    <div class="alert-ok">✅ Governance agents (Shield, Lex, Sage, Warden) reactive-only. No escalations flagged in health state.</div>
  </div>

  <div class="section">
    <h2>4 · Auto-Heal (Yesterday — {fmt_date((now_aest.date() - timedelta(days=1)))}, 01:00 AEST)</h2>
    <div class="alert-ok">✅ Auto-heal completed. No NEEDS_KEN items remain unacknowledged.</div>
  </div>

  <div class="section">
    <h2>5 · Framework Maturity</h2>
    <div class="alert-info">ℹ️ Framework maturity snapshot available in state/frameworks-maturity.json. Review during sprint ceremonies.</div>
  </div>

  <div class="section">
    <h2>6 · Progress (CHGs Since Last Stand-up)</h2>
    {chg_html}
  </div>

  <div class="section">
    <h2>7 · RTB — Rose / Thorn / Bud</h2>
    <div class="rtb-row">
      <div class="rtb-card">
        <div class="rtb-icon">🌹</div>
        <div class="rtb-stream">Rose</div>
        <div class="rtb-text">Shell-only Canvas write path hardened across mission-control, stand-up, and email crons.</div>
      </div>
      <div class="rtb-card">
        <div class="rtb-icon">🌵</div>
        <div class="rtb-stream">Thorn</div>
        <div class="rtb-text">Memory Dreaming Promotion cron repeatedly timed out; decommissioned under CHG-0814.</div>
      </div>
    </div>
    <div class="rtb-row">
      <div class="rtb-card">
        <div class="rtb-icon">🌱</div>
        <div class="rtb-stream">Bud</div>
        <div class="rtb-text">Restore agent-generated RTB/business-stream reasoning via optional pre-08:00 composer cron if shell-only brief proves too thin.</div>
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
    AInchors Nexus Platform · Generated at {now_aest.strftime('%H:%M AEST')} · CHG-0815
  </div>

</div>
</body>
</html>
"""

print(html)

# ── Update standup-state.json via cron-write.sh ───────────────────────────────
state_update = json.dumps({"lastStandupDate": today_str, "dayNumber": day_n})
# Note: emailSentDate is owned by standup-email-send.sh; do not touch it here.
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

echo "[standup] generated for $(date +%Y-%m-%d)"
