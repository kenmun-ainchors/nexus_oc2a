# Context Handoff: Phase 4 Data & Memory Architecture
## Agentic AI Platform - FSI Enterprise Build

**Date:** 1 May 2026
**Prepared by:** Ken Mun (kenmun@gmail.com)
**Purpose:** Dedicated project and chat context for designing and implementing the Data and Memory Architecture strategy for the agentic AI platform being built for an AI training and consultancy startup, with a deliberate focus on enterprise-grade, FSI-regulated deployment readiness.

---

## Who I Am

Ken Mun (Sui Kuen Mun), senior technology executive, Melbourne VIC. Malaysian citizen, full Australian work rights.

**Background:** 25+ years across FSI (AIA Australia, AIA Berhad Malaysia), telecommunications (Celcom Axiata, Maxis Berhad) and manufacturing (USG Boral). Engineering and architecture foundation - co-founded Digital Commerce (M) Sdn Bhd as Head of Technical Engineering, built .NET, C#, ColdFusion and JavaScript applications ground-up. Most recently Head of DevOps, QA & SRE at AIA Australia (departed April 2026).

**Current state:** In active career transition targeting CIO/CTO by 2028-2029. Running three parallel tracks:
- Track 1 (Learning): MIT Sloan AI: Implications for Business Strategy completing May 2026; 17 LinkedIn Learning AI certifications completed
- Track 2 (Building): Agentic AI platform described below
- Track 3 (Job Search): Director-level corporate roles, July 2026 target start

**Why this matters for the platform:** The platform serves dual purpose - applied learning to close the AI delivery gap, and a portfolio credential for the job search. Phase 4 specifically targets closing the data domain knowledge gap identified during the job search - Ken can govern data strategy broadly but lacks hands-on depth in data platform technology, concepts and implementation.

---

## Current Platform State (as of May 2026)

**Platform name:** Not disclosed publicly (pro bono applied project for an AI training and consultancy startup)

**Stack:**
- Orchestration: OpenClaw
- Primary LLM: Claude Sonnet 4.6 (reasoning, complex decisions)
- Secondary LLM: Claude Haiku 4.5 (bounded, repetitive tasks)
- Local LLM: Gemma4 via Ollama (background batch, privacy-sensitive tasks)
- Explored: Qwen

**Current agent architecture (6 live agents):**
- 2 Lead Agents (operational orchestration)
- 4 Governance Agents: Security, Legal, QA, Compliance/Model

**Operational stats:**
- 52 production scripts deployed
- 20+ automated cron jobs
- 8 enterprise operational frameworks established (Agile, ITIL/ITSM, Governance, TOM, Model Strategy, Knowledge Management, Cost Management, Business ROI)
- All frameworks tracked at L2-L4 maturity
- 97.46% platform availability
- 85+ change records
- ~A$25,000-30,000/year projected model cost savings via 3-tier routing vs all-Sonnet baseline

**Model routing strategy (3-tier):**
- Sonnet: reasoning, complex orchestration, high-stakes decisions
- Haiku: bounded tasks, structured outputs, repetitive processing
- Gemma4 local: background batch, privacy-sensitive, cost-sensitive workloads

**ITSM and governance frameworks already in place:**
- P1-P4 incident management
- Change control with 85+ change records
- 9-check post-verification test after every risky operation
- Nightly auto-heal covering 13 automated self-fix checks
- SLO/SLA governance

**What is NOT yet implemented (Phase 4 scope):**
- Vector store / semantic memory layer
- RAG pipeline
- Structured agent event logging with immutable audit trail
- Data classification and PII detection
- Multi-agent shared memory with access control
- Data lineage and traceability
- APRA CPG 234/235 compliance controls

---

## Phase 4 Objective

Design and implement the Data and Memory Architecture for the platform, targeting:

1. **Enterprise-grade data architecture** that can scale from the current startup context to a regulated FSI enterprise deployment
2. **FSI regulatory compliance** aligned to APRA CPG 234 (Information Security) and CPG 235 (Managing Data Risk) and Australian Privacy Act 1988
3. **Closing the data domain knowledge gap** through hands-on implementation of vector databases, RAG pipelines, data governance frameworks and structured audit logging
4. **Portfolio artefacts** that demonstrate data architecture credibility for senior technology leadership roles

