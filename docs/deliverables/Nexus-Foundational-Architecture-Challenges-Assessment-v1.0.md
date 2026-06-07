# Nexus Platform — Foundational Architecture Challenges Assessment

**Document ID:** NFA-v1.0
**Status:** DRAFT FOR REVIEW
**Date:** 2026-06-07
**Prepared for:** Ken Mun (CTO) — Claude research context handover
**Source data:** Atlas TKT-0317 Context Optimization Assessment, Thrawn TKT-0309 TQP Design, TKT-0321 2-Pass Contract, TKT-0322 Routing Matrix, Phase 4 Data & Memory Architecture, Platform Constraints Audit, OWL Drift Detection System (TKT-0228), Platform Rule Engine (TKT-0237)

---

## Executive Summary

This assessment documents the three foundational challenge areas currently limiting the Nexus agentic platform's execution quality, cost economics, and operational durability. Each area is presented with actual platform data, the current-state mitigations already in place, the gaps that remain, and the observations Ken has raised for deeper research — specifically around multi-step progression execution models like VMAO and POLARIS that achieve better quality assurance and cost economy.

---

## 1. Agentic Workflow Execution — Decay, OWL, RVEV, 2-Pass, Skills.md

### 1.1 Current State Architecture

The Nexus platform has evolved a multi-layered execution discipline stack over 40+ days of production operation:

