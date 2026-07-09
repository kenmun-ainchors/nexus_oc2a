# Nexus Platform — System Architecture Document
## v1.0 | Internal Reference

> ⚠️ **SUPERSEDED — docs/Nexus-System-Architecture-v1.1.md approved by Ken Mun 2026-07-09 under CHG-0853.** This v1.0 document is retained for historical reference only.

**Classification: INTERNAL — Aevlith Technologies / AInchors**
**Status: APPROVED ✅**
**Approved by: Ken Mun (CTO) — 2026-05-14 12:39 AEST**
**Author: Atlas 🏛️ — Enterprise Architect**
**Date: 2026-05-14 | Day 20**
**TKT-0173**

---

> **Supersedes:** Fragmented architecture docs (TKT-0046 component sections, TKT-0104 component sections, Yoda_ORCHESTRATOR.md partial coverage). This document is the single authoritative system architecture reference for the Nexus platform.
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
| Current state (Day 20, 2026-05-14) | P2+ multi-tenant implementation detail |
| Target state (Option B Phased, approved CHG-0308) | Client-specific agent configurations |
| Gap map: current → target | Business process design (→ Lando) |
| All 12 active agents and their configs | Content strategies (→ Spark / Aria) |
| All infrastructure (OC1, networking, storage) | Consulting delivery methodology (→ Ahsoka) |
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

1. **An internal operations platform** (P1 — current): 12 active agents orchestrate AInchors' own business operations across technical architecture, social marketing, business process, content, governance, and infrastructure.

2. **A deployable product** (P2–P4): The same architecture is designed from day one to become a commercially-deployed SaaS (P2, end-August 2026), with expansion to enterprise/FSI consulting deployments (P4).

The business IS the demo. AInchors' own operations — two founders, 12 agents, full-stack AI operations — is the proof of concept. The platform must be demonstrably production-grade at all times.

### 2.2 Deployment Status (Day 20)

| Dimension | Current State |
|-----------|--------------|
| Primary node | OC1 — Mac Mini M4 24GB, Melbourne |
| Runtime | OpenClaw v2026.5.5 (final platform — no replatforming) |
| Active agents | 12 |
| Active scripts | 52+ |
| Active crons | 20+ |
| Change records | 230+ |
| Platform availability | 97.46% historical |
| Day count | Day 20 (2026-04-25 → 2026-05-14) |

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

---

## 3. Agent Architecture

### 3.1 Governance Tier Model

The Nexus agent governance hierarchy is a five-tier model defining authority, communication patterns, and operational scope. Approved by Ken Mun, 2026-05-08 (TKT-0103).

| Tier | Agent | Role | Authority Model |
|------|-------|------|----------------|
| **T0** | Yoda 🟢 | Lead Orchestrator | Full platform authority. Classifies, routes, quality-gates, presents decisions. Does NOT execute specialist work. |
| **T1** | Aria 🔵 | Business Lead | Dual-principal: reports to CEO (Angie) AND Yoda. Leads business stream. Full AInchors data read access. |
| **T2** | Warden 🔍 | Model Compliance Monitor | Yoda-Governed. 15-min autonomous monitoring cycle. Reads agent configs; never acts directly. Reports only. |
| **T3** | Spark ✨, Atlas 🏛️, Thrawn, Lando 🟡, Forge 🏗️, Mon Mothma 🌟 | Specialist Agents | Yoda-Manage-Passthrough. Execute specialist work in their domain. |
| **T4** | Shield 🛡️, Lex ⚖️, Sage 🧪 | Sanctum Triad | Reactive verdict-only. Never initiate work. Shield → Lex → Sage gate sequence for all external outputs. |

> **Key constraint:** Yoda orchestrates. Yoda does NOT execute specialist work directly. Routing to the wrong tier is a governance failure.

### 3.2 Agent Roster — All 12 Active Agents

Agent configurations are read from `/Users/ainchorsangiefpl/.openclaw/openclaw.json`. The following table reflects actual configurations as of Day 20.

#### T0 — Yoda 🟢 (Lead Orchestrator)

| Attribute | Value |
|-----------|-------|
| Agent ID | `main` |
| Display Name | Yoda 🟢 |
| Session | `agent:main:dashboard:*` |
| Primary Model | `anthropic/claude-sonnet-4-6` |
| Fallbacks | `anthropic/claude-haiku-4-5` → `ollama/kimi-k2.6:cloud` |
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
| Session | `agent:main:business:*` |
| Primary Model | `anthropic/claude-sonnet-4-6` |
| Fallbacks | `anthropic/claude-haiku-4-5` → `ollama/kimi-k2.6:cloud` |
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
| Primary Model | `anthropic/claude-haiku-4-5` |
| Fallbacks | `ollama/kimi-k2.6:cloud` → `ollama/kimi-k2.6:cloud` |
| Stream | Governance (cross-stream) |
| Workspace | `/Users/ainchorsangiefpl/.openclaw/workspace-governance` |
| Cron ID | `83accf7b` (every 15 min) |
| State Files | `state/model-drift-state.json`, `state/violations.json`, `state/warden-escalation-pending.json` |
| Key Responsibilities | Checks all 9 agents every 15 min for model drift and compliance. Never acts directly — writes violations and escalates to Yoda. |
| Tools | `read`, `write`, `exec` only |
| Note | Moving to Gemma4 local at TRIGGER-03 (OC2 Gemma4 validated) |

#### T3 — Spark ✨ (Social Marketing Agent)

| Attribute | Value |
|-----------|-------|
| Agent ID | Within business stream / spawned subagent |
| Display Name | Spark ✨ |
| Primary Model | `ollama/kimi-k2.6:cloud` (Tier 2 — fixed cost) |
| Stream | Business / Social |
| Key Responsibilities | LinkedIn, Instagram, Facebook, YouTube content creation and scheduling. AIOps campaign management. Content governance review. |
| Cron IDs | `e7ebaf61` (primary), `bef42235` (secondary), review `316df676` (2026-06-02) |
| Key Constraint | Post cancellation must update queue state AND delete cron. Never verbal-only acknowledgement (L-027). |
| State Files | `workspace/state/linkedin-queue.json` (canonical), `workspace-social/state/linkedin-queue.json` (deprecated in Phase 1) |
| SOUL Location | `workspace-social/SPARK_SOUL.md` |

