# Research Framework — AInchors
_Created: 2026-04-26 | Updated: 2026-04-29 | Status: All tiers defined (US20). Approved by Ken 18:05 AEST 2026-04-29._

---

## Purpose
Define what research means at AInchors — the scope, depth, execution effort, and validation standard for each tier. This is the service catalogue for `/research`.

When Ken commissions research, he names the tier. The agent knows exactly what to deliver.

---

## Tier Summary

| Tier | Name | Model | Effort | Use When |
|------|------|-------|--------|----------|
| T1 | Deep Research | Sonnet (escalate to Opus if needed) | 3–6 hrs | High-stakes, strategic, irreversible decisions |
| T2 | Standard Research | Sonnet | 1–2 hrs | Evaluations, comparisons, planning inputs |
| T3 | Quick Scan | Sonnet | 15–30 min | Directional answers, topic overviews |
| T4 | Fact Check | Haiku | 5 min | Single verifiable fact + source |

---

## Tier 1 — Deep Research

**Model:** Sonnet (Opus if 2× failed or Ken escalates)
**Effort:** 3–6 hours (isolated sub-agent session)
**Trigger:** `/research t1 [topic]`
**When to use:** Decisions that are high-stakes, strategic, or irreversible. Architectural choices, vendor selections, model strategy, competitive analysis, compliance questions.

### Output Structure
1. Executive Summary — recommendation first, 3 key findings, decision required
2. Problem Statement — what's being evaluated, why it matters, Ken's concern (verbatim if available)
3. Comparative Analysis — structured comparison table with published data
4. Empirical Testing — actual execution, measured results, not desk research alone
5. Cost Analysis — full breakdown with break-even, projections, real-cost framing
6. Quality & Risk Assessment — where each option fails, risk matrix
7. Recommendations — concrete actionable rules, not vague guidance
8. Expected Outcomes — directional impact table
9. Conclusion & Next Steps — approve/reject decision points, implementation steps
10. References — minimum 6 sources, all cited inline, captured date

### Standards
- Minimum 2 independent sources per factual claim
- All benchmarks cited to original source (not secondary)
- Empirical test results: include hardware, model version, exact timing, prompt used
- Word count: 5,000–10,000 words
- Output: `reports/[topic]-[YYYY-MM-DD].md` + Notion Research Log entry

---

## Tier 2 — Standard Research

**Model:** Sonnet
**Effort:** 1–2 hours (isolated sub-agent)
**Trigger:** `/research t2 [topic]`
**When to use:** Evaluations, vendor comparisons, tool assessments, planning inputs where empirical testing is not required.

### Output Structure
1. Summary — recommendation + 3 key findings (half page max)
2. Context — what's being researched and why
3. Analysis — web research + synthesis, structured findings, no empirical testing required
4. Options Compared — table with pros/cons/cost/fit for each option
5. Recommendation — clear preferred option with rationale
6. References — minimum 3 sources, all cited

### Standards
- Minimum 2 independent sources per factual claim
- Web research required — no hallucinated data
- Word count: 1,500–4,000 words
- Output: `reports/[topic]-[YYYY-MM-DD].md` + Notion Research Log entry

---

## Tier 3 — Quick Scan

**Model:** Sonnet
**Effort:** 15–30 minutes (isolated sub-agent)
**Trigger:** `/research t3 [topic]`
**When to use:** Directional answers, topic overviews, "what is X", "how does Y work", orientation before a deeper decision.

### Output Structure
1. TL;DR — 2–3 sentences, the answer up front
2. Key Points — 5–8 bullets, no fluff
3. Caveats — what this scan does NOT cover
4. Sources — minimum 2 links

### Standards
- Minimum 2 sources checked (not just cited)
- No fabricated data — if unsure, flag it
- Word count: 300–800 words
- Output: delivered inline to chat + brief `reports/scan-[topic]-[YYYY-MM-DD].md`

---

## Tier 4 — Fact Check

**Model:** Haiku
**Effort:** 5 minutes (inline, no sub-agent)
**Trigger:** `/research t4 [question]`
**When to use:** Single verifiable fact. "What is X's current price?", "Is Y compatible with Z?", "When did X happen?"

### Output Structure
1. Answer — one sentence
2. Source — one URL, verified
3. Confidence — High / Medium / Low with reason if not High

### Standards
- Must verify against live source (web search required)
- If fact cannot be verified with confidence → escalate to T3
- Word count: 1–3 sentences
- Output: delivered inline to chat only (no report file)

---

## Routing Rules (for `/research` command)

```
/research t1 [topic]  →  Spawn isolated Sonnet sub-agent, 3-6hr budget
/research t2 [topic]  →  Spawn isolated Sonnet sub-agent, 1-2hr budget
/research t3 [topic]  →  Spawn isolated Sonnet sub-agent, 30min budget
/research t4 [topic]  →  Run inline with Haiku, no sub-agent
/research [topic]     →  Yoda asks: "Which tier? T1 (deep) / T2 (standard) / T3 (scan) / T4 (fact)?"
```

**Output registry:** Every T1–T3 research run logged to `state/research-registry.json`.
**Notion:** T1 and T2 auto-filed to AKB Research Log. T3 filed if Ken requests.

---

## Completed Research Log
| Date | Tier | Topic | Report | Key Finding |
|------|------|-------|--------|-------------|
| 2026-04-26 | T1 | Model Validation — Sonnet vs Gemma4 | `reports/model-config-proposal-2026-04-26.md` | Keep Sonnet as default. Gemma4 = background only. |
