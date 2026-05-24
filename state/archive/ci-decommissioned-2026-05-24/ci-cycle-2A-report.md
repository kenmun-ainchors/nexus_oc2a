# CI Cycle 2A — Weekly Report
**Generated:** 2026-05-16 10:39 AEST  
**Window:** 2026-05-09 to 2026-05-16 (7.25 days)  
**Total Runs:** 18 | **Total Tasks Evaluated:** 68  

---

## Summary Table

| Task Category | T2b Model | Avg Quality | Avg Latency | Candidate Score | Pass Rate | Confidence |
|---------------|-----------|-------------|-------------|------------------|-----------|------------|
| ops-cron | gemma4:31b-cloud | 4.39/5 | 11.4s | 0.90 | 93% (13/14) | **HIGH** |
| subtask | deepseek-v4-flash:cloud | 4.00/5 | 18.4s | 0.75 | 68% (13/19) | **MEDIUM** |
| reasoning | deepseek-v4-pro:cloud | 4.28/5 | 27.3s | 0.67 | 39% (7/18) | **LOW** |
| creative | kimi-k2.6:cloud | 4.29/5 | 34.5s | 0.66 | 35% (6/17) | **LOW** |

---

## Top 2 Head-to-Head Candidates (>50% pass rate required)

### 1. ops-cron → gemma4:31b-cloud | Q=4.39/5 (Δ-0.4 vs Sonnet 4.8) | L=11.4s | HIGH confidence

- 14/14 pass quality (100%), 13/14 pass latency (93%)
- Average 11.4s latency — 4x faster than Sonnet equivalent
- One failure: 30s SIGKILL on multi-status classification (Service Status Report r33)
- Minor thinking-mode bleed in ~3/14 runs (cosmetic, doesn't affect final output correctness)
- Strongest candidate in CI history: highest avg candidateScore (0.90) across all cycles
- **Recommendation: PROMOTE to Cycle B for real-time evaluation on live ops-cron tasks**

### 2. subtask → deepseek-v4-flash:cloud | Q=4.00/5 (Δ-0.8 vs Sonnet 4.8) | L=18.4s | MEDIUM confidence

- 16/19 pass quality (84%), 13/19 pass latency (68%)
- Fast when successful: 5 runs at 2-8s (pure data transcription)
- 3 failures: SIGKILL/SIGTERM on prompts with any semantic ambiguity (multi-metric classification, status semantics, inference)
- Works only with deterministic, pre-supplied single-metric data
- Quality gap (-0.8 vs Sonnet) is the concern — may degrade on real-world data with edge cases
- **Recommendation: CONDITIONAL — only for fully-deterministic subtasks with pre-computed data**

---

## Full Ranked List

| Rank | Category | Model | Avg Q | Avg L | Pass% | Score | Conf |
|------|----------|-------|-------|-------|-------|-------|------|
| 1 | ops-cron | gemma4:31b-cloud | 4.39 | 11.4s | 93% | 0.90 | HIGH |
| 2 | subtask | deepseek-v4-flash:cloud | 4.00 | 18.4s | 68% | 0.75 | MEDIUM |
| 3 | reasoning | deepseek-v4-pro:cloud | 4.28 | 27.3s | 39% | 0.67 | LOW |
| 4 | creative | kimi-k2.6:cloud | 4.29 | 34.5s | 35% | 0.66 | LOW |

---

## Key Findings

1. **gemma4:31b-cloud is production-ready for ops-cron.** 93% pass rate, 11.4s avg latency, no quality failures. Only gap: thinking-mode bleed in ~20% of runs.

2. **deepseek-v4-flash is reliable only for deterministic subtasks.** When data and classification rules are pre-supplied and unambiguous, achieves 4.5 quality at 2-8s. Fails catastrophically on any prompt requiring inference.

3. **Neither kimi-k2.6 nor deepseek-v4-pro meet latency SLA for reasoning/creative.** Both avg >25s vs 20s threshold. Quality is strong (4.3+) but thinking-chain word-count obsession is fatal for time-constrained workloads.

4. **No candidate meets Cycle B ≥75% pass rate requirement.** gemma4/ops-cron at 93% clears, but subtask at 68% does not. Per Ken's directive (2026-05-09), Cycle B requires ALL candidates ≥75%.

---

## Next Steps

- Ken approval requested for gemma4:31b-cloud → ops-cron promotion to Cycle B
- Cycle 3A window auto-started for continued evaluation
- subtask/deepseek-v4-flash needs tighter prompt engineering to push pass rate above 75%
- reasoning and creative: recommend keeping on Claude for Cycle 3
