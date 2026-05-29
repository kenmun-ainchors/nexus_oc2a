# Monthly Model Strategy Review — May 2026

**Date:** 2026-05-28  
**Reviewer:** Yoda 🟢 (Lead Orchestrator)  
**Approval required:** Ken Mun (CTO)  
**Status:** DRAFT FOR REVIEW

---

## (1) Spend vs A$500/month Cap

| Metric | Value |
|--------|-------|
| May total Claude API spend | **~$3,384.41** |
| Ollama Cloud subscription | **$100.00** (fixed monthly) |
| May total spend | **~$3,484.41** |
| Monthly cap | **A$500** |
| Over cap by | **~$2,984.41 (597%)** |

### Context — why the massive overspend?

May was a two-phase month:

**Phase 1 (May 1–15): Claude API era.** All agents ran on Claude Sonnet 4.6 + Haiku 4.5. This was the heavy platform build phase — architecture docs, Notion migration, PG SSOT, agent workspace separation, TQP contract enforcement, OWL guard implementation. Daily burn averaged **$225/day** for those 15 days. Auto-reload triggered 6 times (May 10-15) at $450 each.

**Phase 2 (May 16–27): Ollama Cloud era.** Claude credits depleted May 15 midnight. All agents migrated to deepseek-v4-pro, gemma4:31b-cloud, and kimi-k2.6 via Ollama Cloud (fixed $100/mo subscription). Daily Claude API cost: **$0.00** for 12 consecutive days. Only $7.63 residual Haiku cost on May 16 (transition day).

**The A$500/month cap was set on April 26** when we only had Claude pricing. It was never adjusted for the Ollama Cloud phase change, which makes the comparison misleading. Realistically, May was a transition month: 15 days at full Claude burn rate, then 12 days at $0. The $500 cap was blown in the first 3 days of May.

### Daily Burn Rate (May 1–15, Claude era)
- Average: **$225.12/day**
- Peak: $376.09 (May 10)  
- Trough: $61.46 (May 1)

### Daily Burn Rate (May 16–27, Ollama Cloud era)
- Average: **$0.00/day** (Claude API) + ~$3.33/day (Ollama Cloud amortized)
- Total Ollama Cloud cost: $100.00 fixed

### Projection (June 2026)
If Ollama Cloud remains the only active API path: **$100/month total**. Well within the $500 cap. The Claude era spend was a one-time platform build investment, not a recurring baseline.

---

## (2) Model Usage Breakdown

### Claude API Era (May 1–15)

| Model | Total Cost | Share |
|-------|-----------|-------|
| Claude Sonnet 4.6 | ~$3,119.03 | 92.4% |
| Claude Haiku 4.5 | ~$117.98 | 3.5% |
| Claude Opus 4.7 | ~$0.05 | <0.1% |
| Ollama Cloud models (gemma4, deepseek, kimi) | $0.00 | 0% |
| **Total** | **~$3,384.41** | — |

### Ollama Cloud Era (May 16–27) — by Turns & Tokens

| Model | Turns | Input Tokens | Output Tokens | Days Active |
|-------|-------|-------------|---------------|-------------|
| **gemma4:31b-cloud** | 16,564 | 215.4M | 665K | 12 days |
| **deepseek-v4-pro:cloud** | 6,595 | 326.8M | 1.2M | 12 days |
| **kimi-k2.6:cloud** | 3,229 | 62.4M | 232K | 12 days |
| **deepseek-v4-flash:cloud** | 79 | 588K | 8K | sporadic |
| **gemma4:e2b** / **gemma4:26b** | 39 | 64K | 0.7K | minimal |
| **claude-haiku-4-5** (residual) | 1,720 | 19.6K | 408K | May 16 only |

**Total Ollama Cloud turns (May 16–27):** 26,506  
**Total Ollama Cloud input tokens:** ~605M  
**Total Ollama Cloud output tokens:** ~2.5M  

**Daily average (Ollama Cloud era):** 2,209 turns/day, ~50.4M input tokens/day.

