#!/usr/bin/env python3
"""ollama-usage-scraper.py — Scrape Ollama Cloud usage dashboard for real request counts.
Uses OpenClaw browser automation to extract data-usage-segment values.
Updates cost-state.json → turnsLimit with live data from Ollama's own dashboard.

Tracks Ollama's TWO native windows:
  - Session: resets every ~6h (shown on dashboard)
  - Weekly: resets Monday 00:00 UTC (Monday 10:00 AEST)

Prerequisites:
  - OpenClaw browser must be running
  - Must be signed into ollama.com in the browser profile
  - Session cookie must be valid

Usage:
  python3 ollama-usage-scraper.py          # update cost-state.json
  python3 ollama-usage-scraper.py --report # print report only
  python3 ollama-usage-scraper.py --dry-run # print report, don't update
"""

import json, os, subprocess, sys, time
from datetime import datetime, timezone, timedelta

WORKSPACE = os.environ.get("WORKSPACE", os.path.expanduser("~/.openclaw/workspace"))
COST_STATE = os.path.join(WORKSPACE, "state/cost-state.json")
AEST = timezone(timedelta(hours=10))

MODE = "update"
if "--report" in sys.argv:
    MODE = "report"
elif "--dry-run" in sys.argv:
    MODE = "dry-run"

def browser(cmd_args):
    """Run an openclaw browser command and return stdout."""
    result = subprocess.run(
        ["openclaw", "browser"] + cmd_args,
        capture_output=True, text=True, timeout=30
    )
    return (result.stdout + result.stderr).strip()

# --- Check browser is running ---
status = browser(["status"])
if "running: true" not in status:
    print("ERROR: Browser not running. Start with: openclaw browser start", file=sys.stderr)
    sys.exit(2)

# --- Navigate to usage page ---
browser(["navigate", "https://ollama.com/settings"])
time.sleep(2)

# --- Check if signed in ---
page_text = browser(["evaluate", "--fn", "() => document.body.innerText.substring(0, 500)"])
if "Sign in" in page_text:
    print("ERROR: Not signed into ollama.com. Sign in first.", file=sys.stderr)
    sys.exit(1)

# --- Extract usage data ---
extract_js = r"""() => {
  const meters = document.querySelectorAll('[data-usage-meter]');
  const result = { session: null, weekly: null, balance: null };

  meters.forEach((meter, i) => {
    const segments = meter.querySelectorAll('[data-usage-segment]');
    const data = { models: {}, total: 0 };

    segments.forEach(seg => {
      const model = seg.dataset.model || '';
      const requests = parseInt(seg.dataset.requests || '0', 10);
      if (model) {
        data.models[model] = requests;
        data.total += requests;
      }
    });

    if (i === 0) result.session = data;
    else if (i === 1) result.weekly = data;
  });

  const body = document.body.innerText;
  const sessionPctMatch = body.match(/Session usage\s+(\d+\.?\d*)%\s+used/);
  const weeklyPctMatch = body.match(/Weekly usage\s+(\d+\.?\d*)%\s+used/);
  if (sessionPctMatch) result.session.pct = parseFloat(sessionPctMatch[1]);
  if (weeklyPctMatch) result.weekly.pct = parseFloat(weeklyPctMatch[1]);

  const timeEls = document.querySelectorAll('[data-time]');
  const resetTimes = [];
  timeEls.forEach(el => {
    const iso = el.dataset.time;
    if (iso) resetTimes.push(iso);
  });
  if (resetTimes.length >= 1) result.session.resetTime = resetTimes[0];
  if (resetTimes.length >= 2) result.weekly.resetTime = resetTimes[1];

  const balanceMatch = body.match(/Balance remaining\s+\$?([\d.]+)/);
  if (balanceMatch) result.balance = parseFloat(balanceMatch[1]);

  return JSON.stringify(result);
}"""

raw_json = browser(["evaluate", "--fn", extract_js])
raw_json = json.loads(raw_json)  # Unwrap outer JSON string quoting
usage = json.loads(raw_json)     # Parse actual data

session = usage.get("session") or {}
weekly = usage.get("weekly") or {}

session_total = session.get("total", 0)
weekly_total = weekly.get("total", 0)
weekly_pct = weekly.get("pct", 0)
session_pct = session.get("pct", 0)
balance = usage.get("balance", 0)
models = weekly.get("models", {})

if weekly_total == 0:
    print(f"ERROR: Failed to extract usage data. Raw: {raw_json[:300]}", file=sys.stderr)
    sys.exit(3)

# --- Compute Ollama's actual limits from usage + percentage ---
SESSION_LIMIT = round(session_total / (session_pct / 100)) if session_pct > 0 else 0
WEEKLY_LIMIT = round(weekly_total / (weekly_pct / 100)) if weekly_pct > 0 else 0

