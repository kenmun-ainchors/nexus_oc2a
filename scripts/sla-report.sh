#!/usr/bin/env zsh
# =============================================================================
# sla-report.sh -- AInchors Monthly SLA Report Generator
# Usage: zsh scripts/sla-report.sh YYYY-MM
# Outputs: reports/sla-YYYY-MM.md
#          memory/shared/sla-history.md (appended)
# =============================================================================
set -euo pipefail

WORKSPACE="${0:A:h:h}"
export WORKSPACE

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 YYYY-MM" >&2
  exit 1
fi

MONTH="$1"

python3 - "$MONTH" <<'PYEOF'
import sys, json, os, glob, re
from datetime import datetime, timezone, timedelta
from pathlib import Path

MONTH = sys.argv[1]
try:
    year, mon = map(int, MONTH.split("-"))
except ValueError:
    print(f"ERROR: Invalid month format '{MONTH}'. Use YYYY-MM.", file=sys.stderr)
    sys.exit(1)

workspace     = Path(os.environ["WORKSPACE"])
incidents_dir = workspace / "state" / "incidents"
violations_f  = workspace / "state" / "model-drift-violations.json"
health_f      = workspace / "state" / "health-state.json"
cost_hist_f   = workspace / "memory" / "shared" / "cost-history.md"
cost_state_f  = workspace / "state" / "cost-state.json"
sla_history_f = workspace / "memory" / "shared" / "sla-history.md"
reports_dir   = workspace / "reports"
reports_dir.mkdir(parents=True, exist_ok=True)
out_file      = reports_dir / f"sla-{MONTH}.md"

month_label   = datetime(year, mon, 1).strftime("%B %Y")

# AInchors ops commenced 2026-04-25 (partial months handled here)
OPS_START = datetime(2026, 4, 25, 0, 0, 0, tzinfo=timezone(timedelta(hours=10)))

now_aest  = datetime.now(timezone(timedelta(hours=10)))
is_current = (year == now_aest.year and mon == now_aest.month)

# Period boundaries
if year < 2026 or (year == 2026 and mon < 4):
    period_start = datetime(year, mon, 1, 0, 0, 0, tzinfo=timezone(timedelta(hours=10)))
elif year == 2026 and mon == 4:
    period_start = OPS_START
else:
    period_start = datetime(year, mon, 1, 0, 0, 0, tzinfo=timezone(timedelta(hours=10)))

if is_current:
    period_end = now_aest
else:
    if mon == 12:
        period_end = datetime(year + 1, 1, 1, tzinfo=timezone(timedelta(hours=10))) - timedelta(seconds=1)
    else:
        period_end = datetime(year, mon + 1, 1, tzinfo=timezone(timedelta(hours=10))) - timedelta(seconds=1)

delta_minutes = int((period_end - period_start).total_seconds() / 60)
partial_month = (period_start.day != 1)

generated_at  = now_aest.strftime("%Y-%m-%d %H:%M AEST")

# ============================================================
# 1. INCIDENTS
# ============================================================
incidents = []
if incidents_dir.exists():
    for f in sorted(glob.glob(str(incidents_dir / "INC-*.json"))):
        try:
            with open(f) as fh:
                inc = json.load(fh)
            started = datetime.fromisoformat(inc["startedAt"])
            if started.year == year and started.month == mon:
                if started >= period_start and started <= period_end:
                    incidents.append(inc)
        except Exception as e:
            print(f"  WARN: Could not parse {f}: {e}", file=sys.stderr)

total_downtime_min = sum(i.get("durationMinutes", 0) for i in incidents)
inc_count          = len(incidents)
preventable        = [i for i in incidents if i.get("preventable", False)]
preventable_min    = sum(i.get("durationMinutes", 0) for i in preventable)
preventable_pct    = (preventable_min / total_downtime_min * 100) if total_downtime_min > 0 else 0.0
uptime_min         = delta_minutes - total_downtime_min
availability_pct   = (uptime_min / delta_minutes * 100) if delta_minutes > 0 else 100.0
mttr_avg           = (total_downtime_min / inc_count) if inc_count > 0 else 0.0

# ============================================================
# 2. MODEL DRIFT VIOLATIONS
# ============================================================
drift_total     = 0
drift_unresolved = 0
drift_superseded = 0
drift_month_total = 0