```
┌─────────────────────────────────────────────────────────────────┐
│                  EXECUTION DISCIPLINE STACK                       │
│                                                                  │
│  LAYER 5: DoD Gate (TKT-0237 A1)                                │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Pre-close validation: deliverable exists? git committed?  │   │
│  │ Post-close: dod-validator.sh re-checks within 2h         │   │
│  └──────────────────────────────────────────────────────────┘   │
│                          ▲                                       │
│  LAYER 4: TQP Execution Gate (TKT-0309)                         │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ No atom = "complete" until PG commit returns success      │   │
│  │ Auto-resume from last persisted atom on restart           │   │
│  └──────────────────────────────────────────────────────────┘   │
│                          ▲                                       │
│  LAYER 3: 2-Pass Dispatch (TKT-0321)                            │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Pass 1: Discovery (orchestrator) → atom breakdown          │   │
│  │ Pass 2: Execution (specialist) → RVEV cycle only           │   │
│  │ Rule: "No executor receives undiscovered work."            │   │
│  └──────────────────────────────────────────────────────────┘   │
│                          ▲                                       │
│  LAYER 2: RVEV Cycle (TKT-0321)                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ READ → VALIDATE → EXECUTE → VERIFY per atom               │   │
│  │ Traces logged. Partial execution not permitted.            │   │
│  └──────────────────────────────────────────────────────────┘   │
│                          ▲                                       │
│  LAYER 1: OWL Guard (TKT-0228)                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Pre-session contract injection for MEDIUM+ currency        │   │
│  │ Plan→Breakdown→Sequence→Execute→Verify enforced            │   │
│  │ Compliance tracked: chain-reaction detection, daily score  │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 What We've Built (Mitigations in Place)

| Layer | When Built | Ticket | Status | What It Does |
|-------|-----------|--------|--------|--------------|
| OWL Guard | Day 20+ | TKT-0228 | 🟡 Partially deployed | Injects execution contract at session start; currency detection; chain-reaction monitoring |
| RVEV Cycle | Day 33 | TKT-0321 | 📋 Contract designed | Read→Validate→Execute→Verify per atom; trace format defined; no discovery in execution |
| 2-Pass Dispatch | Day 33 | TKT-0321 | 📋 Contract designed | Discovery/execution separation; dispatch-validate.sh gate (TKT-0323 not yet built) |
| TQP Gate | Day 30 | TKT-0309 | 🟢 Phase 1 live (Yoda) | Atom persistence to PG; auto-resume from last atom; sc_persist_atom() wrapper |
| DoD Gate | Day 22 | TKT-0237 A1 | 🟢 Live | Pre-close validation in ticket.sh; dod-validator.sh every 2h; 10-rule audit engine |

### 1.3 The Decay Problem — Observable Data

Despite five layers of discipline, execution quality decays across multiple dimensions:

**A. OWL Compliance Drift (L-039)**

On Day 23 (2026-05-17), during the v2026.5.12 OpenClaw upgrade:
- Yoda exhibited chain-reaction execution: install failed → immediately attempted force reinstall without assessment
- Ken flagged the drift explicitly: *"you're rushing"*
- The OWL compliance score dropped; credibility damaged
- Root cause: OWL is a **pre-session contract** — it activates at session start but has no real-time enforcement during execution. The agent can drift mid-session and the guard only catches it post-hoc.

**B. CHG-0401: The "Done But Not Done" Pattern**

The most visible decay incident — CHG-0401 was marked "done" with 607 items migrated, 3 databases created. Reality 4 days later: 15 Done + 5 Auto-Heal items still in DB A. DB C had no schema. The archive code never shipped. The agent executed → reported done → no one checked.

This pattern triggered TKT-0237 (Platform Rule Engine) — but the fundamental issue remains: **agents self-report completion without external verification**. The DoD gate catches it post-close, but doesn't prevent the false completion from happening.

**C. Gemma4 Unreliability (Current, Pre-OC2)**

All models below deepseek-v4-pro (gemma4:31b-cloud, kimi) exhibit:
- Instruction decay over long sessions: early atoms are disciplined, later atoms skip verification
- RVEV skipping: model moves directly from READ to EXECUTE, bypassing VALIDATE and VERIFY
- "Figure it out" drift: executor performs discovery despite receiving pre-discovered atoms (TKT-0321 violation)

**D. Skills.md — The Missing Component**

Currently, Skills.md files exist for tools (browser-automation, office-docs, notion, etc.) but there is **no per-agent execution skill** that encodes the execution discipline as a reusable, loadable skill. Every agent's RULES.md contains the same 2-pass, RVEV, and OWL instructions — but these are injected as static context, not as an active execution framework. The 92% rule duplication (Atlas TKT-0317 finding) means every specialist burns tokens re-reading execution discipline rules they should inherit from a shared execution skill.

### 1.4 Remaining Gaps

| Gap | Severity | Current Mitigation | Why It's Not Enough |
|-----|----------|-------------------|---------------------|
| No real-time execution guard | High | OWL guard at session start | Agent can drift mid-session; no inter-atom enforcement |
| Self-reported completion | Critical | DoD gate post-close | Catches lies but doesn't prevent them |
| No atom-level quality scoring | Medium | RVEV traces logged | Traces are binary (OK/FAIL) — no quality dimension |
| Model-specific execution decay | High | 2-pass contract | Contract is textual — weaker models ignore it when context grows |
| Skills.md not used for execution | Medium | Rules in RULES.md | Static injection vs active skill loading |
| No continuous execution loop | High | Sequential atoms | No plan → verify → replan loop; plans go stale mid-execution |

### 1.5 The Multi-Step Progression Opportunity

The current Nexus execution model is fundamentally **linear**: Plan → Breakdown → Sequence → Execute → Verify. Each atom is verified individually, but there is no **closed-loop progression** where execution quality informs plan revision.

External models Ken has identified for research:
- **VMAO** (Validate → Measure → Act → Observe) — a continuous quality loop, not a linear pipe
- **POLARIS** — multi-step progression with plan/design/verify/execute/validate phases

These models introduce a dimension Nexus currently lacks: **iterative replanning based on execution quality feedback**. In Nexus today, if Atom 3 fails verification, the agent retries Atom 3 — it doesn't reconsider whether Atoms 4-7 are still the right plan given what was learned from Atom 3's failure.

---

## 2. Model & Token Economics — Hydration, Context Compression, Drift, Unnecessary Tokens

### 2.1 Current State — Quantitative Baseline

**Source:** Atlas TKT-0317 Context Optimization Assessment (2026-05-27)

| Metric | Value |
|--------|-------|
| Yoda per-session injected context | **123.8 KB** (~30,943 tokens) |
| Yoda loaded files | AGENTS.md (17.9KB), SOUL.md (4.7KB), MEMORY.md (9.0KB), HEARTBEAT.md (13.6KB), RULES.md (46.5KB), YODA_RULES.md (24.5KB), SHARED_CONTEXT.md (4.7KB) |
| Specialist average injected | **5-27 KB** per agent per session |
| Platform daily injected token burn | **~79,942 tokens/day** (injected context only) |
| Rule duplication ratio | **92%** — 215 of 234 rule instances are duplicates |
| Agents using gemma4:31b as primary | 12 of 14 |
| Agents on deepseek-v4-pro | 2 (Yoda, Aria) |
| Identical fallback chain | 13 of 14 agents share: deepseek → gemma → kimi |

**Actual cost context (from journal data):**
- Day 20 (heavy architecture day): $151.99 USD, 3,493 turns
- Typical active day: $50-150 USD
- Post-Claude budget cap: $150/month (Jun 2026), $100 Ollama Cloud fixed + $50 buffer
- Daily heavy: 120M cache read tokens, 27M cache write tokens (Day 9)

### 2.2 The Hydration Problem

"Hydration" refers to the cost of loading context into a session before any productive work begins. Every session restart, model switch, or agent spawn incurs a hydration tax:

**Yoda Hydration Cost:**
```
Every session start:
  AGENTS.md      → 17.9 KB
  SOUL.md        →  4.7 KB
  MEMORY.md      →  9.0 KB
  HEARTBEAT.md   → 13.6 KB
  RULES.md       → 46.5 KB
  YODA_RULES.md  → 24.5 KB
  SHARED_CONTEXT →  4.7 KB
  ───────────────────────
  Total: 123.8 KB / ~30,943 tokens per session

