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

## 2026-05-14

| Metric | Value |
|--------|-------|
| Total Cost | $27.2698 |
| Turns | 466 |
| Input Tokens | 637,543 |
| Output Tokens | 158,000 |
| Cache Read | 21,002,722 |

### By Stream
- **technical**: 406 turns | $26.3484
- **business**: 60 turns | $0.9214

### By Model
- **claude-sonnet-4-6**: 388 turns | 624 in / 124,805 out | $26.7605
- **claude-haiku-4-5**: 68 turns | 761 in / 29,687 out | $0.5093
- **deepseek-v4-pro:cloud**: 10 turns | 636,158 in / 3,508 out | $0.0000

## 2026-05-15

| Metric | Value |
|--------|-------|
| Total Cost | $191.3396 |
| Turns | 1079 |
| Input Tokens | 9,990,579 |
| Output Tokens | 492,849 |
| Cache Read | 119,012,113 |

### By Stream
- **technical**: 1068 turns | $190.9687
- **business**: 11 turns | $0.3709

### By Model
- **claude-sonnet-4-6**: 622 turns | 948 in / 370,564 out | $190.1018
- **claude-haiku-4-5**: 246 turns | 2,829 in / 75,571 out | $1.2379
- **deepseek-v4-pro:cloud**: 14 turns | 940,581 in / 3,598 out | $0.0000
- **kimi-k2.6:cloud**: 197 turns | 9,046,221 in / 43,116 out | $0.0000

## 2026-05-16

| Metric | Value |
|--------|-------|
| Total Cost | $7.6272 |
| Turns | 2668 |
| Input Tokens | 46,536,735 |
| Output Tokens | 544,338 |
| Cache Read | 20,668,609 |
| Calculated Cost (ephemeral) | $0.0000 |
| Calculated Turns | 0 |

### By Stream
- **technical**: 2605 turns | $7.5703
- **business**: 63 turns | $0.0569

### By Model
- **claude-haiku-4-5**: 1716 turns | 19,579 in / 407,867 out | $7.6272
- **deepseek-v4-pro:cloud**: 52 turns | 3,673,587 in / 16,123 out | $0.0000
- **kimi-k2.6:cloud**: 900 turns | 42,843,569 in / 120,348 out | $0.0000

## 2026-05-17

| Metric | Value |
|--------|-------|
| Total Cost | $0.0333 |
| Turns | 473 |
| Input Tokens | 19,634,886 |
| Output Tokens | 99,148 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0333 |
| Calculated Turns | 4 |

### By Stream
- **technical**: 467 turns | $0.0333
- **business**: 6 turns | $0.0000

### By Model
- **claude-haiku-4-5**: 4 turns | 0 in / 0 out | $0.0333 (calc: 4 turns @ $0.0333)
- **deepseek-v4-pro:cloud**: 17 turns | 829,859 in / 4,526 out | $0.0000
- **kimi-k2.6:cloud**: 451 turns | 18,805,027 in / 94,622 out | $0.0000
- **gemma4:26b**: 1 turns | 0 in / 0 out | $0.0000

## 2026-05-18

| Metric | Value |
|--------|-------|
| Total Cost | $0.0000 |
| Turns | 648 |
| Input Tokens | 34,287,501 |
| Output Tokens | 112,204 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0000 |
| Calculated Turns | 0 |

### By Stream
- **technical**: 636 turns | $0.0000
- **business**: 12 turns | $0.0000

### By Model
- **deepseek-v4-pro:cloud**: 479 turns | 32,274,734 in / 97,988 out | $0.0000
- **gemma4:31b-cloud**: 165 turns | 2,012,767 in / 14,216 out | $0.0000
- **delivery-mirror**: 4 turns | 0 in / 0 out | $0.0000

## 2026-05-19

| Metric | Value |
|--------|-------|
| Total Cost | $0.0000 |
| Turns | 791 |
| Input Tokens | 21,126,894 |
| Output Tokens | 63,939 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0000 |
| Calculated Turns | 0 |

### By Stream
- **technical**: 751 turns | $0.0000
- **business**: 40 turns | $0.0000

### By Model
- **gemma4:31b-cloud**: 333 turns | 1,732,627 in / 8,209 out | $0.0000
- **kimi-k2.6:cloud**: 178 turns | 0 in / 0 out | $0.0000
- **deepseek-v4-pro:cloud**: 264 turns | 19,394,267 in / 55,730 out | $0.0000
- **delivery-mirror**: 16 turns | 0 in / 0 out | $0.0000

## 2026-05-20

| Metric | Value |
|--------|-------|
| Total Cost | $0.0000 |
| Turns | 2333 |
| Input Tokens | 28,288,917 |
| Output Tokens | 136,238 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0000 |
| Calculated Turns | 0 |

### By Stream
- **technical**: 2145 turns | $0.0000
- **business**: 188 turns | $0.0000