# --- Burn rate since Monday 10:00 AEST (Ollama weekly reset = Mon 00:00 UTC = Mon 10:00 AEST) ---
now = datetime.now(AEST)
days_since_mon = now.weekday()
monday = now - timedelta(days=days_since_mon)
monday = monday.replace(hour=10, minute=0, second=0, microsecond=0)
hours_elapsed = (now - monday).total_seconds() / 3600
burn_rate = round(weekly_total / hours_elapsed, 1) if hours_elapsed > 0 else 0

# --- Projected exhaustion of Ollama weekly limit ---
weekly_remaining = WEEKLY_LIMIT - weekly_total
if burn_rate > 0 and weekly_remaining > 0:
    hours_to_exhaust = weekly_remaining / burn_rate
    exhaust_dt = now + timedelta(hours=hours_to_exhaust)
    proj_exhaust = exhaust_dt.strftime("%Y-%m-%dT%H:%M:%S%z")
else:
    proj_exhaust = "N/A"

# --- Session remaining ---
session_remaining = SESSION_LIMIT - session_total

window_start = monday.strftime("%Y-%m-%dT%H:%M:%S%z")
window_end = (monday + timedelta(days=7)).strftime("%Y-%m-%dT%H:%M:%S%z")
now_iso = now.strftime("%Y-%m-%dT%H:%M:%S%z")

# --- Report mode ---
if MODE in ("report", "dry-run"):
    print("=== Ollama Cloud Usage (from dashboard) ===")
    print(f"Scraped at: {now_iso}")
    print()
    print("--- Session Window ---")
    print(f"Used: {session_total} / ~{SESSION_LIMIT} requests ({session_pct}%)")
    print(f"Remaining: ~{session_remaining}")
    print(f"Resets: {session.get('resetTime', 'unknown')}")
    print()
    print("--- Weekly Window ---")
    print(f"Used: {weekly_total} / ~{WEEKLY_LIMIT} requests ({weekly_pct}%)")
    print(f"Remaining: ~{weekly_remaining}")
    print(f"Burn rate: {burn_rate} req/hr")
    print(f"Projected exhaustion: {proj_exhaust}")
    print(f"Resets: {weekly.get('resetTime', 'unknown')}")
    print()
    print(f"Balance: ${balance}")
    print()
    print("By model (weekly):")
    for m, c in sorted(models.items(), key=lambda x: -x[1]):
        pct_of_limit = round(c * 100 / WEEKLY_LIMIT, 1) if WEEKLY_LIMIT > 0 else 0
        print(f"  {m:<35} {c:>6} requests  ({pct_of_limit:>5.1f}% of weekly limit)")
    if MODE == "dry-run":
        print()
        print("[DRY RUN — cost-state.json NOT updated]")
    sys.exit(0)

# --- Update cost-state.json ---
if not os.path.exists(COST_STATE):
    print(f"ERROR: cost-state.json not found at {COST_STATE}", file=sys.stderr)
    sys.exit(4)

with open(COST_STATE) as f:
    state = json.load(f)

tl = state.setdefault("turnsLimit", {})

# Ollama's two windows
tl["session"] = {
    "requests": session_total,
    "limit": SESSION_LIMIT,
    "pct": session_pct,
    "remaining": session_remaining,
    "resetTime": session.get("resetTime", ""),
}
tl["weekly"] = {
    "requests": weekly_total,
    "limit": WEEKLY_LIMIT,
    "pct": weekly_pct,
    "remaining": weekly_remaining,
    "burnRateRequestsPerHour": burn_rate,
    "projectedExhaustion": proj_exhaust,
    "windowStart": window_start,
    "windowEnd": window_end,
    "resetTime": weekly.get("resetTime", ""),
}

# Top-level convenience fields (for backward compat with request-budget-check.sh)
tl["weeklyLimit"] = WEEKLY_LIMIT  # backward compat for request-budget-check.sh
tl["currentRequests"] = weekly_total  # mirror of weekly.requests for old consumers
tl["currentPct"] = weekly_pct
tl["requestsRemaining"] = weekly_remaining
tl["burnRateRequestsPerHour"] = burn_rate
tl["projectedExhaustion"] = proj_exhaust
tl["currentWindowStart"] = window_start
tl["currentWindowEnd"] = window_end
tl["lastUpdated"] = now_iso
tl["byModel"] = models
tl["modelBreakdown"] = models
tl["balance"] = balance
tl["countingMethod"] = "ollama-dashboard-scrape"
tl["countingLimitation"] = "Scraped from ollama.com/settings via browser automation. Requires valid login session. Accuracy: source of truth (Ollama's own dashboard)."

with open(COST_STATE, "w") as f:
    json.dump(state, f, indent=2)

print(f"OK: cost-state.json updated from Ollama dashboard — session={session_total}/{SESSION_LIMIT} ({session_pct}%) | weekly={weekly_total}/{WEEKLY_LIMIT} ({weekly_pct}%) | balance=${balance} | {now_iso}")
sys.exit(0)