If Yoda restarts 3× in a day: ~93,000 tokens burned on context alone
At ~$0.50/1M tokens (Ollama Cloud): ~$0.05/session hydration
At Claude rates (~$3/1M input): ~$0.28/session hydration
```

**The real cost is not financial — it's context window pressure.** 123.8KB of injected context leaves less room for conversation history, tool output, and model reasoning. This manifests as:
- Earlier context truncation in long sessions
- Model "forgetting" early instructions as context window fills
- Reduced reasoning quality when tool outputs compete with injected context

### 2.3 Context Compression — What We've Done

| Mitigation | Status | Savings |
|-----------|--------|---------|
| Progressive Disclosure design (TKT-0317) | 📋 Designed, not implemented | Projected 55-64% Yoda reduction |
| SHARED_CONTEXT.md consolidation | 📋 TKT-0321 (in sprint) | 12-18% per specialist |
| Tiered context: Essential/Situational/Never-Needed | 📋 TKT-0275 (folded into TKT-0317) | 30-50% per specialist |
| HEARTBEAT.md → cron migration | 📋 TKT-0326 (in sprint) | 10-15% of Yoda injection |
| MEMORY.md archive overflow pattern | 🟢 Live (TKT-0310) | Prevents silent truncation |
| TQP auto-resume (vs full rehydration) | 🟢 Phase 1 live | Resumes from last atom, not from scratch |

### 2.4 Unnecessary Token Burn — Identified Sources

**A. Duplicate Rule Injection (92% problem)**

Every specialist agent loads its own RULES.md containing 92% rules that are already in SHARED_CONTEXT.md. For Spark (27KB context, worst case): 22.6KB is RULES.md, and ~20.8KB of that is duplicated from other sources. That's ~5,200 tokens burned every Spark session on rules Spark has already read via SHARED_CONTEXT.md.

**B. HEARTBEAT.md in Every Session**

At 13.6KB, HEARTBEAT.md is the 3rd-largest injected file for Yoda. It contains 30+ periodic checks — most of which are not relevant to the current session's task. A session that's closing a single ticket doesn't need the LinkedIn posting rules, the blog verification checklist, or the delegated auth health check.

**C. Full RULES.md vs Task-Relevant Sections**

RULES.md at 46.5KB covers 34 sections spanning tickets, CHG, journal, blog, cost, security, cron, routing, dispatch, skills, and more. In any given session, only 3-6 sections are relevant. The remaining 35-40KB is dead weight.

**D. Model Drift Token Waste**

When a weaker model (gemma4) receives the same 123.8KB context as a stronger model (deepseek-v4-pro), it processes the context less efficiently — resulting in more re-reads, more clarification turns, and ultimately more tokens burned for the same output quality. The TKT-0322 matrix partially addresses this by routing tasks to appropriate models, but doesn't yet trim context per model capability.

### 2.5 The Model Economics Tension

```
HIGH CAPABILITY (deepseek-v4-pro, Claude Sonnet)
  ├─ Pros: Follows execution discipline, produces quality
  ├─ Cons: Expensive per token, limited availability (Claude credits depleted)
  └─ Current use: Yoda + Aria only

