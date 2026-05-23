# Postgres-as-Master SSOT: Enterprise Architecture Assessment
**Document:** EA_SSOT_PostgresMaster_v1.0_2026-05-23
**Author:** Atlas 🏛️ (Enterprise Architect)
**Directive:** Ken Mun (CTO) — Postgres Full Activation as Platform Master Repo & SSOT
**Ticket:** TKT-0253
**Status:** DRAFT FOR REVIEW
**Sprint:** 5 (2026-05-25 onward)

---

## 1. Executive Summary

**The file-based state system has served P1 but is structurally incapable of supporting P2 multi-tenancy, cross-agent query, or guaranteed consistency.** The fragmented ecosystem of 402 files (194 JSON, 51 Markdown, 90+ backup artifacts, 38 logs, 2 SQLite DBs) across `state/` (36MB) and 78 memory files across `memory/` (2MB) cannot provide cross-domain query, audit trail integrity, or conflict resolution at the level required for client-facing operations.

PostgreSQL 16.14 with pgvector 0.8.2 is deployed on OC1 with the 5-tier schema. TKT-0198 migrated the first 5 JSON state files. **Now we must complete the job** — classifying all remaining data assets, consolidating where beneficial, migrating in priority order, and wiring all agents to Postgres as their authoritative read/write path.

**This assessment provides the enterprise architecture blueprint for that transformation.**

---

## 2. Complete Data Asset Inventory & Classification

### 2.1 Classification Framework

| Tier | Definition | Access Latency | Consistency | Example |
|------|-----------|----------------|-------------|---------|
| **Tier 0** | Must-have-realtime — agents read/write every session | <10ms | Strong (transactional) | Tickets, Config, Agent State |
| **Tier 1** | Operational — read/write daily or per-task | <50ms | Strong (eventual ok for reads) | Task Queue, Model Policy, Cost State |
| **Tier 2** | Reference — read-frequent, write-occasional | <100ms | Eventual | Benchmarks, Policies, Sprint Plans |
| **Tier 3** | Archive — infrequent access, compliance retention | Any | Immutable | Old auto-heal logs, old backups, retired tickets |

| Migration Priority | Meaning |
|--------------------|---------|
| **P0** | Immediate — Sprint 5, Week 1-2. Agents cannot function without SSOT. |
| **P1** | Phase 1 — Sprint 5, Week 3-4. Required for P2 readiness. |
| **P2** | Phase 2 — Sprint 6+. Nice-to-have, or deferred awaiting maturity. |
| **P3** | Archive / not worth migrating. Keep as files or delete. |

| Domain | Scope |
|--------|-------|
| **Operations** | Agent execution, task routing, health, heartbeats |
| **Governance** | Tickets, changes, policies, DoD validation, rules |
| **Agent State** | Per-agent memory, session context, shared knowledge |
| **Business** | LinkedIn, content, marketing, ROI, budgets |
| **Knowledge** | Document registry, embeddings, lessons, frameworks |

---

### 2.2 Tier 0 — Must-Have-Realtime (P0 Migration Priority)

These are the files every agent touches. They must be in Postgres with strong consistency guarantees.

| # | File | Domain | Format | Current Size | Postgres Destination | Notes |
|---|------|--------|--------|-------------|---------------------|-------|
| 1 | `tickets.json` | Governance | JSON | ~850KB | `state_tickets` ✅ (migrated TKT-0198) | 251 tickets, 250 changes. Core platform asset. |
| 2 | `cost-state.json` | Operations | JSON | ~8KB | `state_cost` ✅ (migrated TKT-0198) | API balance, spend tracking, top-up history. |
| 3 | `model-policy.json` | Governance | JSON | ~12KB | `state_model_policy` ✅ (migrated TKT-0198) | Model routing, tier assignments, interim periods. |
| 4 | `task-queue.json` | Operations | JSON | ~5KB | `state_task_queue` ✅ (migrated TKT-0198) | Async task dispatch. Postgres backend pending. |
| 5 | `critical-config-baseline.json` | Governance | JSON | ~8KB | `state_config_baseline` ✅ (migrated TKT-0198) | Auto-heal drift detection baseline. |
| 6 | `agent-status.json` | Operations | JSON | ~3KB | `agent_sessions` (extend) | Agent health, last-run timestamps. Merge into sessions table. |
| 7 | `chg-registry.json` | Governance | JSON | ~15KB | `state_changes` (NEW table) | Change management registry. 250+ changes currently embedded in tickets JSON. |
| 8 | `task-queue-dispatch.json` | Operations | JSON | ~2KB | merge → `state_task_queue` | Task dispatch state. Consolidate into single task_queue table. |
| 9 | `heartbeat-state.json` | Operations | JSON | ~2KB | `agent_shared_state` | Heartbeat check tracking. Key-value pattern fits shared state table. |
| 10 | `policy-register.json` | Governance | JSON | ~10KB | `state_policies` (NEW table) | POL-001 through POL-012. Formal numbered policies. |

**Schema Approach for Tier 0:** Relational-first with JSONB for nested/optional fields. These are your system-of-record tables. Strong typing for columns that are queried/filtered; JSONB for flexible payloads. Every table gets `tenant_id`, `created_at`, `updated_at`, `updated_by`.

---

### 2.3 Tier 1 — Operational (P1 Migration Priority)

These files are accessed regularly but not every session. Eventual consistency acceptable for read replicas.

