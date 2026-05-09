# Nexus Enterprise Landscape: Solutions and Components P2–P4
**TKT-0046 | Enterprise Architecture Deliverable**
**Status:** DRAFT FOR REVIEW
**Author:** Atlas 🏛️ — Enterprise Architect, AInchors / Aevlith Technologies
**Date:** 2026-05-08
**Version:** v1.0

---

> **Phase Structure Reference (CHG-0234, confirmed Ken 2026-05-08)**
>
> - **P1** — Internal single-tenant (current, OC1)
> - **P2** — SaaS, multi-tenant from day one. P3 commercial tier (company/multi-agent) is a feature flag and commercial unlock **within P2** — not a separate build phase.
> - **P4** — Enterprise / FSI consulting. Regulated sectors. Physical/in-house deployment viable.
> - **P3 as build phase: DROPPED (CHG-0234).** All references to P3 below mean the commercial tier label within P2.

---

## Section 1 — Enterprise Landscape Overview

### Executive Summary

Nexus is Aevlith's agentic AI operations platform — the technical core that powers AInchors' AI training, consulting (Ahsoka), and technology-as-a-service offerings across the P1–P4 commercial trajectory. At P1, Nexus runs entirely within OC1 (a Mac Mini M4 in Melbourne), orchestrating twelve live agents across Yoda's governance layer, Aria's business stream, Spark's social marketing, Atlas/Thrawn's architecture function, and the Sanctum governance triad (Shield, Lex, Sage). The platform is production-grade, ITSM-instrumented, and already differentiated by a four-tier model strategy enforcing client-side data sovereignty.

In the enterprise context, Nexus sits at the centre of a broader landscape spanning four rings: (1) a **core agent runtime** built on OpenClaw, (2) an **integration estate** connecting to LLM providers, communication channels, and knowledge management, (3) **client-facing surfaces** (The Bridge, The Citadel, Datapad, Holonet) that expose value to operators and end-clients, and (4) **governance and observability infrastructure** (Sanctum, Warden, Beacon) that makes Nexus auditable and trusted in regulated environments.

The P2 commercial launch targets end-August 2026, with multi-tenant isolation (tenant_id + RLS on all tables), single-agent deployments as the Standard tier, and the P3 company/multi-agent tier unlockable on demand, ROI-gated. P4 expands to enterprise and FSI (APRA CPG 234/235) clients who may prefer physical/in-house deployment over shared SaaS — a model that is architecturally viable given Nexus's containerised, local-inference-first design.

For Ken, the strategic framing is this: **Nexus is not just an internal tool. It is a deployable, governed, data-sovereign agentic operations platform that can be operated as SaaS, hosted for enterprise, or installed physically in a client's infrastructure.** That breadth — from a Mac Mini in an SME boardroom to a regulated FSI on-prem deployment — is Aevlith's defensible architectural position.

---

## Section 2 — Component Map: Core vs Adjacent

### Classification Legend
- **Core** — Inside Nexus, owned and operated by AInchors/Aevlith Technologies
- **Adjacent** — Outside Nexus, integrated or consumed
- **Client-side** — Deployed in or operated by the client environment (P4)

---

### 2.1 Agent Runtime

| Component | Classification | Description | Notes |
|-----------|----------------|-------------|-------|
| OpenClaw Gateway | **Core** | Agent orchestration runtime. Session management, tool dispatch, cron scheduling, heartbeats, channel routing. | Final platform — no replatforming. All agents run here. |
| Session Manager | **Core** | Per-session context lifecycle, token budget enforcement, session isolation across tenants. | Currently implicit in OpenClaw; needs formalisation at P2 for per-tenant isolation. |
| Cron Engine | **Core** | Scheduled task execution — health checks, heartbeats, cost tracking, model drift monitoring. | 6+ active crons. Must be tenant-scoped at P2. |
| Heartbeat Subsystem | **Core** | Proactive state management loop for lead agents (Yoda, Aria). Watchdog for task and agent health. | Integrated with HEARTBEAT.md; needs obs-collector integration. |
| Sub-agent Spawner | **Core** | Dynamic spawning of ephemeral task-scoped agents. Used for Atlas, Thrawn, and specialised research tasks. | Depth limits apply. Completion push-based. |
| Agent SOUL.md / Identity Layer | **Core** | Per-agent identity, traits, rules, persona. Hard limit: <5,000 chars (truncation risk at 10K). | SOUL.md Compact Standard locked 2026-04-30. |

---

### 2.2 LLM Providers

| Component | Classification | Description | Notes |
|-----------|----------------|-------------|-------|
| Anthropic Claude Sonnet 4.6 | **Adjacent** | Primary reasoning model. Tier 3 (pay-per-token). All AInchors-internal complex tasks. | NEVER for client PII/regulated data. DPA verification required. |
| Anthropic Claude Haiku 4.5 | **Adjacent** | Governance agents (Shield, Lex, Sage, Warden). Cost-optimised. Migrates to Gemma4 at TRIGGER-03. | Current: all governance agents using Haiku. |
| Ollama Cloud — kimi-k2.6 | **Adjacent** | Tier 2B. Spark social content, RTB tasks. AInchors-internal only. | accounts@ainchors.com. Flat $100/mo. Never client data. |
| Ollama Cloud — deepseek-flash / pro | **Adjacent** | Tier 2. Supplementary cloud inference. | TRIGGER-05 fired 2026-05-02. Active. |
| Ollama Local — Gemma4:26b (OC2) | **Core** (post-TRIGGER-01) | Tier 1 local inference. Client-facing workloads. Zero data residency risk. | Needs OC2-A. Current: Gemma4:e2b preview on OC1 only. |
| Ollama Local — nomic-embed-text | **Core** | Embedding model (768-dim). Local, FSI-safe. Powers RAG/pgvector. | Dimension locked at P1. |
| BYOK (Bring Your Own Key) | **Client-side** (P4) | P4 enterprise clients supply their own LLM API credentials. Nexus routes workloads through client-provided models. | BYOK policy live globally. Critical for FSI data sovereignty. |

---

### 2.3 Memory and Data Layer

