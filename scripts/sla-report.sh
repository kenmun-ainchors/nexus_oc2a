#!/usr/bin/env bash
# =============================================================================
# sla-report.sh — AInchors Monthly SLA Report Generator
# Usage: bash scripts/sla-report.sh [--month YYYY-MM] [--period-start YYYY-MM-DD]
# Outputs: canvas/documents/sla-YYYY-MM/index.html + memory/shared/sla-history.md
# =============================================================================
set -euo pipefail

WORKSPACE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INCIDENT_LOG="$WORKSPACE/state/incident-log.json"
COST_STATE="$WORKSPACE/state/cost-state.json"

export WORKSPACE
python3 - "$@" <<'PYEOF'
import sys, json, os, math, argparse
from datetime import datetime, timezone, timedelta
from pathlib import Path

# ── Args ────────────────────────────────────────────────────────────────────
parser = argparse.ArgumentParser(description="AInchors SLA Report Generator")
parser.add_argument("--month", default=None, help="YYYY-MM (default: current month)")
parser.add_argument("--period-start", default=None, dest="period_start",
                    help="YYYY-MM-DD override for partial months")
args = parser.parse_args()

now_utc = datetime.now(timezone.utc)
now_melb = now_utc + timedelta(hours=10)  # AEST/AEDT approx

if args.month:
    year, mon = map(int, args.month.split("-"))
else:
    year, mon = now_melb.year, now_melb.month

month_str  = f"{year:04d}-{mon:02d}"
month_label = datetime(year, mon, 1).strftime("%B %Y")

# Period end = today (if current month) or last day of month (if past)
is_current_month = (year == now_melb.year and mon == now_melb.month)
if is_current_month:
    period_end = now_melb.replace(hour=23, minute=59, second=59)
else:
    # last day of past month
    if mon == 12:
        last_day = datetime(year + 1, 1, 1, tzinfo=timezone.utc) - timedelta(days=1)
    else:
        last_day = datetime(year, mon + 1, 1, tzinfo=timezone.utc) - timedelta(days=1)
    period_end = last_day.replace(hour=23, minute=59, second=59)

# Period start
if args.period_start:
    period_start = datetime.strptime(args.period_start, "%Y-%m-%d").replace(
        hour=0, minute=0, second=0, tzinfo=timezone(timedelta(hours=10))
    )
else:
    period_start = datetime(year, mon, 1, 0, 0, 0,
                            tzinfo=timezone(timedelta(hours=10)))

partial_note = args.period_start and args.period_start != f"{year:04d}-{mon:02d}-01"

# ── Paths ────────────────────────────────────────────────────────────────────
workspace = Path(os.environ["WORKSPACE"])

incident_log_path = workspace / "state" / "incident-log.json"
cost_state_path   = workspace / "state" / "cost-state.json"
output_dir        = Path(os.path.expanduser("~/.openclaw/canvas")) / "documents" / f"sla-{month_str}"
output_html       = output_dir / "index.html"
sla_history_path  = workspace / "memory" / "shared" / "sla-history.md"

output_dir.mkdir(parents=True, exist_ok=True)

# ── Load data ────────────────────────────────────────────────────────────────
with open(incident_log_path) as f:
    inc_data = json.load(f)

with open(cost_state_path) as f:
    cost_data = json.load(f)

# ── Filter incidents in period ───────────────────────────────────────────────
incidents_in_period = []
for inc in inc_data.get("incidents", []):
    ts = datetime.fromisoformat(inc["timestamp_start"].replace("Z", "+00:00"))
    ts_melb = ts + timedelta(hours=10)
    if period_start <= ts_melb <= period_end:
        incidents_in_period.append(inc)

total_downtime_min = sum(i["duration_minutes"] for i in incidents_in_period)
inc_count          = len(incidents_in_period)

# Preventable: incidents with "prevention" key or recurrence=True treated as preventable
# Known: INC-002 and INC-003 have prevention keys → 52+116=168 min preventable
preventable_min = sum(
    i["duration_minutes"] for i in incidents_in_period
    if "prevention" in i
)
preventable_pct = (preventable_min / total_downtime_min * 100) if total_downtime_min > 0 else 0

# ── Period minutes ───────────────────────────────────────────────────────────
delta_days   = (period_end.date() - period_start.date()).days + 1
total_min    = delta_days * 1440

