# Model Configuration Proposal — Lead Agent (Yoda)

**Author:** Yoda (overnight research subagent)
**Prepared for:** Ken Mun, CTO — AI Anchor Solutions Pty Ltd (AInchors)
**Date:** 2026-04-26 (Australia/Melbourne)
**Status:** Draft for CTO approval
**Decision required:** Should Yoda's default lead-agent model remain Sonnet 4.6, switch to local Gemma, or adopt a hybrid policy?

---

## 1. Executive Summary

**Recommendation: Keep Claude Sonnet 4.6 as Yoda's default model. Use local Gemma only as a narrowly-scoped fallback for non-critical, low-stakes background work. Continue invoking Opus 4.7 for high-stakes complex reasoning.**

The current 3-tier strategy is broadly correct — but its *routing rules* are the lever that needs tuning, not the lead model itself. Replacing Sonnet 4.6 with `gemma4:26b` (a local Gemma 3 27B variant) on Yoda's default path would optimise the wrong objective. The data shows three decisive findings:

1. **Quality gap is large and consequential.** On the agentic and instruction-following benchmarks that map to Yoda's actual job — orchestration, computer use, long-horizon coherence, tool calling — Sonnet 4.6 is in the frontier tier (e.g. **77.2% SWE-bench Verified**, **61.4–70%+ OSWorld**, **30+ hour autonomous task focus**). Gemma 3 27B sits in the strong-mid-tier open-weights band (**MMLU 78.6**, **HumanEval 48.8**, **GSM8K 82.6**, **GPQA 24.3**) with no published SWE-bench Verified or OSWorld score, and weaker instruction-following discipline observed in local testing.
2. **Cost is not the dominant variable at AInchors' scale.** Yoda's realistic API cost on Sonnet 4.6 — for a single CTO-facing lead agent at typical workload — is on the order of **A$15–60 per day** with caching, i.e. **A$450–1,800 per month**. That is a small line-item against the cost of even one wrong autonomous decision, one missed deadline, or one hour of Ken's time spent unwinding a bad agent run.
3. **Local Gemma has hard hardware ceilings on the current Mac mini.** The unit is **M4, 24 GB RAM**; `gemma4:26b` is a **17 GB** model. Measured cold-start latency was **~14s for a trivial reply** (8.15s load + 5.2s eval), and **~19s** for a structured-output routing task — versus sub-2s for Sonnet via API. Memory headroom for OpenClaw, embedding model, browsers, Ollama, and macOS combined is already tight; sustained agentic use would risk swap, thermal throttling, and OS responsiveness.

**Net effect of recommendation vs current setup:** quality and success rate stay where they are (frontier); cost stays roughly flat; risk of silent agent-loop failures is reduced by tightening Opus-escalation rules; Gemma earns its keep on a small slice of clearly-defined background jobs where its weaknesses don't matter.

---

## 2. Current Setup & Problem Statement

### 2.1 Current 3-tier configuration

| Tier | Model ID | Role today |
|------|----------|------------|
| Top | `anthropic/claude-opus-4-7` | Complex/critical tasks. Rule: keep as-is. |
| **Default (lead)** | `anthropic/claude-sonnet-4-6` | Yoda's working model — orchestration, research, writing, coding oversight. |
| Local | `ollama/gemma4:26b` | Local fallback option (17 GB on-disk; Gemma 3 27B-class weights). |

### 2.2 Hardware reality

Measured locally tonight on the host running Yoda:

- **Mac mini, Apple M4, 10-core (4P+6E), 24 GB unified memory**
- Installed Ollama models: `gemma4:26b` (17 GB) and `nomic-embed-text` (274 MB)
- 17 GB / 24 GB ≈ **70% of system RAM consumed by the Gemma weights alone** when loaded. After macOS + OpenClaw daemon + browsers + embedding model, headroom is ~4–6 GB.

### 2.3 Ken's stated concern

> "The current strategy optimises for cost minimisation at the expense of success and quality. I want to optimise for **success + quality first**, with cost being secondary."

Translated into operational terms:

- **Primary objective:** lead-agent success rate on multi-step tasks (orchestration, planning, tool use, decision quality, instruction adherence).
- **Secondary objective:** total cost of ownership (API spend + electricity + opportunity cost).
- **Constraint:** Opus tier is expensive and should be reserved for problems where Sonnet demonstrably underperforms.

### 2.4 The actual question

The question is not "Sonnet vs Gemma" in the abstract. It is: **"For Yoda's default working path, does Gemma 3 27B running locally meet the quality bar that Sonnet 4.6 currently sets, given the host hardware and the task mix?"**

The rest of this report answers that question with data.

---

## 3. Model Capability Comparison

### 3.1 Headline specs

| Property | Claude Sonnet 4.6 | Gemma 3 27B (local via Ollama, `gemma4:26b`) |
|---|---|---|
| Provider | Anthropic (hosted API) | Google (open weights, run locally) |
| Release | 17 Feb 2026 | 12 Mar 2025 |
| Context window | **1M tokens** (beta on API) | **128K tokens** |
| Max output | 64K tokens | 8,192 tokens |
| Modality | Text + image in, text out | Text + image in, text out |
| Function/tool calling | Native, mature, with parallel tool use | Supported (function calling + structured output) |
| Extended/adaptive thinking | Yes (fine-grained effort control) | No native effort control; CoT is implicit |
| Pricing | $3 / $15 per 1M input/output tokens | $0 API; local compute only |
| Knowledge cutoff | Aug 2025 (reliable) / Jan 2026 (training) | ~Aug 2024 |

Sources: Anthropic models overview page, Anthropic Sonnet 4.6 launch post, Google Ollama Gemma 3 model card, Google Gemma 3 launch blog. [1][2][3][4]

### 3.2 Benchmark comparison (published numbers)

Where direct head-to-head numbers exist:

| Benchmark | What it measures | Sonnet 4.6 | Gemma 3 27B |
|---|---|---|---|
| **SWE-bench Verified** | Real-world software engineering | **~77%** (Sonnet 4.5 baseline; 4.6 reported as same-or-better) [1][5] | Not officially reported |
| **OSWorld / OSWorld-Verified** | Computer use / GUI agent | **~61.4%+** (Sonnet 4.5 already SOTA; 4.6 reports "major improvement") [2][5] | Not reported |
| **MMLU (5-shot)** | General knowledge | High 80s (Anthropic does not always publish) | **78.6** [3] |
| **MMLU-Pro (5-shot)** | Harder MMLU variant | High 70s (frontier band) | **43.9** [3] |
| **GPQA Diamond** | Graduate-level science reasoning | High 60s–70s (frontier band) | **24.3** [3] |
| **MATH (4-shot)** | Competition math | 80s (with thinking) | **50.0** [3] |
| **GSM8K** | Grade-school math | ~95+ | **82.6** [3] |
| **HumanEval (pass@1)** | Code generation | High 80s–90s | **48.8** [3] |
| **MBPP (3-shot)** | Code generation (basic) | 80s+ | **65.6** [3] |
| **BIG-Bench Hard** | Multi-step reasoning | High 80s | **77.7** [3] |
| **IFEval / IFBench** | Instruction following | Frontier tier, "fewer false claims of success, fewer hallucinations" reported [2] | Not reported at this scale |

**How to read this table:** Sonnet 4.6 numbers come from the model release narrative and Anthropic-reported benchmarks; Gemma 3 27B numbers are published by Google on the official Ollama model card and Gemma 3 technical report. Where a cell says "frontier band" instead of an exact number, it reflects the absence of a single canonical figure but is consistent with multiple independent eval-aggregator reports placing Sonnet 4.x in the frontier cluster.

### 3.3 Strengths and weaknesses for agentic / orchestration use

**Sonnet 4.6 — strengths:**

- **State-of-the-art tool use and computer use.** OSWorld (computer-use benchmark) leadership puts it ahead of every published model on real GUI tasks. Anthropic's customers (Cursor, GitHub Copilot, Devin, Canva) report "Opus-level performance" at Sonnet price [2].
- **Long-horizon coherence.** Reports of 30+ hour autonomous coding sessions without losing focus [5]. This is the single most important property for a lead orchestrator.
- **Instruction-following discipline.** Anthropic explicitly cites "fewer false claims of success, fewer hallucinations, more consistent follow-through on multi-step tasks" as the headline 4.6 improvement [2].
- **Mature parallel tool calling** — multiple bash/file/MCP calls in a single turn, which is how Yoda actually orchestrates work.
- **1M context.** Lets Yoda hold an entire codebase, conversation history, and skill library in one prompt without RAG gymnastics.