MEDIUM CAPABILITY (gemma4:31b-cloud)
  ├─ Pros: Included in $100/mo subscription, always available
  ├─ Cons: Execution decay over long sessions, skips RVEV, instruction drift
  └─ Current use: 12 of 14 agents

LOW CAPABILITY (gemma4:26b local, OC2-gated)
  ├─ Pros: $0 marginal cost, data sovereignty
  ├─ Cons: Not available until OC2 (Jul 2026), lower reasoning quality
  └─ Current use: None (OC2-gated)
```

The core tension: the models that follow execution discipline best are the most expensive and least available. The models that are always available are the ones that exhibit execution decay. This is not a problem that better prompting alone can solve — it's a fundamental architectural constraint.

### 2.6 What's Missing

| Gap | Impact |
|-----|--------|
| No per-task context budget enforcement | Agent loads full injection regardless of task complexity |
| No model-aware context trimming | gemma4 gets same 123.8KB as deepseek-v4-pro |
| No context compression/summarization | Long sessions accumulate context; no compaction step |
| No token cost per atom tracking | We measure session cost, not per-atom cost |
| No hydration cost amortization | Every restart pays full hydration tax |

---

## 3. Agentic Memory Management — 5-Tier Storage (+PG), Stateless Persistence & Resume

### 3.1 Current State Architecture

The Nexus platform's memory architecture is defined by the Phase 4 Data & Memory Architecture (designed by Ken Mun, 2026-05-01):

```
┌─────────────────────────────────────────────────────────────────┐
│                   5-TIER MEMORY ARCHITECTURE                      │
│                                                                  │
│  TIER 1: Working Memory (Context Window)                         │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Active context for current invocation. Managed by LLM.    │   │
│  │ Design focus: token budget, state compression for long    │   │
│  │ workflows. Currently unmanaged — no budget enforcement.    │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  TIER 2: Short-Term / Session Memory                             │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ State persisting within a workflow run. Conversation       │   │
│  │ history, intermediate reasoning, tool call results.        │   │
│  │ Storage: session-scoped, ephemeral.                       │   │
│  │ Current: OpenClaw manages this implicitly.                 │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  TIER 3: Long-Term Episodic Memory                               │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Timestamped immutable record of agent actions, decisions.  │   │
│  │ Storage: PostgreSQL (append-only). Audit/compliance layer. │   │
│  │ Current: PG has agent_events, agent_decisions,             │   │
│  │ decision_lineage, memory_access_log schemas DESIGNED.      │   │
│  │ IMPLEMENTATION: Schemas exist but no live data pipeline.   │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  TIER 4: Long-Term Semantic Memory                               │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Vector store + RAG pipeline. Documents, policies,          │   │
│  │ regulatory rules, reference data.                          │   │
│  │ Storage: pgvector (designed, not deployed).                │   │
│  │ IMPLEMENTATION: Schema designed. Zero data loaded.         │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  TIER 5: Shared Multi-Agent Memory                               │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ State readable/writable across 14-agent hierarchy.         │   │
│  │ Storage: PostgreSQL (agent_shared_state table +            │   │
│  │ agent_state_history for audit). Optimistic locking.        │   │
│  │ Current: PG table exists, used for TQP + tickets + cost.   │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 What's Live vs What's Designed

