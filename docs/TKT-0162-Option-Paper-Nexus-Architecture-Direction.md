# Option Paper: Nexus Platform Architecture Direction
## Data Architecture, Integration Architecture, and Sustainability

**TKT-0162 | Ken Mun (CTO) | 2026-05-14**
**Status: APPROVED ✅**
**Approved by: Ken Mun (CTO) — 2026-05-14 10:28 AEST**
**Decision: Option B — Phased Delivery**
**Author: Atlas 🏛️ — Enterprise Architect, AInchors / Aevlith Technologies**
**Reviewed by: Yoda 🟢 — Lead Orchestrator**

> **Approved decisions:** (1) Option B-phased. (2) Phase 1 JSON→Postgres list confirmed. (3) Typed contracts: Yoda→Forge, Yoda→Sanctum, Atlas→Ken, Spark→Yoda — plus standing cadence for business stream and all future agents (contract schema as DoD gate; reviewed at QBR + each new agent activation). (4) Full work breakdown, KRI dashboard, and individual tickets commissioned — Yoda owns live KRI updates. (5) Event sourcing deferred to Phase 3, trigger: post-P2 stable.

---

## Table of Contents

1. [Purpose and Scope](#1-purpose-and-scope)
2. [Current State — Honest Assessment](#2-current-state--honest-assessment)
3. [What the Decision Must Resolve](#3-what-the-decision-must-resolve)
4. [Locked Constraints — Non-Negotiable Boundaries](#4-locked-constraints--non-negotiable-boundaries)
5. [Option A — Evolve Current Architecture (Incremental Hardening)](#5-option-a--evolve-current-architecture-incremental-hardening)
6. [Option B — Redesign Data and Integration Layers (Keep OpenClaw and Agent Model)](#6-option-b--redesign-data-and-integration-layers-keep-openclaw-and-agent-model)
7. [Option C — More Radical Platform Refactor (Rebase the Foundation)](#7-option-c--more-radical-platform-refactor-rebase-the-foundation)
8. [Comparison Table](#8-comparison-table)
9. [Recommended Direction](#9-recommended-direction)
10. [What Ken Must Decide](#10-what-ken-must-decide)
11. [Appendix: Locked Decisions Reference](#appendix-locked-decisions-reference)

---

## 1. Purpose and Scope

This paper supports a single CTO-level decision: **which architectural direction should Nexus take before opening P2 to broader agent deployments and SME clients?**

Ken has identified three structural concerns that, if left unaddressed, will become unmanageable at P1–P4 scale:

1. **Data architecture** — No coherent data landscape. Fragmented across JSON files, agent memories, and file stores. No formal sources of truth, data quality rules, lineage, or data dictionary. Ken manually intervenes to maintain integrity. This is the most urgent concern.
2. **Integration architecture** — Agents make direct point-to-point calls. No standardised service or integration layer. Effective spaghetti at P2 scale.
3. **Cost and sustainability** — Almost everything routes through LLMs, including work that should be plain compute or CRUD. No clean separation between valid LLM work and non-LLM work.

This paper analyses three options across the five evaluation criteria Ken nominated, then makes a clear recommendation.

**Audience:** Ken Mun (CTO). Technical depth is appropriate. No hand-holding.

**This document is DRAFT FOR REVIEW.** Nothing in it is approved until Ken says so explicitly.

---

## 2. Current State — Honest Assessment

Before evaluating options, the current state must be named clearly. The gap between where Nexus is today and where it needs to be is significant.

### 2.1 What Exists Today (Day 19, 2026-05-14)

**Platform runtime:** OpenClaw on OC1 (Mac Mini M4 24GB). Twelve active agents. 52+ scripts. 20+ crons. ITSM-grade operations (230+ CHG records, incident management, auto-heal, Warden 15-min compliance monitoring). Production-ready at P1 internal scale.

**Data reality:**
- All structured state lives in ad-hoc JSON files with no schema validation, no ownership model, no classification tagging.
- All knowledge lives in Markdown files (MEMORY.md, RULES.md, daily notes) with no formal index.
- Notion (Holocron) is the closest thing to a source of truth for tickets, CHG records, and agent knowledge — but it is a human-managed wiki, not a governed data platform.
- No Postgres deployed. No pgvector. No formal episodic audit log.
- Ken manually corrects data state (updating statuses, file contents, logs) because agents have no reliable shared truth to write against.

**Integration reality:**
- All agent-to-agent communication happens via OpenClaw `sessions_send`.
- No contracts. No typing. No versioning. One agent's output is another's string input.
- Agents mutate state (JSON files, Markdown files) directly. No coordination layer. No conflict detection.
- System-to-agent calls and agent-to-agent calls are architecturally indistinguishable.

**LLM usage reality:**
- Status updates, file writes, JSON state mutations, CRUD operations all route through Sonnet or Haiku.
- This drives unnecessary cost, latency, and non-determinism into operations that should be deterministic scripted actions.
- Example: updating `tickets.json` status requires an agent invocation where a shell script write would suffice.

### 2.2 What Is Already Approved But Not Built

**TKT-0104 (Data & Memory Architecture Roadmap, LIVE, approved 2026-05-12):**
The full 5-tier memory architecture is designed and approved. Decisions locked: pgvector, nomic-embed-text 768-dim, optimistic locking, shared schema + RLS from P2, Postgres session tables in P1, Redis at P2. The complete schema for `agent_events`, `agent_decisions`, `decision_lineage`, `memory_access_log`, `knowledge_chunks`, `knowledge_documents`, `agent_shared_state`, `agent_state_history` is defined.

**TKT-0046 (Enterprise Landscape, LIVE, approved 2026-05-12):**
Full component map (38 Core, 8 Adjacent, 14 Client-side) with integration architecture, P2/P4 physical deployment model, and Decisions A–H locked (including shared-schema RLS, consulting-led P4, Claude block for client workloads).

**Gap that neither document addresses:** TKT-0104 defines *what to build*. TKT-0046 defines *what components exist*. Neither defines the **integration architecture** (how agents coordinate, where the integration layer sits, what a service contract looks like) nor the **data governance model** (who owns what data, what is a source of truth, how lineage is enforced across ad-hoc state).

This is what TKT-0162 must resolve.

---

### 2.3 Live Proof Point: The LinkedIn Dual-Post Incident (2026-05-14)

*Added post-authorship — same day as this paper was written. Included because it is a concrete, first-hand demonstration of all three structural concerns in production.*

**What happened:**
On the morning of 2026-05-14, two LinkedIn posts were published for the same series slot (C1W2P3 — Part 3/6 of the AIOps campaign):
- "Token Efficiency Is AIOps (Part 3/6)" — had been cancelled by Ken
- "Multi-Agent Trust (Part 3/6)" — the intended replacement

Ken had issued a cancellation instruction via Telegram. The post fired anyway. Ken manually deleted it from LinkedIn. A third post ("AIOps — What Teams Miss") would have fired the following morning at 07:30 AEST from a separate one-shot cron — caught and deleted before it ran.

**Failure mode 1 — Data architecture (no source of truth, no lineage):**
Post state was split across two separate queue files: `workspace/state/linkedin-queue.json` (main queue, managed by the content generation cron) and `workspace-social/state/linkedin-queue.json` (original series queue, managed by one-shot crons). Neither file was the authoritative source of truth. The cancellation instruction was acknowledged verbally but never written to either file. No data lineage existed to trace the instruction to a state change. The post remained in `approved` status and fired.

**Failure mode 2 — Integration architecture (no event, no contract):**
The cancellation path was: Ken → Telegram → main session (Yoda) → verbal acknowledgement. There was no typed event (e.g. `post-cancellation-requested`), no contract binding the instruction to a queue state update, and no propagation layer between the channel instruction and Spark's operational state. The instruction simply had nowhere to go. This is the spaghetti integration problem at its clearest: a valid instruction issued through a valid channel produced zero effect on downstream state.

**Failure mode 3 — Dual-channel instruction coherence:**
The cancellation came via Telegram. The queue state Spark reads from lives in the workspace filesystem, accessible from the webchat/main session context. There is no channel-agnostic instruction layer — meaning an instruction delivered in one channel has no guaranteed path to state that another session or cron reads. At P2, clients will issue instructions across Telegram, Citadel, and email. Without a single state layer that all channels write to, this class of failure is structural and repeatable.

**Why this matters for the option decision:**
Option A (incremental hardening) would add a convention: "always update the queue when you cancel." That convention has no enforcement mechanism. The same failure mode recurs whenever a channel-to-state path is missed — and at P2 scale, there will be many such paths.

Option B directly solves this: a single `linkedin_posts` table in Postgres as the source of truth, a typed `post_cancellation` event that any channel can emit, and a contract that Spark's posting logic reads only from that table. The incident becomes architecturally impossible, not just a matter of discipline.

---

### 2.4 LLM Cost Topology Today

*The third structural concern — cost and sustainability — has a specific, diagnosable root cause that is distinct from general LLM usage volume: almost everything routes through Claude Sonnet or Haiku, including work that is pure CRUD, state mutation, file writes, or system calls. This is not an agent behaviour problem. It is an architectural gap: there is no formal work classification model that routes tasks to the right compute tier. Everything defaults to LLM because LLM is the only available execution path in the current architecture.*

**Top LLM-for-CRUD offenders currently in production:**

1. **Ticket status updates** — Agents call Sonnet to update `tickets.json` when `ticket.sh` is a shell script that already exists. The reasoning step adds zero value; the script is deterministic. A ticket status update that should be a 5ms shell script write is currently a 2–3 second Sonnet turn consuming ~500–800 tokens.

2. **Cost record writes** — `cost-tracker.sh` exists and is the designated write path, but agents continue to invoke LLM turns to log spend, either by composing the log entry or by calling Sonnet to determine what to write. The composition is templated; no reasoning is required.

3. **Agent health state reads/writes** — `health-state.json` is mutated via LLM turns (agents reading, interpreting, and writing health status) rather than via deterministic script. Warden's 15-min compliance cycle routes through T3 for what are essentially file read/compare/write operations.

4. **Workflow state updates** — `async-tasks.json` and `active-work.json` are written and updated by LLM turns. State mutations (marking tasks in-progress, complete, failed) are templated operations that require no reasoning and could be handled entirely by a script called with structured parameters.

5. **LinkedIn queue mutations** — Queue state (`linkedin-queue.json`) is updated via LLM turns — as demonstrated directly by the Day 20 dual-post incident in Section 2.3. The approval status, scheduling metadata, and cancellation flags are structured fields that a script can set atomically. Instead, the current path is: instruction → LLM turn → agent writes JSON. The middle step is unnecessary and, as the incident proved, unreliable.

6. **Journal and blog generation** — A partially legitimate LLM use case, but currently triggers full Sonnet turns for output that is 60–70% script-driven template fill. The reasoning component (angle selection, first-person framing) is genuine LLM work; the structural assembly, metadata population, and file write are not.

**The structural gap:**

There is no formal **work classification model** in the current Nexus architecture. No component asks "what kind of work is this?" before routing it to an execution tier. The result is that every agent request, regardless of cognitive complexity, defaults to the highest available compute tier — Claude Sonnet or Haiku — because that is the only guaranteed execution path.

This is not a discipline failure. It is an architecture gap. The agents cannot route differently because there is no routing layer to route through. Option A adds a convention. Option B adds the structural layer that makes routing possible by design.

---

## 3. What the Decision Must Resolve

The three options differ primarily on *how much architectural restructuring happens before P2*, and *in which order*. They share the same endpoint — a P4-capable platform — but take different paths and impose different costs on Ken's time.

**The core question:** Build what's already designed (TKT-0104) and incrementally add discipline, OR redesign the integration and data governance layers now before the agent count and client count make it exponentially harder?

A secondary question: Given Ken is executing this solo (with agent assistance), what is the maximum scope of architectural work that is realistic in the 6–12 month window before P2?

**The P2 deadline is the hard constraint:** P2 target is end-August 2026 — approximately 3.5 months from now. OC2-A/B arrive in July. The window between now and P2 launch is narrow.

---

## 4. Locked Constraints — Non-Negotiable Boundaries

All three options operate within these hard constraints:

| Constraint | Detail | Source |
|---|---|---|
| OpenClaw is the final platform | No replatforming. All options extend OpenClaw, never replace it. | IT Strategy, TKT-0046 |
| Mac Mini HIVE for P1–P2 | OC1 now. OC2-A/B arriving July 2026. No cloud replatforming in this window. | MEMORY.md, IT Strategy |
| Data sovereignty | Client data = Tier 0/1 local ONLY. Never Tier 2/3 cloud APIs. | DS-1 to DS-5, TKT-0104 |
| pgvector as vector store | Locked. Changing requires full re-embedding. | TKT-0104 Decision 1 |
| nomic-embed-text 768-dim | Locked. Changing requires full re-embedding. | TKT-0104 Decision 2 |
| Shared schema + RLS with tenant_id from P2 day one | Locked. | CHG-0234, TKT-0104 Decision 6 |
| Postgres session tables P1, Redis P2 | Locked. | TKT-0104 Decision 8 |
| 4-tier model strategy | T0=systemEvent $0 \| T1=Gemma4 local $0 \| T2=Ollama Cloud $100/mo \| T3=Claude FALLBACK ONLY | MEMORY.md |
| Block Claude for P2 client workloads | BYOK exception applies. | TKT-0046 Decision H |
| Must-keep capabilities | Multi-agent orchestration, Sanctum governance, ITSM/change logging, observability, local models, cost-tier routing, always-on background ops, dual-stream agents | Brief |
| P4 consulting-led deployment | Not self-service install. | TKT-0046 Decision B |
| Phase structure | P1 (internal) → P2 (SaaS multi-tenant from day one) → P4 (Enterprise FSI). P3 = commercial tier within P2 (CHG-0234). | CHG-0234 |

---

## 5. Option A — Evolve Current Architecture (Incremental Hardening)

### 5.1 Architectural Description

Option A implements TKT-0104 as designed, adds lightweight integration conventions (not a new integration layer), and replaces the most egregious LLM-for-CRUD patterns with shell scripts. No structural redesign of how agents coordinate.

**Data architecture under Option A:**
- Deploy Postgres on OC1. Implement TKT-0104 schema (5 tiers: episodic audit, vector store, session tables, shared state with optimistic locking, state history).
- Define a **Data Landscape Register** in Holocron: for each data type, document the source of truth, owner, access pattern, and retention policy. This is a human-maintained governance artefact, not enforced by code.
- Add `tenant_id` column to all tables from day one (even though P1 is single-tenant).
- Implement `decision_lineage` table to track data lineage for agent decisions.
- Implement PII scanner (spaCy) on document ingestion.
- Classify all existing JSON state files as owned by specific agents; add a naming convention (e.g., `state/[agent]-[type].json`) and document the convention in Holocron.

**Integration architecture under Option A:**
- No formal service layer. Agents continue to call each other via `sessions_send`.
- Introduce a **CRUD script convention**: for all state mutations (JSON file writes, ticket status updates, cost record updates), agents must call a shell script rather than writing directly. Scripts are already the pattern (52+ exist); formalise it as a rule: *if a script exists for a mutation, use it; if not, create the script first*. This prevents LLM-generated mutations that bypass consistency checks.
- Document which agent "owns" each state file / Postgres table. Enforce the ownership rule: only the owning agent (or a designated script) can write to its state.
- No event bus. No typed contracts. No formal API between agents.

**LLM vs compute separation under Option A:**
- Audit all existing crons and scripts. Flag those routing through Sonnet/Haiku for work that is plainly CRUD or system calls.
- For each flagged item: replace with `systemEvent` (Tier 0) or a direct shell script.
- Implement per-agent token budget rules (already in TKT-0104's design).
- Target: reduce LLM-routed CRUD operations by ~60–70% through convention and script-first discipline.

**Work Currency Model treatment under Option A:**

Ken's work currency directive — *"Only valid LLM (high currency) work should use paid models. Medium and low currency work should use the integration layer or Ollama Cloud where best and applicable"* — maps to the existing 4-tier model strategy as follows:

| Work Currency | Definition | Compute Tier | Cost |
|---|---|---|---|
| **High** | Reasoning, design, planning, complex synthesis, novel content, decisions requiring judgment | T3: Claude Sonnet / Haiku / Opus (paid, per-token) | ~$0.003–$0.015/1K tokens |
| **Medium** | Content generation from templates, structured analysis, summarisation, classification, moderate reasoning | T2: Ollama Cloud — kimi/deepseek (fixed $100/mo) | Fixed, unlimited within plan |
| **Low** | State mutations, CRUD, file writes, status updates, simple lookups, templated formatting | T1: Gemma4 local (post-OC2) or T0: script/systemEvent (now) | $0 |
| **None** | Pure system calls, file I/O, API calls to non-LLM services, database reads/writes | T0: Shell script / systemEvent / integration layer | $0 |

Option A partially addresses the **None/Low** tier by formalising the script-first convention: if a script exists for a mutation, agents must use it. This catches the most egregious CRUD-via-Sonnet patterns (ticket updates, cost writes, health state mutations). However, Option A does nothing for the **Medium** tier. Work that is medium currency — content generation from templates, structured analysis, journal drafts, classification — continues to route to Sonnet because there is no routing layer to direct it to Ollama Cloud (T2) instead.

Critically, **there is no routing intelligence in Option A.** The improvement is manual and convention-based: Ken or an agent engineer must identify each LLM-for-CRUD offender, write a replacement script, and update the relevant agent behaviour. This approach is sound for a one-time audit but degrades over time. As new agents and workflows are added during P2, LLM-for-CRUD patterns will naturally recur — because the architecture still provides no mechanism to prevent them. The script-first convention is a policy, not an enforcement layer.

**What this does NOT change:**
- Agent-to-agent communication remains point-to-point via `sessions_send`.
- No formal service contracts or typing.
- Data ownership is documented but not enforced programmatically (relying on convention).
- Integration patterns remain ad-hoc; new agents added during P2 must be manually reviewed for compliance with conventions.

### 5.2 Pros and Cons by Evaluation Criterion

#### Criterion 1: Technical Robustness and Scalability

| Pros | Cons |
|---|---|
| Builds on what's already approved (TKT-0104). No new architecture decisions. | Point-to-point agent calls will not scale beyond ~15 agents without becoming unmanageable. |
| Postgres + pgvector + RLS provides a solid data foundation once built. | Ownership conventions enforced by rule, not code. Rule violations accumulate silently. |
| The 5-tier memory model is FSI-appropriate and proven in design. | No event bus means no retry, no dead-letter queue, no observable failure path for agent coordination. |
| Lowest risk of regression during the P2 window. | Technical debt in the integration layer is deferred, not eliminated. At P2 with 3-5 clients and growing agent count, complexity grows non-linearly. |

**Assessment:** Technically adequate for P1–early P2 with ≤5 clients and ≤15 agents. Structural ceiling hit at P2 moderate scale (~15–20 agents, 10+ clients). Not FSI-ready at integration layer.

#### Criterion 2: Data Quality, Lineage, Governance, FSI Readiness

| Pros | Cons |
|---|---|
| Implements all TKT-0104 data controls: audit log, decision lineage, PII scanner, classification tagging. | Data Landscape Register is human-maintained in Notion. Not enforced. Governance is documentation, not architecture. |
| Episodic audit log provides the lineage foundation APRA CPG 235 requires. | Sources of truth for operational state (tickets, agent status, cost reports) remain JSON files with naming conventions. No schema validation. |
| pgvector + nomic-embed-text gives a compliant local-first RAG pipeline. | No data quality gate on agent-to-agent data flows. An agent can pass malformed output and the next agent has no validation. |
| WORM-capable upgrade path to P4 is clear (append-only schema from day one). | Without integration contracts, data lineage beyond "this decision came from this chunk" is hard to reconstruct. Agent A tells Agent B something; that context is not in the lineage table. |

**Assessment:** Good for P1 data governance. TKT-0104 implementation closes the most critical gaps. But the absence of typed integration contracts means a meaningful FSI readiness gap remains at the integration layer. For P4 APRA CPG 234, the integration layer will need to be addressed regardless.

#### Criterion 3: Complexity and Feasibility for Ken (Solo, 6–12 Months)

| Pros | Cons |
|---|---|
| Work is well-defined. TKT-0104 schema is ready. TKT-0046 provides the component map. Very little architectural design work required. | Still requires ~3–5 months of build time: Postgres deploy, schema, pgvector, RAG pipeline, PII scanner, session tables, audit wiring across 12 agents. |
| No new architectural decisions to make before building. | Script-first convention requires backporting discipline to all existing agents and crons. Not small. |
| Each TKT-0104 P1 action (5 actions, Weeks 1–4) is well-scoped. | The Data Landscape Register requires Ken to document ~30+ existing data types. That is real work. |
| Estimated weekly time commitment: **8–12 hrs/week** for 3–4 months, then maintenance. | If skipped or partially done, the "incremental" path produces a half-built data layer that is worse than the current state (adds Postgres but doesn't consistently use it). |

**Assessment:** The most feasible option in the P2 window. The risk is not scope — it is discipline. Incremental paths require sustained commitment to convention; without it, the technical debt simply moves from files to a partially-used database.

#### Criterion 4: Cost (Build + Run) and Long-Term Sustainability

| Pros | Cons |
|---|---|
| Lowest upfront build cost. Reuses existing patterns. | Lowest long-term sustainability. Integration spaghetti grows with every new agent. |
| No new infrastructure required beyond Postgres on OC1. | Agent coordination via `sessions_send` without contracts means each new integration is a one-off negotiation between two agents — not a reusable pattern. |
| No new operational overhead (no event bus, no service registry). | LLM cost reduction is achievable but relies on Ken manually auditing and replacing patterns. No systemic mechanism. |

**Assessment:** Lowest build cost, but "cheapest now, most expensive later." At P2 with 5+ clients and 20+ agents, the absence of a service layer will be felt every time a new workflow crosses agent boundaries.

#### Criterion 5: Flexibility to Change Direction Later

| Pros | Cons |
|---|---|
| Maximum flexibility in theory — no irreversible architectural commitments beyond TKT-0104 (already locked). | In practice, building Option A now and then redesigning the integration layer at P2 scale is harder than designing it correctly at P1 scale. |
| Can pivot to Option B at any point — the Postgres schema already supports it. | The more agents and workflows built on point-to-point patterns, the more expensive Option B becomes later. |

**Assessment:** Option A preserves optionality, but optionality is not free. The cost of the Option B migration grows non-linearly with every new agent that ships without integration contracts.

### 5.3 Complexity and Feasibility Assessment

**Implementation sequence:**
1. **Weeks 1–2:** Deploy Postgres on OC1. Implement TKT-0104 5-tier schema. Wire SHA-256 hashing into top 3 most active agents.
2. **Weeks 3–4:** Add pgvector. Deploy nomic-embed-text. Build PII scanner. Create initial knowledge base.
3. **Month 2:** Audit all agent crons for LLM-for-CRUD patterns. Replace top 10 offenders with `systemEvent`/shell scripts. Wire `decision_lineage` tracking into Yoda and Atlas.
4. **Month 2–3:** Document Data Landscape Register in Holocron. Define agent state ownership. Apply classification tags to all existing JSON files.
5. **Month 3–4:** Add `tenant_id` to all tables. Implement RLS policies. Prepare P2 data layer.

**Estimated weekly time commitment for Ken:** 8–12 hrs/week months 1–3; 3–5 hrs/week maintenance thereafter.

**Dependencies:** OC2-A/B not required for this option. Can execute entirely on OC1.

**P2-readiness timeline:** Data layer ready by end of Month 3 (end-July 2026). Integration layer remains ad-hoc. P2 can launch with this — but will require rework at P2 scale.

### 5.4 P1–P4 Overlay

| Phase | Option A State | What Must Happen Before Each Phase |
|---|---|---|
| **P1 (current internal)** | Postgres deployed. 5-tier schema live. Script-first convention documented and partially backported. LLM-for-CRUD patterns reduced. | TKT-0104 P1 actions 1–5 completed. Data Landscape Register drafted. |
| **P2 (SaaS multi-tenant)** | Postgres with tenant_id + RLS operational. Redis for session state. RAG pipeline live. Agent coordination still point-to-point. | All P1 actions complete. tenant_id + RLS on all tables. Per-tenant isolation validated in Docker. Integration spaghetti managed by convention, not architecture. This is the risk zone. |
| **P3 (commercial tier within P2)** | Same as P2. Feature flag enablement for company/multi-agent tier. | RLS policies proven under real tenant load. No new data architecture work required — it is a feature unlock. |
| **P4 (Enterprise FSI)** | Data layer is FSI-adequate (audit log, lineage, PII gate, WORM path). Integration layer requires redesign before P4 consulting engagement begins. | Integration layer must be redesigned before any P4 FSI engagement. This is Option B work, deferred. Option A does not produce a P4-ready integration architecture. |

### 5.5 Key Risks and Point-of-No-Return Moments

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Convention drift:** Agents bypass script-first rule, write to JSON files directly, eroding data integrity | High | Medium | Warden monitoring extended to detect non-script state mutations. Convention documented in RULES.md. |
| **Incomplete implementation:** Postgres deployed but not consistently wired across all 12 agents | High | High | Mandatory wiring as DoD on all new agent work. Audit check added to auto-heal.sh. |
| **P2 integration debt becomes unblocking:** At 5+ clients, a single workflow crossing 4+ agents fails in a way that is impossible to debug without contracts | Medium | High | None under Option A. This is the structural risk that Option B addresses. |
| **P4 engagement blocked:** FSI client requires demonstrable integration governance before sign-off | Low (P1–P2) / High (P4) | High | Accepted deferral. Option A explicitly defers integration architecture to "before P4." |
| **Point of no return:** None in Option A — no irreversible decisions beyond what is already locked. | — | — | Maximum optionality, lowest ceiling. |

---

## 6. Option B — Redesign Data and Integration Layers (Keep OpenClaw and Agent Model)

### 6.1 Architectural Description

Option B implements TKT-0104 as designed AND introduces a deliberate, structured redesign of both the data governance model and the integration layer — while keeping OpenClaw, the current agent model, and all approved decisions intact.

**The core architectural addition:** A thin, explicit **internal service layer** that sits between agents and the systems they interact with. Agents do not call each other directly for data mutations; they interact through defined contracts. The data layer has explicit sources of truth, ownership rules enforced by the architecture (not just convention), and lightweight data quality gates.

**Data architecture under Option B:**

Everything in Option A, plus:

- **Formal Sources of Truth Register:** Define the authoritative source for each data domain — not in Notion as a human document, but enforced at the architecture level. Each data type has exactly one owner and one canonical storage location. Reads come from the source; nothing gets cached elsewhere without an explicit derivation rule.
  - Examples: `tickets.json` → migrated to Postgres `tickets` table (owned by ITSM subsystem, accessed via `ticket.sh`). Agent health state → Postgres `agent_health` table (owned by Forge/Warden, read via API). Cost data → Postgres `cost_events` table (owned by cost-tracker script, never LLM-written).
  
- **Postgres as the operational backbone:** All structured state migrates from JSON files to Postgres tables over a 2–3 month period. JSON files become deprecated caches only. No new state is created in JSON files for structured data.

- **Data quality gates on agent-to-agent data flows:** When Agent A hands data to Agent B, the output conforms to a defined schema (JSON Schema, validated before passing). A lightweight schema validator (e.g., `ajv` or Python `pydantic`) is integrated into the handoff path for high-value workflows.

- **Formal data lineage pipeline:** Not just `decision_lineage` for RAG retrievals, but a lightweight event that records: *Agent X consumed data Y from source Z to produce output W for workflow V*. This creates full lineage for any agent workflow — not just decisions that touch the vector store.

**Integration architecture under Option B:**

- **Internal event bus via Postgres LISTEN/NOTIFY:** Lightweight async coordination between agents without adding infrastructure. Agent A publishes an event (e.g., `ticket_created`, `workflow_completed`) to a Postgres channel. Agent B subscribes and reacts. This eliminates direct `sessions_send` for non-interactive agent coordination (background tasks, status propagation, handoffs).
  - This is not Kafka. It is a Postgres extension already available. Zero new infrastructure.
  - For synchronous coordination (one agent instructing another), `sessions_send` is retained — it is the right tool for interactive orchestration.

- **Typed agent contracts for cross-agent data exchange:** Define a lightweight schema for each agent's "output contract" — what it produces, in what format, with what required fields. Stored in Holocron and enforced by a validator called at the handoff point.
  - These do not need to be full OpenAPI specs. A JSON Schema file per agent output type, validated before passing between agents.

- **Clear separation of agent work types:**
  - *Reasoning work (LLM):* Analysis, planning, content generation, complex decisions. Always routes through appropriate model tier.
  - *CRUD work (systemEvent/script):* State mutations, ticket updates, file writes, cost records, status changes. Never routes through LLM.
  - *Coordination work (event bus or sessions_send):* Agent-to-agent handoffs. Light events via Postgres LISTEN/NOTIFY for async; `sessions_send` for synchronous orchestration.
  - This is codified in a RULES.md addition: **The Three Work Types Rule.**

**Work Currency Model treatment under Option B:**

Option B is the architectural prerequisite for systematically enforcing Ken's work currency model. The event bus and typed contracts create the structural foundation that makes routing by currency possible — not just aspirational.

| Work Currency | Definition | Compute Tier | Cost |
|---|---|---|---|
| **High** | Reasoning, design, planning, complex synthesis, novel content, decisions requiring judgment | T3: Claude Sonnet / Haiku / Opus (paid, per-token) | ~$0.003–$0.015/1K tokens |
| **Medium** | Content generation from templates, structured analysis, summarisation, classification, moderate reasoning | T2: Ollama Cloud — kimi/deepseek (fixed $100/mo) | Fixed, unlimited within plan |
| **Low** | State mutations, CRUD, file writes, status updates, simple lookups, templated formatting | T1: Gemma4 local (post-OC2) or T0: script/systemEvent (now) | $0 |
| **None** | Pure system calls, file I/O, API calls to non-LLM services, database reads/writes | T0: Shell script / systemEvent / integration layer | $0 |

How Option B delivers work currency routing in practice:

- **The event bus natively separates coordination (T0/T1) from reasoning (T2/T3).** Events fired via Postgres LISTEN/NOTIFY are zero-cost system signals — they carry no LLM invocation. An agent subscribing to a `ticket_status_changed` event and updating its internal state is executing a T0 operation, not a T3 turn.

- **Typed contracts make work currency explicit at design time.** Each contract declares the nature of the work being requested. A `WorkflowRequest` contract typed as `work_currency: medium` can be intercepted at the dispatch layer and routed to Ollama Cloud (T2) rather than Sonnet (T3). Without typed contracts, there is no field to inspect; routing must be inferred from free-form text.

- **The integration layer makes call paths observable.** When agents call external systems (scripts, APIs, other agents) through named wrappers rather than ad-hoc invocations, every call is a named operation with a known compute cost. This creates the observability needed to identify remaining medium-currency work that still routes to T3 and reassign it.

- **Concrete examples of currency-based routing under Option B:**
  - Journal generation (medium currency — template-driven narrative synthesis) → Ollama Cloud kimi (T2). Not Sonnet.
  - Ticket status update (none currency — field write) → `ticket.sh` script (T0). Not Haiku.
  - Option paper analysis (high currency — complex architectural reasoning) → Claude Sonnet (T3). Correct tier.
  - LinkedIn post draft (medium currency — structured content generation from campaign brief) → Ollama Cloud kimi (T2). Not Sonnet.

Option B builds the pipes. The work currency routing intelligence follows from having observable, typed call paths — something Option A cannot provide.

- **Service layer abstraction for external calls:** All calls to external systems (Google Drive, Telegram, Notion API) go through named scripts (already mostly true). No agent invokes an external API directly in freeform — it calls a defined script wrapper. This already exists for some tools; Option B completes the pattern.

**What this does NOT change:**
- OpenClaw runtime — unchanged.
- Agent model (Yoda orchestrates, specialists execute) — unchanged.
- All locked decisions (pgvector, RLS, model tiers) — unchanged.
- Mac Mini HIVE infrastructure — unchanged.

### 6.2 Pros and Cons by Evaluation Criterion

#### Criterion 1: Technical Robustness and Scalability

| Pros | Cons |
|---|---|
| Internal event bus (Postgres LISTEN/NOTIFY) allows async coordination without blocking — agents no longer block each other waiting for `sessions_send` responses in background tasks. | Introducing typed contracts requires schema design for each agent's output — not a huge task but adds ~20–30 hours of design work upfront. |
| Typed contracts make integration failures observable and diagnosable — broken contracts produce schema validation errors, not silent bad data. | Postgres LISTEN/NOTIFY is not a durable queue — if the listener isn't active when the event fires, the event is lost. Acceptable for background coordination; requires Redis Streams at P2 for durable async. |
| Separation of work types (reasoning/CRUD/coordination) produces a deterministic, cost-optimised, and auditable platform. | Migration of JSON state to Postgres requires systematic effort across all 12 agents. Under-done, it produces a messy dual-state reality. |
| Event bus pattern scales to P2 multi-tenant naturally (add tenant_id to event payloads). Each tenant's events are isolated by design. | Adding schema validation to agent handoffs adds latency in the critical path (typically <5ms, negligible for most workflows but non-zero). |
| Technically sound to P4 scale. FSI auditors can inspect the integration layer and find it structured and governed. | Requires Ken to invest ~6–8 weeks of focused build before the first P2 client goes live. |

**Assessment:** Option B produces a platform that scales architecturally from P1 through P4 without requiring a rethink of the integration layer. It is the right architecture for a platform targeting FSI clients.

#### Criterion 2: Data Quality, Lineage, Governance, FSI Readiness

| Pros | Cons |
|---|---|
| All TKT-0104 data controls, plus formal sources of truth enforced by architecture. | Data quality gates on agent handoffs add design overhead — schema must be defined for each workflow's data exchange points. Not all workflows need this; prioritisation required. |
| Full data lineage: not just RAG-decision lineage but end-to-end workflow lineage. Any workflow output traceable to its inputs. | If schema validation is too strict, it breaks existing workflows that pass informal data. Migration requires either relaxed schemas initially (and tightening over time) or fixing workflows. |
| Postgres as single backbone for all structured state: single place to query, single place to govern, single place to audit. | |
| Data quality gates catch bad data before it corrupts downstream agents — the exact problem Ken is experiencing with manual state correction. | |
| Directly addresses CPG 235 requirement: "every agent decision traceable to source data." End-to-end lineage, not just vector-retrieval lineage. | |
| Sources of truth register enforced by code: agent state migrations, ownership rules, and write permissions are architectural constraints, not conventions. | |

**Assessment:** Option B is the path to genuine FSI readiness at the data and integration layer. Not just defensible to an auditor — actually structured the way a regulated entity would require.

#### Criterion 3: Complexity and Feasibility for Ken (Solo, 6–12 Months)

| Pros | Cons |
|---|---|
| The additional work beyond Option A is well-defined: schema design per agent output type, JSON→Postgres migration for ~8–10 key state files, Postgres LISTEN/NOTIFY event bus setup, Three Work Types Rule codification. | The additional work is real: estimate +6–8 weeks of design and build beyond Option A. This is a material difference given the P2 August deadline. |
| The event bus (Postgres LISTEN/NOTIFY) is a 1–2 day implementation, not weeks. It is not Kafka. | Typing agent contracts requires discipline across all future agent development — a new overhead Ken must maintain. |
| JSON Schema validation can be introduced incrementally — start with the 3–4 most critical cross-agent handoffs, expand over time. | Migrating JSON state to Postgres while maintaining operational continuity requires careful sequencing. One wrong migration breaks live agents. |
| Much of the work is systematic (script-level) and can be delegated to Forge with clear specifications, reducing Ken's direct build time. | |

**Estimated weekly time commitment for Ken:** 12–18 hrs/week months 1–3; 5–8 hrs/week months 4–6 (integration solidification and P2 multi-tenancy); 3–5 hrs/week maintenance thereafter.

**Timeline risk:** The additional scope makes P2 by end-August 2026 ambitious but achievable IF the integration layer work is scoped tightly — event bus + top 3–4 typed contracts + JSON→Postgres migration of the 5 most-critical state files. Full schema coverage across all 12 agents is a 6-month project, not a 3-month one. Phased delivery is essential.

**Recommendation within Option B:** Phase the integration layer work. Phase 1 (P1→P2): event bus + critical typed contracts + Postgres migration of core state. Phase 2 (P2 live): complete agent output schema library. This is not compromising Option B — it is sequencing it realistically.

### 6.3 P1–P4 Overlay

| Phase | Option B State | What Must Happen Before Each Phase |
|---|---|---|
| **P1 (current internal)** | Postgres + 5-tier schema + Postgres LISTEN/NOTIFY event bus. Top 3–4 typed contracts. Core state migrated from JSON to Postgres. Three Work Types Rule enforced. | All TKT-0104 P1 actions. Event bus setup. Critical typed contracts. Core JSON→Postgres migration. |
| **P2 (SaaS multi-tenant)** | Full data governance layer (sources of truth, lineage, classification). tenant_id + RLS. Per-tenant event isolation. Redis Streams replaces Postgres LISTEN/NOTIFY for durable async. Complete agent output schema library (incremental). | Redis Streams deployed. All tenant-facing workflows have typed contracts. Data quality gates on all tenant-touching agent handoffs. |
| **P3 (commercial tier within P2)** | Same as P2. Company-level event channels for org-scoped coordination. | Org-level event namespacing in Redis Streams. Agent team coordination patterns (manager-worker within org) formalized. |
| **P4 (Enterprise FSI)** | Integration layer already structured and auditable. Full workflow lineage. Postgres LISTEN/NOTIFY → Redis Streams → (optional) Kafka for FSI client system integration. WORM audit log. HSM key management. | Kafka connector (if FSI client requires). Event sourcing migration for shared state (Option B schema supports this). APRA CPG 234/235 formal compliance assessment. |

**Key insight:** Option B's P4 path is clean. The FSI auditor sees a structured integration layer, typed contracts, full data lineage, and a clear source-of-truth architecture. No structural redesign required before a P4 engagement begins.

### 6.4 Key Risks and Point-of-No-Return Moments

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Scope overrun into P2 window:** Integration layer work bleeds into P2 launch timeline | Medium | High | Phase the work. Phase 1 covers what is needed for P2 launch. Phase 2 fills gaps post-launch. Define the Phase 1/2 boundary explicitly before starting. |
| **Postgres LISTEN/NOTIFY lost events:** A background agent publishes an event but no listener is active | Medium | Low–Medium | Acceptable for P1 background coordination. Migrate to Redis Streams at P2 (already planned). Log all events to Postgres table as durable record regardless. |
| **Schema typing creates friction for new agents:** New agent development requires schema design before implementation | Low–Medium | Low | Manageable overhead. Define a schema template and a "minimum viable contract" (3 required fields) as the standard. Enforce via CHG gate — no new agent without a defined output contract. |
| **JSON→Postgres migration breaks live agents mid-migration:** Dual-state during migration causes inconsistency | Medium | High | Sequenced migration with parallel reads during transition (read from Postgres, fallback to JSON). Kill switch in auto-heal.sh to revert a specific migration. |
| **Point of no return:** The JSON→Postgres migration is partially reversible but costly to undo once workflows depend on Postgres. | — | — | Not a true point of no return. But reverting mid-migration adds weeks of cleanup. Commit to completing each migration as a single sprint. |

---

## 7. Option C — More Radical Platform Refactor (Rebase the Foundation)

### 7.1 Architectural Description

Option C goes beyond redesigning the data and integration layers — it rebases the architectural foundation itself, adopting patterns that are typically found in mature enterprise data platforms. This means: event sourcing as the primary state model (not just for P4 migration, but from day one), a formal data platform separation (OLTP for agent operations, analytical/reporting layer for observability and lineage), and a thin internal service mesh with fully typed, versioned contracts.

**Hard constraint reminder:** Option C CANNOT mean replacing OpenClaw. That decision is locked. Option C operates entirely within the OpenClaw + Mac Mini HIVE constraint. "Rebasing the foundation" means the data model and integration architecture, not the runtime.

**Event sourcing as primary state model:**
- All state changes are expressed as immutable events (`TicketCreated`, `AgentDecisionMade`, `WorkflowStarted`, `StatusChanged`).
- Current state is derived by replaying the event log — no mutable state tables for operational data.
- The `agent_state_history` table in TKT-0104 becomes the primary record, not a secondary audit table.
- Every agent's write operation produces an event, never a direct mutation.
- Benefits: full audit trail of every state change, by whom, in what order. APRA CPG 235 is satisfied natively. No separate "audit log" layer required — the event log IS the system of record.

**Formal data platform separation:**
- **OLTP layer (Postgres):** Event store. Current session state. Vector store (pgvector). Agent coordination.
- **Analytical layer:** A set of Postgres views (or materialised views) that project current state from events. These are the "current state" tables agents query — derived from events, not written directly. Alternatively: periodic export to Parquet files for any reporting that doesn't need real-time data.
- **Reporting layer:** Datapad and Beacon consume from the analytical layer, not from agent OLTP tables directly. Clean separation of concerns.
- This is not a data warehouse. It is a thin separation of "write-optimised event store" from "read-optimised projected state." Achievable in Postgres alone without new infrastructure.

**Fully typed, versioned service contracts:**
- Every agent-to-agent interaction has a named, versioned contract (e.g., `WorkflowRequest/v1.0`, `DecisionOutput/v1.1`).
- Contract registry in Holocron. Version bumps require a CHG entry.
- Breaking contract changes require migration path for all consuming agents.
- This is the integration pattern enterprises use. It is also significant overhead for a solo operator.

**Internal service mesh:**
- A lightweight routing layer (implemented as a script or small service) that mediates all inter-agent communication. Agents do not call each other directly — they publish requests to the router, which dispatches to the appropriate agent.
- This eliminates the hard-coded `sessions_send` calls between specific agents and introduces discoverability and routing flexibility.
- The router is a new component to build and maintain.

**Work Currency Model treatment under Option C:**

Event sourcing natively captures work type at the event level. Every state change is an immutable event that carries metadata about its origin — including which agent produced it and through which compute tier. This means work currency is not an add-on classification; it is embedded in the event schema from the start.

| Work Currency | Definition | Compute Tier | Cost |
|---|---|---|---|
| **High** | Reasoning, design, planning, complex synthesis, novel content, decisions requiring judgment | T3: Claude Sonnet / Haiku / Opus (paid, per-token) | ~$0.003–$0.015/1K tokens |
| **Medium** | Content generation from templates, structured analysis, summarisation, classification, moderate reasoning | T2: Ollama Cloud — kimi/deepseek (fixed $100/mo) | Fixed, unlimited within plan |
| **Low** | State mutations, CRUD, file writes, status updates, simple lookups, templated formatting | T1: Gemma4 local (post-OC2) or T0: script/systemEvent (now) | $0 |
| **None** | Pure system calls, file I/O, API calls to non-LLM services, database reads/writes | T0: Shell script / systemEvent / integration layer | $0 |

Under Option C, every event in the event store carries a `compute_tier` and `work_currency` field (e.g., `{"event": "TicketStatusChanged", "compute_tier": "T0", "work_currency": "none", "agent": "forge"}`). This creates:

- **Retrospective analysis:** Query the event log to determine what proportion of state changes originated from T3 vs T0/T1. Identify remaining high-currency spend on low-currency work with a single SQL query against the event store.
- **Automated routing optimisation:** Once patterns are visible in the event log, routing rules can be adjusted programmatically — closing the feedback loop between observed compute cost and future routing decisions.
- **Auditability:** An FSI auditor or cost reviewer can inspect the event log and see exactly what compute tier produced every state change over any time period. No inference required.

**However:** this level of sophistication is not needed to achieve 80% of the cost benefit. Option B delivers the routing separation — observable call paths, typed contracts with work currency declarations, integration layer that makes medium-currency work identifiable. Option C adds auditability and feedback loop automation on top of that foundation. The incremental value of Option C's event sourcing over Option B's integration layer for work currency purposes is real, but it is the last 20%, not the first 80%. Given the feasibility constraints on Option C (Section 7.2 Criterion 3), the work currency benefit alone does not justify the additional implementation complexity.

### 7.2 Pros and Cons by Evaluation Criterion

#### Criterion 1: Technical Robustness and Scalability

| Pros | Cons |
|---|---|
| Event sourcing produces the most robust, auditable platform architecture available. Every state mutation is immutable and traceable. | Event sourcing is significantly more complex to implement and operate than CRUD + audit log. Most teams make mistakes in their first event sourcing implementation. |
| The analytical/reporting layer separation eliminates contention between agent operational writes and reporting reads. | Materialised views or event projections add query latency and must be refreshed — a non-trivial operational concern. |
| Versioned contracts mean breaking changes are impossible to make silently. Downstream failures are caught before they hit production. | Service mesh router is a new single point of failure. If it fails, all agent coordination fails. High operational consequence. |
| Maximum P4 scalability. This architecture does not need to be revisited before a P4 FSI engagement. | This architecture is built for 50+ agents and 100+ workflows. At 12 agents and P1–P2 scale, much of the complexity adds overhead without proportional value. |

**Assessment:** Technically superior, but overbuilt for the current scale. The gap between the sophistication of this architecture and Ken's current solo execution capacity is the defining concern.

#### Criterion 2: Data Quality, Lineage, Governance, FSI Readiness

| Pros | Cons |
|---|---|
| Event sourcing natively satisfies CPG 235 lineage requirements: every state change is an event with agent identity, timestamp, and causal context. | Event schema design is an art — poor event schema decisions are expensive to correct after events have been stored. Requires careful upfront design with FSI requirements in mind. |
| Full data platform separation means audit reports, compliance reports, and operational dashboards never contend with agent writes. | Maintaining event schema versioning across 12 agents is a governance overhead that adds to Ken's ongoing operational burden. |
| Versioned contracts mean every data interface is documented and auditable. The FSI auditor's dream. | |
| Analytical layer projection gives clean, validated "current state" views that agents and dashboards consume — no dirty data from partial writes. | |

**Assessment:** Best possible data quality and FSI readiness. But the governance overhead of maintaining event schemas and versioned contracts for 12 agents solo is substantial.

#### Criterion 3: Complexity and Feasibility for Ken (Solo, 6–12 Months)

| Pros | Cons |
|---|---|
| The architectural vision is clear and well-documented in industry literature. | Event sourcing is a non-trivial implementation paradigm. The first implementation typically takes 2–3x longer than estimated. |
| Agents produce events naturally (they are already taking actions with observable side effects). | Service mesh router is a new infrastructure component to design, build, test, and operate. |
| | Versioned contract registry adds ongoing maintenance overhead for every new agent and every workflow change. |
| | **Estimated weekly time commitment: 20–30 hrs/week months 1–4; 10–15 hrs/week months 5–12.** This is at the outer limit of what is realistic for a solo operator with concurrent business obligations (P2 clients, training delivery, OKR execution). |
| | The P2 August deadline is very likely missed under Option C unless significant scope is cut from P2 itself. |
| | Option C risks the "halfway done" failure mode: if Ken starts this architecture and cannot complete it before P2, the platform is in an inconsistent state that is harder to operate than the current ad-hoc state. |

**Estimated weekly time commitment for Ken:** 20–30 hrs/week months 1–4; 10–15 hrs/week months 5–12. **This is not realistic for solo execution given concurrent business obligations.**

**Honest assessment:** Option C is the right architecture for a team of 3–5 engineers building a platform over 12–18 months. For a solo CTO with concurrent training delivery, consulting engagements, P2 client management, and agent operations, Option C is likely to be partially completed — which is worse than not starting it.

### 7.3 P1–P4 Overlay

| Phase | Option C State | Risk |
|---|---|---|
| **P1 (current)** | Event store partially deployed. Some agents wired to event model. Dual-state (events + legacy JSON) during migration. | Highest instability risk. Platform in transition throughout P1. |
| **P2 (SaaS)** | Event sourcing complete for core agent workflows. Analytical projection layer operational. Service mesh handling internal routing. | P2 delay risk is high. The architecture may not be complete enough for multi-tenant operation by August 2026. |
| **P3 (commercial tier)** | Full event sourcing. Org-level event channels. | If P2 was delayed, P3 commercial tier unlock is also delayed. |
| **P4 (FSI)** | Natively P4-ready. Full audit trail, versioned contracts, clean separation. | If the platform gets here, it is the best possible foundation for FSI. The risk is whether it gets here. |

### 7.4 Key Risks and Point-of-No-Return Moments

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Solo execution capacity exceeded:** Ken cannot sustain 20–30 hrs/week of architectural build while running a business | Very High | Critical | No technical mitigation. This is a capacity question only Ken can answer. |
| **P2 deadline missed:** Platform not multi-tenant ready by August 2026 | High | High | Descope: accept that P2 launches with a subset of Option C implemented. At that point, you are effectively doing Option B with event sourcing added. |
| **"Halfway" failure mode:** Event sourcing partially implemented; half the agents write events, half write to JSON files; system state is unpredictable | High | Very High | Requires strict enforcement: all agents migrate or none. One agent on legacy patterns breaks the projection logic. |
| **Event schema mistakes:** First event schemas are poorly designed, requiring costly schema migration after events are stored | Medium | High | Invest 2–3 weeks in event schema design with Ken reviewing every schema before implementation. Do not rush. |
| **Point of no return:** Event sourcing commits you to a specific state model. Once significant event history is accumulated, migrating away from event sourcing is extremely expensive. | — | — | True point of no return. If Option C is started and found to be infeasible mid-build, you cannot revert to Option A/B cleanly. The event store is now a constraint on all future design. |

**Direct statement:** Option C is the right architecture for the wrong execution context. For a solo CTO, the risk of partial completion is too high. A partially implemented event sourcing architecture is significantly worse than a well-implemented CRUD + audit log architecture.

---

## 8. Comparison Table

| Evaluation Criterion | Option A — Incremental Hardening | Option B — Redesign Data + Integration | Option C — Radical Refactor |
|---|---|---|---|
| **Technical robustness and scalability** | ⚠️ Adequate P1–early P2. Ceiling hit at 15–20 agents. Integration spaghetti grows. | ✅ Scales P1→P4 without rethink. Structured integration layer. Event bus provides async headroom. | ✅✅ Maximum robustness. Best possible scalability. But overbuilt for current scale. |
| **Data quality, lineage, governance / FSI readiness** | ⚠️ Good data layer (TKT-0104). Lineage for RAG decisions. But integration-layer lineage gaps. Sources of truth documented not enforced. | ✅ Full data governance. Enforced sources of truth. End-to-end workflow lineage. Schema-validated data exchange. FSI-ready at integration layer. | ✅✅ Native event sourcing satisfies CPG 235 without separate audit infrastructure. Best possible FSI readiness. |
| **Complexity and feasibility for Ken (solo, 6–12 months)** | ✅✅ Most feasible. Well-defined scope. TKT-0104 is ready to implement. 8–12 hrs/week. | ✅ Feasible with phased delivery. 12–18 hrs/week months 1–3. Requires tight scope management on Phase 1. | ❌ Not feasible for solo execution alongside concurrent business obligations. 20–30 hrs/week required. High risk of partial completion. |
| **Cost (build + run) and long-term sustainability** | ✅ Lowest build cost. ⚠️ Lowest sustainability — integration debt grows. Defers the expensive work to P2 when it costs more. | ✅ Moderate build cost. High sustainability — event bus + typed contracts scale to P4 without rethink. Best total cost of ownership. | ⚠️ High build cost. Highest sustainability if completed. But high risk of sunk cost if partially completed. |
| **Flexibility to change direction later** | ✅ Maximum flexibility now. ⚠️ Flexibility decreases fast as agents and workflows accumulate on ad-hoc patterns. | ✅ Flexibility preserved. Option C can be added later (event sourcing migration path preserved in schema). | ⚠️ Most committed. Event sourcing is a point of no return. Difficult to undo once significant history accumulated. |
| **P2 readiness timeline** | ✅✅ Fastest. Data layer ready by end-July 2026. P2 launch on schedule. | ✅ Achievable with phased delivery. Phase 1 complete by end-July 2026. Phase 2 post-P2 launch. | ❌ High risk of missing August 2026 P2 target. |
| **P4 FSI readiness** | ⚠️ Data layer ready. Integration layer must be redesigned before P4 engagement (Option B work deferred). | ✅ P4-ready at integration layer without further redesign. | ✅✅ Natively P4-ready. No further redesign required. |
| **Risk of "halfway done" failure** | Low | Low–Medium (with phased delivery) | Very High |

**Summary scoring (1 = worst, 5 = best for Nexus's context):**

| Criterion (weighted) | Option A | Option B | Option C |
|---|---|---|---|
| Technical robustness / scalability (25%) | 3 | 5 | 5 |
| Data quality / FSI readiness (25%) | 3 | 5 | 5 |
| Feasibility for Ken solo (20%) | 5 | 4 | 1 |
| Cost / sustainability (15%) | 3 | 5 | 3 |
| Direction flexibility (15%) | 4 | 4 | 2 |
| **Weighted score** | **3.55** | **4.70** | **3.35** |

---

## 9. Recommended Direction

**Recommendation: Option B — with phased delivery.**

**The case for Option B:**

Option A is tempting because it is well-defined and low-risk. But Option A explicitly defers the integration architecture problem. That problem does not disappear — it compounds. Every new agent built on point-to-point patterns, every new workflow that crosses agent boundaries without a contract, makes the future redesign more expensive. At P2 with 5 SME clients and 15+ active agents, a single complex workflow failure will be impossible to diagnose without the integration visibility that Option B provides.

Option C is architecturally superior but the wrong fit for Ken's execution context. The risk of partial completion — a platform caught between event sourcing and CRUD, with neither working cleanly — is genuinely high for a solo operator with concurrent business obligations. The right architecture at the wrong execution capacity produces the wrong outcome.

Option B is the answer because it solves the actual problem (data fragmentation, integration spaghetti, LLM-for-CRUD) at a scope that Ken can execute, delivers a platform that is genuinely P4-ready at the integration layer, and does so without the irreversible commitments of Option C.

**The phasing that makes Option B work:**

Phase 1 (Now → end-July 2026, before OC2 arrives):
- All TKT-0104 P1 actions (Postgres + 5-tier schema + pgvector + RAG + PII scanner).
- Postgres LISTEN/NOTIFY event bus set up. Core event types defined.
- Top 5 critical state files migrated from JSON to Postgres (tickets, cost events, agent health, change records, workflow state).
- Top 3–4 typed agent contracts (Yoda→Atlas, Yoda→Forge, Yoda→Shield, Atlas→Ken output).
- Three Work Types Rule published in RULES.md and wired into RULES.md of all agents.
- Data Landscape Register (sources of truth) documented — 10 core data types as first pass.

Phase 2 (August–October 2026, P2 live):
- Complete JSON→Postgres migration for remaining state files.
- Redis Streams replaces Postgres LISTEN/NOTIFY for durable async (already planned for P2).
- Full agent output schema library — complete coverage across all 12 agents.
- Holonet v0 schema validation wired into all external integration points.
- Formal data quality gates on all tenant-touching workflows.

Phase 3 (October 2026 onwards, P2 mature → P4 preparation):
- Event sourcing migration for shared agent state (TKT-0104 schema supports this — `agent_state_history` is the seed of the event log).
- Full end-to-end workflow lineage.
- APRA CPG 234/235 formal compliance assessment against the live platform.

**What Option B does NOT require:**
- A new service mesh router (too complex for solo execution — `sessions_send` is retained for synchronous orchestration; the event bus handles async).
- Full event sourcing from day one (this is the Option C trap — too much upfront).
- Kafka (Postgres LISTEN/NOTIFY for P1, Redis Streams for P2 — no Kafka until P4 FSI client has an existing Kafka infrastructure to integrate with).

**The most urgent data architecture action (6-month target):**
Ken's stated priority for within 6 months:
1. Clearly defined data landscape and structure, including explicit sources of truth. ✅ Phase 1 delivers this: Sources of Truth Register + JSON→Postgres migration of core data types.
2. Clear distinctions between source-of-truth data, data in transit, and data for consumption. ✅ Phase 1 delivers this: Three Work Types Rule + event bus separation of write (events) from read (projections).
3. Strong decision traceability via data lineage. ✅ Phase 1 delivers the foundation: decision_lineage table + end-to-end lineage wired into top 4 typed contracts.

**The honest trade-off:** Option B Phase 1 is more work than Option A in the same timeframe. The honest estimate is 2–4 weeks of additional build. The payoff is that Option B Phase 1 delivers a platform where the P2 integration problems are structural solutions, not duct tape. Given that Nexus IS the demo — the proof of concept that AInchors sells — a platform that demonstrates structured, governed integration architecture is a sales asset, not just a technical preference.

**Work Currency Model as a Phase 1 design constraint:** The Work Currency Model Ken has articulated — routing high-currency work to paid models, medium-currency to Ollama Cloud, and low-currency/none to scripts and the integration layer — is not an add-on to Option B. It is the **primary cost justification** for building the integration layer at all. Without a service layer that makes work type observable, you cannot systematically route by currency. Option B's event bus and typed contracts are the structural prerequisite: the event bus separates coordination (T0) from reasoning (T2/T3) by design; typed contracts make currency explicit at the point of request; and the integration layer makes every call path inspectable so medium-currency work can be identified and rerouted to Ollama Cloud rather than Sonnet. Recommend: add Three Work Types Rule enforcement and a Work Currency routing table to Option B Phase 1 scope. Target: reduce Sonnet/Haiku turns by 40–60% within 3 months of Phase 1 completion by reclassifying medium-currency work to T2 (Ollama Cloud) and low/none-currency work to T0 (scripts/systemEvent).

---

## 10. What Ken Must Decide

This paper presents analysis and a recommendation. Final decision is Ken's. The following choices must be made explicitly before build begins:

**Decision 1 (Required before any work starts):** Which option? A, B, or B-phased? If Option B-phased, confirm the Phase 1 scope above is correct or adjust it.

**Decision 2 (If Option B):** Phase 1 scope — confirm or adjust. The critical question is the boundary: which state files migrate to Postgres in Phase 1, and which can wait for Phase 2? Suggested Phase 1 priority: `tickets.json`, cost event log, agent health state, change records, workflow active state. Confirm or substitute.

**Decision 3 (Architecture commitment):** The typed contracts for the top 3–4 cross-agent handoffs need to be designed before the event bus is wired. Ken needs to allocate ~1–2 days to schema design for: Yoda→Forge workflow requests, Yoda→Shield/Lex/Sage review requests, Atlas→Ken option paper outputs. These are the highest-value contract definitions.

**Decision 4 (Phase 2 timing):** Is the Phase 2 scope (August–October 2026) aligned with Ken's capacity post-P2 launch? P2 launch itself will be operationally intensive. Phase 2 should not start until at least 2 weeks post-P2-launch stability.

**Decision 5 (Option C future consideration):** This paper recommends deferring event sourcing to Phase 3 (post-P2 mature). Is Ken comfortable with this deferral? The `agent_state_history` schema in TKT-0104 preserves the migration path. It does not lock out event sourcing — it defers the commitment until the platform has proven stability and capacity allows it.

---

## Appendix: Locked Decisions Reference

The following decisions are approved and must not be contradicted or re-opened by this option paper:

| Decision | Locked By | Summary |
|---|---|---|
| OpenClaw as final platform | IT Strategy | No replatforming. All options extend OpenClaw. |
| Mac Mini HIVE for P1–P2 | MEMORY.md, IT Strategy | OC1 now, OC2-A/B July 2026. No cloud infrastructure in this window. |
| pgvector as vector store | TKT-0104 Decision 1 | Locked. Re-embedding cost is prohibitive after initial load. |
| nomic-embed-text 768-dim | TKT-0104 Decision 2 | Locked. Embedding dimension is baked into schema. |
| RecursiveCharacterTextSplitter 400-600 tokens, 10-20% overlap | TKT-0104 Decision 3 | Locked chunking strategy. |
| Optimistic locking for shared state | TKT-0104 Decision 4 | Schema designed to support event sourcing migration at P4. |
| Shared schema + RLS with tenant_id from P2 day one | TKT-0104 Decision 6 / CHG-0234 | P2 multi-tenant foundation from day one. |
| Postgres session tables P1, Redis P2 | TKT-0104 Decision 8 | No Redis in P1. Migrate at P2. |
| Block Claude for all P2 client workloads | TKT-0046 Decision H | BYOK exception applies. AInchors internal use of Claude continues. |
| P4 consulting-led deployment model | TKT-0046 Decision B | Not self-service. Professional services engagement. |
| Phase structure: P1→P2→P4 | CHG-0234 | P3 = commercial tier within P2. Not a build phase. |
| 4-tier model strategy | MEMORY.md | T0=systemEvent, T1=Gemma4 local, T2=Ollama Cloud, T3=Claude (fallback only). |
| Data sovereignty: client data T0/T1 local only | DS-1 to DS-5, all docs | Non-negotiable. Never Tier 2/3 for client data. |
| BYOK policy | TKT-0046 | P4 clients provide own LLM API keys and own their DPA compliance. |

---

*End of Option Paper.*

*TKT-0162 | Atlas 🏛️ Enterprise Architect | AInchors / Aevlith Technologies | 2026-05-14*
*Status: DRAFT FOR REVIEW — awaiting Ken Mun approval*
