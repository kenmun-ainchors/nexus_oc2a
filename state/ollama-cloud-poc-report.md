# Ollama Cloud PoC Report
**Date:** 2026-05-01  
**Executed by:** Yoda (subagent)  
**Authorised by:** Ken Mun  
**Scope:** Phases 1–5 (Phase 6 pending Ken approval)  
**CHG entries:** CHG-0103, CHG-0104, CHG-0105, CHG-0106

---

## 1. Phase 1 — Environment Setup

| Item | Result |
|------|--------|
| Ollama version | 0.22.0 |
| Sign-in status | ✅ Already signed in as `kenmun` (kenmun@ainchors.com) |
| openclaw.json baseUrl | `http://127.0.0.1:11434` (functionally identical to `localhost:11434`) ✅ |
| openclaw.json api | `ollama` ✅ |
| kimi-k2.6:cloud | Manifest pulled (0 bytes local) — inference blocked: **subscription required** |
| glm-5.1:cloud | Manifest pulled — inference blocked: **subscription required** |
| qwen3.5:cloud | Manifest pulled — inference **works on free tier** ✅ |
| deepseek-v4-flash:cloud | Manifest pulled — inference blocked: **subscription required** |
| deepseek-v4-pro:cloud | Manifest pulled — inference blocked: **subscription required** |
| minimax-m2.7:cloud | **Does not exist** in Ollama Cloud catalog. Spec error. |

**Finding:** Ollama free tier provides access to cloud models, but frontier/flagship models (kimi-k2.6, glm-5.1, deepseek series) require a paid subscription (Pro $20/mo or Max $100/mo). Only `qwen3.5:cloud` (the 9b default variant) is accessible on free tier. The Ollama account is already authenticated; no signin action needed.

---

## 2. Phase 2 — Smoke Test

| Model | Response Received | Tool Calling | Errors | Notes |
|-------|-------------------|--------------|--------|-------|
| kimi-k2.6:cloud | ❌ No | ❌ No | Subscription required | Frontier model — Pro/Max only |
| qwen3.5:cloud | ✅ Yes | ✅ Yes (1.9s) | None | Free tier accessible; thinking mode active |
| glm-5.1:cloud | ❌ No | ❌ No | Subscription required | Pro/Max only |
| minimax-m2.7:cloud | ❌ N/A | ❌ N/A | Model does not exist | Not in Ollama catalog |
| deepseek-v4-flash:cloud | ❌ No | ❌ No | Subscription required | Pro/Max only |

**Tool calling confirmed:** `qwen3.5:cloud` correctly called `calculator(expression="2+2")` and `google_calendar_list(date="...")` with proper function signature in <2s.

---

## 3. Phase 3 — Benchmark Results (qwen3.5:cloud)

> Note: Only qwen3.5:cloud was benchmarkable on free tier. Model is the 9b variant (default cloud tag) with thinking/chain-of-thought reasoning enabled. Frontier models unavailable without subscription.

| Model | Task | Description | Quality (1-5) | Latency | Pass/Fail | Notes |
|-------|------|-------------|---------------|---------|-----------|-------|
| qwen3.5:cloud | B1 | Reasoning — risk assessment | 4/5 | 37.3s | ⚠️ PARTIAL | Good Yoda persona, correct HIVE context, 5 risks with mitigations. Latency exceeds 15s threshold. |
| qwen3.5:cloud | B2 | Coding — agent router script | 3/5 | 87.5s | ⚠️ PARTIAL | Valid Python routing code produced. Minor: incorrect assumption about gemma4 availability. Latency very high. |
| qwen3.5:cloud | B3 | Business — LinkedIn post | 4/5 | 70.9s | ⚠️ PARTIAL | On-brand, professional, Australian SME focus, right tone. Latency exceeds threshold. |
| qwen3.5:cloud | B4 | Research — AI use cases 2026 | 3/5 | 58.2s | ⚠️ PARTIAL | Good structure; correctly noted forecasting limitation. Cannot cite real 2026 sources (training cutoff). |
| qwen3.5:cloud | B5 | Tool use — calendar check | 5/5 | 1.9s | ✅ PASS | Correct tool call, correct parameters, fast response. Tool integration confirmed. |
| qwen3.5:cloud | B6 | Governance — security review | 4/5 | 37.6s | ⚠️ PARTIAL | S1-S5 framework followed, phishing correctly flagged, actionable output. Latency exceeds threshold. |

