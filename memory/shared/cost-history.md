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

## 2026-05-02

| Metric | Value |
|--------|-------|
| Total Cost | $28.9958 |
| Turns | 664 |
| Input Tokens | 1,863 |
| Output Tokens | 250,826 |
| Cache Read | 27,561,086 |

### By Stream
- **technical**: 636 turns | $28.1918
- **business**: 28 turns | $0.8040

### By Model
- **claude-sonnet-4-6**: 573 turns | 887 in / 237,481 out | $28.7210
- **claude-haiku-4-5**: 89 turns | 976 in / 13,345 out | $0.2748
- **gateway-injected**: 2 turns | 0 in / 0 out | $0.0000

## 2026-05-03

| Metric | Value |
|--------|-------|
| Total Cost | $0.0000 |
| Turns | 0 |
| Input Tokens | 0 |
| Output Tokens | 0 |
| Cache Read | 0 |

### By Stream

### By Model

## 2026-05-04

| Metric | Value |
|--------|-------|
| Total Cost | $32.8365 |
| Turns | 936 |
| Input Tokens | 815,927 |
| Output Tokens | 224,421 |
| Cache Read | 26,996,843 |

### By Stream
- **technical**: 715 turns | $26.4441
- **governance**: 139 turns | $4.3586
- **business**: 82 turns | $2.0337

### By Model
- **claude-sonnet-4-6**: 816 turns | 1,434 in / 197,014 out | $32.3265
- **claude-haiku-4-5**: 97 turns | 1,076 in / 17,175 out | $0.5100
- **gemma4:e2b**: 1 turns | 12,412 in / 35 out | $0.0000
- **deepseek-v4-pro:cloud**: 22 turns | 801,005 in / 10,197 out | $0.0000

## 2026-05-05

| Metric | Value |
|--------|-------|
| Total Cost | $26.6520 |
| Turns | 961 |
| Input Tokens | 361,864 |
| Output Tokens | 116,035 |
| Cache Read | 11,871,387 |

### By Stream
- **technical**: 645 turns | $17.4011
- **governance**: 208 turns | $6.6066
- **business**: 108 turns | $2.6443

### By Model
- **claude-sonnet-4-6**: 869 turns | 1,791 in / 94,655 out | $26.2799
- **claude-haiku-4-5**: 84 turns | 933 in / 14,075 out | $0.3721
- **gemma4:e2b**: 1 turns | 12,428 in / 35 out | $0.0000
- **deepseek-v4-pro:cloud**: 7 turns | 346,712 in / 7,270 out | $0.0000

## 2026-05-06

| Metric | Value |
|--------|-------|
| Total Cost | $7.2163 |
| Turns | 607 |
| Input Tokens | 303,806 |
| Output Tokens | 90,402 |
| Cache Read | 9,298,279 |

### By Stream
- **technical**: 425 turns | $4.7655
- **business**: 76 turns | $1.7338
- **governance**: 106 turns | $0.7170

### By Model
- **claude-sonnet-4-6**: 551 turns | 1,159 in / 71,589 out | $7.0047
- **claude-haiku-4-5**: 47 turns | 522 in / 8,418 out | $0.2116
- **deepseek-v4-pro:cloud**: 9 turns | 302,125 in / 10,395 out | $0.0000

## 2026-05-07

| Metric | Value |
|--------|-------|
| Total Cost | $0.0000 |
| Turns | 0 |
| Input Tokens | 0 |
| Output Tokens | 0 |
| Cache Read | 0 |

### By Stream

### By Model

## 2026-05-08

| Metric | Value |
|--------|-------|
| Total Cost | $15.6351 |
| Turns | 1156 |
| Input Tokens | 311,941 |
| Output Tokens | 240,962 |
| Cache Read | 19,931,647 |

### By Stream
- **technical**: 794 turns | $13.0635
- **business**: 105 turns | $1.8466
- **governance**: 257 turns | $0.7250

### By Model
- **claude-sonnet-4-6**: 839 turns | 1,575 in / 191,312 out | $14.7083
- **claude-haiku-4-5**: 308 turns | 3,515 in / 41,719 out | $0.9268
- **deepseek-v4-pro:cloud**: 8 turns | 296,364 in / 7,896 out | $0.0000
- **gemma4:e2b**: 1 turns | 10,487 in / 35 out | $0.0000

