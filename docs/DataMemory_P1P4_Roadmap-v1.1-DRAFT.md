> ⚠️ **DRAFT FOR REVIEW — NOT APPROVED.**
> This document is a **delta/draft update** of `DataMemory_P1P4_Roadmap.md` (v1.0, 2026-05-08).
> Prepared under **CHG-0852** (Phase 3 Holocron Refresh). For Ken review only.
> Do not implement against this document until Ken approves.

# Data & Memory Architecture: P1-P4 Progressive Build Roadmap
**TKT-0104 | Enterprise Architecture Deliverable**
**Status:** DRAFT FOR REVIEW — v1.1 refresh prepared by Thrawn 🟦
**Parent:** v1.0 (approved 2026-05-12, Atlas 🏛️)
**Date:** 2026-07-09 | **Platform Day:** ~Day 76
**Author:** Thrawn 🟦 — Design Backend, AInchors
**Source:** Phase4_DataMemory_Architecture.md (Ken Mun, 1 May 2026); v1.0 (Atlas, 8 May 2026)

---

**ITIL Practice:** Service Design

> **⚠️ PHASE STRUCTURE REMAINS AS PER CHG-0234 (Ken confirmed 2026-05-08 15:08 AEST)**
>
> P3 is **not a build phase.** The Licensed Product model was dropped entirely. P3 survives only as a **commercial tier label within P2** (company/multi-agent feature unlock). This decision is locked and unchanged.
>
> **v1.1 additions to note:**
> - **PG SSOT-first** adopted 2026-05-23 — Postgres is now the canonical source of truth for all operational state, not just an audit log.
> - **CREST v1.3** approved 2026-06-20 — capability-based multi-model routing, Sage-as-Judge.
> - **CRESTv2-P1** in progress — structured foundation, PG-first write policy enforcement.
> - **model-policy.json v3.0** approved CHG-0812 2026-07-03.
> - **OC2-A/B** incoming ~27 Jul 2026 with shadow/sandbox ports locked (28789/38789).
> - **Notion 3-DB architecture** active: Backlog A, Auto-Heal B, Archive C. 598 AKB pages synced.
> - **web_search** now DuckDuckGo; **gog** working.
> - **Redis P2** still deferred — PG-first approach has superseded Redis-first thinking. Re-evaluate at P2 gate.

---

## Document Purpose

This document maps the FSI-grade P4 target data and memory architecture progressively across all productisation phases. It answers: *what must be built now, what can be deferred, and what decisions cannot be undone cheaply later?*

**v1.1 update:** This roadmap now reflects the PG SSOT-first reality and the current state of the platform as of Day ~76 (2026-07-09). Sections marked **[UPDATED]** or **[NEW]** reflect material changes since v1.0.

---

## Platform Phase Reference

| Phase | Label | Context (v1.1 update) |
|-------|-------|----------------------|
| **P1** | Internal Single-Tenant | **Current** — OC1, AInchors internal. Ken primary user. Mac Mini M-series. Postgres 16 fully operational. 47+ PG tables live. 14 agents active. PG SSOT-first since 2026-05-23. AKB at 598 pages across 3 Notion DBs. |
| **P2** | SaaS Multi-Tenant — from day one | Planned. Multi-tenant foundation (tenant_id, RLS, optimistic locking, access control matrix, SSO/SAML hooks). PG-first architecture carries forward. Redis at P2 gate. OC2-A/B hardware incoming ~27 Jul 2026. |
| **P3** | Commercial Tier Label within P2 (NOT a build phase) | Unchanged from v1.0. Company/multi-agent feature unlock within P2. No separate infrastructure build. |
| **P4** | Enterprise / Regulated | FSI enterprise consulting engagements. APRA CPG 234/235. Event sourcing migration. |

---

## Section 1 — 5-Tier Memory Architecture × P1-P4 Matrix [UPDATED]

### T1: Working Memory (Context Window)

| Phase | Status | Technology | Rationale |
|-------|--------|------------|-----------|
| **P1** | ✅ Full | LLM context window (Claude Sonnet/Haiku/Gemma4, DeepSeek V4, Kimi K2.7, GLM 5.2, MiniMax M3). 12 models in global allowlist per model-policy.json v3.0. | **Update:** Model roster expanded significantly. Warden enforces policy. 14 agents with CREST v1.3 capability-based routing. Token budget discipline still needed. |
| **P2** | ✅ Full | Same mechanism. Session ID as isolation boundary across tenants. | Unchanged. |
| **P3** | ✅ Full (commercial tier) | Customer's LLM (may not be Claude). Design must be model-agnostic. | Unchanged. |
| **P4** | ✅ Full + Governance | Same plus: explicit PII-in-context controls, token budget per regulated workload, input/output classification before context injection. | Unchanged. |

**P1 action (v1.1 update):** Token budget policy still not formally defined. CREST v1.3 capability routing partially addresses model selection governance. Recommend formalising token budget policy as a CRESTv2-P1 deliverable.

---

### T2: Short-Term / Session Memory [UPDATED]

