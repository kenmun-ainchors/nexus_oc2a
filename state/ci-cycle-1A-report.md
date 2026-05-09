# CI Cycle 1A — Weekly Report
**Generated:** 2026-05-09 04:38 AEST (2026-05-08T18:38:00Z)
**Window:** 2026-05-02 11:23 AEST → 2026-05-09 04:38 AEST
**Total runs:** 25 | **Total tasks evaluated:** 97

---

## Summary Table

| Category | T2B Model | Runs | Avg Quality | Avg Latency | Candidate Score | Pass Both % | Confidence |
|----------|-----------|------|-------------|-------------|-----------------|-------------|------------|
| reasoning | deepseek-v4-pro:cloud | 32 | 3.51/5 | 22.4s | 0.60 | 41% | LOW |
| creative | kimi-k2.6:cloud | 29 | 4.14/5 | 24.1s | 0.68 | 45% | LOW |
| subtask | deepseek-v4-flash:cloud | 32 | 3.88/5 | 15.5s | 0.71 | 62% | MEDIUM |

---

## Top 2 Head-to-Head Candidates (>50% pass both)

### 1. subtask → deepseek-v4-flash:cloud
- **Avg Quality:** 3.88/5 (Δ -0.9 vs Sonnet 4.8 baseline)
- **Avg Latency:** 15.5s (passes 20s SLA)
- **Candidate Score:** 0.71
- **Confidence:** MEDIUM (62% pass both quality + latency)
- **Strengths:** Excellent at deterministic structured output with pre-supplied data. Fast response (3-15s typical). Cost snapshot, backup reports, asset scans, disk usage, SLA reports — all strong.
- **Weaknesses:** Fails catastrophically (>30s SIGKILL) on any prompt with semantic ambiguity (WARN vs FAIL, degraded vs healthy). Cannot handle inference/decision-making. Pure data transcription only.

### 2. creative → kimi-k2.6:cloud
- **Avg Quality:** 4.14/5 (Δ -0.7 vs Sonnet 4.8 baseline)
- **Avg Latency:** 24.1s (fails 20s SLA by 4.1s avg)
- **Candidate Score:** 0.68
- **Confidence:** LOW (45% pass both)
- **Strengths:** Highest raw quality of all T2b models for creative tasks. Standup briefs, blog posts, LinkedIn content, journal entries — consistently 4.5/5. Founder voice nailed.
- **Weaknesses:** Unreliable latency. Word-choice iteration in thinking chain causes 30-57s blowouts on ~30% of creative prompts. Needs hard word-cap + no-optimization directive to be viable.

---

## Full Ranked List

| Rank | Category | Model | Avg CS | Avg Q | Avg L | %Pass |
|------|----------|-------|--------|-------|-------|-------|
| 1 | subtask | deepseek-v4-flash:cloud | 0.71 | 3.88 | 15.5s | 62% |
| 2 | creative | kimi-k2.6:cloud | 0.68 | 4.14 | 24.1s | 45% |
| 3 | reasoning | deepseek-v4-pro:cloud | 0.60 | 3.51 | 22.4s | 41% |

---

## Key Patterns (Cycle 1A)

- **deepseek-v4-flash:cloud** = strongest T2b candidate. Works well when prompt has: all data pre-supplied, explicit format, deterministic rules, no semantic ambiguity. Fails on any inference.
- **kimi-k2.6:cloud** = best creative quality but latency unreliable. Thinking chain word-obsession causes 30-57s blowouts on ~30% of creative prompts.
- **deepseek-v4-pro:cloud** = not viable for reasoning. 41% pass rate. Fails on governance/compliance with word-counting loops or 503 errors at peak hours. Latency 22.4s avg exceeds SLA.
- **Peak hour failures:** Multiple SIGKILLs between 10PM-4AM AEST when Ollama cloud likely overloaded.

---

## Recommendation

**Cycle B candidate:** `subtask → deepseek-v4-flash:cloud` for deterministic structured-output cron jobs (cost snapshots, backup reports, health checks with pre-supplied data, SLA monitors).

**Creative tasks:** Keep on Claude Sonnet until kimi latency stabilized. OR test with `max_tokens` / `num_ctx` limiting to force faster output.

**Reasoning tasks:** Keep on Claude Sonnet. deepseek-v4-pro not ready.

**Awaiting Ken approval** → Reply APPROVE to start Cycle B with subtask → deepseek-v4-flash:cloud.