| Tier | Design Status | Implementation Status | Data Flowing? |
|------|--------------|----------------------|---------------|
| T1 (Working) | Conceptual only | No budget enforcement | N/A |
| T2 (Session) | Implicit via OpenClaw | Auto-managed | Yes (transient) |
| T3 (Episodic) | Full schema designed | Schema deployed, no pipeline | No — schemas are empty |
| T4 (Semantic) | Full schema + strategy | pgvector not deployed | No |
| T5 (Shared) | Optimistic locking designed | agent_shared_state live for TQP/tickets/cost/sprints | Yes (partial) |

**The reality:** 2 of 5 tiers are operational. Tiers 3 and 4 — the compliance and knowledge layers — are designed but not built. This means the platform has no immutable audit trail, no semantic search, and no RAG pipeline.

### 3.3 Stateless Persistence & Resume — What We Have

**TQP (Task Queue Processor) — TKT-0309:**

The most significant memory innovation on the platform. TQP transforms volatile session context into durable PG state:

```
Execution Flow:
  1. Plan atoms → announce
  2. Execute Atom[N]
  3. Call sc_persist_atom(task_id, N, state_payload, execution_context)
  4. PG write MUST succeed before advancing
  5. Announce "Atom N complete ✅"
  6. Proceed to Atom[N+1]

Resume Flow (after crash/restart/model-switch):
  1. Identify current TKT
  2. Call sc_resume_context(task_id)
  3. Load last state_payload as "Last Known State"
  4. Start at atom_index + 1
  5. Announce: "Resuming TKT-XXXX from Atom N. Last: [summary]."
```

**Current TQP state:**
- Phase 1 (Yoda inline): 🟢 Live (2026-05-27)
- Phase 2 (Aria business tasks): 📋 TKT-0318, not started
- Phase 3 (All 14 agents): 📋 TKT-0319, not started
- Schema: 5 new columns (parent_task_id, execution_context, atom_index, state_payload, persistence_type)
- Integration: sc_persist_atom() + sc_resume_context() + tqp-yoda.sh wrapper

### 3.4 The Persistence Gap

| Scenario | Current Behavior | Ideal Behavior |
|----------|-----------------|----------------|
| Yoda session crashes mid-atom | TQP auto-resumes from last persisted atom | ✅ Works (Phase 1) |
| Aria session crashes mid-task | Context lost. Restart = fresh. | ❌ No TQP Phase 2 yet |
| Forge subagent times out after 10 min | Work lost. Must re-dispatch. | ❌ No TQP Phase 3 yet |
| Model switch mid-session (deepseek→gemma) | gemma4 gets full rehydration, loses previous atom context | ⚠️ Partial (TQP resume loads state_payload but not full reasoning context) |
| Ken asks "where are we on TKT-XXXX?" | Yoda reads TQP to answer | ✅ Works for Yoda-tracked atoms only |
| Cross-agent work handoff | Manual. Yoda bridges workspaces. | ❌ No cross-agent TQP linking |

### 3.5 The 5-Tier Gap Map

