#!/usr/bin/env bash
# generate-mission-control.sh
# AInchors Mission Control Dashboard Generator
# Queries Notion, reads state files, writes data.json + index.html
# Run: bash ~/.openclaw/workspace/scripts/generate-mission-control.sh

set -euo pipefail

WORKSPACE="$HOME/.openclaw/workspace"
CANVAS_DIR="$HOME/.openclaw/canvas/documents/mission-control"
NOTION_KEY_FILE="$HOME/.config/notion/api_key"
DATA_FILE="$CANVAS_DIR/data.json"
HTML_FILE="$CANVAS_DIR/index.html"
CHANGELOG="$WORKSPACE/memory/CHANGELOG.md"
TASKS_DB="26de9c3ba4604b6eb3e2408fc8993c10"
BACKLOG_DB="34dc182953ff814b8257d3a3bf351d44"

mkdir -p "$CANVAS_DIR"

# ── Run obs-trend widget (produces state/obs-trend.json) ─────────────────────
if [[ -f "$WORKSPACE/scripts/obs-trend.sh" ]]; then
  bash "$WORKSPACE/scripts/obs-trend.sh" || echo "[warn] obs-trend.sh failed — continuing" >&2
fi

# ── Read NOTION_KEY ──────────────────────────────────────────────────────────
if [[ -f "$NOTION_KEY_FILE" ]]; then
  NOTION_KEY=$(cat "$NOTION_KEY_FILE")
else
  NOTION_KEY=""
fi
export NOTION_KEY WORKSPACE CANVAS_DIR DATA_FILE HTML_FILE CHANGELOG TASKS_DB BACKLOG_DB

# ── Main generation (Python) → stdout → cron-write.sh for HTML ────────────────
python3 << 'PYEOF' | bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/cron-write.sh "$HTML_FILE"
import os, json, sys, subprocess
from datetime import datetime, timezone, timedelta
from pathlib import Path
import urllib.request
import urllib.error

WORKSPACE   = Path(os.environ["WORKSPACE"])
CANVAS_DIR  = Path(os.environ["CANVAS_DIR"])
DATA_FILE   = Path(os.environ["DATA_FILE"])
HTML_FILE   = Path(os.environ["HTML_FILE"])
CHANGELOG   = Path(os.environ["CHANGELOG"])
NOTION_KEY  = os.environ.get("NOTION_KEY", "")
TASKS_DB    = os.environ["TASKS_DB"]
BACKLOG_DB  = os.environ["BACKLOG_DB"]

NOW_UTC = datetime.now(timezone.utc)
TODAY   = NOW_UTC.date().isoformat()
AEST    = timezone(timedelta(hours=10))
NOW_AEST = NOW_UTC.astimezone(AEST)

# ── Helpers ──────────────────────────────────────────────────────────────────

def safe_read_json(path, default=None):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return default if default is not None else {}