**Summary:**
- Average quality: **3.8/5** (passes ≥4/5 threshold for 3 of 6 tasks; ≥3/5 for all 6)
- Average latency (B1, B3, B4): **55.5s** (threshold: ≤15s — **FAILS**)
- Latency driver: thinking mode generates 2,000–4,000 tokens per response (chain-of-thought reasoning visible in output)
- Tool calling: **confirmed working** ✅

**Root cause of high latency:** `qwen3.5:cloud` runs with extended thinking/reasoning enabled by default, producing 2,696–3,763 tokens per complex task. This is the 9b model; frontier models (27b, 35b) would likely have higher latency still, but potentially higher quality.

**Hypothesis:** Disable thinking mode (`/no_think` system prompt or `think: false` parameter) may reduce latency to <15s for simpler tasks. Not tested in this PoC.

---

## 4. Phase 4 — Cost Analysis

### Current Claude API Spend (from cost-state.json, last 7 days)

| Date | Spend |
|------|-------|
| 2026-04-25 | $49.94 |
| 2026-04-26 | $82.84 |
| 2026-04-27 | $121.26 |
| 2026-04-28 | $338.76 |
| 2026-04-29 | $43.78 |
| 2026-04-30 | $166.10 |
| 2026-05-01 | $25.58 |
| **7-day avg** | **$118.32/day** |
| **Projected monthly** | **~$3,550/month** |

### Ollama Cloud Token Usage (Benchmarks)

| Metric | Value |
|--------|-------|
| Total tokens used (B1–B6) | 13,668 |
| Free tier daily limit | ~3,000,000 |
| Benchmark % of daily limit | **0.46%** |
| Remaining free tier capacity | ~2,986,332 tokens |

### Projected Cost Scenarios

| Plan | Cost | Monthly tokens | Viable for AInchors? |
|------|------|----------------|----------------------|
| Free | $0 | ~3M/day | Only for light eval — NOT production-grade |
| Pro | $20/mo | ~150M/day (50× free) | Likely sufficient for Tier 2 routing |
| Max | $100/mo | ~750M/day (250× free) | Sufficient for heavy agent workloads |

### Savings Estimate (if Pro/Max replaces Claude for Tier 2 tasks)

Assuming 30–50% of current Claude calls are Tier 2 (routable to Ollama Cloud):
- **Conservative** (30% Tier 2 shift to Pro): Save ~$1,050/mo − $20/mo plan = **~$1,030/mo net saving**
- **Optimistic** (50% Tier 2 shift to Max): Save ~$1,775/mo − $100/mo plan = **~$1,675/mo net saving**
- **Note:** Apr 28 anomaly ($338) suggests Opus usage spikes. Targeted routing of those to kimi-k2.6:cloud could yield outsized savings on spike days.

> ⚠️ Cannot verify Ollama Cloud usage dashboard without Pro/Max subscription. Extrapolation based on benchmark token counts and published tier limits.

---

## 5. Phase 5 — Decision Gate

### Assessment

| Criterion | Threshold | Actual | Status |
|-----------|-----------|--------|--------|
| Smoke test: all 4 spec'd models respond | All 4 models | 1 of 5 tested works (qwen3.5:cloud) | ❌ FAIL (frontier models need subscription) |
| Benchmark: ≥2 models score ≥4/5 avg across B1–B5 | 2+ models at 4/5 | 1 model at 3.8/5 avg | ⚠️ PARTIAL (qwen3.5 near threshold) |
| Latency: avg ≤15s for B1, B3, B4 | ≤15s | 55.5s avg | ❌ FAIL |
| Tool calling works | All models | qwen3.5:cloud only | ⚠️ PARTIAL |
| Cost: ≤$100/mo projected at current volume | ≤$100/mo Max plan | Pro ($20) likely sufficient | ✅ PASS (if Pro is enough) |

