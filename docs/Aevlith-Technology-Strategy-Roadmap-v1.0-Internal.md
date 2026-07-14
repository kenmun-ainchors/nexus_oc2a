# Aevlith Technologies — Technology Strategy & Roadmap
## Internal Reference v1.0

> ⚠️ **SUPERSEDED — docs/Aevlith-Technology-Strategy-Roadmap-v1.1.md approved by Ken Mun 2026-07-09 under CHG-0853.** This v1.0 document is retained for historical reference only.

**Classification: INTERNAL — AInchors / Aevlith Technologies**
**Status: APPROVED ✅**
**Approved by: Ken Mun (CTO) — 2026-05-14 12:39 AEST**
**Author: Atlas 🏛️ — Enterprise Architect | Reviewed by: Yoda 🟢**
**Date: 2026-05-14 | Platform Day 20**
**TKT-0172**

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Strategic Context](#2-strategic-context)
3. [Technology Principles](#3-technology-principles)
4. [Current State — Platform Maturity (Day 20)](#4-current-state--platform-maturity-day-20)
5. [Architecture Direction — Option B Phased](#5-architecture-direction--option-b-phased-approved-2026-05-14-chg-0308)
6. [P1–P4 Technology Roadmap](#6-p1p4-technology-roadmap)
7. [Model & Cost Strategy](#7-model--cost-strategy)
8. [OKRs & KRI Alignment](#8-okrs--kri-alignment)
9. [Governance & Security](#9-governance--security)
10. [Roadmap Summary](#10-roadmap-summary)

---

## 1. Executive Summary

Aevlith Technologies designs, builds, and operates Nexus — the agentic AI operations platform powering AInchors. As of Platform Day 20 (2026-05-14), Nexus is production-ready: 12 active agents, ITSM-grade operations (230+ CHG records), 52+ production scripts, 20+ automated crons, Sanctum governance, Warden compliance monitoring at 15-minute intervals, and auto-heal running nightly.

The most consequential architectural decision of P1 was made on 2026-05-14: **Option B Phased** — redesign the data and integration layers before P2 opens to SME clients, while retaining the OpenClaw platform and the agent model. This decision is locked (CHG-0308, Ken Mun approval 10:28 AEST).

**P2 target: end-August 2026.** P4 Enterprise/FSI trajectory follows as the platform matures.

This document consolidates all approved architectural work, strategic context, P1-P4 roadmap, model/cost strategy, governance controls, and OKR alignment into a single authoritative internal reference. It supersedes the fragmented Aevlith IT Strategy (aevlith-it-strategy-2026-05.md) and standalone OKR document for internal agent and leadership use.

**Key facts at a glance:**
- Platform: OC1 Mac Mini M4 24GB, Melbourne, production. OC2-A/B (Mac Mini M4 Pro 48GB × 2) arrive July 2026.
- Architecture decision: Option B Phased — Postgres + event bus + typed contracts + Work Currency Model before P2.
- Phase 1 architectural fixes: risk-reduced by Sprint 4 end (25 May); architecturally fixed by Sprint 6 end (~8 June).
- Cost: ~$185/day current (intensive build phase). Target 40-60% Sonnet/Haiku reduction via Work Currency Model by September 2026.
- Data sovereignty: client data T0/T1 local ONLY. Non-negotiable. Anthropic DPA verification required before any client data touches Claude.

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

Client data never crosses to Tier 2/3 cloud APIs. Tier 0/1 (local or no-LLM) handles all client workloads. Tier 2/3 (Ollama Cloud, Claude) handles AInchors-internal operations only. This is enforceable at the routing layer and will be enforced at the Postgres schema and access control layers from P2. Anthropic DPA verification is required before any client data touches Claude (Decision H, TKT-0046).

### TP-4: Shipping vs Generality (Context-Dependent)

For training and consulting support features: ship for the immediate use case. Generalise only when 2-3 clients have pulled the same pattern. For security, governance, multi-client isolation, data models, and integration contracts: design for multi-year, multi-client reuse from the start. This is not a contradiction — it is a deliberate prioritisation of what must be right and what can evolve.

### TP-5: FinOps-First (Work Currency Model)

Agentic AI has a 100-1,000x cost multiplier potential per multi-step chain versus single API calls. Every agent workflow must have token budget limits, workflow cost caps, and escalation gates. The Work Currency Model (see Section 7.1) is the primary FinOps instrument. The four currencies — High, Medium, Low, None — map directly to model tiers. Cost is a design constraint, not an afterthought.

### TP-6: ITSM-Grade Operations

Change records (CHG-NNNN), incident management, SLA tracking, and asset registries are native to Nexus operations — not retrofits. All structural changes require a CHG record before execution. All incidents are logged in incident-log.sh with timestamp, severity, and resolution. Ticket discipline (ticket.sh) is non-negotiable. This is the proof of concept: AInchors running ITSM-grade AI operations is itself the demo.

### TP-7: OpenClaw-Committed (No Replatforming)

OpenClaw is the final platform choice for P1-P4. Architectural decisions extend the OpenClaw paradigm rather than fighting it. No replatforming proposals will be evaluated. Agents, sessions, skills, and crons are all OpenClaw-native. The integration layer (Holonet v0, Phase 2) will be built as an OpenClaw-compatible service layer, not a replacement.

---

## 4. Current State — Platform Maturity (Day 20, 2026-05-14)

### 4.1 Infrastructure

| Component | Spec | Status | Notes |
|---|---|---|---|
| OC1 | Mac Mini M4 24GB, Melbourne | ✅ Production | Always-on, single node |
| OC2-A | Mac Mini M4 Pro 48GB | ⏳ Arriving Jul 6-13 | HA Primary |
| OC2-B | Mac Mini M4 Pro 48GB | ⏳ Arriving Jul 6-13 | HA Standby |
| Tailscale mesh | Zero-trust overlay | ✅ Live | `ainchorsoc2as-mac-mini-1.tailfc3ed1.ts.net` |
| MinIO | 4 buckets, local NVMe | ✅ Live | URL pattern: Tailscale FQDN:9000 |
| Google Drive | Human docs, EA outputs | ✅ Live | `kenmun@ainchors.com` |
| Notion / Holocron | Agent Knowledge Base (AKB) | ✅ Live | 38+ pages, SSOT for tickets + CHG |
| Colima / Docker | Container workloads | ✅ Live | Replaces Docker Desktop |
| Postgres | State database | ❌ Not deployed | TKT-0164 — Sprint 4-5 |

**OC1 hard limit:** ~8B parameter Q4 inference local. Gemma4:26b requires OC2. All local inference on OC1 is currently preview-only. Production local inference waits for OC2 commission (~27 July 2026 per TRIGGER-01).

### 4.2 Agent Roster

| Agent | ID | Role | Model Tier | Stream |
|---|---|---|---|---|
| Yoda 🟢 | main | Lead Orchestrator | Sonnet → Haiku → kimi | Technical + Platform |
| Aria 🔵 | business | Business Lead | Sonnet → Haiku → kimi | Business |
| Spark ✨ | social | Social & Marketing | kimi | Business |
| Atlas 🏛️ | architect | Enterprise Architect | Sonnet → Haiku → kimi | Technical |
| Thrawn | platform-arch | Platform Architect | Sonnet → Haiku → kimi | Technical |
| Lando 🟡 | biz-process | BPM Specialist | Sonnet → Haiku → kimi | Business |
| Forge 🏗️ | infra | Infra & SRE | Haiku → kimi | Technical |
| Mon Mothma 🌟 | change-mgt | Change Management | Sonnet → Haiku → kimi | Business |
| Warden 🔍 | governance | Compliance Monitor | Haiku → kimi | Governance |
| Shield 🛡️ | security | Security Review | Haiku → kimi | Governance |
| Lex ⚖️ | legal | Legal & Compliance | Haiku → kimi | Governance |
| Sage 🧪 | qa | QA & Accuracy | Haiku → kimi | Governance |

12 active agents across 4 streams. Ahsoka (consulting delivery) is a named agent role, delivered by Ken for client-facing work in P1. Agent 13 (Krennic — planned platform engineering specialist) is not yet activated.

### 4.3 Operational Maturity

| Metric | Current State |
|---|---|
| Production scripts | 52+ |
| Automated crons | 20+ |
| CHG records | 230+ |
| Incident logs | Live (incident-log.sh) |
| Auto-heal | 01:00 AEST, 19 checks |
| Warden monitoring | 15-min intervals, consecutive clean runs tracking |
| Availability (historical) | 97.46% |
| Cost (intensive build phase) | ~$185/day AUD |
| Daily cost cap | $150/day (temp $450 until 17 May) |
| API auto-reload | Triggers at $50 balance, reloads $450 |

### 4.4 Platform Maturity by TOGAF Domain

| Architecture Domain | Maturity Level | Current Gaps |
|---|---|---|
| Business Architecture | L3 — Functional | Client journey templates, GTM playbooks, Ahsoka engagement model templates |
| Data Architecture | L1 — Ad hoc | No formal data strategy; JSON fragmentation; no SoT register; no data dictionary |
| Application Architecture | L3 — Functional | Integration layer missing; typed contracts not implemented; document generation not built |
| Technology Architecture | L2 — Emerging | Single node (no HA); no Postgres; local inference Tier 1 gated on OC2 |
| Security & Governance Architecture | L3 — Functional | S1-S7 live; Sanctum live; P2 per-client governance policies pending |

**Most critical gap:** Data Architecture at L1 is the primary blocker for P2. The Option B decision directly addresses this.

---

## 5. Architecture Direction — Option B Phased (APPROVED 2026-05-14, CHG-0308)

### 5.1 The Three Structural Concerns

Ken identified three structural concerns that, left unaddressed, become unmanageable at P1-P4 scale. These drove the Option B decision:

**Concern 1 — Data Architecture:**
No coherent data landscape. All structured state lives in ad-hoc JSON files with no schema validation, no ownership model, no classification tagging. Notion (Holocron) is the closest thing to a source of truth but is a human-managed wiki, not a governed data platform. Ken manually corrects data state because agents have no reliable shared truth to write against. At P2 scale with SME client data, this is a compliance and integrity failure waiting to happen.

**Concern 2 — Integration Architecture:**
All agent-to-agent communication happens via OpenClaw `sessions_send`. No contracts. No typing. No versioning. One agent's output is another's string input. Agents mutate state (JSON files, Markdown files) directly with no coordination layer and no conflict detection. The LinkedIn dual-post incident (Day 20) is the live proof of the integration architecture risk.

**Concern 3 — Cost and Sustainability:**
Status updates, file writes, JSON state mutations, and CRUD operations all route through Sonnet or Haiku. This drives unnecessary cost, latency, and non-determinism into operations that should be deterministic scripted actions. Without the Work Currency Model, every agent invocation is an LLM call regardless of whether it needs to be.

### 5.2 Decision: Option B Phased

Three options were evaluated by Atlas and approved by Ken Mun (CTO):

| Option | Description | Score | Decision |
|---|---|---|---|
| A | Incremental hardening — evolve current architecture in place | 3.55/5 | ❌ Rejected — defers the problem, compounds at P2 scale |
| **B** | **Redesign data + integration layers, keep OpenClaw and agent model** | **4.70/5** | **✅ SELECTED — CHG-0308** |
| C | Radical platform refactor — rebase the foundation | 3.35/5 | ❌ Rejected — architecturally superior but not feasible solo before August |

Option B keeps what works (OpenClaw platform, 12-agent roster, ITSM operations) and fixes what is broken (data architecture, integration layer, LLM-for-CRUD anti-pattern). It is the only option that is both architecturally sound and deliverable before P2 launch.

**Full analysis and decision rationale:** `docs/TKT-0162-Option-Paper-Nexus-Architecture-Direction.md`

### 5.3 Work Currency Model

The Work Currency Model is the primary cost justification for building a proper integration layer. It classifies all platform work into four currencies and routes each to the appropriate execution tier:

| Currency | Work Type | Examples | Execution Tier | Model |
|---|---|---|---|---|
| High | Reasoning, design, judgment, planning, synthesis | Architecture decisions, proposal drafting, complex analysis | T3 | Sonnet 4.6 / Haiku 4.5 / Opus |
| Medium | Template content, classification, summarisation, structured generation | Content generation, ticket triage, categorisation | T2 | Ollama Cloud (kimi-k2.6, deepseek) |
| Low | CRUD, state writes, status updates, simple lookups | Ticket status updates, file writes, log appends | T1/T0 | Gemma4:26b local / systemEvent |
| None | System calls, file I/O, API calls, non-LLM processing | Shell scripts, database writes, API integrations | T0 | Script / integration layer |

**Target:** 40-60% Sonnet/Haiku turn reduction within 3 months of Phase 1 completion (by ~September 2026). The investigation of 2026-05-14 confirmed the real cost driver is interactive sessions and subagents (not the cron layer). The structural fix is Work Currency routing — routing "Low" and "None" currency work away from T3 models entirely.

### 5.4 Structural Fix Timeline

| Milestone | Target | What Changes |
|---|---|---|
| Risk reduced | Sprint 4 end, 25 May 2026 | Three Work Types Rule (TKT-0165) + SoT Register (TKT-0166) operational |
| Architecturally fixed | Sprint 6 end, ~8 June 2026 | Event bus (TKT-0168) + JSON→Postgres migration top 5 (TKT-0167) complete |
| Phase 1 complete | August 2026 | All WP1-WP8 delivered, OC2 commissioned, Cloudflare Tunnel live |

### 5.5 Phase 1 Work Packages

| WP | Title | Ticket | Priority | Sprint | Launch Blocker |
|---|---|---|---|---|---|
| WP1 | Postgres Deploy + 5-Tier Schema | TKT-0164 | P0 | S4-5 | ✅ Yes |
| WP2 | Three Work Types Rule + Work Currency Routing | TKT-0165 | P0 | S4 | ✅ Yes |
| WP3 | Sources of Truth Register — 10 Core Data Types | TKT-0166 | P0 | S4 | ✅ Yes |
| WP4 | JSON→Postgres Migration — Top 5 State Files | TKT-0167 | P0 | S5 | ✅ Yes |
| WP5 | Postgres LISTEN/NOTIFY Event Bus | TKT-0168 | P0 | S5 | ✅ Yes |
| WP6 | Typed Agent Contracts — 4 Cross-Agent Handoffs | TKT-0169 | P1 | S5-6 | No |
| WP7 | PII Scanner on Document Ingestion Pipeline | TKT-0170 | P1 | S5-6 | No |
| WP8 | pgvector + nomic-embed-text RAG Pipeline | TKT-0171 | P1 | S6 | No |

**Dependency sequence:** WP1 must land before WP3, WP4, WP5, WP7, WP8. WP5 must land before WP6.

**KRI dashboard:** https://www.notion.so/Nexus-Architecture-KRI-Dashboard-Option-B-Implementation-360c182953ff816a9d1dd5c104ca6cd1

---

## 6. P1–P4 Technology Roadmap

### 6.1 P1 — Internal Single-Tenant (Current → P2 Launch)

**Objective:** Harden Nexus as a governance-first, production-grade agentic AI operations platform for AInchors. Fix the data, integration, and cost architecture before P2.

#### Sprint 4 (May 19-25, 2026)
- TKT-0141: CLI-Anything security controls
- TKT-0142: SKILL.md poisoning protection
- TKT-0165: Three Work Types Rule + Work Currency Routing Table
- TKT-0166: Sources of Truth Register (10 core data types)
- Cloudflare Tunnel: public-safe ingress for client-facing surfaces

#### Sprint 5 (May 26-Jun 1, 2026)
- TKT-0164: Postgres deploy + 5-Tier Memory Schema on OC1 (P0 — launch blocker)
- TKT-0167: JSON→Postgres migration — top 5 state files
- TKT-0168: Postgres LISTEN/NOTIFY event bus — core event types + 3 publishers
- TKT-0108: Document generation pipeline (DOCX/XLSX/PPTX/PDF)
- TKT-0130: QBR ceremony (Sprint 5 review)

#### Sprint 6 (Jun 2-8, 2026)
- TKT-0169: Typed agent contracts — 4 cross-agent handoffs
- TKT-0170: PII scanner on document ingestion pipeline
- TKT-0150: DR Playbook (documented RTO/RPO, tested recovery procedure)
- Continue JSON migration if WP4 not complete

#### Sprint 7 (Jun 9-15, 2026)
- TKT-0171: pgvector + nomic-embed-text RAG pipeline — initial knowledge base
- Architecture hardening and Phase 1 close verification

#### Sprint 9-10 (July 2026) — TRIGGER-01
- OC2-A/B arrival (Est. Jul 6-13) → commission ~27 July
- HA HIVE cluster activation (OC1 → OC2-A Primary + OC2-B Standby)
- Local Gemma4:26b inference live (T1 unlocked for AInchors-internal workloads)
- Aria and other agents migrated to HIVE multi-node configuration
- NAS encryption (S7 completion) — pre-OC2 arrival

**P1 Exit Criteria:**
- WP1-WP5 complete (Postgres, Three Work Types Rule, SoT Register, JSON migration, Event Bus)
- OC2-A/B commissioned and HA validated
- Cloudflare Tunnel live
- DR Playbook documented and tested
- Security controls TKT-0141/0142 verified
- Cost trajectory showing Work Currency Model impact

### 6.2 P2 — SaaS Multi-Tenant (August 2026)

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
- WP16: Full agent output schema library (all 12 agents typed)
- WP17: Formal data quality gates on tenant-touching workflows

**KL team integration:**
- 4-5 headcount, Malaysia
- Cloudflare Access for role-scoped IAM
- KL team scoped to business stream only (Aria, Spark, Mon Mothma, Lando)
- No KL access to platform architecture, security controls, or client data

**Commercial tiers at P2:**
- Standard: single agent, AInchors-managed, Tier 0/1 client workloads
- Company (P3 unlock): multi-agent, company-wide context, ROI-gated feature flag activation

**P2 Exit Criteria:**
- 2+ live SME clients with data sovereignty verified
- Tier 1 (Gemma4:26b on OC2) handling all client workloads — no client data on T3
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

**BYOK policy at P4:** Enterprise clients supply their own LLM API keys. They own their DPA compliance. Client data never touches AInchors model subscriptions. Anthropic DPA risk is fully transferred to the client.

---

## 7. Model & Cost Strategy

### 7.1 4-Tier Model Architecture

| Tier | Models | Primary Use | Unit Cost |
|---|---|---|---|
| T0 | systemEvent, shell scripts, non-LLM APIs | CRUD, system calls, file I/O, deterministic operations | $0 |
| T1 | Gemma4:26b local (OC2+) | Client workloads, background batch, AInchors-internal Low-currency work | $0 (post-OC2) |
| T2 | Ollama Cloud: kimi-k2.6, deepseek-r1 | Medium-currency AInchors-internal: content, classification, summarisation | Fixed ~$100/mo |
| T3 | Claude Sonnet 4.6, Haiku 4.5, Opus 4 | High-currency reasoning, design, planning, judgment | Pay-per-token |

**Routing rule (CHG-0270 — mandatory 3-level fallback):**
- All T3 agents: Primary → Secondary → kimi (Anthropic-independent safety net)
- Yoda/Aria: Sonnet 4.6 → Haiku 4.5 → kimi
- All T3 specialists: Sonnet 4.6 → Haiku 4.5 → kimi
- Governance/infra agents: Haiku 4.5 → kimi → kimi

**Client data routing rule (non-negotiable):**
- All client workloads → T0/T1 ONLY. No client data on T2/T3.
- At P2 launch: Gemma4:26b (OC2) handles all client inference. T3 models never see client data.

### 7.2 Cost Management

| Parameter | Value | Notes |
|---|---|---|
| Daily cap | $150/day | Temporary $450 until 17 May (intensive build phase) |
| Auto-reload trigger | $50 balance | Reloads $450 |
| Daily actual (May 10-14 avg) | ~$185/day | Build phase — expected to normalise |
| Tier 3 alert threshold | $15/session | Alert Ken + Angie immediately via webchat + Telegram |
| Monthly AInchors target (post-Phase 1) | ~$3,000/mo | Estimate based on 40-60% T3 reduction |
| KL team cost allocation | Separate tracking | Business stream only, lower T3 volume |

**Cost driver analysis (2026-05-14 investigation):**
The cron layer was 80% correctly routed. The real drivers are interactive sessions and subagents — both legitimate High-currency work. The structural fix is the Work Currency Model: routing "Low" and "None" currency work to T0/T1 eliminates the unnecessary T3 cost. Sonnet/Haiku remains appropriate for all legitimate High-currency work.

### 7.3 P2 Cost Model

At P2, client workloads fully migrate to T1 (Gemma4:26b on OC2). The client cost model becomes:
- Infrastructure: OC2 hardware (amortised — near-zero per-client marginal cost)
- T2 fixed: ~$100/mo for AInchors-internal business stream
- T3 variable: AInchors-internal planning, design, and orchestration only
- No T3 client exposure: Gemma4:26b handles all client inference

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
- KR1: Atlas + Yoda produce P2/P4 architecture roadmap tying platform capabilities to OKRs ✅ **DONE** (TKT-0162 approved 2026-05-14; TKT-0172 this document)
- KR2: All major architecture Epics tagged with pillar + OKR IDs
- KR3: At least 2 internal architecture reviews per quarter

### 8.2 Architecture KRIs (Live Dashboard)

**Dashboard:** https://www.notion.so/Nexus-Architecture-KRI-Dashboard-Option-B-Implementation-360c182953ff816a9d1dd5c104ca6cd1
**Managed by:** Yoda 🟢 (live updates at each sprint review)
**Last updated:** 2026-05-14 by Atlas 🏛️

| KRI | Baseline (Day 20) | Phase 1 Target | Phase 2 Target |
|---|---|---|---|
| Postgres deployed | ❌ | ✅ | ✅ |
| State files on Postgres | 0 | 5 | 15+ |
| Event bus (LISTEN/NOTIFY) live | ❌ | ✅ | ✅ |
| Typed agent contracts | 0 | 4 | 10+ (all agents) |
| LLM-for-CRUD eliminated | 0% | 40% | 80% |
| Sonnet/Haiku turns reduced | 0% | 40-60% | 70%+ |
| SoT Register complete | ❌ | ✅ | ✅ |
| PII scanner live | ❌ | ✅ | ✅ |
| RAG pipeline live | ❌ | ✅ | ✅ |
| Multi-tenant RLS live | ❌ | ❌ | ✅ |

### 8.3 Locked Architectural Decisions

The following decisions are locked for P1-P4 and require CTO-level review to change:

| Decision | Reference |
|---|---|
| pgvector + nomic-embed-text 768-dim for RAG | TKT-0104 |
| Shared schema + RLS from P2 day one | CHG-0234 |
| OpenClaw as final platform — no replatforming | TP-7 |
| Mac Mini HIVE for P1-P2 | TRIGGER-01 |
| Client data: T0/T1 local ONLY | DS-1 to DS-5 |
| BYOK policy for P4 FSI clients | TKT-0046 Decision H |
| Block Claude for P2 client workloads | TKT-0046 Decision H |
| P3 = commercial tier within P2 (not a build phase) | CHG-0234 |
| Event sourcing deferred to Phase 3 (TRIGGER-14) | TKT-0162 approved |
| Option B Phased — redesign data + integration | CHG-0308 |

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
All external outputs → Shield (security review) → Lex (legal/compliance review) → Sage (QA/accuracy review). Average target turnaround: <24h training/marketing content, <72h proposals.

### 9.2 Security Controls S1-S7

| Control | Requirement | Status |
|---|---|---|
| S1 | OpenClaw ≥ v2026.5.5 (current release) | ✅ Live |
| S2 | Port 18789 loopback only — never public | ✅ Live |
| S3 | No ClawHub skills on production (TKT-0142 pending hardening) | ✅ Live |
| S4 | Least-privilege per agent (CHG-0176) | ✅ Live |
| S5 | No hardcoded credentials anywhere in workspace | ✅ Live |
| S6 | All changes CHG-logged + Warden-monitored | ✅ Live |
| S7 | NAS encrypted | ⏳ Post-OC2 (pre-OC2-A/B arrival) |

**Open security items:**
- TKT-0141: CLI-Anything security controls (Sprint 4)
- TKT-0142: SKILL.md poisoning protection (Sprint 4)
- S7: NAS encryption before OC2 arrival (July)

### 9.3 Data Sovereignty Controls (DS-1 to DS-5)

These controls are technically enforced at P2 via Postgres RLS and routing rules. At P1, they are operationally enforced by agent instruction and monitored by Warden.

| Control | Rule |
|---|---|
| DS-1 | Client data never leaves OC1. T0/T1 local ONLY for all client processing. |
| DS-2 | Client data never routes to T2/T3 cloud APIs (Ollama Cloud, Claude, any external model). |
| DS-3 | No co-mingling of client data and AInchors-internal data. |
| DS-4 | BYOK exception at P4: client supplies own LLM API keys and accepts DPA compliance. |
| DS-5 | Anthropic DPA verification required before any client data touches Claude (Decision H, TKT-0046). |

**Privacy Act (Australia) compliance:**
All client data handling must comply with APP 11 (cross-border data transfer). Gemma4:26b local inference (OC1/OC2) satisfies this requirement. Cloud model routing for client data does not.

### 9.4 Warden Monitoring

Warden 🔍 runs at 15-minute intervals, monitoring all 12 agents for:
- Model routing compliance (is agent using correct tier?)
- HITL gate adherence (is Sanctum bypassed?)
- CHG record completeness (does every structural change have a CHG?)
- Cost anomaly detection (per-agent spend spike alerts)
- Data sovereignty violations (T2/T3 receiving client data)

Warden reports go to Yoda 🟢 and are logged to `state/warden-compliance-state.json`. Consecutive clean runs are tracked. Any violation triggers immediate escalation to Ken.

---

## 10. Roadmap Summary

| Quarter | Phase | Key Deliverables | Sprints |
|---|---|---|---|
| Q2 2026 (May-Jun) | P1 Architecture | Three Work Types Rule, SoT Register, Postgres, Event Bus, Typed Contracts, PII Scanner, RAG Pipeline, Cloudflare Tunnel, Security TKT-0141/0142, DR Playbook | S4-S8 |
| Q3 2026 (Jul-Aug) | P1 Close + P2 Launch | OC2-A/B commission (TRIGGER-01), HA HIVE, Gemma4:26b T1 live, Multi-tenant RLS, Citadel v0, Holonet v0, first SME clients onboarded | S9-S18 |
| Q4 2026 (Sep-Oct) | P2 Mature | Client portal fully live, Beacon/Datapad observability dashboard, Holocron API-first retrieval, SLO reporting, Work Currency Model validated (40-60% T3 reduction confirmed) | Post-P2 |
| Q1 2027 | P2 Stable + P4 Prep | Event sourcing design (TRIGGER-14 initiated), APRA CPG 234/235 control mapping, FSI packaging, P3 commercial tier unlocked for pilot clients | P3 |
| 2027+ | P4 Enterprise / FSI | Physical deployment package, APRA full compliance, HSM-backed CMK, WORM archive (7-year), first FSI client engaged, Aevlith Technologies brand surfaces | P4 |

---

## Appendix A — Sprints at a Glance

| Sprint | Dates | Theme | Key Tickets |
|---|---|---|---|
| Sprint 3 | May 12-18 | Security + Observability | TKT-0135, TKT-0141, TKT-0142, TKT-0144 |
| Sprint 4 | May 19-25 | Work Currency + SoT | TKT-0141, TKT-0142, TKT-0165, TKT-0166 |
| Sprint 5 | May 26-Jun 1 | Postgres + Data Layer | TKT-0164, TKT-0167, TKT-0168, TKT-0108 |
| Sprint 6 | Jun 2-8 | Integration + Contracts | TKT-0169, TKT-0170, TKT-0150 |
| Sprint 7 | Jun 9-15 | RAG + Phase 1 Close | TKT-0171, Phase 1 KRI validation |
| Sprint 9-10 | Jul 2026 | OC2 Commission (TRIGGER-01) | OC2 setup, HA config, Gemma4:26b T1 |
| Sprint 11-18 | Jul-Aug 2026 | P2 Build | WP9-WP17, first client onboarding |

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
| YODA_RULES.md | `/Users/ainchorsoc2a/.openclaw/workspace/YODA_RULES.md` | Strategic routing rules |
| ORCHESTRATOR.md | `/Users/ainchorsoc2a/.openclaw/workspace/ORCHESTRATOR.md` | Full platform architecture reference |

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

*Document produced by Atlas 🏛️ — Enterprise Architect, AInchors / Aevlith Technologies*
*Reviewed by Yoda 🟢 — Lead Orchestrator*
*TKT-0172 | Platform Day 20 | 2026-05-14*
*Approved by Ken Mun (CTO) — 2026-05-14*
*Next review: P1→P2 checkpoint (P2 launch, target Aug 2026) or May 2027 (annual)*