def notion_query(db_id, payload=None):
    """Query a Notion DB. Returns list of results or []."""
    if not NOTION_KEY:
        return []
    url = f"https://api.notion.com/v1/databases/{db_id}/query"
    body = json.dumps(payload or {"page_size": 100}).encode()
    req = urllib.request.Request(url, data=body, method="POST", headers={
        "Authorization": f"Bearer {NOTION_KEY}",
        "Notion-Version": "2022-06-28",
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.load(resp).get("results", [])
    except Exception as e:
        print(f"[warn] Notion query {db_id}: {e}", file=sys.stderr)
        return []

def prop_text(p, key):
    """Get plain text from a Notion property."""
    try:
        v = p[key]
        t = v.get("type", "")
        if t == "title":
            return "".join(x["text"]["content"] for x in v["title"])
        if t == "rich_text":
            return "".join(x["text"]["content"] for x in v["rich_text"])
        if t == "select":
            return (v["select"] or {}).get("name", "")
        if t == "date":
            return (v["date"] or {}).get("start", "")
    except Exception:
        pass
    return ""

def prop_select(p, key):
    try:
        return (p[key]["select"] or {}).get("name", "")
    except Exception:
        return ""

# ── 1. Gateway health ────────────────────────────────────────────────────────
health = safe_read_json(WORKSPACE / "state" / "health-state.json")
gateway_status = health.get("overallStatus", health.get("status", "unknown"))
gateway_uptime = health.get("lastOk", "")

# ── 2. Balance ───────────────────────────────────────────────────────────────
cost  = safe_read_json(WORKSPACE / "state" / "cost-state.json")
cost_alert = safe_read_json(WORKSPACE / "state" / "cost-alert-state.json")
# Prefer cost-alert-state confirmedBalance (live, set by Ken) over apiBalance.remainingEstimate (stale formula)
balance_amount_raw = (
    cost_alert.get("currentBalance") or
    cost_alert.get("balance") or
    cost.get("confirmedBalance") or
    cost.get("apiBalance", {}).get("remainingEstimate", 0.0)
)
try:
    balance_amount = float(balance_amount_raw)
except (ValueError, TypeError):
    balance_amount = 0.0
# Determine tier
if balance_amount > 50:
    balance_tier = 3  # green
elif balance_amount >= 25:
    balance_tier = 2  # amber
else:
    balance_tier = 1  # red

# ── 3. Async tasks → active agent detection ───────────────────────────────────
async_tasks = safe_read_json(WORKSPACE / "state" / "async-tasks.json", {})
active_agent_ids = set()
active_task_map = {}  # agent → task title
all_tasks_raw = {**async_tasks.get("activeTasks", {}), **async_tasks.get("completedTasks", {})}
for tid, task in all_tasks_raw.items():
    if task.get("status") == "running":
        agent = task.get("agent", "")
        goal  = task.get("goal", "")
        active_agent_ids.add(agent)
        # Map known agent IDs
        for known in ["yoda", "aria", "shield", "lex", "sage"]:
            if known in agent.lower():
                active_task_map[known] = goal[:80]

# ── 4. Notion — Tasks DB (open + in-progress + done) ─────────────────────────
task_rows = notion_query(TASKS_DB)

def bucket_tasks(rows, stream_filter=None):
    backlog, wip, done = [], [], []
    for r in rows:
        p = r["properties"]
        name     = prop_text(p, "Name")
        status   = prop_select(p, "Status")
        stream   = prop_select(p, "Stream")
        priority = prop_select(p, "Priority")
        if not name:
            continue
        if stream_filter and stream_filter.lower() not in (stream or "").lower():
            continue
        item = {"id": r["id"][:8], "title": name[:60], "priority": priority, "status": status}
        sl = status.lower()
        if "done" in sl or "complete" in sl:
            done.append(item)
        elif "progress" in sl or "wip" in sl or "doing" in sl:
            wip.append(item)
        else:
            backlog.append(item)
    return backlog[:10], wip[:10], done[:10]

tech_backlog, tech_wip, tech_done = bucket_tasks(task_rows, "technical")
biz_backlog,  biz_wip,  biz_done  = bucket_tasks(task_rows, "business")

# ── 5. Notion — Backlog DB (US) ───────────────────────────────────────────────
us_rows = notion_query(BACKLOG_DB)

def bucket_us(rows, stream_filter=None):
    backlog, wip, done = [], [], []
    for r in rows:
        p = r["properties"]
        title    = prop_text(p, "US Title")
        status   = prop_select(p, "Status")
        stream   = prop_select(p, "Stream")
        priority = prop_select(p, "Priority")
        if not title:
            continue
        # Stream filter — allow cross-stream or matching
        if stream_filter:
            sl_stream = (stream or "").lower()
            if stream_filter.lower() not in sl_stream and "cross" not in sl_stream:
                continue
        item = {"id": r["id"][:8], "title": title[:60], "priority": priority, "status": status}
        sl = (status or "").lower()
        if "done" in sl or "complete" in sl:
            done.append(item)
        elif "progress" in sl or "wip" in sl or "sprint" in sl:
            wip.append(item)
        else:
            backlog.append(item)
    return backlog[:10], wip[:10], done[:10]

tech_us_backlog, tech_us_wip, tech_us_done = bucket_us(us_rows, "technical")
biz_us_backlog,  biz_us_wip,  biz_us_done  = bucket_us(us_rows, "business")

# Merge task rows + US rows for richer data
def merge_buckets(t_bl, t_wip, t_done, u_bl, u_wip, u_done):
    def dedup(lst):
        seen = set()
        out = []
        for x in lst:
            k = x["title"]
            if k not in seen:
                seen.add(k)
                out.append(x)
        return out
    return (dedup(t_bl + u_bl)[:10],
            dedup(t_wip + u_wip)[:10],
            dedup(t_done + u_done)[:10])

tech_bl, tech_wi, tech_dn = merge_buckets(tech_backlog, tech_wip, tech_done, tech_us_backlog, tech_us_wip, tech_us_done)
biz_bl,  biz_wi,  biz_dn  = merge_buckets(biz_backlog,  biz_wip,  biz_done,  biz_us_backlog,  biz_us_wip,  biz_us_done)

# ── 6. Governance review logs ─────────────────────────────────────────────────
def read_gov_log(agent_name):
    base = Path.home() / f".openclaw/workspace-{agent_name}" / "state"
    log_file = base / f"{agent_name}-review-log.json"
    # Shield uses "shield", Lex uses "lex", Sage uses "sage"
    data = safe_read_json(log_file, {"reviews": []})
    reviews = data.get("reviews", [])
    today_reviews = [r for r in reviews if (r.get("reviewedAt") or "").startswith(TODAY)]
    counts = {"pending": 0, "clear": 0, "conditional": 0, "block": 0}
    for r in today_reviews:
        v = (r.get("verdict") or "").lower()
        if "clear" in v or "approve" in v or "ok" in v:
            counts["clear"] += 1
        elif "conditional" in v or "warn" in v:
            counts["conditional"] += 1
        elif "block" in v or "reject" in v or "deny" in v:
            counts["block"] += 1
        else:
            counts["pending"] += 1
    last_verdict = ""
    if reviews:
        last = reviews[-1]
        last_verdict = f"{last.get('verdict','?')} — {last.get('description','')[:60]}"
    return {**counts, "lastVerdict": last_verdict, "totalToday": len(today_reviews)}

gov = {
    "shield": read_gov_log("security"),
    "lex":    read_gov_log("legal"),
    "sage":   read_gov_log("qa"),
}

# ── 7. Recent activity from CHANGELOG ────────────────────────────────────────
recent_activity = []
if CHANGELOG.exists():
    try:
        with open(CHANGELOG) as f:
            for line in f:
                line = line.strip()
                if line.startswith("## ") and "[CHG-" in line:
                    # Format: ## 2026-04-27 22:48 AEST — [CHG-0041] Title
                    parts = line[3:].split(" — ", 1)
                    if len(parts) == 2:
                        ts_raw = parts[0].strip()
                        desc   = parts[1].strip()
                        # Extract HH:MM
                        ts_parts = ts_raw.split()
                        time_str = ts_parts[1] if len(ts_parts) >= 2 else ts_raw
                        recent_activity.append({"time": time_str, "description": desc})
    except Exception:
        pass

recent_activity = [
    a for a in recent_activity
    if "One-line title" not in a["description"]
    and "CHG-NNNN" not in a["description"]
    and "HH:MM" not in a.get("time", "")
][:10]

# ── 8. Agent status ───────────────────────────────────────────────────────────
def agent_status(agent_id):
    for key in active_agent_ids:
        if agent_id in key.lower() or key.lower() in agent_id:
            return "active"
    return "idle"

def agent_current_task(agent_id):
    for key, task in active_task_map.items():
        if agent_id in key.lower() or key.lower() in agent_id:
            return task
    return None

# ── 9. Build data.json ────────────────────────────────────────────────────────
agents = [
    {
        "id": "main",
        "name": "Yoda",
        "emoji": "🟢",
        "stream": "technical",
        "model": "Sonnet",
        "status": agent_status("yoda") if agent_status("yoda") != "idle" else ("active" if any("yoda" in k or "main" in k for k in active_agent_ids) else "idle"),
        "currentTask": agent_current_task("yoda"),
        "backlog": tech_bl,
        "wip": tech_wi,
        "done": tech_dn,
    },
    {
        "id": "business",
        "name": "Aria",
        "emoji": "🔵",
        "stream": "business",
        "model": "Sonnet",
        "status": agent_status("aria"),
        "currentTask": agent_current_task("aria"),
        "backlog": biz_bl,
        "wip": biz_wi,
        "done": biz_dn,
    },
]

# ── 8b. Daily note / tip ─────────────────────────────────────────────────────
daily_note = safe_read_json(WORKSPACE / "state" / "daily-note.json", {})
tip_text  = daily_note.get("tip", None)
tip_date  = daily_note.get("date", None)
TODAY_AEST = NOW_AEST.date().isoformat()
# Only show tip if it's from today (AEST)
if tip_date != TODAY_AEST:
    tip_text = None

# ── 8c. Obs Error Trend widget ───────────────────────────────────────────────
obs_trend = safe_read_json(WORKSPACE / "state" / "obs-trend.json", None)

# ── 8d. Cron Health (TKT-0340) ────────────────────────────────────────────────
cron_baseline = safe_read_json(WORKSPACE / "state" / "cron-timeout-baseline.json", {})
crons_raw = cron_baseline.get("crons", [])
cron_summary = cron_baseline.get("summary", {})

# Compute cron health counts
cron_total = len(crons_raw)
cron_healthy = 0
cron_degraded = 0
cron_failed = 0
for c in crons_raw:
    status = (c.get("lastStatus") or "unknown").lower()
    if status == "ok":
        cron_healthy += 1
    elif status in ("error", "failure", "timeout"):
        cron_failed += 1
    elif status in ("warn", "deviated"):
        cron_degraded += 1
    else:
        # unknown or other status → neutral (count as degraded for visibility)
        cron_degraded += 1

data = {
    "generatedAt": NOW_UTC.isoformat(),
    "generatedAtAEST": NOW_AEST.strftime("%Y-%m-%d %H:%M AEST"),
    "gateway": {
        "status": gateway_status,
        "lastOk": gateway_uptime,
    },
    "balance": {
        "amount": float(balance_amount),
        "tier": balance_tier,
    },
    "agents": agents,
    "governance": gov,
    "recentActivity": recent_activity,
    "tip": tip_text,
    "obsTrend": obs_trend,
    "cronHealth": {
        "total": cron_total,
        "healthy": cron_healthy,
        "degraded": cron_degraded,
        "failed": cron_failed,
        "crons": crons_raw,
        "summary": cron_summary,
    },
}

with open(DATA_FILE, "w") as f:
    json.dump(data, f, indent=2)

print(f"[ok] data.json written ({DATA_FILE})")

# ── 10. Generate index.html ───────────────────────────────────────────────────
def esc(s):
    return str(s).replace("&","&amp;").replace("<","&lt;").replace(">","&gt;").replace('"',"&quot;")

def balance_html(amount, tier):
    if tier == 3:
        colour = "#48bb78"; icon = "✅"
    elif tier == 2:
        colour = "#ecc94b"; icon = "⚠️"
    else:
        colour = "#fc8181"; icon = "🚨"
    return f'<span style="color:{colour}">{icon} ${amount:.2f}</span>'

def gateway_html(status):
    if status == "ok":
        return '<span style="color:#48bb78">✅ OK</span>'
    return f'<span style="color:#fc8181">⚠️ {esc(status)}</span>'

def status_dot_html(status):
    if status == "active":
        return '<span class="dot dot-active">●</span>'
    elif status == "error":
        return '<span class="dot dot-error">●</span>'
    return '<span class="dot dot-idle">●</span>'

def task_list_html(items, empty_msg="—"):
    if not items:
        return f'<div class="task-empty">{empty_msg}</div>'
    rows = []
    for item in items:
        pri = item.get("priority","")
        pri_badge = ""
        if pri:
            pri_colour = "#fc8181" if pri.lower() in ("high","critical") else ("#ecc94b" if pri.lower()=="medium" else "#718096")
            pri_badge = f'<span class="badge" style="background:{pri_colour}22;color:{pri_colour}">{esc(pri)}</span>'
        rows.append(f'<div class="task-item"><span class="task-dot">•</span> {esc(item["title"][:55])} {pri_badge}</div>')
    return "\n".join(rows)

def agent_card_html(agent, accent):
    status   = agent["status"]
    border   = "border-color:#fc8181" if status == "error" else ""
    cur_task = agent.get("currentTask")
    cur_html = ""
    if cur_task:
        cur_html = f'<div class="current-task">⚡ {esc(cur_task[:70])}</div>'
    backlog_count = len(agent["backlog"])
    wip_count     = len(agent["wip"])
    done_count    = len(agent["done"])
    return f"""
    <div class="agent-card" style="{border}">
      <div class="agent-header">
        <span class="agent-emoji">{agent['emoji']}</span>
        <span class="agent-name" style="color:{accent}">{esc(agent['name'])}</span>
        {status_dot_html(status)}
        <span class="agent-status-label">{status.upper()}</span>
        <span class="agent-model">{esc(agent['model'])}</span>
      </div>
      {cur_html}
      <div class="task-section">
        <div class="task-section-header">📋 Backlog <span class="count-badge">{backlog_count}</span></div>
        {task_list_html(agent['backlog'], 'No backlog items')}
      </div>
      <div class="task-section">
        <div class="task-section-header">🔄 WIP <span class="count-badge">{wip_count}</span></div>
        {task_list_html(agent['wip'], 'Nothing in progress')}
      </div>
      <div class="task-section">
        <div class="task-section-header">✅ Done today <span class="count-badge">{done_count}</span></div>
        {task_list_html(agent['done'], 'Nothing done yet today')}
      </div>
    </div>"""

def gov_card_html(name, emoji, label, counts):
    total = counts.get("totalToday", 0)
    blocks = counts.get("block", 0)
    conds  = counts.get("conditional", 0)
    clears = counts.get("clear", 0)
    if blocks > 0:
        card_colour = "#fc8181"
    elif conds > 0:
        card_colour = "#ecc94b"
    elif total > 0:
        card_colour = "#48bb78"
    else:
        card_colour = "#4a5568"
    last = esc(counts.get("lastVerdict","No reviews today")[:80])
    return f"""
    <div class="gov-card" onclick="this.classList.toggle('expanded')" title="Click to expand">
      <div class="gov-header" style="color:{card_colour}">
        {emoji} <strong>{total}</strong>
      </div>
      <div class="gov-label">{esc(label)}</div>
      <div class="gov-detail">
        <span style="color:#48bb78">✅{clears}</span>
        <span style="color:#ecc94b">⚠️{conds}</span>
        <span style="color:#fc8181">🚫{blocks}</span>
      </div>
      <div class="gov-verdict">{last}</div>
    </div>"""

def activity_html(items):
    if not items:
        return '<div class="task-empty">No recent activity</div>'
    rows = []
    for item in items:
        rows.append(f'<div class="activity-item"><span class="activity-time">{esc(item["time"])}</span> {esc(item["description"])}</div>')
    return "\n".join(rows)

# ── Obs Error Trend widget HTML ─────────────────────────────────────────────
def obs_trend_section_html(obs_trend):
    if not obs_trend or obs_trend.get("error"):
        return ""
    totals    = obs_trend.get("totals", {})
    errors    = totals.get("ERROR", 0)
    warns     = totals.get("WARN",  0)
    info      = totals.get("INFO",  0)
    trend     = obs_trend.get("trend", {})
    worst     = obs_trend.get("worst_hour")
    top_errs  = obs_trend.get("top_errors",   [])
    top_wrns  = obs_trend.get("top_warnings", [])
    gen_at    = obs_trend.get("generated_at_aest", "")

    def trend_arrow(pct):
        if pct is None:
            return ""
        if pct > 10:
            return f'<span style="color:#fc8181">&#8593;{abs(pct):.0f}%</span>'
        elif pct < -10:
            return f'<span style="color:#48bb78">&#8595;{abs(pct):.0f}%</span>'
        else:
            return f'<span style="color:#718096">&#8594;{abs(pct):.0f}%</span>'

    err_arrow  = trend_arrow(trend.get("errors_pct_change"))
    warn_arrow = trend_arrow(trend.get("warns_pct_change"))
    err_colour  = "#fc8181" if errors > 0 else "#48bb78"
    warn_colour = "#ecc94b" if warns  > 0 else "#718096"

    def type_bars(items, colour):
        if not items:
            return '<div class="task-empty">\u2014</div>'
        max_cnt = items[0]["count"] if items else 1
        rows = []
        for item in items:
            bar_pct = int(item["count"] / max(max_cnt, 1) * 100)
            rows.append(
                f'<div class="obs-bar-row">'
                f'<span class="obs-bar-label">{esc(item["type"])}</span>'
                f'<div class="obs-bar-track"><div class="obs-bar-fill" style="width:{bar_pct}%;background:{colour}"></div></div>'
                f'<span class="obs-bar-count">{item["count"]}</span>'
                f'</div>'
            )
        return "\n".join(rows)

    worst_html = ""
    if worst:
        worst_html = f'<div class="obs-worst">&#128336; Worst hour: <strong>{esc(worst["hour"])}</strong> &mdash; {worst["cnt"]} errors</div>'

    has_prev = trend.get("has_prev_data", False)
    trend_note = ""
    if has_prev:
        trend_note = f'<span class="obs-trend-note">vs prev 24h: errors&nbsp;{err_arrow}&nbsp;&nbsp;warns&nbsp;{warn_arrow}</span>'

    return f"""
    <div class="obs-trend-section">
      <div class="obs-header">
        <span class="obs-title">&#128225; Obs Error Trend</span>
        <span class="obs-period">Last 24h</span>
        <span class="obs-totals">
          <span style="color:{err_colour}">&#10060; {errors} errors</span>
          <span style="color:{warn_colour}">&#9888;&#65039; {warns} warns</span>
          <span style="color:#718096">&#8505;&#65039; {info} info</span>
        </span>
        {trend_note}
        <span class="obs-gentime">{esc(gen_at)}</span>
      </div>
      {worst_html}
      <div class="obs-cols">
        <div class="obs-col">
          <div class="obs-col-title" style="color:#fc8181">Top Errors</div>
          {type_bars(top_errs, "#fc8181")}
        </div>
        <div class="obs-col">
          <div class="obs-col-title" style="color:#ecc94b">Top Warnings</div>
          {type_bars(top_wrns, "#ecc94b")}
        </div>
      </div>
    </div>"""

# ── Cron Health section (TKT-0340) ───────────────────────────────────────────
def cron_health_section_html(cron_health):
    if not cron_health or not cron_health.get("crons"):
        return ""
    total   = cron_health["total"]
    healthy = cron_health["healthy"]
    degraded = cron_health["degraded"]
    failed  = cron_health["failed"]
    crons   = cron_health["crons"]

    # Helper: human-readable duration
    def fmt_duration(ms):
        if ms is None:
            return "—"
        ms = int(ms)
        if ms < 1000:
            return f"{ms}ms"
        elif ms < 60000:
            return f"{ms/1000:.1f}s"
        else:
            mins = ms / 60000
            if mins < 60:
                return f"{mins:.1f}min"
            else:
                return f"{mins/60:.1f}h"

    # Truncate long names
    def trunc_name(name, max_len=50):
        if len(name) <= max_len:
            return esc(name)
        return esc(name[:max_len-3]) + "..."

    def class_badge(tc):
        colours = {
            "shell": "#3182ce",
            "light-agent": "#805ad5",
            "heavy-agent": "#dd6b20",
            "blog-standup": "#38a169",
        }
        c = colours.get(tc, "#718096")
        return f'<span class="cron-class-badge" style="background:{c}22;color:{c};border-color:{c}44">{esc(tc)}</span>'

    def row_bg(status, consec_errors):
        s = (status or "").lower()
        if s in ("error", "failure", "timeout"):
            return "cron-row-failed"
        if consec_errors and consec_errors > 0:
            return "cron-row-failed"
        if s in ("warn", "deviated"):
            return "cron-row-degraded"
        if s == "ok":
            return "cron-row-ok"
        return "cron-row-unknown"

    def status_badge(status):
        s = (status or "").lower()
        if s == "ok":
            return '<span class="cron-status-badge cron-status-ok">✅ OK</span>'
        elif s in ("error", "failure", "timeout"):
            return '<span class="cron-status-badge cron-status-failed">🚨 ' + esc(status) + '</span>'
        elif s in ("warn", "deviated"):
            return '<span class="cron-status-badge cron-status-warn">⚠️ ' + esc(status) + '</span>'
        else:
            return '<span class="cron-status-badge cron-status-unknown">❓ ' + esc(status) + '</span>'

    rows_html = []
    for c in crons:
        name     = trunc_name(c.get("name", ""), 55)
        tclass   = class_badge(c.get("taskClass", "?"))
        timeout  = c.get("computedTimeoutSec", "—")
        status   = status_badge(c.get("lastStatus", "unknown"))
        dur_ms   = c.get("lastDurationMs") or c.get("avgDurationMs")
        dur_fmt  = fmt_duration(dur_ms)
        err_count = c.get("consecutiveErrors", 0)
        row_cls   = row_bg(c.get("lastStatus"), err_count)
        rows_html.append(
            f'<tr class="{row_cls}">'
            f'<td class="cron-name" title="{esc(c.get("name",""))}">{name}</td>'
            f'<td class="cron-class">{tclass}</td>'
            f'<td class="cron-timeout">{timeout}s</td>'
            f'<td class="cron-status">{status}</td>'
            f'<td class="cron-duration">{dur_fmt}</td>'
            f'</tr>'
        )
    rows_str = "\n".join(rows_html)

    return f"""
    <div class="cron-health-section">
      <div class="cron-health-title">&#9201; Cron Health</div>
      <div class="cron-summary-cards">
        <div class="cron-summary-card cron-card-total">
          <div class="cron-summary-num">{total}</div>
          <div class="cron-summary-label">Total Crons</div>
        </div>
        <div class="cron-summary-card cron-card-ok">
          <div class="cron-summary-num">{healthy}</div>
          <div class="cron-summary-label">Healthy</div>
        </div>
        <div class="cron-summary-card cron-card-warn">
          <div class="cron-summary-num">{degraded}</div>
          <div class="cron-summary-label">Degraded</div>
        </div>
        <div class="cron-summary-card cron-card-failed">
          <div class="cron-summary-num">{failed}</div>
          <div class="cron-summary-label">Failed</div>
        </div>
      </div>
      <div class="cron-table-wrapper">
        <table class="cron-table">
          <thead>
            <tr>
              <th class="cron-th-name">Name</th>
              <th class="cron-th-class">Class</th>
              <th class="cron-th-timeout">Timeout</th>
              <th class="cron-th-status">Status</th>
              <th class="cron-th-duration">Duration</th>
            </tr>
          </thead>
          <tbody>
            {rows_str}
          </tbody>
        </table>
      </div>
    </div>"""

# ── Tip banner ───────────────────────────────────────────────────────────────
def tip_banner_html(tip):
    if not tip:
        return ""
    return f'''<div class="tip-banner">💡 <strong>Yoda's Note:</strong> {esc(tip)}</div>'''

tip_html     = tip_banner_html(data.get("tip"))
obs_html     = obs_trend_section_html(data.get("obsTrend"))
cron_html    = cron_health_section_html(data.get("cronHealth"))
yoda_card = agent_card_html(data["agents"][0], "#00d4ff")
aria_card  = agent_card_html(data["agents"][1], "#ff6b9d")
gov_html   = (
    gov_card_html("shield", "🔐", "Shield", gov["shield"]) +
    gov_card_html("lex",    "⚖️", "Lex",    gov["lex"])    +
    gov_card_html("sage",   "🧪", "Sage",   gov["sage"])
)
activity_rows = activity_html(recent_activity)

generated_display = NOW_AEST.strftime("%H:%M AEST")
gateway_display   = gateway_html(gateway_status)
balance_display   = balance_html(balance_amount, balance_tier)

html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta http-equiv="refresh" content="60">
<title>🎯 AInchors Mission Control</title>
<style>
  *, *::before, *::after {{ box-sizing: border-box; margin: 0; padding: 0; }}

  body {{
    background: #0a0e1a;
    color: #e2e8f0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif;
    font-size: 13px;
    line-height: 1.5;
    min-height: 100vh;
  }}

  /* ── Header ── */
  .header {{
    background: #0d1224;
    border-bottom: 1px solid #1e2a4a;
    padding: 14px 20px;
    display: flex;
    align-items: center;
    gap: 16px;
    flex-wrap: wrap;
  }}
  .header-title {{
    font-size: 17px;
    font-weight: 700;
    letter-spacing: 0.5px;
    color: #e2e8f0;
    flex: 1;
  }}
  .header-title span {{
    color: #00d4ff;
  }}
  .header-meta {{
    display: flex;
    align-items: center;
    gap: 16px;
    font-size: 12px;
    flex-wrap: wrap;
  }}
  .header-meta .sep {{ color: #4a5568; }}
  .last-updated {{ color: #718096; }}

  /* ── Tip banner ── */
  .tip-banner {{
    background: #0d1a2e;
    border-left: 3px solid #00d4ff;
    color: #a0c4ff;
    font-size: 12px;
    padding: 8px 20px;
    line-height: 1.5;
  }}
  .tip-banner strong {{ color: #00d4ff; }}

  /* ── Refresh button ── */
  .btn-refresh {{
    background: #1a2040;
    border: 1px solid #2d3f6a;
    color: #00d4ff;
    padding: 5px 12px;
    border-radius: 6px;
    cursor: pointer;
    font-size: 12px;
    font-weight: 600;
    transition: background 0.15s;
  }}
  .btn-refresh:hover {{ background: #222a55; }}

  /* ── Main grid ── */
  .main-grid {{
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0;
    min-height: calc(100vh - 52px);
  }}

  /* ── Stream columns ── */
  .stream-col {{
    padding: 16px;
    border-right: 1px solid #1e2a4a;
  }}
  .stream-col:last-child {{ border-right: none; }}

  .stream-header {{
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 1.5px;
    text-transform: uppercase;
    margin-bottom: 12px;
    padding-bottom: 8px;
    border-bottom: 1px solid #1e2a4a;
  }}
  .stream-header.technical {{ color: #00d4ff; }}
  .stream-header.business  {{ color: #ff6b9d; }}

  /* ── Agent card ── */
  .agent-card {{
    background: #0d1224;
    border: 1px solid #1e2a4a;
    border-radius: 10px;
    padding: 14px;
    margin-bottom: 14px;
  }}
  .agent-header {{
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 10px;
    flex-wrap: wrap;
  }}
  .agent-emoji {{ font-size: 16px; }}
  .agent-name {{
    font-size: 15px;
    font-weight: 700;
    letter-spacing: 0.3px;
  }}
  .agent-model {{
    margin-left: auto;
    background: #1a2040;
    border: 1px solid #2d3f6a;
    color: #718096;
    font-size: 10px;
    padding: 2px 7px;
    border-radius: 4px;
  }}
  .agent-status-label {{
    font-size: 11px;
    font-weight: 600;
    color: #718096;
  }}

  /* ── Status dots ── */
  .dot {{ font-size: 14px; }}
  .dot-idle   {{ color: #4a5568; }}
  .dot-active {{ color: #48bb78; animation: pulse 1.5s infinite; }}
  .dot-error  {{ color: #fc8181; }}

  @keyframes pulse {{
    0%, 100% {{ opacity: 1; }}
    50% {{ opacity: 0.3; }}
  }}

  /* ── Current task ── */
  .current-task {{
    background: #12193a;
    border: 1px solid #2d4a8a;
    color: #90cdf4;
    font-size: 11px;
    padding: 6px 10px;
    border-radius: 6px;
    margin-bottom: 10px;
  }}

  /* ── Task sections ── */
  .task-section {{
    margin-top: 10px;
    padding-top: 10px;
    border-top: 1px solid #1a2240;
  }}
  .task-section-header {{
    font-size: 11px;
    font-weight: 600;
    color: #a0aec0;
    margin-bottom: 6px;
    display: flex;
    align-items: center;
    gap: 6px;
  }}
  .count-badge {{
    background: #1a2240;
    color: #718096;
    font-size: 10px;
    padding: 1px 6px;
    border-radius: 10px;
    min-width: 20px;
    text-align: center;
  }}
  .task-item {{
    display: flex;
    align-items: baseline;
    gap: 4px;
    padding: 2px 0;
    color: #cbd5e0;
    font-size: 12px;
    line-height: 1.4;
  }}
  .task-dot {{ color: #4a5568; flex-shrink: 0; }}
  .task-empty {{ color: #4a5568; font-size: 11px; padding: 4px 0; font-style: italic; }}
  .badge {{
    font-size: 9px;
    padding: 1px 5px;
    border-radius: 3px;
    font-weight: 700;
    flex-shrink: 0;
    margin-left: 4px;
  }}

  /* ── Governance layer ── */
  .gov-section {{
    margin-top: 16px;
    padding-top: 14px;
    border-top: 1px solid #1e2a4a;
  }}
  .gov-section-title {{
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 1.2px;
    text-transform: uppercase;
    color: #718096;
    margin-bottom: 10px;
  }}
  .gov-cards {{
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }}
  .gov-card {{
    background: #0d1224;
    border: 1px solid #1e2a4a;
    border-radius: 8px;
    padding: 10px 12px;
    cursor: pointer;
    flex: 1;
    min-width: 80px;
    transition: border-color 0.15s;
    user-select: none;
  }}
  .gov-card:hover {{ border-color: #2d3f6a; }}
  .gov-header {{
    font-size: 18px;
    font-weight: 700;
    margin-bottom: 3px;
  }}
  .gov-label {{
    font-size: 11px;
    font-weight: 600;
    color: #718096;
    margin-bottom: 6px;
  }}
  .gov-detail {{
    font-size: 10px;
    display: flex;
    gap: 6px;
    margin-bottom: 4px;
  }}
  .gov-verdict {{
    font-size: 10px;
    color: #4a5568;
    display: none;
    margin-top: 6px;
    border-top: 1px solid #1a2240;
    padding-top: 6px;
  }}
  .gov-card.expanded .gov-verdict {{ display: block; }}

  /* ── Activity feed ── */
  .activity-section {{
    grid-column: 1 / -1;
    padding: 14px 16px;
    border-top: 1px solid #1e2a4a;
    background: #0d1224;
  }}
  .activity-title {{
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 1.2px;
    text-transform: uppercase;
    color: #718096;
    margin-bottom: 10px;
  }}
  .activity-item {{
    display: flex;
    gap: 10px;
    padding: 3px 0;
    font-size: 12px;
    color: #a0aec0;
    border-bottom: 1px solid #0f172a;
  }}
  .activity-item:last-child {{ border-bottom: none; }}
  .activity-time {{
    color: #4a5568;
    font-size: 11px;
    font-variant-numeric: tabular-nums;
    flex-shrink: 0;
    min-width: 55px;
  }}

  /* ── Obs Error Trend widget ── */
  .obs-trend-section {{
    grid-column: 1 / -1;
    padding: 14px 16px;
    border-top: 1px solid #1e2a4a;
    background: #0a0e1a;
  }}
  .obs-header {{
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 10px;
    flex-wrap: wrap;
  }}
  .obs-title {{
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 1.2px;
    text-transform: uppercase;
    color: #718096;
  }}
  .obs-period {{
    font-size: 10px;
    color: #4a5568;
    background: #1a2240;
    padding: 2px 6px;
    border-radius: 4px;
  }}
  .obs-totals {{
    display: flex;
    gap: 14px;
    font-size: 12px;
    font-weight: 600;
  }}
  .obs-trend-note {{
    font-size: 11px;
    color: #718096;
  }}
  .obs-gentime {{
    margin-left: auto;
    font-size: 10px;
    color: #4a5568;
  }}
  .obs-worst {{
    font-size: 11px;
    color: #a0aec0;
    background: #12193a;
    border: 1px solid #1e2a4a;
    padding: 5px 10px;
    border-radius: 5px;
    margin-bottom: 10px;
  }}
  .obs-cols {{
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
  }}
  .obs-col-title {{
    font-size: 10px;
    font-weight: 700;
    letter-spacing: 0.8px;
    text-transform: uppercase;
    margin-bottom: 6px;
  }}
  .obs-bar-row {{
    display: flex;
    align-items: center;
    gap: 6px;
    margin-bottom: 5px;
    font-size: 11px;
  }}
  .obs-bar-label {{
    color: #a0aec0;
    min-width: 140px;
    flex-shrink: 0;
  }}
  .obs-bar-track {{
    flex: 1;
    height: 7px;
    background: #1a2240;
    border-radius: 4px;
    overflow: hidden;
  }}
  .obs-bar-fill {{
    height: 100%;
    border-radius: 4px;
    opacity: 0.75;
  }}
  .obs-bar-count {{
    color: #718096;
    min-width: 32px;
    text-align: right;
    font-variant-numeric: tabular-nums;
    font-size: 11px;
  }}

  /* ── Cron Health (TKT-0340) ── */
  .cron-health-section {{
    grid-column: 1 / -1;
    padding: 14px 16px;
    border-top: 1px solid #1e2a4a;
    background: #0a0e1a;
  }}
  .cron-health-title {{
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 1.2px;
    text-transform: uppercase;
    color: #718096;
    margin-bottom: 12px;
  }}

  /* ── Cron Summary Cards ── */
  .cron-summary-cards {{
    display: flex;
    gap: 10px;
    margin-bottom: 14px;
    flex-wrap: wrap;
  }}
  .cron-summary-card {{
    background: #0d1224;
    border: 1px solid #1e2a4a;
    border-radius: 8px;
    padding: 10px 16px;
    flex: 1;
    min-width: 90px;
    text-align: center;
  }}
  .cron-card-total {{ border-left: 3px solid #4299e1; }}
  .cron-card-ok    {{ border-left: 3px solid #48bb78; }}
  .cron-card-warn  {{ border-left: 3px solid #ecc94b; }}
  .cron-card-failed {{ border-left: 3px solid #fc8181; }}
  .cron-summary-num {{
    font-size: 22px;
    font-weight: 700;
    color: #e2e8f0;
  }}
  .cron-summary-label {{
    font-size: 10px;
    font-weight: 600;
    color: #718096;
    text-transform: uppercase;
    letter-spacing: 0.8px;
    margin-top: 2px;
  }}

  /* ── Cron Table ── */
  .cron-table-wrapper {{
    max-height: 460px;
    overflow-y: auto;
    border: 1px solid #1e2a4a;
    border-radius: 6px;
  }}
  .cron-table {{
    width: 100%;
    border-collapse: collapse;
    font-size: 11px;
  }}
  .cron-table thead {{
    position: sticky;
    top: 0;
    z-index: 1;
  }}
  .cron-table th {{
    background: #0d1224;
    color: #718096;
    font-size: 10px;
    font-weight: 700;
    letter-spacing: 0.8px;
    text-transform: uppercase;
    padding: 8px 10px;
    text-align: left;
    border-bottom: 2px solid #1e2a4a;
  }}
  .cron-table td {{
    padding: 5px 10px;
    border-bottom: 1px solid #12193a;
    color: #cbd5e0;
    vertical-align: middle;
  }}
  .cron-table tbody tr:hover {{
    background: #12193a;
  }}
  .cron-th-name    {{ min-width: 220px; }}
  .cron-th-class   {{ width: 100px; }}
  .cron-th-timeout {{ width: 70px; }}
  .cron-th-status  {{ width: 80px; }}
  .cron-th-duration {{ width: 75px; }}
  .cron-name {{
    max-width: 300px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }}

  /* ── Cron row colour coding ── */
  .cron-row-ok      {{ background: #0d1224; }}
  .cron-row-degraded {{ background: #1a1a10; border-left: 3px solid #ecc94b; }}
  .cron-row-failed  {{ background: #1a1010; border-left: 3px solid #fc8181; }}
  .cron-row-unknown {{ background: #0d1224; }}

  /* ── Cron badges ── */
  .cron-class-badge {{
    font-size: 9px;
    padding: 2px 6px;
    border-radius: 3px;
    font-weight: 700;
    border: 1px solid;
    white-space: nowrap;
  }}
  .cron-status-badge {{
    font-size: 10px;
    font-weight: 600;
    white-space: nowrap;
  }}
  .cron-status-ok      {{ color: #48bb78; }}
  .cron-status-failed  {{ color: #fc8181; }}
  .cron-status-warn    {{ color: #ecc94b; }}
  .cron-status-unknown {{ color: #718096; }}

  .cron-duration, .cron-timeout {{
    font-variant-numeric: tabular-nums;
    white-space: nowrap;
    color: #a0aec0;
  }}

  /* ── Mobile responsive ── */
  @media (max-width: 700px) {{
    .main-grid {{ grid-template-columns: 1fr; }}
    .stream-col {{ border-right: none; border-bottom: 1px solid #1e2a4a; }}
    .activity-section {{ grid-column: 1; }}
    .obs-trend-section {{ grid-column: 1; }}
    .cron-health-section {{ grid-column: 1; }}
    .obs-cols {{ grid-template-columns: 1fr; }}
    .cron-summary-cards {{ flex-direction: column; }}
    .cron-table-wrapper {{ max-height: 350px; }}
    .header-meta {{ font-size: 11px; gap: 8px; }}
  }}
</style>
</head>
<body>

<!-- ── Header ── -->
<div class="header">
  <div class="header-title">🎯 <span>AInchors</span> Mission Control</div>
  <div class="header-meta">
    <span>Gateway: {gateway_display}</span>
    <span class="sep">|</span>
    <span>Balance: {balance_display}</span>
    <span class="sep">|</span>
    <span class="last-updated">Updated: {generated_display}</span>
    <button class="btn-refresh" onclick="location.reload()">↻ Refresh</button>
  </div>
</div>

{tip_html}

<!-- ── Main grid ── -->
<div class="main-grid">

  <!-- ── Technical Stream ── -->
  <div class="stream-col">
    <div class="stream-header technical">⚙️ Technical Stream</div>
    {yoda_card}

    <!-- Governance layer (under Technical) -->
    <div class="gov-section">
      <div class="gov-section-title">🏛️ Governance Layer</div>
      <div class="gov-cards">
        {gov_html}
      </div>
    </div>
  </div>

  <!-- ── Business Stream ── -->
  <div class="stream-col">
    <div class="stream-header business">💼 Business Stream</div>
    {aria_card}
  </div>

  <!-- ── Obs Error Trend (full-width) ── -->
  {obs_html}

  <!-- ── Cron Health (full-width, TKT-0340) ── -->
  {cron_html}

  <!-- ── Recent Activity (full-width) ── -->
  <div class="activity-section">
    <div class="activity-title">📋 Recent Activity</div>
    {activity_rows}
  </div>

</div>

</body>
</html>"""

print(html, end="")

print(f"[ok] index.html generated", file=sys.stderr)
print(f"[ok] Generated at {data['generatedAtAEST']}", file=sys.stderr)
print(f"[ok] Balance: ${balance_amount:.2f} (tier {balance_tier})", file=sys.stderr)
print(f"[ok] Gateway: {gateway_status}", file=sys.stderr)
print(f"[ok] Agents: Yoda={data['agents'][0]['status']}, Aria={data['agents'][1]['status']}", file=sys.stderr)
print(f"[ok] Tech tasks — backlog:{len(tech_bl)} wip:{len(tech_wi)} done:{len(tech_dn)}", file=sys.stderr)
print(f"[ok] Biz tasks  — backlog:{len(biz_bl)} wip:{len(biz_wi)} done:{len(biz_dn)}", file=sys.stderr)
print(f"[ok] Governance — shield:{gov['shield']['totalToday']} lex:{gov['lex']['totalToday']} sage:{gov['sage']['totalToday']}", file=sys.stderr)
print(f"[ok] Activity entries: {len(recent_activity)}", file=sys.stderr)
print(f"[ok] Cron Health — total:{cron_total} healthy:{cron_healthy} degraded:{cron_degraded} failed:{cron_failed}", file=sys.stderr)

PYEOF

echo "[done] Mission Control generation complete."