### By Model
- **gemma4:31b-cloud**: 1574 turns | 12,599,744 in / 43,730 out | $0.0000
- **kimi-k2.6:cloud**: 294 turns | 0 in / 0 out | $0.0000
- **deepseek-v4-flash:cloud**: 18 turns | 391,347 in / 3,301 out | $0.0000
- **deepseek-v4-pro:cloud**: 435 turns | 15,297,826 in / 89,207 out | $0.0000
- **glm-5.1:cloud**: 4 turns | 0 in / 0 out | $0.0000
- **delivery-mirror**: 8 turns | 0 in / 0 out | $0.0000

## 2026-05-21

| Metric | Value |
|--------|-------|
| Total Cost | $0.0000 |
| Turns | 428 |
| Input Tokens | 8,882,143 |
| Output Tokens | 54,901 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0000 |
| Calculated Turns | 0 |

### By Stream
- **technical**: 418 turns | $0.0000
- **business**: 10 turns | $0.0000

### By Model
- **gemma4:31b-cloud**: 314 turns | 3,119,454 in / 25,296 out | $0.0000
- **deepseek-v4-pro:cloud**: 97 turns | 5,625,038 in / 27,161 out | $0.0000
- **delivery-mirror**: 5 turns | 0 in / 0 out | $0.0000
- **kimi-k2.6:cloud**: 12 turns | 137,651 in / 2,444 out | $0.0000

## 2026-05-22

| Metric | Value |
|--------|-------|
| Total Cost | $0.0000 |
| Turns | 86 |
| Input Tokens | 3,373,602 |
| Output Tokens | 21,943 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0000 |
| Calculated Turns | 0 |

### By Stream
- **technical**: 44 turns | $0.0000
- **business**: 42 turns | $0.0000

### By Model
- **deepseek-v4-pro:cloud**: 84 turns | 3,373,602 in / 21,943 out | $0.0000
- **delivery-mirror**: 2 turns | 0 in / 0 out | $0.0000

## --quick

| Metric | Value |
|--------|-------|
| Total Cost | $0.0000 |
| Turns | 0 |
| Input Tokens | 0 |
| Output Tokens | 0 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0000 |
| Calculated Turns | 0 |

### By Stream

### By Model

## --estimate

| Metric | Value |
|--------|-------|
| Total Cost | $0.0000 |
| Turns | 0 |
| Input Tokens | 0 |
| Output Tokens | 0 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0000 |
| Calculated Turns | 0 |

### By Stream

### By Model

## 2026-05-23

| Metric | Value |
|--------|-------|
| Total Cost | $0.0000 |
| Turns | 583 |
| Input Tokens | 13,445,852 |
| Output Tokens | 56,327 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0000 |
| Calculated Turns | 0 |

### By Stream
- **technical**: 570 turns | $0.0000
- **business**: 13 turns | $0.0000

### By Model
- **gemma4:31b-cloud**: 378 turns | 3,725,087 in / 13,019 out | $0.0000
- **deepseek-v4-flash:cloud**: 2 turns | 12,569 in / 113 out | $0.0000
- **deepseek-v4-pro:cloud**: 191 turns | 9,530,155 in / 39,234 out | $0.0000
- **kimi-k2.6:cloud**: 12 turns | 178,041 in / 3,961 out | $0.0000

## 2026-05-24

| Metric | Value |
|--------|-------|
| Total Cost | $0.0000 |
| Turns | 0 |
| Input Tokens | 0 |
| Output Tokens | 0 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0000 |
| Calculated Turns | 0 |

### By Stream

### By Model

## --check

| Metric | Value |
|--------|-------|
| Total Cost | $0.0000 |
| Turns | 0 |
| Input Tokens | 0 |
| Output Tokens | 0 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0000 |
| Calculated Turns | 0 |

### By Stream

### By Model

## 2026-05-25

| Metric | Value |
|--------|-------|
| Total Cost | $0.0000 |
| Turns | 627 |
| Input Tokens | 32,741,717 |
| Output Tokens | 61,832 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0000 |
| Calculated Turns | 0 |

### By Stream
- **technical**: 618 turns | $0.0000
- **business**: 9 turns | $0.0000

### By Model
- **gemma4:31b-cloud**: 391 turns | 3,845,842 in / 15,799 out | $0.0000
- **deepseek-v4-pro:cloud**: 231 turns | 28,843,397 in / 44,651 out | $0.0000
- **kimi-k2.6:cloud**: 5 turns | 52,478 in / 1,382 out | $0.0000

## 2026-05-26

| Metric | Value |
|--------|-------|
| Total Cost | $0.0000 |
| Turns | 497 |
| Input Tokens | 5,150,612 |
| Output Tokens | 28,971 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0000 |
| Calculated Turns | 0 |

### By Stream
- **technical**: 483 turns | $0.0000
- **business**: 14 turns | $0.0000

### By Model
- **gemma4:31b-cloud**: 369 turns | 3,332,180 in / 10,659 out | $0.0000
- **deepseek-v4-pro:cloud**: 110 turns | 1,566,688 in / 15,921 out | $0.0000
- **kimi-k2.6:cloud**: 18 turns | 251,744 in / 2,391 out | $0.0000

## 2026-05-27

| Metric | Value |
|--------|-------|
| Total Cost | $0.0000 |
| Turns | 1026 |
| Input Tokens | 53,931,626 |
| Output Tokens | 154,122 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0000 |
| Calculated Turns | 0 |