#### T3 — Atlas 🏛️ (Enterprise Architect)

| Attribute | Value |
|-----------|-------|
| Agent ID | `architect` |
| Display Name | Atlas 🏛️ — Enterprise Architect |
| Primary Model | `anthropic/claude-sonnet-4-6` |
| Fallbacks | `anthropic/claude-haiku-4-5` → `ollama/kimi-k2.6:cloud` |
| Stream | Technical |
| Workspace | `/Users/ainchorsangiefpl/.openclaw/agents/architect/agent` |
| Key Responsibilities | Enterprise architecture (TOGAF), P1–P4 architecture design, cross-platform landscape (TKT-0046), data architecture (TKT-0104), option papers, architecture decision log, integration architecture |
| Boundary with Thrawn | Atlas sets enterprise-facing architectural constraints. Thrawn implements platform-internal architecture. Atlas does NOT build or run scripts (→ Forge). |

#### T3 — Thrawn (AI Platform Architect)

| Attribute | Value |
|-----------|-------|
| Agent ID | `platform-arch` |
| Display Name | Thrawn — AI Platform Architect |
| Primary Model | `anthropic/claude-sonnet-4-6` |
| Fallbacks | `anthropic/claude-haiku-4-5` → `ollama/kimi-k2.6:cloud` |
| Stream | Technical |
| Key Responsibilities | Nexus platform architecture (model strategy, S1–S7 security controls, OpenClaw configuration, agent deployment design, multi-tenant isolation design, OC2 architecture) |
| Boundary with Atlas | Thrawn designs platform-internal. Atlas designs enterprise-facing. Conflict → Atlas sets constraints, Thrawn implements within them. |
| Note | NEVER route build/scripts to Thrawn. Build → Forge ONLY (L-026). |

#### T3 — Lando 🟡 (Business Process Specialist)

| Attribute | Value |
|-----------|-------|
| Agent ID | `biz-process` |
| Display Name | Lando 🟡 — Business Process Specialist |
| Primary Model | `anthropic/claude-sonnet-4-6` |
| Fallbacks | `anthropic/claude-haiku-4-5` → `ollama/kimi-k2.6:cloud` |
| Stream | Business |
| Key Responsibilities | BPM, BPMN process design, workflow optimisation, business process documentation |

#### T3 — Forge 🏗️ (Infrastructure & SRE)

| Attribute | Value |
|-----------|-------|
| Agent ID | `infra` |
| Display Name | Forge 🏗️ |
| Primary Model | `anthropic/claude-haiku-4-5` |
| Fallbacks | `ollama/kimi-k2.6:cloud` → `ollama/kimi-k2.6:cloud` |
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
| Primary Model | `anthropic/claude-sonnet-4-6` |
| Fallbacks | `anthropic/claude-haiku-4-5` → `ollama/kimi-k2.6:cloud` |
| Stream | Business / Governance |
| Key Responsibilities | ADKAR methodology, change management plans, stakeholder adoption, digital transformation strategy |

#### T4 — Shield 🛡️ (Security Agent)

| Attribute | Value |
|-----------|-------|
| Agent ID | `security` |
| Display Name | Shield 🛡️ |
| Primary Model | `anthropic/claude-haiku-4-5` |
| Fallbacks | `ollama/kimi-k2.6:cloud` → `ollama/kimi-k2.6:cloud` |
| Stream | Governance (Sanctum Triad) |
| Workspace | `/Users/ainchorsangiefpl/.openclaw/workspace-security` |
| Key Responsibilities | Content security review (first gate in Sanctum). Pre-publish security scan for all external outputs. |
| Tools | `read`, `exec`, `web_search`, `web_fetch` only |
| RULES | `SHIELD_RULE_1.md` |
| Note | Moving to Gemma4 local at TRIGGER-03. |

#### T4 — Lex ⚖️ (Legal / Compliance)

| Attribute | Value |
|-----------|-------|
| Agent ID | `legal` |
| Display Name | Lex ⚖️ |
| Primary Model | `anthropic/claude-haiku-4-5` |
| Fallbacks | `ollama/kimi-k2.6:cloud` → `ollama/kimi-k2.6:cloud` |
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
| Primary Model | `anthropic/claude-haiku-4-5` |
| Fallbacks | `ollama/kimi-k2.6:cloud` → `ollama/kimi-k2.6:cloud` |
| Stream | Governance (Sanctum Triad) |
| Workspace | `/Users/ainchorsangiefpl/.openclaw/workspace-qa` |
| Key Responsibilities | Source verification, definition-of-done, quality gate (third gate in Sanctum). Final quality check before external delivery. |
| Tools | `read`, `exec`, `process`, `web_search`, `web_fetch` |
| RULES | `SAGE_RULES.md` |

#### Ahsoka 🤍 (AI Transformation Consultant)

| Attribute | Value |
|-----------|-------|
| Agent ID | `ahsoka` |
| Display Name | Ahsoka 🤍 — AI Transformation Consultant |
| Primary Model | `anthropic/claude-haiku-4-5` |
| Fallbacks | `ollama/kimi-k2.6:cloud` → `ollama/kimi-k2.6:cloud` |
| Stream | Consulting |
| Key Responsibilities | Client discovery, proposals, business cases, AI transformation consulting delivery |
| Note | Consulting stream lead. Ahsoka leads → P4 delivery. Aevlith/partnership pending (TKT-0114). |

### 3.3 Agent Fallback Chain Policy (LOCKED — CHG-0270)

**The Kimi Safety Net Rule:** Every agent MUST have a 3-level fallback chain. No exceptions.