---

## The Five-Tier Memory Architecture (Design Framework)

This is the architectural framework to implement across Phase 4. Each tier has distinct storage, governance and compliance requirements.

**Tier 1 - Working Memory (Context Window)**
Active context for the current agent invocation. Managed implicitly by the LLM. Design focus: what goes in, in what order, token budget management, state compression for long workflows.

**Tier 2 - Short-Term / Session Memory**
State persisting within a workflow run, not beyond. Conversation history, intermediate reasoning, tool call results. Storage: Redis or session-scoped Postgres tables. Fast, ephemeral.

**Tier 3 - Long-Term Episodic Memory**
Timestamped immutable record of all agent actions, decisions, tool calls, inputs and outputs. The audit and compliance layer. Storage: Postgres with append-only design and hash-based tamper evidence.

**Tier 4 - Long-Term Semantic Memory**
The agent knowledge base - documents, policies, regulatory rules, reference data, retrievable on demand. Storage: vector database (pgvector recommended for FSI - familiar SQL interface, no new infrastructure, encryption via Postgres). Engine: RAG pipeline.

**Tier 5 - Shared Multi-Agent Memory**
State readable and writable across the 6-agent hierarchy. Requires concurrency management, access control per agent role, and consistency guarantees. Critical design decision: event sourcing vs optimistic locking vs pessimistic locking.

---

## Key Design Decisions to Work Through

### Decision 1: Vector Store Selection
Options:
- **pgvector** (Postgres extension) - recommended for FSI: familiar SQL, no new infrastructure, encryption via existing Postgres config, ACID compliance, audit-friendly
- **Chroma** - lightweight, local-first, good for development, less enterprise-hardened
- **Qdrant** - high performance, more configuration overhead
- **Weaviate** - feature-rich, cloud-native, more complex

Recommended starting point: pgvector. Fits the FSI constraint of minimising infrastructure surface area and maximising auditability.

### Decision 2: Embedding Model Selection
- **nomic-embed-text** via Ollama - local, private, no data leaves the environment, good for FSI PII sensitivity
- **text-embedding-3-small** (OpenAI) - high quality, cloud API, data residency consideration for FSI
- **mxbai-embed-large** via Ollama - strong performance, local
- **claude embeddings** - not yet available via Anthropic API (check current availability)

Recommended: nomic-embed-text via Ollama for development and privacy-sensitive content; text-embedding-3-small for general knowledge base content where data residency is acceptable.

### Decision 3: Chunking Strategy
- Chunk size: 400-600 tokens with 10-20% overlap is the standard starting point
- Chunking method: recursive character text splitter (respects document structure) vs semantic chunking (splits on meaning boundaries, more expensive)
- Metadata per chunk: source document, page/section, created date, expiry date, classification level, author

### Decision 4: Concurrency Model for Shared Memory
- **Optimistic locking**: agent reads state, checks version, writes only if version unchanged. Simple, performant, occasional conflict retry needed.
- **Pessimistic locking**: agent acquires exclusive lock before writing. Safe, can create bottlenecks in high-concurrency scenarios.
- **Event sourcing**: all writes are immutable events, state is derived by replaying event log. Most auditable, most complex, best for FSI.

Recommended: Start with optimistic locking, design the schema to support event sourcing migration.

### Decision 5: Data Residency
All data processed by the platform must be assessed for residency compliance if deploying for an Australian FSI entity. Gemma4 via Ollama is fully local - no residency risk. Claude via Anthropic API - verify Australian data processing location in Anthropic's data processing agreements. This affects model selection for PII-adjacent workloads.

---

## Database Schema Design (Starting Point)

### Core Audit Tables (Tier 3 - Episodic Memory)