| # | File | Domain | Format | Postgres Destination | Consolidation |
|---|------|--------|--------|---------------------|---------------|
| 1 | `agent-budgets.json` | Business | JSON | `state_agent_budgets` (NEW) | Standalone. Agent-level cost caps. |
| 2 | `backlog-state.json` | Governance | JSON | `state_backlog` (NEW) | Standalone. Sprint backlog management. |
| 3 | `ci-agent-state.json` | Operations | JSON | `state_ci` (NEW unified) | Merge with `ci-agent-metrics.json`, `ci-register.json`, `ci-cycle-b-active.json`. |
| 4 | `ci-agent-metrics.json` | Operations | JSON | merge → `state_ci` | Consolidate all CI agent artifacts. |
| 5 | `ci-register.json` | Governance | JSON | merge → `state_ci` | CI cycle register. |
| 6 | `ci-cycle-b-active.json` | Operations | JSON | merge → `state_ci` | Active CI cycle. |
| 7 | `content-queue.json` | Business | JSON | `state_content_queue` (NEW) | Standalone. Content publishing pipeline. |
| 8 | `cron-health-state.json` | Operations | JSON | `agent_shared_state` | Key-value. Fits shared state pattern. |
| 9 | `delegation-log.json` | Operations | JSON | `agent_decisions` (extend) | Merge into existing decisions table with type='delegation'. |
| 10 | `drive-sync-state.json` | Operations | JSON | `state_drive_sync` (NEW) | Google Drive sync tracker. |
| 11 | `framework-registry.json` | Governance | JSON | `state_frameworks` (NEW) | Framework audit trail. |
| 12 | `health-state.json` | Operations | JSON | `agent_shared_state` | Health check state. Key-value. |
| 13 | `incident-log.json` | Operations | JSON | `state_incidents` (NEW) | Merge with `state/incidents/INC-*.json`. |
| 14 | `latency-tracker-state.json` | Operations | JSON | `state_latency` (NEW) | Model latency tracking. |
| 15 | `linkedin-queue.json` | Business | JSON | `state_linkedin` (NEW unified) | Merge with `linkedin-metrics.json`, `linkedin-campaign.json`, `linkedin-content-tracker.json`. |
| 16 | `linkedin-metrics.json` | Business | JSON | merge → `state_linkedin` | LinkedIn analytics. |
| 17 | `linkedin-campaign.json` | Business | JSON | merge → `state_linkedin` | Campaign state. |
| 18 | `linkedin-content-tracker.json` | Business | JSON | merge → `state_linkedin` | Content publishing tracker. |
| 19 | `notion-audit-report.json` | Governance | JSON | `state_notion_sync` (NEW unified) | Merge with all notion-*.json files. |
| 20 | `obs-collector-state.json` | Operations | JSON | `state_obs` (NEW unified) | Merge with `obs-trend.json`. |
| 21 | `roi-tracker.json` | Business | JSON | `state_roi` (NEW) | ROI tracking. |
| 22 | `rule-violations.json` | Governance | JSON | `state_rule_violations` (NEW) | Platform rule engine violations. |
| 23 | `sprint-current.json` | Governance | JSON | `state_sprints` (NEW unified) | Merge with `sprint-next.json`, `sprint-4-*.json`. |
| 24 | `standup-state.json` | Operations | JSON | `state_standups` (NEW) | Merge with all `standup-data-*.json`. |
| 25 | `yoda-relay-queue.json` | Operations | JSON | `state_relay_queue` (NEW) | Message relay queue. |
| 26 | `open-decisions.json` | Governance | JSON | `agent_decisions` (extend) | Merge into decisions table with status='open'. |
| 27 | `research-registry.json` | Knowledge | JSON | `state_research` (NEW) | Research task registry. |
| 28 | `skill-registry.json` | Governance | JSON | `state_skills` (NEW) | Agent skill registry. |

---

### 2.4 Tier 2 — Reference (P2 Migration Priority)

Infrequently modified, but valuable for cross-agent query. Migrate when Tier 0/1 complete.

| # | Category | Files | Count | Domain | Consolidation |
|---|----------|-------|-------|--------|---------------|
| 1 | **Auto-heal logs (JSON)** | `auto-heal-2026-04-27.json` through `auto-heal-2026-05-21.json` | 26 files | Operations | `state_autoheal_log` — single table, date-partitioned. |
| 2 | **Standup data** | `standup-data-2026-05-09.json` through `standup-data-2026-05-13.json` | 5 files | Operations | Merge → `state_standups`. |
| 3 | **Sprint planning** | `sprint-4-commitment.json`, `sprint-4-planning-notes.json`, `sprint-4-unified-scope.json` | 3 files | Governance | Merge → `state_sprints`. |
| 4 | **Sprint outputs (MD)** | `tkt-0085-sprint-output.md`, `tkt-0086-*.md`, `tkt-0087-groom.md`, `tkt-0089-backlog-replan.md`, `tkt-0092-output.md`, `tkt-0093-output.md` | 8 files | Governance | `state_ticket_deliverables` — link to ticket_id. |
| 5 | **CI reports (MD)** | `ci-cycle-1A-report.md`, `ci-cycle-2A-report.md` | 2 files | Operations | Merge → `state_ci`. |
| 6 | **Atlas assessments** | `atlas-tkt-0046-summary.json`, `atlas-tkt-0103-summary.json`, `atlas-tkt-0104-summary.json`, `atlas-tkt-0124-assessment.md`, `atlas-tkt-0135-*.md`, `atlas-p3-amendment-summary.json`, `atlas-cli-anything-assessment.md`, `atlas-access-ea-v1.md` | 9 files | Knowledge | `knowledge_documents` (vectorize) or `state_assessments`. |
| 7 | **Notion sync audit** | `notion-audit.json`, `notion-chg-verification.json`, `notion-created-date-fix.json`, `notion-delivered-date-fix.json`, `notion-false-done-report.json`, `notion-missing-chg.json`, `notion-missing-tickets.json` | 7 files | Governance | Merge → `state_notion_sync`. |
| 8 | **Diagnostics** | `diagnostics-2026-04-27-0715.json`, `diagnostics-2026-04-27-0719.json`, `diagnostics-2026-04-27-2206.json`, `diagnostics-2026-04-28-1431.json` | 4 files | Operations | `state_diagnostics` — date-partitioned. |
| 9 | **Skill audits** | `skill-audit-report-2026-05-15.json`, `skill-audit-report-2026-05-17.json`, `skill-audit-state.json`, `cron-skill-audit.json` | 4 files | Governance | Merge → `state_skills`. |
| 10 | **Cost investigations** | `cost-investigation-2026-05-14.json`, `cost-forecast-2026-05-15.json`, `p1-cost-forecast-2026-05-15.json`, `api-cost-actuals.json`, `cost-alert-state.json`, `budget-alert-state.json` | 6 files | Business | Merge → `state_cost` (existing). |
| 11 | **Model trials** | `gemma4-rtb-trial.json`, `gemma4-shadow.json`, `kimi-rtb-trial.json`, `kimi-confidence-mapping.json`, `interim-model-period.json`, `model-drift-state.json`, `model-drift-violations.json`, `fallback-chain-status.json` | 8 files | Operations | `state_model_trials` — unified model performance table. |
| 12 | **Business/ROI** | `business-roi.json` | 1 file | Business | Merge → `state_roi`. |
| 13 | **Channel state** | `channel-state.json` | 1 file | Operations | `agent_shared_state`. |
| 14 | **Daily notes** | `daily-note.json` | 1 file | Operations | `agent_shared_state`. |
| 15 | **Uptime log** | `uptime-log.json` | 1 file | Operations | `state_uptime` (NEW). |
| 16 | **Architecture KRI** | `architecture-kri-state.json` | 1 file | Governance | `state_kri` (NEW). |

