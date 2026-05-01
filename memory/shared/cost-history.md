# AInchors Cost History
_Token costs by day. Source: OpenClaw session logs._

Gemma4 (Ollama) = $0.00 always (local). Cloud costs = Anthropic API.

## 2026-04-25

| Metric | Value |
|--------|-------|
| Total Cost | $25.7494 |
| Turns | 416 |
| Input Tokens | 583 |
| Output Tokens | 160,704 |
| Cache Read | 32,176,831 |

### By Model
- **claude-sonnet-4-6**: 416 turns | 583 in / 160,704 out | $25.7494

## 2026-04-26

| Metric | Value |
|--------|-------|
| Total Cost | $37.1455 |
| Turns | 499 |
| Input Tokens | 663 |
| Output Tokens | 208,682 |
| Cache Read | 33,156,717 |
| Cache Write | 6,417,667 |

### By Model
- **claude-sonnet-4-6**: 499 turns | 663 in / 208,682 out | $37.1455

> **Source:** `state/cost-state.json` (direct — cost-tracker.sh was returning stale partial output today; US22 raised to fix parsing)

### Cost Tracker Note
⚠️ `cost-tracker.sh` script produced stale output for Day 2 ($5.58 / 138 turns mid-day snapshot). Actual Day 2 figures sourced directly from `state/cost-state.json`. New backlog item: **US22 — Fix cost tracker script (session log parsing broken)**.

### API Balance Alert
⚠️ Remaining balance: **$7.31 USD** (as of 2026-04-26 EOD). Below 75% threshold. At current burn rate (~$37/day), approximately 5 hours runway. **Top-up required.**

### All-Time Summary
| Date | Cost | Turns | Cost/Turn |
|------|------|-------|-----------|
| 2026-04-25 | $25.75 | 416 | $0.062 |
| 2026-04-26 | $37.15 | 499 | $0.074 |
| **Total** | **$62.89** | **915** | **$0.069 avg** |

## 2026-04-27

| Metric | Value |
|--------|-------|
| Total Cost | $0.0000 |
| Turns | 0 |
| Input Tokens | 0 |
| Output Tokens | 0 |
| Cache Read | 0 |

### By Model

## 2026-04-28

| Metric | Value |
|--------|-------|
| Total Cost (Tracker) | $338.7606 USD |
| Partial CSV Actual (until 18:39) | $150.86 USD |
| Turns | 2,191 |
| Input Tokens | 7,637 |
| Output Tokens | 1,050,948 |
| Cache Read | 313,716,128 |
| Cache Write | 62,229,979 |
| Balance Remaining | $58.72 USD |

### By Model
- **claude-sonnet-4-6**: 1,732 turns | $335.60
- **claude-haiku-4-5**: 452 turns | $2.40 (Tier 2 — first live day)
- **claude-opus-4-7**: 4 turns | $0.76

### Cost Tracker Note
⚠️ Tracker overcounts due to `input_cache_write_5m` tokens. US38 filed to switch to Anthropic billing API as ground truth. Partial Anthropic CSV actual for Day 4 (until 18:39 AEST) = $150.86 USD. Haiku Tier 2 live — $2.40 for 452 governance/health cron runs.

### 4-Day Summary (Anthropic CSV ground truth)
| Date | Cost | Notes |
|------|------|-------|
| 2026-04-25 | $49.94 | Foundation |
| 2026-04-26 | $82.84 | Opus drift = $17 |
| 2026-04-27 | $121.26 | Resiliency day |
| 2026-04-28 | $150.86+ | Governance + frameworks |
| **Total** | **$404.90+** | **4-day cumulative** |

Avg: ~$101/day. Balance at 2026-04-28 EOD: $58.72 USD.

## 2026-04-29

| Metric | Value |
|--------|-------|
| Total Cost | $3.3841 |
| Turns | 164 |
| Input Tokens | 810 |
| Output Tokens | 44,401 |
| Cache Read | 4,021,745 |

### By Model
- **claude-sonnet-4-6**: 106 turns | 156 in / 33,576 out | $3.0960
- **claude-haiku-4-5**: 58 turns | 654 in / 10,825 out | $0.2881

## 2026-04-30

| Metric | Value |
|--------|-------|
| Total Cost | $0.0000 |
| Turns | 0 |
| Input Tokens | 0 |
| Output Tokens | 0 |
| Cache Read | 0 |

### By Model

## 2026-05-01

| Metric | Value |
|--------|-------|
| Total Cost | $7.4330 |
| Turns | 394 |
| Input Tokens | 439,892 |
| Output Tokens | 49,166 |
| Cache Read | 9,725,652 |

### By Stream
- **technical**: 393 turns | $7.4330
- **business**: 1 turns | $0.0000

### By Model
- **claude-sonnet-4-6**: 302 turns | 516 in / 36,580 out | $7.1786
- **claude-haiku-4-5**: 59 turns | 649 in / 10,217 out | $0.2544
- **delivery-mirror**: 1 turns | 0 in / 0 out | $0.0000
- **gemma4:e2b**: 32 turns | 438,727 in / 2,369 out | $0.0000