uptime_min   = total_min - total_downtime_min
uptime_pct   = uptime_min / total_min * 100 if total_min > 0 else 100.0
mttr_avg     = total_downtime_min / inc_count if inc_count > 0 else 0

# ── Costs ────────────────────────────────────────────────────────────────────
cost_history = cost_data.get("history", {})
period_costs = {}
for date_str, day_data in cost_history.items():
    d = datetime.strptime(date_str, "%Y-%m-%d")
    if d.year == year and d.month == mon:
        ps_date = period_start.date()
        pe_date = period_end.date()
        if ps_date <= d.date() <= pe_date:
            period_costs[date_str] = day_data

total_cost   = sum(d["totalCost"] for d in period_costs.values())
days_tracked = len(period_costs)
avg_daily    = total_cost / days_tracked if days_tracked > 0 else 0

# ── SLA Targets ──────────────────────────────────────────────────────────────
AVAIL_TARGET = 99.0   # %
MTTR_TARGET  = 60.0   # min

def traffic_light(actual, target, higher_is_better=True):
    """Returns 'green', 'amber', or 'red'."""
    if higher_is_better:
        diff = actual - target
    else:
        diff = target - actual
    if diff >= 0:
        return "green"
    elif diff >= -1.0:
        return "amber"
    else:
        return "red"

avail_light = traffic_light(uptime_pct, AVAIL_TARGET, higher_is_better=True)
mttr_light  = traffic_light(mttr_avg, MTTR_TARGET, higher_is_better=False)

# ── Traffic light CSS ────────────────────────────────────────────────────────
LIGHT_COLORS = {"green": "#22c55e", "amber": "#f59e0b", "red": "#ef4444"}
LIGHT_BG     = {"green": "#f0fdf4", "amber": "#fffbeb", "red": "#fef2f2"}
LIGHT_TEXT   = {"green": "#166534", "amber": "#92400e", "red": "#991b1b"}
LIGHT_LABEL  = {"green": "✅ TARGET MET", "amber": "⚠️ NEAR MISS", "red": "❌ TARGET MISSED"}

def badge(light, value_str):
    return (f'<span style="background:{LIGHT_BG[light]};color:{LIGHT_TEXT[light]};'
            f'border:1.5px solid {LIGHT_COLORS[light]};border-radius:6px;'
            f'padding:3px 10px;font-weight:700;font-size:0.92em;">'
            f'{value_str} &nbsp; {LIGHT_LABEL[light]}</span>')

# ── Incident rows ─────────────────────────────────────────────────────────────
def inc_row(inc):
    ts  = datetime.fromisoformat(inc["timestamp_start"].replace("Z", "+00:00"))
    ts  = ts + timedelta(hours=10)
    ts_str = ts.strftime("%Y-%m-%d %H:%M AEST")
    typ = inc.get("type", "—").capitalize()
    typ_color = {"Outage": "#ef4444", "Degraded": "#f59e0b", "Security": "#8b5cf6",
                 "Data": "#3b82f6", "Planned": "#6b7280"}.get(typ, "#6b7280")
    prev = "✔ Yes" if "prevention" in inc else "✘ No"
    prev_color = "#ef4444" if "prevention" in inc else "#6b7280"
    return f"""
        <tr>
          <td style="font-family:monospace;font-size:0.85em;white-space:nowrap;">{inc['id']}</td>
          <td style="white-space:nowrap;">{ts_str}</td>
          <td><span style="background:{typ_color}20;color:{typ_color};border-radius:4px;
              padding:2px 8px;font-size:0.85em;font-weight:600;">{typ}</span></td>
          <td style="font-size:0.9em;">{inc.get('trigger','—')}</td>
          <td style="text-align:center;font-weight:700;">{inc['duration_minutes']} min</td>
          <td style="text-align:center;color:{prev_color};font-weight:600;">{prev}</td>
          <td style="font-size:0.85em;">{inc.get('resolution','—')}</td>
        </tr>"""

inc_rows_html = "\n".join(inc_row(i) for i in incidents_in_period) if incidents_in_period else \
    '<tr><td colspan="7" style="text-align:center;color:#6b7280;">No incidents in period</td></tr>'