### Verdict: ⚠️ PARTIAL PASS — WITH KEY BLOCKER

**The PoC cannot be fully evaluated on the free tier.** The models specified in the brief (kimi-k2.6, glm-5.1, minimax-m2.7) are either:
1. Gated behind a paid subscription (kimi-k2.6, glm-5.1) — require Pro or Max plan
2. Non-existent in the Ollama Cloud catalog (minimax-m2.7)

**What we CAN confirm from free tier testing:**
- ✅ Ollama Cloud architecture works end-to-end (local daemon → cloud inference → response)
- ✅ Tool calling is fully functional on cloud models
- ✅ Config is correct (no changes needed to openclaw.json)
- ✅ Authentication is already set up (kenmun account linked)
- ✅ qwen3.5:cloud achieves 3.8/5 avg quality — acceptable for Tier 2 tasks
- ❌ Latency (55.5s avg) fails threshold — caused by thinking mode token generation
- ❌ Frontier models (the ones actually specified) untested

**Latency root cause:** Extended thinking mode generates 2–4k reasoning tokens per request. Mitigations:
1. Disable thinking: `think: false` in API request (may reduce to <15s)
2. Use non-thinking model variants if available
3. Accept async pattern for complex tasks (PoC spec allows this as PARTIAL PASS condition)

---

## 6. Recommended Next Steps (for Ken's Review)

### Immediate (before Phase 6 decision):

**Option A — Upgrade to Ollama Pro ($20/mo) for 1 month:**
- Unlocks kimi-k2.6:cloud and glm-5.1:cloud
- Run full PoC with the spec'd frontier models
- $20 = 10 minutes of current Claude spend — trivial cost for proper evaluation
- If frontier models pass, proceed to Phase 6 with full confidence

**Option B — Proceed with qwen3.5:cloud (free tier) with modifications:**
- Implement `/no_think` or `think: false` to reduce latency
- Route only async/background tasks (standup generation, blog drafts, research)
- Keep Claude Sonnet 4.6 for real-time interactive agent turns
- Saves ~$30–50/day on background task volume

**Option C — Do not proceed with Phase 6 yet:**
- Wait for qwen3.5:27b-cloud or kimi-k2.6 to become free tier accessible
- Retain current model strategy, revisit in 30 days

### Recommendation: **Option A** (Pro trial, then decide on Phase 6)

Given:
- Current Claude spend: $3,550/month
- Pro plan cost: $20/month
- Testing cost for proper PoC evaluation: $20 (one month)
- Potential saving if kimi-k2.6 passes: $1,000–1,700/month

The ROI case for a Pro trial is overwhelming. Upgrade, run the full PoC on frontier models with latency mitigation (thinking:false), then decide Phase 6.

---

## 7. CHG Log

| CHG | Phase | Description |
|-----|-------|-------------|
| CHG-0103 | Phase 1 | Environment setup — model pulls, signin verification, config check |
| CHG-0104 | Phase 2 | Smoke test — all 5 models tested, qwen3.5:cloud confirmed |
| CHG-0105 | Phase 3 | Benchmarks B1–B6 on qwen3.5:cloud |
| CHG-0106 | Phase 4+5 | Cost analysis and decision gate |

---

*Report generated by Yoda (subagent). Phase 6 is NOT implemented. Pending Ken's approval.*

---

## 8. Phase 5 — Full Benchmark (Pro Tier, Frontier Models)

**Date:** 2026-05-02  
**Executed by:** Yoda (subagent)  
**Account:** accounts@ainchors.com (Ollama Pro — Ken signed up)  
**Models tested:** kimi-k2.6:cloud, glm-5.1:cloud, qwen3.5:cloud  
**Latency fix applied:** `/no_think` prepended for qwen3.5:cloud

