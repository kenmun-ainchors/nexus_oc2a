# Yoda + Aria CREST Plan Benchmark — Recommendation

**Date:** 2026-06-20
**Atoms:** 12 Plan scenarios (6 Yoda, 6 Aria)
**Models tested:** `glm-5.2:cloud`, `kimi-k2.7-code:cloud`, `deepseek-v4-pro:cloud`

## Aggregate Results

| Model | Rubric Score | Insight Score | Adjusted | Elapsed | Rel. Cost | Value (pct/cost) |
|---|---|---|---|---|---|---|
| `ollama/kimi-k2.7-code:cloud` | 76/81 (93.8%) | 31/36 (86.1%) | 107/117 (91.5%) | 234.1s | 1.5× | 61.0 |
| `ollama/deepseek-v4-pro:cloud` | 76/81 (93.8%) | 26/36 (72.2%) | 102/117 (87.2%) | 114.9s | 3.0× | 29.07 |
| `ollama/glm-5.2:cloud` | 75/81 (92.6%) | 24/36 (66.7%) | 99/117 (84.6%) | 127.5s | 1.5× | 56.4 |

## Key Observations

1. **kimi-k2.7-code:cloud** leads on rubric (93.8%) and insight (86.1%), giving the highest adjusted score (91.5%). It was also the slowest (234s total).
2. **glm-5.2:cloud** is close on rubric (92.6%) but lowest on insight (66.7%) due to fabrications (Claude 3.5 Sonnet, invented agent IDs, wrong LinkedIn slot time). Fast (128s).
3. **deepseek-v4-pro:cloud** ties kimi on rubric (93.8%) but lower insight (72.2%) due to external-vendor fabrications, EU jurisdiction invention, Ken/Angie title swap, and wrong LinkedIn rescheduling. Fastest (115s).
4. All three models fabricate model names when asked to cite current policy. This is expected without live policy lookup; the differentiator is whether the fabrication is harmless (generic) or policy-violating (Claude/o1-preview/OpenAI/Gemini).
5. The `state_model_policy` PG source currently assigns `yoda_master|Plan` to `deepseek-v4-pro:cloud` and `business|Plan` to `kimi-k2.6:cloud`. This benchmark did not test `kimi-k2.6:cloud`.

## Recommendation

- **Primary Yoda/Aria user-interaction model:** Keep `kimi-k2.7-code:cloud` as the default. This benchmark does not change that decision.
- **Pro CREST Plan/Replan for Yoda + Aria:** Adopt `kimi-k2.7-code:cloud` as primary, replacing `deepseek-v4-pro:cloud`. Quality is higher, fabrications are less policy-violating, and cost is lower.
- **Deepseek-v4-pro:cloud:** Demote to fallback-only for Yoda/Aria Plan/Replan. Use only when kimi-k2.7-code is unavailable or for a specific atom flagged as requiring deepseek by the model router.
- **glm-5.2:cloud:** Not recommended for Yoda/Aria Plan. While fast and structurally capable, it produced the most policy-violating fabrications (Anthropic/Claude references) and should remain in its approved niche (`design_backend` Plan/Analysis per CHG-0685).

## Required Next Steps

1. Log a CHG (e.g. CHG-0686) to update `state_model_policy.crest_phase_rules`:
   - `yoda_master|Plan` → `kimi-k2.7-code:cloud` (primary), `deepseek-v4-pro:cloud` (fallback).
   - `yoda_master|Replan` → `kimi-k2.7-code:cloud` (primary), `deepseek-v4-pro:cloud` (fallback).
   - `business|Plan` → `kimi-k2.7-code:cloud` (primary), `kimi-k2.6:cloud` or `deepseek-v4-pro:cloud` (fallback).
   - `business|Replan` → `kimi-k2.7-code:cloud` (primary), fallback as above.
2. Run a follow-up benchmark for `kimi-k2.6:cloud` vs `kimi-k2.7-code:cloud` specifically for Aria `business|Plan/Replan` to confirm the k2.7 upgrade over k2.6.
3. Update `agent-skills/crest/SKILL.md` and `docs/CREST-v1.3-Recursive-Model-C.md` matrix once Ken approves the CHG.

## Data Files

- `state/phase5-results/yoda-aria-plan-2026-06-20/manifest.json`
- `state/phase5-results/yoda-aria-plan-2026-06-20/scores-final.json`
- `state/phase5-results/yoda-aria-plan-2026-06-20/comparison.json`
- `state/phase5-results/yoda-aria-plan-2026-06-20/<model>/report.json`
- `state/phase5-results/yoda-aria-plan-2026-06-20/<model>/atom_XX_raw.txt`