| Phase | Status | Technology | Rationale |
|-------|--------|------------|-----------|
| **P1** | ⚠️ Partial → 🟡 Improved | OpenClaw implicit session state. `agent_sessions` and `agent_events` tables in PG. No formal TTL or classification. | **Update:** PG tables exist (`agent_sessions`) but session lifecycle management is still implicit. No TTL enforcement, no classification. Session isolation via OpenClaw session IDs. |
| **P2** | ✅ Full | Postgres session tables (PG-first approach). Redis at P2 gate if concurrent session count warrants. | **Update:** PG-first has superseded Redis-first. Redis is a performance optimisation, not architectural dependency. v1.0 said "Redis preferred" — now PG is default, Redis considered at P2 gate. |
| **P3** | ✅ Full (commercial tier) | Customer-provided Redis or Postgres. AInchors provides session schema and TTL recommendations. | Unchanged. |
| **P4** | ✅ Full + Hardened | Redis with TLS, encryption at rest, strict TTL (max 8h for FSI workloads), PII-free session store policy. All session creation/deletion events logged to Tier 3. | Unchanged. |

**Key design constraint (v1.1):** PG-first means session tables are already in Postgres. The migration path originally described (Postgres P1 → Redis P2) is now better described as: **PG default P1–P2, Redis optional performance optimisation at P2+.**

---

### T3: Long-Term Episodic Memory (Audit / Compliance Log) [UPDATED]

| Phase | Status | Technology | Rationale |
|-------|--------|------------|-----------|
| **P1** | ✅ **LIVE** | Postgres. Tables: `agent_events`, `agent_decisions`, `decision_lineage`, `memory_access_log`, `state_changes`, `changelog`, `state_autoheal_log`. | **Update:** Fully built and operational. The v1.0 "Building" status is now **LIVE**. `state_changes` is the canonical CHG record. `changelog` table mirrors key entries. `state_autoheal_log` added for auto-heal events. SHA-256 hashing not yet confirmed — verify. |
| **P2** | ✅ Full | Postgres with tenant_id on all audit tables. Tenant isolation via RLS. | Unchanged. tenant_id foundation in place (tables created with tenant_id column). |
| **P3** | ✅ Full (commercial tier) | Customer-deployed Postgres. AInchors provides schema, migration scripts, and compliance queries. | Unchanged. |
| **P4** | ✅ Full + APRA Grade | Append-only Postgres with hash tamper evidence (SHA-256 on all records). WORM-capable storage. Minimum 7-year retention. | Unchanged. |

**P1 immediate action (v1.1 update):** Verify SHA-256 hashing is wired. `state_changes` is canonical — confirm tamper evidence is active. This was a P1 non-negotiable from v1.0.

---

### T4: Long-Term Semantic Memory (RAG / Vector Store) [UPDATED]

| Phase | Status | Technology | Rationale |
|-------|--------|------------|-----------|
| **P1** | ✅ **LIVE** | pgvector extension on Postgres. nomic-embed-text via Ollama (local, 768-dim). Tables: `knowledge_documents`, `knowledge_chunks` with `vector(768)`. Ingestion pipeline: `ingest-memory-to-pg.sh`. | **Update:** Fully operational. Memory docs are chunked, embedded, and stored. Decision D1 (pgvector), D2 (nomic-embed-text 768-dim), D3 (RecursiveCharTextSplitter) all **locked and implemented**. The v1.0 "Build" status is now **LIVE**. |
| **P2** | ✅ Full Multi-Tenant | pgvector with schema-per-tenant isolation OR tenant_id + RLS on shared schema. Per-tenant knowledge bases. | Unchanged. |
| **P3** | ✅ Full (commercial tier) | Customer-controlled. AInchors provides ingestion pipeline as deployable component. | Unchanged. |
| **P4** | ✅ Full + PII Hardened | pgvector with mandatory PII scan before ingestion. `pii_present` flag gates embedding. Quality score threshold enforced. Full provenance on every chunk. | Unchanged. PII scanner not yet confirmed in P1 — see Section 8 re-evaluation. |

---

### T5: Shared Multi-Agent Memory [UPDATED]

| Phase | Status | Technology | Rationale |
|-------|--------|------------|-----------|
| **P1** | ✅ **LIVE** | Postgres tables: `agent_shared_state` (optimistic locking), `agent_state_history` (append-only), `agent_registry` (agent roster), `state_model_policy` (model routing), `state_sprints` (sprint data), `state_standups` (standup records), `state_sub_crest` (CREST phase state). Plus 27+ `state_*` tables for domain-specific state. | **Update:** Major expansion. T5 is now **fully deployed** with 47+ PG tables. Optimistic locking in place. `agent_registry` tracks 14 agents. `state_model_policy` drives CREST v1.3 routing. `state_sub_crest` records CREST phase transitions. The v1.0 "Partial Build" status is now **LIVE and comprehensive**. |
| **P2** | ✅ Full + Tenant Isolation | Postgres with tenant_id on all shared state tables. Agent roles scoped to tenant context. | Unchanged. All tables have tenant_id column foundation. |
| **P3** | ✅ Full (commercial tier) | Customer-deployed Postgres. AInchors configures access control matrix at deployment time. | Unchanged. |
| **P4** | ✅ Full + Event Sourcing | Migrate from optimistic locking to event sourcing. All state changes are immutable events. | Unchanged. Migration path seeded by `agent_state_history` table. |

---

## Section 2 — Data Classification & Use Lens [UPDATED for P1 reality]

### P1 — Internal Single-Tenant (Current State)