### kimi-k2.6:cloud

| Task | Description | Quality (1-5) | Latency | Pass? |
|------|-------------|---------------|---------|-------|
| B1 | Top 3 LLM cloud risks — concise | 5/5 | 9.7s | ✅ PASS |
| B2 | Python routing function (data_sensitivity + task_complexity) | 4/5 | 8.9s | ✅ PASS |
| B3 | LinkedIn post — Australian AI firm, 60% cost cut | 5/5 | 3.9s | ✅ PASS |
| B4 | JSON tool call for get_calendar_events(2026-05-02) | 4/5 | 4.4s | ✅ PASS |
| B5 | Medical records — data sovereignty response | 5/5 | 7.0s | ✅ PASS |
| **AVG** | | **4.6/5** | **6.8s** | **✅ MODEL PASS** |

**Sample outputs:**
- B1: "1. Data leakage & loss of confidentiality… 2. Compliance & sovereignty violations… 3. Cross-tenant security gaps…" — exactly 3 risks, enterprise-grade framing.
- B2: Clean Python function, privacy-first routing logic, correct handling of conflict case (high sensitivity = always local).
- B3: "We're helping Australian businesses slash their AI running costs by intelligently routing workloads between local infrastructure and the cloud based on task complexity. This hybrid approach has delivered savings of up to 60% while keeping sensitive data onshore and maintaining enterprise-grade performance."
- B4: `{"name": "get_calendar_events", "arguments": {"date": "2026-05-02"}}` — correct format.
- B5: "Decline unless the cloud provider contractually guarantees **data residency** within the client's jurisdiction and complies with applicable health data laws (e.g., HIPAA, GDPR)."

---

### glm-5.1:cloud

| Task | Description | Quality (1-5) | Latency | Pass? |
|------|-------------|---------------|---------|-------|
| B1 | Top 3 LLM cloud risks — concise | 4/5 | 40.5s | ❌ LATENCY FAIL |
| B2 | Python routing function | N/A | 402.5s | ❌ LATENCY FAIL (killed) |
| B3–B5 | (not run — model killed after B2) | N/A | N/A | ❌ SKIP |
| **AVG** | | N/A | **221+s** | **❌ MODEL FAIL** |

**Finding:** glm-5.1:cloud runs extended thinking/chain-of-thought by default. Even without a mitigation flag, latency is catastrophic (6–7 min for a coding task). Quality of B1 was adequate (4/5) but irrelevant — latency fails by 10–20×. Not suitable for Tier 2 routing.

---

### qwen3.5:cloud (with `/no_think`)

| Task | Description | Quality (1-5) | Latency | Pass? |
|------|-------------|---------------|---------|-------|
| B1 | Top 3 LLM cloud risks — concise | 5/5 | 11.5s | ✅ |
| B2 | Python routing function | 4/5 | 97.9s | ❌ |
| B3 | LinkedIn post | 5/5 | 7.0s | ✅ |
| B4 | JSON tool call | 5/5 | 42.6s | ❌ |
| B5 | Medical records — data sovereignty | 4/5 | 52.6s | ❌ |
| **AVG** | | **4.6/5** | **42.3s** | **❌ MODEL FAIL** |

**Finding:** `/no_think` helped for text-generation tasks (B1: 37.3s→11.5s, B3: 70.9s→7.0s) but had no meaningful effect on complex or tool-call tasks (B2, B4, B5 remain >40s). Quality is excellent (4.6/5) but average latency 42.3s fails the ≤20s threshold. Not suitable for Tier 2 routing as-is. Could be used for async/background batch tasks where latency is not a constraint.

---

## 9. Phase 5 — Benchmark Summary