| Component | Classification | Description | Notes |
|-----------|----------------|-------------|-------|
| Postgres (primary) | **Core** | Relational store for agent events, decisions, decision lineage, shared state, tenant data, audit log. | P2: tenant_id + RLS on all tables. P4: TDE + WORM. |
| pgvector extension | **Core** | Vector/embedding store for RAG pipeline. Schema: knowledge_chunks, knowledge_documents. | 768-dim locked. PII gate before ingestion. |
| Redis / Session Cache | **Core** (P2+) | Short-term session state (24h TTL). Tenant-isolated namespace. | Postgres session tables in P1. Redis at P2. |
| Local Filesystem | **Core** | Markdown state files, YAML configs, workspace files, memory files (MEMORY.md, daily notes). | Primary persistence in P1. Transitions to Postgres for structured data at P2. |
| NAS (Synology or equiv.) | **Core** (post-OC2) | Shared model weights, backups, cold archive. Tailscale-accessible across HIVE. | S7 gap: NAS encryption pending OC2. |
| SQLite (obs.db, tasks.db) | **Core** | Observability event log, task ledger. Lightweight structured data for agent events. | To be migrated to Postgres at P2. |
| S3-compatible Object Store | **Core** (P2+) | Document blobs, backups, long-term archive. AWS ap-southeast-2 (Sydney) or MinIO self-hosted. | P4: WORM + AES-256 + 7-year retention. |
| Episodic Audit Log | **Core** | agent_events, agent_decisions, decision_lineage, memory_access_log tables. SHA-256 hash on records. | TKT-0104 Action 1. Must be built in P1. Foundation for P4 APRA compliance. |

---

### 2.4 Identity and Access

| Component | Classification | Description | Notes |
|-----------|----------------|-------------|-------|
| macOS Keychain | **Core** (P1) | Secret storage for API keys, tokens. Zero hardcoded credentials policy. | Migrates to Cloud KMS at P2. |
| Cloud KMS (AWS KMS or Azure Key Vault) | **Core** (P2+) | Tenant-scoped key management. Annual rotation minimum. | P4: HSM-backed CMK for FSI clients. |
| Tailscale Mesh | **Core** | Zero-trust mesh networking across HIVE nodes (OC1, OC2-A/B, NAS). S2: loopback bind, never public. | Remote admin, dev access. Not for client traffic in P2. |
| API Tokens (per-agent) | **Core** | Per-agent scoped tokens. S4 least-privilege applied CHG-0176. | Separate tokens per client at P2. |
| SSO/SAML Stubs | **Core** (P2 stub, P4 full) | Organisation-level auth hooks. org_id field, group membership stubbed in P2 schema. Full SSO at P3 commercial tier unlock / P4. | P3 commercial tier gated on this. |
| RBAC (Role-Based Access Control) | **Core** (P2+) | Per-tenant access control matrix. Agent roles scoped to tenant context. | Access control matrix defined in DataMemory_P1P4_Roadmap.md. |
| MFA | **Core** (P4) | Mandatory for FSI P4 clients. All access events logged to immutable audit trail. | APRA CPG 234 requirement. |

---

### 2.5 Integration Layer

| Component | Classification | Description | Notes |
|-----------|----------------|-------------|-------|
| OpenClaw Gateway (as API Gateway) | **Core** | Receives channel-specific requests, routes to agents, returns responses. Port 18789, loopback-only. | Remote access via Tailscale only. |
| Webhook Dispatcher | **Core** | Outbound webhook support for external system notifications. | Part of Holonet v0 at P2. |
| Telegram Channel Adapter | **Core** | Bidirectional Telegram Bot API integration. Ken: @AInchorsOC1Bot (Yoda). Angie: @AInchorsAriaBot (Aria). | Per-client bots at P2. |
| Email Adapter (gog / Gmail) | **Core** | Google Workspace Gmail integration via gog CLI. kenmun@ainchors.com. | Accounts: GOG_ACCOUNT env var. Full path: /opt/homebrew/bin/gog. |
| Webchat Channel | **Core** | Primary web-based chat interface for Ken (main session). | dashboard session: agent:main:dashboard:... |
| Social Media Adapters (Spark) | **Adjacent** | LinkedIn, Instagram, Facebook, YouTube APIs. Managed by Spark agent. | CHG-0160. Governed: content-governance-review.sh. |
| Holonet (Real-Time API Layer) | **Core** (P2 v0, P4 full) | Connects Nexus agents to client business systems: CRM, ERP, REST APIs, webhooks, Google Sheets connectors. | Holonet v0 in Q4 2026. Full real-time data integration bus at Year 2. |
| REST API (Nexus Public API) | **Core** (P2) | Exposed API surface for The Citadel and external system integrations. Tenant-scoped. | Needs design. OpenAPI spec to be produced. |

---

### 2.6 Knowledge Management

| Component | Classification | Description | Notes |
|-----------|----------------|-------------|-------|
| Holocron (Notion) | **Adjacent** (primary in P1/P2) → **Core** (API-first at P2) | Single source of truth for AKB, tickets, change log, SLA tracker, asset registry, journal, blog. | DB IDs in MEMORY.md. API-first formalisation at Q3 2026. |
| File-based Memory | **Core** | MEMORY.md (long-term), daily memory files, SOUL.md, RULES.md, AGENTS.md. Workspace on OC1. | Obsidian RETIRED. Markdown only. |
| RAG Pipeline | **Core** (building) | pgvector + nomic-embed-text + PII scanner + document ingestion pipeline. | TKT-0104 Action 4/5. Must be built in P1. |
| PII Scanner | **Core** | spaCy or Presidio-based. Pre-ingestion gate. pii_present flag blocks embedding without approval. | TKT-0104 Action 5. |
| Knowledge Chunks (pgvector) | **Core** | knowledge_chunks and knowledge_documents tables. 768-dim vectors. Per-tenant at P2. | Shared base layer (AInchors) + per-tenant layer (client) at P2. |
| Tenant Knowledge Base | **Core** (P2) | Per-client isolated knowledge namespace within pgvector. | Two-tier model: AInchors base (read-only to tenants) + client layer. |

---

### 2.7 Observability, Health, and Governance