| Gap | Current State | Impact |
|-----|--------------|--------|
| No semantic memory (Tier 4) | pgvector schema exists, no deployment | Agents can't retrieve past decisions, policies, or reference data on demand — everything must be in injected context |
| No immutable audit trail (Tier 3) | Schema designed, no data pipeline | No tamper-proof record of agent actions for compliance or debugging |
| No PII detection pipeline | Designed (spaCy/Presidio), not built | Platform processes data without classification |
| No data lineage tracking | decision_lineage table empty | Cannot trace agent decisions to source data |
| No working memory budget (Tier 1) | Unmanaged | Context window pressure causes truncation and quality decay in long sessions |
| No memory compaction | Not designed | Long sessions accumulate context; no summarization step |
| No cross-agent shared memory beyond TQP | Partial (agent_shared_state exists) | Agents operate in silos; cross-workspace delivery is manual (TKT-0329) |

### 3.6 The "Stateless Ideal" vs Reality

The async stateless design (CHG-0389, 2026-05-17) defined a 3-layer architecture:
1. **Task Queue** — pending work
2. **Checkpoints** — per-atom status
3. **Artifacts** — output

In practice, only Layer 2 (checkpoints via TQP) and Layer 3 (artifacts via filesystem) are partially implemented. Layer 1 (task queue) exists in PG but is not the universal dispatch mechanism — most work still arrives via session context, not via queue claim.

---

## 4. Synthesis — How These Three Areas Interlock

```
┌─────────────────────────────────────────────────────────────────┐
│              THE THREE PILLARS — INTERDEPENDENCIES               │
│                                                                  │
│  EXECUTION QUALITY         TOKEN ECONOMICS        MEMORY         │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐  │
│  │ • OWL decay      │    │ • 123.8KB Yoda   │    │ • T3+T4 not  │  │
│  │ • Self-reported   │◄──►│   hydration      │◄──►│   built      │  │
│  │   completion      │    │ • 92% duplication│    │ • No semantic │  │
│  │ • RVEV skipping   │    │ • 79K tokens/day │    │   retrieval   │  │
│  │ • No closed loop  │    │ • No per-atom $  │    │ • Cross-agent │  │
│  └─────────────────┘    └─────────────────┘    │   gap         │  │
│          │                      │              └─────────────┘  │
│          └──────────────────────┘                      │         │
│                    │                                   │         │
│                    ▼                                   ▼         │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │               ROOT CAUSE: CONTEXT AS STATE                 │   │
│  │                                                           │   │
│  │  The platform treats the LLM context window as the         │   │
│  │  primary state holder. Every session loads 123.8KB of      │   │
│  │  "memory" as context injection. Every agent carries 92%     │   │
│  │  duplicated rules. Every restart pays full hydration tax.   │   │
│  │                                                           │   │
│  │  Execution discipline (OWL, RVEV, 2-pass) is enforced       │   │
│  │  through context injection — meaning the enforcement        │   │
│  │  mechanism IS the thing burning tokens.                     │   │
│  │                                                           │   │
│  │  Memory (T3-T5) is designed but not built — so agents       │   │
│  │  can't retrieve knowledge on demand. Everything must be     │   │
│  │  pre-loaded as context.                                     │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

**The fundamental insight:** The three problem areas are not separate — they're symptoms of one architectural choice: **using the LLM context window as the primary state and knowledge mechanism**. Every fix in one area (better execution discipline) increases the problem in another (more context = more tokens). Breaking this cycle requires moving state and knowledge OUT of the context window and into Tier 3-5 storage that agents can query on demand.

---

## 5. Research Directions — Multi-Step Progression Execution Models

### 5.1 What Nexus Currently Does

```
Plan → Breakdown → Sequence → Execute → Verify
  │                                           │
  └───────────────────────────────────────────┘
              (linear, no feedback loop)
```

Atoms execute in sequence. Verification is per-atom. If Atom 3 fails, retry Atom 3. The plan (Atoms 4-7) doesn't change based on what was learned during Atoms 1-3.

### 5.2 What VMAO/POLARIS-Class Models Add

**Continuous Loop:**
```
Plan → Execute → Validate → Observe → (replan) → Execute → ...
  │                                            │
  └────────────────────────────────────────────┘
              (closed feedback loop)