| Agent Group | Chain |
|-------------|-------|
| Yoda + Aria | `claude-sonnet-4-6` → `claude-haiku-4-5` → `kimi-k2.6:cloud` |
| All T3+ complex | `claude-sonnet-4-6` → `claude-haiku-4-5` → `kimi-k2.6:cloud` |
| All T2/T4 governance | `claude-haiku-4-5` → `kimi-k2.6:cloud` → `kimi-k2.6:cloud` |
| Ahsoka | `claude-haiku-4-5` → `kimi-k2.6:cloud` → `kimi-k2.6:cloud` |

**Cause:** 2026-05-13 key expiry caused platform-wide outage. Kimi as final fallback prevents total dark.

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
| Client discovery/proposals/business cases | Ahsoka | — |
| Security review | Shield | — |
| Legal/compliance/APP | Lex | — |
| QA/accuracy/policy | Sage | — |
| Model compliance/drift | Warden (auto, 15-min) | — |
| Infra/SRE/health/build/scripts | Forge | — |

> **No agent defined for a task? STOP — advise Ken (TOM gap) before acting.** Do not route to the closest-fit agent without explicit guidance.

### 3.5 Agent Communication Patterns

#### Current State (Day 20)

| Pattern | Mechanism | Used For |
|---------|-----------|----------|
| Synchronous orchestration | `sessions_send` (OpenClaw) | Yoda → specialist, interactive task delegation |
| Sub-agent spawning | `sessions_spawn` | Isolated task execution (Atlas, Thrawn, research) |
| Background coordination | None (ad-hoc file writes) | ⚠️ Gap — no formal async coordination layer |
| Channel delivery | Telegram Bot API, Webchat | Ken, Angie notifications |

#### Target State (Phase 1, TKT-0168)

| Pattern | Mechanism | Used For |
|---------|-----------|----------|
| Synchronous orchestration | `sessions_send` (retained) | Interactive orchestration |
| Async coordination | Postgres LISTEN/NOTIFY event bus | Background task handoffs, status propagation |
| State mutations | Shell scripts / systemEvent (T0) | CRUD, file writes, ticket updates |
| Sub-agent spawning | `sessions_spawn` (retained) | Isolated task execution |

#### Typed Contracts (4 handoffs — TKT-0169, Phase 1)

| Handoff | Schema | Status |
|---------|--------|--------|
| Yoda → Forge | WorkflowRequest/v1 | To build Sprint 7 |
| Yoda → Sanctum (Shield/Lex/Sage) | ReviewRequest/v1 | To build Sprint 7 |
| Atlas → Ken | OptionPaperOutput/v1 | To build Sprint 7 |
| Spark → Yoda | ContentApproval/v1 | To build Sprint 7 |

Standing cadence: Contract schema is a DoD gate for all new agents. Reviewed at QBR and each new agent activation.

---

## 4. Infrastructure Architecture

### 4.1 HIVE Architecture — Current State (Day 20)

```
┌──────────────────────────────────────────────────────────────────────┐
│                      NEXUS HIVE — OC1 (LIVE)                        │
│                                                                      │
│  OC1: Mac Mini M4 24GB                                               │
│  Location: Melbourne, Australia                                      │
│  Role: Primary production node — ALL 12 agents, ALL crons            │
│  Storage: 460GB NVMe internal (21% used)                             │
│  Network: Tailscale mesh (ainchorss-mac-mini.tail5e2567.ts.net)      │
│  OpenClaw: Port 18789, loopback-only bind (S2 compliant)             │
│  Status: PERMANENT. Hard limit: No local LLM inference >~8B Q4.      │
│                                                                      │
│  Supporting infrastructure:                                          │
│  - Tailscale: Zero-trust overlay, admin/dev access only              │
│  - MinIO (Colima/Docker): 4 buckets, Tailscale-accessible            │
│  - Docker/Colima: Container runtime (Docker Desktop replaced)        │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

**Platform availability:** 97.46% historical. Incident tracking via `scripts/incident-log.sh`.

### 4.2 HIVE Architecture — Target State (Post-OC2, July 2026)

```
┌──────────────────────────────────────────────────────────────────────┐
│                   NEXUS HIVE — TARGET (POST-OC2)                     │
│                                                                      │
│  OC1: Mac Mini M4 24GB                                               │
│  Role: Production (retained), supporting node post-OC2               │
│                                                                      │
│  OC2-A: Mac Mini M4 Pro 48GB (TRIGGER-01: arrival → setup)          │
│  Role: HA Primary. Local Gemma4:26b inference. Aria migration.       │
│  Estimate: 6–13 July 2026. Commission ~27 Jul 2026.                  │
│                                                                      │
│  OC2-B: Mac Mini M4 Pro 48GB (TRIGGER-02: both live → HA active)    │
│  Role: HA Secondary / Hot Standby.                                   │
│                                                                      │
│  NAS: Shared model weights + backup destination.                     │
│  Encryption: S7 (pending OC2 arrival).                               │
│  Strategy: 3-2-1+1 backup (NAS hourly, S3 Sydney daily, USB weekly)  │
│                                                                      │
│  All nodes: Tailscale mesh. Zero-trust. loopback-only OpenClaw bind. │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### 4.3 External Access Architecture

| Access Method | Current State | Target State |
|---------------|---------------|-------------|
| Developer/Admin | Tailscale mesh (zero-trust) | Tailscale mesh (retained) |
| Client chat | Loopback (internal only) | Cloudflare Tunnel → `chat.ainchors.com` (Sprint 4) |
| MinIO (storage) | Tailscale Serve (internal) | Tailscale Funnel (KL team) |
| Google Remote Desktop | Available (post-RustDesk unlock) | Retained |
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
| Agent Layer | MinIO (4 buckets) | Agent memory, generated media, workspace assets, brand code | LIVE (Sprint 3) |
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

### 5.1 Current State — Honest Assessment (Day 20)

The current data architecture is a P1 baseline: functional for single-tenant internal operations, but structurally insufficient for P2 multi-tenant or P4 FSI deployment. Specific gaps:

| Area | Current State | Gap |
|------|--------------|-----|
| Structured state | ~40+ ad-hoc JSON files in `workspace/state/` | No schema validation, no ownership model, no classification tagging |
| Knowledge | Markdown files (MEMORY.md, SOUL.md, RULES.md, daily notes) | No formal index, no RAG pipeline |
| Source of truth | Notion (Holocron) — human-managed wiki | Not enforced programmatically; Ken manually corrects state |
| Database | No Postgres deployed | No formal episodic audit log, no pgvector |
| State ownership | Fragmented across `workspace/state/`, `workspace-social/state/`, `canvas/`, `tmp/` | No ownership model, no schema validation |
| Data lineage | None formal | Ken manually corrects state inconsistencies |

**Proof point:** The LinkedIn dual-post incident (Day 20, 2026-05-14) demonstrated all three structural gaps in production: no source of truth, no typed event for cancellation propagation, no channel-agnostic instruction layer. The same failure class is structurally repeatable until Phase 1 is complete.

### 5.2 Five-Tier Memory Architecture (APPROVED — TKT-0104)

| Tier | Name | Technology (Current) | Technology (Target) | Status | Locked Decisions |
|------|------|---------------------|--------------------|---------|-----------------| 
| **T1** | Working Memory (Context Window) | LLM context window — OpenClaw implicit | Same — disciplined token budget policy | Exists | Token budget policy to define |
| **T2** | Session Memory | OpenClaw implicit session state — no TTL, no audit | Postgres session tables (P1) → Redis (P2, TTL 24h, tenant-isolated) | Partial | Postgres P1 → Redis P2 (LOCKED — TKT-0104 D8) |
| **T3** | Episodic / Audit Log | None | Postgres: `agent_events`, `agent_decisions`, `decision_lineage`, `memory_access_log`. SHA-256 per record. | **Must build Phase 1** | Append-only, SHA-256 tamper evidence |
| **T4** | Semantic Memory (RAG) | None | pgvector (768-dim, nomic-embed-text local). Tables: `knowledge_chunks`, `knowledge_documents` | **Must build Phase 1** | pgvector (LOCKED — TKT-0104 D1), nomic-embed-text 768-dim (LOCKED — TKT-0104 D2) |
| **T5** | Shared Multi-Agent State | Ad-hoc JSON files | Postgres: `agent_shared_state` (optimistic locking + version column), `agent_state_history` (append-only seed of event log) | **Must build Phase 1** | Optimistic locking P1–P2 (LOCKED — TKT-0104 D4), event sourcing P3 (TRIGGER-14) |

### 5.3 Data Classification

| Category | Definition | Current State | P2 Enforcement |
|----------|------------|---------------|----------------|
| **Client** | Data belonging to or about external clients | ❌ None (no external clients) | RBAC by tenant_id, strict isolation |
| **Internal** | AInchors operational and business data | ✅ Exists, unclassified | Separated from tenant data stores |
| **System** | Platform-generated metrics, logs, health data | ✅ Exists | Per-tenant metrics, isolated |
| **Operational** | Task states, tickets, scripts, change records | ✅ Exists in JSON files | Migrating to Postgres (Phase 1) |
| **Repository** | Knowledge base, governance frameworks | ✅ Markdown files | RAG pipeline (Phase 1) |
| **Backup** | Point-in-time copies | ✅ Daily cron | Encrypted at rest |

**Classification Labels (to be enforced from P2):** `PUBLIC` / `INTERNAL` / `CONFIDENTIAL` / `RESTRICTED`

### 5.4 Data Sovereignty Rules (DS-1 to DS-5)

| Rule | Statement |
|------|-----------|
| **DS-1** | Client data NEVER leaves OC1 / the local HIVE. Tier 0/1 local ONLY. |
| **DS-2** | Client data NEVER routes to Tier 2/3 cloud APIs (Anthropic, Ollama Cloud). |
| **DS-3** | Client data is NEVER co-mingled with AInchors operational data. |
| **DS-4** | BYOK exception: P4 clients supply own LLM API keys. Client owns their DPA compliance. |
| **DS-5** | Anthropic DPA verification required before any client data touches Claude APIs. (Status: DPA verified — TKT-0104 D5.) |

### 5.5 Target Data Architecture — Phase 1 (Sprints 4–8)

#### Sources of Truth Register (TKT-0166 — Sprint 4)

The Sources of Truth Register defines the canonical storage location for each data domain. Enforced at architecture level, not convention.

| Data Domain | Source of Truth (Target) | Current State | Owner Agent | Phase |
|-------------|--------------------------|---------------|-------------|-------|
| Tickets | Postgres `tickets` table + Notion AKB Backlog | `tickets.json` | ITSM subsystem (via `ticket.sh`) | Phase 1 |
| Cost events | Postgres `cost_events` table | `state/cost-*.json` | cost-tracker script | Phase 1 |
| Agent health | Postgres `agent_health` table | `state/health-state.json` | Forge / Warden | Phase 1 |
| Change records | Postgres `change_records` table + Notion AKB Backlog | `state/changelog.json` | changelog-append.sh | Phase 1 |
| Workflow state | Postgres `workflow_state` table | `state/async-tasks.json`, `active-work.json` | Yoda / orchestration layer | Phase 1 |
| LinkedIn posts | Postgres `linkedin_posts` table | `state/linkedin-queue.json` (dual-file problem) | Spark | Phase 1 |
| Agent config | `openclaw.json` (authoritative) | `openclaw.json` | Ken / Yoda | Exists |
| Model drift | `state/model-drift-state.json` | `state/model-drift-state.json` | Warden | Interim |
| Memory (long-term) | `MEMORY.md` + daily notes (P1) → Postgres T3 (Phase 1) | `MEMORY.md` | Yoda | Transitioning |
| Knowledge base | pgvector `knowledge_chunks` / `knowledge_documents` | Markdown files (unindexed) | Atlas / RAG pipeline | Phase 1 |

#### Top 5 JSON→Postgres Migrations (TKT-0167 — Sprint 5/6)

Priority-ordered migrations for Phase 1:

1. **tickets** — `tickets.json` → Postgres `tickets` table (already accessed via `ticket.sh`; Postgres becomes the backend)
2. **cost_events** — Cost event log → Postgres `cost_events` table
3. **agent_health** — `health-state.json` → Postgres `agent_health` table
4. **change_records** — Changelog → Postgres `change_records` table
5. **workflow_state** — `async-tasks.json` + `active-work.json` → Postgres `workflow_state` table

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