**Key observation:** gemma4:31b-cloud is the workhorse (62% of turns), deepseek-v4-pro is the quality model (25%), kimi-k2.6 is niche (12%). Flash is barely used. This tiering strategy is working well.

---

## (3) Delegation Model Performance

**No benchmark data available for May 2026.** The `state/benchmark/` directory is empty. The last benchmarks were run on April 28 (Gemma4 variants and Haiku 4.5 vs Qwen3).

**What we know from usage patterns:**
- Deepseek-v4-pro is performing adequately as Yoda's primary — interactive response quality has not drawn complaints
- Gemma4:31b-cloud is handling backend/cron workloads at scale — 16,564 turns with no reported failures
- Kimi-k2.6 is restricted to simple single-thread tasks per policy (CHG-0383: Kimi Atomic Task Rule)
- No benchmark suite has been run against the Ollama Cloud models (deepseek-v4-pro, gemma4:31b-cloud, kimi-k2.6, deepseek-v4-flash)

**Recommendation:** Run a fresh benchmark against the current Ollama Cloud model lineup. The April benchmark tested local models (Gemma4:e2b) and Anthropic models (Haiku) — neither of which is in active use today. We're flying without instrumented quality data.

---

## (4) Drift Incidents — May 2026

**Drift state summary (from model-drift-state.json):**
- Total checks run: 204
- Total violations found: 207 (cumulative all-time, includes pre-May)
- Consecutive clean checks: **0** (reset at baseline on May 25)
- Last check: 2026-05-28 10:07 AEST
- Last status: **violation**
- Last check: 8 passed, 1 failed
- Last violation at: 2026-05-28 10:07 AEST

**Current drift status: 1 active violation detected today (May 28).** The consecutiveClean counter reset to 0 with a baseline reset on May 25 (CHG-0394: clean v2.0 model-policy rebuild), meaning there have been violations since the reset.

**Violation count note:** The `model-drift-violations.json` file does not exist — violation details are tracked inline in the drift state and Warden reports, not in a separate violations log. This is a documentation gap.

**Resolution time:** The ongoing violation at the time of this review (10:07 AEST May 28) has not yet been resolved. Cause unknown without the violation detail file — likely a model mismatch on an agent's config vs policy.

**Recommendation:** Investigate the May 28 10:07 violation immediately. Create `model-drift-violations.json` as a structured violations log for audit trail.

---

## (5) Warden Effectiveness

**Warden (governance agent) is active on gemma4:31b-cloud** per model-policy v2.0 (CHG-0394).

**Key metrics:**
- Total checks run: 204 (since inception)
- Consecutive clean: 0 (reset May 25)
- Last check: 2026-05-28 10:07 AEST — 8/9 models compliant, 1 violation

**Effectiveness assessment:**
- Warden is catching violations — the 1 in 9 failure rate shows it's actively detecting drift
- However, consecutiveClean=0 means we've never had a sustained clean period since the May 25 baseline
- The violation at 10:07 today needs immediate attention — a model may have drifted since the policy reset
- No known escalations to Ken this month (Warden handles violations automatically via allowlist-sync.sh; it does not proactively alert unless the violation is un-resolvable)

**Gap:** We lack a structured violations log file. Warden should write to `model-drift-violations.json` on each detection for audit trail. Currently violations are only tracked in-memory in the drift state.

---

## (6) New Models Worth Evaluating

Web search was unavailable during this review (Minimax API key missing). However, based on known release cadences:

**Recent/upcoming candidates:**
- **DeepSeek V4 series** — already in use (v4-pro, v4-flash). Monitor for v4.1 or successor releases.
- **Gemma 4 family** — already in use (31b-cloud, e2b, 26b). Google has not released a Gemma 5.
- **Qwen 3 series** — benchmarked April 28 (inconclusive, re-test pending with /no_think). Still worth evaluating for offline Tier 3 work.
- **GLM-5.1** — 4 turns logged May 20. No sustained evaluation. Unknown quality.
- **Claude 4.x models** — Sonnet 4.6 and Opus 4.7 are the current Anthropic frontier. No new Claude releases expected imminently.
- **Mistral Large 3** — rumored. Not evaluated.