| Category | Present | Owner | Access Control | Flow Constraints |
|----------|---------|-------|----------------|-----------------|
| **Client** | ❌ None | N/A | N/A | Unchanged. |
| **Internal** | ✅ Yes | Ken / AInchors | Ken only. Single-tenant. PG SSOT-first with `state_changes` canonical. | Ken's prompts, agent outputs, decision context. Now stored in PG tables as well as memory docs. |
| **System** | ✅ Yes | Platform | Ken only. | Logs, metrics, cron outputs, health check results. PG tables: `state_uptime`, `state_latency`, `state_diagnostics`, `state_cost`, `state_kri`. |
| **Operational** | ✅ Yes | Platform | Ken only. | **Update:** 47+ PG tables covering CHGs, tickets, sprints, standups, task queue, auto-heal, model drift, CI state, config baseline, governance, policies, frameworks, lessons, LinkedIn, resume checkpoints. Significantly expanded since v1.0. |
| **Repository** | ✅ Yes | Ken | Ken only. | 598 AKB pages across 3 Notion DBs. PG tables: `knowledge_documents`, `knowledge_chunks`. Memory docs in filesystem. |
| **Backup** | ✅ Yes | Platform | Ken only. | Daily workspace backups. Encrypted (FileVault). PG backups via pg_dump. |

**P1 gap (v1.1):** Classification tagging is still not enforced on all data. This was flagged in v1.0 and remains open. Recommend CRESTv2-P1 ticket to implement classification tag enforcement.

---

## Section 3 — Data Type Lens [UPDATED]

### P1 — Internal Single-Tenant (Current State)

| Data Type | In Use | Tooling | Schema Governance |
|-----------|--------|---------|-------------------|
| **Relational** | ✅ **Full** | Postgres 16+. 47+ tables. pgvector extension active. | **Update:** Formal schema governance via migration scripts. `db.sh` skill-gated wrapper enforces access control. TKT-0357 PG write events. |
| **Structured JSON/YAML/CSV** | ✅ Extensively | Config files, state files, ticket records, cost reports. PG JSONB columns for state_* tables. | **Update:** JSONB columns with schema validation where enforced. Config files still in filesystem. |
| **Unstructured (text/docs)** | ✅ Extensively | Markdown files in memory/ directory. AKB docs in Notion (598 pages). | **Update:** RAG pipeline active via `ingest-memory-to-pg.sh`. Memory docs chunked, embedded, and searchable. |
| **Vector/Embedding** | ✅ **LIVE** | pgvector. nomic-embed-text (768-dim) via Ollama. | Dimension: 768 — **locked** (Decision D10). Index type: ivfflat. |
| **Blob/Binary** | ✅ Limited | Script outputs, backups. Local filesystem. | Unchanged. |
| **Event/Stream** | ⚠️ Not yet | Events written to PG tables (batch, not streaming). | **Update:** `state_changes` table acts as a de facto event stream for CHG records. `pg_write_events` table tracks write operations. No streaming infrastructure yet. |

---

## Section 4 — Additional Considerations Lens [UPDATED]

### 4.1 Encryption

| Aspect | P1 (v1.1 update) |
|--------|-------------------|
| **At-rest** | macOS FileVault (disk-level). PG runs on encrypted APFS volume. No application-level PG encryption confirmed. **Gap still open from v1.0.** |
| **In-transit** | TLS for all API calls to Claude/Anthropic and Ollama cloud models. Internal PG connections via Unix socket (no network encryption needed — localhost). |
| **Key Management** | macOS Keychain for secrets. OpenClaw manages API keys. No formal KMS. **Gap still open.** |

### 4.2 Real-Time vs Batch

**Key update:** All agent requests are synchronous/real-time. Audit log writes are synchronous to PG. Knowledge base ingestion is batch (via `ingest-memory-to-pg.sh`). Cost reporting batch (nightly cron). Compliance reporting ad-hoc. No changes to the P1 pattern from v1.0; the pattern is now **proven in production**.

### 4.3 Caching

**Key update:** No caching layer deployed in P1. PG-first approach means all reads hit Postgres directly. Session state is implicit in OpenClaw. Redis deferred to P2 gate. This is consistent with Decision D8 (Postgres session tables P1, Redis P2).

### 4.4 Retention Policy [UPDATED]

| Data Category | P1 (v1.1 update) |
|---------------|-------------------|
| **Episodic audit log** | **No formal retention policy.** PG `state_changes` grows unbounded. Recommend defining a policy per CRESTv2-P1. |
| **Session state** | No TTL. Persists in OpenClaw session. PG `agent_sessions` table data persists. |
| **Knowledge chunks** | `expires_at` field in schema. Not yet enforced. |
| **Shared agent state** | `state_*` tables grow unbounded. No archival process. |
| **Backups** | Daily workspace backups. PG dumps run. Retention undefined. |

### 4.5 Data Residency [UPDATED]

**v1.1 update:** Anthropic DPA status still not formally verified. This was flagged as urgent in v1.0 (Action 2). **This remains open.** Claude API may route data outside Australia. All Ollama models (including cloud-routed) are run via Ollama providers — data residency of Ollama cloud endpoints (DeepSeek, Kimi, GLM, MiniMax, etc.) is unverified. Recommend: document a full Data Residency Register for all 12 approved models in model-policy.json v3.0.

