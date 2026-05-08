# TKT-0092 Output — FinOps Per-Agent Budget Limits + Workflow Cost Caps

**Completed:** 2026-05-08T08:12 AEST  
**CHG:** CHG-0237  
**Cron ID:** 3ea986bf-5dfc-4805-a13c-80427b4d29c7

---

## Deliverables

| # | Deliverable | Status |
|---|-------------|--------|
| 1 | `state/agent-budgets.json` | ✅ Created |
| 2 | `scripts/budget-check.sh` | ✅ Created (chmod 700) |
| 3 | `scripts/cost-tracker.sh` — `estimate_workflow_cost()` added | ✅ Updated |
| 4 | `HEARTBEAT.md` — Budget Check section added | ✅ Updated |
| 5 | Daily budget report cron (7:55 AM AEST) | ✅ Registered |
| 6 | `budget-check.sh --report` output | ✅ See below |

---

## budget-check.sh --report Output (2026-05-08)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  AInchors Budget Report — 2026-05-08
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  AGENT              TODAY     BUDGET        %       STATUS
  ────────────── ────────── ────────── ──────── ────────────
  [PLATFORM]       $15.6351       $200     7.8%       ✅ OK
  architect         $1.3274        $10    13.3%       ✅ OK
  business          $6.9632        $30    23.2%       ✅ OK
  governance        $1.0137         $5    20.3%       ✅ OK
  infra            $14.3825         $5   287.6% ❌ EXCEEDED
  legal             $0.7357         $3    24.5%       ✅ OK
  main             $54.9347        $80    68.7%       ✅ OK
  platform-arch     $1.3293        $10    13.3%       ✅ OK
  qa                $0.7582         $3    25.3%       ✅ OK
  security          $0.8179         $3    27.3%       ✅ OK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Key Finding: infra Agent Budget Needs Calibration

`infra` is at $14.38 vs $5/day budget (287%) — EXCEEDED.

**Root cause:** `infra` runs many scheduled crons (backup, CI cycles, asset review, midday cost, allowlist sync, fallback forge). The $5/day initial budget is too low for actual infra workload.

**Recommendation:** Increase `infra` dailyBudgetUsd to $20–$25 in `state/agent-budgets.json`. Ken to approve.

---

## Architecture Notes

- **Per-agent cost tracking:** Budget check reads individual agent session logs (JSONL) to derive per-agent spend. No platform-level per-agent aggregation yet — tracked per-session per-agent only.
- **Workflow cost estimation:** `estimate_workflow_cost()` uses 7-day platform daily average as proxy. True per-workflow isolation requires session tagging (future US).
- **Alert state:** Written to `state/budget-alert-state.json` on every run.
- **Cron:** Daily at 07:55 AEST, Haiku model, 60s timeout, isolated session, Telegram alert to Ken on EXCEEDED.