### By Stream
- **technical**: 1011 turns | $0.0000
- **business**: 15 turns | $0.0000

### By Model
- **gemma4:31b-cloud**: 674 turns | 34,014,391 in / 100,413 out | $0.0000
- **deepseek-v4-pro:cloud**: 329 turns | 19,675,958 in / 48,834 out | $0.0000
- **kimi-k2.6:cloud**: 16 turns | 241,277 in / 4,875 out | $0.0000
- **delivery-mirror**: 7 turns | 0 in / 0 out | $0.0000

## 2026-05-28

| Metric | Value |
|--------|-------|
| Total Cost | $0.4839 |
| Turns | 518 |
| Input Tokens | 15,005,740 |
| Output Tokens | 57,202 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.4839 |
| Calculated Turns | 518 |

### By Stream
- **technical**: 505 turns | $0.4652
- **business**: 13 turns | $0.0187

### By Model
- **deepseek-v4-pro:cloud**: 293 turns | 12,869,365 in / 49,396 out | $0.4215 (calc: 293 turns @ $0.4215)
- **gemma4:31b-cloud**: 216 turns | 2,014,924 in / 5,993 out | $0.0474 (calc: 216 turns @ $0.0474)
- **kimi-k2.6:cloud**: 9 turns | 121,451 in / 1,813 out | $0.0150 (calc: 9 turns @ $0.0150)

## 2026-05-29

| Metric | Value |
|--------|-------|
| Total Cost | $0.3510 |
| Turns | 429 |
| Input Tokens | 8,884,305 |
| Output Tokens | 48,282 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.3510 |
| Calculated Turns | 428 |

### By Stream
- **technical**: 414 turns | $0.3294
- **business**: 15 turns | $0.0216

### By Model
- **deepseek-v4-pro:cloud**: 199 turns | 6,672,696 in / 40,836 out | $0.2863 (calc: 199 turns @ $0.2863)
- **gemma4:31b-cloud**: 219 turns | 2,100,324 in / 5,970 out | $0.0480 (calc: 219 turns @ $0.0480)
- **kimi-k2.6:cloud**: 10 turns | 111,285 in / 1,476 out | $0.0167 (calc: 10 turns @ $0.0167)
- **delivery-mirror**: 1 turns | 0 in / 0 out | $0.0000

## 2026-05-30

| Metric | Value |
|--------|-------|
| Total Cost | $0.2780 |
| Turns | 395 |
| Input Tokens | 5,289,828 |
| Output Tokens | 22,408 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.2780 |
| Calculated Turns | 395 |

### By Stream
- **technical**: 381 turns | $0.2578
- **business**: 14 turns | $0.0201

### By Model
- **deepseek-v4-pro:cloud**: 151 turns | 2,380,774 in / 12,521 out | $0.2172 (calc: 151 turns @ $0.2172)
- **gemma4:31b-cloud**: 239 turns | 2,847,189 in / 8,094 out | $0.0524 (calc: 239 turns @ $0.0524)
- **kimi-k2.6:cloud**: 5 turns | 61,865 in / 1,793 out | $0.0083 (calc: 5 turns @ $0.0083)

## 2026-05-31

| Metric | Value |
|--------|-------|
| Total Cost | $0.2690 |
| Turns | 362 |
| Input Tokens | 4,577,526 |
| Output Tokens | 19,215 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.2690 |
| Calculated Turns | 362 |

### By Stream
- **technical**: 346 turns | $0.2460
- **business**: 16 turns | $0.0230

### By Model
- **deepseek-v4-pro:cloud**: 146 turns | 2,288,201 in / 11,360 out | $0.2100 (calc: 146 turns @ $0.2100)
- **gemma4:31b-cloud**: 208 turns | 2,191,112 in / 5,769 out | $0.0456 (calc: 208 turns @ $0.0456)
- **kimi-k2.6:cloud**: 8 turns | 98,213 in / 2,086 out | $0.0133 (calc: 8 turns @ $0.0133)

## 2026-06-01

| Metric | Value |
|--------|-------|
| Total Cost | $0.4638 |
| Turns | 486 |
| Input Tokens | 9,434,496 |
| Output Tokens | 48,374 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.4638 |
| Calculated Turns | 486 |

### By Stream
- **technical**: 426 turns | $0.3775
- **business**: 60 turns | $0.0863

### By Model
- **deepseek-v4-pro:cloud**: 255 turns | 6,614,552 in / 34,881 out | $0.3668 (calc: 255 turns @ $0.3668)
- **kimi-k2.6:cloud**: 32 turns | 632,944 in / 4,489 out | $0.0534 (calc: 32 turns @ $0.0534)
- **gemma4:31b-cloud**: 199 turns | 2,187,000 in / 9,004 out | $0.0436 (calc: 199 turns @ $0.0436)

## 2026-06-02

| Metric | Value |
|--------|-------|
| Total Cost | $0.5066 |
| Turns | 382 |
| Input Tokens | 9,332,567 |
| Output Tokens | 36,749 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.5066 |
| Calculated Turns | 373 |

### By Stream
- **technical**: 360 turns | $0.4749
- **business**: 22 turns | $0.0316