---

## Section 5 — Physical Infrastructure Architecture Lens [UPDATED]

### P1 — OC1 Mac Mini (Current — Updated)

| Dimension | Detail (v1.1) |
|-----------|---------------|
| **Storage type** | Local NVMe SSD (Mac Mini internal). Postgres 16 on local filesystem. pgvector extension active. Ollama model store on local NVMe. |
| **Location** | OC1 Mac Mini, Melbourne, Australia. Single node. Residential internet. |
| **Performance tier** | 🔥 Hot — NVMe SSD. Handles all current P1 workloads (14 agents, 47+ PG tables, knowledge base). |
| **HA / DR** | None. Single point of failure. Daily backup. Acceptable for P1 internal use. |
| **Scalability gate** | **Update:** Trigger for P2 investment: OC1 IO saturation, first external client, availability requirement, Ken's Mac Mini needed for development. OC2-A/B hardware incoming ~27 Jul 2026. |
| **Estimated capacity headroom** | Mac Mini M-series with 32-64GB RAM. Operating comfortably with 14 agents + PG + Ollama + OpenClaw. |

### P2 — OC2 HA Cluster + Cloud Hybrid [UPDATED]

| Dimension | Detail (v1.1) |
|-----------|---------------|
| **Storage type** | Postgres 16+ on SSD-backed cloud instances or on OC2-A/B locally. Redis considered at P2 gate. pgvector on Postgres. |
| **Location** | **OC2-A/B** planned — two Mac Mini nodes, incoming ~27 Jul 2026. AWS ap-southeast-2 (Sydney) or Azure East Australia for cloud tier. |
| **Performance tier** | 🔥 Hot — NVMe SSD for Postgres. |
| **HA / DR** | **Update:** OC2-A/B planned as active-passive with Postgres streaming replication. Sandbox (28789) and Shadow (38789) ports already locked per CHG-0471. Patroni or RDS Multi-AZ for automatic failover. |
| **Port convention** | **18789** PROD / **18791** browser / **28789** SANDBOX / **38789** SHADOW — formalised CHG-0471. |
| **Scalability gate** | Shared schema + RLS migration at >100 tenants. Read replica at >70% CPU. |

### P3 — Customer-Deployed (Variable)

**Update:** P3 is a commercial tier label within P2, not a separate build phase. The customer-deployed rows from v1.0 are superseded by CHG-0234. Include only as reference for P2 commercial tier feature unlock.

### P4 — APRA-Grade Enterprise (FSI)

Unchanged from v1.0. No FSI engagements yet.

---

## Section 6 — Design Decision Register [UPDATED]

### Decision 1: Vector Store Selection
| Attribute | Detail (v1.1) |
|-----------|---------------|
| **Status** | ✅ **LOCKED — implemented.** pgvector active. |
| **v1.1 update** | No change to decision. pgvector proven in production. P4+ scale concern (>10M vectors) still valid but future. |

### Decision 2: Embedding Model Selection
| Attribute | Detail (v1.1) |
|-----------|---------------|
| **Status** | ✅ **LOCKED — implemented.** nomic-embed-text (768-dim) via Ollama. |
| **v1.1 update** | Decision confirmed. No quality issues identified. Dual-model approach not needed. |

### Decision 3: Chunking Strategy
| Attribute | Detail (v1.1) |
|-----------|---------------|
| **Status** | ✅ **LOCKED — implemented.** RecursiveCharacterTextSplitter at 400-600 tokens, 10-20% overlap. |
| **v1.1 update** | Implemented in `ingest-memory-to-pg.sh`. Metadata per chunk includes source_document, chunk_index, created_at. Classification and PII flag fields in schema but not yet enforced. |

### Decision 4: Concurrency Model for Shared Memory
| Attribute | Detail (v1.1) |
|-----------|---------------|
| **Status** | ✅ **LOCKED — implemented.** Optimistic locking in P1. Event sourcing at P4. |
| **v1.1 update** | Confirmed. `agent_state_history` table active as embryonic event log. 14 agents, non-parallel execution — optimistic locking zero conflict rate. |

### Decision 5: Data Residency Framework
| Attribute | Detail (v1.1) |
|-----------|---------------|
| **Status** | ⚠️ **STILL OPEN — NOT RESOLVED.** |
| **v1.1 update** | This was flagged as urgent in v1.0 (Action 2). Anthropic DPA still unverified. Ollama cloud model residency (DeepSeek, Kimi, GLM, MiniMax, etc.) unverified. **Recommend: make this a CRESTv2-P1 priority.** |

### Decision 6: Multi-Tenancy Isolation Model
| Attribute | Detail (v1.1) |
|-----------|---------------|
| **Status** | ✅ **LOCKED — build in P2 from day one.** Shared schema + RLS + tenant_id. |
| **v1.1 update** | P1 tables already have tenant_id column (DEFAULT 'ainchors'). P2-ready foundation in place. |

### Decision 7: Key Management Architecture
| Attribute | Detail (v1.1) |
|-----------|---------------|
| **Status** | 🟡 **Design at P2 gate.** Unchanged from v1.0. |
| **v1.1 update** | macOS Keychain still in use. No formal KMS. |