```sql
-- Immutable agent event log
CREATE TABLE agent_events (
    event_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id        VARCHAR(100) NOT NULL,
    session_id      UUID NOT NULL,
    correlation_id  UUID,  -- links related events across agents
    event_type      VARCHAR(50) NOT NULL,
    -- values: TOOL_CALL | DECISION | MEMORY_READ | MEMORY_WRITE
    --         | ESCALATION | PII_DETECTED | COMPLIANCE_FLAG | ERROR
    event_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    input_hash      CHAR(64),   -- SHA-256 of input payload
    output_hash     CHAR(64),   -- SHA-256 of output payload
    model_used      VARCHAR(100),
    tokens_input    INTEGER,
    tokens_output   INTEGER,
    cost_usd        DECIMAL(10,6),
    pii_detected    BOOLEAN DEFAULT FALSE,
    classification  VARCHAR(20) DEFAULT 'INTERNAL',
    -- values: PUBLIC | INTERNAL | CONFIDENTIAL | RESTRICTED
    compliance_flags JSONB DEFAULT '[]',
    metadata        JSONB DEFAULT '{}'
);

-- Append-only: no updates or deletes permitted
-- Implement via row-level security or application-level enforcement

-- Agent decisions with reasoning
CREATE TABLE agent_decisions (
    decision_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id            UUID REFERENCES agent_events(event_id),
    agent_id            VARCHAR(100) NOT NULL,
    decision_type       VARCHAR(100) NOT NULL,
    reasoning_summary   TEXT,  -- not full chain of thought
    outcome             TEXT NOT NULL,
    confidence_score    DECIMAL(5,4),
    human_review_required BOOLEAN DEFAULT FALSE,
    reviewed_by         VARCHAR(200),
    reviewed_at         TIMESTAMPTZ,
    review_outcome      VARCHAR(50),
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Data lineage: links decisions to source data
CREATE TABLE decision_lineage (
    lineage_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    decision_id     UUID REFERENCES agent_decisions(decision_id),
    source_type     VARCHAR(50),  -- VECTOR_CHUNK | SHARED_MEMORY | TOOL_OUTPUT | EXTERNAL_API
    source_id       VARCHAR(500),
    source_document VARCHAR(500),
    retrieval_score DECIMAL(6,4),  -- similarity score if from vector store
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Memory access log
CREATE TABLE memory_access_log (
    access_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id        VARCHAR(100) NOT NULL,
    session_id      UUID,
    memory_tier     VARCHAR(20) NOT NULL,
    -- values: SESSION | EPISODIC | SEMANTIC | SHARED
    operation       VARCHAR(10) NOT NULL,
    -- values: READ | WRITE | DELETE
    key_accessed    VARCHAR(500),
    classification  VARCHAR(20),
    access_timestamp TIMESTAMPTZ DEFAULT NOW()
);
```

### Vector Store Tables (Tier 4 - Semantic Memory, using pgvector)

```sql
-- Requires: CREATE EXTENSION vector;

CREATE TABLE knowledge_chunks (
    chunk_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_document VARCHAR(500) NOT NULL,
    source_url      VARCHAR(1000),
    chunk_index     INTEGER NOT NULL,
    chunk_text      TEXT NOT NULL,
    embedding       vector(768),  -- dimension matches your embedding model
    -- nomic-embed-text = 768 dimensions
    -- text-embedding-3-small = 1536 dimensions
    token_count     INTEGER,
    classification  VARCHAR(20) DEFAULT 'INTERNAL',
    pii_present     BOOLEAN DEFAULT FALSE,
    quality_score   DECIMAL(5,4),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    expires_at      TIMESTAMPTZ,  -- data retention compliance
    created_by      VARCHAR(200),
    metadata        JSONB DEFAULT '{}'
);

-- Index for similarity search
CREATE INDEX ON knowledge_chunks
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- Document registry (parent of chunks)
CREATE TABLE knowledge_documents (
    document_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_name   VARCHAR(500) NOT NULL,
    document_type   VARCHAR(100),
    -- values: POLICY | REGULATION | PROCEDURE | REFERENCE | TRAINING
    source_system   VARCHAR(200),
    classification  VARCHAR(20) DEFAULT 'INTERNAL',
    pii_assessed    BOOLEAN DEFAULT FALSE,
    pii_present     BOOLEAN DEFAULT FALSE,
    version         VARCHAR(50),
    effective_date  DATE,
    expiry_date     DATE,
    ingested_at     TIMESTAMPTZ DEFAULT NOW(),
    ingested_by     VARCHAR(200),
    chunk_count     INTEGER,
    quality_score   DECIMAL(5,4),
    metadata        JSONB DEFAULT '{}'
);
```