### By Model
- **deepseek-v4-pro:cloud**: 327 turns | 8,922,038 in / 33,342 out | $0.4704 (calc: 327 turns @ $0.4704)
- **kimi-k2.6:cloud**: 18 turns | 213,737 in / 2,067 out | $0.0300 (calc: 18 turns @ $0.0300)
- **gemma4:31b-cloud**: 28 turns | 196,792 in / 1,340 out | $0.0061 (calc: 28 turns @ $0.0061)
- **delivery-mirror**: 9 turns | 0 in / 0 out | $0.0000

## 2026-06-03

| Metric | Value |
|--------|-------|
| Total Cost | $0.4230 |
| Turns | 308 |
| Input Tokens | 5,077,507 |
| Output Tokens | 30,075 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.4230 |
| Calculated Turns | 306 |

### By Stream
- **technical**: 277 turns | $0.3813
- **business**: 31 turns | $0.0417

### By Model
- **deepseek-v4-pro:cloud**: 280 turns | 4,832,822 in / 27,829 out | $0.4028 (calc: 280 turns @ $0.4028)
- **kimi-k2.6:cloud**: 10 turns | 146,543 in / 1,802 out | $0.0167 (calc: 10 turns @ $0.0167)
- **gemma4:31b-cloud**: 16 turns | 98,142 in / 444 out | $0.0035 (calc: 16 turns @ $0.0035)
- **delivery-mirror**: 2 turns | 0 in / 0 out | $0.0000

## 2026-06-04

| Metric | Value |
|--------|-------|
| Total Cost | $0.5194 |
| Turns | 374 |
| Input Tokens | 12,396,308 |
| Output Tokens | 50,225 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.5194 |
| Calculated Turns | 374 |

### By Stream
- **technical**: 364 turns | $0.5050
- **business**: 10 turns | $0.0144

### By Model
- **deepseek-v4-pro:cloud**: 354 turns | 12,255,495 in / 48,052 out | $0.5092 (calc: 354 turns @ $0.5092)
- **kimi-k2.6:cloud**: 4 turns | 42,671 in / 1,729 out | $0.0067 (calc: 4 turns @ $0.0067)
- **gemma4:31b-cloud**: 16 turns | 98,142 in / 444 out | $0.0035 (calc: 16 turns @ $0.0035)

## 2026-06-05

| Metric | Value |
|--------|-------|
| Total Cost | $0.5013 |
| Turns | 360 |
| Input Tokens | 9,137,975 |
| Output Tokens | 46,453 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.5013 |
| Calculated Turns | 360 |

### By Stream
- **technical**: 343 turns | $0.4769
- **business**: 17 turns | $0.0245

### By Model
- **deepseek-v4-pro:cloud**: 331 turns | 8,843,871 in / 43,814 out | $0.4761 (calc: 331 turns @ $0.4761)
- **kimi-k2.6:cloud**: 13 turns | 195,962 in / 2,195 out | $0.0217 (calc: 13 turns @ $0.0217)
- **gemma4:31b-cloud**: 16 turns | 98,142 in / 444 out | $0.0035 (calc: 16 turns @ $0.0035)

## 2026-06-06

| Metric | Value |
|--------|-------|
| Total Cost | $0.4441 |
| Turns | 322 |
| Input Tokens | 4,990,818 |
| Output Tokens | 27,788 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.4441 |
| Calculated Turns | 321 |

### By Stream
- **technical**: 286 turns | $0.3923
- **business**: 36 turns | $0.0518

### By Model
- **deepseek-v4-pro:cloud**: 297 turns | 4,769,605 in / 25,504 out | $0.4272 (calc: 297 turns @ $0.4272)
- **kimi-k2.6:cloud**: 8 turns | 123,071 in / 1,840 out | $0.0133 (calc: 8 turns @ $0.0133)
- **gemma4:31b-cloud**: 16 turns | 98,142 in / 444 out | $0.0035 (calc: 16 turns @ $0.0035)
- **delivery-mirror**: 1 turns | 0 in / 0 out | $0.0000

## 2026-06-07

| Metric | Value |
|--------|-------|
| Total Cost | $0.4414 |
| Turns | 319 |
| Input Tokens | 5,342,646 |
| Output Tokens | 35,529 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.4414 |
| Calculated Turns | 319 |

### By Stream
- **technical**: 298 turns | $0.4112
- **business**: 21 turns | $0.0302

### By Model
- **deepseek-v4-pro:cloud**: 294 turns | 5,090,106 in / 32,550 out | $0.4229 (calc: 294 turns @ $0.4229)
- **kimi-k2.6:cloud**: 9 turns | 154,398 in / 2,535 out | $0.0150 (calc: 9 turns @ $0.0150)
- **gemma4:31b-cloud**: 16 turns | 98,142 in / 444 out | $0.0035 (calc: 16 turns @ $0.0035)

## 2026-06-08

| Metric | Value |
|--------|-------|
| Total Cost | $3.6511 |
| Turns | 4878 |
| Input Tokens | 330,146,708 |
| Output Tokens | 459,304 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $3.6511 |
| Calculated Turns | 4878 |