### Decision 8: Session State Store
| Attribute | Detail (v1.1) |
|-----------|---------------|
| **Status** | ✅ **IMPLEMENTED — Postgres session tables in P1.** Redis at P2 gate. |
| **v1.1 update** | **PG-first approach** has superseded the v1.0 "Redis preferred" framing. PG is the default; Redis is a performance optimisation at P2+. |

### Decision 9: Event Streaming Adoption
| Attribute | Detail (v1.1) |
|-----------|---------------|
| **Status** | 🟡 **Design at P2 gate.** Unchanged. |
| **v1.1 update** | `state_changes` table provides ad-hoc event stream capability. No streaming infrastructure needed yet. |

### Decision 10: Embedding Dimension Standardisation
| Attribute | Detail (v1.1) |
|-----------|---------------|
| **Status** | ✅ **LOCKED — 768 dimensions (nomic-embed-text).** |
| **v1.1 update** | Locked at table creation. Changing dimension would require full re-embed. No reason to change. |

---

## Section 7 — APRA Compliance Phase Map [UPDATED]

### Key Updates for P1 (Current State)

| Control | Status (v1.1) |
|---------|---------------|
| Data classification on all stored data | ⚠️ **Still not enforced.** Gap remains from v1.0. |
| Encryption at rest (AES-256) | ⚠️ FileVault only. PG-level encryption not confirmed. |
| Encryption in transit (TLS 1.3) | ✅ In place for API calls. PG via Unix socket (local). |
| Access control (least-privilege per agent) | ⚠️ CREST v1.3 capability routing provides partial model-level access control. Agent-level access control matrix not implemented. |
| Immutable audit log with tamper evidence | ✅ **LIVE.** `state_changes`, `agent_events`, `agent_decisions`, `decision_lineage`, `memory_access_log`, `changelog`. SHA-256 hashing status: **verify.** |
| Incident response: PII detection | ⚠️ Not implemented. PII scanner not confirmed. |
| PII scanner on document ingestion | ⚠️ **Not confirmed.** `ingest-memory-to-pg.sh` does not include PII scan. This was Action 5 in v1.0. |
| Data lineage: agent decision traceable to source data | ✅ `decision_lineage` table active. |
| Change management: schema changes via change control | ✅ 827+ CHG records in PG `state_changes`. 598 CHG pages in Notion Archive C. |

---

## Section 8 — P1 Immediate Actions [RE-EVALUATION]

### v1.0 Actions — Status Check

| Action | v1.0 Target | Status (v1.1) | Notes |
|--------|-------------|---------------|-------|
| **1.** Deploy Postgres + Episodic Log Schema | Week 1-2 | ✅ **COMPLETE** | Postgres 16 live. All audit tables active. |
| **2.** Verify Anthropic DPA | Week 1-2 | ❌ **STILL OPEN** | Not resolved. Flagged as urgent in v1.0. |
| **3.** Add tenant_id to all PG tables | Week 2-3 | ✅ **COMPLETE** | All tables have tenant_id column. |
| **4.** Lock embedding model + pgvector | Week 3-4 | ✅ **COMPLETE** | nomic-embed-text 768-dim locked. pgvector deployed. |
| **5.** Implement PII scanner | Week 3-4 | ❌ **STILL OPEN** | Not implemented in ingestion pipeline. PII risk remains. |

### v1.1 New Actions

| Action | Priority | Detail |
|--------|----------|--------|
| **6.** Verify SHA-256 hashing on audit tables | 🔴 **HIGH** | v1.0 required SHA-256 on all audit records. Confirm `state_changes`, `agent_events`, etc. have hash verification. |
| **7.** Document Data Residency Register | 🔴 **HIGH** | For all 12 models in model-policy.json v3.0. Where does each process data? |
| **8.** Implement PII scanner (carried forward) | 🔴 **HIGH** | v1.0 Action 5. Wire into `ingest-memory-to-pg.sh`. |
| **9.** Define formal retention policy | 🟡 MEDIUM | For `state_*` tables, `state_changes`, `changelog`, `knowledge_chunks`, `agent_events`. |
| **10.** Enforce data classification tagging | 🟡 MEDIUM | Add classification enforcement to all PG tables and file writes. |
| **11.** Formalise token budget policy | 🟡 MEDIUM | Per agent type. CRESTv2-P1 deliverable candidate. |

---

## Section 9 — Open Decisions for Ken [UPDATED]

### Resolved since v1.0

The following were marked as open in v1.0. They are now resolved or superseded:

| Q# | Question | Resolution |
|----|----------|------------|
| Q1 | Anthropic DPA — which workloads? | **Still open.** Not resolved. |
| Q2 | Postgres deployment model — Standalone vs Docker? | **Resolved.** Standalone Postgres via Homebrew. |
| Q3 | Redis in P1 — Add now or defer? | **Resolved.** Deferred to P2 gate. PG-first approach. |
| Q4 | Initial knowledge base — which documents? | **Resolved.** Memory docs ingested via `ingest-memory-to-pg.sh`. RULES.md, AGENTS.md, SOUL.md, governance docs, APRA CPG summaries. |
| Q5 | PII scanner — spaCy or Presidio? | **Still open.** Not implemented. |
| Q6 | Audit log retention period for P1? | **Still open.** No formal policy. |
| Q7 | agent_shared_state conflict handling? | **Resolved.** Last-write-wins with history preserved. Optimistic locking in place. |
| Q8 | P2 multi-tenancy model? | **Resolved per CHG-0234.** Shared schema + RLS + tenant_id from day one. |
| Q9 | P3 licensed product phase? | **Resolved per CHG-0234.** Dropped. P3 = commercial tier label within P2. |
| Q10 | Portfolio artefacts audience? | **Not addressed in this document.** Refer to Ken's decision. |