### Shared Agent State (Tier 5)

```sql
-- Shared state with optimistic locking
CREATE TABLE agent_shared_state (
    state_key       VARCHAR(500) PRIMARY KEY,
    state_value     JSONB NOT NULL,
    version         INTEGER NOT NULL DEFAULT 1,
    owner_agent_id  VARCHAR(100),
    classification  VARCHAR(20) DEFAULT 'INTERNAL',
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_by      VARCHAR(100)
);

-- State history for audit (append-only)
CREATE TABLE agent_state_history (
    history_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    state_key       VARCHAR(500) NOT NULL,
    state_value     JSONB NOT NULL,
    version         INTEGER NOT NULL,
    changed_by      VARCHAR(100),
    change_reason   VARCHAR(500),
    changed_at      TIMESTAMPTZ DEFAULT NOW()
);
```

---

## Multi-Agent Access Control Matrix

Define before implementation. This governs which agent can perform which operations on which memory tier.

| Memory Tier | Lead Agent 1 | Lead Agent 2 | Security Agent | Legal Agent | QA Agent | Compliance Agent |
|---|---|---|---|---|---|---|
| Working Memory | R/W | R/W | R | R | R | R |
| Session State | R/W | R/W | R/W | R | R | R |
| Episodic Log | W | W | R/W | R/W | R/W | R/W |
| Semantic Store | R | R | R | R | R | R |
| Shared State | R/W | R/W | R | R | R | R/W |
| State History | R | R | R/W | R/W | R/W | R/W |

**Principle:** Governance agents (Security, Legal, QA, Compliance) are primarily readers of operational state and writers of audit/compliance records. Lead Agents own operational state. No agent can modify the episodic event log - append only.

---

## APRA Compliance Checklist for Phase 4

### CPG 234 (Information Security)
- [ ] Data classification applied to all stored data (PUBLIC / INTERNAL / CONFIDENTIAL / RESTRICTED)
- [ ] Encryption at rest: AES-256 on all Postgres tables including vector store
- [ ] Encryption in transit: TLS 1.3 minimum for all API calls
- [ ] Access control: least-privilege per agent per memory tier
- [ ] Immutable audit log with tamper evidence (hash fields)
- [ ] Incident response: PII detection triggers automatic escalation to Compliance Agent
- [ ] Vulnerability management: no PII in vector store without governance controls
- [ ] Security agent reviews all WRITE operations to shared state

### CPG 235 (Data Risk Management)
- [ ] Data quality gate on all document ingestion (quality_score threshold before embedding)
- [ ] Source verification: every knowledge document has verified provenance
- [ ] Data retention policy: expires_at field on all knowledge chunks, automated expiry process
- [ ] Data residency assessment: document which models process which data categories
- [ ] Model risk register: document model limitations, known failure modes, human review thresholds
- [ ] Data lineage: every agent decision traceable to source data via decision_lineage table
- [ ] Change management: all schema changes go through existing change control process

### Privacy Act 1988 (Australian Privacy Principles)
- [ ] PII scanner on all document ingestion before chunking and embedding
- [ ] PII-containing documents routed to Gemma4 local only (no external API calls)
- [ ] pii_present flag on knowledge_documents prevents embedding without explicit approval
- [ ] pii_detected flag on agent_events triggers Compliance Agent review
- [ ] Data subject access and deletion capability: chunk-level deletion by document_id

---

## Recommended Tool Stack for Implementation

**Vector Operations:**
- pgvector (Postgres extension) - primary vector store
- LangChain or LlamaIndex - RAG pipeline orchestration (optional, can build custom)

**Embedding:**
- nomic-embed-text via Ollama - local, FSI-safe for sensitive content
- text-embedding-3-small via OpenAI API - general knowledge base