| Model | Avg Quality | Avg Latency | Phase 5 Pass? |
|-------|-------------|-------------|---------------|
| kimi-k2.6:cloud | **4.6/5** | **6.8s** | **✅ PASS** |
| glm-5.1:cloud | N/A (killed) | 221s+ | **❌ FAIL** |
| qwen3.5:cloud (/no_think) | 4.6/5 | 42.3s | **❌ FAIL (latency)** |

**Phase 6 gate:** At least 1 model with avg Q≥3.5 AND avg L≤20s → **TRIGGERED** ✅

---

## 10. Phase 6 — Implementation

**Status: ✅ IMPLEMENTED**  
**Passing model:** kimi-k2.6:cloud (Q=4.6/5, L=6.8s avg)

### Actions taken:
1. **model-policy.json updated** — kimi-k2.6:cloud added to `tier2_subtasks.ollamaCloudModels` and `globalAllowedModels`. Tier 2 assignment. Constraints: non-sensitive tasks only (low data_sensitivity). Approved date: 2026-05-02.
2. **CHG entry logged** — CHG-0120 (Ollama Cloud PoC Phase 5/6 implementation)
3. **MEMORY.md updated** — Ollama Cloud PoC marked COMPLETE

### Cost Impact (updated estimate):

| Scenario | Monthly saving | Plan cost | Net saving |
|----------|---------------|-----------|------------|
| Conservative (20% Tier 2 shifted to kimi-cloud) | ~$710/mo | $20/mo | **~$690/mo** |
| Optimistic (40% Tier 2 shifted to kimi-cloud) | ~$1,420/mo | $20/mo | **~$1,400/mo** |

**Basis:** Current Claude spend ~$3,550/mo. kimi-k2.6:cloud is ~99% cheaper per token for Tier 2 tasks (Ollama Pro $20/mo flat vs $1–15/MTok Claude). Routing 20–40% of non-sensitive Tier 2 tasks yields $690–1,400/mo net saving.

### Constraints and caveats:
- kimi-k2.6:cloud is restricted to **non-sensitive tasks only** (no PII, no medical, no legal data)
- Routing rule: `if data_sensitivity == "low"` → eligible for kimi-cloud; `if data_sensitivity == "high"` → must stay on local or Anthropic
- Warden must enforce this. Policy now reflected in model-policy.json.
- glm-5.1:cloud: ❌ NOT added — catastrophic latency (400s+), not viable for any real-time tier
- qwen3.5:cloud: ❌ NOT added — latency fix partial only; may revisit for async batch jobs in OC2

---

## 11. CHG Log (Phase 5/6)

| CHG | Phase | Description |
|-----|-------|-------------|
| CHG-0120 | Phase 5+6 | Full frontier benchmark + kimi-k2.6:cloud Tier 2 implementation |

---

*Report updated by Yoda (subagent) — 2026-05-02. Phase 6 IMPLEMENTED. Ollama Cloud PoC COMPLETE.*

---

## Phase 5C — gemma4 community cloud

**Date:** 2026-05-02  
**Model:** `blissful_ishizaka_626/gemma4-cloud` (community/unofficial)  
**Executed by:** Yoda (subagent)  
**Authorised by:** Ken directive 2026-05-02  
**CHG ref:** CHG-0120 (same 5-task spec)  
**Note:** Community model — results are indicative only, not production-grade evaluation.

### Benchmark Results

| Task | Description | Latency (s) | Quality (1–5) | Notes |
|------|-------------|-------------|---------------|-------|
| B1 | Top 3 LLM cloud risks | 11.0 | 4/5 | Clear, accurate, concise — 3 well-structured risks |
| B2 | Python routing function (~20 lines) | 47.3 | 4/5 | Correct logic, input validation, test cases included; long latency |
| B3 | LinkedIn post (3 sentences, 60% cost cut) | 14.6 | 4/5 | Exactly 3 sentences, AU context ("optimise"), all elements present |
| B4 | JSON tool call for get_calendar_events | 12.7 | 5/5 | Perfect JSON, correct format, exact date string |
| B5 | Medical records data sovereignty response | 38.6 | 4/5 | Concise, correct GDPR/HIPAA mention, jurisdiction-specific |