### By Stream
- **technical**: 2135 turns | $2.8827
- **governance**: 2638 turns | $0.6174
- **business**: 105 turns | $0.1510

### By Model
- **deepseek-v4-pro:cloud**: 2115 turns | 89,429,663 in / 348,317 out | $3.0424 (calc: 2115 turns @ $3.0424)
- **gemma4:31b-cloud**: 2761 turns | 240,706,742 in / 110,935 out | $0.6054 (calc: 2761 turns @ $0.6054)
- **kimi-k2.6:cloud**: 2 turns | 10,303 in / 52 out | $0.0033 (calc: 2 turns @ $0.0033)

## 2026-06-09

| Metric | Value |
|--------|-------|
| Total Cost | $0.4191 |
| Turns | 302 |
| Input Tokens | 4,790,239 |
| Output Tokens | 27,323 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.4191 |
| Calculated Turns | 302 |

### By Stream
- **technical**: 280 turns | $0.3874
- **business**: 22 turns | $0.0316

### By Model
- **deepseek-v4-pro:cloud**: 268 turns | 4,365,779 in / 24,422 out | $0.3855 (calc: 268 turns @ $0.3855)
- **kimi-k2.6:cloud**: 18 turns | 326,142 in / 2,457 out | $0.0300 (calc: 18 turns @ $0.0300)
- **gemma4:31b-cloud**: 16 turns | 98,318 in / 444 out | $0.0035 (calc: 16 turns @ $0.0035)

## 2026-06-10

| Metric | Value |
|--------|-------|
| Total Cost | $0.7844 |
| Turns | 1029 |
| Input Tokens | 64,689,533 |
| Output Tokens | 238,182 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.7844 |
| Calculated Turns | 562 |

### By Stream
- **technical**: 1020 turns | $0.7844
- **business**: 9 turns | $0.0000

### By Model
- **deepseek-v4-pro:cloud**: 528 turns | 56,795,663 in / 175,825 out | $0.7595 (calc: 528 turns @ $0.7595)
- **kimi-k2.6:cloud**: 12 turns | 179,895 in / 1,830 out | $0.0200 (calc: 12 turns @ $0.0200)
- **gemma4:31b-cloud**: 22 turns | 141,927 in / 1,071 out | $0.0048 (calc: 22 turns @ $0.0048)
- **deepseek-v4-flash:cloud**: 458 turns | 7,572,048 in / 59,456 out | $0.0000
- **delivery-mirror**: 9 turns | 0 in / 0 out | $0.0000

## 2026-06-11

| Metric | Value |
|--------|-------|
| Total Cost | $0.0751 |
| Turns | 389 |
| Input Tokens | 6,655,507 |
| Output Tokens | 39,700 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0751 |
| Calculated Turns | 64 |

### By Stream
- **technical**: 378 turns | $0.0751
- **business**: 11 turns | $0.0000

### By Model
- **deepseek-v4-pro:cloud**: 37 turns | 2,070,069 in / 5,459 out | $0.0532 (calc: 37 turns @ $0.0532)
- **kimi-k2.6:cloud**: 11 turns | 269,375 in / 2,216 out | $0.0184 (calc: 11 turns @ $0.0184)
- **gemma4:31b-cloud**: 16 turns | 98,334 in / 444 out | $0.0035 (calc: 16 turns @ $0.0035)
- **deepseek-v4-flash:cloud**: 324 turns | 4,217,729 in / 31,581 out | $0.0000
- **delivery-mirror**: 1 turns | 0 in / 0 out | $0.0000

## 2026-06-12

| Metric | Value |
|--------|-------|
| Total Cost | $0.0463 |
| Turns | 331 |
| Input Tokens | 4,110,378 |
| Output Tokens | 30,173 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0463 |
| Calculated Turns | 46 |

### By Stream
- **technical**: 323 turns | $0.0463
- **business**: 8 turns | $0.0000

### By Model
- **deepseek-v4-pro:cloud**: 13 turns | 273,234 in / 1,583 out | $0.0187 (calc: 13 turns @ $0.0187)
- **kimi-k2.6:cloud**: 9 turns | 97,265 in / 1,894 out | $0.0150 (calc: 9 turns @ $0.0150)
- **minimax-m3:cloud**: 8 turns | 250,901 in / 2,393 out | $0.0091 (calc: 8 turns @ $0.0091)
- **gemma4:31b-cloud**: 16 turns | 98,274 in / 444 out | $0.0035 (calc: 16 turns @ $0.0035)
- **deepseek-v4-flash:cloud**: 285 turns | 3,390,704 in / 23,859 out | $0.0000

## 2026-06-13

| Metric | Value |
|--------|-------|
| Total Cost | $0.4324 |
| Turns | 658 |
| Input Tokens | 51,629,746 |
| Output Tokens | 170,618 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.4324 |
| Calculated Turns | 384 |

### By Stream
- **technical**: 649 turns | $0.4324
- **business**: 9 turns | $0.0000