**Recommendation:** When web search is available, scan for new model releases before next monthly review. Prioritize benchmarking any new Ollama-compatible models that could improve quality or reduce the gemma4 workload.

---

## (7) OC2 Readiness

**OC2 status (from MEMORY.md):**
- **Hardware:** Mac Mini M4 Pro 48GB ×2 — INCOMING, ETA 6–13 Jul 2026
- **Configuration:** OC2-A = HA Primary, OC2-B = Standby
- **Commissioning target:** ~27 Jul 2026
- **OC2-gated items:** NAS (S7 encrypted), Gemma4:26b keep-alive (US34), P1 scale, KL team onboarding

**No hardware update** — OC2 is still on track for July 2026. The current Ollama Cloud strategy (deepseek + gemma4 + kimi) is the bridge to OC2. Once OC2 arrives with 32GB RAM minimum, local Gemma4:26b keep-alive becomes viable, potentially reducing Ollama Cloud dependency for some workloads.

**Model strategy impact of OC2:**
- Gemma4:26b (16GB) currently can't run persistently on OC1 (24GB, ~11GB headroom with OS+gateway). On OC2 (48GB), it can run as a keep-alive service for background delegation.
- This could shift some gemma4:31b-cloud workload to free local inference, reducing Ollama Cloud load
- Nascent NAS (S7) enables model caching/checkpoint storage

---

## (8) Recommended Policy Changes

| # | Recommendation | Justification | Priority |
|---|---------------|---------------|----------|
| 1 | **Run fresh benchmark suite** against deepseek-v4-pro, gemma4:31b-cloud, kimi-k2.6, deepseek-v4-flash | Last benchmarks were April 28 against Anthropic/local models. No quality data on current lineup. | HIGH |
| 2 | **Create `model-drift-violations.json`** structured log | Currently no audit trail for individual violations. Warden should write structured entries. | MEDIUM |
| 3 | **Investigate May 28 10:07 drift violation** | 1 active violation at review time. consecutiveClean=0. Needs root cause. | HIGH |
| 4 | **Re-evaluate A$500/month cap** | Set April 26 for Claude-only era. No longer meaningful in Ollama Cloud $100/mo regime. Cap should reflect current cost reality. | MEDIUM |
| 5 | **Evaluate deepseek-v4-flash for more use cases** | Only 79 turns used. If quality is adequate for simple tasks, could offload gemma4:31b-cloud further. | LOW |
| 6 | **GLM-5.1 evaluation / removal** | 4 turns logged, no sustained use. Either evaluate properly or remove from allowlist to reduce drift surface. | LOW |
| 7 | **OC2 model transition plan** | Draft plan for model migration when OC2 arrives (Jul 2026): which workloads move to local Gemma4:26b, which stay on Ollama Cloud. | MEDIUM |

### No recommended routing changes at this time.

The current tier structure (user-facing: deepseek-v4-pro primary, backend: gemma4:31b-cloud primary) is working. The Kimi policy (CHG-0383: atomic tasks only, no complex orchestration) is appropriate. No model should be promoted or demoted without benchmark data.

---

## Verdict

**MAY 2026: CONDITIONAL PASS**

The platform successfully navigated a major transition from Claude API ($225/day burn) to Ollama Cloud ($0/day marginal cost). This validates the multi-model strategy designed in April. However:

1. **Spend was catastrophic** in the first 15 days — 597% over the $500 cap. This was a known trade-off for the heavy build phase, but the cap should have been formally adjusted.
2. **No benchmark data** means we're flying blind on model quality. We know the models "work" from operational uptime, but we have no quantitative quality comparison of the current lineup.
3. **Active drift violation** at review time is a yellow flag. Warden is detecting but not resolving cleanly.
4. **Ollama Cloud is the right strategy for now** — $100/mo fixed cost for unlimited inference across 3+ models is an exceptional value proposition.

**Next monthly review: June 28, 2026.**

---

*End of report. No policy changes implemented. Awaiting Ken Mun approval.*
