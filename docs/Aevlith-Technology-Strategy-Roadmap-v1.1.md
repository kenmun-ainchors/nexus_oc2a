# Aevlith Technologies — Technology Strategy & Roadmap
## Internal Reference v1.1 — APPROVED ✅

**Classification: INTERNAL — AInchors / Aevlith Technologies**
**Status: APPROVED ✅ by Ken Mun (CTO) — 2026-07-09**
**Author: Atlas 🏛️ — Enterprise Architect**
**Reviewed by: Yoda 🟢**
**Approved by: Ken Mun (CTO) — 2026-07-09**
**Date: 2026-07-09 | Platform Day ~76**
**CHG-0853 (Promotion to APPROVED v1.1)**

---

> **Supersedes:** Aevlith-Technology-Strategy-Roadmap-v1.0-Internal.md (2026-05-14, approved by Ken Mun). This document is a **delta refresh** as part of the Holocron Refresh project (P006, CHG-0852). All material changes are catalogued in Appendix D.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Strategic Context](#2-strategic-context)
3. [Technology Principles](#3-technology-principles)
4. [Current State — Platform Maturity (Day ~76)](#4-current-state--platform-maturity-day-76)
5. [Architecture Direction — Option B Phased](#5-architecture-direction--option-b-phased-approved-2026-05-14-chg-0308)
6. [P1–P4 Technology Roadmap](#6-p1p4-technology-roadmap)
7. [Model & Cost Strategy](#7-model--cost-strategy)
8. [OKRs & KRI Alignment](#8-okrs--kri-alignment)
9. [Governance & Security](#9-governance--security)
10. [Roadmap Summary](#10-roadmap-summary)

---

## 1. Executive Summary

Aevlith Technologies designs, builds, and operates Nexus — the agentic AI operations platform powering AInchors. As of Platform Day ~76 (2026-07-09), Nexus is significantly more mature than at v1.0 (Day 20): **14 active agents**, ITSM-grade operations (850+ CHG records), **Postgres SSOT-first architecture** live, **CREST v1.3** governance framework approved, and the **OC2 hardware** arrived for commissioning.

The most significant architectural shift since v1.0 is the **model migration from Anthropic Claude to Ollama Cloud** (kimi-k2.7-code, deepseek-v4-pro, deepseek-v4-flash, gemma4:31b-cloud). This was not a single decision but an organic evolution driven by cost, capability, and independence considerations. The platform now operates entirely on Ollama Cloud models for primary inference, with no agent relying on Anthropic Claude as its primary model.

Postgres is live as the canonical state store (SSOT-first adopted 2026-05-23). The `state_changes` table is the authoritative CHG record. CREST v1.3 (approved 2026-06-20, CHG-0680) governs capability-based multi-model routing with Sage-as-Judge.

**P2 target: August 2026.** OC2-A/B commissioning is the critical path. Phase 1 architectural foundations (Postgres, event bus, Work Currency Model) are substantially complete. Remaining gaps include RAG pipeline, PII scanner, typed contracts, and full JSON migration.

**Key facts at a glance:**
- Platform: OC1 Mac Mini M4 24GB, Melbourne, production. OC2-A/B (Mac Mini M4 Pro 48GB × 2) **arrived** — commissioning ~27 July 2026.
- Agents: **14 active** (up from 12). Ahsoka formalised. Krennic parked. Luthen queued for P2 build (not yet registered in agent_registry).
- Postgres: **LIVE** — SSOT-first architecture. CHG-0845 hardening complete.
- Model tier: **Ollama Cloud** (kimi-k2.7-code, deepseek-v4-pro, deepseek-v4-flash, gemma4:31b-cloud). Anthropic Claude deprecated as primary.
- Governance: **CREST v1.3** (CHG-0680). `model_policy.json v3.0` (CHG-0812).
- CHG records: **850+** (up from 230+).
- Cost: Current model cost structure reflects Ollama Cloud pricing (fixed ~$100/mo base + variable API usage). No longer Anthropic pay-per-token dependency.
- Data sovereignty: unchanged — client data T0/T1 local ONLY. Non-negotiable.

---

## 2. Strategic Context

### 2.1 Company Structure

AInchors is the market-facing brand — an AI-native consulting, training, and managed operations business targeting SME founders in Australia, Malaysia, and the GCC. Aevlith Technologies is the internal technology and IP company that designs, builds, and operates Nexus. Aevlith is invisible at P1-P3; it surfaces as the product brand at P4 only when enterprise/FSI clients require a distinct vendor identity.

The practical arrangement: AInchors wins and serves clients. Aevlith holds the platform IP, manages infrastructure, and operates the agent roster. Every dollar of consulting or training revenue funds Aevlith's platform build.

**Founders:**
- **Ken Mun (CTO):** Platform builder, enterprise architect, consulting delivery lead (Ahsoka). Technical authority.
- **Angie Foong (CEO):** Business development, marketing, KL team management, GTM execution.

### 2.2 Three Business Pillars

| Pillar | Revenue Weight (Year 1) | Lead Agent | Status |
|---|---|---|---|
| Training (workshops L1/L2/L3) | ~80% | Aria / Spark / Mon Mothma | Active |
| Consulting — AI Ops Jumpstart (Ahsoka) | ~20% | Ahsoka | Active |
| Technology / Nexus (managed platform) | Future | Yoda / Atlas / Thrawn | Building |

The training pillar is the commercial engine for Year 1. Workshop participants are the primary funnel for Jumpstart consulting engagements. Jumpstart clients are the primary funnel for Nexus-managed platform clients (P2 SaaS). Every platform investment must be traceable to one of these three pillars and to the validated OKRs.

### 2.3 Commercial Trajectory

| Phase | Target | Timeline | Business Model |
|---|---|---|---|
| P1 | Internal / proof-of-concept | Now → Aug 2026 | Training revenue funds platform build |
| P2 | SaaS — 2-3 SME pilot clients | Aug 2026 | Managed platform subscriptions (Standard / Company tiers) |
| P3 | Commercial tier expansion (within P2) | Within P2 | Company/multi-agent unlock — feature flag, ROI-gated |
| P4 | Enterprise / FSI | Year 2-3 | Physical deployment, APRA compliance, BYOK, HSM |

P3 is a commercial tier — not a separate infrastructure build phase (CHG-0234). Multi-tenant foundation is designed from P2 day one; P3 is a feature unlock within that foundation.

---

## 3. Technology Principles

These seven principles govern all architectural and platform decisions at Aevlith Technologies. They are immutable within the P1-P4 horizon unless explicitly reviewed by Ken.

### TP-1: Business-Outcome-First

Every platform capability must map to a business pillar (Training / Consulting / Technology) and an OKR. No capability is approved without a business owner and a concrete use case. Architecture exists to serve revenue and client outcomes — not the other way around. If a build item cannot be linked to C1, T1, S1, X1, or G1, it requires explicit CTO sign-off to proceed.

### TP-2: Governance-by-Design

The Sanctum (Shield, Lex, Sage) and Warden are non-negotiable governance infrastructure — not optional modules. Security, compliance, and quality reviews are embedded at every layer. No external output bypasses Sanctum. Governance is a visible differentiator for AInchors, not an internal overhead. Warden monitors all agents at 15-minute intervals; drift is surfaced immediately.

### TP-3: Data Sovereignty — Non-Negotiable

Client data never crosses to Tier 2/3 cloud APIs. Tier 0/1 (local or no-LLM) handles all client workloads. Tier 2/3 (Ollama Cloud, any external model) handles AInchors-internal operations only. This is enforceable at the routing layer and will be enforced at the Postgres schema and access control layers from P2. Anthropic DPA verification is required before any client data touches Claude (Decision H, TKT-0046).

### TP-4: Shipping vs Generality (Context-Dependent)

For training and consulting support features: ship for the immediate use case. Generalise only when 2-3 clients have pulled the same pattern. For security, governance, multi-client isolation, data models, and integration contracts: design for multi-year, multi-client reuse from the start. This is not a contradiction — it is a deliberate prioritisation of what must be right and what can evolve.

### TP-5: FinOps-First (Work Currency Model)

Agentic AI has a 100-1,000x cost multiplier potential per multi-step chain versus single API calls. Every agent workflow must have token budget limits, workflow cost caps, and escalation gates. The Work Currency Model (see Section 7.1) is the primary FinOps instrument. The four currencies — High, Medium, Low, None — map directly to model tiers. Cost is a design constraint, not an afterthought.

### TP-6: ITSM-Grade Operations

Change records (CHG-NNNN), incident management, SLA tracking, and asset registries are native to Nexus operations — not retrofits. All structural changes require a CHG record before execution. All incidents are logged in incident-log.sh with timestamp, severity, and resolution. Ticket discipline (ticket.sh) is non-negotiable. This is the proof of concept: AInchors running ITSM-grade AI operations is itself the demo.

### TP-7: OpenClaw-Committed (No Replatforming)

OpenClaw is the final platform choice for P1-P4. Architectural decisions extend the OpenClaw paradigm rather than fighting it. No replatforming proposals will be evaluated. Agents, sessions, skills, and crons are all OpenClaw-native. The integration layer (Holonet v0, Phase 2) will be built as an OpenClaw-compatible service layer, not a replacement.

---

## 4. Current State — Platform Maturity (Day ~76, 2026-07-09)

### 4.1 Infrastructure

| Component | Spec | Status | Notes |
|---|---|---|---|
| OC1 | Mac Mini M4 24GB, Melbourne | ✅ Production | Always-on, single node |
| OC2-A | Mac Mini M4 Pro 48GB | **✅ ARRIVED** — commissioning in progress | HA Primary. Commission ~27 Jul 2026. |
| OC2-B | Mac Mini M4 Pro 48GB | **✅ ARRIVED** — awaiting commissioning | HA Standby. |
| Tailscale mesh | Zero-trust overlay | ✅ Live | `ainchorsoc2as-mac-mini-1.tailfc3ed1.ts.net` |
| MinIO | 4 buckets, local NVMe | ✅ Live | URL pattern: Tailscale FQDN:9000 |
| Google Drive | Human docs, EA outputs | ✅ Live | `kenmun@ainchors.com` |
| Notion / Holocron | Agent Knowledge Base (AKB) | ✅ Live | **3-DB architecture** (Notion). SSOT for tickets + CHG — now secondary to PG. |
| Colima / Docker | Container workloads | ✅ Live | Replaces Docker Desktop |
| Postgres | State database | **✅ LIVE** | SSOT-first adopted 2026-05-23. 5-tier schema. CHG-0845 hardened. |
| DuckDuckGo | Web search provider | ✅ Live | CHG-0844 approved. |

**Updated v1.1:** Postgres upgraded from "❌ Not deployed" to "✅ LIVE". OC2 upgraded from "⏳ Arriving" to "✅ ARRIVED — commissioning in progress." Notion now secondary to PG for structured state.

### 4.2 Agent Roster

| Agent | ID | Role | Model Tier | Stream |
|---|---|---|---|---|
| Yoda 🟢 | main | Lead Orchestrator | kimi-k2.7-code → deepseek-v4-pro → deepseek-v4-flash | Technical + Platform |
| Aria 🔵 | business | Business Lead | kimi-k2.7-code → deepseek-v4-pro → deepseek-v4-flash | Business |
| Spark ✨ | social | Social & Marketing | deepseek-v4-flash → gemma4:31b-cloud → deepseek-v4-pro | Business |
| Luthen 🧠 | luthen | Marketing Intelligence | deepseek-v4-pro → gemma4:31b-cloud → kimi-k2.6 | Business (NEW) |
| Atlas 🏛️ | architect | Enterprise Architect | deepseek-v4-flash → gemma4:31b-cloud → kimi-k2.6 | Technical |
| Thrawn | platform-arch | Platform Architect | deepseek-v4-flash → gemma4:31b-cloud → kimi-k2.6 | Technical |
| Lando 🟡 | biz-process | BPM Specialist | deepseek-v4-pro → gemma4:31b-cloud → kimi-k2.6 | Business |
| Forge 🏗️ | infra | Infra & SRE | deepseek-v4-flash → gemma4:31b-cloud → kimi-k2.6 | Technical |
| Mon Mothma 🌟 | change-mgt | Change Management | deepseek-v4-pro → gemma4:31b-cloud → kimi-k2.6 | Business |
| Ahsoka 🤍 | ahsoka | AI Consulting | deepseek-v4-pro → gemma4:31b-cloud → kimi-k2.6 | Consulting |
| Warden 🔍 | governance | Compliance Monitor | gemma4:31b-cloud → deepseek-v4-pro → kimi-k2.6 | Governance |
| Shield 🛡️ | security | Security Review | gemma4:31b-cloud → deepseek-v4-pro → kimi-k2.6 | Governance |
| Lex ⚖️ | legal | Legal & Compliance | gemma4:31b-cloud → deepseek-v4-pro → kimi-k2.6 | Governance |
| Sage 🧪 | qa | QA & Accuracy | gemma4:31b-cloud → deepseek-v4-pro → kimi-k2.6 | Governance |

**14 active agents** across 4 streams. Key additions since v1.0: **Luthen** (Marketing Intelligence — new agent). **Ahsoka** formalised as a named agent (was Ken-delivered in P1). **Krennic** (platform engineering specialist) is parked — not yet activated.

**Model migration note:** The entire model stack has changed since v1.0. All agents previously used Anthropic Claude (Sonnet/Haiku/Opus) as primary models. The platform now runs entirely on Ollama Cloud models. This is not a single decision but an organic evolution — see Section 7 for details.

### 4.3 Operational Maturity

| Metric | Current State (v1.1) | Change from v1.0 |
|---|---|---|
| Production scripts | 52+ | Stable |
| Automated crons | 20+ | Stable |
| CHG records | **850+** | Up from 230+ |
| Incident logs | Live (incident-log.sh) | Stable |
| Auto-heal | 01:00 AEST, 19 checks | Stable |
| Warden monitoring | 15-min intervals | Stable |
| Availability (historical) | 97.46%+ | Stable |
| Cost model | **Ollama Cloud** (fixed + variable) | Changed from Anthropic pay-per-token |
| Daily cost cap | $150/day | Stable |
| Postgres | **LIVE** | New — was not deployed |
| CREST | **v1.3** (CHG-0680) | New |
| Model routing | **PG-first, capability-based** (CHG-0812) | New — replaced Kimi Safety Net |
| Web search | **DuckDuckGo** (CHG-0844) | New |

### 4.4 Platform Maturity by TOGAF Domain

| Architecture Domain | v1.0 Maturity | v1.1 Maturity | Key Changes |
|---|---|---|---|
| Business Architecture | L3 — Functional | L3 — Functional | Luthen added. Ahsoka formalised. |
| Data Architecture | **L1 — Ad hoc** | **L2 — Defined** | Postgres LIVE. SSOT-first adopted. CHG-0845 hardened. P003 active. |
| Application Architecture | L3 — Functional | L3 — Functional | Event bus built. Typed contracts not yet implemented. |
| Technology Architecture | L2 — Emerging | **L3 — Functional** | Postgres live. CREST v1.3. OC2 hardware arrived. |
| Security & Governance Architecture | L3 — Functional | L3 — Functional | CREST v1.3. S7 still pending OC2. |

**Most critical progress:** Data Architecture moved from L1 (Ad hoc) to L2 (Defined). This was the primary blocker flagged in v1.0. The Option B decision is materially advancing.

**Remaining critical gap:** Data Architecture still needs to reach L3 (Integrated) before P2. RAG pipeline, PII scanner, and complete JSON migration are the key milestones.

---

## 5. Architecture Direction — Option B Phased (APPROVED 2026-05-14, CHG-0308)

### 5.1 The Three Structural Concerns

Ken identified three structural concerns that, left unaddressed, become unmanageable at P1-P4 scale. These drove the Option B decision:

**Concern 1 — Data Architecture:** ✅ **Substantially addressed.** Postgres is live as the canonical state store. SSOT-first adopted. CHG records in PG. JSON migration in progress via P003. The concern is no longer critical — remaining gaps are manageable.

**Concern 2 — Integration Architecture:** ⚠️ **Partially addressed.** Postgres LISTEN/NOTIFY event bus is built. Typed contracts not yet implemented. The LinkedIn dual-post class is partially addressed via the event bus, but full typed contracts (TKT-0169) remain to be built.

**Concern 3 — Cost and Sustainability:** ✅ **Substantially addressed.** The model migration from Anthropic Claude to Ollama Cloud has eliminated the per-token cost dependency for primary inference. The Work Currency Model is operational. Remaining optimisation: routing "Low" and "None" currency work to T0/T1.

### 5.2 Decision: Option B Phased (Retained — Still Holding)

| Option | Description | Score | Decision |
|---|---|---|---|
| A | Incremental hardening — evolve current architecture in place | 3.55/5 | ❌ Rejected |
| **B** | **Redesign data + integration layers, keep OpenClaw and agent model** | **4.70/5** | **✅ SELECTED — CHG-0308 — Still the right decision** |
| C | Radical platform refactor — rebase the foundation | 3.35/5 | ❌ Rejected |

**Assessment (v1.1):** Option B was the correct decision. Postgres is live, event bus is live, and the platform is measurably more mature. The decision remains the right one for P2 readiness.

### 5.3 Work Currency Model

The Work Currency Model is the primary cost justification for building a proper integration layer. It classifies all platform work into four currencies and routes each to the appropriate execution tier.

**v1.1 update:** The model tier mapping has been updated to reflect the new Ollama Cloud stack:

| Currency | Work Type | Examples | Execution Tier | Model |
|---|---|---|---|---|
| High | Reasoning, design, judgment, planning, synthesis | Architecture decisions, proposal drafting, complex analysis | T3 | deepseek-v4-pro / kimi-k2.7-code / gemma4:31b-cloud |
| Medium | Template content, classification, summarisation, structured generation | Content generation, ticket triage, categorisation | T2 | deepseek-v4-flash / kimi-k2.6 |
| Low | CRUD, state writes, status updates, simple lookups | Ticket status updates, file writes, log appends | T1/T0 | Gemma4:26b local (post-OC2) / systemEvent |
| None | System calls, file I/O, API calls, non-LLM processing | Shell scripts, database writes, API integrations | T0 | Script / integration layer |

**Target:** 40-60% LLM turn reduction within 3 months of Phase 1 completion (by ~September 2026). The model migration to Ollama Cloud has already reduced per-token cost dependency. The Work Currency Model will further optimise routing.

### 5.4 Structural Fix Timeline

| Milestone | Target | What Changes | Status |
|---|---|---|---|---|
| Risk reduced | Sprint 4 end, 25 May 2026 | Three Work Types Rule + SoT Register operational | ✅ **ACHIEVED** |
| Architecturally fixed | Sprint 6 end, ~8 June 2026 | Event bus + JSON→Postgres migration top 5 complete | ⚠️ **PARTIAL** — Event bus live, JSON migration ongoing |
| Phase 1 complete | August 2026 | All WP1-WP8 delivered, OC2 commissioned, Cloudflare Tunnel live | 🔄 **IN PROGRESS** |

### 5.5 Phase 1 Work Packages

| WP | Title | Status | Notes |
|---|---|---|---|
| WP1 | Postgres Deploy + 5-Tier Schema | ✅ **ACHIEVED** | TKT-0164 delivered |
| WP2 | Three Work Types Rule + Work Currency Routing | ✅ **ACHIEVED** | TKT-0165 operational |
| WP3 | Sources of Truth Register — 10 Core Data Types | ✅ **ACHIEVED** | TKT-0166 documented |
| WP4 | JSON→Postgres Migration — Top 5 State Files | ⚠️ **IN PROGRESS** | P003 active. CHG-0845 hardened. |
| WP5 | Postgres LISTEN/NOTIFY Event Bus | ✅ **ACHIEVED** | TKT-0168 delivered |
| WP6 | Typed Agent Contracts — 4 Cross-Agent Handoffs | ❌ **NOT YET BUILT** | TKT-0169 pending |
| WP7 | PII Scanner on Document Ingestion Pipeline | ❌ **NOT YET BUILT** | TKT-0170 pending |
| WP8 | pgvector + nomic-embed-text RAG Pipeline | ❌ **NOT YET BUILT** | TKT-0171 pending |

**KRI dashboard:** https://www.notion.so/Nexus-Architecture-KRI-Dashboard-Option-B-Implementation-360c182953ff816a9d1dd5c104ca6cd1

---

## 6. P1–P4 Technology Roadmap

### 6.1 P1 — Internal Single-Tenant (Current → P2 Launch)

**Objective:** Harden Nexus as a governance-first, production-grade agentic AI operations platform for AInchors. Fix the data, integration, and cost architecture before P2.

#### Sprint 4 (May 19-25) — COMPLETED
- TKT-0141: CLI-Anything security controls — ✅
- TKT-0142: SKILL.md poisoning protection — ✅
- TKT-0165: Three Work Types Rule — ✅
- TKT-0166: Sources of Truth Register — ✅

#### Sprint 5 (May 26-Jun 1) — COMPLETED
- TKT-0164: Postgres deploy + 5-Tier Schema — ✅
- TKT-0167: JSON→Postgres migration — ⚠️ In progress
- TKT-0168: Event bus — ✅
- TKT-0108: Document generation pipeline — TBD
- TKT-0130: QBR ceremony — ✅

#### Sprint 6 (Jun 2-8) — COMPLETED
- TKT-0169: Typed contracts — ❌ Not yet built
- TKT-0170: PII scanner — ❌ Not yet built
- TKT-0150: DR Playbook — TBD

#### Sprint 7 (Jun 9-15) — COMPLETED
- TKT-0171: RAG pipeline — ❌ Not yet built

#### Sprint 9-10 (July 2026) — IN PROGRESS
- OC2-A/B arrival (Est. Jul 6-13) — **HARDWARE ARRIVED** ✅
- Commissioning ~27 July — 🔄 In progress
- HA HIVE cluster activation — 🔄 Pending
- Local Gemma4:26b inference — 🔄 Pending OC2
- Aria and other agents migrated to HIVE — 🔄 Pending
- NAS encryption (S7) — 🔄 Pending OC2

**P1 Exit Criteria:**
- WP1-WP5 complete (Postgres, Three Work Types Rule, SoT Register, JSON migration, Event Bus) — ⚠️ WP4 in progress
- OC2-A/B commissioned and HA validated — 🔄 In progress
- Cloudflare Tunnel live — ❌ Not yet
- DR Playbook documented and tested — TBD
- Security controls TKT-0141/0142 verified — ✅
- Cost trajectory showing Work Currency Model impact — ⚠️ Monitoring

### 6.2 P2 — SaaS Multi-tenant (August 2026)

**Objective:** Open Nexus to 2-3 SME pilot clients with full data sovereignty, per-client isolation, and production-grade managed operations.

**Architecture requirements — multi-tenant from day one:**
- `tenant_id` on all Postgres tables, enforced via Row-Level Security (RLS)
- Optimistic locking on all shared state mutations
- Access control matrix: per-tenant agent permissions
- Per-client config separation, logging separation, Sanctum governance workflows
- No co-mingling of AInchors-internal data and client data (DS-3)

**Platform deliverables:**
- WP9: Redis session state (replaces Postgres session tables at P2 scale)
- WP10: Full multi-tenant RLS + `tenant_id` enforcement on all tables
- WP11: Per-tenant knowledge bases (pgvector two-tier: shared + tenant-specific)
- WP12: Cloud KMS (AWS KMS) for secret management
- WP13: Holonet v0 — REST/webhook integration layer (OC2-gated)
- WP14: Citadel v0 — client portal (Notion-based at P2, custom at P4)
- WP15: Complete JSON→Postgres migration (all remaining state files)
- WP16: Full agent output schema library (all 14 agents typed)
- WP17: Formal data quality gates on tenant-touching workflows

**KL team integration:**
- 4-5 headcount, Malaysia
- Cloudflare Access for role-scoped IAM
- KL team scoped to business stream only (Aria, Spark, Luthen, Mon Mothma, Lando)
- No KL access to platform architecture, security controls, or client data

**Commercial tiers at P2:**
- Standard: single agent, AInchors-managed, Tier 0/1 client workloads
- Company (P3 unlock): multi-agent, company-wide context, ROI-gated feature flag activation

**P2 Exit Criteria:**
- 2+ live SME clients with data sovereignty verified
- Tier 1 (Gemma4:26b on OC2) handling all client workloads — no client data on cloud models
- Multi-tenant RLS live and tested
- Warden monitoring all client agent instances
- Citadel v0 client portal operational
- Holonet v0 integration layer handling at least 3 external integration patterns

### 6.3 P3 — Commercial Tier (Within P2 Foundation)

P3 is **not** a separate infrastructure build phase. It is a commercial tier unlocked within the P2 multi-tenant foundation (CHG-0234).

**P3 unlock:**
- Company/multi-agent feature flag activated per client
- Shared context and data across an entire client organisation
- Full agent roster deployment (vs. single-agent Standard tier)
- Cross-agent workflow orchestration with typed contracts
- Enabled on demand, ROI-gated per client engagement

No additional infrastructure build is required for P3. The multi-tenant foundation, per-client isolation, and event bus built in P2 are sufficient. P3 is a pricing and packaging decision, not an engineering milestone.

### 6.4 P4 — Enterprise / FSI (Year 2-3)

**Objective:** Package Nexus as a physically deployable, APRA-compliant enterprise AI operations platform for FSI and large enterprise clients.

**Trigger:** First FSI enterprise client engagement (or equivalent regulatory requirement).

**Platform deliverables:**
- WP23: HSM-backed Customer Master Keys (CMK) — physical HSM or cloud HSM with client control
- WP24: Physical/in-house deployment package (hardware spec, software stack, network diagram, handover checklist)
- WP25: Full APRA CPG 234/235 compliance suite
- WP26: Kafka connector for FSI integration (if required by client)
- WP27: WORM archive — S3 Object Lock COMPLIANCE mode, 7-year retention
- WP28: Penetration testing + quarterly vulnerability scanning program

**Compliance requirements:**
- APRA CPG 234 (information security) full controls
- APRA CPG 235 (data management) full controls
- Hash-verified WORM audit log (7-year retention)
- Physical/in-house deployment for air-gapped requirements
- Full end-to-end workflow lineage (TRIGGER-14 — post-P2 stable)
- Event sourcing migration from optimistic locking (TRIGGER-14)

**Brand:** Aevlith Technologies surfaces as the product brand at P4. Prior phases (P1-P3), Aevlith is invisible — the product is AInchors Nexus.

**BYOK policy at P4:** Enterprise clients supply their own LLM API keys. They own their DPA compliance. Client data never touches AInchors model subscriptions. Model risk is fully transferred to the client.

---

## 7. Model & Cost Strategy

### 7.1 4-Tier Model Architecture (Updated for v1.1)

**v1.1 update:** The model stack has fundamentally changed since v1.0. The platform has migrated from Anthropic Claude (Sonnet/Haiku/Opus) to Ollama Cloud models. This was not a single approved decision but an organic evolution driven by:

1. **Cost independence:** Ollama Cloud fixed pricing (~$100/mo) vs Anthropic pay-per-token
2. **Capability maturity:** deepseek-v4-pro, kimi-k2.7-code, and gemma4:31b-cloud proved adequate for T3 reasoning
3. **Pipeline simplification:** Single provider (Ollama) vs dual provider (Anthropic + Ollama)

| Tier | Models | Primary Use | Unit Cost |
|---|---|---|---|
| T0 | systemEvent, shell scripts, non-LLM APIs | CRUD, system calls, file I/O, deterministic operations | $0 |
| T1 | Gemma4:26b local (OC2+) | Client workloads, background batch, AInchors-internal Low-currency work | $0 (post-OC2) |
| T2 | Ollama Cloud: kimi-k2.6, deepseek-v4-flash | Medium-currency AInchors-internal: content, classification, summarisation | Fixed ~$100/mo |
| T3 | Ollama Cloud: kimi-k2.7-code, deepseek-v4-pro, gemma4:31b-cloud | High-currency reasoning, design, planning, judgment | Variable (API usage) |

**Routing rule (CHG-0812 — capability-based, PG-first):**
- Model selection is resolved by `model-policy-query.sh` (PG-first)
- Capability requirements of the task determine the model tier
- No fixed "primary → fallback" chain — dynamic routing per task type
- Supersedes the old Kimi Safety Net (CHG-0270)

**Client data routing rule (non-negotiable — unchanged):**
- All client workloads → T0/T1 ONLY. No client data on T2/T3.
- At P2 launch: Gemma4:26b (OC2) handles all client inference. Cloud models never see client data.

### 7.2 Cost Management

| Parameter | Value | Notes |
|---|---|---|
| Daily cap | $150/day | Stable |
| Model provider | Ollama Cloud | Changed from Anthropic. Fixed base + variable API usage. |
| Monthly AInchors target (post-Phase 1) | ~$3,000/mo | Estimate — model migration may reduce costs vs Anthropic. |
| KL team cost allocation | Separate tracking | Business stream only. |

**Cost driver analysis (v1.1 update):** The model migration from Anthropic to Ollama Cloud has structurally changed the cost profile. The per-token cost dependency is eliminated for primary inference. The remaining cost driver is Ollama Cloud API usage for T3 models. Variable costs are now driven by deepseek-v4-pro and gemma4:31b-cloud usage, not Anthropic tokens.

### 7.3 P2 Cost Model

At P2, client workloads fully migrate to T1 (Gemma4:26b on OC2). The client cost model becomes:
- Infrastructure: OC2 hardware (amortised — near-zero per-client marginal cost)
- T2 fixed: ~$100/mo for AInchors-internal business stream
- T3 variable: AInchors-internal planning, design, and orchestration only — Ollama Cloud API costs
- No client data exposure to cloud models: Gemma4:26b handles all client inference

This enables a sustainable managed service margin at P2 without proportional model cost growth per client.

---

## 8. OKRs & KRI Alignment

### 8.1 Technology OKRs (6-12 Months)

**Objective X1 — Harden Nexus for AInchors + first SME tenants with full governance and observability:**
- KR1: >99% uptime for Nexus on OC1 over a rolling 90-day window
- KR2: Per-client environment isolation for at least 2 SME clients (config, logging, Sanctum)
- KR3: Warden monitors all agents every 15 minutes with <0.5% missed intervals over a 30-day period
- KR4: OC2-A/B deployed and failover/HA validated before 12-month mark

**Objective X2 — Align Aevlith architecture with P2/P4 roadmap:**
- KR1: Atlas + Yoda produce P2/P4 architecture roadmap tying platform capabilities to OKRs ✅ **DONE** (TKT-0162, v1.0, v1.1)
- KR2: All major architecture Epics tagged with pillar + OKR IDs
- KR3: At least 2 internal architecture reviews per quarter

### 8.2 Architecture KRIs (Live Dashboard)

**Dashboard:** https://www.notion.so/Nexus-Architecture-KRI-Dashboard-Option-B-Implementation-360c182953ff816a9d1dd5c104ca6cd1
**Managed by:** Yoda 🟢 (live updates at each sprint review)
**Last updated:** 2026-07-09 (this document)

| KRI | Baseline (Day 20) | v1.1 Status | Phase 1 Target | Phase 2 Target |
|---|---|---|---|---|
| Postgres deployed | ❌ | **✅** | ✅ | ✅ |
| State files on Postgres | 0 | **5+** | 5 | 15+ |
| Event bus (LISTEN/NOTIFY) live | ❌ | **✅** | ✅ | ✅ |
| Typed agent contracts | 0 | **0 (not built)** | 4 | 10+ |
| LLM-for-CRUD eliminated | 0% | **~40%** | 40% | 80% |
| Sonnet/Haiku turns reduced | 0% | **100% (migrated)** | 40-60% | 70%+ |
| SoT Register complete | ❌ | **✅** | ✅ | ✅ |
| PII scanner live | ❌ | **❌** | ✅ | ✅ |
| RAG pipeline live | ❌ | **❌** | ✅ | ✅ |
| Multi-tenant RLS live | ❌ | **❌** | ❌ | ✅ |

**Note:** The "Sonnet/Haiku turns reduced" KRI is now 100% achieved — the platform no longer uses Sonnet or Haiku. This KRI should be redefined for the new model stack.

### 8.3 Locked Architectural Decisions

The following decisions are locked for P1-P4 and require CTO-level review to change:

| Decision | Reference | v1.1 Status |
|---|---|---|
| pgvector + nomic-embed-text 768-dim for RAG | TKT-0104 | ✅ HOLDING |
| Shared schema + RLS from P2 day one | CHG-0234 | ✅ HOLDING |
| OpenClaw as final platform — no replatforming | TP-7 | ✅ HOLDING |
| Mac Mini HIVE for P1-P2 | TRIGGER-01 | ✅ HOLDING |
| Client data: T0/T1 local ONLY | DS-1 to DS-5 | ✅ HOLDING |
| BYOK policy for P4 FSI clients | TKT-0046 Decision H | ✅ HOLDING |
| Block Claude for P2 client workloads | TKT-0046 Decision H | ✅ HOLDING (applies to all cloud models) |
| P3 = commercial tier within P2 (not a build phase) | CHG-0234 | ✅ HOLDING |
| Event sourcing deferred to Phase 3 (TRIGGER-14) | TKT-0162 approved | ✅ HOLDING |
| Option B Phased — redesign data + integration | CHG-0308 | ✅ HOLDING (correct decision) |
| **CREST v1.3 — capability-based multi-model routing** | **CHG-0680** | **✅ NEW** |
| **model_policy.json v3.0 — PG-first model dispatch** | **CHG-0812** | **✅ NEW** |
| **PG SSOT-first architecture** | **Platform decision** | **✅ NEW** |
| **DuckDuckGo as web search provider** | **CHG-0844** | **✅ NEW** |

---

## 9. Governance & Security

### 9.1 Governance Framework

Nexus operates under the AI Charter v1.0 and Agent Governance Framework v1.0 (both approved). The governance model is hierarchical:

| Tier | Role | Agents |
|---|---|---|
| T0 — Orchestration | Lead orchestrator, strategic routing | Yoda 🟢 |
| T1 — Stream Leads | Business and technical stream leads | Aria 🔵 |
| T2 — Compliance Monitor | Continuous drift and compliance monitoring | Warden 🔍 |
| T3 — Specialists | Domain experts, execution agents | All named agents |
| T4 — Sanctum | External output review and approval | Shield 🛡️, Lex ⚖️, Sage 🧪 |

**HITL (Human-in-the-Loop) framework — 5 tiers:**
Every external output passes human checkpoints. The Sanctum (Shield → Lex → Sage) gates all client-facing and external outputs. No bypass, no self-approval, no exceptions.

**Sanctum protocol (non-negotiable):**
All external outputs → Shield (security review) → Lex (legal/compliance review) → Sage (QA/accuracy review, CREST Judge role). Average target turnaround: <24h training/marketing content, <72h proposals.

### 9.2 Security Controls S1-S7

| Control | Requirement | Status |
|---|---|---|
| S1 | OpenClaw ≥ v2026.5.5 | ✅ Live |
| S2 | Port 18789 loopback only — never public | ✅ Live |
| S3 | No ClawHub skills on production | ✅ Live |
| S4 | Least-privilege per agent (CHG-0176) | ✅ Live |
| S5 | No hardcoded credentials anywhere in workspace | ✅ Live |
| S6 | All changes CHG-logged + Warden-monitored | ✅ Live (850+ CHG records) |
| S7 | NAS encrypted | ⏳ Post-OC2 (commissioning ~27 Jul 2026) |

### 9.3 Data Sovereignty Controls (DS-1 to DS-5)

These controls are technically enforced at P2 via Postgres RLS and routing rules. At P1, they are operationally enforced by agent instruction and monitored by Warden.

| Control | Rule |
|---|---|
| DS-1 | Client data never leaves OC1. T0/T1 local ONLY for all client processing. |
| DS-2 | Client data never routes to T2/T3 cloud APIs (Ollama Cloud, any external model). |
| DS-3 | No co-mingling of client data and AInchors-internal data. |
| DS-4 | BYOK exception at P4: client supplies own LLM API keys and accepts DPA compliance. |
| DS-5 | Anthropic DPA verification required before any client data touches Claude (Decision H, TKT-0046). |

**Privacy Act (Australia) compliance:**
All client data handling must comply with APP 11 (cross-border data transfer). Gemma4:26b local inference (OC1/OC2) satisfies this requirement. Cloud model routing for client data does not.

### 9.4 Warden Monitoring

Warden 🔍 runs at 15-minute intervals, monitoring all 14 agents for:
- Model routing compliance (is agent using correct tier?)
- HITL gate adherence (is Sanctum bypassed?)
- CHG record completeness (does every structural change have a CHG?)
- Cost anomaly detection (per-agent spend spike alerts)
- Data sovereignty violations (T2/T3 receiving client data)

Warden reports go to Yoda 🟢 and are logged to `state/warden-compliance-state.json`. Consecutive clean runs are tracked. Any violation triggers immediate escalation to Ken.

---

## 10. Roadmap Summary

| Quarter | Phase | Key Deliverables | Status |
|---|---|---|---|
| Q2 2026 (May-Jun) | P1 Architecture | Three Work Types Rule ✅, SoT Register ✅, Postgres ✅, Event Bus ✅, Typed Contracts ❌, PII Scanner ❌, RAG Pipeline ❌, Cloudflare Tunnel ❌, Security TKT-0141/0142 ✅, DR Playbook ❌ | **Partial** |
| Q3 2026 (Jul-Aug) | P1 Close + P2 Launch | OC2-A/B commission (TRIGGER-01) **— hardware arrived** 🔄, HA HIVE, Gemma4:26b T1 live, Multi-tenant RLS, Citadel v0, Holonet v0, first SME clients onboarded | **In progress** |
| Q4 2026 (Sep-Oct) | P2 Mature | Client portal fully live, Beacon/Datapad observability dashboard, Holocron API-first retrieval, SLO reporting, Work Currency Model validated | **Plan** |
| Q1 2027 | P2 Stable + P4 Prep | Event sourcing design (TRIGGER-14), APRA CPG 234/235 control mapping, FSI packaging, P3 commercial tier unlocked | **Plan** |
| 2027+ | P4 Enterprise / FSI | Physical deployment package, APRA full compliance, HSM-backed CMK, WORM archive (7-year), first FSI client engaged, Aevlith Technologies brand surfaces | **Long-term** |

---

## Appendix A — Sprints at a Glance (Updated)

| Sprint | Dates | Theme | Status |
|---|---|---|---|
| Sprint 3 | May 12-18 | Security + Observability | ✅ Completed |
| Sprint 4 | May 19-25 | Work Currency + SoT | ✅ Completed |
| Sprint 5 | May 26-Jun 1 | Postgres + Data Layer | ✅ Completed |
| Sprint 6 | Jun 2-8 | Integration + Contracts | ⚠️ Partial (event bus ✅, contracts ❌) |
| Sprint 7 | Jun 9-15 | RAG + Phase 1 Close | ⚠️ Partial (RAG ❌, KRI validation ✅) |
| Sprint 9-10 | Jul 2026 | OC2 Commission (TRIGGER-01) | 🔄 In progress |
| Sprint 11-18 | Jul-Aug 2026 | P2 Build | 🔄 Planned |

---

## Appendix B — Key References

| Document | Location | Purpose |
|---|---|---|
| Option Paper (TKT-0162) | `docs/TKT-0162-Option-Paper-Nexus-Architecture-Direction.md` | Full Option A/B/C analysis + decision rationale |
| KRI Dashboard | Notion (see Section 8.2 URL) | Live architecture KRI tracking |
| Architecture KRI State | `state/architecture-kri-state.json` | Machine-readable KRI state |
| Data & Memory Architecture (TKT-0104) | Notion / Holocron | 5-tier memory schema, pgvector decisions |
| Enterprise Landscape (TKT-0046) | Notion / Holocron | Full platform landscape, all locked decisions |
| AI Charter v1.0 | Holocron | Governance policy |
| Agent Governance Framework v1.0 | Holocron | Agent tier model + HITL framework |
| System Architecture v1.1 DRAFT | `docs/Nexus-System-Architecture-v1.1-DRAFT.md` | **Companion document — this refresh** |
| System Architecture v1.0 | `docs/Nexus-System-Architecture-v1.0.md` | Previous approved version |
| DevBoard (Notion) | Notion | Sprint tracking, tickets, backlog |

---

## Appendix C — Review & Revision Cadence

**Owner:** Atlas 🏛️ | **Approver:** Ken Mun (CTO)

This document is reviewed and revised at each P1→P4 stage checkpoint and annually.

| Trigger | Condition | Action |
|---|---|---|
| **P1→P2 Checkpoint** | P2 launch (first SME client onboarded, target Aug 2026) | Atlas revises strategy doc to reflect P2 operational reality, P3/P4 trajectory updates. Ken review + approval. |
| **P2→P4 Checkpoint** | TRIGGER-14 fires (post-P2 stable) | Atlas revises P3/P4 sections, updates commercial model, adds FSI strategy detail. Ken review. |
| **P4 Entry** | First FSI/Enterprise engagement confirmed | Atlas revises P4 sections with live detail. Ken review. |
| **Annual Review** | Every May (platform anniversary) | Full document review: update current state, prune outdated content, revalidate OKRs and KRIs, confirm principles still hold. Ken approval. |

---

## Appendix D — Changes from v1.0

**Document:** Aevlith-Technology-Strategy-Roadmap-v1.1-DRAFT.md
**Previous version:** Aevlith-Technology-Strategy-Roadmap-v1.0-Internal.md (2026-05-14, approved by Ken Mun)
**Author:** Atlas 🏛️
**Date:** 2026-07-09

### Material Changes

| # | Section | Change | Reason |
|---|---------|--------|--------|
| 1 | §1 | Updated executive summary: 14 agents, 850+ CHG records, Postgres LIVE, CREST v1.3, OC2 hardware arrived, model migration from Claude to Ollama Cloud. | Platform maturity. |
| 2 | §4.1 | Infrastructure table: Postgres upgraded from "❌ Not deployed" to "✅ LIVE". OC2 upgraded from "⏳ Arriving" to "✅ ARRIVED — commissioning in progress." Added DuckDuckGo, CREST v1.3. | Infrastructure progress. |
| 3 | §4.2 | **Complete refresh of agent roster.** All 14 agents with updated model configs. Added Luthen, Ahsoka formalised, Krennic noted as parked. Model stack changed from Anthropic Claude to Ollama Cloud. | Agent roster + model migration. |
| 4 | §4.3 | Updated operational metrics: CHG count 230+→850+. Added Postgres, CREST, model routing, DuckDuckGo status. Model cost: "Ollama Cloud" from "Anthropic pay-per-token." | Operational maturity. |
| 5 | §4.4 | Updated TOGAF maturity: Data Architecture L1→L2. Technology Architecture L2→L3. | Architecture progress. |
| 6 | §5.1 | Updated structural concerns assessment: Concern 1 (Data) ✅ substantially addressed, Concern 2 (Integration) ⚠️ partially addressed, Concern 3 (Cost) ✅ substantially addressed. | Progress assessment. |
| 7 | §5.2 | Added decision assessment: "Option B was the correct decision." | Retrospective. |
| 8 | §5.3 | Updated Work Currency Model tier mapping for new model stack. | Model migration. |
| 9 | §5.4 | Updated structural fix timeline with actual status. | Progress tracking. |
| 10 | §5.5 | Updated Phase 1 Work Packages: WP1-WP3/WP5 ✅ ACHIEVED, WP4 ⚠️ IN PROGRESS, WP6-WP8 ❌ NOT YET BUILT. | Phase 1 progress. |
| 11 | §6.1 | Updated sprint plan with actual completion status. | Timeline accuracy. |
| 12 | §7.1 | **Complete rewrite of 4-Tier Model Architecture.** New model stack: kimi-k2.7-code, deepseek-v4-pro, deepseek-v4-flash, gemma4:31b-cloud. Deprecated Anthropic Claude. Explained migration rationale. | Major model migration. |
| 13 | §7.2 | Updated cost management: Ollama Cloud pricing model. Removed Anthropic-specific cost parameters. | Cost model change. |
| 14 | §8.2 | Updated KRI dashboard: Postgres, Event Bus, SoT Register ✅. Added note: "Sonnet/Haiku turns reduced" KRI is now 100% achieved — needs redefinition. | KRI update. |
| 15 | §8.3 | Added new locked decisions: CREST v1.3, model_policy v3.0, PG SSOT-first, DuckDuckGo. | New decisions. |
| 16 | §10 | Updated roadmap summary with actual status. | Timeline accuracy. |
| 17 | Appendix A | Updated sprint status with actual completion. | Sprint tracking. |
| 18 | Appendix D | **This appendix** — added for v1.1. | Governance. |

### Top 5 Most Significant Changes

1. **Model migration: Anthropic Claude → Ollama Cloud** (§4.2, §7.1). The entire model stack changed. All 14 agents now use Ollama Cloud models. No agent uses Anthropic Claude as primary. This is the single biggest architectural shift since v1.0.
2. **Postgres LIVE — SSOT-first architecture** (§4.1, §4.4, §5.1). From "not deployed" to "live and operational." Data Architecture maturity moved from L1 to L2.
3. **Agent roster expansion: 12→14** (§4.2). Luthen added. Ahsoka formalised. Krennic parked.
4. **CREST v1.3 + model_policy v3.0** (§8.3, §9). New governance framework. Capability-based model routing. PG-first dispatch.
5. **OC2 transition phase** (§4.1, §6.1). Hardware arrived. Commissioning ~27 July. This is the critical path for S7, local Gemma4:26b, and P2 readiness.

---

*Document produced by Atlas 🏛️ — Enterprise Architect, AInchors / Aevlith Technologies*
*Reviewed by Yoda 🟢 — Lead Orchestrator*
*CHG-0852 (Holocron Refresh) | Platform Day ~76 | 2026-07-09 | v1.1-DRAFT*
*Supersedes: Aevlith-Technology-Strategy-Roadmap-v1.0-Internal.md (2026-05-14)*
*This document is NOT approved. Do not build against it until Ken review is complete.*
*Next review: P1→P2 checkpoint (P2 launch, target Aug 2026) or May 2027 (annual)*