---

### 2.5 Memory Files — The Knowledge Domain

The 78 memory files in `memory/` represent a different data category — they are **narrative, contextual, and agent-specific**. They bridge the gap between structured state and unstructured knowledge.

| Category | Files | Count | Format | Migration Strategy |
|----------|-------|-------|--------|-------------------|
| **Daily logs** | `2026-04-25.md` through `2026-05-22.md`, `journal-*.md` | ~56 files | Markdown | **Tier 2 → `knowledge_documents` with vector embeddings.** Each daily entry becomes a knowledge chunk. Full-text searchable. Original MD retained as archive. |
| **Shared memory** | `memory/shared/*.md` (company, projects, decisions, integrations, notion, sla-history, cost-history, research-framework) | 8 files | Markdown | **Tier 1 → `knowledge_documents`.** These are living reference docs. Update via Postgres, regenerate MD cache. |
| **Agent memory** | `memory/agents/*.md` (content, dev, infra, legal, marketing, qa, report, research, security, social, support) | 11 files | Markdown | **Tier 2 → `knowledge_documents` with agent_id filter.** Each agent's memory is a named knowledge partition. |
| **Lessons learned** | `LESSONS.md` | 1 file | Markdown | **Tier 1 → `knowledge_documents` + `state_lessons` (NEW).** Structured lessons table with category, severity, date. |
| **Changelog** | `CHANGELOG.md` | 1 file | Markdown | **Tier 1 → `state_changes` table.** Already tracked in tickets JSON. Formalize as relational. |
| **Memory archive** | `MEMORY-archive-*.md` | 2 files | Markdown | **Tier 3.** Archive. Keep as files; vectorize if needed for historical RAG. |
| **Dreams** | `memory/.dreams/*.jsonl`, `short-term-recall.json` | 2 files | JSON/JSONL | **Tier 2 → `knowledge_documents`.** Agent introspection data. |
| **Journal temp** | `.journal-tmp.json` | 1 file | JSON | **Tier 1 → `agent_shared_state`.** Temporary journal write state. |

**Key Principle:** Memory files are narrative. They should be **vectorized into the knowledge tier** (Tier 2 tables: `knowledge_documents` + `knowledge_chunks`) for semantic search, while the **raw MD files remain as the authoritative archive**. This gives us the best of both worlds: SQL query for metadata + vector search for content.

---

### 2.6 Workspace Config Files — What Stays as Files

These are configuration documents that define agent identity and behavior. They should remain as files but be **registered** in Postgres with a file hash for drift detection.

| File | Purpose | Postgres Treatment |
|------|---------|-------------------|
| `AGENTS.md` | Workspace discipline rules | Register in `state_config_files` with SHA-256 hash. |
| `SOUL.md` | Agent persona/tone | Register in `state_config_files`. |
| `MEMORY.md` | Long-term curated memory (Yoda) | **Vectorize into knowledge_documents.** Most critical narrative file. |
| `RULES.md` | Platform rules | Register in `state_config_files`. |
| `YODA_RULES.md` | Yoda-specific rules | Register in `state_config_files`. |
| `YODA_RUNBOOK.md` | Operational runbook | Register in `state_config_files` + vectorize for RAG. |
| `HEARTBEAT.md` | Heartbeat checklist | Register in `state_config_files`. |
| `IDENTITY.md` | Agent identity | Register in `state_config_files`. |
| `USER.md` | Human context | Register in `state_config_files`. |
| `TOOLS.md` | Tool notes | Register in `state_config_files`. |
| `AGENT_ARCHITECTURE.md` | Agent roster | Register in `state_config_files` + vectorize for RAG. |
| `SHARED_CONTEXT.md` | Shared business context | **Vectorize into knowledge_documents.** |
| `INFRA_RULES.md` | Infrastructure rules | Register in `state_config_files`. |
| `MEMORY_DECISIONS.md` | Decision log | Merge into `state_changes` / `agent_decisions`. |
| `MEMORY_TICKETS.md` | Ticket-related memory | Merge into `state_tickets` as notes. |
| `CHANGELOG.md` (root) | Changelog | Merge into `state_changes`. |
| `OllamaCloud_PoC.md` | PoC report | Register in `state_config_files`. |
| `YODA_OC1_OC2_OPERATIONAL_BRIEF.md` | Infra brief | Register in `state_config_files` + vectorize. |
| `context-for-aria.md` (root) | Agent context | Merge into `agent_sessions` context field. |

---

### 2.7 Archive-Only (P3 — Not Worth Migrating)

| Category | Count | Rationale |
|----------|-------|-----------|
| `tickets.json.bak*` | 90+ files | Backup artifacts. Keep 7 days, then `trash`. |
| `auto-heal-*.log` | 38 files | Text logs. Aggregate into `state_autoheal_log` if needed for pattern analysis, otherwise archive. |
| `diagnostics-*.log` | 8 files | Diagnostic logs. Keep 30 days, archive. |
| `skill-audit-cron.log` | 1 file | Single cron log. Archive. |
| `*.txt` files in state/ | ~18 files | Pre-upgrade notes, test actions. Archive or delete. |
| `obs.db`, `tasks.db` | 2 SQLite DBs | Legacy. Migrate data to Postgres, archive DB file. |
| `generated-images/` | 5 files | Binary assets. Stay in MinIO, not Postgres. |
| `benchmark/` | 4 files | Model benchmarks. Tier 3 → keep as files, register metadata in Postgres. |
| `phase5-results/` | 12 files | Model trial outputs. Archive. |
| `checkpoints/` | 4 files | Task checkpoints. Archive. |
| `pir/` | 2 files | PIR records. Archive. |
| `owl-archive/` | 1 file | OWL compliance archive. Archive. |

---

## 3. Consolidation Strategy

### 3.1 Consolidation Principles

1. **Merge by domain, not by format.** Two JSON files about LinkedIn belong in one table, regardless of their current filenames.
2. **One table per business entity.** Tickets, Changes, Policies, Agents, Sprints — each gets its own well-designed table.
3. **JSONB for flexibility, columns for queryability.** Any field that will be WHERE-filtered or JOINed must be a column. Flexible payloads go in JSONB.
4. **No duplication across tables.** If ticket status is in `state_tickets`, it must not also be independently stored in `agent_shared_state` or a config file.
5. **Version column on every mutable table.** Optimistic locking (`version INT`) prevents silent overwrites.
6. **Every write is audited.** `agent_events` captures who changed what, when. `agent_state_history` captures the before/after.