### By Model
- **minimax-m3:cloud**: 345 turns | 47,431,830 in / 140,887 out | $0.3933 (calc: 345 turns @ $0.3933)
- **kimi-k2.6:cloud**: 11 turns | 250,911 in / 3,481 out | $0.0184 (calc: 11 turns @ $0.0184)
- **deepseek-v4-pro:cloud**: 12 turns | 268,741 in / 1,598 out | $0.0173 (calc: 12 turns @ $0.0173)
- **gemma4:31b-cloud**: 16 turns | 98,274 in / 444 out | $0.0035 (calc: 16 turns @ $0.0035)
- **deepseek-v4-flash:cloud**: 271 turns | 3,579,990 in / 24,208 out | $0.0000
- **delivery-mirror**: 1 turns | 0 in / 0 out | $0.0000
- **gateway-injected**: 2 turns | 0 in / 0 out | $0.0000

## --help

| Metric | Value |
|--------|-------|
| Total Cost | $0.0000 |
| Turns | 0 |
| Input Tokens | 0 |
| Output Tokens | 0 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0000 |
| Calculated Turns | 0 |

### By Stream

### By Model

## --ollama-balance

| Metric | Value |
|--------|-------|
| Total Cost | $0.0000 |
| Turns | 0 |
| Input Tokens | 0 |
| Output Tokens | 0 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0000 |
| Calculated Turns | 0 |

### By Stream

### By Model

## --refresh

| Metric | Value |
|--------|-------|
| Total Cost | $0.0000 |
| Turns | 0 |
| Input Tokens | 0 |
| Output Tokens | 0 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0000 |
| Calculated Turns | 0 |

### By Stream

### By Model

## 2026-06-15

| Metric | Value |
|--------|-------|
| Total Cost | $0.5062 |
| Turns | 753 |
| Input Tokens | 49,023,054 |
| Output Tokens | 210,808 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.5062 |
| Calculated Turns | 422 |

### By Stream
- **technical**: 733 turns | $0.5051
- **business**: 20 turns | $0.0011

### By Model
- **minimax-m3:cloud**: 330 turns | 43,103,721 in / 171,680 out | $0.3762 (calc: 330 turns @ $0.3762)
- **kimi-k2.6:cloud**: 64 turns | 787,827 in / 5,724 out | $0.1068 (calc: 64 turns @ $0.1068)
- **deepseek-v4-pro:cloud**: 14 turns | 319,620 in / 1,740 out | $0.0201 (calc: 14 turns @ $0.0201)
- **gemma4:31b-cloud**: 14 turns | 88,189 in / 397 out | $0.0031 (calc: 14 turns @ $0.0031)
- **delivery-mirror**: 4 turns | 0 in / 0 out | $0.0000
- **deepseek-v4-flash:cloud**: 327 turns | 4,723,697 in / 31,267 out | $0.0000

## 2026-06-16

| Metric | Value |
|--------|-------|
| Total Cost | $0.0234 |
| Turns | 503 |
| Input Tokens | 6,977,494 |
| Output Tokens | 47,322 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0234 |
| Calculated Turns | 14 |

### By Stream
- **technical**: 494 turns | $0.0234
- **business**: 9 turns | $0.0000

### By Model
- **kimi-k2.6:cloud**: 14 turns | 250,514 in / 2,394 out | $0.0234 (calc: 14 turns @ $0.0234)
- **deepseek-v4-flash:cloud**: 488 turns | 6,726,980 in / 44,928 out | $0.0000
- **delivery-mirror**: 1 turns | 0 in / 0 out | $0.0000

## 2026-06-17

| Metric | Value |
|--------|-------|
| Total Cost | $0.4279 |
| Turns | 3232 |
| Input Tokens | 108,003,616 |
| Output Tokens | 395,097 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.4279 |
| Calculated Turns | 320 |

### By Stream
- **technical**: 3158 turns | $0.4177
- **business**: 74 turns | $0.0103

### By Model
- **deepseek-v4-pro:cloud**: 233 turns | 20,823,468 in / 59,085 out | $0.3352 (calc: 233 turns @ $0.3352)
- **minimax-m3:cloud**: 58 turns | 1,276,703 in / 20,087 out | $0.0661 (calc: 58 turns @ $0.0661)
- **kimi-k2.6:cloud**: 14 turns | 518,298 in / 2,591 out | $0.0234 (calc: 14 turns @ $0.0234)
- **gemma4:31b-cloud**: 15 turns | 186,282 in / 2,009 out | $0.0033 (calc: 15 turns @ $0.0033)
- **deepseek-v4-flash:cloud**: 2369 turns | 36,602,633 in / 212,525 out | $0.0000
- **delivery-mirror**: 102 turns | 0 in / 0 out | $0.0000
- **kimi-k2.7-code:cloud**: 441 turns | 48,596,232 in / 98,800 out | $0.0000

## 2026-06-18

| Metric | Value |
|--------|-------|
| Total Cost | $0.3695 |
| Turns | 3181 |
| Input Tokens | 71,871,540 |
| Output Tokens | 460,884 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.3695 |
| Calculated Turns | 322 |

### By Stream
- **technical**: 3085 turns | $0.3566
- **business**: 96 turns | $0.0129

