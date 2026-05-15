# Gemma4 Fine-Tuning Research — P3
## TKT-0181 | Status: COMMITTED | Priority: P3-research
## Date: 2026-05-15 | Approved by: Ken Mun
## Agent: Thrawn (research) + Forge (infra) | Est: 2-3 sprints at P3 boundary

---

## 1. Objective

Evaluate fine-tuning Gemma4:26b (or successor) on OC2 for agent-specific tasks. Determine if fine-tuning delivers meaningful improvement over base model + RAG for our use cases.

**NOT training from scratch.** Fine-tuning an existing open-weights model on our curated dataset.

---

## 2. Context

### Current Model Stack (locked)
- T0: systemEvent ($0)
- T1: Gemma4:26b local on OC2 ($0) — background/non-interactive only
- T2: Ollama Cloud kimi/deepseek ($100/mo)
- T3: Claude Sonnet (fallback only)

### Why Fine-Tune?
| Potential Benefit | Detail |
|---|---|
| Agent-specific reasoning | Better at routing decisions, pattern recognition, anomaly detection |
| Platform knowledge | Internalized understanding of Nexus architecture, governance rules |
| Reduced RAG dependency | Some knowledge embedded in weights, faster inference |
| Cost reduction | Fewer T3 fallback calls if T1 reasoning improves |
| Local-only operation | Complete independence from external APIs for specific tasks |

### Why NOT Fine-Tune?
| Risk | Detail |
|---|---|
| Overfitting | Small dataset (our platform docs) → model memorizes, doesn't generalize |
| Catastrophic forgetting | Fine-tuning degrades base model's general capabilities |
| Compute cost | OC2 48GB can inference, not efficiently train. Need cloud GPU or prolonged OC2 training. |
| Data prep effort | Curating high-quality training dataset = significant work |
| Uncertain ROI | May not beat "base model + RAG + good prompts" |

---

## 3. Research Questions (P3)

| # | Question | How to Answer | Owner |
|---|---|---|---|
| 1 | What tasks would benefit most from fine-tuning? | Benchmark: base Gemma4 vs fine-tuned on routing decisions, Warden pattern detection, governance rule application | Thrawn |
| 2 | How much training data do we need? | Estimate: platform docs, decision logs, agent transcripts. Target: 10K–100K examples. | Atlas |
| 3 | Can OC2 handle fine-tuning efficiently? | Test: LoRA/QLoRA fine-tuning on OC2 Mac Mini M4 Pro 48GB. Measure time, memory, output quality. | Forge |
| 4 | What's the cost of cloud GPU training vs OC2? | Quote: RunPod, Lambda Labs, Google TPU for 7B model fine-tuning. Compare to OC2 prolonged use. | Forge |
| 5 | Does fine-tuned model beat "base + RAG"? | A/B test: same prompts, base model + RAG vs fine-tuned model. Human evaluation by Ken. | Sage |
| 6 | What's the maintenance burden? | Model versioning, retraining cadence, drift detection. | Thrawn |

---

## 4. Candidate Tasks for Fine-Tuning

| Task | Why Fine-Tune? | Priority |
|---|---|---|
| **Warden pattern detection** | Recognize model drift, config violations, anomalous agent behavior | High |
| **Routing decisions** | Classify task type → correct agent. Reduce Yoda's routing errors | High |
| **Governance rule application** | Apply S1-S7 controls consistently. Reduce false positives | Medium |
| **Cost classification** | Classify work currency (High/Medium/Low/None) automatically | Medium |
| **Ticket triage** | Classify incoming tickets by type, priority, agent | Low (TKT-0174 already planned) |

---

## 5. Technical Approach

### Method: LoRA / QLoRA
- **Base model:** Gemma4:26b (or latest open-weights successor at P3)
- **Method:** LoRA (Low-Rank Adaptation) or QLoRA (quantized LoRA)
- **Why:** Efficient fine-tuning. Only trains small adapter layers, not full model. 48GB can handle 7B QLoRA.
- **Output:** Adapter weights (~100MB) applied to base model at load time.