# ── Cost rows ─────────────────────────────────────────────────────────────────
def cost_row(date_str, day):
    by_model = day.get("byModel", {})
    models = ", ".join(by_model.keys()) or "—"
    return f"""
        <tr>
          <td>{date_str}</td>
          <td>{day.get('totalTurns', 0):,}</td>
          <td style="font-family:monospace;">{day.get('totalInputTokens', 0):,}</td>
          <td style="font-family:monospace;">{day.get('totalOutputTokens', 0):,}</td>
          <td style="font-family:monospace;">{day.get('totalCacheReadTokens', 0):,}</td>
          <td style="font-size:0.85em;color:#6b7280;">{models}</td>
          <td style="text-align:right;font-weight:700;">${day['totalCost']:.4f}</td>
        </tr>"""

if period_costs:
    sorted_costs = sorted(period_costs.items())
    cost_rows_html = "\n".join(cost_row(d, v) for d, v in sorted_costs)
    # Add "in progress" row for today if current month and today not yet in data
    today_str = now_melb.strftime("%Y-%m-%d")
    if is_current_month and today_str not in period_costs:
        cost_rows_html += f"""
        <tr style="background:#fffbeb;">
          <td>{today_str}</td>
          <td colspan="5" style="color:#92400e;font-style:italic;">Day in progress — data not yet recorded</td>
          <td style="text-align:right;color:#92400e;font-style:italic;">TBD</td>
        </tr>"""
else:
    cost_rows_html = '<tr><td colspan="7" style="text-align:center;color:#6b7280;">No cost data in period</td></tr>'

# ── Recommendations ───────────────────────────────────────────────────────────
recs = []
if avail_light in ("amber", "red"):
    recs.append(("🔴 Availability below target",
                 f"Actual uptime {uptime_pct:.2f}% vs target ≥{AVAIL_TARGET}%. "
                 "Primary causes: FileVault unlock dependency (INC-001) and gateway crash loop (INC-003). "
                 "Mitigations: implement auto-unlock post-boot, pre-risky-op checkpoint (in place from 2026-04-26)."))
if mttr_light in ("amber", "red"):
    recs.append(("🔴 MTTR above target",
                 f"Avg MTTR {mttr_avg:.0f} min vs target ≤{MTTR_TARGET:.0f} min. "
                 "INC-003 (116 min) is the main driver — gateway crash loop required LaunchAgent self-recovery. "
                 "Mitigations: pre-restart-cleanup script (in place), US21 PVT checklist item pending."))
if preventable_pct > 50:
    recs.append(("⚠️ High preventable downtime",
                 f"{preventable_pct:.0f}% of downtime ({preventable_min} min) was preventable with known fixes. "
                 "Pre-risky-op checkpoint protocol now in place. "
                 "Expected to eliminate INC-002/003 class incidents going forward."))
recs.append(("📋 Partial month baseline",
             "This is Day 1–3 of AInchors technical operations. All metrics serve as baseline. "
             "SLA targets will be re-evaluated once full-month data is available (May 2026)."))

rec_html = "".join(f"""
    <div style="margin-bottom:16px;padding:14px 16px;background:#f8fafc;border-left:4px solid #334155;
         border-radius:0 8px 8px 0;">
      <div style="font-weight:700;margin-bottom:4px;">{r[0]}</div>
      <div style="color:#475569;font-size:0.93em;">{r[1]}</div>
    </div>""" for r in recs)

# ── Overall status ────────────────────────────────────────────────────────────
lights = [avail_light, mttr_light]
if "red" in lights:
    overall_light = "red"
    overall_label = "SLA TARGETS MISSED"
elif "amber" in lights:
    overall_light = "amber"
    overall_label = "SLA NEAR MISS"
else:
    overall_light = "green"
    overall_label = "SLA TARGETS MET"

overall_color = LIGHT_COLORS[overall_light]
overall_bg    = LIGHT_BG[overall_light]
overall_text  = LIGHT_TEXT[overall_light]

partial_banner = ""
if partial_note:
    ps_label = period_start.strftime("%Y-%m-%d")
    partial_banner = f"""
    <div style="background:#eff6ff;border:1.5px solid #3b82f6;border-radius:8px;
         padding:12px 18px;margin-bottom:24px;color:#1e40af;font-size:0.93em;">
      <strong>ℹ️ Partial month report</strong> — AInchors technical operations commenced {ps_label}.
      Period covers {delta_days} day{'s' if delta_days != 1 else ''} ({ps_label} to {period_end.strftime('%Y-%m-%d')}).
    </div>"""