---

## 6. Integration Architecture

### 6.1 Current State — Point-to-Point (Day 20)

| Dimension | Current State | Problem |
|-----------|--------------|---------|
| Agent-to-agent | `sessions_send` (string input/output, no contracts, no versioning) | No typing, no retry, no observable failure path |
| State mutations | Direct file writes or script calls — no coordination layer | No conflict detection. Agents bypass scripts. |
| Instruction propagation | Verbal acknowledgement via LLM turn | Not propagated to state (LinkedIn dual-post proof, TKT-0162 Section 2.3) |
| LLM-for-CRUD | Ticket updates, cost writes, state changes all route through Sonnet/Haiku | Unnecessary cost, latency, non-determinism |
| Integration layer | None | No work type separation, no routing by currency |

### 6.2 Work Currency Model (APPROVED — 2026-05-14, TKT-0162)

The Work Currency Model governs which compute tier executes which work. This is the primary cost justification for building the integration layer.

| Work Currency | Definition | Compute Tier | Estimated Cost |
|---------------|------------|-------------|----------------|
| **High** | Reasoning, judgment, design, planning, novel content, decisions requiring complex synthesis | T3: Claude Sonnet/Haiku/Opus | Pay-per-token |
| **Medium** | Template content generation, structured analysis, summarisation, classification, moderate reasoning | T2: Ollama Cloud (kimi-k2.6) | Fixed $100/mo |
| **Low** | State mutations, CRUD, file writes, status updates, simple lookups, templated formatting | T1: Gemma4:26b local (post-OC2) or T0: systemEvent (now) | $0 |
| **None** | Pure system calls, file I/O, API calls to non-LLM services, database reads/writes | T0: Shell script / systemEvent / integration layer | $0 |

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

#### Why This Eliminates LinkedIn-Type Incidents

Under Phase 1 architecture:
- Post cancellation = typed `post_cancellation` event on the event bus
- Queue state = single `linkedin_posts` table in Postgres (one source of truth)
- Posting logic = reads only from that table (never from JSON file)
- Cron deletion = part of the typed event handler (automated, not manual)

The incident class becomes architecturally impossible, not a matter of discipline.

### 6.5 External Integration Points

| Integration | Technology | Classification | Notes |
|-------------|-----------|----------------|-------|
| Google Workspace | gog CLI (`/opt/homebrew/bin/gog`) | Adjacent | Account: `kenmun@ainchors.com`. Gmail, Calendar, Drive, Contacts, Sheets, Docs. Always use full path in exec. |
| Telegram (Ken) | Bot API | Adjacent | @AInchorsOC1Bot → Yoda. ChatID: 8574109706. Emergency: "YODA THIS IS KEN" |
| Telegram (Angie) | Bot API | Adjacent | @AInchorsAriaBot → Aria. ChatID: 8141152780. Strict allowlist. |
| LinkedIn | LinkedIn API | Adjacent | Token valid to 2026-07-12. MDP approved. Managed by Spark. |
| Notion / Holocron | Notion API | Adjacent | SSOT for tickets, CHGs, AKB. DB IDs in MEMORY.md. |
| Anthropic API | Claude | Adjacent | AInchors internal use only. NEVER client data (Decision H). |
| Ollama Cloud | kimi-k2.6, deepseek | Adjacent | AInchors internal only. accounts@ainchors.com. Flat $100/mo. Never client data. |
| GitHub | gh CLI | Adjacent | Account: kenmun-ainchors. Scopes: repo, read:org, gist. |

---

## 7. Component Map

### 7.1 Classification

| Classification | Definition |
|----------------|------------|
| **Core** | Inside Nexus. Owned and operated by AInchors / Aevlith Technologies. |
| **Adjacent** | Outside Nexus. Integrated or consumed (third-party APIs, cloud services). |
| **Client-side** | Deployed in or operated by the client environment (P4 FSI physical deployments). |

**Summary:** Core: 38 | Adjacent: 8 | Client-side: 14

### 7.2 Full Component Tables

#### 7.2.1 Agent Runtime

| Component | Class | Description | Status / Notes |
|-----------|-------|-------------|----------------|
| OpenClaw Gateway | **Core** | Agent orchestration runtime. Session management, tool dispatch, cron scheduling, heartbeats, channel routing. | LIVE. Final platform — no replatforming. v2026.5.5. |
| Session Manager | **Core** | Per-session context lifecycle, token budget enforcement, session isolation. | LIVE (implicit in OpenClaw). Needs formalisation at P2 for per-tenant isolation. |
| Cron Engine | **Core** | Scheduled task execution — health checks, heartbeats, cost tracking, model drift monitoring. | LIVE. 20+ active crons. Must be tenant-scoped at P2. |
| Heartbeat Subsystem | **Core** | Proactive state management loop for Yoda, Aria. Watchdog for task and agent health. | LIVE. Integrated with `HEARTBEAT.md`. |
| Sub-agent Spawner | **Core** | Dynamic spawning of ephemeral task-scoped agents (Atlas, Thrawn, research). | LIVE. Depth limits apply. Push-based completion. |
| Agent SOUL.md / Identity Layer | **Core** | Per-agent identity, traits, rules, persona. Hard limit: <10,000 chars (warn at 6,000). | LIVE. SOUL.md Compact Standard locked 2026-04-30. |

#### 7.2.2 LLM Providers