| Component | Classification | Description | Notes |
|-----------|----------------|-------------|-------|
| obs-collector.sh / obs.db | **Core** | Agent action event log. Captures tool calls, model choices, soul_truncated events. | SQLite → Postgres migration at P2. |
| health-state.json | **Core** | Current state of all agent health checks. 6 checks per cycle. | Auto-heal triggers on 3+ failures. |
| auto-heal.sh | **Core** | Nightly 23:30 AEST. 12 checks, auto-fix stale state. Files Notion US for Ken-action items. | CHG reference in auto-heal output. |
| scripts/run-diagnostics.sh | **Core** | On-demand /diagnostics. 6-phase deep inspection. | Yoda command: /diagnostics. |
| Warden 🔍 | **Core** | Model Compliance Officer. Checks all 9 agents every 15 min. Writes violations. Never acts directly. Reports to Yoda. | Cron: 83accf7b. State: model-drift-state.json. Escalation: warden-escalation-pending.json. |
| Beacon (Health Dashboard) | **Core** (Q3 2026) | Unified real-time agent health + cost + task queue observability. Replaces fragmented obs.db + health-state.json. | Not yet built. Q3 2026. OKR X1-KR1. |
| Datapad (Reporting Terminal) | **Core** (Q3 2026) | Weekly ROI summaries, agent performance, cost attribution per tenant, governance review status. | Client-facing. PDF/Notion output. Q3 2026. |
| cost-tracker.sh | **Core** | Daily spend tracking. Confirmed balance − spent after date model. | CHG-0098. Midday cron. T1=$60/T2=$55/T3=$15 alerts. |
| TRIGGER system | **Core** | 12 defined CHG triggers. State: state/chg-triggers.json. | Governs OC2, model promotions, P2 client onboarding, etc. |

---

### 2.8 ITSM and Governance (The Sanctum)

| Component | Classification | Description | Notes |
|-----------|----------------|-------------|-------|
| Shield 🛡️ | **Core** | Security governance agent. Pre-publish security scan. Tier 4 Triad. Model: Haiku (→ Gemma4 at TRIGGER-03). | RULES: SHIELD_RULE_1.md. |
| Lex ⚖️ | **Core** | Legal/compliance agent. AU law, APP, platform ToS. Tier 4 Triad. | RULES: LEX_RULES.md. |
| Sage 🧪 | **Core** | QA agent. Source verification, definition-of-done, quality gate. Tier 4 Triad. | RULES: SAGE_RULES.md. |
| Sanctum Gate Flow | **Core** | Shield → Lex → Sage gate sequence. Mandatory for: external sends, proposals, published content, client deliverables. | 100% adherence required per OKR S2-KR2. |
| scripts/ticket.sh | **Core** | ITSM ticketing (TKT-NNNN). Ticket-first rule. Auto-syncs to Notion AKB Backlog. | TKT before any work. |
| scripts/changelog-append.sh | **Core** | CHG-NNNN auto-increment. Auto-syncs to Notion AKB Backlog. | >230 CHG records to date. |
| Incident Log | **Core** | Per-incident logging. PIR process. scripts/incident-log.sh. | Linked to Notion AKB. |
| scripts/pvt.sh | **Core** | Post-op validation test. 9/9 pass required after every risky op. | Yoda command: /pvt. |
| Agile Framework v1.0 | **Core** | Agile L2→L3. Sprint cadence. CHG-0222. | Sprint 1 started 2026-05-07. |

---

### 2.9 Client-Facing Surfaces

| Component | Classification | Description | Notes |
|-----------|----------------|-------------|-------|
| The Bridge | **Core** | Real-time ops command centre for Ken and Yoda. Agent status, task queue, alerts. | Primary internal ops surface. |
| The Citadel | **Core** (P2 Q3 2026) | Per-client access portal. Workflow status, SLA reporting, document access, Datapad view. | First version: lightweight (Notion or simple web). Full portal at Year 2. |
| Datapad | **Core** (P2 Q3 2026) | Client-facing reporting terminal. ROI summaries, governance review log, cost attribution. | PDF/Notion output. Consulting upsell trigger. |
| Holonet | **Core** (P2 Q4 2026) | Live data feeds. Real-time API integration layer to client business systems. | v0: REST/webhook/Sheets. v1: production-grade connectors at Year 2. |
| Morning Stand-up (Telegram) | **Core** | Daily 8AM AEST. Brief + new input + US capture + RTB recommendations to Ken via Telegram. | Interim model until OC2. |

---

### 2.10 Infrastructure (HIVE Architecture)

| Component | Classification | Description | Notes |
|-----------|----------------|-------------|-------|
| OC1 (Mac Mini M4 24GB) | **Core** | Primary production node. All current agents. PERMANENT. Hard limit: no local LLM >~8B Q4. | Melbourne. Always-on. Single node — no HA until OC2. |
| OC2-A (Mac Mini M4 Pro 48GB) | **Core** (July 2026) | HA Primary. Local inference primary. Gemma4:26b. Aria migration. | TRIGGER-01 fires on arrival. |
| OC2-B (Mac Mini M4 Pro 48GB) | **Core** (July 2026) | HA Secondary / hot standby. | TRIGGER-02: both nodes live → HA active. |
| NAS (Shared) | **Core** (post-OC2) | Shared model weights + state. Tailscale-accessible. S7: encryption pending OC2. | 3-2-1+1 backup strategy. |
| Tailscale Mesh | **Core** | Zero-trust overlay network across HIVE. Loopback-only OpenClaw bind. S2 compliance. | Dev/admin access only. Not for client data traffic. |
| Docker (Multi-client) | **Core** (P2 Q2 2026) | Per-client container isolation. Separate filesystem, process, network, credentials per tenant. | Docker-based multi-tenant deployment per IT strategy. |
| Backup (scripts/backup.sh) | **Core** | Daily 2:00 AM workspace backup. 3-2-1+1 strategy from Q1 2026. | NAS (hourly), S3 Sydney (daily), USB SSD (weekly). |

---

## Section 3 — Phase Evolution Matrix

States: **Exists** | **Enhanced** | **New Build** | **External/Client** | **N/A**