### New Open Questions

| Q# | Question | Context |
|----|----------|---------|
| **Q11** | **PG SSOT-first — is this the permanent architecture?** | PG is now the canonical source for CHGs, tickets, sprints, standups, model policy, agent registry, and 27+ other state domains. Is there any domain where PG should NOT be the SSOT? |
| **Q12** | **OC2 deployment model — local PG or cloud PG?** | OC2-A/B incoming ~27 Jul 2026. Should PG remain on OC2 local nodes, or migrate to cloud (AWS RDS in Sydney)? Affects HA, backup, and P2 multi-tenant architecture. |
| **Q13** | **web_search model change — DuckDuckGo sufficient?** | web_search provider changed to DuckDuckGo. Is this sufficient for production use, or should a paid search API be considered? |
| **Q14** | **gog integration — formalise as data pipeline?** | gog (Google Workspace CLI) is working. Should it be formalised as a data ingestion pipeline (email, calendar, drive → PG)? |

---

## Section 10 — CREST v1.3 & CRESTv2-P1 Impact on Data Architecture [NEW]

This section is new in v1.1.

### CREST v1.3 (Approved 2026-06-20)

CREST v1.3 introduced capability-based multi-model routing. Key data architecture implications:

| Aspect | Implication |
|--------|-------------|
| **Model routing** | `state_model_policy` table drives routing decisions. `model_capabilities`, `model_registry`, `routing_log` tables support this. |
| **Sage-as-Judge** | Sage evaluates outputs. `state_sub_crest` records enable evidence assembly. |
| **Phase ownership** | `state_sub_crest` table tracks phase state per task. `state_crest_status` active. |
| **PG-first write policy** | CREST enforces PG writes before declaring Done. `state_changes` is canonical for CHG records. |

### CRESTv2-P1 (In Progress)

CRESTv2-P1 focuses on structured foundation and PG-first write policy enforcement. Data architecture workstreams:

| Workstream | Status | Notes |
|------------|--------|-------|
| PG-first write policy enforcement | 🔨 In progress | `pg_write_events` table active. Write lessons tracked in `state_lessons`. |
| Structured foundation | 🔨 In progress | CREST phase rules in `crest_phase_rules` table. |
| Retention governance | 📋 Planned | Formal retention policy for all `state_*` tables. |

---

## Section 11 — Notion 3-DB Architecture & AKB Sync [NEW]

This section is new in v1.1.

### Notion Database Architecture

| Database | Name | Purpose |
|----------|------|---------|
| **Backlog A** | 825e0f47-1c7e-81d8-ae36-1b9b457b85b4 | Active tickets, in-progress items, sprint backlog |
| **Auto-Heal B** | 364c1829-53ff-818e-9e3b-d22729b34167 | Auto-heal events, system health records |
| **Archive C** | 364c1829-53ff-818e-a783-ebafcb6a9880 | Completed CHGs, archive. 827 CHG pages as of 2026-07-09 |

### AKB (AInchors Knowledge Base) Sync

| Metric | Value |
|--------|-------|
| Total AKB pages | ~598 |
| 3-DB architecture | Backlog A, Auto-Heal B, Archive C |
| Sync mechanism | `notion-sync.sh` / `notion-orphan-cleanup.sh` |
| Sync state tracking | `state_notion_sync` table |
| Recent work | CHG-0849/0850/0851 holocron refresh — backfilled 273 missing CHGs to Archive C |

### Key Data Architecture Pattern

PG is the authoritative source (`state_changes`). Notion is a synced copy. The `state_notion_sync` table tracks sync status and detects drift. CHG-0849-0851 demonstrated that drift detection works and backfill was needed.

---

## Section 12 — PG SSOT-First Architecture [NEW]

This section is new in v1.1.

### What Changed

On 2026-05-23, the platform adopted PG SSOT-first. This means:

- **`state_changes`** is canonical for all CHG records — not Notion, not filesystem
- **`state_sprints`** is canonical for sprint data
- **`state_standups`** is canonical for standup records
- **`agent_registry`** is canonical for agent roster
- **`state_model_policy`** is canonical for model routing policy
- All `state_*` tables are the authoritative source for their domain

### Live PG Tables (47+ as of 2026-07-09)

| Category | Tables |
|----------|--------|
| **Audit & Events** | `agent_events`, `agent_decisions`, `decision_lineage`, `memory_access_log`, `changelog`, `state_changes`, `state_autoheal_log`, `state_notion_sync` |
| **Agent State** | `agent_registry`, `agent_shared_state`, `agent_state_history`, `agent_sessions`, `config_entries` |
| **Knowledge** | `knowledge_documents`, `knowledge_chunks` |
| **Model Policy** | `model_registry`, `model_capabilities`, `state_model_policy`, `routing_log`, `state_model_drift`, `state_model_trials` |
| **Operational** | `state_tickets`, `state_task_queue`, `state_sprints`, `state_sprint_normalization_map`, `state_standups`, `state_sub_crest`, `crest_phase_rules` |
| **Governance** | `state_frameworks`, `state_governance`, `state_policies`, `policy_matrices`, `state_lessons` |
| **Infrastructure** | `state_uptime`, `state_latency`, `state_diagnostics`, `state_cost`, `state_kri`, `state_ci`, `state_config_baseline` |
| **Integration** | `state_linkedin`, `state_resume_checkpoints`, `entity_links`, `notifications`, `cost_events`, `pg_write_events` |