### By Model
- **minimax-m3:cloud**: 297 turns | 9,055,950 in / 85,593 out | $0.3386 (calc: 297 turns @ $0.3386)
- **kimi-k2.6:cloud**: 10 turns | 233,740 in / 6,692 out | $0.0167 (calc: 10 turns @ $0.0167)
- **deepseek-v4-pro:cloud**: 9 turns | 176,361 in / 3,220 out | $0.0129 (calc: 9 turns @ $0.0129)
- **gemma4:31b-cloud**: 6 turns | 62,626 in / 134 out | $0.0013 (calc: 6 turns @ $0.0013)
- **deepseek-v4-flash:cloud**: 2570 turns | 41,999,881 in / 245,019 out | $0.0000
- **kimi-k2.7-code:cloud**: 287 turns | 20,342,982 in / 120,226 out | $0.0000
- **delivery-mirror**: 2 turns | 0 in / 0 out | $0.0000

## 2026-06-19

| Metric | Value |
|--------|-------|
| Total Cost | $0.0200 |
| Turns | 697 |
| Input Tokens | 22,236,394 |
| Output Tokens | 100,663 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0200 |
| Calculated Turns | 12 |

### By Stream
- **technical**: 689 turns | $0.0200
- **business**: 8 turns | $0.0000

### By Model
- **kimi-k2.6:cloud**: 12 turns | 250,218 in / 2,739 out | $0.0200 (calc: 12 turns @ $0.0200)
- **deepseek-v4-flash:cloud**: 448 turns | 6,350,209 in / 39,366 out | $0.0000
- **kimi-k2.7-code:cloud**: 234 turns | 15,635,967 in / 58,558 out | $0.0000
- **delivery-mirror**: 3 turns | 0 in / 0 out | $0.0000

## 2026-06-20

| Metric | Value |
|--------|-------|
| Total Cost | $0.5398 |
| Turns | 3202 |
| Input Tokens | 182,700,309 |
| Output Tokens | 489,479 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.5398 |
| Calculated Turns | 686 |

### By Stream
- **technical**: 2846 turns | $0.4640
- **governance**: 346 turns | $0.0759
- **business**: 10 turns | $0.0000

### By Model
- **deepseek-v4-pro:cloud**: 208 turns | 18,341,949 in / 47,243 out | $0.2992 (calc: 208 turns @ $0.2992)
- **minimax-m3:cloud**: 105 turns | 3,453,531 in / 35,657 out | $0.1197 (calc: 105 turns @ $0.1197)
- **gemma4:31b-cloud**: 346 turns | 26,878,419 in / 20,185 out | $0.0759 (calc: 346 turns @ $0.0759)
- **kimi-k2.6:cloud**: 27 turns | 886,414 in / 9,318 out | $0.0451 (calc: 27 turns @ $0.0451)
- **deepseek-v4-flash:cloud**: 518 turns | 8,495,433 in / 97,745 out | $0.0000
- **kimi-k2.7-code:cloud**: 1942 turns | 124,644,563 in / 279,331 out | $0.0000
- **gateway-injected**: 4 turns | 0 in / 0 out | $0.0000
- **delivery-mirror**: 52 turns | 0 in / 0 out | $0.0000

## 2026-06-21

| Metric | Value |
|--------|-------|
| Total Cost | $0.0300 |
| Turns | 561 |
| Input Tokens | 11,909,212 |
| Output Tokens | 75,328 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0300 |
| Calculated Turns | 18 |

### By Stream
- **technical**: 550 turns | $0.0300
- **business**: 11 turns | $0.0000

### By Model
- **kimi-k2.6:cloud**: 18 turns | 435,010 in / 7,241 out | $0.0300 (calc: 18 turns @ $0.0300)
- **deepseek-v4-flash:cloud**: 472 turns | 6,838,052 in / 42,230 out | $0.0000
- **kimi-k2.7-code:cloud**: 71 turns | 4,636,150 in / 25,857 out | $0.0000

## 2026-06-22

| Metric | Value |
|--------|-------|
| Total Cost | $0.0968 |
| Turns | 917 |
| Input Tokens | 38,470,513 |
| Output Tokens | 207,952 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0968 |
| Calculated Turns | 58 |

### By Stream
- **technical**: 907 turns | $0.0968
- **business**: 10 turns | $0.0000

### By Model
- **kimi-k2.6:cloud**: 58 turns | 2,410,421 in / 15,203 out | $0.0968 (calc: 58 turns @ $0.0968)
- **deepseek-v4-flash:cloud**: 434 turns | 6,896,630 in / 38,958 out | $0.0000
- **kimi-k2.7-code:cloud**: 403 turns | 29,163,462 in / 153,791 out | $0.0000
- **delivery-mirror**: 22 turns | 0 in / 0 out | $0.0000

## 2026-06-23

| Metric | Value |
|--------|-------|
| Total Cost | $0.0150 |
| Turns | 452 |
| Input Tokens | 7,259,088 |
| Output Tokens | 42,528 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0150 |
| Calculated Turns | 9 |

### By Stream
- **technical**: 443 turns | $0.0150
- **business**: 9 turns | $0.0000