# ── HTML ─────────────────────────────────────────────────────────────────────
generated_at = now_melb.strftime("%Y-%m-%d %H:%M AEST")

html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AInchors SLA Report — {month_label}</title>
  <style>
    *, *::before, *::after {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      background: #f1f5f9;
      color: #1e293b;
      line-height: 1.6;
      padding: 32px 16px;
    }}
    .container {{ max-width: 960px; margin: 0 auto; }}
    .card {{
      background: #ffffff;
      border-radius: 12px;
      box-shadow: 0 1px 4px rgba(0,0,0,0.08);
      padding: 28px 32px;
      margin-bottom: 24px;
    }}
    h1 {{ font-size: 1.8em; font-weight: 800; letter-spacing: -0.5px; }}
    h2 {{ font-size: 1.15em; font-weight: 700; margin-bottom: 18px;
          padding-bottom: 10px; border-bottom: 2px solid #e2e8f0; color: #334155; }}
    .header-meta {{ color: #64748b; font-size: 0.9em; margin-top: 6px; }}
    .status-banner {{
      background: {overall_bg};
      border: 2px solid {overall_color};
      border-radius: 10px;
      padding: 16px 24px;
      display: flex;
      align-items: center;
      gap: 16px;
      margin-bottom: 8px;
    }}
    .status-dot {{
      width: 20px; height: 20px; border-radius: 50%;
      background: {overall_color};
      flex-shrink: 0;
      box-shadow: 0 0 0 4px {overall_color}30;
    }}
    .status-label {{ font-size: 1.2em; font-weight: 800; color: {overall_text}; }}
    .metrics-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 16px;
      margin-bottom: 8px;
    }}
    .metric {{
      background: #f8fafc;
      border-radius: 10px;
      padding: 18px 20px;
      border: 1px solid #e2e8f0;
    }}
    .metric-label {{ font-size: 0.78em; font-weight: 600; text-transform: uppercase;
                     letter-spacing: 0.06em; color: #64748b; margin-bottom: 6px; }}
    .metric-value {{ font-size: 1.9em; font-weight: 800; line-height: 1.1; }}
    .metric-sub {{ font-size: 0.8em; color: #94a3b8; margin-top: 4px; }}
    table {{ width: 100%; border-collapse: collapse; font-size: 0.9em; }}
    th {{
      background: #f1f5f9;
      padding: 10px 12px;
      text-align: left;
      font-size: 0.78em;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: #475569;
      border-bottom: 2px solid #e2e8f0;
    }}
    td {{ padding: 10px 12px; border-bottom: 1px solid #f1f5f9; vertical-align: top; }}
    tr:last-child td {{ border-bottom: none; }}
    tr:hover td {{ background: #f8fafc; }}
    .sla-row {{ display: flex; align-items: center; justify-content: space-between;
                padding: 12px 0; border-bottom: 1px solid #f1f5f9; }}
    .sla-row:last-child {{ border-bottom: none; }}
    .sla-metric {{ font-weight: 600; }}
    .footer {{ text-align: center; color: #94a3b8; font-size: 0.82em; padding: 16px 0 0; }}
    @media (max-width: 600px) {{
      .card {{ padding: 20px 16px; }}
      .metrics-grid {{ grid-template-columns: 1fr 1fr; }}
    }}
  </style>
</head>
<body>
<div class="container">

  <!-- Header -->
  <div class="card">
    <div style="display:flex;align-items:flex-start;justify-content:space-between;flex-wrap:wrap;gap:12px;">
      <div>
        <div style="font-size:0.8em;font-weight:600;text-transform:uppercase;letter-spacing:0.08em;
             color:#64748b;margin-bottom:6px;">AInchors — Service Level Agreement Report</div>
        <h1>📊 {month_label}</h1>
        <div class="header-meta">
          Period: {period_start.strftime("%Y-%m-%d")} → {period_end.strftime("%Y-%m-%d")} &nbsp;·&nbsp;
          {delta_days} days &nbsp;·&nbsp; Generated: {generated_at}
        </div>
      </div>
      <div style="text-align:right;">
        <div style="font-size:0.75em;color:#94a3b8;margin-bottom:4px;">Overall Status</div>
        <div class="status-banner" style="padding:10px 16px;">
          <div class="status-dot"></div>
          <div class="status-label">{overall_label}</div>
        </div>
      </div>
    </div>
  </div>

  {partial_banner}

  <!-- Key Metrics -->
  <div class="card">
    <h2>📈 Key Metrics</h2>
    <div class="metrics-grid">
      <div class="metric">
        <div class="metric-label">Uptime</div>
        <div class="metric-value" style="color:{LIGHT_COLORS[avail_light]};">{uptime_pct:.2f}%</div>
        <div class="metric-sub">Target ≥{AVAIL_TARGET}%</div>
      </div>
      <div class="metric">
        <div class="metric-label">Total Downtime</div>
        <div class="metric-value">{total_downtime_min} min</div>
        <div class="metric-sub">{uptime_min:,} min uptime</div>
      </div>
      <div class="metric">
        <div class="metric-label">Avg MTTR</div>
        <div class="metric-value" style="color:{LIGHT_COLORS[mttr_light]};">{mttr_avg:.0f} min</div>
        <div class="metric-sub">Target ≤{MTTR_TARGET:.0f} min</div>
      </div>
      <div class="metric">
        <div class="metric-label">Incidents</div>
        <div class="metric-value">{inc_count}</div>
        <div class="metric-sub">In period</div>
      </div>
      <div class="metric">
        <div class="metric-label">Preventable</div>
        <div class="metric-value">{preventable_pct:.0f}%</div>
        <div class="metric-sub">{preventable_min} of {total_downtime_min} min</div>
      </div>
      <div class="metric">
        <div class="metric-label">API Cost</div>
        <div class="metric-value">${total_cost:.2f}</div>
        <div class="metric-sub">~${avg_daily:.2f}/day avg</div>
      </div>
    </div>
  </div>

  <!-- SLA Targets -->
  <div class="card">
    <h2>🎯 SLA Targets vs Actual</h2>
    <div class="sla-row">
      <div>
        <div class="sla-metric">Availability</div>
        <div style="font-size:0.85em;color:#64748b;">Target: ≥{AVAIL_TARGET}% &nbsp;·&nbsp; Actual: {uptime_pct:.2f}%</div>
      </div>
      <div>{badge(avail_light, f"{uptime_pct:.2f}%")}</div>
    </div>
    <div class="sla-row">
      <div>
        <div class="sla-metric">Mean Time to Recovery (MTTR)</div>
        <div style="font-size:0.85em;color:#64748b;">Target: ≤{MTTR_TARGET:.0f} min &nbsp;·&nbsp; Actual: {mttr_avg:.0f} min</div>
      </div>
      <div>{badge(mttr_light, f"{mttr_avg:.0f} min")}</div>
    </div>
  </div>

  <!-- Incidents -->
  <div class="card">
    <h2>🚨 Incident Log ({inc_count} incident{'s' if inc_count != 1 else ''})</h2>
    <div style="overflow-x:auto;">
      <table>
        <thead>
          <tr>
            <th>ID</th><th>Start (AEST)</th><th>Type</th><th>Trigger</th>
            <th style="text-align:center;">Duration</th>
            <th style="text-align:center;">Preventable</th>
            <th>Resolution</th>
          </tr>
        </thead>
        <tbody>{inc_rows_html}</tbody>
      </table>
    </div>
    <div style="margin-top:14px;padding:12px 16px;background:#fef2f2;border-radius:8px;
         border-left:4px solid #ef4444;font-size:0.87em;color:#7f1d1d;">
      <strong>Downtime summary:</strong>
      Total {total_downtime_min} min &nbsp;·&nbsp;
      Preventable {preventable_min} min ({preventable_pct:.0f}%) &nbsp;·&nbsp;
      Non-preventable {total_downtime_min - preventable_min} min ({100-preventable_pct:.0f}%)
    </div>
  </div>

  <!-- Costs -->
  <div class="card">
    <h2>💰 API Cost Report</h2>
    <div style="overflow-x:auto;">
      <table>
        <thead>
          <tr>
            <th>Date</th><th>Turns</th><th>Input Tokens</th><th>Output Tokens</th>
            <th>Cache Read</th><th>Model</th><th style="text-align:right;">Cost (USD)</th>
          </tr>
        </thead>
        <tbody>{cost_rows_html}
          <tr style="background:#f1f5f9;font-weight:700;border-top:2px solid #e2e8f0;">
            <td>TOTAL ({days_tracked} day{'s' if days_tracked != 1 else ''} tracked)</td>
            <td>{sum(d.get('totalTurns',0) for d in period_costs.values()):,}</td>
            <td style="font-family:monospace;">{sum(d.get('totalInputTokens',0) for d in period_costs.values()):,}</td>
            <td style="font-family:monospace;">{sum(d.get('totalOutputTokens',0) for d in period_costs.values()):,}</td>
            <td style="font-family:monospace;">{sum(d.get('totalCacheReadTokens',0) for d in period_costs.values()):,}</td>
            <td>—</td>
            <td style="text-align:right;">${total_cost:.4f}</td>
          </tr>
        </tbody>
      </table>
    </div>
    <div style="margin-top:14px;font-size:0.87em;color:#475569;">
      Daily average: <strong>${avg_daily:.2f}</strong> &nbsp;·&nbsp;
      All usage: <strong>Anthropic claude-sonnet-4-6</strong> &nbsp;·&nbsp;
      Current API balance: <strong>${cost_data.get('apiBalance', {}).get('balance', 'N/A')}</strong>
    </div>
  </div>

  <!-- Recommendations -->
  <div class="card">
    <h2>💡 Recommendations</h2>
    {rec_html}
  </div>

  <div class="footer">
    Generated by Yoda (AInchors AI Ops) &nbsp;·&nbsp; {generated_at} &nbsp;·&nbsp;
    Source: incident-log.json + cost-state.json &nbsp;·&nbsp;
    AInchors OC1 — sla-{month_str}
  </div>

</div>
</body>
</html>"""

# ── Write HTML ────────────────────────────────────────────────────────────────
output_html.write_text(html, encoding="utf-8")
print(f"✅ HTML report → {output_html}")

# ── Append sla-history.md ─────────────────────────────────────────────────────
history_entry = f"""
## {month_label} (`{month_str}`)

| Metric               | Actual     | Target   | Status        |
|----------------------|------------|----------|---------------|
| Availability         | {uptime_pct:.2f}%  | ≥99%     | {LIGHT_LABEL[avail_light]} |
| MTTR (avg)           | {mttr_avg:.0f} min     | ≤60 min  | {LIGHT_LABEL[mttr_light]} |
| Total Downtime       | {total_downtime_min} min      | —        | —             |
| Incidents            | {inc_count}          | —        | —             |
| Preventable Downtime | {preventable_pct:.0f}%        | —        | —             |
| API Cost (tracked)   | ${total_cost:.2f}    | —        | —             |
| Days in Period       | {delta_days}          | —        | Partial month (ops commenced 2026-04-25) |

_Generated {generated_at}_

"""

if sla_history_path.exists():
    existing = sla_history_path.read_text(encoding="utf-8")
    if month_str in existing:
        print(f"⏭️  sla-history.md already contains {month_str} — skipping append")
    else:
        sla_history_path.write_text(existing.rstrip() + "\n" + history_entry, encoding="utf-8")
        print(f"✅ Appended to sla-history.md")
else:
    header = "# AInchors SLA History\n\nCumulative monthly SLA summaries. Generated by `scripts/sla-report.sh`.\n"
    sla_history_path.write_text(header + history_entry, encoding="utf-8")
    print(f"✅ Created sla-history.md")

# ── Summary ───────────────────────────────────────────────────────────────────
print(f"""
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SLA Report — {month_label}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Period:       {period_start.strftime('%Y-%m-%d')} → {period_end.strftime('%Y-%m-%d')} ({delta_days} days)
Uptime:       {uptime_pct:.2f}%  [{avail_light.upper()}]  (target ≥{AVAIL_TARGET}%)
MTTR avg:     {mttr_avg:.0f} min      [{mttr_light.upper()}]  (target ≤{MTTR_TARGET:.0f} min)
Downtime:     {total_downtime_min} min ({preventable_pct:.0f}% preventable)
Incidents:    {inc_count}
API Cost:     ${total_cost:.4f} ({days_tracked} days tracked)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Overall:      {overall_label}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
""")

PYEOF