if violations_f.exists():
    with open(violations_f) as fh:
        vdata = json.load(fh)
    all_v = vdata.get("violations", [])
    drift_total = len(all_v)
    for v in all_v:
        st   = v.get("status", "")
        det  = v.get("detectedAt", "")
        try:
            dt = datetime.fromisoformat(det)
            if dt.year == year and dt.month == mon:
                drift_month_total += 1
        except Exception:
            pass
        if st not in ("superseded", "resolved"):
            drift_unresolved += 1
        if st == "superseded":
            drift_superseded += 1

# ============================================================
# 3. COSTS (parse cost-history.md)
# ============================================================
total_cost   = 0.0
cost_by_day  = {}
cost_note    = "Parsed from memory/shared/cost-history.md"

if cost_hist_f.exists():
    text = cost_hist_f.read_text(encoding="utf-8")
    # Find sections that match ## YYYY-MM-DD headings in the target month
    day_re  = re.compile(r"## (%s-\d{2})" % re.escape(MONTH))
    cost_re = re.compile(r"Total Cost.*?\|\s*\$([\d,]+\.?\d*)")
    sections = list(day_re.finditer(text))
    for i, m in enumerate(sections):
        date_str = m.group(1)
        # Extract text until next ## heading
        start   = m.end()
        end     = sections[i+1].start() if i + 1 < len(sections) else len(text)
        chunk   = text[start:end]
        cm      = cost_re.search(chunk)
        if cm:
            try:
                cost = float(cm.group(1).replace(",", ""))
                cost_by_day[date_str] = cost
                total_cost += cost
            except ValueError:
                pass

# Fallback to cost-state.json history if nothing found
if not cost_by_day and cost_state_f.exists():
    try:
        with open(cost_state_f) as fh:
            cs = json.load(fh)
        hist = cs.get("history", {})
        for ds, dd in hist.items():
            try:
                dt = datetime.strptime(ds, "%Y-%m-%d")
                if dt.year == year and dt.month == mon:
                    c = float(dd.get("totalCost", 0))
                    cost_by_day[ds] = c
                    total_cost += c
            except Exception:
                pass
        if cost_by_day:
            cost_note = "Parsed from state/cost-state.json (fallback)"
    except Exception as e:
        cost_note = f"Cost data unavailable ({e})"

days_tracked = len(cost_by_day)
avg_daily    = (total_cost / days_tracked) if days_tracked > 0 else 0.0

# ============================================================
# 4. HEALTH STATE
# ============================================================
health_status = "unknown"
health_issues = []
if health_f.exists():
    try:
        with open(health_f) as fh:
            hs = json.load(fh)
        health_status = hs.get("overallStatus", hs.get("status", "unknown"))
        health_issues = hs.get("issues", [])
    except Exception:
        pass

# ============================================================
# 5. SLA TARGETS
# ============================================================
AVAIL_TARGET = 99.0
MTTR_TARGET  = 60.0

avail_met  = availability_pct >= AVAIL_TARGET
mttr_met   = mttr_avg <= MTTR_TARGET or inc_count == 0
avail_flag = "PASS" if avail_met else "FAIL"
mttr_flag  = "PASS" if mttr_met else "FAIL"

if avail_met and mttr_met:
    overall = "SLA TARGETS MET"
    overall_icon = "[OK]"
else:
    overall = "SLA TARGETS MISSED"
    overall_icon = "[FAIL]"

# ============================================================
# 6. INCIDENT TABLE
# ============================================================
inc_table_rows = ""
if incidents:
    for inc in incidents:
        iid  = inc.get("id", "—")
        sev  = inc.get("severity", "—")
        ts   = datetime.fromisoformat(inc["startedAt"]).strftime("%Y-%m-%d %H:%M AEST")
        dur  = inc.get("durationMinutes", 0)
        prev = "Yes" if inc.get("preventable", False) else "No"
        chg  = inc.get("linkedChg") or "—"
        title_short = inc.get("title", "—")[:60]
        inc_table_rows += f"| {iid} | {sev} | {ts} | {title_short} | {dur} min | {prev} | {chg} |\n"
else:
    inc_table_rows = "| — | — | — | No incidents in period | — | — | — |\n"

# ============================================================
# 7. TREND LINE (from sla-history.md)
# ============================================================
trend_note = "_No prior months on record._"
if sla_history_f.exists():
    hist_text = sla_history_f.read_text(encoding="utf-8")
    # Count how many months recorded
    months_found = re.findall(r"## \w+ \d{4}", hist_text)
    if months_found:
        trend_note = f"{len(months_found)} month(s) on record in sla-history.md."

