> ⚠️ **INCORPORATED** — Data & memory architecture consolidated into `Nexus-System-Architecture-v1.0.md` (approved 2026-05-14). Locked decision record — preserve as-is.

# Data & Memory Architecture: P1-P4 Progressive Build Roadmap
**TKT-0104 | Enterprise Architecture Deliverable**
**Status:** LIVE — Approved by Ken Mun 2026-05-12
**Decisions confirmed:** D1 pgvector, D2 nomic-embed-text 768-dim, D3 RecursiveChar 400-600 tokens, D4 optimistic locking, D5 DPA verified, D6 Shared-RLS, D8 Postgres P1→Redis P2. D7/D9 deferred to P2 gate.
**Author:** Atlas 🏛️ - Enterprise Architect, AInchors
**Date:** 2026-05-08 | **Amended:** 2026-05-08
**Source:** Phase4_DataMemory_Architecture.md (Ken Mun, 1 May 2026)

---

**ITIL Practice:** Service Design

> **⚠️ PHASE STRUCTURE AMENDMENT - CHG-0234 (Ken confirmed 2026-05-08 15:08 AEST)**
>
> **P3 is no longer a build phase.** The Licensed Product model has been **dropped entirely**.
>
> **Final phase structure:**
> - **P1** - Internal single-tenant (AInchors internal, OC1, current)
> - **P2** - SaaS, multi-tenant architecture **from day one**. Two commercial tiers within P2:
>   - **P2 Standard** = single-agent per client (multi-tenant foundation, single-agent feature set)
>   - **P3 (commercial tier label only)** = company/multi-agent add-on within P2 - shared context + data across an organisation. Enabled and assessed only when need arises, ROI-gated. **NOT a separate build phase.**
> - **P4** - Enterprise consulting / FSI regulated sectors (APRA CPG 234/235)
>
> **Key architectural implication:** Multi-tenant foundation (tenant_id on all tables, RLS, shared state concurrency with optimistic locking, access control matrix per tenant, company-level auth SSO/SAML future-ready) must be built in P2 from day one. P3 label is then a feature flag / commercial unlock, not a separate build.
>
> **Where tables in this document reference a "P3" column:** those entries represent the P3 commercial tier feature set within P2 (multi-agent / company-level capabilities). They do **not** represent a separate infrastructure build phase. Customer-Deployed / Licensed Product references are obsolete and superseded by this amendment.

---

## Document Purpose

This document maps the FSI-grade P4 target data and memory architecture (as defined by Ken) progressively across all four productisation phases. It answers the question: *what must be built now, what can be deferred, and what decisions cannot be undone cheaply later?*

Structured across 7 architectural lenses. Each lens is addressed per phase (P1-P4).

---

## Platform Phase Reference

| Phase | Label | Context |
|-------|-------|---------|
| **P1** | Internal Single-Tenant | Current - OC1, AInchors internal use only. Ken is the only user. Mac Mini. |
| **P2** | SaaS Multi-Tenant - from day one | SME clients onboarded to AInchors-hosted platform. Cloud-hosted. Multi-tenant foundation built from day one: tenant_id on all tables, RLS, optimistic locking, access control matrix per tenant, company-level auth hooks (SSO/SAML future). **P3 commercial tier** (company/multi-agent) is a feature unlock within P2 - see P3 row. |
| **P3** | **Commercial Tier Label within P2** (NOT a build phase) | Company/multi-agent add-on within P2. Shared context + data across an organisation. Enabled as a feature flag / commercial unlock when ROI is justified - assessed on demand. No separate infrastructure build. **Licensed Product model: DROPPED (CHG-0234).** |
| **P4** | Enterprise / Regulated | FSI enterprise consulting engagements. APRA CPG 234/235. Regulated sectors. |}

---

## Section 1 - 5-Tier Memory Architecture × P1-P4 Matrix

### T1: Working Memory (Context Window)

| Phase | Status | Technology | Rationale |
|-------|--------|------------|-----------|
| **P1** | ✅ Full | LLM context window (Claude Sonnet/Haiku/Gemma4). Implicit management via OpenClaw. | Already in production. Needs discipline: explicit token budget rules, what enters context, state compression for long workflows. |
| **P2** | ✅ Full | Same mechanism. Session ID as isolation boundary across tenants. | Multi-tenant sessions must be strictly isolated at the session ID level. No cross-tenant context leakage. |
| **P3** | ✅ Full | Customer's LLM (may not be Claude). Design must be model-agnostic. | Customer may substitute their own LLM. Context management patterns must be model-independent. |
| **P4** | ✅ Full + Governance | Same plus: explicit PII-in-context controls, token budget per regulated workload, input/output classification before context injection. | APRA CPG 234: what data enters an AI model's context is a data handling event. Must be logged and classified. |

**P1 action:** Define a token budget policy document. Capture what goes in and out of context for each agent type. This is design-only in P1 but prevents expensive context contamination issues at P2+.

---

### T2: Short-Term / Session Memory

| Phase | Status | Technology | Rationale |
|-------|--------|------------|-----------|
| **P1** | ⚠️ Partial | OpenClaw implicit session state. No formal session store. | Functional but ungoverned. No TTL, no classification, no audit. Minimum: define what constitutes a session and its lifecycle. |
| **P2** | ✅ Full | Redis (primary) or session-scoped Postgres tables. TTL: 24h default. Tenant-isolated by tenant_id prefix/namespace. | Redis preferred for performance. Postgres session tables acceptable if Redis adds too much infrastructure overhead at P2 launch. |
| **P3** | ✅ Full | Customer-provided Redis or Postgres. AInchors provides session schema and TTL recommendations. | Customer owns their infrastructure. AInchors defines minimum spec and governance requirements. |
| **P4** | ✅ Full + Hardened | Redis with TLS, encryption at rest, strict TTL (max 8h for FSI workloads), PII-free session store policy. All session creation/deletion events logged to Tier 3. | FSI clients require session data to be auditable. Session state containing PII must be Gemma4-only or explicitly approved. |

**Key design constraint:** Session state must never persist beyond session end without explicit promotion to Tier 3 (episodic log). Design the lifecycle now; retrofitting is expensive.

---

### T3: Long-Term Episodic Memory (Audit / Compliance Log)

| Phase | Status | Technology | Rationale |
|-------|--------|------------|-----------|
| **P1** | 🔨 Design + Implement | Postgres. Tables: `agent_events`, `agent_decisions`, `decision_lineage`, `memory_access_log`. Schema fully defined in source doc. | **This must be built in P1.** Retroactively adding audit trails is the most expensive data architecture mistake. Every agent action from this point forward should generate an event record. |
| **P2** | ✅ Full | Postgres with tenant_id on all audit tables. Tenant cannot read other tenants' logs. AInchors platform team can read all (with access log). | Tenant isolation via row-level security. Audit logs are a SaaS compliance differentiator - expose to tenant admins as a feature. |
| **P3** | ✅ Full | Customer-deployed Postgres. AInchors provides schema, migration scripts, and compliance queries. Customer owns the data. | AInchors is data processor. Customer is data controller. Customer must be able to run their own compliance reports against their own logs. |
| **P4** | ✅ Full + APRA Grade | Append-only Postgres with hash tamper evidence (SHA-256 on all records). WORM-capable storage for long-term archive. Minimum 7-year retention per APRA. Regular hash verification cron job. | CPG 235 mandates data integrity for regulated records. WORM storage prevents even privileged users from modifying audit records. This is non-negotiable for FSI. |

**P1 immediate action:** Deploy the schema from source doc. Wire SHA-256 hashing into the first 3 agents as a proof of concept. This is Month 1 of the source doc's implementation sequence.

---

### T4: Long-Term Semantic Memory (RAG / Vector Store)