```

The key difference: **execution quality feedback modifies the plan**. If Atom 3's output reveals a dependency not anticipated in the original plan, the plan adapts — adding, removing, or reordering atoms before proceeding.

### 5.3 Specific Questions for Claude Research

These are the questions Ken has flagged for deeper research with Claude:

**A. Execution Architecture:**
1. How do VMAO and POLARIS handle the plan↔execution feedback loop in practice? What is the specific mechanism for "observe triggers replan"?
2. Is there a formal state machine or is it LLM-prompt-driven? (Nexus's current approach is entirely prompt-driven — no formal state machine for execution state.)
3. How do these models prevent infinite replanning loops? What is the termination condition?
4. How do they handle partial execution — if Atom 3 of 7 fails, is the retry scoped to Atom 3 or does the whole plan re-evaluate?

**B. Quality Assurance Integration:**
5. Do VMAO/POLARIS incorporate quality scoring per step? If so, how is quality measured — binary (pass/fail) or gradient (0-100)?
6. How do they handle the "self-reported completion" problem — does an external verifier validate each step, or does the model self-validate?
7. Can the verification layer be model-agnostic? (Critical for Nexus — enforcement must work regardless of which model executes.)

**C. Cost Economics:**
8. What is the token cost profile of multi-step progression vs linear execution? Does the replanning loop cost more or less than executing a stale plan to completion?
9. Do these models support model-tiered execution — where planning uses a strong model and execution uses a cheaper model? (Aligns with TKT-0322 routing matrix.)
10. How do they handle context compression between cycles? Does each cycle get a fresh, compressed context or does context accumulate?

**D. Memory Integration:**
11. How do VMAO/POLARIS integrate with persistent memory? Does each cycle checkpoint to durable storage?
12. Can the execution state survive a model switch mid-plan? (Critical for Nexus where deepseek→gemma4 switches happen.)
13. Is there a concept of "execution memory" separate from "knowledge memory" — i.e., the plan state is stored differently from reference knowledge?

**E. Practical Implementation:**
14. Are there open-source implementations or reference architectures for VMAO/POLARIS that could be adapted to OpenClaw's agent framework?
15. What is the minimum viable implementation — could a VMAO-style loop be implemented as a Skills.md file that agents load, or does it require deeper platform integration?
16. How do these models compose with existing execution disciplines like RVEV and 2-pass dispatch — complementary or conflicting?

---

## 6. Current Sprint Status (For Context)

**Sprint 7 (2026-06-08 to 2026-06-14) — Committed, 7 items:**

| Seq | Ticket | Title | Agent | Effort | Status |
|-----|--------|-------|-------|--------|--------|
| 1 | TKT-0327 | Tilde-Path Normalization | Forge | S | Pending |
| 2 | TKT-0317 | Context Optimization Epic (4 child tickets) | Atlas+Forge | XL | Pending |
| 3 | TKT-0293 | Regression Testing Framework | Forge | L | Pending |
| 4 | TKT-0319 | Global TQP Phase 3 | Atlas+Forge | L | Pending |
| 5 | TKT-0318 | Aria TQP Phase 2 | Yoda+Aria | M | Pending |
| 6 | TKT-0326 | NAS Writable Backup Target | Forge | M | Pending |
| 7 | TKT-0137 | Policy Register | Thrawn | M | Pending |

**Key constraint:** TKT-0317 is an XL epic with remaining implementation atoms for dispatch-validate.sh + agent config migration. TKT-0319 is gated on TKT-0318. OC2 arrives ~Jul 6-13 — unlocks gemma4:26b local (Tier 1, $0 marginal cost).

---

## 7. Recommendations for Claude Research Session

### 7.1 Priority Research Areas (Ken's Focus)

1. **Multi-step progression execution models** (VMAO, POLARIS, or equivalents) — understand the closed-loop plan→execute→validate→replan architecture
2. **How to decouple execution discipline from context injection** — move enforcement from prompt text to platform mechanism
3. **Memory architecture that minimizes hydration** — how to make agents "remember" without reloading everything into context

### 7.2 Design Principles to Evaluate

| Principle | Current Nexus State | Desired State |
|-----------|-------------------|---------------|
| Execution = State Machine, not Prompt | Prompt-driven OWL contract | Platform-enforced state machine |
| Verify = External, not Self-Reported | Agent self-reports completion | Platform verifies independently |
| Context = Query, not Preload | Everything injected at start | Agents query knowledge on demand |
| Memory = Durable, not Ephemeral | Session context is primary state | PG is primary state; context = working set only |
| Plan = Living, not Static | Plan locked at start | Plan adapts based on execution feedback |

### 7.3 Key Documents to Share with Claude

For the research session, the following documents provide the full current-state picture:

1. **This document** — foundational challenges assessment
2. **TKT-0317 Context Optimization Assessment** — `docs/deliverables/TKT-0317-Context-Optimization-Assessment-v1.0.md`
3. **TKT-0321 2-Pass Dispatch Contract** — `docs/deliverables/TKT-0321-2-Pass-Dispatch-Contract-v1.0.md`
4. **TKT-0309 TQP Execution Gate Design** — `docs/deliverables/TKT-0309-TQP-Execution-Gate-Design-v1.0-APPROVED.md`
5. **TKT-0322 Model-Task Routing Matrix** — `docs/deliverables/TKT-0322-Model-Task-Routing-Matrix-v1.0.md`
6. **Phase 4 Data & Memory Architecture** — `docs/Phase4_DataMemory_Architecture.md`
7. **Platform Constraints Audit** — `docs/platform-constraints-audit-v1.0.md`
8. **Nexus System Architecture v1.0** — `docs/Nexus-System-Architecture-v1.0.md`
9. **Technology Strategy & Roadmap** — `docs/Aevlith-Technology-Strategy-Roadmap-v1.0-Internal.md`

---

## Appendix A: Execution Decay Incident Log (Selected)

| Date | Incident | Model | Root Cause | Lesson |
|------|----------|-------|------------|--------|
| 2026-05-17 | OWL drift during v2026.5.12 upgrade | deepseek-v4-pro | Chain-reaction on error; no pause before retry | L-039: Ken feedback "you're rushing" → immediate OWL recommitment |
| 2026-05-22 | CHG-0401: 607 items "migrated" — not actually done | deepseek-v4-pro | Self-reported completion; no external verification | Triggered TKT-0237 Platform Rule Engine |
| 2026-05-25 | gemma4 skips RVEV verification phase | gemma4:31b-cloud | Model capability decay in long sessions | Triggered Conservative Mode + gemma4 policy: background/crons only |
| 2026-05-30 | Forge sub-agent deliverable stuck in workspace-infra | gemma4:31b-cloud | Cross-workspace delivery gap (TKT-0328 first victim) | Raised TKT-0329 for Thrawn assessment |
| 2026-06-02 | Blog cron silent failure for 12 days | gemma4:31b-cloud | Cron reported OK but no output file produced | PIA raised; blog verification added to heartbeat |

---

## Appendix B: Token Burn Calculation Methodology

**Per-session injected token estimate:**
- Text bytes ÷ 4 = approximate tokens (rough heuristic; actual varies by tokenizer)
- Example: 123,800 bytes ÷ 4 ≈ 30,950 tokens

**Platform daily estimate:**
- Yoda: 1 session × 30,943 tokens = 30,943
- 13 specialists: 1 session each × average 3,769 tokens = 48,999
- Total injected: ~79,942 tokens/day

**Note:** These are injected context only. Actual token consumption including conversation, tool output, and model thinking is typically 4-8× higher.

---

*End of Assessment — DRAFT FOR REVIEW*
*Prepared for Ken Mun (CTO) as context handover for Claude architecture research session*
*Next step: Ken to review, then use as input to Claude research on VMAO/POLARIS-class execution models*