### Aggregate Scores

| Metric | Result | Threshold | Status |
|--------|--------|-----------|--------|
| Avg Quality | **4.2 / 5** | ≥ 3.5 | ✅ PASS |
| Avg Latency | **24.8s** | ≤ 20s | ❌ FAIL |

### Verdict: **FAIL**

Quality is strong (4.2/5), but average latency of 24.8s exceeds the 20s threshold. B2 (47.3s) and B5 (38.6s) are significant outliers — likely due to extended thinking/reasoning traces visible in the model output. Tasks B1, B3, B4 were within acceptable range (11–14.6s).

### Comparison vs Prior Runs

| Model | Avg Quality | Avg Latency | Verdict |
|-------|-------------|-------------|---------|
| kimi-k2.6:cloud | 4.6/5 | 6.8s | ✅ PASS |
| blissful_ishizaka_626/gemma4-cloud | 4.2/5 | 24.8s | ❌ FAIL |

### Notes & Recommendations

- **DO NOT add to model-policy.json** — community model requires Ken's explicit approval after security review.
- Quality is production-viable (4.2/5 is solid), but latency makes it unsuitable for time-sensitive workflows without optimization.
- The model appears to use an extended thinking/scratchpad pattern before responding, inflating latency on complex tasks (B2, B5). If thinking can be disabled or streamed in parallel, latency may improve.
- **Security review warranted** if Ken wishes to pursue this model: being a community/unofficial model, provenance, training data, and safety alignment are unverified.
- Suggested next step: Ken to decide whether to initiate a security review. If latency can be reduced (e.g., via streaming, no-think mode, or prompt tuning), a re-run may be justified.


---

## Phase 5D — deepseek-v4-flash:cloud + deepseek-v4-pro:cloud Benchmark

**Date:** 2026-05-02  
**Executed by:** Yoda (subagent)  
**Authorised by:** Ken directive 2026-05-02  
**CHG ref:** CHG-0121  
**Account:** accounts@ainchors.com (Ollama Pro — both models pre-pulled)

---

### deepseek-v4-flash:cloud — Results

| Task | Description | Latency (s) | Quality (1–5) | Pass? | Notes |
|------|-------------|-------------|---------------|-------|-------|
| B1 | Top 3 LLM cloud risks | 5 | 4/5 | ✅ | Concise, 3 clear risks (data leakage, cost spikes, perf variability) |
| B2 | Python routing function (~20 lines) | 34 | 4/5 | ⚠️ PARTIAL | Correct logic, 20 lines, input validation. Latency exceeds 20s threshold on this task alone. |
| B3 | LinkedIn post (3 sentences, 60% cost cut) | 3 | 4/5 | ✅ | 3 sentences, AU context (🇦🇺), hybrid routing framing |
| B4 | JSON tool call for get_calendar_events | 19 | 5/5 | ✅ | Perfect JSON: `{"name":"get_calendar_events","arguments":{"date":"2026-05-02"}}` |
| B5 | Medical records data sovereignty | 2 | 4/5 | ✅ | Concise, HIPAA/GDPR cited, data residency addressed |

**Aggregate (deepseek-v4-flash:cloud):**

| Metric | Result | Threshold | Status |
|--------|--------|-----------|--------|
| Avg Quality | **4.2 / 5** | ≥ 3.5 | ✅ PASS |
| Avg Latency | **12.6s** | ≤ 20s | ✅ PASS |

**Verdict: ✅ PASS**

---

### deepseek-v4-pro:cloud — Results

