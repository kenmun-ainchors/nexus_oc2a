# Research Framework — AInchors
_Created: 2026-04-26 | Status: Tier 1 defined. Tiers 2–4 to be defined when US20 is picked up._

---

## Purpose
Define what research means at AInchors — the scope, depth, execution effort, and validation standard for each tier. This is the service catalogue for the Research Agent 🔬 (planned).

When Ken commissions research, he names the tier. The agent knows exactly what to deliver.

---

## Tier 1 — Deep Research (DEFINED)

**Model:** Opus 4.7 (non-negotiable at this tier)
**Effort:** 3–6 hours (sub-agent, isolated session)
**When to use:** Decisions that are high-stakes, strategic, or irreversible. Architectural choices, vendor selections, model strategy, competitive analysis, compliance questions.

### Pattern (derived from: Model Validation Report 2026-04-26)

**Structure:**
1. Executive Summary — recommendation first, 3 key findings, decision required
2. Problem Statement — what's being evaluated, why it matters, Ken's stated concern (verbatim if available)
3. Comparative Analysis — structured comparison table with published data
4. Empirical Testing — actual execution, measured results, not just desk research
5. Cost Analysis — full breakdown with break-even, projections, real-cost framing
6. Quality & Risk Assessment — where each option fails, risk matrix
7. Recommendations — concrete routing rules or decision rules, not vague guidance
8. Expected Outcomes — directional impact table
9. Conclusion & Next Steps — approve/reject decision points, implementation steps
10. References — minimum 6 sources, all cited inline, captured date

**Standards:**
- Minimum 2 independent sources per factual claim
- All benchmarks cited to original source (not secondary)
- Empirical test results: include hardware, model version, exact timing, prompt used
- Recommendation must be actionable — "approve X, or send back with edits"
- Never mark done unless all sections complete and tested
- Output format: structured Markdown, saved to `reports/[topic]-[YYYY-MM-DD].md`
- Word count: 5,000–10,000 words (this is not a brief — it's a decision document)

**Validation:**
- All cited data checked against original source URL
- Empirical tests run on production hardware (not assumed)
- Recommendations cross-checked against SOUL.md standards and existing decisions

**Delivery:**
- Report saved to workspace `reports/`
- Obsidian copy filed under relevant domain
- Summary delivered to Ken in chat with: key finding, recommendation, 3 decision points

---

## Tier 2 — Standard Research (TO BE DEFINED)
_To be defined when US20 is picked up from backlog._

Likely: Sonnet, 1–2 hours, web research + synthesis, no empirical testing, structured output.

---

## Tier 3 — Quick Scan (TO BE DEFINED)
_To be defined when US20 is picked up from backlog._

Likely: Sonnet, 15–30 min, single-source lookup + summary, opinion/comparison, no testing.

---

## Tier 4 — Fact Check (TO BE DEFINED)
_To be defined when US20 is picked up from backlog._

Likely: Gemma4, 5 min, single question, verified answer with source link.

---

## Completed Deep Research Examples
| Date | Topic | Report | Key Finding |
|------|-------|--------|-------------|
| 2026-04-26 | Model Validation — Sonnet vs Gemma4 lead agent | `reports/model-config-proposal-2026-04-26.md` | Keep Sonnet 4.6 as default. Gemma4 = background fallback only. |