### By Model
- **kimi-k2.6:cloud**: 9 turns | 193,114 in / 2,488 out | $0.0150 (calc: 9 turns @ $0.0150)
- **deepseek-v4-flash:cloud**: 437 turns | 7,004,008 in / 39,431 out | $0.0000
- **delivery-mirror**: 1 turns | 0 in / 0 out | $0.0000
- **kimi-k2.7-code:cloud**: 5 turns | 61,966 in / 609 out | $0.0000

## 2026-06-24

| Metric | Value |
|--------|-------|
| Total Cost | $0.0349 |
| Turns | 715 |
| Input Tokens | 11,086,332 |
| Output Tokens | 60,427 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0349 |
| Calculated Turns | 26 |

### By Stream
- **technical**: 636 turns | $0.0349
- **business**: 79 turns | $0.0000

### By Model
- **minimax-m3:cloud**: 16 turns | 402,987 in / 3,409 out | $0.0182 (calc: 16 turns @ $0.0182)
- **kimi-k2.6:cloud**: 10 turns | 244,772 in / 2,583 out | $0.0167 (calc: 10 turns @ $0.0167)
- **kimi-k2.7-code:cloud**: 52 turns | 1,958,038 in / 9,381 out | $0.0000
- **delivery-mirror**: 8 turns | 0 in / 0 out | $0.0000
- **deepseek-v4-flash:cloud**: 629 turns | 8,480,535 in / 45,054 out | $0.0000

## 2026-06-25

| Metric | Value |
|--------|-------|
| Total Cost | $0.0217 |
| Turns | 586 |
| Input Tokens | 7,891,964 |
| Output Tokens | 41,644 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0217 |
| Calculated Turns | 13 |

### By Stream
- **technical**: 575 turns | $0.0217
- **business**: 11 turns | $0.0000

### By Model
- **kimi-k2.6:cloud**: 13 turns | 450,707 in / 2,962 out | $0.0217 (calc: 13 turns @ $0.0217)
- **deepseek-v4-flash:cloud**: 573 turns | 7,441,257 in / 38,682 out | $0.0000

## 2026-06-26

| Metric | Value |
|--------|-------|
| Total Cost | $0.0451 |
| Turns | 740 |
| Input Tokens | 13,175,393 |
| Output Tokens | 63,096 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0451 |
| Calculated Turns | 27 |

### By Stream
- **technical**: 731 turns | $0.0451
- **business**: 9 turns | $0.0000

### By Model
- **kimi-k2.6:cloud**: 27 turns | 535,973 in / 2,468 out | $0.0451 (calc: 27 turns @ $0.0451)
- **deepseek-v4-flash:cloud**: 690 turns | 9,760,302 in / 55,445 out | $0.0000
- **kimi-k2.7-code:cloud**: 22 turns | 2,879,118 in / 5,183 out | $0.0000
- **delivery-mirror**: 1 turns | 0 in / 0 out | $0.0000

## 2026-06-27

| Metric | Value |
|--------|-------|
| Total Cost | $0.0534 |
| Turns | 703 |
| Input Tokens | 9,920,532 |
| Output Tokens | 53,768 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0534 |
| Calculated Turns | 32 |

### By Stream
- **technical**: 695 turns | $0.0534
- **business**: 8 turns | $0.0000

### By Model
- **kimi-k2.6:cloud**: 32 turns | 987,376 in / 7,391 out | $0.0534 (calc: 32 turns @ $0.0534)
- **deepseek-v4-flash:cloud**: 423 turns | 7,211,034 in / 36,845 out | $0.0000
- **kimi-k2.7-code:cloud**: 247 turns | 1,722,122 in / 9,532 out | $0.0000
- **delivery-mirror**: 1 turns | 0 in / 0 out | $0.0000

## 2026-07-04

| Metric | Value |
|--------|-------|
| Total Cost | $0.0234 |
| Turns | 145 |
| Input Tokens | 6,533,932 |
| Output Tokens | 20,114 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0234 |
| Calculated Turns | 14 |

### By Stream
- **technical**: 145 turns | $0.0234

### By Model
- **kimi-k2.6:cloud**: 14 turns | 330,014 in / 2,486 out | $0.0234 (calc: 14 turns @ $0.0234)
- **deepseek-v4-flash:cloud**: 83 turns | 1,311,173 in / 6,323 out | $0.0000
- **kimi-k2.7-code:cloud**: 45 turns | 4,892,745 in / 11,305 out | $0.0000
- **delivery-mirror**: 3 turns | 0 in / 0 out | $0.0000

## 2026-07-05

| Metric | Value |
|--------|-------|
| Total Cost | $0.0150 |
| Turns | 389 |
| Input Tokens | 6,548,325 |
| Output Tokens | 41,471 |
| Cache Read | 0 |
| Calculated Cost (ephemeral) | $0.0150 |
| Calculated Turns | 9 |

### By Stream
- **technical**: 377 turns | $0.0150
- **business**: 12 turns | $0.0000

### By Model
- **kimi-k2.6:cloud**: 9 turns | 213,842 in / 2,811 out | $0.0150 (calc: 9 turns @ $0.0150)
- **deepseek-v4-flash:cloud**: 380 turns | 6,334,483 in / 38,660 out | $0.0000