| Task | Description | Latency (s) | Quality (1–5) | Pass? | Notes |
|------|-------------|-------------|---------------|-------|-------|
| B1 | Top 3 LLM cloud risks | 14 | 4/5 | ✅ | Deep reasoning visible; 3 risks well-structured (data breach, compliance, cost/perf) |
| B2 | Python routing function (~20 lines) | 59 | 5/5 | ⚠️ PARTIAL | Excellent code quality, full docstring, exactly 20 lines. Extended CoT thinking inflates latency. |
| B3 | LinkedIn post (3 sentences, 60% cost cut) | 4 | 5/5 | ✅ | Excellent — data sovereignty angle, AU context, professional tone |
| B4 | JSON tool call for get_calendar_events | 6 | 5/5 | ✅ | Perfect JSON: `{"tool":"get_calendar_events","arguments":{"date":"2026-05-02"}}` |
| B5 | Medical records data sovereignty | 9 | 4/5 | ✅ | Thorough: HIPAA/GDPR, patient consent, DPA — slightly verbose but high quality |

**Aggregate (deepseek-v4-pro:cloud):**

| Metric | Result | Threshold | Status |
|--------|--------|-----------|--------|
| Avg Quality | **4.6 / 5** | ≥ 3.5 | ✅ PASS |
| Avg Latency | **18.4s** | ≤ 20s | ✅ PASS (marginal — 1.6s headroom) |

**Verdict: ✅ PASS** *(avg latency 18.4s — suitable for async/non-realtime tasks; avoid for strict sub-10s SLA)*

---

### Comparison Table — All Models

| Model | Avg Quality | Avg Latency | Verdict |
|-------|-------------|-------------|---------|
| kimi-k2.6:cloud | 4.6/5 | 6.8s | ✅ PASS |
| deepseek-v4-flash:cloud | 4.2/5 | 12.6s | ✅ PASS |
| deepseek-v4-pro:cloud | 4.6/5 | 18.4s | ✅ PASS (marginal) |
| blissful_ishizaka_626/gemma4-cloud | 4.2/5 | 24.8s | ❌ FAIL |
| qwen3.5:cloud | 4.6/5 | 42.3s | ❌ FAIL |
| glm-5.1:cloud | N/A | 221s+ | ❌ FAIL |

---

### Implementation Actions

1. **model-policy.json updated** — both models added to `globalAllowedModels` and `tier2_subtasks.ollamaCloudModels` with data_sensitivity constraints (non-sensitive only).
2. **CHG-0121 logged** — deepseek benchmark results + policy update.
3. **MEMORY.md updated** — Tier 2 now has 3 Ollama Cloud models.

### Updated Cost Saving Estimate

| Scenario | Models available | Monthly saving | Ollama Pro cost | Net saving |
|----------|-----------------|----------------|-----------------|------------|
| Conservative (20% Tier 2 → Ollama Cloud) | kimi + deepseek-flash + deepseek-pro | ~$710/mo | $20/mo | **~$690/mo** |
| Moderate (35% Tier 2 → Ollama Cloud) | kimi + deepseek-flash + deepseek-pro | ~$1,243/mo | $20/mo | **~$1,223/mo** |
| Optimistic (50% Tier 2 → Ollama Cloud) | kimi + deepseek-flash + deepseek-pro | ~$1,775/mo | $20/mo | **~$1,755/mo** |

**Basis:** Baseline Claude spend ~$3,550/mo. Having 3 viable Ollama Cloud models increases routing surface area — more tasks can be safely offloaded to non-sensitive Tier 2. deepseek-v4-flash is the best latency/quality tradeoff for time-sensitive subtasks; deepseek-v4-pro matches kimi quality (4.6/5) for complex reasoning tasks.

### Routing Guidance

| Task type | Recommended Ollama Cloud model |
|-----------|-------------------------------|
| Fast concurrent subtasks | deepseek-v4-flash:cloud (12.6s avg) |
| Complex reasoning / code (non-sensitive) | deepseek-v4-pro:cloud or kimi-k2.6:cloud |
| Creative/content tasks | kimi-k2.6:cloud (fastest: 6.8s) |
| All high-sensitivity data | ❌ Must stay on Anthropic/local |

---

*Appended by Yoda (subagent) — 2026-05-02. Phase 5D: deepseek benchmark COMPLETE. Both models PASSED and added to Tier 2.*