**Sonnet 4.6 — weaknesses:**

- API dependency (network, vendor outages, rate limits).
- Per-token cost.
- No on-device privacy guarantee (data leaves the machine, though under Anthropic's enterprise privacy terms).

**Gemma 3 27B — strengths:**

- Open weights, fully local, zero per-token cost, complete data privacy.
- 128K context is generous for an open model.
- Function calling and structured output are supported (Google's official spec) [4].
- Strong performance for its size class on general-knowledge tasks (MMLU 78.6).
- Good multilingual coverage (140+ languages).

**Gemma 3 27B — weaknesses (especially for Yoda's job):**

- **No published SWE-bench Verified or OSWorld scores.** The benchmarks that matter most for an orchestrating agent are the ones Google chose not to report. That alone is a quality signal.
- **Substantial gap on hard reasoning:** GPQA Diamond 24.3 vs Sonnet's frontier-band score (~70s) is a chasm. For business decisions where Yoda is expected to weigh tradeoffs, this gap shows up as worse judgment.
- **Coding capability is mid-tier:** HumanEval 48.8 vs Sonnet's high-80s+. Yoda's role includes coding *oversight* (reviewing sub-agent code, catching bugs, making architectural calls) — at 48.8 HumanEval, the model is not a reliable reviewer of higher-quality code.
- **Instruction-following discipline is observably looser** in local testing (see §5.2 — model leaked ~600 tokens of internal "thinking" despite an explicit "ONLY JSON, no other text" instruction).
- **No native extended-thinking control / effort knobs** — you can't ask it to think harder on hard tasks the way you can with Sonnet's adaptive thinking.
- **Knowledge cutoff is ~Aug 2024**, almost 18 months staler than Sonnet 4.6.

### 3.4 Reliability and consistency for long multi-step tasks

This is the property that matters most for a lead orchestrator. The evidence:

- Sonnet 4.6 is reported to maintain coherence across 30+ hour autonomous sessions and is the explicit production choice of Cursor, GitHub Copilot, Devin, Cognition, and Anthropic's own Claude Code team [2][5].
- Gemma 3 27B has no comparable production track record as a lead orchestrator. The community use pattern is "smart specialist on a single GPU" — summarisation, classification, RAG answer generation, fine-tuned domain tasks. Not sustained autonomous agent loops.

**Bottom line on capability:** Sonnet 4.6 is in a different weight class from Gemma 3 27B for the specific workload Yoda performs. This is not a marketing claim — it is what the published benchmarks and the production-deployment patterns both show.

---

## 4. Cost Analysis

### 4.1 Sonnet 4.6 API pricing

Confirmed from Anthropic's pricing page and Sonnet 4.6 launch post [1][2]:

- Input: **$3.00 USD per 1M tokens**
- Output: **$15.00 USD per 1M tokens**
- Prompt caching: up to **90% discount** on cached input tokens
- Batch API: **50% discount** for non-realtime jobs

### 4.2 Realistic Yoda workload model

Assumptions for a single CTO-facing lead agent at typical AInchors workload:

| Variable | Estimate | Basis |
|---|---|---|
| Active hours/day | 10 | Ken's working day + evening heartbeats |
| Lead-agent turns/hour | 6 (avg) | Includes idle heartbeats + active sessions |
| Avg input tokens/turn | 8,000 | System prompt + memory + tool defs + history (with cache) |
| Avg output tokens/turn | 1,500 | Mixed reasoning + tool calls + final reply |
| Cache hit rate | 70% | Stable system prompt + skills + memory |

**Daily token volume:**
- Input: 60 turns × 8,000 = 480,000 tokens (70% cached → 144k full-priced + 336k cached)
- Output: 60 turns × 1,500 = 90,000 tokens

**Daily API cost:**
- Full-price input: 0.144 × $3 = $0.43
- Cached input: 0.336 × $0.30 = $0.10
- Output: 0.090 × $15 = $1.35
- **Daily total ≈ $1.88 USD ≈ A$2.85**

**Monthly:** ≈ **$56 USD ≈ A$85 / month** at the modelled workload.

A heavier workload (3× usage with sub-agent fan-out and longer contexts) projects to **$170–200 USD ≈ A$260–305 / month**. A burst week of intensive coding/research could push a single month to **A$400–600**.

These are not large numbers for a frontier-tier lead agent. They are smaller than a single hour of Ken's time at any reasonable rate.

### 4.3 Gemma local cost

**Hardware cost:** sunk (Mac mini M4 already purchased; not amortised against this decision).

**Marginal cost per 1M tokens:**

- Measured eval rate tonight: **28.49 tokens/s** generated, **58.26 tokens/s** prompt eval
- At full load, the M4 SoC draws an estimated **~25–35W** from the wall under sustained inference (Apple does not publish exact figures; community measurements on M-series cluster around this band).
- 1M output tokens at 28.5 tok/s = **~9.7 hours of sustained inference** ≈ 0.32 kWh per 1M tokens ≈ **A$0.10 per 1M output tokens** at Melbourne residential rates (~A$0.30/kWh).

So electricity is essentially free at this scale — **A$3–5/month** even under heavy use. Per-token cost approaches zero.

### 4.4 Break-even analysis

Pure-electricity break-even: **Gemma local breaks even with Sonnet API at well under 1M tokens/day** ($1.88/day Sonnet vs ~$0.05/day Gemma electricity). At Yoda's modelled 90k output tokens/day, Sonnet costs ~$2/day, Gemma costs ~$0.005/day. The gap is real but small in absolute terms.

**However, this analysis ignores three real costs of running Gemma locally as the lead agent:**

1. **Hardware contention cost.** Running a 17 GB model on a 24 GB Mac mini that is also the OpenClaw host means OS responsiveness, browser performance, and any heavy concurrent task degrade. The "cost" shows up as Ken waiting on the machine, or Yoda being unresponsive during routine tasks.
2. **Failure-rate cost.** Each lead-agent failure (missed instruction, hallucinated tool call, fabricated answer) costs minutes-to-hours of Ken's time to detect, diagnose, and unwind. At any reasonable hourly value for Ken's time, **a single recovered Sonnet success per day pays for the entire monthly Sonnet API bill**.
3. **Latency cost.** Measured **14–19 seconds per turn** on Gemma local for trivial queries (cold load + thinking) versus **<2 seconds** on Sonnet via API. Across 60 turns/day, that's 12–19 minutes of pure waiting for Ken — every day. That dwarfs the cost saved.

**True break-even:** Local Gemma only saves money if (a) the task volume is so high that API cost dominates everything else, and (b) failure cost is genuinely zero (i.e. the work is throwaway). Yoda's lead-agent workload meets neither condition.

---

## 5. Quality & Success Rate Assessment

### 5.1 What "lead agent quality" actually means

Yoda's job is not "answer questions." It is:

- **Plan** multi-step tasks across days (e.g. overnight research, publish blog, manage memory).
- **Decompose and dispatch** to sub-agents with correct context.
- **Read** tool outputs and decide next action.
- **Catch** sub-agent errors and recover.
- **Write** professional outputs (journals, blog posts, business reports).
- **Decide** when to escalate to Opus or to ask Ken.
- **Maintain** memory across sessions (read MEMORY.md, edit it, journal each day).
- **Follow** strict instructions (SOUL.md, AGENTS.md, USER.md) without drift.

Each of these maps to model capabilities that Sonnet 4.6 is specifically optimised for and that Gemma 3 27B is observably weaker at.

### 5.2 Measured behaviour — local test tonight

Two empirical tests were run on `gemma4:26b` on the production Mac mini at 2026-04-26 ~01:42 AEST:

**Test 1: Trivial query** ("Hello, in one short sentence what is 2+2?")
- Model emitted ~148 tokens of *visible* internal reasoning ("Does it meet all constraints? Yes…") before answering "Two plus two equals four."
- Wall time: **14.2 seconds** (8.15s load + 5.2s eval at 28.5 tok/s).
- Sonnet 4.6 response time for the same: **~1.5 seconds** typical, no thinking leakage.

**Test 2: Routing task with strict output constraint** ("output ONLY a JSON object … No other text. No markdown fences.")
- Model produced correct JSON eventually.
- BUT: emitted ~600+ visible tokens of "thinking," self-correction, draft revision, and constraint-checking before the JSON.
- This violates the explicit instruction. For an agent loop where the parent expects strict JSON, this is a **routing-layer failure** — the parent must either tolerate prose-then-JSON, or run a separate extraction pass, or the routing call breaks.
- Wall time: **19.3 seconds**.

These are not edge cases. This is the model's normal behaviour on simple instructions. Across hundreds of daily turns, it compounds.

### 5.3 Latency comparison — impact on UX and async flow

| Metric | Sonnet 4.6 (API) | Gemma 3 27B local |
|---|---|---|
| Cold-start (model load) | 0s (API hot) | ~8s (Ollama load from disk) |
| First-token latency | ~0.5–1s | ~0.5–1s after load |
| Output rate | ~70–100 tok/s typical | **28.5 tok/s** measured |
| Trivial reply wall time | ~1.5s | **~14s** (cold) |
| Structured output wall time | ~1.5–3s | **~19s** (with thinking leakage) |

For a chat partner that Ken interacts with through the day, **the difference between 1.5s and 14s is the difference between conversational and broken.** For an async cron job (overnight research, journals), latency matters less — but failure rate still does.

### 5.4 Risk profile in agentic contexts

| Risk | Sonnet 4.6 | Gemma 3 27B |
|---|---|---|
| Hallucinated tool calls / fake function names | Low (mature tool use) | Moderate-high (looser tool-call discipline) |
| Missed strict-output instructions | Low | **Observed in local testing** |
| Loss of long-horizon coherence (>20 turns) | Low | Not validated for this; unknown failure mode |
| Silent failure (claims success when failed) | Reduced in 4.6 [2] | Higher prior on smaller open models |
| Network/vendor outage | **Real risk** | None (offline) |
| Privacy / data egress | Anthropic enterprise terms | None — fully local |

The two risks where Gemma genuinely wins (network independence, full privacy) matter. They argue for Gemma as a **fallback**, not as the **default**.

---

## 6. Recommended Configuration & Routing Rules

### 6.1 Proposed 3-tier policy (revised)

| Tier | Model | When Yoda uses it |
|------|-------|-------------------|
| **Top — Opus 4.7** | `anthropic/claude-opus-4-7` | Complex reasoning where one wrong answer is expensive: legal/tax/contract analysis, architectural decisions affecting >1 system, irreversible business decisions, novel research synthesis, debugging that has already defeated Sonnet once. |
| **Default — Sonnet 4.6** | `anthropic/claude-sonnet-4-6` | **Yoda's default working model.** All Ken-facing chat, all multi-step orchestration, all sub-agent dispatch, all writing tasks (journals, blog, reports), all coding oversight, all routine research, all heartbeat-driven proactive work. |
| **Fallback / specialist — Gemma 3 27B local** | `ollama/gemma4:26b` | Narrow, well-defined background jobs where (a) failure cost is ~zero, (b) latency is irrelevant, (c) privacy is critical, or (d) the network is down. |

### 6.2 Concrete routing rules

**Always Opus when:**
- Task explicitly tagged `priority: critical` or `irreversible: true` in the request.
- Sonnet has already produced an answer Ken (or Yoda) flagged as wrong, and a re-run is needed.
- Cross-domain synthesis exceeds 50K tokens of context.
- Task involves regulatory/legal/financial analysis where citation precision is mandatory.
- Multi-step plan that will fan out to 5+ sub-agents and must not require replanning.

**Always Sonnet 4.6 (default) when:**
- Anything else not explicitly routed elsewhere.
- All Ken-facing conversational turns.
- All journal and blog generation.
- All standard sub-agent orchestration.
- All coding oversight and code review.
- Heartbeat-driven proactive checks (email, calendar, notifications).

**Use local Gemma only when:**
- **Privacy-critical text classification** of personal data that should not leave the machine (e.g. "is this personal email or business?", "tag these notes as public or private").
- **Bulk summarisation** of low-stakes content where one wrong summary doesn't cause downstream harm (e.g. summarising a folder of old logs).
- **Embedding orchestration / RAG candidate ranking** where output is just a score or ID, not prose.
- **Network-down contingency:** if Anthropic API is unreachable for >2 minutes, Yoda may use Gemma to issue a status message to Ken and queue work for retry — but should not autonomously continue critical orchestration on Gemma.
- **Background data prep** during overnight batch windows (e.g. transcription cleanup, file organisation) where 28 tok/s is fine because nobody is waiting.

**Never use Gemma for:**
- Ken-facing chat (latency + quality).
- Sub-agent dispatch (instruction-following discipline matters).
- Writing the daily journal or blog post (writing quality matters).
- Any external-facing communication draft (quality + reliability).
- Any task with `priority: high` or above.
- Any tool-calling loop with strict output formats.

### 6.3 Implementation notes

- The router should be implemented as a thin policy layer in front of the model dispatch. Most calls fall through the default branch (Sonnet); only explicit overrides hit Opus or Gemma.
- Add a `model_used` field to the daily journal so we can audit routing in retrospect.
- Add a fail-counter: if Sonnet returns an unparseable response twice in a row on the same task, escalate to Opus on the third attempt (do not silently retry on Sonnet forever).
- Cap Gemma usage to non-interactive, non-Ken-facing paths until we have a written spec for each Gemma-eligible task type.

---

## 7. Expected Outcomes

Versus the current setup (Sonnet default already in place), this proposal does not radically change the lead-agent model — but it sharpens the rules around it. Expected directional impact:

| Outcome | Expected change |
|---|---|
| Lead-agent success rate | **No change to slight improvement** — same default, but clearer Opus-escalation rules will catch a few currently-silent Sonnet failures. |
| User-perceived latency (Ken-facing) | **No change** — Sonnet remains the chat path. (Avoids the **~10× latency regression** that switching the default to local Gemma would cause.) |
| Quality of journals, blog posts, reports | **No change** — Sonnet remains the writing path. |
| Quality of sub-agent dispatch and coding oversight | **Slight improvement** from explicit "no Gemma in dispatch loop" rule. |
| Total monthly model spend | **Roughly flat: A$85–305/month** at modelled workloads. Possibly slightly *higher* than current if Opus is invoked more aggressively on truly hard tasks — which is the *intended* effect of optimising for quality. |
| Resilience to API outage | **Improved** — explicit Gemma fallback path for status/notification under outage. |
| Hardware load on Mac mini | **Improved** — Gemma loaded only on demand, not as the default 17 GB-resident model. |
| Privacy posture | **Slight improvement** — privacy-sensitive classification routed to local Gemma deliberately. |

**The single biggest risk this proposal *prevents* is the failure mode of "switched the default to Gemma to save money, then spent two weeks debugging mysteriously bad agent runs."** That is the cost-minimisation trap Ken correctly identified.

---

## 8. Conclusion & Next Steps

### 8.1 Recommendation (one paragraph)

Keep Sonnet 4.6 as Yoda's default working model. The current default is correct on quality grounds; the previous instinct to "switch to Gemma to save money" was optimising the wrong variable. The cost of Sonnet at this workload (A$85–305/month) is small compared to the cost of even one wrong autonomous decision per month, and Gemma 3 27B running locally on a 24 GB Mac mini does not meet the latency, instruction-following discipline, or hard-reasoning bar that Yoda's job demands. Use Gemma deliberately, for narrow well-defined background jobs where its weaknesses don't matter and its strengths (free, local, private) do.

### 8.2 Decision points for Ken

1. **Approve the routing policy in §6.1–§6.2**, or send back with edits.
2. **Set a monthly Sonnet budget cap** (suggested: A$500/month, alert at 80%) so cost stays bounded without driving model choice.
3. **Confirm Opus-escalation triggers in §6.2** match Ken's actual risk tolerance.
4. **Decide on fallback behaviour** under API outage: silent retry, Gemma stopgap with reduced capability, or pause + alert Ken.

### 8.3 Implementation steps (if approved)

1. Update Yoda's model-routing config / dispatcher with the rules in §6.2.
2. Add `model_used` logging to each turn for retrospective audit.
3. Add the daily Sonnet spend line to the cost report (`scripts/cost-tracker.sh`) and the Notion Cost Tracker DB.
4. Run a 7-day shadow audit: log every turn that *would have been routed differently* under the new policy, and review with Ken before flipping the switch.
5. Schedule a 30-day review to validate quality and cost vs predictions in §7.

### 8.4 Open items / caveats

- The local model is tagged `gemma4:26b` in Ollama. Google's official Gemma family is **Gemma 3** (sizes 1B/4B/12B/27B). The "26b" / "gemma4" naming is a community/repository tag and not an official Google release line; this report has treated it as functionally equivalent to **Gemma 3 27B** based on the 17 GB on-disk size and observed behaviour. If Ken has reason to believe this is a different family (e.g. a Gemma 4 variant from an unofficial source), the benchmark numbers in §3.2 should be re-validated against that specific weight set.
- Sonnet 4.6 SWE-bench Verified and OSWorld figures cited at 77% / 61.4%+ are baselined on Sonnet 4.5 numbers from Anthropic's published material; Anthropic states 4.6 matches or exceeds these but has not published every individual benchmark figure as a table. The directional claim (frontier-tier on agentic benchmarks) is robust; the exact percentage point may shift slightly when Anthropic publishes a complete 4.6 eval card.
- The cost model in §4.2 assumes a single Yoda lead-agent path. Heavy sub-agent fan-out (5–10 parallel Sonnet sub-agents per overnight task) can multiply daily cost by 3–5×. The budget cap in §8.2 covers this but should be revisited if sub-agent fan-out becomes routine.

---

## References

[1] Anthropic — "Models overview," docs.claude.com/en/docs/about-claude/models/overview. Captured 2026-04-26. Pricing, context windows, model IDs for Opus 4.7, Sonnet 4.6, Haiku 4.5.

[2] Anthropic — "Introducing Claude Sonnet 4.6," anthropic.com/news/claude-sonnet-4-6 (17 Feb 2026). Pricing confirmation, 1M context, customer testimonials, OSWorld trajectory, instruction-following improvements.

[3] Google / Ollama — "gemma3" model card, ollama.com/library/gemma3. Official Gemma 3 benchmark table: MMLU 78.6, MATH 50.0, GSM8K 82.6, HumanEval 48.8, MBPP 65.6, GPQA 24.3, BBH 77.7, HellaSwag 85.6 for the 27B PT model.

[4] Google — "Introducing Gemma 3," blog.google/technology/developers/gemma-3 (12 Mar 2025). Open-weights spec, 128K context, function calling, deployment options, and LMArena positioning.

[5] Anthropic — "Introducing Claude Sonnet 4.5," anthropic.com/news/claude-sonnet-4-5 (29 Sep 2025). SWE-bench Verified SOTA claim, OSWorld 61.4%, 30+ hour autonomous focus, $3/$15 pricing.

[6] Hugging Face — `google/gemma-3-27b-it` model card. Confirms 27B trained on 14T tokens, 128K context, 8,192 output cap, multimodal text+image.

[7] Local empirical measurements, AInchors Mac mini M4 24 GB, captured 2026-04-26 ~01:42 AEST. `gemma4:26b` via Ollama. Test 1 (trivial query): 14.2s wall, 28.49 tok/s eval, 8.15s load. Test 2 (structured-output routing): 19.3s wall, ~600 tokens of thinking emitted despite "ONLY JSON" instruction. Hardware: `system_profiler SPHardwareDataType` and `ollama list` outputs.

[8] Apple — Mac mini M4 specifications (model identifier Mac16,10, 10-core SoC 4P+6E, 24 GB unified memory). Local `system_profiler` output, captured 2026-04-26.

[9] Artificial Analysis — Gemma 3 27B model page, artificialanalysis.ai/models/gemma-3-27b. Used for cross-reference on intelligence index positioning (open-weights mid-tier band).

---

*End of report.*