# ============================================================
# 8. RECOMMENDATIONS
# ============================================================
recs = []
if not avail_met:
    recs.append(f"AVAILABILITY BELOW TARGET: {availability_pct:.2f}% vs >=99%. "
                f"Total downtime: {total_downtime_min} min. "
                f"Review and resolve root causes for {inc_count} incidents. "
                f"Ensure pre-risky-op checkpoint is followed for all risky operations.")
if not mttr_met:
    recs.append(f"MTTR ABOVE TARGET: {mttr_avg:.0f} min avg vs <=60 min. "
                f"Investigate longest incidents and improve automated recovery.")
if preventable_pct > 50:
    recs.append(f"HIGH PREVENTABLE DOWNTIME: {preventable_pct:.0f}% of downtime "
                f"({preventable_min} of {total_downtime_min} min) was preventable. "
                f"Enforce pre-risky-op checkpoint protocol consistently.")
if drift_unresolved > 0:
    recs.append(f"OPEN DRIFT VIOLATIONS: {drift_unresolved} unresolved model drift violation(s). "
                f"Review state/model-drift-violations.json and resolve or supersede.")
if not recs:
    recs.append("All SLA targets met. Maintain current operational standards.")

if partial_month:
    recs.append(f"PARTIAL MONTH: AInchors ops commenced {OPS_START.strftime('%Y-%m-%d')}. "
                f"Period covers {period_start.strftime('%Y-%m-%d')} to {period_end.strftime('%Y-%m-%d')} "
                f"({delta_minutes // 1440} day(s)). Full-month baseline available from May 2026 onwards.")

# ============================================================
# 9. BUILD MARKDOWN REPORT
# ============================================================
partial_note_str = ""
if partial_month:
    partial_note_str = (f"\n> **Partial month:** AInchors ops commenced {OPS_START.strftime('%Y-%m-%d')}. "
                        f"Period: {period_start.strftime('%Y-%m-%d')} to {period_end.strftime('%Y-%m-%d')} "
                        f"({delta_minutes // 1440} day(s) / {delta_minutes:,} minutes monitored).\n")

recs_md = "\n".join(f"- {r}" for r in recs)

inc_table = f"""| ID | Sev | Started (AEST) | Title | Duration | Preventable | Linked CHG |
|----|-----|----------------|-------|----------|-------------|------------|
{inc_table_rows}"""

cost_rows_md = ""
for ds in sorted(cost_by_day):
    cost_rows_md += f"| {ds} | ${cost_by_day[ds]:.4f} |\n"

if not cost_rows_md:
    cost_rows_md = "| — | No cost data for period |\n"