## 2026-05-09

| Metric | Value |
|--------|-------|
| Total Cost | $14.8555 |
| Turns | 1059 |
| Input Tokens | 636,177 |
| Output Tokens | 215,103 |
| Cache Read | 19,288,694 |

### By Stream
- **technical**: 687 turns | $12.7218
- **business**: 94 turns | $1.3840
- **governance**: 278 turns | $0.7498

### By Model
- **claude-sonnet-4-6**: 727 turns | 1,367 in / 163,228 out | $13.9572
- **claude-haiku-4-5**: 310 turns | 3,547 in / 41,978 out | $0.8983
- **gemma4:e2b**: 1 turns | 10,487 in / 35 out | $0.0000
- **deepseek-v4-pro:cloud**: 11 turns | 490,686 in / 8,627 out | $0.0000
- **kimi-k2.6:cloud**: 10 turns | 130,090 in / 1,235 out | $0.0000

## 2026-05-10

| Metric | Value |
|--------|-------|
| Total Cost | $37.2932 |
| Turns | 1032 |
| Input Tokens | 589,609 |
| Output Tokens | 298,192 |
| Cache Read | 39,939,991 |

### By Stream
- **technical**: 681 turns | $34.5472
- **business**: 113 turns | $1.7692
- **governance**: 238 turns | $0.9769

### By Model
- **claude-sonnet-4-6**: 741 turns | 1,259 in / 255,177 out | $36.2813
- **claude-haiku-4-5**: 279 turns | 3,197 in / 37,644 out | $1.0119
- **gemma4:e2b**: 1 turns | 10,488 in / 35 out | $0.0000
- **deepseek-v4-pro:cloud**: 11 turns | 574,665 in / 5,336 out | $0.0000

## --report

| Metric | Value |
|--------|-------|
| Total Cost | $0.0000 |
| Turns | 0 |
| Input Tokens | 0 |
| Output Tokens | 0 |
| Cache Read | 0 |

### By Stream

### By Model

## 2026-05-11

| Metric | Value |
|--------|-------|
| Total Cost | $32.4814 |
| Turns | 980 |
| Input Tokens | 979,690 |
| Output Tokens | 261,796 |
| Cache Read | 31,090,066 |

### By Stream
- **technical**: 591 turns | $26.3577
- **business**: 115 turns | $5.3147
- **governance**: 274 turns | $0.8090

### By Model
- **claude-sonnet-4-6**: 662 turns | 1,222 in / 214,495 out | $31.6065
- **claude-haiku-4-5**: 305 turns | 3,488 in / 40,985 out | $0.8750
- **deepseek-v4-pro:cloud**: 13 turns | 974,980 in / 6,316 out | $0.0000

## 2026-05-12

| Metric | Value |
|--------|-------|
| Total Cost | $53.5024 |
| Turns | 733 |
| Input Tokens | 1,284,175 |
| Output Tokens | 279,520 |
| Cache Read | 56,830,263 |

### By Stream
- **technical**: 644 turns | $49.3130
- **business**: 89 turns | $4.1893

### By Model
- **claude-sonnet-4-6**: 605 turns | 915 in / 237,528 out | $52.7267
- **claude-haiku-4-5**: 87 turns | 987 in / 33,544 out | $0.7756
- **deepseek-v4-pro:cloud**: 14 turns | 807,134 in / 5,040 out | $0.0000
- **kimi-k2.6:cloud**: 27 turns | 475,139 in / 3,408 out | $0.0000

## 2026-05-13

| Metric | Value |
|--------|-------|
| Total Cost | $90.0303 |
| Turns | 3277 |
| Input Tokens | 3,424,548 |
| Output Tokens | 900,091 |
| Cache Read | 100,278,020 |

### By Stream
- **technical**: 2780 turns | $82.9378
- **business**: 497 turns | $7.0926

### By Model
- **claude-sonnet-4-6**: 2586 turns | 4,294 in / 637,205 out | $83.8583
- **claude-haiku-4-5**: 609 turns | 6,813 in / 244,361 out | $6.1720
- **deepseek-v4-pro:cloud**: 42 turns | 2,058,120 in / 10,092 out | $0.0000
- **gateway-injected**: 1 turns | 0 in / 0 out | $0.0000
- **kimi-k2.6:cloud**: 39 turns | 1,355,321 in / 8,433 out | $0.0000