| Component | Class | Description | Status / Notes |
|-----------|-------|-------------|----------------|
| Anthropic Claude Sonnet 4.6 | **Adjacent** | Primary reasoning model (T3). All AInchors-internal complex tasks. | LIVE. NEVER for client PII/regulated data. DPA verified. |
| Anthropic Claude Haiku 4.5 | **Adjacent** | Governance agents (Shield, Lex, Sage, Warden, Forge, Ahsoka). Cost-optimised. | LIVE. Migrates to Gemma4 at TRIGGER-03. |
| Anthropic Claude Opus 4.7 | **Adjacent** | Available for exceptional reasoning tasks. | Available, not default. |
| Ollama Cloud — kimi-k2.6 | **Adjacent** | Tier 2B. Spark social content, medium-currency tasks. AInchors-internal only. | LIVE (TRIGGER-05 fired). accounts@ainchors.com. $100/mo. |
| Ollama Cloud — deepseek-flash / pro | **Adjacent** | Tier 2. Supplementary cloud inference. | Available. |
| Ollama Local — Gemma4:26b | **Core** (post-TRIGGER-03) | Tier 1 local inference. Client-facing workloads. Zero data residency risk. | Waiting OC2-A. Gemma4:e2b preview on OC1 (background/non-interactive only). |
| Ollama Local — Gemma4:31b-cloud | **Adjacent** | Experimental. ≥75% gate before prod. | TKT-0134 review ~2026-05-18. |
| Ollama Local — nomic-embed-text | **Core** | Embedding model (768-dim). Local, FSI-safe. Powers RAG/pgvector. | LIVE (Ollama running). Schema deployment pending. |
| BYOK (Bring Your Own Key) | **Client-side** (P4) | P4 enterprise clients supply own LLM API credentials. Client owns their DPA compliance. | Policy LIVE globally. Critical for FSI data sovereignty. |

#### 7.2.3 Memory & Data

| Component | Class | Description | Status / Notes |
|-----------|-------|-------------|----------------|
| Postgres (primary) | **Core** | Relational store for agent events, decisions, shared state, tenant data, audit log. | **Not yet deployed. Phase 1 critical path (TKT-0164, Sprint 5).** |
| pgvector extension | **Core** | Vector/embedding store for RAG pipeline. Schema: `knowledge_chunks`, `knowledge_documents`. | Blocked on Postgres deployment. |
| Redis / Session Cache | **Core** (P2+) | Short-term session state (24h TTL). Tenant-isolated namespace. | Not in P1. Postgres session tables in P1. Redis at P2. |
| Local Filesystem | **Core** | Markdown state files, YAML configs, workspace files, memory files. | Primary persistence in P1. Transitioning to Postgres for structured data. |
| NAS | **Core** (post-OC2) | Shared model weights, backups, cold archive. Tailscale-accessible. | S7 gap: NAS encryption pending OC2 arrival. |
| MinIO (Colima) | **Core** | Object storage (4 buckets). Tailscale-accessible. | LIVE (Sprint 3). |
| SQLite (obs.db, tasks.db) | **Core** | Observability event log, task ledger. | LIVE. To migrate to Postgres at P2. |
| S3 Object Store | **Core** (P2+) | Document blobs, backups, long-term archive. AWS ap-southeast-2 (Sydney). | P4: WORM + AES-256 + 7-year retention. |
| Episodic Audit Log | **Core** | `agent_events`, `agent_decisions`, `decision_lineage`, `memory_access_log`. SHA-256 per record. | **Must build Phase 1. Non-negotiable foundation.** |

#### 7.2.4 Identity & Access

| Component | Class | Description | Status / Notes |
|-----------|-------|-------------|----------------|
| macOS Keychain | **Core** (P1) | Secret storage for all API keys, tokens. Zero hardcoded credentials policy (S5). | LIVE. Migrates to Cloud KMS at P2. |
| Cloud KMS | **Core** (P2+) | Tenant-scoped key management. Annual rotation minimum. | P4: HSM-backed CMK for FSI. |
| Tailscale Mesh | **Core** | Zero-trust mesh networking across HIVE. Loopback-only OpenClaw bind (S2). | LIVE. `ainchorss-mac-mini.tail5e2567.ts.net`. |
| API Tokens (per-agent) | **Core** | Per-agent scoped tokens. S4 least-privilege (CHG-0176). | LIVE. |
| SSO/SAML Stubs | **Core** (P2+) | Organisation-level auth hooks. `org_id` field, group membership stubbed. | P2: stubs. P3 commercial: full SSO. P4: mandatory. |
| RBAC | **Core** (P2+) | Per-tenant access control matrix. Agent roles scoped to tenant context. | Design at P2. |
| MFA | **Core** (P4) | Mandatory for FSI P4 clients. APRA CPG 234 requirement. | P4 only. |

#### 7.2.5 Integration

| Component | Class | Description | Status / Notes |
|-----------|-------|-------------|----------------|
| OpenClaw Gateway (as API Gateway) | **Core** | Port 18789, loopback-only. Remote via Tailscale. | LIVE. |
| Webhook Dispatcher | **Core** | Outbound webhook support. Part of Holonet v0 at P2. | Not yet built. |
| Telegram Channel Adapters | **Core** | Bidirectional Telegram Bot API. Ken: @AInchorsOC1Bot. Angie: @AInchorsAriaBot. | LIVE. |
| Email Adapter (gog / Gmail) | **Core** | Google Workspace Gmail via gog CLI. `kenmun@ainchors.com`. | LIVE. Always full path: `/opt/homebrew/bin/gog`. |
| Webchat Channel | **Core** | Primary web-based chat interface for Ken. | LIVE. |
| Social Media Adapters (Spark) | **Adjacent** | LinkedIn (connected), Instagram/Facebook/YouTube (not yet). Managed by Spark. | LinkedIn LIVE. Others pending (CHG-0160). |
| Holonet (Real-Time API Layer) | **Core** (P2 v0) | Connects Nexus agents to client business systems: CRM, ERP, REST APIs, webhooks, Google Sheets. | Not built. Holonet v0 Q4 2026. |
| Postgres LISTEN/NOTIFY Event Bus | **Core** | Internal async coordination layer. Replaces ad-hoc `sessions_send` for background tasks. | **Phase 1 build (TKT-0168, Sprint 6).** |

#### 7.2.6 Knowledge Management