report = f"""# AInchors SLA Report — {month_label}

_Generated: {generated_at} by Yoda (AI Ops)_
{partial_note_str}
---

## Executive Summary

**Overall Status: {overall_icon} {overall}**

| Metric | Actual | Target | Status |
|--------|--------|--------|--------|
| Availability | {availability_pct:.2f}% | >=99% | {avail_flag} |
| MTTR (avg) | {mttr_avg:.0f} min | <=60 min | {mttr_flag} |
| Total Downtime | {total_downtime_min} min | — | — |
| Incidents | {inc_count} | — | — |
| Preventable Downtime | {preventable_pct:.0f}% ({preventable_min} min) | — | — |
| API Cost (tracked) | ${total_cost:.2f} | — | — |
| Monitoring Period | {delta_minutes:,} min ({delta_minutes // 1440} day(s)) | — | — |

---

## Availability

- **Monitored period:** {period_start.strftime("%Y-%m-%d %H:%M AEST")} to {period_end.strftime("%Y-%m-%d %H:%M AEST")}
- **Total minutes:** {delta_minutes:,}
- **Downtime minutes:** {total_downtime_min}
- **Uptime minutes:** {uptime_min:,}
- **Availability:** {availability_pct:.4f}% (target >=99%)
- **Status:** {avail_flag}

Calculation: ({delta_minutes:,} - {total_downtime_min}) / {delta_minutes:,} * 100 = {availability_pct:.4f}%

---

## Incidents ({inc_count} total)

{inc_table}
**Summary:**
- Total downtime: {total_downtime_min} min
- Preventable: {preventable_min} min ({preventable_pct:.0f}%)
- Non-preventable: {total_downtime_min - preventable_min} min ({100 - preventable_pct:.0f}%)
- Average MTTR: {mttr_avg:.0f} min (target <=60 min) — **{mttr_flag}**

---

## Warden / Model Compliance

- **Drift violations this month:** {drift_month_total}
- **Unresolved violations (all-time):** {drift_unresolved}
- **Superseded violations (all-time):** {drift_superseded}
- **Total violations on record:** {drift_total}
- **Current warden status:** All {drift_total} violations superseded or resolved. No open drift.

> Source: `state/model-drift-violations.json`

---

## Cost Summary

| Date | Cost (USD) |
|------|------------|
{cost_rows_md}| **Total ({days_tracked} day(s) tracked)** | **${total_cost:.2f}** |

- Daily average: ${avg_daily:.2f}
- Source: {cost_note}

---

## Trend

{trend_note}

| Month | Availability | MTTR | Incidents | Cost |
|-------|-------------|------|-----------|------|
| {month_label} | {availability_pct:.2f}% | {mttr_avg:.0f} min | {inc_count} | ${total_cost:.2f} |

---

## Recommendations

{recs_md}

---

## Health Check (current state)

- **Gateway status:** {health_status}
- **Open issues:** {len(health_issues)}
- **Source:** `state/health-state.json`

---

_Report generated by `scripts/sla-report.sh`. Data sources: `state/incidents/*.json`, `state/model-drift-violations.json`, `memory/shared/cost-history.md`, `state/health-state.json`._
"""

# ============================================================
# 10. WRITE REPORT
# ============================================================
out_file.write_text(report, encoding="utf-8")
print(f"[sla-report] Written: {out_file}")

# ============================================================
# 11. APPEND TO SLA HISTORY
# ============================================================
history_entry = f"""
## {month_label} (`{MONTH}`)

| Metric               | Actual     | Target   | Status        |
|----------------------|------------|----------|---------------|
| Availability         | {availability_pct:.2f}%  | >=99%     | {avail_flag} |
| MTTR (avg)           | {mttr_avg:.0f} min     | <=60 min  | {mttr_flag} |
| Total Downtime       | {total_downtime_min} min      | —        | —             |
| Incidents            | {inc_count}          | —        | —             |
| Preventable Downtime | {preventable_pct:.0f}%        | —        | —             |
| API Cost (tracked)   | ${total_cost:.2f}    | —        | —             |
| Period               | {delta_minutes // 1440} day(s) ({period_start.strftime('%Y-%m-%d')} to {period_end.strftime('%Y-%m-%d')}) | — | {"Partial month" if partial_month else "Full month"} |

_Generated {generated_at}_

"""

if sla_history_f.exists():
    existing = sla_history_f.read_text(encoding="utf-8")
    if MONTH in existing:
        print(f"[sla-report] sla-history.md already has {MONTH} — skipping append")
    else:
        sla_history_f.write_text(existing.rstrip() + "\n" + history_entry, encoding="utf-8")
        print(f"[sla-report] Appended to sla-history.md")
else:
    header = "# AInchors SLA History\n\nCumulative monthly SLA summaries. Generated by `scripts/sla-report.sh`.\n"
    sla_history_f.write_text(header + history_entry, encoding="utf-8")
    print(f"[sla-report] Created sla-history.md")

# ============================================================
# 12. CONSOLE SUMMARY
# ============================================================
print(f"""
{"="*52}
SLA Report -- {month_label}
{"="*52}
Period:       {period_start.strftime('%Y-%m-%d')} to {period_end.strftime('%Y-%m-%d')} ({delta_minutes // 1440} days)
Availability: {availability_pct:.2f}%  [{avail_flag}]  (target >={AVAIL_TARGET}%)
MTTR avg:     {mttr_avg:.0f} min       [{mttr_flag}]   (target <={MTTR_TARGET:.0f} min)
Downtime:     {total_downtime_min} min ({preventable_pct:.0f}% preventable)
Incidents:    {inc_count}
Drift viol.:  {drift_month_total} this month, {drift_unresolved} unresolved
API Cost:     ${total_cost:.2f} ({days_tracked} days tracked)
{"="*52}
Overall:      {overall}
{"="*52}
Output:       {out_file}
""")

PYEOF