| Phase | Status | Technology | Rationale |
|-------|--------|------------|-----------|
| **P1** | 🔨 Design + Initial Build | pgvector extension on existing Postgres. Embedding: nomic-embed-text via Ollama (local, 768-dim). Initial knowledge base: governance docs, RULES.md, AGENTS.md, APRA CPG summaries. | FSI-safe by default: no data leaves the environment. pgvector chosen for FSI fitness (SQL interface, existing Postgres, ACID, encryption via Postgres config). |
| **P2** | ✅ Full Multi-Tenant | pgvector with schema-per-tenant isolation OR tenant_id + RLS on shared schema. Per-tenant knowledge bases. Shared AInchors base knowledge layer accessible to all tenants (read-only). | Two-layer knowledge model: shared base (AInchors-owned) + tenant-specific (client-owned). Clear data flow boundaries required. |
| **P3** | ✅ Full Customer-Controlled | pgvector on customer's Postgres. Customer ingests their own documents. AInchors provides ingestion pipeline as deployable component. | Customer controls their knowledge base entirely. AInchors cannot access customer embeddings post-deployment. |
| **P4** | ✅ Full + PII Hardened | pgvector with mandatory PII scan before ingestion. `pii_present` flag gates embedding - no PII document embedded without explicit Compliance Agent approval. Quality score threshold enforced. Full provenance on every chunk. | CPG 235: no unvalidated data enters a decision-making system. Every retrieval must be traceable to a source document with verified provenance. |

**Dimension decision:** Choose embedding model in P1 and lock it. Changing embedding dimensions later requires re-embedding the entire knowledge base - expensive and disruptive.

---

### T5: Shared Multi-Agent Memory

| Phase | Status | Technology | Rationale |
|-------|--------|------------|-----------|
| **P1** | 🔨 Design + Partial Build | Postgres tables: `agent_shared_state` (optimistic locking), `agent_state_history` (append-only). Access control matrix (defined in source doc) implemented at application layer. | 6 live agents require coordinated state. Optimistic locking is sufficient at current concurrency (non-parallel agent execution). Schema must be designed to migrate to event sourcing at P4. |
| **P2** | ✅ Full + Tenant Isolation | Postgres with tenant_id on all shared state tables. Agent roles scoped to tenant context. Cross-tenant shared state architecturally prohibited. | Each tenant's agent cluster has its own shared state namespace. Shared state is not shared across tenants. |
| **P3** | ✅ Full Customer-Scoped | Customer-deployed Postgres. Agent shared state within customer environment. AInchors configures access control matrix at deployment time. | Same schema, customer-controlled. AInchors provides configuration tooling to set up the access control matrix per deployment. |
| **P4** | ✅ Full + Event Sourcing | Migrate from optimistic locking to event sourcing. All state changes are immutable events. State derived by replaying event log. Full audit trail of every state mutation with agent identity and timestamp. | CPG 235 + CPG 234: regulated entities require full traceability of how system state changed and who/what changed it. Event sourcing is the only pattern that provides this natively. |

**Migration path:** P1 schema is designed to support event sourcing migration without breaking existing queries. The `agent_state_history` table in P1 is the seed of the event log - build it correctly now.

---

## Section 2 - Data Classification & Use Lens (Per Phase)

### Data Categories

| Category | Definition |
|----------|------------|
| **Client** | Data belonging to or about external clients/customers |
| **Internal** | AInchors operational and business data |
| **System** | Platform-generated metrics, logs, health data |
| **Operational** | Task states, tickets, scripts, change records |
| **Repository** | Knowledge base, governance frameworks, reference data |
| **Backup** | Point-in-time copies of all of the above |

---

### P1 - Internal Single-Tenant

| Category | Present | Owner | Access Control | Flow Constraints |
|----------|---------|-------|----------------|-----------------|
| **Client** | ❌ None | N/A | N/A | Not applicable - no external clients yet. |
| **Internal** | ✅ Yes | Ken / AInchors | Ken only. Single-tenant. No access control enforcement yet. | Ken's prompts, Yoda outputs, decision context. Must not be shared externally. |
| **System** | ✅ Yes | Platform | Ken only. | Logs, metrics, cron outputs, health check results. Low sensitivity. |
| **Operational** | ✅ Yes | Platform | Ken only. | 52 scripts, 85+ change records, ticket states. INTERNAL classification. |
| **Repository** | ✅ Yes | Ken | Ken only. | RULES.md, SOUL.md, MEMORY.md, governance frameworks. CONFIDENTIAL. |
| **Backup** | ✅ Yes | Platform | Ken only. | Daily workspace backups. Must be encrypted at filesystem level (FileVault). |

**P1 gap:** Classification tagging is not yet enforced on any data. Every file and database record should carry a classification label (`PUBLIC / INTERNAL / CONFIDENTIAL / RESTRICTED`) before P2 onboards external clients.

---

### P2 - Managed SaaS Multi-Tenant