| Component | Class | Description | Status / Notes |
|-----------|-------|-------------|----------------|
| Holocron (Notion) | **Adjacent** | SSOT for AKB, tickets, change log, SLA tracker, asset registry. | LIVE. DB IDs in MEMORY.md. |
| File-based Memory | **Core** | `MEMORY.md` (long-term), daily memory files, `SOUL.md`, `RULES.md`, `AGENTS.md`. | LIVE. Markdown only (Obsidian retired). |
| RAG Pipeline | **Core** (building) | pgvector + nomic-embed-text + PII scanner + document ingestion. | **Phase 1 build (TKT-0171, Sprint 7).** |
| PII Scanner | **Core** (building) | spaCy or Presidio-based. Pre-ingestion gate. `pii_present` flag blocks embedding without approval. | **Phase 1 build (TKT-0170, Sprint 5/6).** |
| Knowledge Chunks (pgvector) | **Core** | `knowledge_chunks` (vector(768)), `knowledge_documents`. Per-tenant at P2. | Blocked on Postgres + RAG pipeline. |
| Tenant Knowledge Base | **Core** (P2) | Per-client isolated knowledge namespace within pgvector. Two-tier: AInchors base (read-only) + client layer. | P2 design. |

#### 7.2.7 Observability & Governance

| Component | Class | Description | Status / Notes |
|-----------|-------|-------------|----------------|
| obs.db / obs-collector | **Core** | Agent action event log. Captures tool calls, model choices, soul_truncated events. | LIVE (SQLite). Migrates to Postgres at P2. |
| health-state.json | **Core** | Current state of all agent health checks. 6 checks per cycle. Auto-heal triggers on 3+ failures. | LIVE. |
| auto-heal.sh | **Core** | Nightly 01:00 AEST. 19 checks, auto-fix stale state. Files Notion US for Ken-action items. | LIVE. |
| scripts/run-diagnostics.sh | **Core** | On-demand `/diagnostics`. 7-phase deep inspection. | LIVE. |
| Warden 🔍 | **Core** | Model Compliance Officer. 15-min cron (83accf7b). Checks all agents. Writes violations only. Never acts directly. | LIVE. |
| Beacon (Health Dashboard) | **Core** (Q3 2026) | Unified real-time agent health + cost + task queue observability. | Not yet built. |
| Datapad (Reporting Terminal) | **Core** (Q3 2026) | Weekly ROI summaries, agent performance, cost attribution per tenant. | Not yet built. |
| cost-tracker.sh | **Core** | Daily spend tracking. Daily budget cap: $150 (CHG-0268). Alerts: T1=$60/T2=$55/T3=$15. | LIVE. |
| TRIGGER System | **Core** | 13 defined CHG triggers. State: `state/chg-triggers.json`. | LIVE. |
| architecture-kri-state.json | **Core** | KRI dashboard state. Yoda owns live updates at each sprint review. | LIVE (CHG-0308). |

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
| **S6** | All configuration changes CHG-logged and Warden-monitored. | ✅ LIVE — 230+ CHG records |
| **S7** | NAS encrypted at rest (AES-256). | ⚠️ PENDING — blocked on OC2 arrival |

### 8.2 Sanctum Protocol

The Sanctum is the mandatory governance gate for all external/client outputs. No bypass under any circumstance.