| Component | P1 (Current) | P2 (SaaS Multi-tenant) | P3 Commercial Tier (within P2) | P4 (Enterprise/FSI) |
|-----------|-------------|------------------------|-------------------------------|---------------------|
| **OpenClaw Gateway** | Exists | Enhanced (multi-tenant sessions, per-tenant cron scoping) | Enhanced (company-level session context, org-scoped routing) | External/Client (on-prem deployable instance) |
| **Session Manager** | Exists (implicit) | Enhanced (tenant_id isolation, TTL enforcement) | Enhanced (org-level shared sessions) | External/Client (APRA-grade session audit) |
| **Cron Engine** | Exists | Enhanced (tenant-scoped crons) | Enhanced | External/Client |
| **Agent SOUL.md / Identity** | Exists | Enhanced (per-client agent persona config) | Enhanced (org-level agent teams) | External/Client |
| **Claude Sonnet 4.6** | Exists | Exists (AInchors-internal only) | Exists | Exists (non-PII, non-regulated only) |
| **Claude Haiku 4.5** | Exists (governance) | Exists → migrates to Gemma4 at TRIGGER-03 | Migrated to Gemma4 | N/A (Gemma4 local preferred) |
| **Ollama Cloud (kimi/deepseek)** | Exists | Exists (AInchors-internal) | Exists (AInchors-internal only — never client data) | N/A (local-only for regulated) |
| **Gemma4:26b Local (Tier 1)** | N/A (waiting OC2) | New Build (OC2-A, TRIGGER-01) | Exists | External/Client (primary model for FSI) |
| **nomic-embed-text (local)** | Exists (planned) | Exists | Exists | External/Client |
| **BYOK** | Exists (policy live) | Exists | Exists | External/Client (mandatory for FSI) |
| **Postgres (primary)** | New Build (P1 action 1) | Enhanced (RLS, tenant_id, multi-tenant schemas) | Enhanced (org-level shared state) | External/Client (TDE, WORM, HSM) |
| **pgvector / RAG** | New Build (P1 action 4) | Enhanced (per-tenant knowledge namespaces) | Enhanced (shared org knowledge layer) | External/Client (PII-hardened, quality-gated) |
| **Redis / Session Cache** | N/A | New Build (P2) | Exists | External/Client (max 8h TTL, PII-free) |
| **S3 Object Store** | N/A | New Build (AWS ap-southeast-2) | Exists | External/Client (WORM + AES-256) |
| **Episodic Audit Log** | New Build (P1 action 1) | Enhanced (per-tenant, exportable) | Enhanced (org-wide aggregation) | External/Client (WORM, 7yr, hash-verified) |
| **macOS Keychain** | Exists | Deprecated → Cloud KMS | Cloud KMS | External/Client (HSM-backed CMK) |
| **Cloud KMS** | N/A | New Build | Exists | External/Client |
| **Tailscale Mesh** | Exists | Exists (admin only) | Exists | External/Client (site-to-site VPN for on-prem) |
| **SSO/SAML** | N/A | New Build (stubs only in P2 schema) | Enhanced (full SSO unlock — P3 commercial tier gate) | External/Client (mandatory for FSI) |
| **RBAC** | N/A | New Build | Enhanced (org-level roles) | External/Client (full RBAC + MFA audit) |
| **Telegram Adapter** | Exists | Enhanced (per-client bot provisioning) | Enhanced | External/Client (optional) |
| **Email Adapter (gog)** | Exists | Exists | Exists | External/Client (client's own email) |
| **Holonet (API Layer)** | N/A | New Build v0 (Q4 2026) | Exists | External/Client (full integration bus) |
| **REST API (Nexus Public)** | N/A | New Build | Exists | External/Client |
| **Holocron (Notion)** | Exists | Enhanced (API-first, per-client folders) | Enhanced | External/Client (client's own KB) |
| **RAG Pipeline** | New Build | Exists | Exists | External/Client |
| **PII Scanner** | New Build (P1 action 5) | Exists | Exists | External/Client (mandatory, compliance-gated) |
| **Warden** | Exists | Enhanced (multi-tenant compliance monitoring) | Enhanced | External/Client (or AInchors-managed) |
| **Beacon (Dashboard)** | N/A | New Build (Q3 2026) | Exists | External/Client |
| **Datapad (Reporting)** | N/A | New Build (Q3 2026) | Enhanced (org-level reporting) | External/Client |
| **Shield / Lex / Sage** | Exists | Enhanced (per-tenant review flows) | Enhanced | External/Client (or AInchors-managed triad) |
| **The Citadel (Client Portal)** | N/A | New Build (Q3 2026) | Enhanced | External/Client |
| **The Bridge (Ops Centre)** | Exists (internal) | Exists (internal) | Exists | External/Client (optional ops dashboard) |
| **OC1** | Exists | Exists (primary until OC2 ready) | Exists | External/Client (on-prem node option) |
| **OC2-A/B** | N/A | New Build (July 2026) | Exists | External/Client (on-prem HA cluster option) |
| **Docker (multi-client)** | N/A | New Build (Q2 2026) | Exists | External/Client (containerised deployment) |
| **NAS** | N/A (planned) | New Build (OC2 arrival) | Exists | External/Client (on-prem storage) |
| **ITSM / Change Control** | Exists | Enhanced (client-facing SLA reports) | Enhanced | External/Client (APRA-grade change records) |
| **Agile Framework** | Exists | Exists | Exists | Exists |

---

## Section 4 — Integration Architecture (P2)

### 4.1 What Does a P2 Client Connect To?

At P2, a client interacts with Nexus through a defined set of surfaces and integration points:

```
Client (browser / mobile / system)
    │
    ├── [The Citadel]  ← Web portal: status, reports, document access
    │       │
    │       └── Nexus Public REST API  ← Authenticated, tenant-scoped
    │
    ├── [Telegram Bot]  ← Per-client bot (@ClientAIBot). Async notifications, alerts
    │
    ├── [Holonet Webhooks]  ← Client system → Nexus (CRM events, data triggers)
    │
    └── [Datapad Reports]  ← PDF/Notion reports delivered on schedule
```

Internally, the client's OpenClaw instance (Docker container) runs on AInchors-hosted infrastructure (OC1 → OC2 from July 2026), with complete isolation at the filesystem, process, network, and credential layers.

---

### 4.2 APIs Exposed at P2

| API Surface | Description | Auth Method | Tenant Isolation |
|-------------|-------------|-------------|------------------|
| Nexus Public REST API | Agent session control, task status, knowledge base query, report retrieval | API Key (per-tenant, per-client) | tenant_id in all queries, enforced at API layer |
| The Citadel Web Interface | Client dashboard — agent status, Datapad reports, governance log, document access | OAuth2 / session token | Tenant-scoped session; no cross-tenant access |
| Telegram Bot API (per-client) | Async notification channel. Alerts, summaries, approvals-required | Telegram bot token (separate per client) | Each client has their own bot. No shared bot. |
| Holonet Inbound Webhooks | Client system events → Nexus agent triggers | HMAC signature verification | Tenant endpoint path isolation |
| Holocron Knowledge API | Notion-backed knowledge retrieval for Ahsoka proposals and agent context | Service account (per-tenant Notion page scope) | Per-client Notion folder scope |

---

### 4.3 Multi-Tenancy at Each Integration Point

Multi-tenancy in P2 is **row-level security (RLS) first** — confirmed Ken 2026-05-08 (CHG-0234). Every integration point must respect and enforce this model:

| Integration Point | Multi-Tenancy Mechanism | Cross-Tenant Risk | Mitigation |
|-------------------|------------------------|-------------------|------------|
| Postgres (all tables) | tenant_id NOT NULL on every table + Postgres RLS policies | High (SQL injection, misconfigured RLS) | RLS enforced at DB level; application layer secondary check; access via connection pool scoped to tenant role |
| REST API | API key maps to tenant_id in auth middleware | Medium | JWT or API key contains tenant claim; middleware validates before any DB query |
| Docker containers | Process + filesystem + network isolation per client | Low (container escape) | Minimal — Docker provides strong process isolation; file paths never shared |
| Telegram Bots | Separate bot token per client | Low | Bot tokens stored in per-client secret store; Nexus maps bot ID → tenant_id |
| Webhook endpoints | Per-tenant URL namespace (/tenant/{id}/webhook) + HMAC | Medium | HMAC validation + tenant claim in URL; no shared endpoint |
| pgvector / Knowledge Base | Schema-per-tenant OR tenant_id + RLS on knowledge_chunks | High (semantic leakage) | RLS on all knowledge tables; shared AInchors base layer is read-only to all tenants and contains zero client data |
| Audit Log | tenant_id on all audit records; tenant admin can export their own | Low | AInchors platform team access requires audit log entry itself |

---

### 4.4 Authentication and Authorisation Flow (P2)

```
1. Client authenticates to The Citadel (OAuth2 / API key)
2. Auth middleware resolves tenant_id from credential
3. Request forwarded to Nexus Public API with tenant_id in header
4. API layer sets Postgres session variable: SET LOCAL app.tenant_id = 'tenant_xyz'
5. All Postgres queries automatically filtered by RLS policy: WHERE tenant_id = current_setting('app.tenant_id')
6. Agent actions logged to agent_events with tenant_id
7. API response returned — no cross-tenant data possible at DB level

For P3 commercial tier (company/multi-agent):
7b. Organisation-level auth: org_id resolves multiple user accounts under one tenant
7c. Company agents share state within org namespace (org_id prefix on shared state keys)
7d. SSO/SAML integration hook fires if configured (feature flag enabled per commercial agreement)
```

---

### 4.5 Data Flows — What Crosses the Tenant Boundary?

| Data Flow | Crosses Tenant Boundary? | Notes |
|-----------|--------------------------|-------|
| Client agent outputs → Datapad report | ❌ No | Stays within client's tenant namespace |
| AInchors base knowledge (Holocron shared layer) → Client agent context | ✅ Read-only, controlled | AInchors base layer is non-PII, governance docs. Read-only. No client data flows back. |
| Client knowledge base → AInchors | ❌ Never | Client knowledge stays in client's pgvector namespace. RLS enforces this. |
| Client data → LLM (Claude/Ollama Cloud) | ❌ Prohibited | Data sovereignty rule: client data → Tier 1 (Gemma4 local) ONLY. Never Tier 2/3 cloud APIs. |
| Sanctum governance review output | ❌ No | Shield/Lex/Sage review is per-tenant. Results stay in client audit log. |
| Warden compliance monitoring | ❌ No | Warden reads per-agent compliance state; reports to Yoda. No cross-tenant data in reports. |
| Billing/usage metrics | ✅ Aggregate only | AInchors needs aggregated cost/usage for billing. No client content in billing data. tenant_id + token_count only. |
| Incident escalation to Yoda | ✅ Tenant-ID tagged | Yoda receives incident with tenant_id tag. No client content in the escalation. |

---

## Section 5 — P4 Enterprise / Physical Deployment Considerations

### 5.1 Physical/In-House Deployment: Viable Assessment

**Verdict: Viable. Nexus's architecture is well-suited to physical/in-house deployment.**

Ken's note (2026-05-08): *P4 enterprise clients may prefer physical/in-house deployment over P3 SaaS multi-agent.* This is architecturally sound given:

- OpenClaw runs natively on Mac Mini M-series hardware (proven on OC1/OC2). The same hardware can be supplied to or purchased by an FSI client and deployed in their data centre or server room.
- Gemma4:26b runs locally on Mac Mini M4 Pro 48GB — covering all regulated workloads with zero data leaving the client's environment.
- The platform is configuration-file-driven, containerisable via Docker, and Tailscale-mesh-connectable for AInchors remote management.
- APRA CPG 234/235 controls (immutable audit log, AES-256 at rest, TLS 1.3, WORM archive) are all implementable on self-hosted infrastructure.

The primary constraint is **AInchors' ability to remotely manage and support the deployment** — addressed by a Tailscale site-to-site link and a defined support SLA.

---

### 5.2 Deployable vs Cloud-Only Components

| Component | Deployable On-Prem? | Notes |
|-----------|---------------------|-------|
| OpenClaw Gateway | ✅ Yes | Mac Mini or server. The core of the deployment. |
| Gemma4:26b (Ollama) | ✅ Yes | Requires Mac Mini M4 Pro 48GB or equivalent. Tier 1 local inference. |
| nomic-embed-text (Ollama) | ✅ Yes | Lightweight. Runs on OC1-class hardware. |
| Postgres + pgvector | ✅ Yes | Standard Postgres. Deployable on-prem with encrypted volumes. |
| Redis | ✅ Yes | Standard Redis. Self-hosted. |
| Nexus agent roster (Yoda, governance triad, etc.) | ✅ Yes | SOUL.md files + OpenClaw config. Deployable as a package. |
| Sanctum (Shield/Lex/Sage/Warden) | ✅ Yes | Governance agents are OpenClaw-native. No external dependency. |
| The Citadel (Client Portal) | ✅ Yes | Self-hosted web interface. Dockerisable. |
| Datapad / Beacon | ✅ Yes | Runs on Nexus agent runtime. No cloud dependency. |
| NAS (model weights, backup) | ✅ Yes | Client provides NAS hardware. AInchors specifies encryption requirements. |
| Tailscale (management link) | ✅ Yes | Client and AInchors share a Tailscale network. AInchors has management access only. |
| Holocron (Notion) | ⚠️ Partial | Notion is cloud-based. For P4 FSI, Notion should be replaced with a self-hosted KB (Confluence, Outline, or file-based). |
| Anthropic Claude API | ❌ Cloud-only | Not deployable on-prem. Restricted to non-PII, non-regulated workloads only. For FSI: Gemma4 local replaces Claude entirely. |
| Ollama Cloud (kimi/deepseek) | ❌ Cloud-only | AInchors-internal use only. Never deployed in client environment. |
| AWS KMS / S3 | ⚠️ Optional | Client may use their own cloud KMS or HSM. AInchors provides configuration guidance. On-prem HSM (Thales, nCipher) acceptable at P4. |

---

### 5.3 AInchors → Client Handover Architecture

For a P4 physical/in-house deployment, the handover follows this model:

```
Phase A — Design (AInchors leads)
  ├── Infrastructure sizing: Mac Mini M4 Pro × 2 (HA) + NAS + network switch
  ├── Network design: Tailscale site-to-site, loopback bind, firewall rules
  ├── Data classification register: client's data categories mapped to tiers
  └── Security design: APRA CPG 234/235 controls checklist (Atlas + Lex)

Phase B — Build (AInchors + client IT)
  ├── Hardware procurement and rack/desk installation (client IT)
  ├── AInchors deploys: OpenClaw, Ollama, Postgres, Redis, pgvector, Docker
  ├── Agent configuration: SOUL.md, RULES.md, workspace, Sanctum, Warden
  ├── Tailscale management link established
  └── Security hardening: S1–S7 controls applied, S7 NAS encryption, TDE on Postgres

Phase C — Validate (both)
  ├── PVT (9/9 pass) run by Yoda in remote management session
  ├── Failover test: OC2-A goes offline → OC2-B assumes primary
  ├── Sanctum gate review: dummy proposal passes Shield → Lex → Sage
  ├── APRA compliance checklist sign-off (CPG 234/235 per control)
  └── Data sovereignty test: confirm client PII stays Tier 1 (Gemma4 local) only

Phase D — Transition (client takes over)
  ├── Tailscale management link maintained for AInchors remote support
  ├── Client IT team trained on: agent configuration, secret rotation, backup verification
  ├── Incident escalation path: client IT → AInchors Yoda (Telegram / The Bridge)
  └── SLA defined: RTO <4h, RPO <1h, Warden check frequency, quarterly security review

Phase E — Ongoing (AInchors retains)
  ├── IP: OpenClaw configuration, SOUL.md templates, Sanctum rule sets, governance frameworks
  ├── Retained: Model weights are Ollama-sourced (Meta, Google licences) — client must comply
  ├── AInchors retains: orchestration patterns, agent taxonomy, Sanctum review logic
  └── Client owns: their data, their knowledge base, their audit logs
```

---

### 5.4 Minimum Viable P4 Stack (FSI / APRA CPG 234/235)

| Layer | Minimum Viable Specification | APRA Reference |
|-------|------------------------------|----------------|
| **Compute** | 2 × Mac Mini M4 Pro 48GB (HA active-passive) | CPG 234: business continuity |
| **Networking** | Tailscale mesh + physical firewall. Port 18789 loopback-only. No public exposure. | CPG 234: network security |
| **Primary model** | Gemma4:26b (Ollama local). Zero data leaves environment. | CPG 234: third-party risk (no API calls for regulated data) |
| **Database** | Postgres 16+ with encrypted volumes (AES-256) + pgvector. | CPG 235: data integrity; CPG 234: encryption at rest |
| **Audit log** | Episodic log (agent_events, decision_lineage). Append-only. SHA-256 per record. | CPG 235: data lineage and audit |
| **WORM archive** | WORM-capable NAS or object store. 7-year retention. | APRA retention requirements |
| **Key management** | HSM-backed or at minimum client-provided KMS (AWS CloudHSM or Thales). CMK option. | CPG 234: key management |
| **Session management** | Redis with 8h max TTL. PII-free session store. All session events logged. | CPG 234: access controls |
| **Governance (Sanctum)** | Shield + Lex + Sage deployed locally. All external output reviewed. | CPG 234: controls framework |
| **Compliance monitoring** | Warden checking all agents every 15 min. Model drift detection. | CPG 234: ongoing monitoring |
| **Backup** | Daily encrypted backup. Weekly test. Quarterly restore test with documented evidence. | CPG 234: backup and recovery |
| **Access control** | RBAC + MFA on all management interfaces. All access events logged. | CPG 234: access management |
| **Change management** | CHG-NNNN records for all configuration changes. Ken/client IT sign-off. | CPG 235: change control |
| **Incident management** | Incident log via incident-log.sh. PIR within 72h of P1/P2 incidents. Escalation to AInchors. | CPG 234: incident response |
| **Vulnerability management** | Quarterly vulnerability scan. Annual penetration test. OpenClaw patches within 48h (critical). | CPG 234: vulnerability management |

---

### 5.5 What AInchors Retains vs What the Client Owns

| Item | Owner | Notes |
|------|-------|-------|
| Client's data, knowledge base, audit logs | **Client** | Data controller. AInchors is data processor during build/support only. |
| Nexus platform code (OpenClaw) | **OpenClaw project** (open source) | Client runs their own instance. AInchors does not own OpenClaw. |
| Agent orchestration patterns, SOUL.md templates, Sanctum rule sets | **AInchors IP** | Proprietary configuration and governance logic. Included in consulting engagement. |
| Governance frameworks (RULES.md, AGENTS.md patterns) | **AInchors IP** | Delivered as consulting artefacts. Client may not redistribute. |
| Gemma4 model weights | **Meta/Google licence** | Client must comply with Gemma/Llama licences. AInchors provides guidance. |
| Holocron structure / KB taxonomy | **AInchors IP** | If client uses AInchors Holocron design, it is an AInchors deliverable. |
| The Citadel web interface | **AInchors IP** | Deployed in client environment. Not redistributable. |
| Client's custom agent configurations (built during engagement) | **Client** | Bespoke SOUL.md and RULES.md tailored to client's use case. Client owns the output. |
| AInchors' consulting methodology (Jumpstart framework) | **AInchors IP** | Methodology is retained. Deliverables produced by the methodology belong to the client. |

---

## Section 6 — Open Decisions for Ken

These are the architectural decisions that must be made before P2 build begins. Maximum 8. Framed as questions with recommended options.

---

### Decision A — Multi-Tenancy Isolation Model: Schema-per-tenant or Shared Schema + RLS from day one?

**Context:** P2 must be multi-tenant from day one (CHG-0234). Two options:
- **Option 1: Schema-per-tenant** — each client gets a dedicated Postgres schema. Stronger isolation. Higher operational overhead (migration complexity at >50 tenants). Easier debugging per client.
- **Option 2: Shared schema + RLS from day one** — single schema, tenant_id on all tables, Postgres RLS policies. More scalable. More complex to implement correctly. Preferred at P2 scale.

**Recommendation:** Option 2 (shared schema + RLS) from day one. Aligns with CHG-0234. Avoids a costly migration later. Requires tenant_id on every P1 table now (TKT-0104 Action 3).

**Ken must decide:** Confirm Option 2, or accept Option 1 as an early-P2 interim with a planned migration to Option 2 before the 50-tenant threshold.

---

### Decision B — P4 Physical Deployment: Direct Sales or Consulting Engagement Model?

**Context:** P4 can be positioned two ways:
- **Option 1: Consulting engagement** — AInchors consultant (Ahsoka + Ken) designs and deploys Nexus in the client's environment as part of a professional services engagement. Revenue: time + materials or fixed-scope SOW.
- **Option 2: Packaged installation** — AInchors produces a packaged Nexus installer (Docker Compose, scripts, documentation) that a client IT team can deploy with limited AInchors assistance. Revenue: licence fee + implementation fee.

**Recommendation:** Option 1 for P4 year 1-2. The consulting engagement model is lower build cost, higher margin, and builds reference cases. Option 2 deferred to Year 3+ when the platform is sufficiently mature for self-service installation.

**Ken must decide:** Confirms Option 1 (consulting-led P4), or indicates appetite for Option 2 packaging earlier.

---

### Decision C — Holocron Replacement for P4 FSI: Self-Hosted KB or Notion with Data Controls?

**Context:** Notion is cloud-based. FSI clients under APRA CPG 234 may require all knowledge base content to remain on Australian soil in a self-hosted system.
- **Option 1: Notion with strict controls** — no client/regulated data in Notion. Use Notion for AInchors-internal governance only. Client KB is entirely in pgvector (on-prem).
- **Option 2: Self-hosted KB** — replace Notion with an on-prem alternative (Outline, Confluence Data Centre, or Markdown-file-based) for P4 deployments.
- **Option 3: Hybrid** — Notion for AInchors internal + self-hosted component delivered to FSI client as their KB layer.

**Recommendation:** Option 3 (hybrid). AInchors retains Notion (Holocron) for internal use. P4 client deployments include a self-hosted KB component (file-based Markdown is sufficient for MVP; Outline for larger deployments).

**Ken must decide:** Confirms Option 3, or accepts Option 1 (Notion restrictions only) for early P4 if no APRA-specific client demands arise before Year 3.

---

### Decision D — The Citadel (Client Portal): Build or Buy at P2?

**Context:** The Citadel is a per-client access portal for workflow status, SLA reporting, and document delivery. Options:
- **Option 1: Build (custom web app)** — Full control. Higher build cost. Flexible branding. Required for enterprise/white-label at P4.
- **Option 2: Notion-based client view** — Zero build cost. Fast to deploy. Limited UI control. Not suitable for P4 enterprise.
- **Option 3: Notion for P2 clients, custom build for P4** — Pragmatic phasing. P2 clients get a well-structured Notion workspace. P4 clients get The Citadel as a custom portal.

**Recommendation:** Option 3. Notion-based Citadel v0 for the first 2-3 P2 SME pilot clients (aligns with Q3 IT strategy). Custom build begins in Q3-Q4 2026 for the P4-ready version.

**Ken must decide:** Confirms Option 3, or commits to a direct custom build from P2 launch.

---

### Decision E — Holonet Integration Bus: REST/Webhooks only, or Include Database Connectors at P2?

**Context:** Holonet connects Nexus agents to client business systems. At P2 v0, the question is scope:
- **Option 1: REST APIs + Webhooks + Google Sheets** — Low complexity. Sufficient for SME Jumpstart use cases. Most client workflows are webhook-driven or spreadsheet-based.
- **Option 2: Add direct database connectors (Postgres, MySQL, SQL Server read-only)** — Needed for CRM/ERP integration. Significantly higher security complexity (credential management per client system).

**Recommendation:** Option 1 for P2 v0. Defer direct DB connectors to Holonet v1 (Year 2) unless a specific P2 client engagement requires it. REST + webhooks covers 80%+ of SME use cases.

**Ken must decide:** Confirms Option 1 for P2 v0, or identifies a specific client use case requiring DB connectors in Year 1.

---

### Decision F — Warden at P2: AInchors-Managed or Client-Deployable?

**Context:** At P2, Warden monitors all agents for model drift and compliance. For multi-tenant deployment:
- **Option 1: AInchors-managed Warden** — Single Warden instance on AInchors infrastructure monitors all client tenant agents. Simpler to operate. AInchors has visibility into all client agent compliance.
- **Option 2: Per-tenant Warden** — Each client's Docker container includes its own Warden instance. Stronger isolation. Higher operational overhead.

**Recommendation:** Option 1 for P2 (AInchors-managed Warden, tenant-tagged monitoring). Option 2 for P4 physical deployments where the client must own their compliance monitoring.

**Ken must decide:** Confirms Option 1 for P2, or identifies a P2 client sensitivity that requires Option 2 earlier.

---

### Decision G — P3 Commercial Tier (Company/Multi-Agent): Trigger Criteria?

**Context:** P3 is a commercial tier label within P2, unlockable on demand, ROI-gated. Ken has expressed scepticism about whether the maintenance cost justifies enabling it. Before the P2 build begins, the trigger criteria must be defined:
- What is the minimum client size / use case complexity that justifies enabling P3?
- What is the ROI calculation that must pass the gate? (e.g., "client is paying for >3 agent workflows + requests shared context across teams")
- Who approves the P3 unlock? (Ken only, or Ken + Angie?)

**Recommendation:** Define a formal P3 ROI checklist in Holocron before P2 launch. Default: P3 is NOT offered to clients unless they explicitly request it and pass the ROI gate. This prevents premature feature complexity.

**Ken must decide:** Approves the principle of a formal P3 ROI checklist, and nominates who approves it (Ken only recommended).

---

### Decision H — Data Residency Validation: Anthropic DPA — Block or Permit Claude for Non-PII P2 Workloads?

**Context:** Claude API routes data to Anthropic servers. Data residency for Australian data has not been formally verified (TKT-0104 Action 2, marked urgent). Before P2 launches with SME client workloads:
- **Option 1: Permit Claude for non-PII, non-regulated AInchors-internal workloads only** — AInchors uses Claude for its own complex reasoning tasks. Client-facing workloads → Gemma4 local only.
- **Option 2: Require full DPA verification before any P2 client traffic routes near Claude infrastructure** — More conservative. May require engaging Anthropic's enterprise team.
- **Option 3: Block Claude for all P2 client workloads, regardless of PII status** — Simplest compliance posture. All client workloads → Gemma4 local. Claude only for AInchors internal use.

**Recommendation:** Option 3 for client workloads at P2 launch (safest default). Option 1 maintained for AInchors-internal operations. Pursue Option 2 (DPA verification) in parallel as a Q1 2026 action — once resolved, may allow non-PII client workloads on Claude if residency is confirmed AU-based.

**Ken must decide:** Confirms Option 3 as the P2 client data policy, and instructs Yoda to pursue Anthropic DPA verification as a Q1 priority.

---

## Section 7 — Recommended Next Architecture Tasks

Prioritised list for Atlas and Thrawn.

### Tier 1 — Before P2 Build Begins (Critical Path)

1. **[Atlas] Produce Nexus P2 Data Schema Blueprint** — Define the full Postgres schema for P2: all tables with tenant_id, RLS policy definitions, access control matrix per tenant, SSO/SAML stub fields, agent_events structure. This is the foundation every P2 build task depends on. (TKT-NEW)

2. **[Atlas] Produce Nexus Public API Specification (OpenAPI v3)** — Define the REST API surface for The Citadel and Holonet integrations. Endpoints, auth flows, error responses, rate limits, tenant isolation contract. Without this, The Citadel and Holonet cannot be built. (TKT-NEW)

3. **[Thrawn] Design Multi-Tenant Agent Isolation Model** — Define how OpenClaw's gateway, session management, and cron engine must be configured to enforce per-tenant isolation. Docker container spec, per-client workspace layout, credential isolation pattern. This is the P2 deployment architecture. (TKT-NEW)

4. **[Atlas + Yoda] Pursue Anthropic DPA Verification** — Formally verify data processing location for Australian data via Claude API. Produce a Data Residency Register entry. This is urgent — it governs the client data routing policy for all P2 workloads. (TKT-0104 Action 2, escalate to CHG)

5. **[Atlas] Produce P4 Physical Deployment Package Blueprint** — Define the minimum P4 deployment package: hardware specification, software stack, APRA control mapping, handover checklist, ongoing management SLA. Required before AInchors can quote on any FSI engagement. (TKT-NEW)

### Tier 2 — P2 Build Support (Q2 2026)

6. **[Thrawn] Design Holonet v0 Architecture** — Define the integration bus architecture for REST/webhook/Google Sheets connectors. Event schema, tenant routing, error handling, dead-letter queue. Q4 2026 delivery. (TKT-NEW)

7. **[Atlas] Produce The Citadel v0 Design** — Information architecture, wireframe-level UX for Notion-based client view. Covers: agent status panel, governance review log, Datapad access, document delivery. Required for Q3 2026. (TKT-NEW)

8. **[Atlas] Define P3 Commercial Tier ROI Checklist** — Formal criteria for when the P3 tier (company/multi-agent) feature flag may be enabled for a client. To be approved by Ken before P2 launch. (TKT-NEW)

### Tier 3 — Ongoing Architecture Governance

9. **[Atlas] Architecture Review Board — Monthly Cadence** — Two architecture reviews per quarter (OKR X2-KR3). Atlas chairs. Agenda: work-in-progress against OKRs, new decisions required, open ADs from this document. (Ongoing)

10. **[Thrawn] Beacon + Datapad Internal Architecture** — Define the observability event schema consolidation from obs.db/health-state.json into a unified Beacon layer. Datapad report templates. Q3 2026 build. (TKT-NEW)

---

## Appendix A — Architecture Decision Quick Reference

| Decision | Recommended | Status |
|----------|-------------|--------|
| A — Multi-tenancy isolation model | Shared schema + RLS from day one | Open — Ken to confirm |
| B — P4 deployment model | Consulting engagement (Option 1) | Open — Ken to confirm |
| C — Holocron at P4 | Hybrid (Notion internal + self-hosted client KB) | Open — Ken to confirm |
| D — The Citadel build approach | Notion-based P2, custom build P4 | Open — Ken to confirm |
| E — Holonet P2 scope | REST/webhooks only | Open — Ken to confirm |
| F — Warden deployment | AInchors-managed P2, per-tenant P4 | Open — Ken to confirm |
| G — P3 tier trigger criteria | Formal ROI checklist, Ken approves | Open — Ken to confirm |
| H — Anthropic DPA / Claude data policy | Block Claude for all client workloads at P2 launch; pursue DPA verification | Open — Ken to confirm |
| Vector store | pgvector | Locked (TKT-0104) |
| Embedding model | nomic-embed-text 768-dim | Locked (TKT-0104) |
| Multi-tenancy foundation | RLS from P2 day one | Locked (CHG-0234) |
| Session state (P1) | Postgres session tables | Locked (TKT-0104) |
| P4 physical deployment viability | Viable | Confirmed (this document) |

---

## Appendix B — Component Count Summary

| Classification | Count | Key Examples |
|----------------|-------|-------------|
| **Core** | 38 | OpenClaw Gateway, all agents, Postgres, pgvector, Redis, Warden, Sanctum, HIVE nodes, ITSM, The Bridge |
| **Adjacent** | 8 | Claude API, Ollama Cloud, Notion Holocron, Social APIs, Google Workspace (gog), Telegram (platform), Anthropic, external webhook targets |
| **Client-side (P4)** | 14 | On-prem OpenClaw instance, Gemma4 local, client Postgres, HSM, on-prem NAS, client IAM/SSO, client Tailscale node, self-hosted KB |

---

*Document: DRAFT FOR REVIEW*
*TKT-0046 | Atlas 🏛️ Enterprise Architect | AInchors / Aevlith Technologies*
*2026-05-08 | v1.0*