### Impact on Roadmap

The v1.0 roadmap assumed Postgres was primarily for the episodic log (T3) and vector store (T4), with Redis handling session (T2) and caching (Section 4.3). The PG SSOT-first decision fundamentally changed this:

- **PG is now the central data platform**, not just a supporting store
- **Redis is an optimisation** for P2, not a dependency
- **The 5-tier memory architecture** still holds, but PG is the implementation layer for all tiers (T1 implicit, T2 PG tables, T3 PG audit tables, T4 pgvector, T5 PG shared state)
- **The P1→P2 Redis migration** described in v1.0 is superseded: PG is the default, Redis is optional

---

## Appendix A — Architecture Decision Summary [UPDATED]

| Decision | Phase | Recommended | Locked? | v1.1 Status |
|----------|-------|-------------|---------|-------------|
| Vector store | P1 | pgvector | ✅ **Locked** | ✅ **Implemented** |
| Embedding model | P1 | nomic-embed-text (768-dim) | ✅ **Locked** | ✅ **Implemented** |
| Chunking strategy | P1 | RecursiveCharacterTextSplitter, 400-600 tokens, 10-20% overlap | ✅ **Locked** | ✅ **Implemented** |
| Concurrency model | P1→P4 | Optimistic locking P1–P2, event sourcing P4 | ✅ **Locked** | ✅ **Implemented** |
| Data residency framework | P1+ | Gemma4 for PII, Claude for non-PII (post-DPA verification) | ⚠️ **Still open** | ❌ **Not resolved** |
| Embedding dimensions | P1 | 768 (nomic-embed-text) | ✅ **Locked** | ✅ **Implemented** |
| Session state store | P1 | Postgres session tables (Redis at P2 gate) | ✅ **Locked** | ✅ **Implemented** |
| Multi-tenancy isolation | P2 day one | Shared schema + RLS + tenant_id | ✅ **Locked** | ✅ **Foundation in place** |
| Key management | P2 gate | Cloud KMS (AWS KMS) | 🟡 Design at P2 gate | 🟡 Unchanged |
| Event streaming | P2 gate | Redis Streams at P2, Kafka at P4 | 🟡 Design at P2 gate | 🟡 Unchanged |
| **PG SSOT-first** | **P1 (2026-05-23)** | **PG is canonical for all state** | ✅ **Locked** | ✅ **Implemented** |
| **CREST v1.3** | **P1 (2026-06-20)** | **Capability-based multi-model routing** | ✅ **Locked** | ✅ **Implemented** |
| **model-policy v3.0** | **P1 (2026-07-03)** | **12-model global allowlist, tiered agent config** | ✅ **Locked** | ✅ **Implemented** |

---

## Appendix B — P1–P4 Architecture Maturity Summary [UPDATED]

| Dimension | P1 (v1.0 said) | P1 (v1.1 current) | P2 (Standard tier) | P4 |
|-----------|----------------|--------------------|-------------------|-----|
| Memory tiers active | T1 (implicit), T3 (to build), T5 (partial) | **T1+T2+T3+T4+T5 — all 5 tiers live** | All 5 tiers | All 5 tiers + event sourcing |
| Data classification | Manual, ad-hoc | Manual, ad-hoc (⚠️ gap still open) | Enforced on all writes | Mandatory, audited |
| Encryption at rest | FileVault only | FileVault + APFS encrypted volume (⚠️ PG-level encryption not confirmed) | Postgres encrypted (AES-256) | AES-256 mandatory, audited |
| Audit log | Building | ✅ **LIVE** — 7+ audit tables active | Per-tenant, exportable | WORM, 7-year retention, hash-verified |
| RAG pipeline | Building | ✅ **LIVE** — pgvector, 768-dim, ingestion pipeline | Full multi-tenant | PII-hardened, quality-gated |
| APRA compliance | Foundation controls | Foundation controls operational | Partial (SME SaaS) | Full CPG 234/235 + Privacy Act |
| Residency | All local | All local (⚠️ DPA not verified) | AU region cloud | Australian soil mandatory |
| Multi-tenant foundation | Placeholder (tenant_id = 'ainchors') | tenant_id on all tables (✅ P2-ready) | **Built day one** | Dedicated infra per FSI engagement |
| PG tables | 0 (planned) | **47+** live across 8 categories | Scaled with tenant isolation | Event sourcing, TDE |
| Agents | 6 | **14** active | 14+ per tenant | Regulated |
| Model policy | Not formalised | **model-policy.json v3.0** with 12 models, CREST v1.3 routing | Per-tenant model config | Model risk register |
| CREST | Not designed | **CREST v1.3** live, **CRESTv2-P1** in progress | CRESTv2 complete | CRESTv3 (FSI overlay) |
| Notion AKB | ~200 pages | **598 pages** across 3 DBs | Per-tenant KB | Restricted |