| Category | Present | Owner | Access Control | Flow Constraints |
|----------|---------|-------|----------------|-----------------|
| **Client** | ✅ Yes | SME Client (Data Controller) | RBAC by tenant_id. Strict isolation. No cross-tenant access architecturally possible. | Client data stays within tenant namespace. AInchors platform team access requires audit log entry. Clients can export and delete their own data. |
| **Internal** | ✅ Yes | AInchors | AInchors staff only. Separated from tenant data stores. | Billing, onboarding, support tickets. CONFIDENTIAL. Not accessible via tenant APIs. |
| **System** | ✅ Yes | Platform (per tenant) | Platform admins + tenant admin (tenant's own metrics only). | Per-tenant metrics and logs. Tenant admin can view their own system stats. Aggregated AInchors metrics kept separate. |
| **Operational** | ✅ Yes | Per Tenant | Tenant scoped. | Task states, agent outputs. Isolated by tenant_id. |
| **Repository** | ✅ Two-tier | AInchors (base) + Tenant (per-tenant) | Shared base: read-only to all tenants. Tenant layer: tenant admin manages. | AInchors base knowledge (frameworks, policies): no PII. Tenant layer: tenant responsible for PII controls on ingested documents. |
| **Backup** | ✅ Yes | AInchors (platform) | Encrypted. Tenant consent required for backup scope. | Tenant data included in platform backup. Tenant has right to export backup of their own data. Backup deletion on offboarding. |

---

### P3 - Licensed Product (Customer-Deployed)

| Category | Present | Owner | Access Control | Flow Constraints |
|----------|---------|-------|----------------|-----------------|
| **Client** | ✅ Yes | Customer's End Users | Customer's IAM. AInchors has no access post-deployment. | AInchors is a software vendor, not a data processor. Customer data never leaves customer environment. |
| **Internal** | ✅ Yes (AInchors) | AInchors | AInchors only. | Engagement records, support data, licence keys. CONFIDENTIAL. |
| **System** | ✅ Yes | Customer | Customer's monitoring stack. | AInchors may receive anonymised telemetry if contractually agreed - no PII in telemetry. |
| **Operational** | ✅ Yes | Customer | Customer controls. | AInchors has no visibility into customer operational data unless explicitly granted during support engagement. |
| **Repository** | ✅ Yes | Customer | Customer IAM. | Customer's knowledge base within their infrastructure. AInchors provides ingestion tooling. |
| **Backup** | ✅ Yes | Customer | Customer's backup policy. | AInchors provides backup recommendations. Customer's responsibility. No AInchors access to backups. |

---

### P4 - Enterprise / Regulated (FSI)

| Category | Present | Owner | Access Control | Flow Constraints |
|----------|---------|-------|----------------|-----------------|
| **Client** | ✅ Yes (RESTRICTED) | FSI Client (APRA-regulated) | FSI client IAM + APRA access logs. MFA mandatory. All access events logged. | Data cannot leave Australian borders without documented APRA approval. AInchors consultants require explicit access grants. Every access logged to immutable audit trail. |
| **Internal** | ✅ Yes (CONFIDENTIAL) | AInchors | AInchors staff with MFA. | Consulting engagement records, SOW, deliverables. Separate from client data stores entirely. |
| **System** | ✅ Yes (INTERNAL→CONFIDENTIAL) | FSI Client | FSI client's SOC team. AInchors read access during engagement only. | Logs treated as potential evidence. Immutable, hash-verified. Must be available for APRA audit on request. |
| **Operational** | ✅ Yes (RESTRICTED) | FSI Client | Change-controlled. All changes require documented approval. | Every state change traceable to an authorised change record. No ad-hoc operational changes. |
| **Repository** | ✅ Yes (RESTRICTED) | FSI Client | Compliance Agent manages access. PII-assessed before ingestion. | APRA CPG summaries, regulatory rules, internal policies. Every document version-controlled with effective/expiry dates. |
| **Backup** | ✅ Yes (RESTRICTED) | FSI Client | Encrypted (AES-256). WORM where required. | Minimum 7-year retention per APRA. Backup integrity verified quarterly. Secure deletion with certificate at end of retention period. |

---

## Section 3 - Data Type Lens (Per Phase)

### P1 - Internal Single-Tenant

| Data Type | In Use | Tooling | Schema Governance |
|-----------|--------|---------|-------------------|
| **Relational** | ✅ Postgres (planned for episodic log). SQLite for some state files. | Postgres 16+. pgvector extension to add. | Informal. Migration scripts to be written for Phase 4 schema. |
| **Structured JSON/YAML/CSV** | ✅ Extensively | Config files, state files, ticket records, cost reports. In-place on filesystem. | No schema validation enforced. Ad-hoc. |
| **Unstructured (text/docs)** | ✅ Extensively | Markdown files (MEMORY.md, RULES.md, daily notes). Local filesystem. | No formal index. RAG pipeline will provide structure. |
| **Vector/Embedding** | ❌ Not yet | pgvector to be added. nomic-embed-text (768-dim) via Ollama. | Dimension: 768 (locked when embedding model chosen). |
| **Blob/Binary** | ✅ Limited | Script outputs, backups. Local filesystem. | No management beyond filename conventions. |
| **Event/Stream** | ❌ Not yet | Events written to Postgres audit tables (batch, not streaming). | No streaming infrastructure in P1. Acceptable for current load. |

**P1 technical debt to address:** Multiple data types stored on filesystem without schema validation or classification tagging. This is acceptable for single-tenant but will not survive P2.

---

### P2 - Managed SaaS Multi-Tenant

| Data Type | In Use | Tooling | Schema Governance |
|-----------|--------|---------|-------------------|
| **Relational** | ✅ Full | Postgres with schema-per-tenant (≤100 tenants) OR shared schema + tenant_id + RLS (>100 tenants). Read replicas for reporting. | Flyway or Liquibase for schema migrations. Versioned DDL per tenant schema. |
| **Structured JSON/YAML/CSV** | ✅ Full | Config stored in Postgres JSONB with schema validation. File-based configs deprecated for tenant data. | JSON Schema validation on all JSONB columns. |
| **Unstructured (text/docs)** | ✅ Full | S3-compatible object store (AWS S3 Sydney or MinIO self-hosted) for document storage. Postgres for metadata. | Object metadata carries classification label. Document registry in Postgres (knowledge_documents table). |
| **Vector/Embedding** | ✅ Full | pgvector. Per-tenant schema or namespace. Shared AInchors base knowledge layer separate. | Embedding dimensions locked at P1 selection. Index type: ivfflat for ≤1M vectors, HNSW for larger. |
| **Blob/Binary** | ✅ Full | S3-compatible object store. Presigned URLs for secure access. No direct filesystem access. | Object classification label mandatory. PII flag on object metadata. |
| **Event/Stream** | ⚠️ Consider | Redis Streams for async task processing and webhook delivery. Kafka if event volume justifies complexity. | Event schema versioning required. Dead-letter queue for failed events. |

---

### P3 - Licensed Product (Customer-Deployed)

| Data Type | In Use | Tooling | Schema Governance |
|-----------|--------|---------|-------------------|
| **Relational** | ✅ Customer-provided | Postgres 16+ (minimum spec defined by AInchors). AInchors provides DDL scripts and migration tooling. | AInchors provides versioned DDL packages. Customer runs migrations. |
| **Structured JSON/YAML/CSV** | ✅ Customer-managed | Customer's config store. AInchors provides config schema documentation. | Customer responsible. AInchors provides schema validation tooling as optional component. |
| **Unstructured (text/docs)** | ✅ Customer-managed | Customer's object store (any S3-compatible). | AInchors provides minimum metadata spec. Customer implements. |
| **Vector/Embedding** | ✅ Customer-managed | pgvector on customer's Postgres. Embedding model: nomic-embed-text (local) recommended. | Customer controls embedding pipeline. AInchors provides reference implementation. Dimension must match AInchors schema (768). |
| **Blob/Binary** | ✅ Customer-managed | Customer's storage. AInchors provides encryption requirements. | Customer's responsibility with AInchors guidance. |
| **Event/Stream** | ✅ Optional | Customer may integrate with their existing Kafka/event infrastructure. AInchors provides Kafka connector as optional component. | AInchors defines event schema. Customer's integration team implements. |

---

### P4 - Enterprise / Regulated (FSI)

| Data Type | In Use | Tooling | Schema Governance |
|-----------|--------|---------|-------------------|
| **Relational** | ✅ APRA-Grade | Postgres with TDE (Transparent Data Encryption) or encrypted volumes. AES-256 at rest. TLS 1.3 in transit. Row-level security for multi-team FSI environments. | Full ADR per schema change. CPG 235 compliance review before schema migration. Change record required. |
| **Structured JSON/YAML/CSV** | ✅ Governed | JSONB with classification label on every record. Schema validation enforced via Postgres CHECK constraints and application-layer validators. | Schema registry if event streaming adopted. Every field with potential PII classified explicitly. |
| **Unstructured (text/docs)** | ✅ Classified | Encrypted object store. DRM classification on every document. Document lifecycle management (effective date, expiry date, version). | Document registry is authoritative. No document ingested without provenance verification and PII scan. |
| **Vector/Embedding** | ✅ PII-Hardened | pgvector. PII scan mandatory before embedding. `pii_present` flag gates ingestion. Quality score threshold (≥0.7 recommended) before chunk is searchable. | Chunk-level metadata: classification, provenance, PII flag, quality score, expiry date. Retrieval is loggable (memory_access_log). |
| **Blob/Binary** | ✅ Encrypted | Encrypted object store (AES-256). No PII in object metadata. Presigned URLs with short TTL (max 1h for FSI). | WORM-capable storage for audit artefacts. Cryptographic hash on all objects for integrity verification. |
| **Event/Stream** | ✅ Event Sourcing | Postgres event log (minimum). Kafka optional for integration with FSI client systems. All events immutable. | Event schema versioned. No retroactive event mutation. Dead-letter queue + alerting for failed events. |

---

## Section 4 - Additional Considerations Lens (Per Phase)

### 4.1 Encryption

| Aspect | P1 | P2 | P3 | P4 |
|--------|----|----|----|----|
| **At-rest** | macOS FileVault (disk-level). No application-level Postgres encryption. **Gap: must add before any sensitive data stored.** | Postgres on encrypted volumes (LUKS/dm-crypt on Linux) or cloud-managed encryption (AWS RDS encryption). AES-256. | Customer provides encryption. AInchors specifies minimum: AES-256 at rest. Customer must attest compliance. | AES-256 mandatory. Postgres TDE or encrypted EBS volumes. APRA CPG 234 requirement. |
| **In-transit** | TLS for all API calls to Claude/Anthropic. OpenClaw handles this. Verify: all internal service calls over TLS. | TLS 1.3 minimum for all services. Certificate management via Let's Encrypt (dev) or AWS ACM (prod). | TLS 1.3 between AInchors components. Customer responsible for their network layer. AInchors provides TLS requirements document. | TLS 1.3 mandatory. Mutual TLS (mTLS) for service-to-service. APRA CPG 234: no plaintext transmission of sensitive data. Certificate rotation policy required. |
| **Key Management** | macOS Keychain for secrets (already in place per RULES.md). No formal KMS. | Cloud KMS (AWS KMS or Azure Key Vault). Key rotation: annual minimum. Separate keys per tenant class. | Customer manages keys. AInchors provides key management recommendations and minimum standards. | HSM-backed key management. Customer-managed keys (CMK) option for FSI client sovereignty. Key rotation: 90-day maximum for data encryption keys. APRA CPG 234: formal key lifecycle documentation required. |

---

### 4.2 Real-Time vs Batch

| Workload Class | P1 | P2 | P3 | P4 |
|----------------|----|----|----|----|
| **Agent requests** | Synchronous/real-time. API call → agent → response. | Real-time for interactive requests. Async task queue for long-running agent workflows. | Customer defines. AInchors provides async task queue component. | Real-time with synchronous audit logging. Decision events must be logged before response is returned to client. |
| **Knowledge base ingestion** | Batch (manual trigger). Month 1 of source doc plan. | Batch (nightly or on-demand per tenant). Quality gate before embedding. | Customer-scheduled batch. AInchors provides ingestion pipeline as cron-compatible component. | Batch with compliance gate. Every document must pass PII scan, quality score, and provenance verification before embedding. |
| **Audit log writes** | Synchronous writes to Postgres on each agent event. | Synchronous writes (audit must not be async - risk of data loss on failure). | Synchronous. Customer's Postgres. | Synchronous mandatory. Async audit logging is a CPG 234 compliance risk. Write to audit log must succeed before acknowledging the agent action. |
| **Cost/usage reporting** | Batch (nightly cron, already in place). | Real-time cost metering per tenant + daily batch summary reports. | Customer manages cost visibility. AInchors provides optional cost reporting component. | Real-time cost tracking for model cost allocation to regulated workloads. Batch monthly reporting for APRA operational risk metrics. |
| **Compliance reporting** | Not yet. Ad-hoc queries against Postgres. | Batch (daily/weekly compliance reports per tenant). Exportable for tenant compliance teams. | Customer-run batch. AInchors provides compliance query library. | Formal batch reporting on defined schedule. APRA-ready export format. Human review gate before report is finalised. |

---

### 4.3 Caching

| Layer | P1 | P2 | P3 | P4 |
|-------|----|----|----|-----|
| **Session state** | Implicit in OpenClaw. No TTL. | Redis with 24h TTL. LRU eviction. Tenant-isolated namespace. | Customer's Redis. AInchors recommends 24h TTL, LRU eviction. | Redis with 8h maximum TTL for FSI workloads. PII-free session store policy: no PII in session cache. Session cache events logged. |
| **Embedding / vector query results** | Not applicable (vector store not yet built). | Redis cache for hot embedding queries. TTL: 7 days with LRU eviction. Cache invalidation on document update (via Postgres trigger + cache bust). | Customer's cache. AInchors recommends embedding cache for performance. | Strict governance: only non-PII embeddings cacheable. Classification check before caching. Cache entries carry classification label. |
| **Tool call results** | No caching. Fresh call each time. | Optional: short-TTL cache (5-15 min) for deterministic external API calls (weather, lookup tables). | Customer decision. | No caching of regulated data tool results. Deterministic lookups only. Cache hit must still be logged to audit trail. |
| **LLM responses** | No caching. | Semantic cache (LangChain SemanticCache or custom) for identical/near-identical queries. Cost saving at scale. | Optional component. | Strict prohibition on caching LLM responses that include regulated or PII-adjacent content. Non-PII general knowledge responses cacheable with INTERNAL classification. |

---

### 4.4 Retention Policy

| Data Category | P1 | P2 | P3 | P4 |
|---------------|----|----|----|----|
| **Episodic audit log** | Indefinite (small volume, no formal policy). Define a policy in P1 as a placeholder. | 2 years minimum (SME SaaS SLA). Configurable per tenant. | Customer defines. AInchors recommends 2-year minimum. | 7 years minimum per APRA regulatory requirement. Non-negotiable. |
| **Session state** | No TTL. Persists until OpenClaw session ends. | 24h TTL in Redis. Archived to Postgres on session end (summary only, not full state). | Customer TTL policy. | 8h maximum in cache. Session summary archived to episodic log on session end. Full session state deleted after archive. |
| **Knowledge chunks** | No expiry defined yet. Must add `expires_at` field. | Per document `expires_at` field. Automated expiry process (nightly cron). Default: 1 year. | Customer defines expiry. AInchors provides automated expiry tooling. | Per regulatory document lifecycle. Regulatory documents: effective_date to expiry_date strictly enforced. Expired chunks removed within 24h of expiry. |
| **Shared agent state** | No policy. State history grows indefinitely. | State history: 1 year retention. Archived to cold storage after 90 days. | Customer policy. AInchors provides archival tooling. | State history: 7 years. Immutable event log. WORM archive after 90 days. Cryptographic hash verification on archive. |
| **Backups** | Daily backups (nightly cron in place). Retention: undefined. Set 30 days as P1 baseline. | Daily incremental + weekly full. Retention: 30 days daily, 12 months weekly. Tenant data: per service agreement. | Customer manages. AInchors provides backup recommendations. | Daily encrypted backup. Retention: 7 years minimum for audit data. Quarterly backup restoration test. Deletion certificate on expiry. |

**Deletion mechanism at P4:** Cryptographic erasure (key deletion) for cloud storage. Secure overwrite + certificate for on-premises. Deletion event logged to immutable audit trail.

---

### 4.5 Data Residency

| Aspect                     | P1                                                                                                                  | P2                                                                                                                                                               | P3                                                                                                   | P4                                                                                                                                                                                                                                                                                |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Storage location**       | All data on OC1 Mac Mini. Ken's control. Australian soil (Melbourne). No offshore storage.                          | Cloud: AWS ap-southeast-2 (Sydney) or Azure East Australia for AU clients. International clients: jurisdiction-specific regions.                                 | Customer controls. AInchors provides residency considerations document per target jurisdiction.      | All data on Australian soil mandatory (or documented APRA approval for offshore). AWS Sydney or Azure East Australia. No exceptions without written APRA consent.                                                                                                                 |
| **Claude API (Anthropic)** | Data sent to Anthropic servers. **Must verify:** Does Anthropic process Australian data in Australia? DPA required. | Same concern at scale. DPA with Anthropic must clarify Australian data processing location. Consider routing non-PII workloads via Claude, PII via Gemma4 local. | Customer must verify their API provider's data residency. AInchors provides due diligence checklist. | **High risk.** For FSI clients: all PII and regulated data must use Gemma4 (local) or a verified Australian-sovereign cloud AI service. Claude API for FSI PII workloads requires explicit APRA approval in DPA. Recommend: route all regulated workloads to local Ollama/Gemma4. |
| **Gemma4 / Ollama**        | Fully local. No residency risk. Recommended for all PII-adjacent workloads now.                                     | Deployed on cloud instance in correct region. No data leaves the cloud instance.                                                                                 | Customer deploys Ollama locally. No residency risk.                                                  | Preferred for all regulated workloads. Gemma4 local is the FSI-safe default. Claude used only for non-PII, non-regulated content with documented DPA.                                                                                                                             |
| **Google Workspace (gog)** | Ken's `kenmun@ainchors.com`. No client data in Google Workspace in P1.                                              | Must not use Google Workspace for tenant data processing. Separate tooling for SaaS data flows.                                                                  | Customer's own Google Workspace if applicable.                                                       | Forbidden for regulated client data without explicit FSI client approval and APRA data residency compliance check.                                                                                                                                                                |

---

## Section 5 - Physical Infrastructure Architecture Lens (Per Phase)

### P1 - OC1 Mac Mini (Current)

| Dimension | Detail |
|-----------|--------|
| **Storage type** | Local NVMe SSD (Mac Mini internal). SQLite for lightweight state. Postgres to be deployed (Homebrew or Docker). Local filesystem for Markdown/YAML/JSON. Ollama model store on local NVMe. |
| **Location** | OC1 Mac Mini, Melbourne, Australia. Single node. Residential internet. |
| **Performance tier** | 🔥 Hot - NVMe SSD. Suitable for all P1 workloads. Low concurrent load. |
| **HA / DR** | None. Single point of failure. Daily backup to external medium is the only DR. Acceptable for P1 internal use only. |
| **Scalability gate** | Trigger for P2 infrastructure investment: (a) Postgres + pgvector + Ollama IO saturates Mac Mini, (b) 24/7 availability required beyond residential internet, (c) first external client onboarded, (d) Ken's Mac Mini is needed for development and conflicts with always-on platform requirement. |
| **Estimated capacity headroom** | Mac Mini M-series with 32-64GB RAM can comfortably support: Postgres + pgvector + nomic-embed-text + Ollama Gemma4 + OpenClaw runtime. Sufficient for P1 through early P2 piloting (1-5 tenants). |

---

### P2 - OC2 HA Cluster + Cloud Hybrid (Planned)

| Dimension | Detail |
|-----------|--------|
| **Storage type** | Postgres 16+ on SSD-backed cloud instances (AWS RDS or self-managed on EC2/EC2-equivalent). Redis for session cache. S3-compatible object store for documents and blobs. pgvector as Postgres extension. |
| **Location** | OC2 HA cluster (2-node active-passive minimum) in AWS ap-southeast-2 (Sydney) or Azure East Australia. Dev/test on extended OC1 or local Docker. |
| **Performance tier** | 🔥 Hot - NVMe SSD for Postgres (gp3 EBS or equivalent). 🌡️ Warm - Standard SSD for object store (S3 Standard). |
| **HA / DR** | Active-passive Postgres with streaming replication. RTO: <4h. RPO: <1h. Automated failover via Patroni or RDS Multi-AZ. Redis Sentinel or Redis Cluster for cache HA. |
| **Scalability gate** | Trigger for schema-per-tenant → shared schema + RLS migration: tenant count >100. Trigger for read replica addition: Postgres CPU >70% sustained. Trigger for Citus sharding: single-node Postgres IOPS saturated with write-heavy workload. |
| **Estimated capacity headroom** | 2-node cluster with r6g.xlarge (AWS) or equivalent handles ~500 concurrent tenants before scaling review needed. Object store effectively unlimited at cost. |

---

### P3 - Customer-Deployed (Variable)

| Dimension | Detail |
|-----------|--------|
| **Storage type** | Customer-provided. Minimum spec (AInchors mandate): Postgres 16+ with pgvector, Redis 7+, S3-compatible object store, Ollama runtime for local embedding. |
| **Location** | Customer's infrastructure - on-prem DC, private cloud, or public cloud. AInchors has no control over location. |
| **Performance tier** | Customer-defined. AInchors provides sizing guide: minimum 8 cores, 32GB RAM, 500GB SSD for standard deployment. |
| **HA / DR** | Customer's responsibility. AInchors provides HA architecture reference. Recommended: Postgres streaming replication minimum. |
| **Scalability gate** | AInchors provides capacity planning guide. Customer engages AInchors consulting for scale reviews as part of support contract. |
| **AInchors deliverables** | Minimum specification document, Terraform/Helm deployment templates (or equivalent), migration scripts, sizing calculator. |

---

### P4 - APRA-Grade Enterprise (FSI)

| Dimension | Detail |
|-----------|--------|
| **Storage type** | Postgres with TDE or encrypted EBS volumes (AES-256). HSM-backed key store (AWS CloudHSM, Thales, or equivalent). WORM-capable object store for audit archive (AWS S3 Object Lock COMPLIANCE mode or equivalent). Separate cold archive storage for 3-7 year retention. |
| **Location** | Australian data centres only. AWS Sydney (ap-southeast-2), Azure East Australia, or FSI client's own DC in Australia. No offshore replication without documented APRA approval. |
| **Performance tier** | 🔥 Hot - NVMe for active audit log + vector queries (io2 EBS or NVMe NAS). 🌡️ Warm - SSD for 1-2 year retention. 🧊 Cold - WORM object store for 3-7 year archive. |
| **HA / DR** | Active-passive Postgres HA minimum (APRA business continuity expectation). RTO: <4h, RPO: <1h (typical APRA requirement). Automated failover. Quarterly DR test with documented evidence. |
| **Scalability gate** | APRA-regulated FSI workloads typically require dedicated infrastructure per client engagement. No shared infrastructure with other tenants at P4. Capacity planning per engagement, driven by FSI client SLA. |
| **Additional P4 requirements** | Network segmentation (dedicated VPC/VNET for each FSI engagement). WAF + DDoS protection. Vulnerability scanning quarterly. Penetration testing annually (APRA CPG 234 expectation). |

---

## Section 6 - Design Decision Register

### Decision 1: Vector Store Selection

| Attribute | Detail |
|-----------|--------|
| **Phase classification** | **Decide now (P1)** |
| **Options** | pgvector (Postgres extension), Chroma, Qdrant, Weaviate |
| **Recommended** | **pgvector** |
| **Rationale** | SQL interface - zero new query language. Encryption via existing Postgres config. ACID compliance - critical for FSI audit. No new infrastructure to manage in P1. Supported by all major cloud Postgres services for P2+. Track record in FSI deployments. |
| **Risk of deferring** | Cannot start RAG pipeline or T4 implementation without a vector store decision. Every day deferred is a day without semantic memory. |
| **Constraints** | Locks embedding dimension at table creation. Must choose embedding model first (see Decision 2). At extreme scale (>10M vectors), Qdrant outperforms pgvector - but this is a P4+ concern, not P1. |

---

### Decision 2: Embedding Model Selection

| Attribute | Detail |
|-----------|--------|
| **Phase classification** | **Decide now (P1)** |
| **Options** | nomic-embed-text via Ollama (768-dim, local), text-embedding-3-small via OpenAI (1536-dim, cloud), mxbai-embed-large via Ollama (1024-dim, local) |
| **Recommended** | **nomic-embed-text (768-dim)** as P1 primary. text-embedding-3-small for non-PII general knowledge (optional dual-model approach). |
| **Rationale** | nomic-embed-text: fully local, FSI-safe by default, no data residency risk, good performance, Ollama already deployed. 768 dimensions is sufficient for the knowledge base scale anticipated in P1-P2. Dual-model approach adds complexity - single model preferred unless quality gap is demonstrated. |
| **Risk of deferring** | The embedding dimension is baked into the `knowledge_chunks` table schema (`vector(768)`). Changing dimension post-deployment requires dropping and recreating the vector index and re-embedding all documents. Defer this at your peril. |
| **Decision gate** | Evaluate quality of nomic-embed-text retrieval after initial knowledge base load (Month 2 per source doc). If retrieval quality is insufficient, migrate to mxbai-embed-large (also local) before knowledge base grows large. |

---

### Decision 3: Chunking Strategy

| Attribute | Detail |
|-----------|--------|
| **Phase classification** | **Decide now (P1)** |
| **Options** | Fixed-size (simple, fast), RecursiveCharacterTextSplitter (structure-aware), semantic chunking (quality-first, expensive), sentence-window (retrieval enhancement) |
| **Recommended** | **RecursiveCharacterTextSplitter at 400-600 tokens with 10-20% overlap** for P1. |
| **Rationale** | Balances simplicity and quality. Respects document structure (paragraphs, sections). Overlap prevents context loss at chunk boundaries. Standard starting point in production RAG systems. Semantic chunking reserved for P4 where retrieval quality is a compliance requirement. |
| **Metadata per chunk** | source_document, chunk_index, created_at, expires_at, classification, pii_present, quality_score. Define this schema now - retrofitting metadata is expensive. |
| **Risk of deferring** | Chunking strategy affects retrieval quality directly. A poor chunking decision degrades RAG accuracy across the entire knowledge base. Define and test before loading significant document volume. |

---

### Decision 4: Concurrency Model for Shared Memory

| Attribute | Detail |
|-----------|--------|
| **Phase classification** | **Decide at P1 (optimistic locking) + plan P4 migration path now** |
| **Options** | Pessimistic locking (safe, bottleneck risk), optimistic locking (performant, retry on conflict), event sourcing (most auditable, most complex) |
| **Recommended** | **Optimistic locking in P1** with schema designed for event sourcing migration. |
| **Rationale** | Current platform has 6 agents with non-parallel execution - optimistic locking has near-zero conflict rate. Building event sourcing now is premature optimisation. However, the `agent_state_history` table must be built correctly in P1 as the embryonic event log, to allow migration at P4 without a schema redesign. |
| **P4 migration trigger** | When: (a) parallel agent execution is introduced, OR (b) FSI client requires full audit trail of state mutations (CPG 235). |
| **Risk of deferring event sourcing** | Low in P1-P3. High at P4 if schema was not designed with migration in mind. The `agent_state_history` table is the mitigation - build it now. |

---

### Decision 5: Data Residency Framework

| Attribute | Detail |
|-----------|--------|
| **Phase classification** | **Decide now (P1)** - framework; reassess at each phase gate |
| **P1 baseline** | All data on OC1 Mac Mini (Australian soil). Gemma4 via Ollama: fully local, no residency risk. Claude via Anthropic API: **data residency unverified - must check Anthropic DPA.** |
| **Recommended** | Establish a Data Residency Register. For each model and API endpoint, document: (a) where data is processed, (b) Anthropic/vendor DPA status, (c) which data categories can flow to that endpoint. |
| **Immediate action** | Verify Anthropic's Australian data processing location. If data leaves Australia in Claude API calls, classify: which workloads are acceptable (non-PII, non-regulated) and which must be routed to Gemma4 local. |
| **P4 non-negotiable** | All regulated FSI workloads: Gemma4 local or documented APRA-approved cloud AI service. Claude API for FSI PII is a compliance risk until Anthropic DPA explicitly covers Australian APRA requirements. |
| **Risk of deferring** | Deferring residency assessment means potentially non-compliant data flows are in production. For P1 internal use, risk is low. For any client engagement, risk is material. |

---

### Decision 6: Multi-Tenancy Isolation Model (P2 — from day one, CHG-0234)

| Attribute | Detail |
|-----------|--------|
| **Phase classification** | **Build in P2 from day one (CHG-0234 — updated from "P2 gate")** |
| **Options** | Schema-per-tenant (strong isolation, operational overhead), Row-level security + tenant_id (scalable, complex RLS policies), Database-per-tenant (maximum isolation, highest cost) |
| **Recommended (updated)** | **Shared schema + RLS with tenant_id from day one in P2.** P3 commercial tier (company/multi-agent) is a feature flag on top of this foundation — not a separate build. Schema-per-tenant acceptable for very early P2 (≤20 tenants) but must migrate to RLS before P3 commercial tier is enabled. |
| **Rationale (CHG-0234)** | P3 is no longer a separate build phase. P2 must deliver the full multi-tenant foundation from day one: tenant_id on every table (NOT NULL, indexed), RLS policies enforced at Postgres level, shared state concurrency (optimistic locking with version column on agent_shared_state), access control matrix per tenant (agent roles scoped to tenant context), company-level auth hooks (org_id field, group membership, SSO/SAML integration points stubbed). Cross-tenant access architecturally prohibited at schema level. |
| **Design now** | P1 schema must be fully parameterised on tenant_id (even though P1 is single-tenant). Every table should have tenant_id as a column, even if it always equals 'ainchors' in P1. This makes P2 day-one implementation significantly cheaper. |

---

### Decision 7: Key Management Architecture (P2 Gate)

| Attribute | Detail |
|-----------|--------|
| **Phase classification** | **Decide at P2 gate** |
| **Options** | macOS Keychain (P1 only), Cloud KMS (AWS KMS / Azure Key Vault), HashiCorp Vault (self-managed, more control), Customer-managed keys (CMK) for P3/P4 |
| **Recommended** | Cloud KMS at P2 (AWS KMS if AWS-primary). HashiCorp Vault if multi-cloud or on-prem is required at P3. CMK option for P4 FSI clients. |
| **P1 action** | Document all current secrets stored in macOS Keychain. Map them to future KMS equivalents. Do not add new secret types to Keychain without a migration plan. |

---

### Decision 8: Session State Store

| Attribute | Detail |
|-----------|--------|
| **Phase classification** | **Decide now (P1)** |
| **Options** | Postgres session tables (no new infrastructure), Redis (better performance, new dependency) |
| **Recommended** | **Postgres session tables in P1.** Migrate to Redis at P2 when concurrent session count warrants it. |
| **Rationale** | Adding Redis to P1 is premature. Single-tenant, sequential sessions. Postgres is already being deployed for the episodic log. Use it for session state too. Define the migration path to Redis so P2 build is clean. |

---

### Decision 9: Event Streaming Adoption (P2 Gate)

| Attribute | Detail |
|-----------|--------|
| **Phase classification** | **Decide at P2 gate** |
| **Options** | No streaming (Postgres polling), Redis Streams (lightweight, already in stack), Apache Kafka (enterprise-grade, complex) |
| **Recommended** | **Redis Streams at P2** for async task queue and webhook delivery. **Kafka at P4** only if FSI client has existing Kafka infrastructure or event volume justifies it. |
| **Rationale** | Kafka is significant operational overhead. Redis Streams handles ~10K events/second - more than sufficient for P2 SaaS. Kafka becomes justified at P4 enterprise scale or FSI client integration requirements. |

---

### Decision 10: Embedding Dimension Standardisation

| Attribute | Detail |
|-----------|--------|
| **Phase classification** | **Decide now (P1) - locked at table creation** |
| **Recommended** | **768 dimensions** (nomic-embed-text). |
| **Rationale** | Changing dimensions post-production requires full re-embedding of all documents. Lock this before loading any significant knowledge base. If text-embedding-3-small (1536-dim) is later preferred, a migration plan must be executed. |
| **Risk** | High. This is the single most expensive decision to change retroactively. Decide before Month 2 implementation begins. |

---

## Section 7 - APRA Compliance Phase Map

### CPG 234 (Information Security) Controls

| Control | Mandatory in P1? | P2 | P3 | P4 |
|---------|-----------------|----|----|-----|
| Data classification on all stored data (PUBLIC/INTERNAL/CONFIDENTIAL/RESTRICTED) | ⚠️ Build habit now - enforce at P2 | ✅ Enforced | ✅ Customer-implemented | ✅ Mandatory, auditable |
| Encryption at rest (AES-256) | ⚠️ FileVault only. Add Postgres-level before any CONFIDENTIAL data stored | ✅ Postgres encrypted volumes | ✅ Customer must attest | ✅ Mandatory, audited |
| Encryption in transit (TLS 1.3 minimum) | ✅ Already in place for API calls. Verify all internal paths | ✅ Enforced | ✅ Customer must attest | ✅ Mandatory, mTLS for service-to-service |
| Access control (least-privilege per agent per memory tier) | ⚠️ Design the access matrix now (source doc has it). Implement at P1. | ✅ Tenant-scoped RBAC | ✅ Customer-configured | ✅ Full RBAC + MFA, audited |
| Immutable audit log with tamper evidence | 🔨 Build in P1. Non-negotiable foundation. | ✅ Per-tenant, exportable | ✅ Customer-deployed | ✅ WORM-backed, hash-verified |
| Incident response: PII detection triggers escalation | ⚠️ Design trigger in P1. Wire to Compliance Agent at P2. | ✅ Automated escalation | ✅ Customer-configured | ✅ APRA CPG 234 Clause 52 aligned |
| Vulnerability management | ⚠️ No PII in vector store without governance. PII scan before ingestion. | ✅ Automated PII scanner | ✅ Customer tooling | ✅ Quarterly vuln scan + annual pen test |
| Security agent reviews all WRITE operations to shared state | ⚠️ Define the review pattern now. Implement at P1 for high-value writes. | ✅ Automated review gate | ✅ Customer-configured | ✅ Full review gate, logged |

---

### CPG 235 (Managing Data Risk) Controls

| Control | Mandatory in P1? | P2 | P3 | P4 |
|---------|-----------------|----|----|-----|
| Data quality gate on document ingestion (quality_score threshold) | ⚠️ Define the threshold now (≥0.7 recommended). Implement at P2 Month 2. | ✅ Enforced. Quality score required before embedding. | ✅ Customer-configured threshold. | ✅ Mandatory. Compliance Agent approves ingestion below threshold. |
| Source verification (provenance on every knowledge document) | ⚠️ Add provenance metadata fields in Month 1 schema. | ✅ Document registry with provenance. | ✅ Customer-maintained. | ✅ Every document: verified provenance + effective/expiry date. |
| Data retention policy with automated expiry | ⚠️ Define the policy in P1 even if volume doesn't yet demand it. | ✅ 2-year default. Automated nightly expiry cron. | ✅ Customer policy. AInchors provides tooling. | ✅ 7-year minimum. WORM archive. Automated expiry + deletion cert. |
| Data residency assessment per model/API endpoint | ✅ Must do in P1. Anthropic DPA verification is urgent. | ✅ Cloud region documented. AU clients on AU region. | ✅ Customer residency responsibility + AInchors checklist. | ✅ Formal data residency attestation. Australian soil only. |
| Model risk register (limitations, failure modes, human review thresholds) | ⚠️ Start now. Document known Claude/Haiku/Gemma4 limitations. | ✅ Maintained in platform docs. | ✅ Included in customer deployment package. | ✅ Formal model risk register per APRA model risk management. |
| Data lineage: every agent decision traceable to source data | 🔨 Build in P1 (decision_lineage table). Non-negotiable. | ✅ Full lineage per tenant. | ✅ Customer-deployed. | ✅ Full lineage + human review capability. |
| Change management: schema changes via change control | ✅ 85+ change records already in place. Extend to cover schema changes explicitly. | ✅ Formal change management. DDL migration versioned. | ✅ AInchors provides versioned DDL packages. Customer applies. | ✅ CPG 235 Clause 27: all data risk management changes require formal approval. |

---

### Privacy Act 1988 (Australian Privacy Principles)

| Control | Mandatory in P1? | P2 | P3 | P4 |
|---------|-----------------|----|----|-----|
| PII scanner on all document ingestion before chunking/embedding | 🔨 Build in P1. Any document loaded into knowledge base must be PII-scanned first. | ✅ Automated. Blocks embedding of PII-positive documents without approval. | ✅ Customer deploys PII scanner. | ✅ Mandatory. Compliance Agent gate. |
| PII-containing docs routed to Gemma4 local only | ⚠️ Enforce as policy now. Wire to model router at P1. | ✅ Automated routing via classification check. | ✅ Customer-configured model router. | ✅ Architectural mandate. No PII to external API without written consent. |
| pii_present flag blocks embedding without explicit approval | 🔨 Build in P1 schema. | ✅ Enforced in ingestion pipeline. | ✅ Customer-configured. | ✅ Compliance Agent must approve any PII content in vector store. |
| pii_detected flag on agent_events triggers Compliance Agent review | 🔨 Wire at P1. | ✅ Automated escalation workflow. | ✅ Customer-configured escalation. | ✅ Real-time escalation. Human review required within defined SLA. |
| Data subject access and deletion (chunk-level deletion by document_id) | ⚠️ Build deletion capability in P1 even if no external data subjects yet. Build it before you need it. | ✅ Tenant admin can trigger deletion. Audit log of deletion event. | ✅ Customer implements. AInchors provides deletion tooling. | ✅ Formal data subject request process. Deletion cert. APRA + Privacy Act aligned. |
| APP 11 - Security safeguards for personal information | ✅ FileVault + TLS at minimum. Add Postgres encryption for any PII stored. | ✅ Full encryption stack. PII isolated. | ✅ Customer responsible. AInchors provides security requirements. | ✅ Full APRA CPG 234 stack. HSM. mTLS. Quarterly audit. |

---

## Section 8 - P1 Immediate Actions

These 5 actions must be started now to avoid expensive rework later. Sequenced by dependency.

### Action 1 (Week 1-2): Deploy Postgres + Episodic Log Schema
**What:** Install Postgres (via Homebrew or Docker on OC1). Deploy the schema from the source doc: `agent_events`, `agent_decisions`, `decision_lineage`, `memory_access_log`. Add SHA-256 hashing to the first 3 most active agents as proof of concept.
**Why now:** Every agent action from this point forward without audit logging is permanently unauditable. This is the single most important foundation item.
**Risk of delay:** P1 audit gap grows daily. Retrofitting audit logging retroactively is significantly more expensive than building it first.

---

### Action 2 (Week 1-2, parallel): Verify Anthropic Data Processing Agreement
**What:** Check Anthropic's DPA - specifically: where is Australian customer data processed? Is it in Australia or the US? Document in a Data Residency Register: for each model and API endpoint, where data flows.
**Why now:** If Claude API routes data offshore, every Claude call with PII or sensitive content may be a Privacy Act APP 11 compliance risk. Must be understood before any external client data touches the platform.
**Risk of delay:** Unknown compliance exposure in production today. Cheap to check; expensive to remediate.

---

### Action 3 (Week 2-3): Add tenant_id to All Postgres Tables (P2-readiness)
**What:** Even though P1 is single-tenant, add `tenant_id VARCHAR(100) DEFAULT 'ainchors'` to every table in the P1 schema. This is a 1-line change per table now; it is a painful migration when 20 tables exist and clients are live in P2.
**Why now:** Multi-tenancy isolation is the single most expensive architectural retrofit. Lock in the column now.
**Risk of delay:** P2 launch requires either a disruptive schema migration or a messy bolt-on. Adding tenant_id now costs 30 minutes; adding it during a P2 migration costs days.

---

### Action 4 (Week 3-4): Lock Embedding Model + Dimension, Deploy pgvector
**What:** Formally choose nomic-embed-text (768-dim). Add the pgvector extension to Postgres. Create the `knowledge_chunks` and `knowledge_documents` tables with `vector(768)`. Do NOT load any documents yet - just stand up the infrastructure.
**Why now:** The embedding dimension is baked into the schema. Every document loaded before this decision is made will need to be re-embedded if the dimension changes. Lock it before Month 2 ingestion begins.
**Risk of delay:** Knowledge base load begins in Month 2. If dimension is not locked, the first batch of embeddings may need to be discarded.

---

### Action 5 (Week 3-4): Implement PII Scanner on Document Ingestion Pipeline
**What:** Install spaCy with `en_core_web_lg` (or Presidio for enterprise-grade). Wire it into the document ingestion path: before any document is chunked or embedded, it must pass the PII scanner. Set `pii_present = TRUE` flag on detected documents. Block embedding without explicit approval.
**Why now:** Once PII-containing documents are embedded into the vector store, surgical removal is complex. A pre-ingestion PII gate is the cheapest place to implement this control.
**Risk of delay:** First knowledge base documents are loaded in Month 2. Any PII that enters the vector store without this gate is a Privacy Act compliance risk.

---

## Section 9 - Open Decisions for Ken

These require Ken's input before implementation can proceed. Framed as decisions, not recommendations.

---

**Q1. Anthropic DPA - Which workloads are acceptable on Claude API?**
After verifying Anthropic's data processing location: which categories of data are you comfortable sending to Claude API (e.g., non-PII, non-regulated internal content only)? This determines the model routing policy for all agents.

---

**Q2. Postgres deployment model on OC1 - Standalone vs Docker?**
Standalone Postgres via Homebrew is simpler and lower overhead. Docker provides easier migration to P2 cloud. Preference? Note: Docker on Mac Mini adds memory overhead to a machine also running Ollama + OpenClaw.

---

**Q3. Redis in P1 - Add now or defer to P2?**
Redis adds session caching capability but is another process on OC1. Assessment: Postgres session tables are sufficient for P1 single-tenant load. Do you want to accept the Postgres-only approach for P1, or add Redis now for P2-readiness?

---

**Q4. Initial knowledge base - Which documents first?**
Month 2 calls for loading the initial knowledge base. Suggested priority: RULES.md, AGENTS.md, SOUL.md, governance frameworks, APRA CPG 234/235 summaries. Do you agree with this priority, or are there other documents (e.g., MIT Sloan materials, job search research) you want indexed first?

---

**Q5. PII scanner tool - spaCy or Presidio?**
spaCy with en_core_web_lg: lighter, faster, good for English text. Presidio (Microsoft): heavier, more enterprise-grade, supports more entity types, better for structured data PII detection. Both are local. Decision affects installation complexity and detection quality. Preference?

---

**Q6. Audit log retention period for P1 - How long to keep?**
Source doc has no formal retention policy yet. Recommended P1 baseline: indefinite (volume is small). However, establishing a formal policy now (even if 'indefinite') creates the habit before P2 when client data SLAs require defined retention. Do you want to set a formal retention policy in P1?

---

**Q7. agent_shared_state conflict handling - Retry or last-write-wins?**
With optimistic locking, when two agents write to the same key simultaneously, one will fail the version check. Options: (a) application retries automatically (safe but adds complexity), (b) last write wins (simpler, some conflict risk at low concurrency). Given current sequential agent execution, last-write-wins with history preserved is arguably sufficient for P1. Your call.

---

**Q8. P2 multi-tenancy model - Schema-per-tenant or shared schema + RLS?**
Recommended: schema-per-tenant for early P2 (≤100 tenants). This is a commitment that affects how P2 infrastructure is built. Do you confirm this approach, or do you want to build RLS from day one (harder upfront, cleaner at scale)?

---

**Q9. — RESOLVED (CHG-0234, Ken confirmed 2026-05-08 15:08 AEST)**

~~Is P3 (licensed product) a planned phase or a skip?~~

P3 as a build phase is **dropped**. The Licensed Product model is **dropped entirely**. Phase sequence is **P1 → P2 → P4**.

P3 survives only as a **commercial tier label within P2**: company/multi-agent feature set (shared context + data across an organisation) is a feature flag and commercial unlock within P2 — enabled on demand, ROI-gated. No separate infrastructure build. No separate architecture phase.

Multi-tenant foundation (tenant_id, RLS, shared state concurrency, access control matrix, SSO/SAML hooks) must be built in P2 from day one so the P3 commercial tier can be unlocked without additional infrastructure work.

---

**Q10. Portfolio artefacts - Primary audience: job search or AInchors clients?**
The source doc identifies 6 portfolio artefacts. Are these primarily for Ken's job search (CIO/CTO credential, targeting 2028-2029) or for AInchors client-facing deliverables (P2/P4 sales tool)? This affects the framing, depth, and format of each artefact. Both are valid - but the answer shapes how they should be written.

---

## Appendix A - Architecture Decision Summary

| Decision | Phase | Recommended | Locked? |
|----------|-------|-------------|---------|
| Vector store | P1 | pgvector | 🔴 Decide now |
| Embedding model | P1 | nomic-embed-text (768-dim) | 🔴 Decide now |
| Chunking strategy | P1 | RecursiveCharacterTextSplitter, 400-600 tokens, 10-20% overlap | 🔴 Decide now |
| Concurrency model | P1→P4 | Optimistic locking P1–P2 (incl. P3 commercial tier), event sourcing P4 | 🔴 Decide now |
| Data residency framework | P1+ | Gemma4 for PII, Claude for non-PII (post-DPA verification) | 🔴 Decide now |
| Embedding dimensions | P1 | 768 (nomic-embed-text) | 🔴 Decide now - locked at table creation |
| Session state store | P1 | Postgres session tables (Redis at P2) | 🔴 Decide now |
| Multi-tenancy isolation | **P2 day one (CHG-0234)** | Shared schema + RLS + tenant_id from day one. P3 commercial tier = feature flag on this foundation | 🔴 **Locked — build in P2 from day one** |
| Key management | P2 gate | Cloud KMS (AWS KMS) | 🟡 Design at P2 gate |
| Event streaming | P2 gate | Redis Streams at P2, Kafka at P4 only | 🟡 Design at P2 gate |

---

## Appendix B — P1–P4 Architecture Maturity Summary

> **CHG-0234:** P3 column below now represents the **P3 commercial tier within P2** (company/multi-agent feature unlock). It is NOT a separate build phase. Customer-Deployed / Licensed Product rows are obsolete.

| Dimension | P1 | P2 (Standard tier) | P3 Commercial Tier (within P2) | P4 |
|-----------|----|----|----|----|  
| Memory tiers active | T1 (implicit), T3 (to build), T5 (partial) | All 5 tiers | All 5 tiers + shared org-level T5 coordination | All 5 tiers + event sourcing |
| Data classification | Manual, ad-hoc | Enforced on all writes (tenant-scoped) | Enforced + org-level classification rules | Mandatory, audited |
| Encryption at rest | FileVault only | Postgres encrypted (AES-256), RLS enforced | Same as P2 — no additional infra | AES-256 mandatory, audited |
| Audit log | Building | Per-tenant, exportable | Org-wide audit aggregation view | WORM, 7-year retention, hash-verified |
| RAG pipeline | Building | Full multi-tenant | Shared org knowledge base layer (feature flag) | PII-hardened, quality-gated |
| APRA compliance | Foundation controls | Partial (SME SaaS) | Same as P2 | Full CPG 234/235 + Privacy Act |
| Residency | All local | AU region cloud | AU region cloud (same infra as P2) | Australian soil mandatory |
| Multi-tenant foundation | Placeholder (tenant_id = 'ainchors') | **Built day one:** tenant_id, RLS, optimistic locking, access control matrix, SSO/SAML hooks | Feature flags enabled on P2 foundation | Dedicated infra per FSI engagement |

---

*Document status: DRAFT FOR REVIEW*
*TKT-0104 | Atlas 🏛️ Enterprise Architect | AInchors*
*2026-05-08*