### 3.2 Unified Schema Design for the SSOT

Based on the 10 core data types from TKT-0197 (Tickets, Changes, Decisions, Sessions, Config, Tasks, Knowledge, Memory, Policies, Metrics), here is the target schema:

```
┌─────────────────────────────────────────────────────────────┐
│                    NEXUS SSOT SCHEMA                         │
│                 (tenant-scoped: 'ainchors' in P1)            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  TIER 1 — AUDIT (immutable, append-only)                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ agent_events         — who did what, when             │   │
│  │ agent_decisions      — agent_id, context, rationale   │   │
│  │ decision_lineage     — parent→child decision chain    │   │
│  │ memory_access_log    — who accessed what knowledge    │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  TIER 2 — VECTOR / KNOWLEDGE                                │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ knowledge_documents  — title, source, type, metadata  │   │
│  │ knowledge_chunks     — content, embedding(768), doc_id│   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  TIER 3 — SESSIONS                                          │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ agent_sessions       — session_id, agent_id, context  │   │
│  │   EXTEND: agent_status (heartbeat, health, uptime)    │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  TIER 4 — SHARED STATE (key-value, optimistic locking)      │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ agent_shared_state   — key, value(JSONB), version     │   │
│  │   Used for: heartbeat-state, channel-state,           │   │
│  │   health-state, cron-health-state, daily-note,        │   │
│  │   journal-write-state, akb-sync-state,                │   │
│  │   drive-sync-state, backup-state, etc.                │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  TIER 5 — HISTORY (append-only state mutations)             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ agent_state_history  — key, old_value, new_value,     │   │
│  │                        changed_by, changed_at         │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  SSOT TABLES (Tier 0/1 — System of Record)                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ state_tickets       — id, title, status, type, ...    │   │
│  │ state_changes       — id, title, status, type, ...    │   │
│  │ state_cost          — balance, history[], alerts[]    │   │
│  │ state_model_policy  — model routing, tiers, interim   │   │
│  │ state_task_queue    — task_id, status, payload        │   │
│  │ state_config_baseline — check_key, expected_value     │   │
│  │ state_policies      — pol_id, title, domain, status   │   │
│  │ state_incidents     — inc_id, severity, status        │   │
│  │ state_lessons       — id, category, severity, lesson  │   │
│  │ state_sprints       — sprint_id, commitments, status  │   │
│  │ state_standups      — date, agent_id, content         │   │
│  │ state_ci            — cycle_id, metrics, status       │   │
│  │ state_research      — task_id, query, findings        │   │
│  │ state_skills        — skill_id, agent, status         │   │
│  │ state_frameworks    — category, file_path, hash       │   │
│  │ state_linkedin      — queue, metrics, campaigns       │   │
│  │ state_content_queue — content pipeline                │   │
│  │ state_notion_sync   — sync log, gap reports           │   │
│  │ state_drive_sync    — Google Drive sync state         │   │
│  │ state_autoheal_log  — date, check, result             │   │
│  │ state_diagnostics   — timestamp, component, data      │   │
│  │ state_roi           — metric, value, timestamp        │   │
│  │ state_latency       — model, endpoint, latency_ms     │   │
│  │ state_model_trials  — model, trial_type, results      │   │
│  │ state_uptime        — service, status, timestamp      │   │
│  │ state_kri           — kri_id, value, threshold        │   │
│  │ state_config_files  — path, hash, last_checked        │   │
│  │ state_relay_queue   — message_id, target, status      │   │
│  │ state_rule_violations — rule_id, ticket_id, severity  │   │
│  │ state_agent_budgets — agent_id, budget, consumed      │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Total new tables:** ~28 SSOT tables + existing 9 base tables = 37 tables.

**Consolidation wins:**
- LinkedIn: 4 files → 1 table (`state_linkedin`)
- CI/CD: 4 files → 1 table (`state_ci`)
- Notion sync: 7 files → 1 table (`state_notion_sync`)
- Cost/Finance: 6 files → merge into existing `state_cost`
- Standups: 6 files → 1 table (`state_standups`)
- Sprints: 4 files → 1 table (`state_sprints`)
- 25+ key-value state files → single `agent_shared_state` table (already exists)

### 3.3 Normalization Level

| Entity Type | Normalization | Rationale |
|-------------|---------------|-----------|
| Tickets, Changes, Policies, Incidents | **3NF** (fully normalized) | These are relational business entities. Foreign keys to agents, dates, statuses. |
| Cost, Metrics, Logs | **3NF with JSONB detail columns** | Core columns normalized; payload/details in JSONB. |
| Agent State, Config | **Key-Value (agent_shared_state)** | Deliberately denormalized. Optimistic locking. History in agent_state_history. |
| Knowledge | **Document → Chunk (1:N)** | Document metadata normalized; chunk content + embedding stored together. |

### 3.4 Indexing Strategy

| Table | Index Type | Columns | Rationale |
|-------|-----------|---------|-----------|
| All SSOT tables | B-tree | `tenant_id` | Every query filters by tenant. |
| state_tickets | B-tree | `status`, `type`, `created_at` | Most common filters. |
| state_changes | B-tree | `status`, `type`, `created_at` | Same pattern as tickets. |
| agent_events | B-tree | `agent_id`, `created_at DESC` | Agent activity timeline. |
| agent_shared_state | B-tree UNIQUE | `tenant_id`, `key` | Exact key lookup + optimistic locking. |
| knowledge_chunks | IVFFlat/HNSW | `embedding vector_cosine_ops` | Semantic search. Use IVFFlat for <1M chunks, HNSW for larger. |
| state_model_policy | B-tree | `agent_id` | Model routing per agent. |
| state_autoheal_log | B-tree | `date DESC` | Time-series log queries. |
| state_latency | B-tree | `model`, `timestamp DESC` | Model performance over time. |
| state_config_files | B-tree UNIQUE | `file_path` | Config file registry. |

### 3.5 How Memory Files Map into Knowledge Tiers

```
memory/YYYY-MM-DD.md  ──→  knowledge_documents (type='daily_log', date=YYYY-MM-DD)
                              └── knowledge_chunks (content chunks with embeddings)

memory/journal-*.md   ──→  knowledge_documents (type='journal', date=YYYY-MM-DD)
                              └── knowledge_chunks