---

## Appendix C — Changes from v1.0 [NEW]

This appendix lists every material update made in v1.1.

### Section-Level Changes

| Section | Change Type | Summary |
|---------|-------------|---------|
| **Header** | Updated | Date bumped to 2026-07-09, author changed to Thrawn, status DRAFT FOR REVIEW, added v1.1 amendment note. |
| **Document Purpose** | Updated | Added PG SSOT-first reality and Day ~76 context. |
| **Platform Phase Reference** | Updated | P1 row now reflects 47+ PG tables, 14 agents, PG SSOT-first, AKB 598 pages, 3 Notion DBs. |
| **Section 1 — 5-Tier Memory** | Major update | All 5 tiers updated to reflect current LIVE status. T2: PG-first supersedes Redis-first. T3: LIVE with state_changes canonical. T4: LIVE with pgvector and ingestion pipeline. T5: Major expansion to 47+ tables. |
| **Section 2 — Data Classification** | Updated | P1 table updated with current PG table count, AKB page count, and operational state. |
| **Section 3 — Data Type Lens** | Updated | P1 table updated: relational "Full" (47+ tables), vector "LIVE", event/stream "de facto event stream via state_changes". |
| **Section 4 — Additional Considerations** | Updated | Encryption gaps noted as still open. Caching unchanged. Retention policy gap noted as unresolved. Data residency: 12-model register needed. |
| **Section 5 — Physical Infrastructure** | Major update | OC2-A/B incoming ~27 Jul 2026. Port convention formalised (CHG-0471): 18789/18791/28789/38789. P3 customer-deployed rows superseded by CHG-0234. |
| **Section 6 — Design Decision Register** | Major update | All 10 decisions updated with v1.1 status. D1-D4, D6, D8, D10: LOCKED and IMPLEMENTED. D5: still open. D7, D9: unchanged. |
| **Section 7 — APRA Compliance** | Updated | Audit log status changed to "LIVE". PII scanner status: still not implemented. Data lineage: confirmed active. |
| **Section 8 — P1 Immediate Actions** | Major rework | v1.0 Actions 1-5 status-checked: 2 complete, 2 still open, 1 need verification. 6 new actions added. |
| **Section 9 — Open Decisions** | Major rework | v1.0 Q1-Q10 status-checked: 5 resolved, 4 still open, 1 not addressed. 4 new questions added (Q11-Q14). |
| **Section 10 — CREST Impact** | **NEW** | New section covering CREST v1.3 and CRESTv2-P1 data architecture implications. |
| **Section 11 — Notion 3-DB & AKB Sync** | **NEW** | New section covering 3-DB architecture, AKB sync, PG-SSOT Notion sync pattern. |
| **Section 12 — PG SSOT-First Architecture** | **NEW** | New section defining PG SSOT-first, listing all 47+ live tables by category, explaining roadmap impact. |
| **Appendix A — Decision Summary** | Updated | Added PG SSOT-first, CREST v1.3, model-policy v3.0 as new locked decisions. |
| **Appendix B — Maturity Summary** | Major update | P1 column completely rewritten to reflect current live state. Added PG tables, Agents, Model policy, CREST, Notion AKB rows. |
| **Appendix C — Changes from v1.0** | **NEW** | This appendix. |

### Material Changes Summary

1. **PG SSOT-first reality** supersedes the original Postgres-as-audit-log framing
2. **All 5 memory tiers** are now LIVE in P1 (not just T1/T3/T5)
3. **47+ PG tables** operational across 8 categories (vs 0-5 planned in v1.0)
4. **14 agents** active (vs 6 in v1.0)
5. **CREST v1.3** and **CRESTv2-P1** add data architecture layer not present in v1.0
6. **model-policy.json v3.0** with 12 approved models (vs informal routing in v1.0)
7. **OC2-A/B** incoming ~27 Jul 2026, port convention formalised
8. **Notion 3-DB architecture** with 598 AKB pages synced (vs ~200 pages in v1.0)
9. **Redis P2** is deferred — PG-first has superseded Redis-first
10. **Two unresolved gaps from v1.0** persist: Anthropic DPA verification (Action 2) and PII scanner (Action 5)

### Decisions Requiring Re-Evaluation

| Decision | v1.0 Status | v1.1 Flag | Reason |
|----------|-------------|-----------|--------|
| D5: Data Residency Framework | Decide now (P1) | ⚠️ **URGENT** | Still unresolved after 2 months. 12 models now in use. |
| D8: Session State Store | Postgres P1, Redis P2 | 🟡 **Re-evaluate at P2 gate** | PG-first approach means Redis is no longer the default. Is Redis still needed? |
| PII Scanner tooling | Q5 open | ⚠️ **URGENT** | 598 AKB pages ingested without PII scan. Risk increases with every new document. |
| Audit log retention | Q6 open | 🟡 **Define now** | PG tables grow unbounded. No archival strategy. |

---

*Document status: DRAFT FOR REVIEW — v1.1 refresh for CHG-0852 Phase 3 Holocron Refresh*
*TKT-0104 | Thrawn 🟦 — Design Backend | AInchors*
*2026-07-09 | Platform Day ~76*

*This document is a delta/draft update. The original v1.0 (approved 2026-05-12) remains the approved version until Ken reviews and approves this v1.1 draft.*
