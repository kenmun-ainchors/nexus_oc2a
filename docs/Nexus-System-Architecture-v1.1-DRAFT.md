# Nexus Platform — System Architecture Document
## v1.1 | Internal Reference — DRAFT FOR REVIEW

**Classification: INTERNAL — Aevlith Technologies / AInchors**
**Status: DRAFT FOR REVIEW ⚠️ (Not approved — do not build against)**
**Author: Atlas 🏛️ — Enterprise Architect**
**Date: 2026-07-09 | Platform Day ~76**
**CHG-0852 (Holocron Refresh)**

---

> **Supersedes:** Nexus-System-Architecture-v1.0.md (2026-05-14, approved by Ken Mun). This document is a **delta refresh** as part of the Holocron Refresh project (P006, CHG-0852). All material changes are catalogued in Appendix D.
>
> **Golden rule:** Read this before designing, building, or modifying any Nexus platform component. All agents must treat this as the binding architectural reference.

---

## Table of Contents

1. [Document Purpose & How to Use](#1-document-purpose--how-to-use)
2. [Platform Overview](#2-platform-overview)
3. [Agent Architecture](#3-agent-architecture)
4. [Infrastructure Architecture](#4-infrastructure-architecture)
5. [Data Architecture](#5-data-architecture)
6. [Integration Architecture](#6-integration-architecture)
7. [Component Map](#7-component-map)
8. [Security Architecture](#8-security-architecture)
9. [Gap Map — Current → Target](#9-gap-map--current--target)
10. [Architecture Decision Log Reference](#10-architecture-decision-log-reference)

---

## 1. Document Purpose & How to Use

### 1.1 What This Document Is

This document is the authoritative system architecture reference for the Nexus platform — the agentic AI operations platform owned by Aevlith Technologies and market-operated by AInchors.

It is the **golden blueprint** for all architectural decisions across:
- Agent design, routing, and model configuration
- Infrastructure deployment and scaling
- Data governance, storage, and lineage
- Integration patterns between agents and external systems
- Security controls and compliance readiness

### 1.2 Who Must Read This

- **All agents** producing architecture, platform, or integration decisions (Atlas, Thrawn, Forge)
- **Yoda** — before routing any task that touches platform structure
- **Ken Mun (CTO)** — primary approver and owner of all decisions documented here

### 1.3 Scope

| In Scope | Out of Scope |
|----------|-------------|
| Current state (Day ~76, 2026-07-09) | P2+ multi-tenant implementation detail |
| Target state (Option B Phased, approved CHG-0308) | Client-specific agent configurations |
| Gap map: current → target | Business process design (→ Lando) |
| All 14 active agents and their configs | Content strategies (→ Spark / Aria / Luthen) |
| All infrastructure (OC1, OC2 plan, networking, storage) | Consulting delivery methodology (→ Ahsoka) |
| Security controls S1–S7 | Legal agreements and terms |

### 1.4 Living Document Cadence

**Owner:** Atlas 🏛️ (refresh + summary) | **Approver:** Ken Mun (CTO)

**This section is enforced. Non-negotiable.**

#### Mandatory Review Triggers (P1-P4 Stage Checkpoints)

| Trigger | Condition | Action |
|---|---|---|
| **P1→P2 Checkpoint** | P2 launch (first SME client onboarded, target Aug 2026) | Atlas: full document refresh + delta summary → Ken review + approval before P2 ops begin |
| **P2→P4 Checkpoint** | TRIGGER-14 fires (post-P2 stable, event sourcing design begins) | Atlas: full document refresh + Phase 3/4 target architecture update → Ken review |
| **P4 Entry** | First FSI/Enterprise engagement confirmed | Atlas: full document refresh with APRA/FSI architecture additions → Ken review |
| **Annual Review** | Every May (platform anniversary month) | Atlas: full document review against live state, prune stale content, confirm locked decisions still hold → Ken approval |

#### Continuous Updates (Yoda — between checkpoints)
Yoda updates the following fields at each sprint review without requiring Ken approval:
- Gap map status (Section 9) — tick off completed items, update ticket references
- KRI dashboard reference — link to current KRI state
- Sprint plan table — reflect current sprint progress
- Agent roster — add new agents, update model config if changed via approved CHG

#### Atlas Refresh Deliverable (at each P1-P4 checkpoint)
Atlas produces a **Architecture Delta Summary** for Ken containing:
1. What changed since last approved version (new components, deprecated items, new locked decisions)
2. What sections were updated and why
3. Any locked decisions that need re-evaluation
4. Recommended approvals for Ken to make before proceeding to next phase

Delivery: via webchat + Telegram summary. Ken replies APPROVED or requests changes before next phase work begins.

#### CHG Gate
Significant architectural changes (new agents, infrastructure changes, locked decision updates) must be recorded via CHG before implementation. Ken approves all updates that touch locked decisions.

### 1.5 Status Definitions

- **DRAFT FOR REVIEW** — Not approved. Do not build against this.
- **APPROVED** — Ken has explicitly approved. Binding.
- **LOCKED** — Irreversible decision. Locked decisions can only be re-opened with Ken's explicit instruction and a new CHG record.

---

## 2. Platform Overview

### 2.1 What Nexus Is

Nexus is Aevlith Technologies' agentic AI operations platform — the technical core that powers AInchors' AI training, consulting (Ahsoka), and technology-as-a-service offerings. It is simultaneously:

1. **An internal operations platform** (P1 — current): **14 active agents** orchestrate AInchors' own business operations across technical architecture, social marketing, business process, content, governance, and infrastructure.

2. **A deployable product** (P2–P4): The same architecture is designed from day one to become a commercially-deployed SaaS (P2, target August 2026), with expansion to enterprise/FSI consulting deployments (P4).

The business IS the demo. AInchors' own operations — two founders, 14 agents, full-stack AI operations — is the proof of concept. The platform must be demonstrably production-grade at all times.

### 2.2 Deployment Status (Day ~76)

| Dimension | Current State |
|-----------|--------------|
| Primary node | OC1 — Mac Mini M4 24GB, Melbourne |
| Runtime | OpenClaw v2026.5.5 (final platform — no replatforming) |
| Active agents | **14** (up from 12) |
| Change records | **850+** (up from 230+) |
| Platform availability | 97.46%+ historical |
| Day count | Day ~76 (2026-04-25 → 2026-07-09) |
| Postgres (PG) | **LIVE** — SSOT-first adopted 2026-05-23; state_changes table canonical for CHGs |
| Web search provider | **DuckDuckGo** (approved CHG-0844) |
| CREST | **v1.3** approved 2026-06-20 (CHG-0680); Sage-as-Judge, capability-based multi-model routing, PG SSOT |

### 2.3 Phase Structure (LOCKED — CHG-0234)

| Phase | Label | Timeline | Status |
|-------|-------|----------|--------|
| **P1** | Internal Single-Tenant | Now (OC1, AInchors internal) | LIVE |
| **P2** | SaaS Multi-Tenant from day one | ~August 2026 | Building |
| **P3** | Commercial Tier (within P2) | Feature flag on P2 | Not yet unlocked |
| **P4** | Enterprise / FSI Consulting | Post-P2 stable | Future |

> **P3 as a build phase is DROPPED (CHG-0234).** P3 is a commercial tier label within P2 — a feature flag for company/multi-agent capability. Not a separate infrastructure phase.

### 2.4 Corporate Structure

| Entity | Role |
|--------|------|
| **Ainchor Solutions Pty Ltd** | Market-facing brand (AInchors). Domain: ainchors.com |
| **Aevlith Technologies Pty Ltd** | Technology holding entity. Owns Nexus. Domain: aevlith.ai. Silent in P1–P3; surfaces as product brand at P4. |

### 2.5 Architecture Direction (APPROVED — CHG-0308, 2026-05-14)

**Decision: Option B — Phased Delivery**

Redesign the data and integration layers while keeping OpenClaw and the agent model. Three phases:

- **Phase 1** (Sprints 4–8, by ~8 Jun 2026): Postgres + 5-tier schema, Three Work Types Rule, Sources of Truth Register, JSON→Postgres migration (5 files), Event Bus, Typed Contracts (4 handoffs), PII Scanner, RAG pipeline.
- **Phase 2** (Post-P2 +2 weeks): Redis, multi-tenant RLS, Holonet v0, Citadel v0.
- **Phase 3** (TRIGGER-14, post-P2 stable): Event sourcing, WORM audit, APRA CPG 234/235 full compliance.

### 2.6 Active Projects (P006+)

| Project | ID | Status |
|---------|----|--------|
| P001 — AI Agent Foundation | Foundation | Live |
| P002 — CRESTv2-P1 | In progress | Active |
| P003 — PG SSOT Gap Remediation | Active | Active |
| P004 — OC2 Commissioning | Pre-commissioning | Awaiting hardware |
| P005 — LinkedIn Campaign | Live | Active |
| P006 — Holocron Refresh | Active | CHG-0852 (this document) |

---

## 3. Agent Architecture

### 3.1 Governance Tier Model

The Nexus agent governance hierarchy is a five-tier model defining authority, communication patterns, and operational scope. Approved by Ken Mun, 2026-05-08 (TKT-0103). **Updated 2026-07-09:** Tier assignments refined for 14-agent roster.

| Tier | Agent | Role | Authority Model |
|------|-------|------|----------------|
| **T0** | Yoda 🟢 | Lead Orchestrator | Full platform authority. Classifies, routes, quality-gates, presents decisions. Does NOT execute specialist work. |
| **T1** | Aria 🔵 | Business Lead | Dual-principal: reports to CEO (Angie) AND Yoda. Leads business stream. Full AInchors data read access. |
| **T2** | Warden 🔍 | Model Compliance Monitor | Yoda-Governed. 15-min autonomous monitoring cycle. Reads agent configs; never acts directly. Reports only. |
| **T3** | Spark ✨, Atlas 🏛️, Thrawn, Lando 🟡, Forge 🏗️, Mon Mothma 🌟, Ahsoka 🤍, Luthen 🧠 | Specialist Agents | Yoda-Manage-Passthrough. Execute specialist work in their domain. |
| **T4** | Shield 🛡️, Lex ⚖️, Sage 🧪 | Sanctum Triad | Reactive verdict-only. Never initiate work. Shield → Lex → Sage gate sequence for all external outputs. |

**Note:** Krennic (planned platform engineering specialist) is parked — not yet activated.

> **Key constraint:** Yoda orchestrates. Yoda does NOT execute specialist work directly. Routing to the wrong tier is a governance failure.

### 3.2 Agent Roster — All 14 Active Agents

Agent configurations are read from `/Users/ainchorsangiefpl/.openclaw/openclaw.json`. The following table reflects actual configurations as of Day ~76.

**Important model migration note:** Since v1.0, the platform has migrated from Anthropic Claude as the primary model tier to **Ollama Cloud** models (kimi-k2.7-code, deepseek-v4-pro, deepseek-v4-flash, gemma4:31b-cloud). This is a significant architectural shift — see Section 10 for locked decisions.

#### T0 — Yoda 🟢 (Lead Orchestrator)

| Attribute | Value |
|-----------|-------|
| Agent ID | `main` |
| Display Name | Yoda 🟢 |
| Primary Model | `ollama/kimi-k2.7-code:cloud` |
| Fallbacks | `ollama/deepseek-v4-pro:cloud` → `ollama/deepseek-v4-flash:cloud` → `ollama/kimi-k2.6:cloud` |
| Stream | Cross-stream (orchestration) |
| Workspace | `/Users/ainchorsangiefpl/.openclaw/workspace` |
| SOUL Location | `workspace/SOUL.md` |
| Key Responsibilities | Platform situational awareness, task classification and routing, quality-gating, HITL gates, incident response coordination, CHG discipline, context handoff |
| Heartbeat | `target: none`, isolated session |

#### T1 — Aria 🔵 (Business Lead)

| Attribute | Value |
|-----------|-------|
| Agent ID | `business` |
| Display Name | Aria 🔵 |
| Primary Model | `ollama/kimi-k2.7-code:cloud` |
| Fallbacks | `ollama/deepseek-v4-pro:cloud` → `ollama/deepseek-v4-flash:cloud` → `ollama/kimi-k2.6:cloud` |
| Stream | Business (Angie-facing) |
| Workspace | `/Users/ainchorsangiefpl/.openclaw/workspace-business` |
| Key Responsibilities | Business stream lead, Angie's AI ops partner, social strategy coordination, marketing oversight, Spark coordination |
| Notes | Migrating to OC2-A at TRIGGER-10. Dual-principal: CEO + Yoda. |
| Heartbeat | `target: none`, isolated session |

#### T2 — Warden 🔍 (Model Compliance Monitor)

| Attribute | Value |
|-----------|-------|
| Agent ID | `governance` |
| Display Name | Warden 🔍 |
| Session | Background cron |
| Primary Model | `ollama/gemma4:31b-cloud` |
| Fallbacks | `ollama/deepseek-v4-pro:cloud` → `ollama/kimi-k2.6:cloud` |
| Stream | Governance (cross-stream) |
| Workspace | `/Users/ainchorsangiefpl/.openclaw/workspace-governance` |
| Key Responsibilities | Checks all agents for model drift and compliance. Never acts directly — writes violations and escalates to Yoda. |
| Tools | `read`, `write`, `exec` only |

#### T3 — Spark ✨ (Social Marketing Agent)

| Attribute | Value |
|-----------|-------|
| Agent ID | `social` |
| Display Name | Spark ✨ — Social & Content Marketing |
| Primary Model | `ollama/deepseek-v4-flash:cloud` |
| Fallbacks | `ollama/gemma4:31b-cloud` → `ollama/deepseek-v4-pro:cloud` |
| Stream | Business / Social |
| Key Responsibilities | LinkedIn, Instagram, Facebook, YouTube content creation and scheduling. AIOps campaign management. Content governance review. |
| Key Constraint | Post cancellation must update queue state AND delete cron. Never verbal-only acknowledgement (L-027). |

#### T3 — Atlas 🏛️ (Enterprise Architect)

| Attribute | Value |
|-----------|-------|
| Agent ID | `architect` |
| Display Name | Atlas 🏛️ — Enterprise Architect |
| Primary Model | `ollama/deepseek-v4-flash:cloud` |
| Fallbacks | `ollama/gemma4:31b-cloud` → `ollama/kimi-k2.6:cloud` |
| Stream | Technical |
| Workspace | `/Users/ainchorsangiefpl/.openclaw/workspace-architect` |
| Key Responsibilities | Enterprise architecture (TOGAF), P1–P4 architecture design, cross-platform landscape, data architecture, option papers, architecture decision log, integration architecture |
| CREST Role | `design_backend` — CREST v1.3 compliant (CHG-0680) |
| Boundary with Thrawn | Atlas sets enterprise-facing architectural constraints. Thrawn implements platform-internal architecture. Atlas does NOT build or run scripts (→ Forge). |

#### T3 — Thrawn (AI Platform Architect)

| Attribute | Value |
|-----------|-------|
| Agent ID | `platform-arch` |
| Display Name | Thrawn — AI Platform Architect |
| Primary Model | `ollama/deepseek-v4-flash:cloud` |
| Fallbacks | `ollama/gemma4:31b-cloud` → `ollama/kimi-k2.6:cloud` |
| Stream | Technical |
| Key Responsibilities | Nexus platform architecture (model strategy, S1–S7 security controls, OpenClaw configuration, agent deployment design, multi-tenant isolation design, OC2 architecture) |
| Boundary with Atlas | Thrawn designs platform-internal. Atlas designs enterprise-facing. Conflict → Atlas sets constraints, Thrawn implements within them. |
| Note | NEVER route build/scripts to Thrawn. Build → Forge ONLY (L-026). |

#### T3 — Lando 🟡 (Business Process Specialist)

| Attribute | Value |
|-----------|-------|
| Agent ID | `biz-process` |
| Display Name | Lando 🟡 — Business Process Specialist |
| Primary Model | `ollama/deepseek-v4-pro:cloud` |
| Fallbacks | `ollama/gemma4:31b-cloud` → `ollama/kimi-k2.6:cloud` → `ollama/deepseek-v4-flash:cloud` |
| Stream | Business |
| Key Responsibilities | BPM, BPMN process design, workflow optimisation, business process documentation |

#### T3 — Forge 🏗️ (Infrastructure & SRE)

| Attribute | Value |
|-----------|-------|
| Agent ID | `infra` |
| Display Name | Forge 🏗️ |
| Primary Model | `ollama/deepseek-v4-flash:cloud` |
| Fallbacks | `ollama/gemma4:31b-cloud` → `ollama/kimi-k2.6:cloud` |
| Stream | Technical |
| Workspace | `/Users/ainchorsangiefpl/.openclaw/workspace` |
| Key Responsibilities | Infrastructure builds, scripts, CI/CD, SRE, health checks, backups, auto-heal, diagnostics. **All build and script work routes here.** |
| Tools | `read`, `write`, `edit`, `exec`, `process` |
| Note | Only agent authorised to execute build and infrastructure work. L-026 enforces this. |

#### T3 — Mon Mothma 🌟 (Change Management)

| Attribute | Value |
|-----------|-------|
| Agent ID | `change-mgt` |
| Display Name | Mon Mothma 🌟 — Digital Transformation CM Specialist |
| Primary Model | `ollama/deepseek-v4-pro:cloud` |
| Fallbacks | `ollama/gemma4:31b-cloud` → `ollama/kimi-k2.6:cloud` → `ollama/deepseek-v4-flash:cloud` |
| Stream | Business / Governance |
| Key Responsibilities | ADKAR methodology, change management plans, stakeholder adoption, digital transformation strategy |

#### T3 — Ahsoka 🤍 (AI Transformation Consultant)

| Attribute | Value |
|-----------|-------|
| Agent ID | `ahsoka` |
| Display Name | Ahsoka 🤍 — AI Transformation Consultant |
| Primary Model | `ollama/deepseek-v4-pro:cloud` |
| Fallbacks | `ollama/gemma4:31b-cloud` → `ollama/kimi-k2.6:cloud` → `ollama/deepseek-v4-flash:cloud` |
| Stream | Consulting |
| Key Responsibilities | Client discovery, proposals, business cases, AI transformation consulting delivery |
| Note | Consulting stream lead. Ahsoka leads → P4 delivery. Aevlith/partnership pending (TKT-0114). |

#### T3 — Luthen 🧠 (Marketing Intelligence) — **NEW**

| Attribute | Value |
|-----------|-------|
| Agent ID | `luthen` |
| Display Name | Luthen — Marketing Intelligence |
| Primary Model | `ollama/deepseek-v4-pro:cloud` |
| Fallbacks | `ollama/gemma4:31b-cloud` → `ollama/kimi-k2.6:cloud` → `ollama/deepseek-v4-flash:cloud` |
| Stream | Business |
| Workspace | `/Users/ainchorsangiefpl/.openclaw/workspace-luthen` |
| Key Responsibilities | Marketing intelligence, campaign analytics, audience insights, content performance analysis, competitive intelligence |
| Note | Added post-v1.0. Complements Spark's content creation with analytical intelligence layer. |

#### T4 — Shield 🛡️ (Security Agent)

| Attribute | Value |
|-----------|-------|
| Agent ID | `security` |
| Display Name | Shield 🛡️ |
| Primary Model | `ollama/gemma4:31b-cloud` |
| Fallbacks | `ollama/deepseek-v4-pro:cloud` → `ollama/kimi-k2.6:cloud` |
| Stream | Governance (Sanctum Triad) |
| Workspace | `/Users/ainchorsangiefpl/.openclaw/workspace-security` |
| Key Responsibilities | Content security review (first gate in Sanctum). Pre-publish security scan for all external outputs. |
| Tools | `read`, `exec`, `web_search`, `web_fetch` only |
| RULES | `SHIELD_RULE_1.md` |

#### T4 — Lex ⚖️ (Legal / Compliance)

| Attribute | Value |
|-----------|-------|
| Agent ID | `legal` |
| Display Name | Lex ⚖️ |
| Primary Model | `ollama/gemma4:31b-cloud` |
| Fallbacks | `ollama/deepseek-v4-pro:cloud` → `ollama/kimi-k2.6:cloud` |
| Stream | Governance (Sanctum Triad) |
| Workspace | `/Users/ainchorsangiefpl/.openclaw/workspace-legal` |
| Key Responsibilities | AU law, APP compliance, platform ToS review (second gate in Sanctum). Legal/compliance flag check for all external outputs. |
| Tools | `read`, `web_search`, `web_fetch` only |
| RULES | `LEX_RULES.md` |

#### T4 — Sage 🧪 (Quality Assurance)

| Attribute | Value |
|-----------|-------|
| Agent ID | `qa` |
| Display Name | Sage 🧪 |
| Primary Model | `ollama/gemma4:31b-cloud` |
| Fallbacks | `ollama/deepseek-v4-pro:cloud` → `ollama/kimi-k2.6:cloud` |
| Stream | Governance (Sanctum Triad) |
| Workspace | `/Users/ainchorsangiefpl/.openclaw/workspace-qa` |
| Key Responsibilities | Source verification, definition-of-done, quality gate (third gate in Sanctum). Final quality check before external delivery. CREST v1.3 Judge role. |
| Tools | `read`, `exec`, `process`, `web_search`, `web_fetch` |
| RULES | `SAGE_RULES.md` |

#### Parked Agents

| Agent | ID | Role | Notes |
|-------|-----|------|-------|
| Krennic | `platform-eng` | Platform Engineering Specialist | Parked — not activated. Role would be platform engineering, Kubernetes, CI/CD pipeline. |

### 3.3 Model Fallback Chain Policy (LOCKED — CHG-0270, superseded by CHG-0812)

**⚠️ NOTE:** The original Kimi Safety Net Rule (CHG-0270) has been **superseded** by the capability-based multi-model routing policy approved in **CHG-0812** (2026-07-03) and codified in `model_policy.json v3.0`. The current fallback chains reflect the new routing model, not the old 3-level Haiku→Kimi pattern.

The current model routing policy uses a **capability-based dispatch** system:
- Models are selected based on task capability requirements, not fixed tier assignments
- `model_policy.json v3.0` is the authoritative source (PG SSOT-first)
- Resolution performed by `model-policy-query.sh`
- Fallback chains are dynamically resolved per task type

**v1.0's Kimi Safety Net is deprecated.** The new paradigm is PG-first, capability-based multi-model routing via CREST v1.3.

### 3.4 Routing Model

Yoda routes all tasks based on the following dispatch table:

| Task Type | Primary Destination | Secondary |
|-----------|--------------------|-----------| 
| Platform/infra/agents/models/S1–S7 | Thrawn | Forge (for build) |
| Enterprise arch/P1–P4/integration/TOM | Atlas | — |
| Both infra + enterprise arch | Atlas first, then Thrawn, reconcile if conflict | — |
| BPM/process/workflows | Lando | — |
| Change management/ADKAR/adoption | Mon Mothma | — |
| Social/content/LinkedIn | Spark (via Aria) | — |
| Marketing intelligence/analytics/insights | Luthen (via Aria) | — |
| Client discovery/proposals/business cases | Ahsoka | — |
| Security review | Shield | — |
| Legal/compliance/APP | Lex | — |
| QA/accuracy/policy | Sage | — |
| Model compliance/drift | Warden (auto, 15-min) | — |
| Infra/SRE/health/build/scripts | Forge | — |
| CREST dispatch (design_backend) | Atlas | via model-policy-query.sh |

> **No agent defined for a task? STOP — advise Ken (TOM gap) before acting.** Do not route to the closest-fit agent without explicit guidance.

### 3.5 Agent Communication Patterns

#### Current State (Day ~76)

| Pattern | Mechanism | Used For |
|---------|-----------|----------|
| Synchronous orchestration | `sessions_send` (OpenClaw) | Yoda → specialist, interactive task delegation |
| Sub-agent spawning | `sessions_spawn` | Isolated task execution (Atlas, Thrawn, research) |
| Background coordination | Postgres event bus + file writes | ✅ **Postgres event bus built** (Phase 1 deliverable) |
| Channel delivery | Telegram Bot API, Webchat | Ken, Angie notifications |
| CHG state | Postgres `state_changes` table | ✅ **Canonical CHG store** (CHG-0845 hardening) |

#### Typed Contracts (4 handoffs — TKT-0169, Phase 1)

| Handoff | Schema | Status |
|---------|--------|--------|
| Yoda → Forge | WorkflowRequest/v1 | To build |
| Yoda → Sanctum (Shield/Lex/Sage) | ReviewRequest/v1 | To build |
| Atlas → Ken | OptionPaperOutput/v1 | To build |
| Spark → Yoda | ContentApproval/v1 | To build |

Standing cadence: Contract schema is a DoD gate for all new agents. Reviewed at QBR and each new agent activation.

---

## 4. Infrastructure Architecture

### 4.1 HIVE Architecture — Current State (Day ~76)

```
┌──────────────────────────────────────────────────────────────────────┐
│                      NEXUS HIVE — OC1 (LIVE)                        │
│                                                                      │
│  OC1: Mac Mini M4 24GB                                               │
│  Location: Melbourne, Australia                                      │
│  Role: Primary production node — ALL 14 agents, ALL crons, Postgres  │
│  Storage: 460GB NVMe internal (21% used)                             │
│  Network: Tailscale mesh (ainchorss-mac-mini.tail5e2567.ts.net)      │
│  OpenClaw: Port 18789, loopback-only bind (S2 compliant)             │
│  Status: PERMANENT. Hard limit: No local LLM inference >~8B Q4.      │
│  Postgres: LIVE — SSOT-first architecture adopted                    │
│                                                                      │
│  Supporting infrastructure:                                          │
│  - Tailscale: Zero-trust overlay, admin/dev access only              │
│  - MinIO (Colima/Docker): 4 buckets, Tailscale-accessible            │
│  - Docker/Colima: Container runtime (Docker Desktop replaced)        │
│  - Postgres: OC1-local, 5-tier schema, state_changes canonical       │
│  - DuckDuckGo: Web search provider (approved CHG-0844)               │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

**Platform availability:** 97.46%+ historical. Incident tracking via `scripts/incident-log.sh`.

### 4.2 HIVE Architecture — Target State (Post-OC2, July 2026)

```
┌──────────────────────────────────────────────────────────────────────┐
│                   NEXUS HIVE — TARGET (POST-OC2)                     │
│                                                                      │
│  OC1: Mac Mini M4 24GB                                               │
│  Role: Production (retained), supporting node post-OC2               │
│  Postgres: Primary database instance retained on OC1                 │
│                                                                      │
│  OC2-A: Mac Mini M4 Pro 48GB (TRIGGER-01: arrival → setup)          │
│  Role: HA Primary. Local Gemma4:26b inference. Aria migration.       │
│  Estimate: 6–13 July 2026. Commissioning ~27 July 2026.             │
│  Status: HARDWARE ARRIVED — commissioning in progress.               │
│                                                                      │
│  OC2-B: Mac Mini M4 Pro 48GB (TRIGGER-02: both live → HA active)    │
│  Role: HA Secondary / Hot Standby.                                   │
│                                                                      │
│  NAS: Shared model weights + backup destination.                     │
│  Encryption: S7 (pending OC2 commissioning).                         │
│  Strategy: 3-2-1+1 backup (NAS hourly, S3 Sydney daily, USB weekly)  │
│                                                                      │
│  All nodes: Tailscale mesh. Zero-trust. loopback-only OpenClaw bind. │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

**Updated OC2 timeline:** Hardware arrived ~6-13 July 2026 as expected. Commissioning target ~27 July 2026 per TRIGGER-01. This is the critical path for S7 (NAS encryption) and local Gemma4:26b inference.

### 4.3 External Access Architecture

| Access Method | Current State | Target State |
|---------------|---------------|-------------|
| Developer/Admin | Tailscale mesh (zero-trust) | Tailscale mesh (retained) |
| Client chat | Loopback (internal only) | Cloudflare Tunnel → `chat.ainchors.com` |
| MinIO (storage) | Tailscale Serve (internal) | Tailscale Funnel (KL team) |
| Google Remote Desktop | Available | Retained |
| RustDesk | Primary remote access | Retained |

**S2 Control:** OpenClaw port 18789 is loopback-only. NEVER exposed publicly. Remote access via Tailscale only.

### 4.4 Object Storage — MinIO

**Runtime:** Colima (Docker) on OC1. Replaced Docker Desktop (2026-05-11).

| Bucket | Purpose |
|--------|---------|
| `ainchors-generated-media` | AI-generated images, media assets |
| `ainchors-workspace-assets` | Workspace docs, platform docs |
| `ainchors-brand-code` | Brand assets, code |
| `ainchors-agent-memory` | Agent memory exports |

**URL pattern (MANDATORY):** `http://ainchorss-mac-mini.tail5e2567.ts.net:9000/{bucket}/{path}`
Never use: `s3://`, IP addresses, or `local/` alias.

### 4.5 Storage Architecture (LOCKED — 2026-05-10)

| Layer | Technology | Purpose | Status |
|-------|-----------|---------|--------|
| Human Layer | Google Drive | Business docs, Brand Code, KL sharing, reports | LIVE |
| Agent Layer | MinIO (4 buckets) | Agent memory, generated media, workspace assets, brand code | LIVE |
| P2+ | AWS S3 Sydney (ap-southeast-2) | Multi-tenant client data | Future |
| Collaboration | Tailscale Serve/Funnel | Internal + KL team access | LIVE |
| Backup | Local NVMe → NAS (hourly) → S3 (daily) → USB (weekly) | 3-2-1+1 | Active |
| Daily sync | `scripts/drive-sync.sh` | 11PM AEST cron | Active |

### 4.6 Container Runtime

| Component | Detail |
|-----------|--------|
| Runtime | Colima (`/opt/homebrew/bin/colima`) |
| Docker CLI | `/opt/homebrew/bin/docker` |
| Socket | `unix:///Users/ainchorsangiefpl/.colima/default/docker.sock` |
| Context | `colima` (active, set as default) |
| Auto-start | `brew services start colima` (active at login) |
| Managed services | RustDesk containers (`infra/rustdesk/`), MinIO |

---

## 5. Data Architecture

### 5.1 Current State — Honest Assessment (Day ~76)

**Significant progress since v1.0.** The data architecture has advanced from a purely ad-hoc state to a Postgres-first model, though gaps remain.

| Area | Current State | Gap Assessment |
|------|--------------|----------------|
| Structured state | **Postgres SSOT-first adopted 2026-05-23.** `state_changes` table is canonical for CHGs. | Migration in progress — not all state files migrated yet. P003 (PG SSOT Gap Remediation) active. |
| Knowledge | Markdown files (MEMORY.md, SOUL.md, RULES.md, daily notes) | No formal index, no RAG pipeline (still pending) |
| Source of truth | Postgres + Notion (Holocron) | PG SSOT-first enforced. Notion as secondary/governance layer. |
| Database | **Postgres LIVE** — 5-tier schema deployed | Operational. Gaps in live write paths for some tables. |
| State ownership | PG tables owned by subsystems; JSON files still exist for some domains | P003 actively remediating. |
| Model routing | `model_policy.json v3.0` — PG-first, capability-based | ✅ CHG-0812 approved 2026-07-03. |
| Web search | DuckDuckGo (CHG-0844) | ✅ Replaced earlier search. |

**Known PG SSOT gaps (from P003 audit):** Some tables exist but have no live write path (backfill-only). Some planned tables were never created. Active remediation in progress.

### 5.2 Five-Tier Memory Architecture (APPROVED — TKT-0104)

| Tier | Name | Technology (Current) | Technology (Target) | Status | Locked Decisions |
|------|------|---------------------|--------------------|---------|-----------------| 
| **T1** | Working Memory (Context Window) | LLM context window — OpenClaw implicit | Same — disciplined token budget policy | Exists | Token budget policy to define |
| **T2** | Session Memory | OpenClaw implicit session state — no TTL, no audit | Postgres session tables (P1) → Redis (P2, TTL 24h, tenant-isolated) | Partial | Postgres P1 → Redis P2 (LOCKED — TKT-0104 D8) |
| **T3** | Episodic / Audit Log | Postgres: `agent_events`, `agent_decisions`, `decision_lineage` | SHA-256 per record | **Built** (Phase 1) | Append-only, SHA-256 tamper evidence |
| **T4** | Semantic Memory (RAG) | None | pgvector (768-dim, nomic-embed-text local) | **Not yet built** | pgvector (LOCKED — TKT-0104 D1), nomic-embed-text 768-dim (LOCKED — TKT-0104 D2) |
| **T5** | Shared Multi-Agent State | Postgres tables + some JSON files | Postgres: `agent_shared_state` (optimistic locking + version column) | **Partial** | Optimistic locking P1–P2 (LOCKED — TKT-0104 D4), event sourcing P3 (TRIGGER-14) |

### 5.3 Data Classification

| Category | Definition | Current State | P2 Enforcement |
|----------|------------|---------------|----------------|
| **Client** | Data belonging to or about external clients | ❌ None (no external clients) | RBAC by tenant_id, strict isolation |
| **Internal** | AInchors operational and business data | ✅ Exists, unclassified | Separated from tenant data stores |
| **System** | Platform-generated metrics, logs, health data | ✅ Exists | Per-tenant metrics, isolated |
| **Operational** | Task states, tickets, scripts, change records | ✅ Postgres (state_changes) + JSON files | Migrating to Postgres |
| **Repository** | Knowledge base, governance frameworks | ✅ Markdown files | RAG pipeline (pending) |
| **Backup** | Point-in-time copies | ✅ Daily cron | Encrypted at rest |

**Classification Labels (to be enforced from P2):** `PUBLIC` / `INTERNAL` / `CONFIDENTIAL` / `RESTRICTED`

### 5.4 Data Sovereignty Rules (DS-1 to DS-5)

| Rule | Statement |
|------|-----------|
| **DS-1** | Client data NEVER leaves OC1 / the local HIVE. Tier 0/1 local ONLY. |
| **DS-2** | Client data NEVER routes to Tier 2/3 cloud APIs (Ollama Cloud, Claude, etc.). |
| **DS-3** | Client data is NEVER co-mingled with AInchors operational data. |
| **DS-4** | BYOK exception: P4 clients supply own LLM API keys. Client owns their DPA compliance. |
| **DS-5** | Anthropic DPA verification required before any client data touches Claude APIs. (Status: DPA verified — TKT-0104 D5.) |

### 5.5 Target Data Architecture — Phase 1 (Sprints 4–8)

#### Sources of Truth Register (TKT-0166 — Sprint 4)

The Sources of Truth Register defines the canonical storage location for each data domain. Enforced at architecture level, not convention.

| Data Domain | Source of Truth (Target) | Current State | Status |
|-------------|--------------------------|---------------|--------|
| Tickets | Postgres `tickets` table + Notion AKB Backlog | `tickets.json` → Postgres | Phase 1 |
| Cost events | Postgres `cost_events` table | `state/cost-*.json` | Phase 1 |
| Agent health | Postgres `agent_health` table | `state/health-state.json` | Phase 1 |
| Change records | Postgres `change_records` / `state_changes` | **✅ PG SSOT (CHG-0845 hardened)** | **LIVE** |
| Workflow state | Postgres `workflow_state` table | `state/async-tasks.json`, `active-work.json` | Phase 1 |
| LinkedIn posts | Postgres `linkedin_posts` table | `state/linkedin-queue.json` | Phase 1 |
| Agent config | `openclaw.json` (authoritative) | `openclaw.json` | Exists |
| Model drift | Postgres (target) | `state/model-drift-state.json` | Interim |
| Model policy | `model_policy.json v3.0` | PG-first, capability-based | ✅ LIVE (CHG-0812) |
| Memory (long-term) | `MEMORY.md` + daily notes (P1) → Postgres T3 (Phase 1) | `MEMORY.md` | Transitioning |
| Knowledge base | pgvector `knowledge_chunks` / `knowledge_documents` | Markdown files (unindexed) | **Pending** |

#### Key Data Architecture Achievements (post-v1.0)

| Achievement | Date | Reference |
|-------------|------|-----------|
| Postgres deployed (5-tier schema) | ~Sprint 5 (May 2026) | TKT-0164 |
| `state_changes` table canonical for CHGs | 2026-05-23 | PG SSOT-first adoption |
| CHG-0845 — changelog PG hardening | Post-v1.0 | CHG-0845 |
| `model_policy.json v3.0` — PG-first, capability-based | 2026-07-03 | CHG-0812 |
| PG SSOT Gap Remediation (P003) | Active | P003 |
| Journal cron fix | Post-v1.0 | CHG-0837 |
| Journal discipline | Post-v1.0 | CHG-0838 |
| Gateway degradation mitigation | Post-v1.0 | CHG-0839/0840 |
| Forge workspace boundary | Post-v1.0 | CHG-0841 |
| Residual cron/memory fixes | Post-v1.0 | CHG-0843 |
| DuckDuckGo search | Post-v1.0 | CHG-0844 |

#### RAG Pipeline (TKT-0171 — Sprint 7)

| Component | Specification |
|-----------|--------------|
| Vector store | pgvector (Postgres extension) |
| Embedding model | `nomic-embed-text` via Ollama local (768-dim) |
| Chunking | RecursiveCharacterTextSplitter, 400–600 tokens, 10–20% overlap |
| Schema | `knowledge_chunks` (vector(768)), `knowledge_documents` (provenance + metadata) |
| Chunk metadata | `source_document`, `chunk_index`, `created_at`, `expires_at`, `classification`, `pii_present`, `quality_score` |
| PII gate | PII scanner (TKT-0170) must pass before embedding |
| Quality gate | `quality_score ≥ 0.7` required before chunk is searchable |
| Data sovereignty | All embeddings local. nomic-embed-text runs via Ollama on OC1. Zero data leaves environment. |

**RAG status:** Schema design and component spec complete. Implementation pending. pgvector extension requires Postgres deployment (live), but ingestion pipeline and PII scanner not yet built.

---

## 6. Integration Architecture

### 6.1 Current State — Post-Build (Day ~76)

| Dimension | Current State | Assessment |
|-----------|--------------|------------|
| Agent-to-agent | `sessions_send` (string input/output, no contracts, no versioning) | No typing, no retry, no observable failure path |
| State mutations | Postgres writes + script calls + some direct file writes | ✅ Postgres SSOT-first adopted. Some JSON files remain. |
| Instruction propagation | Verbal acknowledgement via LLM turn | ⚠️ Still a gap — LinkedIn dual-post class partially addressed |
| LLM-for-CRUD | Reduced via Work Currency Model | ⚠️ Ongoing — Phase 1 partially complete |
| Event bus | Postgres LISTEN/NOTIFY | ✅ **Built** (Phase 1, TKT-0168) |
| Integration layer | None | ⚠️ Postgres event bus built, but not yet full typed contracts |

### 6.2 Work Currency Model (APPROVED — 2026-05-14, TKT-0162)

The Work Currency Model governs which compute tier executes which work. This is the primary cost justification for building the integration layer.

| Work Currency | Definition | Compute Tier | Estimated Cost |
|---------------|------------|-------------|----------------|
| **High** | Reasoning, judgment, design, planning, novel content, decisions requiring complex synthesis | T3: DeepSeek Pro / Gemma4:31b / Kimi-k2.7 | Pay-per-token |
| **Medium** | Template content generation, structured analysis, summarisation, classification, moderate reasoning | T2: DeepSeek Flash / Kimi-k2.6 | Fixed ~$100/mo |
| **Low** | State mutations, CRUD, file writes, status updates, simple lookups, templated formatting | T1: Gemma4:26b local (post-OC2) or T0: systemEvent (now) | $0 |
| **None** | Pure system calls, file I/O, API calls to non-LLM services, database reads/writes | T0: Shell script / systemEvent / integration layer | $0 |

**Note:** The model tier mapping has changed since v1.0. The original Sonnet/Haiku/Opus hierarchy has been replaced by the Ollama Cloud model family (deepseek, kimi, gemma4). The Work Currency principles remain valid; the model assignments have been updated to reflect current reality.

**Examples of correct routing:**
- Journal generation → T2 (kimi, template-driven narrative)
- Ticket status update → T0 (shell script)
- Option paper analysis → T3 (complex architectural reasoning)
- LinkedIn post draft → T2 (structured content from campaign brief)
- Agent health check → T0 (systemEvent cron)

### 6.3 Three Work Types Rule (TKT-0165, Sprint 4 — APPROVED)

All agent work must be classified into one of three types before execution:

| Work Type | Execution Path | Examples |
|-----------|---------------|---------|
| **Reasoning Work** | LLM (appropriate tier) | Design, analysis, planning, content creation |
| **CRUD Work** | Shell script / systemEvent | State mutations, ticket updates, file writes, cost records, status changes |
| **Coordination Work** | Event bus (Postgres LISTEN/NOTIFY) or `sessions_send` | Agent handoffs, workflow triggers, status propagation |

**Rule:** If a script exists for a mutation, use it. If not, create the script first. No agent may write directly to state files that belong to another agent.

### 6.4 Target Integration Architecture — Phase 1 (TKT-0168, Sprint 6)

#### Postgres LISTEN/NOTIFY Event Bus

| Dimension | Detail |
|-----------|--------|
| Technology | Postgres LISTEN/NOTIFY (zero new infrastructure) |
| Purpose | Async coordination between agents — replaces ad-hoc `sessions_send` for background tasks |
| Event payload | `{event_type, tenant_id, agent_id, compute_tier, work_currency, payload, timestamp}` |
| Durability | Events also written to Postgres audit table (durable record regardless of listener state) |
| P2 migration | Redis Streams replaces Postgres LISTEN/NOTIFY for durable async (already planned — TKT-0104 D9) |
| Limitations | Not durable if listener inactive (acceptable P1; Redis Streams at P2) |

#### Typed Contracts — 4 Handoffs (TKT-0169, Sprint 7)

Schema-defined request/response for each high-value cross-agent call. JSON Schema files stored in `workspace/schemas/`. Validated at handoff point.

| Contract | Description | Priority |
|----------|-------------|---------|
| `Yoda→Forge: WorkflowRequest/v1` | Infrastructure task delegation | P1 |
| `Yoda→Sanctum: ReviewRequest/v1` | Security/legal/QA review request | P1 |
| `Atlas→Ken: OptionPaperOutput/v1` | Architecture recommendation delivery | P1 |
| `Spark→Yoda: ContentApproval/v1` | Content ready-for-approval signal | P1 |

**Standing cadence:** Contract schema is DoD gate for all new agents. Review at QBR and each new agent activation.

### 6.5 External Integration Points

| Integration | Technology | Classification | Notes |
|-------------|-----------|----------------|-------|
| Google Workspace | gog CLI (`/opt/homebrew/bin/gog`) | Adjacent | Account: `kenmun@ainchors.com`. Gmail, Calendar, Drive, Contacts, Sheets, Docs. Always use full path in exec. |
| Telegram (Ken) | Bot API | Adjacent | @AInchorsOC1Bot → Yoda. ChatID: 8574109706. Emergency: "YODA THIS IS KEN" |
| Telegram (Angie) | Bot API | Adjacent | @AInchorsAriaBot → Aria. ChatID: 8141152780. Strict allowlist. |
| LinkedIn | LinkedIn API | Adjacent | Token valid to 2026-07-12. MDP approved. Managed by Spark. |
| Notion / Holocron | Notion API | Adjacent | SSOT for tickets, CHGs, AKB. 3-DB architecture (Notion). DB IDs in MEMORY.md. |
| Ollama Cloud | kimii-k2.7-code, deepseek-v4-pro, deepseek-v4-flash, gemma4:31b-cloud | Adjacent | AInchors internal only. accounts@ainchors.com. Changed from v1.0's Anthropic-heavy stack. |
| DuckDuckGo | Web Search API | Adjacent | **Web search provider** (CHG-0844). Replaced previous search. |
| GitHub | gh CLI | Adjacent | Account: kenmun-ainchors. Scopes: repo, read:org, gist. |

---

## 7. Component Map

### 7.1 Classification

| Classification | Definition |
|----------------|------------|
| **Core** | Inside Nexus. Owned and operated by AInchors / Aevlith Technologies. |
| **Adjacent** | Outside Nexus. Integrated or consumed (third-party APIs, cloud services). |
| **Client-side** | Deployed in or operated by the client environment (P4 FSI physical deployments). |

**Summary:** Core: 40+ | Adjacent: 10 | Client-side: 14

### 7.2 Full Component Tables

Components are substantially unchanged from v1.0. Key updates:

#### Added Components (post-v1.0)

| Component | Class | Description | Status / Notes |
|-----------|-------|-------------|----------------|
| Postgres (primary) | **Core** | Relational store for agent events, decisions, shared state, CHG records, audit log. | **✅ LIVE** (Phase 1 critical path delivered). PG SSOT-first adopted 2026-05-23. |
| DuckDuckGo Search | **Adjacent** | Web search provider | **✅ LIVE** (CHG-0844). |
| Luthen Agent | **Core** | Marketing Intelligence agent | **✅ LIVE** — Agent 14. |
| CREST v1.3 Framework | **Core** | Capability-based multi-model routing, Sage-as-Judge, PG SSOT | **✅ LIVE** (CHG-0680, 2026-06-20). |
| model_policy.json v3.0 | **Core** | Capability-based model dispatch policy | **✅ LIVE** (CHG-0812, 2026-07-03). |
| PG SSOT Gap Remediation (P003) | **Core** | Active project auditing and fixing PG SSOT gaps | **ACTIVE**. |

#### Updated Components

| Component | Class | v1.0 Status | v1.1 Status | Change |
|-----------|-------|------------|-------------|--------|
| Anthropic Claude | Adjacent | **Primary** model tier | **Deprecated** as primary | Replaced by Ollama Cloud models. No longer primary model for any agent. |
| Ollama Cloud — kimi-k2.6 | Adjacent | Tier 2B | **Tier 2** | Now includes kimi-k2.7-code, deepseek-v4-pro/flash, gemma4:31b-cloud. |
| Ollama Cloud — deepseek | Adjacent | Supplementary | **Tier 3 core** | Now primary model for Atlas, Thrawn, Forge, Spark. |
| Notion | Adjacent | SSOT | **Secondary** | PG SSOT-first adopted. Notion is governance/backup layer. |
| Web Search | Adjacent | (not specified) | **DuckDuckGo** | CHG-0844. |

#### Removed/Deprecated Components

| Component | Class | Reason |
|-----------|-------|--------|
| Anthropic Claude Sonnet 4.6 | Adjacent | No longer primary model for any agent. Replaced by deepseek-v4-pro / gemma4:31b-cloud. |
| Anthropic Claude Haiku 4.5 | Adjacent | No longer used. Replaced by gemma4:31b-cloud for governance agents. |
| Anthropic Claude Opus 4.7 | Adjacent | No longer used. |
| nomic-embed-text 768-dim | Core | Still planned for RAG, but RAG pipeline not yet built. Changing status from "LIVE" to "Pending (RAG pipeline not built)". |

### 7.2.2 LLM Providers (Updated)

| Component | Class | Description | Status / Notes |
|-----------|-------|-------------|----------------|
| Ollama Cloud — kimi-k2.7-code:cloud | **Adjacent** | Primary reasoning model for T0 (Yoda) and T1 (Aria). | **LIVE** (primary). New in v1.1. |
| Ollama Cloud — deepseek-v4-pro:cloud | **Adjacent** | High-complexity specialist T3 model (Lando, Mon Mothma, Ahsoka, Luthen). | **LIVE** (primary for these agents). |
| Ollama Cloud — deepseek-v4-flash:cloud | **Adjacent** | Medium-complexity specialist T3 model (Atlas, Thrawn, Forge, Spark). | **LIVE** (primary for these agents). |
| Ollama Cloud — gemma4:31b-cloud | **Adjacent** | Governance T2/T4 model (Warden, Shield, Lex, Sage). | **LIVE** (primary for these agents). |
| Ollama Cloud — kimi-k2.6:cloud | **Adjacent** | Fallback tier for all agents. | **LIVE** (fallback). |
| Ollama Local — Gemma4:26b | **Core** (post-TRIGGER-03) | Tier 1 local inference. Client-facing workloads. Zero data residency risk. | **Waiting OC2-A commissioning** (~27 Jul 2026). |
| Ollama Local — Gemma4:e2b | **Core** | Experimental preview on OC1. | **Preview only** (background/non-interactive). |
| Ollama Local — nomic-embed-text | **Core** | Embedding model (768-dim). Local, FSI-safe. Powers RAG/pgvector. | **LIVE** (Ollama running). Schema deployment pending. RAG pipeline not yet built. |
| Anthropic Claude | **Adjacent** | Previously the primary model tier. | **Deprecated as primary.** Retained for compatibility. No agent currently uses Claude as primary. |
| BYOK (Bring Your Own Key) | **Client-side** (P4) | P4 enterprise clients supply own LLM API credentials. | Policy LIVE globally. |

---

## 8. Security Architecture

### 8.1 S1–S7 Security Controls

| Control | Requirement | Current Status |
|---------|-------------|----------------|
| **S1** | OpenClaw ≥ v2026.5.5 | ✅ LIVE — v2026.5.5 |
| **S2** | OpenClaw loopback-only bind. Port 18789 NEVER exposed publicly. | ✅ LIVE — loopback-only confirmed |
| **S3** | No ClawHub skill installs on production (OC1). New skills require `audit-skill.sh` + Ken approval. | ✅ LIVE — enforced |
| **S4** | Least-privilege per agent. Per-agent scoped API tokens. | ✅ LIVE — CHG-0176 |
| **S5** | No hardcoded credentials anywhere. All secrets in macOS Keychain. | ✅ LIVE — enforced |
| **S6** | All configuration changes CHG-logged and Warden-monitored. | ✅ LIVE — 850+ CHG records |
| **S7** | NAS encrypted at rest (AES-256). | ⚠️ PENDING — blocked on OC2-A commissioning |

### 8.2 Sanctum Protocol

The Sanctum is the mandatory governance gate for all external/client outputs. No bypass under any circumstance.

```
All external outputs / client deliverables / published content:
  → Shield 🛡️ (security review)
  → Lex ⚖️ (legal/compliance check)
  → Sage 🧪 (quality gate, CREST Judge role)
  → ✅ APPROVED FOR DELIVERY
```

**100% adherence required** (OKR S2-KR2). Any bypass is a governance failure.

**Applies to:** External sends, proposals, published content (LinkedIn, blog), client deliverables, option papers for external consumption.

### 8.3 Data Sovereignty (DS-1 to DS-5)

See Section 5.4. Summary:

| Rule | Enforcement |
|------|------------|
| DS-1: Client data stays local | Architectural — Gemma4 runs local, no cloud API for client data |
| DS-2: No client data to cloud APIs | Warden monitors. T4 controls at API dispatch. |
| DS-3: No co-mingling | tenant_id + RLS at P2. Separate namespaces. |
| DS-4: BYOK exception | P4 clients own their DPA compliance. |
| DS-5: Anthropic DPA verified | DONE — TKT-0104 Decision 5. |

### 8.4 HITL Framework — 5-Tier Human-in-the-Loop

All significant agent outputs require appropriate human oversight. The 5-tier framework:

| Tier | Gate | Description | Applies To |
|------|------|-------------|-----------|
| **H1** | Automatic approval | Low-risk, reversible, routine ops. | Health checks, cron outputs, auto-heal |
| **H2** | Yoda review | Platform-internal changes with moderate impact. | Agent config changes, script updates |
| **H3** | Ken review + approval | Platform architecture, significant decisions, external outputs. | Option papers, CHG records, new agents |
| **H4** | Ken + Angie review | Decisions affecting both streams or the company externally. | Business strategy, partnership decisions |
| **H5** | Ken explicit sign-off | Irreversible or high-risk decisions. Locked decisions. | LOCKED decision changes, P4 client commitments |

> **Non-negotiable:** No output is "approved" until a human explicitly says so. Architecture and strategy documents are always DRAFT FOR REVIEW until Ken gives explicit approval.

### 8.5 Key Management

| Phase | Technology | Scope |
|-------|-----------|-------|
| P1 (current) | macOS Keychain | All API keys, tokens. Zero hardcoded credentials. |
| P2 | Cloud KMS (AWS KMS ap-southeast-2) | Tenant-scoped. Annual rotation minimum. |
| P4 | HSM-backed CMK | FSI clients. Thales / nCipher or AWS CloudHSM. |

**SOP — API Key Rotation (updated from v1.0):** With the platform now using Ollama Cloud models (kimi, deepseek, gemma4) rather than Anthropic Claude, the key rotation SOP applies to Ollama Cloud API keys. The same principle applies: on key expiry/revocation, propagate to all agents via the appropriate script.

---

## 9. Gap Map — Current → Target

### 9.1 Phase 1 Gap (Sprints 4–8, Target: ~8 June 2026)

| Component | Current State | Target State | Status |
|-----------|--------------|-------------|--------|
| Three Work Types Rule | Rule codified | Wired to all agents | **Partially complete** |
| Sources of Truth Register | 10 core data types documented | Active enforcement | **Partially complete** |
| Postgres Database | **✅ LIVE** | 5-tier schema operational | **ACHIEVED** |
| JSON→Postgres Migration | Top 5 files migrated | Remaining files pending | **Partially complete** — P003 active |
| PII Scanner | None | Pre-ingestion gate | **Not yet built** |
| Event Bus | **✅ LIVE** | Postgres LISTEN/NOTIFY | **ACHIEVED** |
| Typed Agent Contracts | 4 handoffs defined | Active enforcement | **Not yet built** |
| RAG Pipeline | None | pgvector + nomic-embed-text | **Not yet built** |
| Cloudflare Tunnel | Pending | Client-facing surfaces | **Not yet live** |
| Architecture KRI Dashboard | Live | Ongoing updates | **LIVE** |

**Notable:** Postgres and Event Bus are live. The biggest remaining gaps are RAG pipeline, PII scanner, typed contracts, and full JSON migration.

### 9.2 Phase 2 Gap (Post-P2 +2 Weeks, ~October 2026)

| Component | Current/Phase 1 State | Phase 2 Target |
|-----------|----------------------|----------------|
| Session store | Postgres session tables | Redis Streams (durable async, tenant-isolated namespace) |
| Multi-tenancy | Single tenant (ainchors) | Shared schema + RLS (tenant_id on all tables) |
| Agent containers | All agents on OC1 bare metal | Per-client Docker container isolation |
| Client portal (Citadel) | None | Citadel v0 (Notion-based for first 2–3 SME clients) |
| Integration bus | Postgres LISTEN/NOTIFY | Redis Streams (durable, P2 load) |
| Holonet | None | Holonet v0 (REST/webhook/Google Sheets) |
| Cloud KMS | macOS Keychain | AWS KMS ap-southeast-2 (tenant-scoped) |
| RBAC | None | Per-tenant access control matrix |
| Agent output schema library | 4 typed contracts | Full coverage across all 14 agents |

### 9.3 Phase 3 Gap (Enterprise/FSI — TRIGGER-14, Post-P2 Stable)

| Component | Phase 2 State | Phase 3 / P4 Target |
|-----------|--------------|---------------------|
| State model | Optimistic locking on shared state | Event sourcing (immutable event log, state derived from replay) |
| Audit log | Postgres append-only | WORM-capable storage (S3 Object Lock COMPLIANCE or NAS WORM) |
| Audit retention | 2 years (P2 default) | 7 years minimum (APRA) |
| Key management | Cloud KMS | HSM-backed CMK (Thales, nCipher, or AWS CloudHSM) |
| Compliance | SME SaaS | Full APRA CPG 234/235 formal assessment |
| Physical deployment | Cloud-only | On-prem HIVE package (Mac Mini × 2 + NAS) |
| Observability | obs.db + health-state.json | Beacon (unified real-time dashboard) |
| Reporting | Manual | Datapad (client-facing PDF/Notion reports) |

---

## 10. Architecture Decision Log Reference

All locked decisions are binding. They cannot be re-opened without a new CHG record and Ken's explicit approval.

### 10.1 Locked Decisions (v1.0 — Still Holding)

| Decision | Locked By | Summary | Date | Status |
|----------|-----------|---------|------|--------|
| **pgvector as vector store** | TKT-0104 D1 | No alternative vector store. Re-embedding entire KB required to change. | 2026-05-08 | ✅ HOLDING |
| **nomic-embed-text 768-dim** | TKT-0104 D2 | Embedding dimension locked at table creation. | 2026-05-08 | ✅ HOLDING |
| **RecursiveCharacterTextSplitter 400–600 tokens, 10–20% overlap** | TKT-0104 D3 | Standard chunking strategy. | 2026-05-08 | ✅ HOLDING |
| **Optimistic locking P1–P2, event sourcing P3** | TKT-0104 D4 | `agent_state_history` seed of future event log. | 2026-05-08 | ✅ HOLDING |
| **Anthropic DPA verified** | TKT-0104 D5 | Claude for non-PII AInchors-internal workloads. | 2026-05-08 | ⚠️ **NEEDS RE-EVALUATION** — Claude no longer primary model tier |
| **Shared schema + RLS from P2 day one** | TKT-0104 D6 / CHG-0234 | Multi-tenant foundation. | 2026-05-08 | ✅ HOLDING |
| **Postgres session tables P1, Redis P2** | TKT-0104 D8 | No Redis in P1. | 2026-05-08 | ✅ HOLDING |
| **OpenClaw as final platform** | IT Strategy | No replatforming. | Pre-Day 1 | ✅ HOLDING |
| **Mac Mini HIVE for P1–P2** | MEMORY.md / IT Strategy | OC1 permanent. OC2-A/B arriving. | Pre-Day 1 | ✅ HOLDING |
| **Block Claude for all P2 client workloads** | TKT-0046 Decision H | BYOK exception. | 2026-05-12 | ✅ HOLDING (applies to all cloud models now) |
| **P4 consulting-led deployment model** | TKT-0046 Decision B | Not self-service install. | 2026-05-12 | ✅ HOLDING |
| **Phase structure: P1→P2→P4 (P3=commercial tier within P2)** | CHG-0234 | P3 as build phase DROPPED. | 2026-05-08 | ✅ HOLDING |
| **P3 commercial tier = shared schema + RLS feature flag** | CHG-0234 | No separate P3 infrastructure. | 2026-05-08 | ✅ HOLDING |
| **Option B Phased — Architecture Direction** | TKT-0162 / CHG-0308 | Redesign data + integration layers. | 2026-05-14 | ✅ HOLDING |
| **Event sourcing deferred to Phase 3 (TRIGGER-14)** | TKT-0162 / CHG-0308 | Post-P2 stable. | 2026-05-14 | ✅ HOLDING |
| **4 Typed contracts as Phase 1 scope** | TKT-0162 / CHG-0308 | Yoda→Forge, Yoda→Sanctum, Atlas→Ken, Spark→Yoda. | 2026-05-14 | ✅ HOLDING |
| **Aevlith Technologies — platform entity** | MEMORY.md | Aevlith = technology holding entity. | 2026-05-09 | ✅ HOLDING |
| **Kimi safety net (3-level fallback)** | CHG-0270 | Every agent: 3-level fallback. | 2026-05-13 | ⚠️ **SUPERSEDED** by CHG-0812 capability-based routing |

### 10.2 New Locked Decisions (Added v1.1)

| Decision | Locked By | Summary | Date |
|----------|-----------|---------|------|
| **CREST v1.3 — capability-based multi-model routing** | CHG-0680 | Sage-as-Judge, PG SSOT-first, model-policy-query.sh resolution. | 2026-06-20 |
| **model_policy.json v3.0 — PG-first model dispatch** | CHG-0812 | Capability-based model selection. Resolves via `model-policy-query.sh`. | 2026-07-03 |
| **PG SSOT-first architecture** | Platform decision | Postgres is authoritative for structured state. Notion is secondary. | 2026-05-23 |
| **DuckDuckGo as web search provider** | CHG-0844 | Replaces previous search. | Post-v1.0 |
| **state_changes table canonical for CHGs** | CHG-0845 | Hardened changelog PG path. | Post-v1.0 |

### 10.3 Decisions Needing Re-evaluation at Next Review

| Decision | Reason for Re-evaluation |
|----------|-------------------------|
| **Anthropic DPA verified (TKT-0104 D5)** | Claude is no longer the primary model tier. The platform has migrated to Ollama Cloud models. The DPA verification is still technically valid but may need updating to reflect the new model stack. |
| **Kimi safety net (CHG-0270)** | Superseded by CHG-0812 capability-based routing. The new model policy should be the canonical reference. Recommend formal deprecation. |
| **nomic-embed-text 768-dim (TKT-0104 D2)** | RAG pipeline not yet built. When implementation begins, re-evaluate whether nomic-embed-text remains the best embedding model, or whether a newer model has emerged. |
| **Gemma4:26b local as T1 for client workloads** | OC2-A commissioning pending. If OC2 timeline slips, a contingency plan for T1 client inference is needed. |

---

## Appendix A — TRIGGER Reference

| Trigger | Condition | Action |
|---------|-----------|--------|
| TRIGGER-01 | OC2-A arrives | OC2-A setup sequence (Gemma4:26b, Aria migration) — **HARDWARE ARRIVED, commissioning ~27 Jul** |
| TRIGGER-02 | Both OC2-A/B live | HA active, NAS encryption (S7) |
| TRIGGER-03 | Gemma4:26b validated ≥75% gate | Swap cloud models → local Gemma4 for governance agents |
| TRIGGER-04 | OpenClaw update available | Forge evaluates, Yoda/Ken decide |
| TRIGGER-05 | ✅ FIRED | kimi-k2.6:cloud Tier 2 active (2026-05-02) |
| TRIGGER-06 | OpenClaw v4.0 ships | Agent platform alternatives assessment |
| TRIGGER-07 | First P2 client | Client onboarding sequence |
| TRIGGER-08 | ✅ FIRED | Auto-reload <$50→$500 (CHG-0232) |
| TRIGGER-09 | Warden drift detected | Yoda remediates |
| TRIGGER-10 | Aria→OC2 | Aria migration from OC1 to OC2-A |
| TRIGGER-11 | Monthly | Model check cadence |
| TRIGGER-12 | ✅ FIRED | Allowlist auto-sync (CHG-0144) |
| TRIGGER-13 | OC2+MinIO 2-sprint validated | TKT-0153 semantic memory. Deprecates MEMORY_TICKETS.md + MEMORY_DECISIONS.md. |
| TRIGGER-14 | Post-P2 stable | Phase 3: event sourcing, WORM audit, APRA CPG 234/235. |

---

## Appendix B — Key File Paths Reference

| File / Path | Purpose |
|-------------|---------|
| `/Users/ainchorsangiefpl/.openclaw/openclaw.json` | Agent model configuration (source of truth for agent models) |
| `/Users/ainchorsangiefpl/.openclaw/workspace/MEMORY.md` | Yoda's long-term memory (curated decisions, facts, IDs) |
| `/Users/ainchorsangiefpl/.openclaw/workspace/SOUL.md` | Yoda's identity and operating principles |
| `/Users/ainchorsangiefpl/.openclaw/workspace-architect/AGENTS.md` | Atlas's identity and operating principles (CREST v1.3 compliant) |
| `/Users/ainchorsangiefpl/.openclaw/workspace-architect/docs/Nexus-System-Architecture-v1.1-DRAFT.md` | **This document** |
| `/Users/ainchorsangiefpl/.openclaw/workspace/docs/Nexus-System-Architecture-v1.0.md` | Previous approved version (v1.0, 2026-05-14) |
| `/Users/ainchorsangiefpl/.openclaw/workspace/docs/Aevlith-Technology-Strategy-Roadmap-v1.0-Internal.md` | Previous strategy roadmap (v1.0, 2026-05-14) |
| `/Users/ainchorsangiefpl/.openclaw/workspace/state/architecture-kri-state.json` | KRI dashboard state (Yoda updates at sprint review) |
| `/Users/ainchorsangiefpl/.openclaw/workspace/state/chg-triggers.json` | TRIGGER system state |
| `/Users/ainchorsangiefpl/.openclaw/workspace/state/model-drift-state.json` | Warden compliance state |

---

## Appendix C — Sprint Plan Reference (Updated ~Day 76)

| Sprint | Target Date | Key Architecture Deliverables |
|--------|------------|-------------------------------|
| Sprint 4 | May 19–25, 2026 | TKT-0165 (Three Work Types Rule), TKT-0166 (SoT Register), Cloudflare Tunnel |
| Sprint 5 | May 26–Jun 1, 2026 | TKT-0164 (Postgres — critical path completed), TKT-0108 |
| Sprint 6 | Jun 2–8, 2026 | TKT-0167 (JSON→Postgres migration), TKT-0168 (Event Bus), TKT-0170 (PII Scanner) |
| Sprint 7 | Jun 9–15, 2026 | TKT-0169 (Typed Contracts), TKT-0171 (RAG Pipeline) |
| Sprint 8 | Jun 16–22, 2026 | P2 blocker verification, Phase 1 sign-off |
| Sprint 9+ | Jun 22+, 2026 | OC2 commissioning, P003 PG SSOT Gap Remediation, CRESTv2-P1 |

---

## Appendix D — Changes from v1.0

**Document:** Nexus-System-Architecture-v1.1-DRAFT.md
**Previous version:** Nexus-System-Architecture-v1.0.md (2026-05-14, approved by Ken Mun)
**Author:** Atlas 🏛️
**Date:** 2026-07-09

### Material Changes

| # | Section | Change | Reason |
|---|---------|--------|--------|
| 1 | §2.2 | Updated agent count: 12→14. Updated CHG count: 230+→850+. Added Postgres, DuckDuckGo, CREST v1.3 status. | Platform maturity. |
| 2 | §2.6 | Added **Active Projects** table (P001–P006). | New structure. |
| 3 | §3.1 | Updated Tier 3 roster: added Ahsoka and Luthen. Added Krennic as parked. | Agent roster growth. |
| 4 | §3.2 | **Complete refresh of all agent model configs.** Replaced Anthropic Claude with Ollama Cloud models: kimi-k2.7-code, deepseek-v4-pro, deepseek-v4-flash, gemma4:31b-cloud. | Major model migration. |
| 5 | §3.2 | Added **Luthen 🧠** (Marketing Intelligence) — new T3 agent. | New agent. |
| 6 | §3.2 | Added **Krennic** as parked (not activated). | Future agent. |
| 7 | §3.3 | **Deprecated** Kimi Safety Net (CHG-0270). Replaced with CHG-0812 capability-based routing. | Model policy evolution. |
| 8 | §3.4 | Added Luthen and CREST dispatch to routing table. | New agents. |
| 9 | §3.5 | Updated background coordination to reflect Postgres event bus built. | Phase 1 progress. |
| 10 | §4.1 | Added Postgres and DuckDuckGo to HIVE diagram. | Infrastructure updates. |
| 11 | §4.2 | Updated OC2 timeline: "Hardware arrived — commissioning in progress." | OC2 progress. |
| 12 | §5.1 | **Complete rewrite.** Postgres SSOT-first adopted, CHG-0845 hardening, model_policy v3.0, known gaps documented. | Major data architecture progress. |
| 13 | §5.2 | Updated T3 (Episodic) status to "Built" and T5 (Shared State) to "Partial." | Phase 1 progress. |
| 14 | §5.5 | Updated SoT Register with CHG-0845 and model_policy v3.0 status. Added Key Data Architecture Achievements table. | Data architecture maturity. |
| 15 | §6.1 | Updated integration state: Postgres event bus built, typed contracts not yet built. | Phase 1 progress. |
| 16 | §6.2 | Updated Work Currency Model tier mapping to reflect new model stack. | Model migration. |
| 17 | §6.5 | Added DuckDuckGo. Updated Ollama Cloud model list. Deprecated Anthropic. | External integration updates. |
| 18 | §7.2 | Added Luthen, CREST v1.3, model_policy v3.0, PG SSOT Gap Remediation. Deprecated Anthropic Claude models. | Component map refresh. |
| 19 | §8.5 | Updated key rotation SOP for Ollama Cloud models. | Model migration. |
| 20 | §9.1 | Updated Phase 1 gap map: Postgres and Event Bus marked ACHIEVED. RAG, PII, contracts still gaps. | Phase 1 status. |
| 21 | §10.1 | **Added new locked decisions** (CREST v1.3, model_policy v3.0, PG SSOT-first, DuckDuckGo, CHG-0845). | New decisions. |
| 22 | §10.3 | **Added "Decisions Needing Re-evaluation"** section. | Governance hygiene. |
| 23 | Appendix B | Updated file paths, added this document. | Reference update. |
| 24 | Appendix C | Updated sprint plan to reflect actual progress. | Timeline accuracy. |

### Top 5 Most Significant Changes

1. **Model migration: Anthropic Claude → Ollama Cloud** (affects §3.2, §6.2, §6.5, §7.2, §10). Every agent's model config changed. The entire model tier hierarchy was rebuilt.
2. **Postgres SSOT-first architecture** (§5.1, §5.5). From "not deployed" to "LIVE with known gaps." This is the single biggest infrastructure achievement since v1.0.
3. **Agent roster expansion: 12→14** (§3.1, §3.2). Luthen added, Ahsoka formalised, Krennic parked.
4. **CREST v1.3 + model_policy v3.0** (§3.3, §7.2, §10.2). New governance framework for capability-based model routing.
5. **OC2 transition** (§4.2). Hardware arrived, commissioning in progress. This is the critical path for S7, local Gemma4:26b, and P2 readiness.

---

*Document: DRAFT FOR REVIEW*
*CHG-0852 | Atlas 🏛️ Enterprise Architect | Aevlith Technologies / AInchors*
*2026-07-09 | Platform Day ~76 | v1.1-DRAFT*
*Supersedes: Nexus-System-Architecture-v1.0.md (2026-05-14)*
*This document is NOT approved. Do not build against it until Ken review is complete.*