memory/shared/*.md    ──→  knowledge_documents (type='shared_context', domain=company|projects|...)
                              └── knowledge_chunks

memory/agents/*.md    ──→  knowledge_documents (type='agent_memory', agent_id=content|dev|...)
                              └── knowledge_chunks

memory/LESSONS.md     ──→  state_lessons (structured) + knowledge_documents (full text)
memory/CHANGELOG.md   ──→  state_changes (structured entries)
MEMORY.md             ──→  knowledge_documents (type='orchestrator_memory', agent_id='yoda')
                              └── knowledge_chunks (with embeddings for RAG)
```

**The files remain** as the canonical narrative archive. Postgres becomes the **queryable, searchable, vectorized** representation. Agents query Postgres for knowledge retrieval; they write to Postgres for state changes. The files become a backup/sync target, not the primary read/write path.

---

## 4. Enterprise Integration Architecture

### 4.1 Integration Landscape

```
┌──────────────────────────────────────────────────────────────┐
│                     DATA SOVEREIGNTY MAP                      │
│                                                               │
│  LOCAL (OC1 Mac Mini M4)          │  CLOUD / EXTERNAL         │
│  ─────────────────────────        │  ────────────────         │
│                                    │                          │
│  ┌─────────────────────┐          │  ┌────────────────────┐  │
│  │ PostgreSQL 16.14    │          │  │ Notion (Holocron)   │  │
│  │ (Master SSOT)       │◄────────►│  │ — Ticket DBs A/B/C │  │
│  │ Tier 0/1/2 data     │  sync    │  │ — Knowledge pages   │  │
│  └────────┬────────────┘          │  └────────────────────┘  │
│           │                        │                          │
│           │ metadata               │  ┌────────────────────┐  │
│           ▼                        │  │ Google Drive       │  │
│  ┌─────────────────────┐          │  │ — Docs, Sheets     │  │
│  │ MinIO (self-hosted) │          │  │ — Strategy artefacts│  │
│  │ — Blob storage       │          │  └────────────────────┘  │
│  │ — Generated images   │          │                          │
│  │ — Document binaries  │          │  ┌────────────────────┐  │
│  └─────────────────────┘          │  │ Ollama Cloud       │  │
│                                    │  │ — Model inference   │  │
│  ┌─────────────────────┐          │  │ — No data stored    │  │
│  │ Workspace Files     │          │  └────────────────────┘  │
│  │ — Configs (hash reg)│          │                          │
│  │ — MD memory (archive)│         │  ┌────────────────────┐  │
│  │ — Logs (rotated)    │          │  │ LinkedIn API       │  │
│  └─────────────────────┘          │  │ — Posting + metrics │  │
│                                    │  └────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### 4.2 Postgres ↔ Notion (Holocron) Integration

- **Current:** Notion is the human-facing ticketing interface. Tickets JSON is the bridge.
- **Target:** Postgres is the SSOT. Notion syncs bidirectionally via the Task Queue Processor.
  - Create/Update in Notion → webhook/API poll → Postgres upsert
  - Create/Update in Postgres (via agent) → Notion API → update Holocron page
  - Conflict resolution: Postgres wins. Notion is the presentation layer.
- **Sync frequency:** Real-time for Tier 0 (LISTEN/NOTIFY on ticket changes). Batch every 5 min for Tier 1.

### 4.3 Postgres ↔ MinIO Integration

- **Pattern:** Postgres stores metadata (document registry in `knowledge_documents`). MinIO stores binary blobs.
- **Cross-reference:** `knowledge_documents.object_key` → MinIO object path. Presigned URLs for agent access.
- **Data sovereignty:** Both OC1-local. No cloud dependency for Tier 0/1 storage.

### 4.4 Postgres ↔ Google Drive Integration

- **Current:** `drive-sync-state.json`, `drive-folder-ids.json`, `gdrive-folders.json` track Google Drive content.
- **Target:** `state_drive_sync` table tracks last sync, folder structure, file hashes. Drive remains the document authoring platform. Postgres is the metadata registry.
- **Sync direction:** Google Drive → Postgres (metadata pull). Postgres does not push to Drive.

### 4.5 Multi-Tenant Readiness (P2 Gate)

Every table already has `tenant_id VARCHAR(63) NOT NULL DEFAULT 'ainchors'`. This was designed in from TKT-0195.

**P2 activation checklist:**
1. Add `tenant_id` to `agent_sessions` (currently missing per DataMemory roadmap)
2. Enable Row-Level Security (RLS) on all tables: `CREATE POLICY tenant_isolation ON table_name USING (tenant_id = current_setting('app.tenant_id'))`
3. Add `org_id` to `state_tickets`, `state_changes` for company-level grouping
4. Cross-tenant access architecturally prohibited at schema level
5. Tenant provisioning script creates schema context + sets `app.tenant_id`

**This costs nothing now but saves weeks in P2.** The schema is already parameterized.

### 4.6 OC2 HA Readiness

| Component | P1 (Now) | P2 (OC2 arrives) |
|-----------|----------|------------------|
| **Postgres** | Single instance, Homebrew on OC1. `pg_dump` nightly. | Streaming replication to OC2 standby. `pgbouncer` for connection pooling. |
| **Failover** | Manual. Restore from dump <15 min. | Automated via `repmgr` or Patroni. <30s failover. |
| **Backup** | `pg_dump` + WAL archiving to MinIO. | Continuous WAL shipping to OC2 + MinIO offsite. |
| **Connection** | Direct `psql` / `libpq` from agents. | `pgbouncer` between agents and Postgres. Connection pooling across OC1+OC2. |
| **LISTEN/NOTIFY** | Single-channel event bus on OC1 Postgres. | Replicated channels. OC2 agents receive same notifications. |

---

## 5. Governance & Standards

### 5.1 Naming Conventions

| Object | Convention | Example |
|--------|-----------|---------|
| **SSOT tables** | `state_<entity>` (plural for collections, singular for singletons) | `state_tickets`, `state_model_policy`, `state_linkedin` |
| **Audit tables** | `agent_<entity>` | `agent_events`, `agent_decisions` |
| **Knowledge tables** | `knowledge_<entity>` | `knowledge_documents`, `knowledge_chunks` |
| **Columns** | `snake_case`, no abbreviations except well-known (`id`, `url`) | `created_at`, `tenant_id`, `object_key` |
| **Primary keys** | `<table>_id` or `id` for core entities | `ticket_id`, `change_id` |
| **Foreign keys** | `<referenced_table>_id` | `agent_id` REFERENCES agents, `document_id` REFERENCES knowledge_documents |
| **Indexes** | `idx_<table>_<column(s)>` | `idx_state_tickets_status`, `idx_knowledge_chunks_embedding` |
| **JSONB columns** | `payload`, `metadata`, `details` | Descriptive suffix indicating content type |
| **Timestamps** | `TIMESTAMPTZ`, always UTC | `created_at`, `updated_at`, `deleted_at` (soft delete) |

### 5.2 Access Patterns — Which Agents Read/Write What

| Agent | Reads | Writes | Rationale |
|-------|-------|--------|-----------|
| **Yoda** (Orchestrator) | ALL tables | `agent_sessions`, `agent_events`, `agent_decisions`, `state_tickets`, `state_changes`, `knowledge_documents` | Global orchestrator. Full read access. Writes to orchestration scope. |
| **Forge** (Dev) | `state_tickets`, `state_task_queue`, `knowledge_documents` | `agent_events`, `state_tickets` (code changes), `knowledge_documents` | Development work. |
| **Thrawn** (Architect) | `state_tickets`, `state_changes`, `state_frameworks`, `state_policies` | `agent_decisions`, `knowledge_documents` (architecture docs) | Platform architecture decisions. |
| **Atlas** (Enterprise Arch) | `state_tickets`, `state_policies`, `state_frameworks`, `knowledge_documents` | `state_assessments`, `agent_decisions` | Enterprise-level assessments. |
| **Shield** (Security) | `agent_events`, `state_incidents`, `state_rule_violations` | `state_incidents`, `state_rule_violations`, `agent_decisions` | Security and compliance. |
| **Warden** (Compliance) | `agent_events`, `state_policies`, `state_rule_violations` | `state_rule_violations`, `agent_decisions` | Rule enforcement. |
| **Spark** (Social) | `state_linkedin`, `state_content_queue` | `state_linkedin`, `agent_events` | LinkedIn operations. |
| **Aria** (Marketing) | `state_linkedin`, `state_content_queue`, `state_roi` | `state_content_queue`, `agent_events` | Marketing ops. |
| **Sage** (Content) | `state_content_queue`, `knowledge_documents` | `knowledge_documents`, `agent_events` | Content creation and publishing. |
| **Lex** (Legal) | `state_policies`, `knowledge_documents` | `state_policies`, `agent_decisions` | Policy drafting. |
| **Lando** (PM) | `state_tickets`, `state_changes`, `state_sprints` | `state_sprints`, `state_standups` | Sprint/standup management. |
| **Ahsoka** (Strategy) | `state_tickets`, `knowledge_documents`, `state_research` | `state_research`, `agent_decisions` | Research ops. |
| **Krennic** (Infra) | `state_ci`, `state_uptime`, `state_latency`, `state_diagnostics` | `state_ci`, `state_uptime`, `state_diagnostics` | Infrastructure monitoring. |
| **Mon Mothma** (Support) | `state_tickets`, `knowledge_documents` | `agent_events` | Support ticket handling. |

### 5.3 Audit Trail Requirements

Every state-changing operation MUST produce an audit trail:

```
WRITE operation:
  1. BEGIN transaction
  2. Perform the write (INSERT/UPDATE/DELETE)
  3. INSERT into agent_events (agent_id, event_type, table_name, record_id, action, timestamp)
  4. INSERT into agent_state_history (table_name, record_id, old_value, new_value, changed_by, changed_at)
  5. COMMIT
```

**Immutable audit tables:** `agent_events`, `agent_decisions`, `agent_state_history` are append-only. No UPDATE or DELETE by application code. Retention: indefinite (compliance requirement per TKT-0104 Q6).

**Soft deletes:** All business tables use `deleted_at TIMESTAMPTZ` for soft deletion. Hard deletes require Shield/Warden approval.

### 5.4 Data Retention Policies

| Data Category | Retention | Action |
|---------------|-----------|--------|
| **Audit logs** (agent_events, agent_decisions, agent_state_history) | Indefinite | Never delete. Archive to cold storage at 5 years. |
| **Tickets & Changes** (state_tickets, state_changes) | Indefinite | Soft-delete only. Archive closed tickets >2 years. |
| **Vector embeddings** (knowledge_chunks) | Until re-embedded | Rebuild on embedding model change. |
| **Auto-heal logs** (state_autoheal_log) | 90 days | Partition by month. Drop partitions >90 days. |
| **Diagnostics** (state_diagnostics) | 30 days | Auto-purge via cron. |
| **Latency metrics** (state_latency) | 90 days | Roll up to hourly/daily aggregates. |
| **Standups** (state_standups) | 1 year | Archive >1 year. |
| **Config file hashes** (state_config_files) | Indefinite | Audit trail of configuration changes. |

---

## 6. Operationalization — How Agents Use Postgres as Master

### 6.1 Read/Write Architecture

```
┌──────────────────────────────────────────────────────────────┐
│              AGENT READ/WRITE PATH (Postgres SSOT)            │
│                                                               │
│  Agent (any)                                                  │
│     │                                                         │
│     │  READ ──────────────────────────┐                      │
│     │                                 ▼                      │
│     │              ┌──────────────────────────────┐          │
│     │              │  Tiered Read Strategy:       │          │
│     │              │                              │          │
│     │              │  Tier 0: Direct PG query     │          │
│     │              │  Tier 1: PG query + 30s cache│          │
│     │              │  Tier 2: PG query + 5m cache │          │
│     │              │  Knowledge: pgvector search  │          │
│     │              └──────────────────────────────┘          │
│     │                                                         │
│     │  WRITE ─────────────────────────┐                      │
│     │                                 ▼                      │
│     │              ┌──────────────────────────────┐          │
│     │              │  Write Path (always PG):     │          │
│     │              │  1. BEGIN                    │          │
│     │              │  2. Validate (version check) │          │
│     │              │  3. Write to target table    │          │
│     │              │  4. Write agent_events       │          │
│     │              │  5. Write agent_state_history│          │
│     │              │  6. NOTIFY <channel>         │          │
│     │              │  7. COMMIT                   │          │
│     │              └──────────────────────────────┘          │
│     │                                                         │
│     │  SYNC (background)                                      │
│     │     │                                                   │
│     │     ▼                                                   │
│     │  ┌──────────────────────────────────────┐              │
│     │  │ LISTEN/NOTIFY Event Bus:             │              │
│     │  │ — ticket_updated → Yoda, Lando       │              │
│     │  │ — config_changed → Thrawn, Warden    │              │
│     │  │ — cost_alert → Yoda, Ken             │              │
│     │  │ — task_ready → Task Queue Processor  │              │
│     │  │ — incident_created → Shield, Warden  │              │
│     │  └──────────────────────────────────────┘              │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

### 6.2 Sync Patterns

| Pattern | Use Case | Implementation |
|---------|----------|---------------|
| **LISTEN/NOTIFY** | Tier 0 real-time changes | Postgres native. Agent subscribes to channel. Receives JSON payload with changed record ID. |
| **Polling (30s)** | Tier 1 operational state | Agent queries `WHERE updated_at > last_check`. Lightweight. |
| **Cached Read + Invalidate** | Reference data (model policy) | Agent loads on session start, caches in memory. LISTEN for `config_changed` to invalidate. |
| **pgvector Search** | Knowledge retrieval | Agent calls `knowledge_chunks ORDER BY embedding <=> query_embedding LIMIT 10`. |
| **Transaction with Optimistic Lock** | Shared state writes | `UPDATE ... WHERE version = $expected_version RETURNING version`. Retry on conflict. |

### 6.3 Backward Compatibility During Transition

**Phase 1 — Dual-Write (Sprint 5, Week 1-2):**
- Agents write to BOTH files and Postgres.
- Reads from Postgres; fall back to file if Postgres unavailable.
- `sync-check.sh` compares file state vs Postgres state hourly. Alerts on divergence.

**Phase 2 — Postgres Primary (Sprint 5, Week 3-4):**
- Agents write to Postgres only.
- `sync-out.sh` writes Postgres → files every 5 min (for tools that still read files).
- Files become read-only cache, not source of truth.

**Phase 3 — Postgres Only (Sprint 6):**
- Files are archived. Agents read/write exclusively from Postgres.
- `state/` directory thinned to archive-only files.

**Rollback strategy:**
- `pg_dump` → JSON files is a simple Python script. Can rebuild all state files from Postgres in <2 minutes.
- File-based agents can continue running in parallel during transition.
- If Postgres fails catastrophically, restore from dump + replay file changes since last backup.

### 6.4 How This Eliminates Fragmentation

| Pain Point | Before (Files) | After (Postgres SSOT) |
|------------|---------------|----------------------|
| **Fragmented memory** | 78 files in `memory/`, no cross-file query | Single `knowledge_documents` table. Vector search across ALL agent memory. |
| **Context out of sync** | Agents read stale files. No version tracking. | Optimistic locking + `updated_at`. LISTEN/NOTIFY pushes changes. |
| **No single source of truth** | "Which tickets.json is current?" (90+ .bak files) | One row per ticket in `state_tickets`. One `state_config_baseline` row per check. |
| **JSON corruption** | No transactional writes. File truncation on crash. | Postgres ACID. Rollback on failure. WAL for crash recovery. |
| **Version conflicts** | Two agents write tickets.json simultaneously → data loss | `version` column. Second writer gets conflict error, retries. |
| **Can't query across domains** | `grep` across 200 JSON files | `SELECT ... JOIN ... WHERE` across any table. Cross-domain analytics. |
| **No audit trail** | Who changed ticket status? Unknown. | `agent_events` records every write with agent_id, timestamp, before/after. |
| **Backup fragility** | 90+ `.bak` files, manual rotation | `pg_dump` + WAL archiving. Point-in-time recovery. |

---

## 7. Migration Phased Plan

### Phase 0 — Foundation (Sprint 5, Day 1-2) ✅ Partially Complete
- [x] Postgres 16.14 + pgvector deployed (TKT-0195)
- [x] 5-tier schema deployed (9 base tables)
- [x] tenant_id on all tables
- [x] Top 5 JSON files migrated (TKT-0198)
- [ ] **REMAINING:** Verify schema matches this assessment. Add missing state tables DDL.

### Phase 1 — Tier 0 Completion (Sprint 5, Week 1)
- [ ] `state_changes` table — extract from tickets.json changes array
- [ ] `state_policies` table — from policy-register.json
- [ ] `state_task_queue` — merge task-queue.json + task-queue-dispatch.json
- [ ] Extend `agent_sessions` with agent-status fields
- [ ] Consolidate heartbeat-state.json, health-state.json, channel-state.json into `agent_shared_state`
- [ ] Wire Task Queue Processor to Postgres backend (TKT-0236)
- [ ] Enable LISTEN/NOTIFY for ticket_updated, config_changed, task_ready channels

### Phase 2 — Tier 1 Migration (Sprint 5, Week 2-3)
- [ ] LinkedIn consolidation: 4 files → `state_linkedin`
- [ ] CI consolidation: 4 files → `state_ci`
- [ ] Notion sync consolidation: 7 files → `state_notion_sync`
- [ ] Sprint/Standup tables: `state_sprints`, `state_standups`
- [ ] Framework registry → `state_frameworks`
- [ ] Skill registry → `state_skills`
- [ ] Incident log consolidation → `state_incidents`
- [ ] Lessons learned → `state_lessons`
- [ ] Config file registry → `state_config_files`
- [ ] All remaining key-value state files → `agent_shared_state`

### Phase 3 — Knowledge Tier (Sprint 5, Week 3-4)
- [ ] Vectorize MEMORY.md → `knowledge_documents` + `knowledge_chunks`
- [ ] Vectorize memory/shared/*.md → `knowledge_documents`
- [ ] Vectorize memory/agents/*.md → `knowledge_documents`
- [ ] Register all workspace config files in `state_config_files` with SHA-256 hashes
- [ ] Enable pgvector semantic search across all knowledge
- [ ] SHARED_CONTEXT.md → `knowledge_documents`

### Phase 4 — Agent Wiring (Sprint 6, Week 1-2)
- [ ] Yoda: Postgres-first for all reads/writes
- [ ] All agents: dual-write to file + Postgres
- [ ] `sync-check.sh`: hourly file-vs-Postgres divergence detection
- [ ] LISTEN/NOTIFY subscribers on all agents for real-time updates
- [ ] Rollback script: Postgres → JSON file restore

### Phase 5 — Cutover (Sprint 6, Week 2-3)
- [ ] Postgres-only mode: agents write exclusively to Postgres
- [ ] `sync-out.sh`: Postgres → file export every 5 min (backward compat)
- [ ] File thinning: archive Tier 3 files, remove .bak files
- [ ] Performance baseline: query latency, agent session startup time

### Phase 6 — Cleanup & Optimization (Sprint 6, Week 3-4)
- [ ] Remove dual-write logic from agents
- [ ] Archive retired state files
- [ ] Index optimization based on query patterns
- [ ] P2 readiness audit: verify tenant_id, RLS, connection pooling

---

## 8. Success Metrics

### 8.1 Fragmentation KPIs

| Metric | Current State | Target | Measurement |
|--------|--------------|--------|-------------|
| **State files outside Postgres** | ~190 JSON/MD state files | 0 (archive only) | `find state/ -name "*.json" ! -name "*.bak*" ! -path "*/archive/*" \| wc -l` |
| **Data domains in files vs Postgres** | 100% files, 5 tables in PG | 100% in PG, files as cache only | Count SSOT tables vs JSON files |
| **Cross-domain queries possible** | 0 (no cross-file query) | All domains queryable via SQL | `SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'` |
| **Version conflicts per week** | Unknown (silent data loss) | 0 (optimistic locking catches all) | `SELECT COUNT(*) FROM agent_events WHERE event_type='version_conflict'` |
| **Sync divergence incidents** | N/A (no sync check existed) | 0 (sync-check.sh alerts within 1h) | `sync-check.sh` exit code |

### 8.2 Operational KPIs

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Agent session startup time** | No regression (>90% of current) | Time from agent init to first Postgres query |
| **Tier 0 read latency** | <10ms p95 | `SELECT` on `state_tickets` by `id` |
| **Tier 1 read latency** | <50ms p95 | `SELECT` with JOIN across 2 SSOT tables |
| **Vector search latency** | <100ms p95 | `SELECT ... ORDER BY embedding <=> LIMIT 10` |
| **Write latency (with audit)** | <50ms p95 | Full write transaction (write + events + history + NOTIFY) |
| **LISTEN/NOTIFY propagation** | <500ms p95 | Time from NOTIFY to agent receiving event |
| **Backup RPO** | <24h (pg_dump), <1h (WAL) | Time since last successful backup |
| **Failover RTO** | <15 min (P1 manual), <30s (P2 automated) | Time from failure detection to agent reconnection |

### 8.3 Data Quality KPIs

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Audit trail coverage** | 100% of state writes | `SELECT COUNT(*) FROM agent_events WHERE created_at > now() - interval '1 hour'` vs expected write count |
| **Config file drift** | 0 undetected changes | `state_config_files.hash` vs `sha256(file)` check every 15 min |
| **Soft-delete coverage** | 100% (no hard deletes) | `SELECT COUNT(*) FROM agent_events WHERE event_type='hard_delete'` — must be 0 without approval |
| **Tenant isolation readiness** | All tables have tenant_id | `SELECT table_name FROM information_schema.columns WHERE column_name='tenant_id'` — count must equal total SSOT tables |

### 8.4 Migration Progress Tracking

```sql
-- Migration dashboard query
SELECT 
  'Tier 0' as tier,
  COUNT(*) as total_tables,
  COUNT(*) FILTER (WHERE migration_status = 'complete') as migrated,
  ROUND(100.0 * COUNT(*) FILTER (WHERE migration_status = 'complete') / COUNT(*), 1) as pct
FROM ssot_migration_status WHERE tier = 'Tier 0'
UNION ALL
SELECT 'Tier 1', COUNT(*), ..., ... FROM ssot_migration_status WHERE tier = 'Tier 1'
UNION ALL
SELECT 'Tier 2', COUNT(*), ..., ... FROM ssot_migration_status WHERE tier = 'Tier 2';
```

**Target:** Tier 0 = 100% by end of Sprint 5 Week 1. Tier 1 = 100% by end of Sprint 5 Week 3. Tier 2 = 100% by end of Sprint 6.

---

## 9. Appendix: Decision Log

| Decision ID | Decision | Rationale | Date |
|-------------|----------|-----------|------|
| EA-SSOT-001 | Consolidate LinkedIn 4→1 table | Same domain, same agent ownership (Spark/Aria). No reason for separate files. | 2026-05-23 |
| EA-SSOT-002 | Keep knowledge files as archive + vectorize to PG | Narrative MD is human-readable; PG is machine-queryable. Both serve different purposes. | 2026-05-23 |
| EA-SSOT-003 | JSONB for flexible payloads, columns for queryable fields | Premature normalization of rapidly-evolving schemas causes migration pain. JSONB gives schema flexibility. | 2026-05-23 |
| EA-SSOT-004 | 28 SSOT tables (not 50+) | Consolidation where domain-aligned. Not every JSON file gets its own table. | 2026-05-23 |
| EA-SSOT-005 | Optimistic locking for shared state (not event sourcing) | P1 agent execution is sequential. Conflict rate is near zero. Event sourcing deferred to P4 per DataMemory roadmap. | 2026-05-23 |
| EA-SSOT-006 | Dual-write transition (file + PG) before PG-only cutover | No big-bang migration. Agents can fall back to files during transition. Risk is contained. | 2026-05-23 |
| EA-SSOT-007 | Notion is presentation layer; Postgres is SSOT | Postgres wins on conflict. Notion is human-facing UI. | 2026-05-23 |
| EA-SSOT-008 | 90+ .bak files → trash (keep 7 days) | Backup artifacts. Redundant with pg_dump + WAL. | 2026-05-23 |
| EA-SSOT-009 | Workspace config files (AGENTS.md, SOUL.md, etc.) stay as files | They define agent identity at boot time. Hashed + registered, but file-first for bootstrapping. | 2026-05-23 |
| EA-SSOT-010 | P2 RLS from day one of multi-tenancy | tenant_id already on every table. RLS is the enforcement layer. | 2026-05-23 |

---

## 10. Risk Register

| Risk ID | Risk | Likelihood | Impact | Mitigation |
|---------|------|-----------|--------|------------|
| R-001 | Postgres performance degradation under agent load | Low | High | Connection pooling (pgbouncer at P2). Index optimization. Query plan monitoring. |
| R-002 | Agent code changes introduce bugs during migration | Medium | High | Dual-write transition. File fallback. Comprehensive test suite. |
| R-003 | Data loss during migration script execution | Low | Critical | Transactional migration scripts. Verify row counts before/after each migration. Rollback script tested. |
| R-004 | pgvector performance degrades with knowledge base growth | Low | Medium | IVFFlat → HNSW migration path documented. Monitor query latency. |
| R-005 | Notion sync conflicts during bidirectionality | Medium | Medium | Postgres-wins conflict resolution. NOTIFY on Notion changes triggers PG upsert within 5 min. |
| R-006 | Homebrew Postgres upgrade breaks schema | Low | High | `pg_dump` before any Homebrew operation. Test schema on staging before production upgrade. |
| R-007 | Agent session startup slower due to PG dependency | Medium | Low | Connection pooling. Cache Tier 2 data locally. Measure and optimize. |

---

*End of Assessment. For review by Ken Mun (CTO) and Thrawn (AI Platform Architect) before Sprint 5 planning.*