### Training Data Sources
| Source | Volume | Quality |
|---|---|---|
| Platform docs (golden blueprints) | ~200 pages | High — authoritative |
| Decision logs (MEMORY_DECISIONS.md) | ~100 entries | High — curated |
| Agent transcripts (correct routing examples) | ~10K turns | Medium — needs filtering |
| Warden violation logs | ~200 entries | High — labeled |
| Ticket resolution logs | ~150 entries | Medium — mixed quality |

### Infrastructure
| Option | Pros | Cons |
|---|---|---|
| **OC2 (local)** | Data never leaves, zero external cost | Slow (days/weeks for 7B), OC2 unavailable during training |
| **Cloud GPU (RunPod/Lambda)** | Fast (hours), no local resource contention | Data leaves environment, hourly cost $2-5 |
| **Hybrid** | Prep data locally, train in cloud, download adapter | Balanced — data prep local, training fast |

---

## 6. Success Criteria

| # | Criterion | Threshold |
|---|---|---|
| 1 | Fine-tuned model beats base + RAG on routing accuracy | ≥ 85% vs ≥ 75% baseline |
| 2 | Training cost < $500 (cloud GPU) or < 1 week (OC2) | Budget threshold |
| 3 | Inference latency ≤ 2× base model | User experience acceptable |
| 4 | No catastrophic forgetting on general tasks | Base capabilities preserved |
| 5 | Ken evaluates output quality as "good enough" | Subjective gate |

---

## 7. Dependencies

| Dependency | Status | Blocker? |
|---|---|---|
| OC2 online | ⏳ TRIGGER-01 (July 2026) | Yes — cannot start until OC2 ready |
| RAG pipeline built | ⏳ TKT-0171 (Sprint 7) | Partial — RAG gives baseline to beat |
| Curated training dataset | ⏳ Build during P2 | Yes — need clean, labeled examples |
| GPU training expertise | ⏳ Hire/learn | Partial — Thrawn can research, may need contractor |

---

## 8. Timeline

| Phase | When | What |
|---|---|---|
| **P2** | Aug–Sep 2026 | Curate training dataset from platform docs, decision logs, agent transcripts. RAG pipeline gives search baseline. |
| **P3 start** | Oct 2026 | Evaluate LoRA/QLoRA feasibility on OC2. Run proof-of-concept on Warden pattern detection. |
| **P3 mid** | Nov 2026 | If PoC successful: expand to routing decisions + governance. If not: abandon, document learnings. |
| **P3 end** | Dec 2026 | Decision: adopt fine-tuned model for specific tasks, or stick with base + RAG. |

---

## 9. Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Fine-tuned model doesn't beat base + RAG | Medium | High | Abandon at PoC stage. Document findings. |
| OC2 can't handle training efficiently | Medium | Medium | Use cloud GPU for training, OC2 for inference only. |
| Training data insufficient or poor quality | Medium | High | Start data curation in P2. Quality gates on examples. |
| Catastrophic forgetting | Low | High | Use LoRA (only adapter layers trained), evaluate general capabilities. |
| Expertise gap | Medium | Medium | Thrawn research + potential contractor for ML engineering. |

---

## 10. Approval

**Ken — TKT-0181 committed as P3 research item.**

Reply: **APPROVED** (locked, Thrawn picks up at P3 boundary) | **EDIT** [feedback] | **REJECT** [reason]

---

## 11. Related Decisions

| Decision | Status | Relevance |
|---|---|---|
| TKT-0171 (RAG Pipeline) | Sprint 7 | Baseline to beat. Must complete before fine-tuning evaluation. |
| TKT-0162 (Option B Phased) | APPROVED | Fine-tuning aligns with "build data + integration layers, keep OpenClaw" |
| TRIGGER-03 (Gemma4 validated) | Pending | If Gemma4 doesn't hit ≥75% gate, successor model needed for fine-tuning. |
| 4-Tier Model Strategy | Current | T1 (local) tier is where fine-tuned model would live. |