**PII Detection:**
- spaCy with en_core_web_lg model - local, no external API dependency
- Presidio (Microsoft open source) - enterprise-grade PII detection, local deployment

**Document Processing:**
- pypdf / pdfplumber - PDF ingestion
- python-docx - Word document ingestion
- unstructured - general document parsing

**Chunking:**
- LangChain RecursiveCharacterTextSplitter - starting point
- Semantic chunking via embedding similarity - more expensive, better quality

---

## Implementation Sequence

### Month 1: Foundation and Audit
- Design final schema (review and extend what is above)
- Implement agent_events, agent_decisions, decision_lineage, memory_access_log
- Add SHA-256 hashing to all existing agent calls
- Implement data classification tagging
- Define and enforce access control matrix
- Write Data Architecture Decision Record (ADR) document

### Month 2: Semantic Memory and RAG
- Stand up pgvector alongside existing Postgres
- Implement document ingestion pipeline with PII detection
- Implement chunking and embedding pipeline (nomic-embed-text via Ollama)
- Load initial knowledge base: governance frameworks, compliance rules, APRA CPG summaries
- Build retrieval tool callable by governance agents
- Test RAG quality: relevance scoring, retrieval accuracy

### Month 3: Compliance and Lineage
- Implement decision_lineage tracking end-to-end
- Build compliance reporting queries (audit trail, decision traceability)
- Implement data retention and expiry automation
- Write FSI Compliance Assessment document against APRA CPG 234/235
- Write Data Governance Framework document

### Month 4: Hardening and Portfolio
- Encryption audit across all storage layers
- Data residency verification per model and API endpoint
- Load test shared state concurrency under multi-agent parallel execution
- Self-assessment against Privacy Act APPs
- Produce final portfolio artefacts (see below)

---

## Portfolio Artefacts to Produce

By end of Phase 4, the following documents should exist as portfolio pieces:

1. **Enterprise Data & Memory Architecture** - the architecture document for the platform covering all five memory tiers, design decisions and rationale
2. **AI Data Governance Framework** - responsible AI, PII policy, data classification, lineage, retention
3. **APRA CPG 234/235 Compliance Assessment** - gap analysis and mitigations for the platform
4. **Multi-Agent Access Control Policy** - who can read and write what and why
5. **Data Architecture Decision Records (ADRs)** - documented decisions with context and consequences
6. **RAG Pipeline Design Document** - ingestion, chunking, embedding, retrieval, quality controls

These are produced from a live production system, not theoretical exercises. That is the differentiating credential.

---

## Credential Pathway (Parallel to Platform Build)

### After MIT Sloan completes (late May 2026) - Priority 1
**dbt Fundamentals** (free, dbt Labs, 4-6 hours)
Teaches data transformation, models, tests, documentation and lineage in the language data engineers use. Directly applicable to structuring agent data pipelines. Closes the vocabulary gap fastest.

### June-July 2026 - Priority 2
**Databricks Fundamentals** (free, Databricks Academy)
Covers Delta Lake, data lakehouse architecture and basic ML concepts. Most common enterprise data platform in Australian FSI. Conceptual understanding closes a major interview vocabulary gap.

### As capacity allows - Priority 3
**Google Professional Data Engineer** or **AWS Data Analytics Specialty**
Formal credential covering pipeline design, storage systems, data processing and ML integration. 3-4 months at moderate intensity. Most transferable formal data engineering credential from a technology leadership background.

---

## The Core Insight to Keep in Mind

The goal is not to become a data engineer. The goal is to become a technology leader who understands data architecture at the level required to govern a data function: ask the right questions, evaluate architecture proposals, make sound investment decisions, and hold data specialists accountable.

Phase 4 - built deliberately with FSI regulatory requirements as the design constraint - closes that gap faster and more credibly than any course alone. A live production system with APRA-aligned governance, vector store implementation, RAG pipeline and immutable audit logging is a stronger credential than a certification from someone who has never shipped it.

Build it right. Document it thoroughly. Use it in interviews.

---

*Handoff prepared: 1 May 2026*
*Next chat context: Dedicated project for Phase 4 Data & Memory Architecture implementation*
