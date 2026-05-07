# TKT-0086 Step 3 — Atlas EA Roadmap & Architecture Strategy
**Auralith / AInchors | TOGAF ADM-Based Enterprise Architecture**

> **Document Owner:** Atlas 🏛️ (Enterprise Architect)
> **Produced:** 2026-05-07
> **Status:** DRAFT v1.0 — Approved for use as definitive architecture reference
> **Review trigger:** P2 gate (July 2026), or any material change to HIVE, multi-tenancy, or model strategy
> **Linked:** TKT-0086 | OKR: X2-KR1 | Pillar: Technology / Auralith

---

## Contents

1. [Current State (As-Is)](#a-current-state-as-is--architecture-summary)
2. [Target State (To-Be)](#b-target-state-to-be--architecture-vision)
3. [Transition States — Gate Criteria](#c-transition-states--p1-through-p5-progressive-delivery)
4. [1-Year Prioritised Plan (Q1–Q4 2026)](#d-immediate-1-year-plan-q1q4-2026--prioritised-architecture-work)
5. [Architecture Decision Register (ADR)](#e-architecture-decision-register-adr)
6. [Risks & Mitigations](#f-risks-and-mitigations)

---

## A. Current State (As-Is) — Architecture Summary

### A1. Platform Context

**Day 13 (2026-05-07). Production on OC1 (Mac Mini M4 24GB). OpenClaw v2026.5.5. 12 active agents.**

AInchors is a Day-13 AI-native business. Auralith's Nexus platform is operational on a single production node, governing a 12-agent team across two streams (Ken/Technical, Angie/Business). The Sanctum (Shield → Lex → Sage) is live. Warden runs 9-check compliance every 15 minutes. Notion Holocron is the SSOT. Model strategy: Sonnet 4.6 primary (Tier 3) + Ollama Cloud kimi-k2.6 (Tier 2 active since TRIGGER-05). Full 4-tier strategy pending OC2 arrival in July 2026.

---

### A2. TOGAF Domain Assessment — As-Is

#### Business Architecture

| Component | State | Gap |
|-----------|-------|-----|
| Pillar model (Training / Consulting / Technology) | Defined ✅ | Not yet embedded in all agent routines |
| Jumpstart offer (Ahsoka) | Pilot testing (Day 13) | No live client; offer v1 not frozen |
| Training ladder (L1/L2/L2.5/L3) | Designed, not delivered | First workshop not yet run |
| Auralith as IP entity | Concept confirmed (Ken, 2026-05-07) | Not yet incorporated |
| OKR tracking | Doc locked (2026-05-07) | Not yet wired into agent KPIs |
| Client funnel | Framework built (CAMP-0001 active) | 0 confirmed conversions, no revenue yet |

**Domain RAG — P2 Readiness: 🔴 Red**
No live clients, no revenue, business stream nascent. First proof-of-model required before P2 entry.

---

#### Data Architecture

| Component | State | Gap |
|-----------|-------|-----|
| Notion Holocron (SSOT) | Live — 38 pages | API-first agent query not formalised |
| Data sovereignty enforcement | Tier 2/3 = AInchors-only confirmed | No client data exists yet to enforce against |
| Multi-tenant data isolation | Not started | Per-client filesystem/DB separation not built |
| Model state management (obs.db, health-state.json) | Live | Not consolidated; no unified view |
| NAS encrypted storage | PENDING — S7 partial | Pre-OC2 delivery blocker |
| Backup strategy | 2AM daily workspace only | No 3-2-1+1 implementation; no documented RTO/RPO |
| Agent memory / session state | File-system-first (MEMORY.md, daily files) | No cross-agent state sharing mechanism |

**Domain RAG — P2 Readiness: 🟡 Amber**
Core data sovereignty principles defined. Enforcement machinery exists for AInchors workloads. Client-data isolation and multi-tenant data architecture are greenfield.

---

#### Application Architecture

| Component | State | Gap |
|-----------|-------|-----|
| Core agents (Yoda, Aria, Shield, Lex, Sage, Warden) | Live ✅ | — |
| Specialist agents (Spark, Atlas, Thrawn, Lando, Mon Mothma) | Live (Spark active; others spawned on-demand) | No agent SLA metrics |
| Ahsoka (consulting) | Pilot (Day 13) | Not battle-tested; no live engagement |
| Krennic (SRE) | Designed, not built | Build trigger: >2 incidents/week |
| Document generation pipeline | Planned | Not implemented; blocks Ahsoka proposals |
| The Citadel (client portal) | Designed, not built | P2 prerequisite |
| Beacon / Datapad (observability) | Designed, not built | Currently split across obs.db + health-state.json |
| Holonet (data integration layer) | Designed, not built | P3 prerequisite |
| Holocron API (programmatic access) | Notion API available | Not formalised for agent queries |
| ITSM (CHG/INC) | Live — internal only | Not client-facing; no SLA measurement |

**Domain RAG — P2 Readiness: 🟡 Amber**
Agent runtime is production-grade. Consulting/client-facing application layer (Ahsoka, Citadel, document generation) is missing and must be built in P1.

---

#### Technology Architecture

| Component | State | Gap |
|-----------|-------|-----|
| OC1 Mac Mini M4 24GB | Live production ✅ | Single point of failure; no HA |
| OC2-A/B Mac Mini M4 Pro 48GB | ETA July 2026 | Not yet deployed |
| Tailscale mesh | Security configured (S2) | Inter-node mesh (OC1/OC2/NAS) not yet validated |
| NAS | Present | Not encrypted (S7 incomplete) |
| Ollama (local inference) | gemma4:e2b on OC1 (background/crons only) | Gemma4:26b (Tier 1) needs OC2 |
| OpenClaw gateway | v2026.5.5, loopback-only | Single instance; no load distribution |
| Docker multi-tenancy | Not implemented | P2 client isolation depends on this |
| Backup | 2AM daily cron | Only workspace; no cloud or offsite copy |
| CI pipeline | Manual CHG/TKT workflow | No automated test gate |

**Domain RAG — P2 Readiness: 🔴 Red**
Single-node, no HA. Multi-tenancy not implemented. Critical infrastructure (OC2, Docker isolation) pending. Technology architecture is the P2 hard gating domain.

---

#### Security & Governance Architecture

| Component | State | Gap |
|-----------|-------|-----|
| S1 — OpenClaw patched (CVE-2026-25253) | ✅ Done | Daily Warden check |
| S2 — Gateway loopback-only | ✅ Done | Tailscale remote validated |
| S3 — No ClawHub skills in prod | ✅ Done | Weekly audit active |
| S4 — Least privilege per agent | ✅ Done (CHG-0176) | — |
| S5 — No hardcoded credentials | ✅ Done | Keychain + env vars enforced |
| S6 — CHG log + Warden compliance | ✅ Done | — |
| S7 — NAS encrypted | ⚠️ Partial | NAS encryption pending OC2 |
| APP compliance | Not documented | Pre-P2 requirement for client data handling |
| Per-client secret isolation | Not implemented | Needed for P2 client onboarding |
| Warden — model compliance | ✅ Live | Monitors 9 agents, 15-min cadence |
| Sanctum review SLA tracking | Not measured | Pass/fail rates not logged |
| SOUL.md size enforcement | ✅ Live (CHG-0176 era) | Max 5,000 chars enforced |

**Domain RAG — P2 Readiness: 🟡 Amber**
Strong foundation (S1–S6 complete, Warden live, Sanctum live). S7 open, no APP documentation, per-client isolation not built. Not P2-client-ready but close.

---

### A3. Top 5 Architectural Risks (Current)

| # | Risk | Domain | Severity |
|---|------|---------|----------|
| R1 | **Single-node failure (OC1 only)** — entire Nexus goes down if OC1 fails; 12 agents, all AInchors ops, all consulting work offline. No HA, no failover. | Technology | 🔴 Critical |
| R2 | **Multi-tenancy not built** — adding SME clients today requires manual per-client config; no Docker isolation, no credential separation; one config error could expose client A data to client B. | Technology / Security | 🔴 Critical |
| R3 | **Agentic cost multiplier exposure** — multi-step agent chains can generate 100–1,000× cost spikes. Token budget limits and per-workflow caps exist conceptually but are not enforced at the platform level. At scale, a single runaway chain could burn the monthly budget in hours. | Business / Technology | 🟠 High |
| R4 | **No unified observability** — ops state is split across obs.db, health-state.json, Warden escalation files, and Notion. No consolidated dashboard. Incidents are detected reactively. | Application / Technology | 🟠 High |
| R5 | **Document generation pipeline missing** — Ahsoka cannot produce board-ready proposals or business cases without this. Blocks the consulting pillar's only revenue path in P1. | Application / Business | 🟠 High |

---

### A4. Framework Maturity Summary (As-Is)

| Framework | Maturity | Priority Focus |
|-----------|----------|----------------|
| AGILE | L2 — Developing | Medium |
| ITSM / ITIL | L3 — Defined | High |
| Governance (Sanctum) | L2–L3 — Defined, not battle-tested | Medium |
| TOM (Agent Team) | L2 — Developing | High |
| Model Strategy | L3–L4 — Defined/Managed | Low |
| Knowledge Management | L2 — Developing | Medium |
| Cost Management | L2–L3 — Developing/Defined | Medium |
| Business ROI | L2 — Developing | High |

---

## B. Target State (To-Be) — Architecture Vision

### B1. Business Architecture — Target States

| Phase | Target State |
|-------|-------------|
| **P1 end (July 2026)** | Jumpstart offer v1 frozen. Ahsoka operational — has produced at least 1 Sanctum-approved proposal. 1–2 training workshops delivered. Business stream (Angie/Aria) active. First revenue event recorded. OKRs tracked in Notion. |
| **P2 end (Jan 2027)** | 3–5 Jumpstart engagements complete. 6–10 workshops delivered. 2–3 SME clients live on Nexus. 2 case studies published. Level 3 training track piloted. AInchors revenue trajectory confirmed. |
| **P3 end (2028)** | AInchors is the go-to AI operations workshop + consulting provider for SMEs in AU/MY. 5–15 concurrent Nexus client tenants. Auralith as a recognised IP/platform entity. Nexus documented as a TOGAF-compliant reference architecture. |
| **P4/P5 end (2031)** | AInchors + Nexus Academy serves AU, MY, GCC. Auralith has a small number of direct external managed tenants. ISO/IEC 42001 alignment complete. Nexus as a live learning environment for Level 3 intensives. |

### B2. Data Architecture — Target States

| Phase | Target State |
|-------|-------------|
| **P1 end (July 2026)** | 3-2-1+1 backup live. NAS encrypted (S7 complete). Holocron API formalised for Ahsoka queries. Tier 2/3 = AInchors-only enforced and Warden-monitored. FinOps tags: all API costs tagged by tier + workload type. |
| **P2 end (Jan 2027)** | Per-client data isolation live (Docker containers with separate workspace, logging, secrets). Client data proven on Tier 0/1 only — zero Tier 2/3 exposure incidents. Datapad producing weekly client data reports. |
| **P3 end (2028)** | Multi-client data model mature — Holocron has client-specific knowledge partitions. Holonet v1 connecting client systems (CRM/ERP) to Nexus agents. Full data lineage and sovereignty audit trail per client. |
| **P4/P5 end (2031)** | Data architecture enterprise-grade: ISO/IEC 42001 compliant audit trails, APP documentation complete, geographic data residency for MY/GCC tenants (OC3 co-lo or in-country node consideration). |

### B3. Application Architecture — Target States

| Phase | Target State |
|-------|-------------|
| **P1 end (July 2026)** | Document generation pipeline live (DOCX/XLSX/PPTX/PDF). Ahsoka with full skills set (research, proposal, ROI model). Agent SOUL.md compact standard enforced across all agents. FinOps dashboard operational (Forge midday output). |
| **P2 end (Jan 2027)** | The Citadel v1 live for 2+ clients. Beacon + Datapad consolidated and producing client reports. Krennic (SRE) deployed. Holonet v0.1 with at least 1 client system connected. ITSM client-facing (SLA reports via Citadel). |
| **P3 end (2028)** | Agent marketplace (internal) — pre-built skills and workflow templates deployable by Ahsoka without bespoke development. Citadel v2 with self-service client views. Full 4-tier TOM with content, support, reporting, coding sub-agents built. |
| **P4/P5 end (2031)** | Nexus as a productised platform: client onboarding < 1 week fully automated. Agent catalogue covering 20+ business use cases. Nexus Academy uses Nexus as a live learning environment. Optional white-label client-facing portal. |

### B4. Technology Architecture — Target States

| Phase | Target State |
|-------|-------------|
| **P1 end (July 2026)** | OC1 stable at >99% uptime (90-day rolling). 3-2-1+1 backup live. NAS encrypted. OC2 deployment playbook in Holocron. FinOps controls enforced at platform level. |
| **P2 end (Jan 2027)** | HIVE live: OC2-A (HA Primary) + OC2-B (HA Secondary) + OC1 (retained). Tailscale mesh validated across all nodes. Tier 1 (Gemma4:26b on OC2-A) handling all client workloads. Docker per-client isolation: 2–3 isolated tenants. Failover tested and documented. |
| **P3 end (2028)** | HIVE fully mature: stable multi-node HA, Krennic managing SLO/error budgets, automated failover runbooks. Infrastructure capable of supporting 5–15 concurrent SME clients. OC3 planning initiated for geographic expansion (MY/GCC) if demand warrants. |
| **P4/P5 end (2031)** | HIVE extended: OC3 co-lo or in-country nodes for MY/GCC data residency if required. Client-aware distributed multi-gateway architecture with intelligent routing. Low-power, always-on, cost-optimised at scale. |

### B5. Security & Governance Architecture — Target States

| Phase | Target State |
|-------|-------------|
| **P1 end (July 2026)** | S1–S7 all complete (S7 NAS resolved). Sanctum SLA tracking live (pass/fail rates logged). Governance metrics in morning standup. Zero client-facing incidents. |
| **P2 end (Jan 2027)** | Per-client secret isolation enforced (separate API keys, separate Telegram bots, separate Sanctum flows). P2 Client Security Onboarding Checklist approved by Lex + Shield. Warden extended to monitor client tenant agents. APP compliance draft for pilot clients. |
| **P3 end (2028)** | ISO/IEC 42001 alignment mapped. Enterprise-grade audit trail completeness. Krennic delivering SLA enforcement. Governance differentiator in client-facing materials — Nexus governance as a sales asset. |
| **P4/P5 end (2031)** | ISO/IEC 42001 certified or aligned. APP compliance fully documented. Audit trails enterprise-complete. Nexus governance positioned as a competitive advantage for regulated sector clients (financial services, legal, government). |

---

## C. Transition States — P1 Through P5 Progressive Delivery

### C1. P1 → P2 Gate (July 2026)

**Gate name:** HIVE Activation + First Client Ready

| Gate Criterion | Why It Matters |
|----------------|----------------|
| ✅ OC1 stable >99% uptime for 30-day rolling window | Platform credibility before adding clients |
| ✅ OC2-A/B live, Tailscale mesh validated, failover tested | HA is the P2 prerequisite — cannot add clients to a single-node platform |
| ✅ Docker per-client isolation: at least 1 test environment validated | Client data cannot be at risk |
| ✅ Tier 1 (Gemma4:26b) operational on OC2-A for client workloads | Data sovereignty rule requires local inference for client data |
| ✅ NAS encrypted (S7 complete) | Security control gap eliminated |
| ✅ Document generation pipeline live | Ahsoka cannot produce proposals without it |
| ✅ Ahsoka produced at least 1 Sanctum-approved proposal | Consulting pillar not validated until this gate passes |
| ✅ FinOps controls enforced at platform level (per-agent token budgets, per-workflow caps) | Cannot open to clients without cost safety rails |

**Key architectural move:** OC1 singleton → HIVE (OC1 + OC2-A + OC2-B). This is the single biggest technology leap of the entire roadmap.

**Risk if rushed:** Adding clients to OC1 without HA exposes AInchors to an SLA breach the moment OC1 hardware fails. A single drive failure or kernel panic wipes out all client operations and all consulting deliverables simultaneously. The reputational damage from a first-client outage would be severe.

**No-over-engineering flag:** The Citadel (client portal) is not required at P2 gate. A per-client Notion view or simple email/Telegram delivery suffices initially. The Beacon/Datapad consolidated dashboard is also deferrable until mid-Q3.

---

### C2. P2 → P3 Gate (January 2027)

**Gate name:** Managed Platform Proven

| Gate Criterion | Why It Matters |
|----------------|----------------|
| ✅ 2–3 SME clients live with isolated Docker tenants and Tier 1 data sovereignty enforced | Platform multi-tenancy proven with real clients |
| ✅ Zero client data sovereignty incidents in P2 | Cannot call it enterprise-ready otherwise |
| ✅ Citadel v1 live and used by at least 2 clients | Client self-visibility is table-stakes for managed platform |
| ✅ Datapad producing weekly client reports | Demonstrating ROI to clients is the retention mechanism |
| ✅ Client onboarding time < 1 week (playbook executed at least twice) | Repeatability is the P3 scaling prerequisite |
| ✅ Krennic deployed, SLO/error budgets defined | Enterprise SLA enforcement requires SRE agent |
| ✅ P2 Security Onboarding Checklist executed for each active client | Security hygiene at scale |

**Key architectural move:** Per-client Docker isolation + Tier 1 local inference = Nexus becomes a genuine managed multi-tenant platform rather than a customised single-tenant system.

**Risk if rushed:** Skipping Docker isolation and running multiple clients on shared file systems creates credential bleed risk. One agent error in client A's workflow could accidentally read or write to client B's workspace. This is existential for a platform claiming governance-by-design.

**No-over-engineering flag:** Holonet v1 (production-grade real-time data integration) is aspirational P3 work. Holonet v0.1 (configured REST/webhook connectors for 1–2 client systems) is sufficient at the P2→P3 gate. Agent marketplace is entirely P3 work — do not build this in P2.

---

### C3. P3 → P4 Gate (2028)

**Gate name:** Enterprise Credibility Threshold

| Gate Criterion | Why It Matters |
|----------------|----------------|
| ✅ 5–15 concurrent SME client tenants with stable SLAs | Platform at operational scale |
| ✅ ISO/IEC 42001 alignment mapped and gap analysis complete | Enterprise and regulated sector entry requires AI governance credentials |
| ✅ APP compliance documentation complete for all active clients | Legal prerequisite for enterprise Australian clients |
| ✅ Krennic delivering automated runbooks and SLA reports | SRE maturity required for enterprise SLAs |
| ✅ Holonet v1 production-grade with 3+ client system integrations | Enterprise use cases require live data integration |
| ✅ Nexus documented as TOGAF-compliant reference architecture | Consulting credibility asset; training curriculum asset |

**Key architectural move:** Governance layer becomes a market-facing differentiator. The Sanctum + Warden + ISO alignment narrative is the differentiator in regulated sectors where governance is mandatory, not optional.

**Risk if rushed:** Entering enterprise or regulated-sector markets without ISO/IEC 42001 alignment or APP documentation exposes AInchors to compliance risk and client-side audit failures that can terminate engagements mid-flight.

**No-over-engineering flag:** OC3 geographic nodes (MY/GCC) are P4/P5 considerations only. Do not plan infrastructure expansion until there are confirmed client requirements for geographic data residency. Multi-cloud is not a P3 requirement.

---

## D. Immediate 1-Year Plan (Q1–Q4 2026) — Prioritised Architecture Work

*Applying the Shipping vs Generality principle: training/consulting features → ship for current use case; security, governance, multi-client, data sovereignty → design for multi-year reuse.*

---

### Q1 — May to July 2026: Foundation & Hardening

**Theme:** Make OC1 production-grade. Enable Ahsoka. Enforce FinOps. Close S7.

#### 🔴 Must-Do (blocks next phase or client readiness)

| Priority | Item | OKR Link | Rationale |
|----------|------|----------|-----------|
| 1 | **Document generation pipeline** (DOCX/XLSX/PPTX/PDF) | S1-KR2, S2-KR1 | Ahsoka cannot deliver proposals without this. Consulting pillar is blocked. |
| 2 | **FinOps controls: per-agent token budgets + per-workflow cost caps enforced at platform level** | X1, G1 | Cost multiplier risk (R3) is live. Cannot open to clients without safety rails. |
| 3 | **NAS encryption (S7 completion)** | X1-KR4, G1-KR3 | Security control gap must close before OC2 arrival. |
| 4 | **3-2-1+1 backup strategy implementation** (NAS hourly + cloud S3 daily + USB weekly) | X1-KR1 | Current backup is workspace-only. Data loss risk is unacceptable pre-client. |
| 5 | **OC2 deployment playbook in Holocron** | X1-KR4 | OC2 arrives July 2026. TRIGGER-01 sequence must be pre-documented or deployment will be improvised. |
| 6 | **Ahsoka full skills deployment** (research, proposal template, ROI model builder, discovery set) | S1-KR1, S2-KR1/KR2 | Consulting pillar blocked without Ahsoka operational. |
| 7 | **FinOps dashboard** — daily cost report automated, tagged by Tier + workload type | X1, cost management | Cost visibility before client work begins. |

#### 🟡 Should-Do (high value, not blocking)

| Priority | Item | OKR Link |
|----------|------|----------|
| 1 | **Sanctum SLA tracking** — log pass/fail rates, avg review turnaround | G1-KR1, G1-KR2 |
| 2 | **Warden extended monitoring** — detect Tier 2/3 client data routing attempts | G1-KR3 |
| 3 | **Holocron API formalisation** — structured query interface for Ahsoka | X1, S2-KR1 |
| 4 | **Agent SLA metrics baseline** — define what "healthy" looks like per agent | X1-KR3 |
| 5 | **OKR tracking in Notion** — wire OKR IDs to all active backlog items | X2-KR2 |

#### 🟢 Could-Do (defer if capacity constrained)

| Priority | Item | Notes |
|----------|------|-------|
| 1 | Krennic build | Defer to P2. Activation trigger is >2 incidents/week. |
| 2 | Beacon/Datapad consolidation | Defer to Q3. obs.db + health-state.json sufficient for Q1. |
| 3 | Docker multi-tenancy implementation | Begin design in Q1; implement in Q2 after OC2 arrives. |

---

### Q2 — July to August 2026: HIVE Activation & Multi-Client Foundation

**Theme:** Deploy OC2. Activate HIVE HA. Deploy Docker isolation. Activate Tier 1 local inference.

#### 🔴 Must-Do

| Priority | Item | OKR Link | Rationale |
|----------|------|----------|-----------|
| 1 | **OC2-A deployment (TRIGGER-01 sequence)** — Ollama + Gemma4:26b + OpenClaw + Tailscale | X1-KR4 | HIVE HA is the P2 gate prerequisite. |
| 2 | **OC2-B deployment** — Hot standby, Tailscale mesh validated | X1-KR4 | HA requires both nodes. |
| 3 | **Failover test — documented scenario: OC1 offline → OC2-A assumes primary** | X1-KR4 | HA without a validated failover is just expensive redundancy. |
| 4 | **Docker per-client isolation** — 2 SME client environments provisioned (isolated workspace, logging, secrets, Telegram bot, Sanctum flow) | X1-KR2 | Data sovereignty + client credibility requires isolation. |
| 5 | **Tier 1 activation (Gemma4:26b on OC2-A)** — all client workloads migrate to local inference | X1-KR2, G1-KR3 | Data sovereignty rule enforcement requires Tier 1 live before first client data is processed. |
| 6 | **TRIGGER-03 execution** — switch governance agents from Haiku to Gemma4:26b on OC2 | X1, model strategy | Reduces Tier 3 cost exposure; validates Tier 1 governance quality. |

#### 🟡 Should-Do

| Priority | Item | OKR Link |
|----------|------|----------|
| 1 | **Aria migration to OC2-A** (TRIGGER-10) | TOM maturity |
| 2 | **Per-client API key management audit** — confirm no cross-client credential sharing | G1-KR3 |
| 3 | **ITSM SLA definitions** — P1=5min, P2=1hr, P3=next sprint — formalised | ITSM maturity |
| 4 | **Krennic build** | Incident response readiness |

#### 🟢 Could-Do

| Priority | Item | Notes |
|----------|------|-------|
| 1 | Citadel v1 design kick-off | Design only in Q2; build in Q3. |
| 2 | Holonet design | Design only; build in Q4. |

---

### Q3 — September to October 2026: Client Enablement & Observability

**Theme:** Give clients visibility. Prove the platform is managed, not just agentic.

#### 🔴 Must-Do

| Priority | Item | OKR Link | Rationale |
|----------|------|----------|-----------|
| 1 | **The Citadel v1** — per-client dashboard (workflow status, governance records, document access) | X1-KR2, S1-KR3 | Without client visibility, Nexus is a black box. Retention depends on clients seeing value. |
| 2 | **Beacon — unified observability** consolidating obs.db + health-state.json + Warden data | X1-KR3 | Reactive incident detection is not acceptable at multi-client scale. |
| 3 | **Datapad — weekly client reports** (PDF/Notion: agent uptime, cost attribution, governance status, ROI indicators) | X1-KR2, S1-KR3 | Demonstrating ROI is the key consulting retention and upsell trigger. |

#### 🟡 Should-Do

| Priority | Item | OKR Link |
|----------|------|----------|
| 1 | **Holocron — client folder structure** (per-client knowledge partitions for Ahsoka) | S2-KR1 |
| 2 | **Sanctum governance metrics** in Datapad | G1-KR1/KR2 |
| 3 | **PIR closure loop** — link recurring incidents to problem tickets | ITSM maturity |
| 4 | **Second architecture review** — check Q1/Q2 work against OKRs | X2-KR3 |

#### 🟢 Could-Do

| Priority | Item | Notes |
|----------|------|-------|
| 1 | Holonet v0.1 early design | Design artefact only; build in Q4. |
| 2 | Agent marketplace (internal) design | P3 concept; design only if time allows. |

---

### Q4 — November 2026 to January 2027: Consolidation & P3 Readiness

**Theme:** Make client onboarding repeatable. Connect to real client data. Security audit. P3 gate prep.

#### 🔴 Must-Do

| Priority | Item | OKR Link | Rationale |
|----------|------|----------|-----------|
| 1 | **Client onboarding playbook** — automated sequence: Docker provisioning → Telegram bot → Sanctum config → Citadel access → Holocron folder | X1-KR2, S1 | Target: <1 week from contract to first live agent workflow. Repeatability is the P3 gate. |
| 2 | **ITSM client-facing** — SLA reports and CHG/INC visibility via Citadel | ITSM maturity | ITSM-grade operations must become client-visible; it is the differentiation story. |
| 3 | **S1–S7 multi-client security audit** — confirm no credential bleed, Warden covers all client tenants, APP compliance draft | G1-KR3, X1-KR2 | Security must be re-audited after multi-client deployment. |
| 4 | **P2 Client Security Onboarding Checklist** (Lex + Shield approved) | G1 | Required before P3 client volume scales. |
| 5 | **P3 readiness review** — platform capable of supporting 5+ concurrent SME clients | X2-KR1 | The P2→P3 gate criteria must be formally assessed before committing to P3 work. |

#### 🟡 Should-Do

| Priority | Item | OKR Link |
|----------|------|----------|
| 1 | **Holonet v0.1** — 1 client system connected (CRM or Google Workspace) to a live agent workflow | X1-KR2 |
| 2 | **APP compliance draft** for all active clients | G1 |
| 3 | **Retrospective + OKR review** — did we meet C1, X1, X2? | All |

#### 🟢 Could-Do

| Priority | Item | Notes |
|----------|------|-------|
| 1 | ISO/IEC 42001 gap analysis | Begin in Q4 if capacity allows; P3 requirement. |
| 2 | Citadel v2 design | P3 build; design concept in Q4. |

---

## E. Architecture Decision Register (ADR)

### ADR-001 — OpenClaw as Agent Framework (Final)

| Field | Detail |
|-------|--------|
| **Decision** | OpenClaw is the permanent agentic operations framework. No replatforming. |
| **Context** | Framework selection made at inception (Day 1, 2026-04-25). Evaluated against CrewAI, LangGraph, custom orchestration. |
| **Decision Made** | OpenClaw selected. Final. Confirmed 2026-04-25. |
| **Rationale** | Native multi-agent, self-hosted, extensible skills architecture, community-aligned, loopback-only security posture. Best fit for SME-scale, always-on, low-power operations. |
| **Alternatives Considered** | CrewAI (more complex orchestration, enterprise overhead), LangGraph (code-first, less operator-friendly), custom (too much build burden for a 2-person founding team). |
| **Review Trigger** | TRIGGER-06: OpenClaw v4.0 ships → P3 gate assessment. Reassess at P3 whether OpenClaw native multi-tenancy has matured enough to replace Docker isolation. |

---

### ADR-002 — HIVE: Mac Mini M4 Pro 48GB × 2 for OC2

| Field | Detail |
|-------|--------|
| **Decision** | OC2-A and OC2-B will be Mac Mini M4 Pro 48GB each. ETA July 2026. |
| **Context** | OC1 (M4 24GB) cannot run Gemma4:26b (Tier 1) at viable inference speed. HA requires a second node. Budget and power constraints favour Mac Mini form factor. |
| **Decision Made** | Confirmed by Ken. Hardware ordered. |
| **Rationale** | M4 Pro 48GB runs Gemma4:26b at viable inference speeds and handles 70B-class models. Low-power, always-on, cost-efficient for 24/7 hosting. Best price/performance for this use case. |
| **Alternatives Considered** | Cloud GPU instance (ongoing cost, data sovereignty risk), NVIDIA workstation (cost, form factor, power), M4 Max (overkill for current use case). |
| **Review Trigger** | OC3 consideration at P3/P4 threshold. If geographic data residency for MY/GCC clients is required, evaluate co-lo or in-country node options. |

---

### ADR-003 — Docker for Multi-Client Tenant Isolation

| Field | Detail |
|-------|--------|
| **Decision** | Per-client environment isolation using Docker containers on Nexus. |
| **Context** | Multiple SME clients on a single Nexus gateway creates credential bleed risk and violates data sovereignty principles if workspaces are not isolated. |
| **Decision Made** | Docker selected as isolation mechanism. Implementation target: Q2 2026. |
| **Rationale** | Docker provides filesystem, process, network, and credential isolation per client. Operationally understood. Compatible with OpenClaw server deployment model. Established pattern for OpenClaw multi-tenant deployments. |
| **Alternatives Considered** | VM per client (overhead, resource cost, management complexity), OpenClaw native multi-tenancy (not yet production-ready per GitHub issue #61123), single gateway with config switching (insufficient isolation for data sovereignty guarantees). |
| **Review Trigger** | Reassess at P3 if OpenClaw native multi-tenancy matures (TRIGGER-06). If OpenClaw v4.0 ships native multi-tenancy with network-level isolation, Docker approach may be superseded. |

---

### ADR-004 — Tier 1 Local Inference for All Client Workloads

| Field | Detail |
|-------|--------|
| **Decision** | All client-data-touching workloads must run on Tier 0 (no LLM) or Tier 1 (Gemma4:26b local on OC2-A). Tier 2/3 cloud APIs are prohibited for client data. |
| **Context** | Data sovereignty is a non-negotiable strategic principle. SME clients in AU/MY/GCC have regulatory and reputational requirements that prohibit client data from leaving their nominated jurisdiction. |
| **Decision Made** | Confirmed. Enforced via Warden DS-1 to DS-5 controls. Tier 1 activation is a P1→P2 gate criterion. |
| **Rationale** | Local inference eliminates cloud data exposure risk. Gemma4:26b on M4 Pro 48GB meets performance thresholds for governance and client workflow tasks. Zero marginal cost at Tier 1. |
| **Alternatives Considered** | Client-specific cloud API key with data processing agreement (legally complex, contractually fragile, trust risk), private cloud deployment (cost and complexity beyond P1/P2 budget). |
| **Review Trigger** | Monthly model strategy review (28th). If a future local model surpasses Gemma4:26b on the OC2 hardware profile, evaluate migration. If OC3 is deployed, extend Tier 1 policy to OC3 nodes. |

---

### ADR-005 — Tailscale for Remote Access (Zero-Trust Mesh)

| Field | Detail |
|-------|--------|
| **Decision** | Tailscale is the remote access and inter-node mesh solution. Gateway binds to loopback only (S2 control). |
| **Context** | OC1 gateway must never be publicly accessible. Remote access required for Ken (and eventually Angie). Inter-node communication (OC1 ↔ OC2-A ↔ OC2-B ↔ NAS) requires a trusted mesh. |
| **Decision Made** | Tailscale selected. S2 implemented. TRIGGER-02 will validate mesh across all HIVE nodes. |
| **Rationale** | Zero-trust, loopback-binding-only, no exposed public port. Industry-standard for self-hosted private AI infrastructure. Supports S2 compliance cleanly. |
| **Alternatives Considered** | WireGuard (manual key management complexity), OpenVPN (higher overhead), public tunnel (violates S2). |
| **Review Trigger** | Annual security review. Reassess if Tailscale pricing or security posture changes materially. |

---

### ADR-006 — Notion Holocron as SSOT (Obsidian Retired)

| Field | Detail |
|-------|--------|
| **Decision** | Notion is the single knowledge base (Holocron). Obsidian is retired. |
| **Context** | Obsidian was the original knowledge base but lacked API-first access for agents and was not accessible by Angie. Obsidian retirement completed 2026-05-05 (TKT-0042 closed, 38 pages migrated, 5 phases complete). |
| **Decision Made** | Notion SSOT confirmed 2026-05-04. Locked. |
| **Rationale** | Notion API enables programmatic agent queries. Collaborative access for both Ken and Angie. Structured databases for backlog, incidents, assets, decisions. AKB daily cron writes to Notion-only. |
| **Alternatives Considered** | Keeping Obsidian (lacks API-first access, Angie cannot access), GitHub Wiki (not structured enough for operational data), custom database (build cost). |
| **Review Trigger** | If Notion API limitations emerge (rate limits, schema constraints) that block agent access at P3 client scale, evaluate migration to a more API-native knowledge base. |

---

### ADR-007 — 4-Tier Model Strategy (FinOps + Data Sovereignty)

| Field | Detail |
|-------|--------|
| **Decision** | Four-tier model routing: Tier 0 (no LLM) → Tier 1 (Gemma4:26b local, OC2) → Tier 2 (Ollama Cloud: kimi-k2.6 / AInchors-only) → Tier 3 (Claude Sonnet 4.6 / fallback). |
| **Context** | Agentic AI has 100–1,000× cost multiplier potential. Multi-step chains can exhaust budgets rapidly. Data sovereignty requires client data never reaches Tier 2/3. |
| **Decision Made** | Tier 2 activated (TRIGGER-05, 2026-05-02). Full 4-tier pending OC2 July 2026. Budget cap: A$500/month (alert at A$400). |
| **Rationale** | FinOps-by-design. Zero marginal cost at Tier 0/1. Flat-fee at Tier 2. Pay-per-token at Tier 3 reserved for high-stakes reasoning only. Warden enforces compliance. |
| **Alternatives Considered** | Single-tier (cloud-only) — cost and sovereignty risk too high. On-prem only (Tier 3 quality gap for complex tasks). |
| **Review Trigger** | Monthly review (28th). Quarterly model CI review (Cycle A/B). Budget cap review when Angie formally approves. |

---

### ADR-008 — TOGAF ADM as EA Framework

| Field | Detail |
|-------|--------|
| **Decision** | TOGAF ADM is the enterprise architecture framework for Auralith / Nexus. Atlas is the EA owner. |
| **Context** | Structured EA framework needed to manage complexity across 5 domains, 4+ phases, and a 5-year technology transformation. Ken and Atlas confirmed TOGAF fit. |
| **Decision Made** | Confirmed. This document is the Phase A–F output. |
| **Rationale** | Industry standard for structured AI transformation architecture. Aligns with ISO/IEC 42001 path at P3/P4. Produces traceable, auditable decisions. Suitable for enterprise client credentialing. |
| **Alternatives Considered** | Zachman (too rigid for an agile startup), SAFe architecture (process overhead excessive), informal roadmap (insufficient for P3 enterprise positioning). |
| **Review Trigger** | Atlas to assess TOGAF fit at P3 for ISO 42001 alignment. Reassess framework if OpenClaw publishes an OpenClaw-native EA pattern. |

---

## F. Risks and Mitigations

| # | Risk Description | Likelihood | Impact | Current Mitigation | Recommended Additional Action |
|---|-----------------|------------|--------|-------------------|-------------------------------|
| **R1** | **Single-node failure (OC1)** — all 12 agents offline; all client work and AInchors operations halted; no failover. | H | H | OC2 ordered. TRIGGER-01 documented. | **Execute TRIGGER-01 sequence as first priority when OC2 arrives July 2026.** Do not take on P2 clients before HIVE is live and failover is tested. |
| **R2** | **Multi-tenancy not implemented** — manual per-client config; no Docker isolation; credential bleed risk between clients. | H | H | Docker plan defined. Not yet implemented. | **Begin Docker architecture design in Q1; implement immediately in Q2 post-OC2 delivery.** Do not onboard more than 1 client to OC1 pre-isolation. |
| **R3** | **Agentic cost multiplier** — multi-step chains generate 100–1,000× cost spikes vs single API calls; no platform-level enforcement of token budgets or workflow caps. | M | H | Conceptual caps exist. A$500/month budget + A$400 alert active. | **Implement per-agent token budgets and per-workflow cost caps in Nexus agent execution layer in Q1. Tag all costs by Tier + workload type. This is a must-do before P2 client work.** |
| **R4** | **No unified observability** — ops state split across obs.db, health-state.json, Warden files; incidents detected reactively. | H | M | Warden 15-min checks, health monitoring active, auto-heal nightly. | **Beacon/Datapad consolidation is a Q3 must-do. Interim: ensure Warden escalation → Telegram alert chain is reliable for all critical checks.** |
| **R5** | **Document generation pipeline missing** — Ahsoka cannot produce proposals or business cases; consulting pillar revenue is blocked. | H | H | Pipeline planned. Skills partially designed. | **This is Q1 Priority #1 architecture build. No consulting revenue until this is live.** |
| **R6** | **Data sovereignty breach** — a misconfiguration routes client data to Tier 2/3 cloud APIs; reputational and legal exposure. | L | H | Warden DS-1 to DS-5 checks. Tier 2/3 = AInchors-only policy confirmed. Tier 1 (local) not yet live for client workloads. | **Activate Tier 1 on OC2 before processing any real client data. Extend Warden to alert on any client-identified workload attempting Tier 2/3 routing.** |
| **R7** | **Governance bypass** — a time-pressured engagement causes Ahsoka to send a proposal or external output without completing Shield → Lex → Sage review. | M | M | Sanctum mandatory for all Ahsoka outputs. Rule confirmed (S2-KR2: 100% of proposals through Sanctum). | **Wire Sanctum gate as a hard technical dependency in Ahsoka's workflow, not a cultural norm. Log every Sanctum review and flag any bypass attempts to Warden. Add Sanctum review SLA tracking in Q1.** |
| **R8** | **OC2 deployment delay or failure** — OC2 hardware arrives but TRIGGER-01 sequence fails or is delayed; P1→P2 gate is missed; clients wait. | M | H | TRIGGER-01 documented as a CHG trigger. OC2 deployment playbook is a Q1 must-do. | **Complete OC2 deployment playbook in Holocron by end of Q1. Assign OC2 deployment as a dedicated sprint when hardware confirms arrival date. Pre-test TRIGGER-01 steps on OC1 where possible.** |

---

## Atlas Notes — Architecture Principles Summary

These principles should be referenced in all future architecture decisions:

1. **Business-outcome-first:** Every platform capability maps to a pillar (Training / Consulting / Technology) and an OKR. No orphan capabilities.
2. **Governance-by-design:** Sanctum and Warden are non-negotiable. Never treated as optional modules.
3. **Data sovereignty non-negotiable:** Client data never leaves Tier 0/1 local infrastructure. This is the product's differentiation story, not just a compliance checkbox.
4. **Shipping vs generality (context-dependent):** Training/consulting features → ship for specific use case. Security, governance, multi-client isolation → design for multi-year reuse.
5. **FinOps-first:** Every agent workflow has token budgets. Every workflow type has cost caps. Cost visibility is operational hygiene, not a reporting exercise.
6. **ITSM-grade from day one:** CHG records, incident management, SLA tracking are native — not retrofitted. These become client-facing differentiators in P2.
7. **OpenClaw-committed:** Extend the platform; don't fight it. Evaluate alternatives only at defined TRIGGER points.
8. **No over-engineering in P1:** If a capability is not blocking the P1→P2 gate or a live client need, defer it. The Citadel, Beacon, Holonet are all Q3+ for a reason.

---

## Appendix: Phase Summary at a Glance

| Phase | Period | Theme | Key Architectural Move | P Readiness Gate |
|-------|--------|-------|----------------------|-----------------|
| P1 | Now → July 2026 | Foundation | OC1 hardened, Ahsoka live, FinOps enforced, doc gen pipeline built | HIVE live + 1 client isolated + Tier 1 active |
| P2 | Jul 2026 → Jan 2027 | HIVE + Multi-Tenancy | OC2-A/B deployed, Docker isolation, Tier 1 client workloads, Citadel v1 | 3 clients live, onboarding <1 week, Citadel live |
| P3 | 2027 | Managed Platform at Scale | Agent marketplace, Holonet v1, Citadel v2, ISO 42001 mapping | 5–15 clients, SLAs enforced, TOGAF reference architecture |
| P4 | 2028–2029 | Enterprise Credibility | ISO/IEC 42001 alignment, regulated sector entry, Krennic mature SRE | ISO alignment complete, APP documented, enterprise SLAs |
| P5 | 2030–2031 | Platform Company Option | OC3 geographic nodes (MY/GCC), Nexus Academy, external tenants option | Ken/Angie strategic decision point |

---

*Document: `state/tkt-0086-step3-atlas-roadmap.md` | Produced by Atlas 🏛️ | TKT-0086 Step 3 | 2026-05-07*
*Next step: Step 4 — Backlog replan (Yoda to execute against this roadmap)*