```
All external outputs / client deliverables / published content:
  → Shield 🛡️ (security review)
  → Lex ⚖️ (legal/compliance check)
  → Sage 🧪 (quality gate)
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

**SOP — Anthropic API Key Rotation (LOCKED — 2026-05-13):**
On key expiry/revocation: Ken runs `openclaw models auth` (main session only). Yoda immediately runs `python3 scripts/propagate-anthropic-key.sh` → propagates to all 12 agents. Do not wait. History: CHG-0142 (Day 8), Day 19 (2026-05-13).

---

## 9. Gap Map — Current → Target

### 9.1 Phase 1 Gap (Sprints 4–8, Target: ~8 June 2026)

| Component | Current State | Target State | Ticket | Sprint |
|-----------|--------------|-------------|--------|--------|
| Three Work Types Rule | No formal work classification | Rule codified in RULES.md, wired to all agents | TKT-0165 | S4 |
| Sources of Truth Register | None | 10 core data types with owner/access/retention | TKT-0166 | S4 |
| Postgres Database | Not deployed | Postgres on OC1 with 5-tier schema | TKT-0164 | S5 |
| JSON→Postgres Migration | Ad-hoc JSON files (~40+) | Top 5 files migrated to Postgres | TKT-0167 | S5/S6 |
| PII Scanner | None | spaCy/Presidio pre-ingestion gate, pii_present flag | TKT-0170 | S5/S6 |
| Event Bus | None | Postgres LISTEN/NOTIFY event bus | TKT-0168 | S6 |
| Typed Agent Contracts | None | 4 typed handoffs (JSON Schema, validated at handoff) | TKT-0169 | S7 |
| RAG Pipeline | None | pgvector + nomic-embed-text + ingestion pipeline | TKT-0171 | S7 |
| Cloudflare Tunnel | None | MinIO + webchat exposed (chat.ainchors.com) | TKT-0141 | S4 |
| Architecture KRI Dashboard | Created (Day 20) | Live KRI updates at each sprint review | — | Ongoing |

**P2 Blockers (must complete by Sprint 8):**
- WP1: Postgres + 5-tier schema live
- WP2: Three Work Types Rule enforced
- WP3: Sources of Truth Register documented
- WP4: JSON→Postgres migration (top 5 complete)
- WP5: Event bus operational (at least for LinkedIn queue use case)

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
| Agent output schema library | 4 typed contracts | Full coverage across all 12 agents |

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

| Decision | Locked By | Summary | Date |
|----------|-----------|---------|------|
| **pgvector as vector store** | TKT-0104 Decision 1 | No alternative vector store. Re-embedding entire KB required to change. | 2026-05-08 |
| **nomic-embed-text 768-dim** | TKT-0104 Decision 2 | Embedding dimension locked at table creation. Cannot change without full re-embedding. | 2026-05-08 |
| **RecursiveCharacterTextSplitter 400–600 tokens, 10–20% overlap** | TKT-0104 Decision 3 | Standard chunking strategy. | 2026-05-08 |
| **Optimistic locking P1–P2, event sourcing P3** | TKT-0104 Decision 4 | `agent_state_history` table is seed of future event log. Schema supports migration. | 2026-05-08 |
| **Anthropic DPA verified** | TKT-0104 Decision 5 | DPA verification complete. Claude for non-PII AInchors-internal workloads. Block for client workloads. | 2026-05-08 |
| **Shared schema + RLS from P2 day one** | TKT-0104 Decision 6 / CHG-0234 | Multi-tenant foundation with tenant_id on every table from P2 launch. No schema-per-tenant. | 2026-05-08 |
| **Postgres session tables P1, Redis P2** | TKT-0104 Decision 8 | No Redis in P1. Postgres session tables sufficient for single-tenant. | 2026-05-08 |
| **OpenClaw as final platform** | IT Strategy | No replatforming. All options extend OpenClaw. | Pre-Day 1 |
| **Mac Mini HIVE for P1–P2** | MEMORY.md / IT Strategy | OC1 permanent. OC2-A/B arriving July 2026. No cloud replatforming in this window. | Pre-Day 1 |
| **Block Claude for all P2 client workloads** | TKT-0046 Decision H | BYOK exception: P4 clients bring own keys, own their DPA. AInchors-internal Claude use continues. | 2026-05-12 |
| **P4 consulting-led deployment model** | TKT-0046 Decision B | Not self-service install. Professional services consulting engagement for P4. | 2026-05-12 |
| **Phase structure: P1→P2→P4 (P3=commercial tier within P2)** | CHG-0234 | P3 as build phase DROPPED. P3 is a feature flag within P2 for company/multi-agent tier. | 2026-05-08 |
| **P3 commercial tier = shared schema + RLS feature flag** | CHG-0234 | No separate P3 infrastructure. Feature flag and commercial unlock on P2 foundation. | 2026-05-08 |
| **Option B Phased — Architecture Direction** | TKT-0162 / CHG-0308 | Redesign data + integration layers, keep OpenClaw. Three-phase delivery. | 2026-05-14 |
| **Event sourcing deferred to Phase 3 (TRIGGER-14)** | TKT-0162 / CHG-0308 | Post-P2 stable. `agent_state_history` schema preserves migration path. | 2026-05-14 |
| **4 Typed contracts as Phase 1 scope** | TKT-0162 / CHG-0308 | Yoda→Forge, Yoda→Sanctum, Atlas→Ken, Spark→Yoda. Standing cadence: contract schema as DoD gate for all future agents. | 2026-05-14 |
| **Aevlith Technologies — platform entity** | MEMORY.md | Aevlith = technology holding entity. Silent P1–P3. Surfaces at P4. Domain: aevlith.ai. | 2026-05-09 |
| **Kimi safety net (3-level fallback)** | CHG-0270 | Every agent: 3-level fallback ending in kimi-k2.6:cloud. No exceptions. | 2026-05-13 |

---

## Appendix A — TRIGGER Reference

| Trigger | Condition | Action |
|---------|-----------|--------|
| TRIGGER-01 | OC2-A arrives | OC2-A setup sequence (Gemma4:26b, Aria migration) |
| TRIGGER-02 | Both OC2-A/B live | HA active, NAS encryption (S7) |
| TRIGGER-03 | Gemma4:26b validated ≥75% gate | Swap Haiku → Gemma4 for governance agents (Shield/Lex/Sage/Warden) |
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
| `/Users/ainchorsangiefpl/.openclaw/workspace/docs/Yoda_RULES.md` | Strategic reference + routing rules (v2.0) |
| `/Users/ainchorsangiefpl/.openclaw/workspace/docs/Yoda_RUNBOOK.md` | Full operational procedures + slash commands |
| `/Users/ainchorsangiefpl/.openclaw/workspace/docs/Yoda_ORCHESTRATOR.md` | Platform architecture reference (superseded by this document) |
| `/Users/ainchorsangiefpl/.openclaw/workspace/docs/Nexus_Enterprise_Landscape_P2P4.md` | Component map TKT-0046 (APPROVED) |
| `/Users/ainchorsangiefpl/.openclaw/workspace/docs/DataMemory_P1P4_Roadmap.md` | 5-tier memory architecture TKT-0104 (APPROVED) |
| `/Users/ainchorsangiefpl/.openclaw/workspace/docs/TKT-0162-Option-Paper-Nexus-Architecture-Direction.md` | Architecture direction option paper (APPROVED) |
| `/Users/ainchorsangiefpl/.openclaw/workspace/state/architecture-kri-state.json` | KRI dashboard state (Yoda updates at sprint review) |
| `/Users/ainchorsangiefpl/.openclaw/workspace/state/chg-triggers.json` | TRIGGER system state |
| `/Users/ainchorsangiefpl/.openclaw/workspace/state/model-drift-state.json` | Warden compliance state |

---

## Appendix C — Sprint Plan Reference (Locked Day 20)

| Sprint | Target Date | Key Architecture Deliverables |
|--------|------------|-------------------------------|
| Sprint 4 | May 19–25, 2026 | TKT-0165 (Three Work Types Rule), TKT-0166 (SoT Register), Cloudflare Tunnel, TKT-0141/0142 |
| Sprint 5 | May 26–Jun 1, 2026 | TKT-0164 (Postgres — critical path), TKT-0108, TKT-0130 QBR |
| Sprint 6 | Jun 2–8, 2026 | TKT-0167 (JSON→Postgres migration), TKT-0168 (Event Bus), TKT-0170 (PII Scanner), TKT-0150 |
| Sprint 7 | Jun 9–15, 2026 | TKT-0169 (Typed Contracts), TKT-0171 (RAG Pipeline) |
| Sprint 8 | Jun 16–22, 2026 | P2 blocker verification, Phase 1 sign-off |

---

*Document: DRAFT FOR REVIEW*
*TKT-0173 | Atlas 🏛️ Enterprise Architect | Aevlith Technologies / AInchors*
*2026-05-14 | Day 20 | v1.0*
*Supersedes: Yoda_ORCHESTRATOR.md (architecture sections), TKT-0046 Section 2–3 summaries, TKT-0104 architecture summaries*
