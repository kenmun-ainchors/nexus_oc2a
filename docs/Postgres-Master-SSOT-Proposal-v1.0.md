# Postgres as Master Repository & Platform SSOT — Full Activation Proposal

**Document ID:** PROPOSAL_PostgresMasterSSOT_v1.0_2026-05-23
**Authors:** Atlas 🏛️ (Enterprise Architect) + Thrawn (Platform Architect)
**Directive:** Ken Mun (CTO) — Full Postgres Activation as Platform Master Repo & SSOT
**Predecessor Tickets:** TKT-0195 (Postgres Deploy + 5-Tier Schema), TKT-0198 (Top 5 JSON Migration), TKT-0196 (Work Types Rule), TKT-0197 (Sources of Truth Register)
**Status:** ✅ APPROVED — Ken Mun (CTO), 2026-05-23 10:31 AEST
**Sprint Target:** Sprint 5 (2026-05-25 onward)
**Approval Note:** Full activation authorized. Proceed with phased migration.

---

## 1. Executive Summary

**The file-based state system is structurally incapable of supporting P2 multi-tenancy, cross-agent query, or guaranteed consistency.** The fragmented ecosystem of ~402 files (194 JSON, 51 Markdown, 90+ backup artifacts, 38 logs) across `state/` (36MB) and ~78 memory files across `memory/` (2MB) cannot provide cross-domain query, audit trail integrity, or conflict resolution at the level required for client-facing operations.

PostgreSQL 16.14 with pgvector 0.8.2 is already deployed on OC1 with the 5-tier schema (14 tables). TKT-0198 migrated the first 5 JSON state files. **This proposal provides the complete blueprint to finish the job** — identify all data assets, consolidate where beneficial, migrate in priority order, and wire all 14+ agents to Postgres as their authoritative read/write path.

**Key outcomes:**
- **190+ state JSON files → ~28 structured SSOT tables** (37 total with existing 9 base tables)
- **78 memory files → vectorized knowledge store** with pgvector semantic search
- **14+ agents → Postgres as primary read/write** with file fallback
- **Real-time inter-agent sync** via LISTEN/NOTIFY event channels
- **Audit trail on every write** — immutable agent_events + agent_state_history
- **P2-ready** — tenant_id on every table, RLS pattern documented, OC2 HA replication plan

---

## 2. Complete Data Asset Inventory & Classification

### 2.1 Classification Framework

| Tier | Definition | Access Latency | Consistency | Migration Priority |
|------|-----------|----------------|-------------|-------------------|
| **Tier 0** | Must-have-realtime — agents read/write every session | <10ms | Strong (transactional) | P0 — Sprint 5 Week 1-2 |
| **Tier 1** | Operational — read/write daily or per-task | <50ms | Strong (eventual ok for reads) | P1 — Sprint 5 Week 2-3 |
| **Tier 2** | Reference — read-frequent, write-occasional | <100ms | Eventual | P2 — Sprint 6 |
| **Tier 3** | Archive — infrequent access, compliance retention | Any | Immutable | P3 — Keep as files/delete |

| Domain | Scope |
|--------|-------|
| **Operations** | Agent execution, task routing, health, heartbeats, latency |
| **Governance** | Tickets, changes, policies, DoD validation, rules, skills |
| **Agent State** | Per-agent memory, session context, shared knowledge |
| **Business** | LinkedIn, content, marketing, ROI, budgets, drive sync |
| **Knowledge** | Document registry, embeddings, lessons, frameworks, research |

### 2.2 Tier 0 — Must-Have-Realtime (P0, 10 files)

| # | File | Domain | Format | Postgres Destination | Status |
|---|------|--------|--------|---------------------|--------|
| 1 | `tickets.json` | Governance | JSON (~850KB) | `state_tickets` | ✅ Migrated (TKT-0198) |
| 2 | `cost-state.json` | Operations | JSON | `state_cost` | ✅ Migrated (TKT-0198) |
| 3 | `model-policy.json` | Governance | JSON | `state_model_policy` | ✅ Migrated (TKT-0198) |
| 4 | `task-queue.json` | Operations | JSON | `state_task_queue` | ✅ Migrated (TKT-0198) |
| 5 | `critical-config-baseline.json` | Governance | JSON | `state_config_baseline` | ✅ Migrated (TKT-0198) |
| 6 | `agent-status.json` | Operations | JSON | Extend `agent_sessions` | ⬜ New |
| 7 | `chg-registry.json` | Governance | JSON | `state_changes` (NEW) | ⬜ New |
| 8 | `task-queue-dispatch.json` | Operations | JSON | Merge → `state_task_queue` | ⬜ Consolidate |
| 9 | `heartbeat-state.json` | Operations | JSON | `agent_shared_state` | ⬜ New |
| 10 | `policy-register.json` | Governance | JSON | `state_policies` (NEW) | ⬜ New |

### 2.3 Tier 1 — Operational (P1, 28 files)

Major consolidation wins:
- **LinkedIn**: 4 files → 1 table (`state_linkedin`)
- **CI/CD**: 4 files → 1 table (`state_ci`)
- **Notion sync**: 7 files → 1 table (`state_notion_sync`)
- **Cost/Finance**: 6 files → merge into existing `state_cost`
- **Standups**: 6 files → 1 table (`state_standups`)
- **Sprints**: 4 files → 1 table (`state_sprints`)
- **25+ key-value state files** → single `agent_shared_state` table (already exists)

Full Tier 1 table list: `state_agent_budgets`, `state_backlog`, `state_ci`, `state_content_queue`, `state_drive_sync`, `state_frameworks`, `state_incidents`, `state_latency`, `state_linkedin`, `state_notion_sync`, `state_roi`, `state_rule_violations`, `state_sprints`, `state_standups`, `state_relay_queue`, `state_research`, `state_skills` — plus 25+ entries merged into `agent_shared_state`.

### 2.4 Memory Files → Knowledge Domain

The ~78 memory files are **narrative, contextual, agent-specific** — different from structured state:

| Category | Files | Migration Strategy |
|----------|-------|-------------------|
| Daily logs (`2026-04-25.md` through `2026-05-22.md`) | ~56 files | `knowledge_documents` + `knowledge_chunks` with vector embeddings. Original MD retained as archive. |
| Shared memory (`memory/shared/*.md`) | 8 files | `knowledge_documents` — living reference docs |
| Agent memory (`memory/agents/*.md`) | 11 files | `knowledge_documents` with `agent_id` filter |
| Lessons learned (`LESSONS.md`) | 1 file | `knowledge_documents` + `state_lessons` (NEW structured table) |
| Changelog (`CHANGELOG.md`) | 1 file | Merge into `state_changes` |
| Memory archive | 2 files | Tier 3 — keep as files, vectorize if needed for historical RAG |

### 2.5 What Stays as Files

Workspace config files (`AGENTS.md`, `SOUL.md`, `MEMORY.md`, `RULES.md`, `YODA_RULES.md`, `YODA_RUNBOOK.md`, `HEARTBEAT.md`, `IDENTITY.md`, `USER.md`, `TOOLS.md`, etc.) **remain as files** — they define agent identity at boot time. They are **registered** in Postgres (`state_config_files` table) with SHA-256 hashes for drift detection, and key narrative files (`MEMORY.md`, `YODA_RUNBOOK.md`, `SHARED_CONTEXT.md`) are additionally vectorized into `knowledge_documents` for RAG.

### 2.6 Archive-Only (P3 — Not Worth Migrating)

- 90+ `tickets.json.bak*` files → keep 7 days, then trash
- 38 `auto-heal-*.log` files → aggregate summaries to PG, archive raw logs
- 8 diagnostic logs → keep 30 days, archive
- 2 legacy SQLite DBs (`obs.db`, `tasks.db`) → migrate data to PG, archive
- PIR records, checkpoints, OWL archive → Tier 3 archive

---

## 3. Unified SSOT Schema Design

### 3.1 Consolidation Principles

1. **Merge by domain, not by format** — two JSON files about LinkedIn = one table
2. **One table per business entity** — Tickets, Changes, Policies, Agents, Sprints each get their own
3. **JSONB for flexibility, columns for queryability** — WHERE-filtered/JOINed fields must be columns
4. **No duplication across tables** — ticket status lives in one place
5. **Version column on every mutable table** — optimistic locking prevents silent overwrites
6. **Every write is audited** — `agent_events` + `agent_state_history` capture who/what/when

### 3.2 Target Schema (37 tables total)

```
NEXUS SSOT SCHEMA
├── TIER 1 — AUDIT (immutable, append-only)
│   ├── agent_events ✓
│   ├── agent_decisions ✓
│   ├── decision_lineage ✓
│   └── memory_access_log ✓
│
├── TIER 2 — VECTOR / KNOWLEDGE
│   ├── knowledge_documents ✓
│   └── knowledge_chunks ✓  (pgvector, 768-dim)
│
├── TIER 3 — SESSIONS
│   └── agent_sessions ✓ (extended with agent_status fields)
│
├── TIER 4 — SHARED STATE (key-value, versioned)
│   └── agent_shared_state ✓
│
├── TIER 5 — HISTORY (append-only state mutations)
│   └── agent_state_history ✓
│
├── SSOT TABLES (28 new/in-progress)
│   ├── state_tickets ✓           ├── state_policies
│   ├── state_changes              ├── state_incidents
│   ├── state_cost ✓              ├── state_lessons
│   ├── state_model_policy ✓      ├── state_sprints
│   ├── state_task_queue ✓        ├── state_standups
│   ├── state_config_baseline ✓   ├── state_ci
│   ├── state_linkedin            ├── state_research
│   ├── state_content_queue       ├── state_skills
│   ├── state_notion_sync         ├── state_frameworks
│   ├── state_drive_sync          ├── state_roi
│   ├── state_autoheal_log        ├── state_latency
│   ├── state_diagnostics         ├── state_model_trials
│   ├── state_uptime              ├── state_kri
│   ├── state_config_files        ├── state_relay_queue
│   ├── state_rule_violations     └── state_agent_budgets
│
└── T6 — CONFIGURATION & MANAGEMENT (Thrawn additions)
    ├── config_entries (structured TOML/YAML config)
    ├── changelog (canonical CHG tracking)
    ├── agent_registry (canonical agent list)
    ├── cost_events (structured daily cost)
    └── notifications (alert/notification state)
```

✓ = already deployed

### 3.3 Normalization Strategy

| Entity Type | Normalization | Rationale |
|-------------|---------------|-----------|
| Tickets, Changes, Policies, Incidents | **3NF** (fully normalized) | Relational business entities with foreign keys |
| Cost, Metrics, Logs | **3NF with JSONB detail columns** | Core columns normalized; payload in JSONB |
| Agent State, Config | **Key-Value** (`agent_shared_state`) | Deliberately denormalized with version locking |
| Knowledge | **Document → Chunk (1:N)** | Metadata normalized; content + embedding stored together |

### 3.4 Indexing Strategy

| Table | Index | Purpose |
|-------|-------|---------|
| All SSOT tables | B-tree `tenant_id` | Multi-tenant filtering (P2-ready) |
| `state_tickets` | B-tree `status`, `type`, `created_at` | Ticket filtering |
| `agent_events` | B-tree `agent_id`, `timestamp DESC` | Agent activity timeline |
| `agent_shared_state` | UNIQUE `(tenant_id, key)` | Exact key lookup |
| `knowledge_chunks` | IVFFlat/HNSW `embedding vector_cosine_ops` | Semantic search |
| `state_model_policy` | B-tree `agent_id` | Per-agent model routing |
| `state_config_files` | UNIQUE `file_path` | Config drift detection |

---

## 4. Migration Phased Plan

### Phase Overview

```
Phase 0: Foundation (Week 1)      — db.sh wrapper, roles, connection verification
Phase 1: Low-Risk State (Week 2)  — New SSOT tables DDL, data migration, state_v views
Phase 2: Tier 1 Consolidation (Week 2-3) — LinkedIn, CI, Notion, Sprints, Standups
Phase 3: Memory → Knowledge (Week 3-4) — 78 memory files → knowledge_documents/chunks
Phase 4: Agent Wiring (Week 4-5) — Dual-write, LISTEN/NOTIFY, agent cutover
Phase 5: Validation & Cutover (Week 5-6) — Parallel run, rollback drill, PG-primary
Phase 6: Cleanup (Week 6)         — Archive files, remove dual-write, optimize
```

### Dependency Order

```
state_cost, model_policy, config_baseline, tickets (Phase 1 — no dependencies)
    │
    ▼
agent_sessions, agent_events, decisions, lineage (Phase 2 — needs session tracking)
    │
    ▼
knowledge_documents, knowledge_chunks (Phase 3 — needs document→chunk pipeline)
    │
    ▼
agent_shared_state, state_task_queue (Phase 4 — needs versioned write pattern)
    │
    ▼
All remaining SSOT tables + agent wiring (Phases 4-5)
```

### Gate Criteria Per Phase

| Phase | Gate |
|-------|------|
| 0 | `psql` accessible from all agent spawn contexts; connection pool functional; read-only role works |
| 1 | All Phase 1 tables populated with >95% data parity vs files; state_v views return correct JSON |
| 2 | Consolidated tables (LinkedIn, CI, Notion, Sprints) verified; file count reduced by 25+ |
| 3 | All ~78 memory files ingested; pgvector similarity search validated |
| 4 | 7+ agents reading/writing Postgres; dual-write parity confirmed |
| 5 | Rollback drill passed; no data divergence >1h; agents on PG-primary |
| 6 | `state/` directory archived (not deleted); backup files older than 30 days cleaned |

---

## 5. Agent Read/Write Architecture

### 5.1 Connectivity Model

**Decision: `psql` CLI wrapper (`db.sh`), not REST API**

- Agents already use shell commands for everything
- Direct `psql` via Unix socket — zero network overhead
- Full SQL power (JSONB queries, aggregations, CTEs)
- No new service to maintain

```
Agent (tool call) → exec("db.sh -c '...'") → psql → PostgreSQL (Unix socket)
                                              ↓ (fallback)
                                         read/write state/*.json
```

### 5.2 Agent Access Matrix

| Agent | Tier | Reads | Writes |
|-------|------|-------|--------|
| **Yoda** (Orchestrator) | T0 | ALL tables | events, sessions, shared_state, tickets, changes, knowledge |
| **Forge** (Dev) | T1-T2 | tickets, task_queue, knowledge | events, tickets, knowledge |
| **Thrawn** (Platform) | T1 | tickets, changes, frameworks, policies | decisions, knowledge (architecture) |
| **Atlas** (Enterprise) | T1 | tickets, policies, frameworks, knowledge | assessments, decisions |
| **Shield** (Security) | T2 | events, incidents, rule_violations | incidents, rule_violations, decisions |
| **Warden** (Compliance) | T2 | events, policies, rule_violations | rule_violations, decisions |
| **Spark** (Social) | T2 | linkedin, content_queue | linkedin, events |
| **Aria** (Marketing) | T2 | linkedin, content_queue, roi | content_queue, events |
| **Sage** (Content) | T2 | content_queue, knowledge | knowledge, events |
| **Lex** (Legal) | T2 | policies, knowledge | policies, decisions |
| **Lando** (PM) | T2 | tickets, changes, sprints | sprints, standups |
| **Ahsoka** (Strategy) | T2 | tickets, knowledge, research | research, decisions |
| **Krennic** (Infra) | T2 | ci, uptime, latency, diagnostics | ci, uptime, diagnostics |
| **Mon Mothma** (Support) | T2 | tickets, knowledge | events |

### 5.3 Write Patterns

- **Every write** = `BEGIN → write target table → write agent_events → write agent_state_history → NOTIFY → COMMIT`
- **Optimistic locking** on `agent_shared_state` via `version` column with retry-on-conflict
- **Atomic task claims**: `UPDATE state_task_queue SET status='claimed' WHERE id=X AND status='pending'` — no version needed
- **Immutable audit**: `agent_events`, `agent_decisions`, `agent_state_history` are append-only

### 5.4 Read Patterns

| Data | Pattern | Refresh |
|------|---------|---------|
| Tier 0 (tickets, config) | Direct PG query, cached in session | 30-60s poll or NOTIFY |
| Tier 1 (LinkedIn, CI, sprints) | PG query with 30s cache | 30s poll |
| Tier 2 (knowledge, frameworks) | pgvector search or PG query | 5m cache |
| Reference (model policy) | Load on session start, NOTIFY invalidate | Event-driven |

---

## 6. Real-Time Sync: LISTEN/NOTIFY

### 6.1 Channel Design

| Channel | Trigger | Payload | Subscribers |
|---------|---------|---------|-------------|
| `ticket_changed` | INSERT/UPDATE on state_tickets | `{id, status, op}` | Yoda, Lando, Ticket Manager |
| `task_queued` | INSERT on state_task_queue | `{id, title, priority}` | Yoda, all T1-T2 agents |
| `task_claimed` | UPDATE status→claimed | `{id, agent}` | Yoda |
| `task_completed` | UPDATE status→complete | `{id, result}` | Yoda |
| `state_changed` | UPDATE on agent_shared_state | `{key, version}` | All agents reading that key |
| `cost_updated` | INSERT on cost_events | `{date, total}` | Cost Tracker, Yoda |
| `config_changed` | UPDATE on config_entries | `{path, new_value}` | Affected agent, Yoda, Warden |
| `alert_raised` | INSERT critical notification | `{title, body}` | All T1-T2 agents |
| `session_started` | INSERT on agent_sessions | `{agent_id, session_key}` | Yoda |
| `session_ended` | UPDATE ended_at | `{agent_id, duration}` | Yoda |

NOTIFY triggers auto-fire on table INSERT/UPDATE. Agents subscribe via a persistent `psql LISTEN` or polling fallback.

### 6.2 Polling Fallback

Stateless T3 subagents use polling with version checks:

```bash
# Poll a state key with version check
db.sh -c "SELECT state_value, version FROM agent_shared_state
          WHERE state_key='ticket-cache' AND version > $last_version"
```

---

## 7. Backward Compatibility & Transition

### 7.1 Dual-Write Transition

**Phase 4-5: Dual-write period**
- Agents write to BOTH Postgres and files
- Reads from Postgres with file fallback
- `sync-check.sh` compares file vs Postgres hourly

**Phase 5: Postgres-primary**
- Agents write to Postgres only
- `sync-out.sh` exports Postgres → files every 5 min (for tools that still read files)
- Files become read-only cache

**Phase 6: Postgres-only**
- Files archived. Agents exclusively use Postgres
- `state_v` views provide backward-compatible JSON output

### 7.2 state_v View Pattern

Agents that previously read `state/tickets.json` now query:
```sql
SELECT data FROM state_v.tickets;  -- returns {"tickets": [...]} — same JSON shape
```

Views exist for: `state_v.tickets`, `state_v.cost_state`, `state_v.config_baseline`, `state_v.model_policy`, `state_v.task_queue`, `state_v.shared_state`, `state_v.agent_status`

### 7.3 Rollback Strategy

| Scenario | Action | Recovery Time |
|----------|--------|---------------|
| Single PG query failure | Retry 3x → use file fallback | <5s |
| Agent unable to reach PG | Agent reverts to file-only mode | <30s |
| PG unavailable >5 min | All agents revert to file-only | <2 min |
| Phase 1-2 rollback | Stop PG writes, files still authoritative | <30 min |
| Phase 3 rollback | Files still exist; PG chunks are supplementary | <1 hour |
| Phase 4 rollback | Files may be stale; reconciliation needed | 2-4 hours |
| Phase 5+ rollback | `pg_dump` → file reconstruction | 4-8 hours |

**Rule:** Don't proceed past Phase 3 without passing a rollback drill.

---

## 8. OC2 HA Readiness

| Component | P1 (Now) | P2 (OC2 arrives Jul 2026) |
|-----------|----------|---------------------------|
| **Postgres** | Single instance on OC1. `pg_dump` nightly. | Streaming replication to OC2 standby. `pgbouncer` for connection pooling. |
| **Failover** | Manual restore from dump <15 min | Automated via `pg_ctl promote`. <30s failover. Target <2 min total. |
| **Backup** | `pg_dump` + WAL archiving to disk | Continuous WAL shipping to OC2. Offsite via rclone (optional). |
| **Connection** | Direct `psql` via Unix socket | `db.sh` auto-discovers primary across OC1+OC2. |
| **LISTEN/NOTIFY** | Single-channel on OC1 | Replicated channels. OC2 agents receive same events. |

**OC2 initial setup:**
```bash
pg_basebackup -h oc1.local -U ainchorsoc2a -D /opt/homebrew/var/postgresql@16/data -P -R
brew services start postgresql@16  # starts in standby mode
```

### PostgreSQL Tuning for M4 24GB

```ini
shared_buffers = 512MB          # ~20% of system RAM
effective_cache_size = 16GB     # Planner hint
work_mem = 16MB                 # Helps JSONB operations
maintenance_work_mem = 256MB    # For VACUUM, CREATE INDEX
random_page_cost = 1.1          # SSD-optimized
effective_io_concurrency = 200  # SSD I/O
max_parallel_workers = 8        # M4 has 10 cores
wal_level = replica
max_wal_senders = 3
```

**Sizing projection:** Current 8.7MB → ~100MB (6 months) → ~200MB (12 months). Well within M4 24GB capacity.

---

## 9. Enterprise Integration

### 9.1 Postgres ↔ Notion (Holocron)

- **SSOT authority:** Postgres wins on conflict. Notion is the presentation/human-facing layer.
- **Sync:** Real-time for Tier 0 (LISTEN/NOTIFY on ticket changes). Batch every 5 min for Tier 1.
- **Flow:** Create/Update in Notion → webhook/poll → Postgres upsert. Create/Update in Postgres → Notion API → update page.

### 9.2 Postgres ↔ MinIO

- Postgres stores metadata (`knowledge_documents.object_key`). MinIO stores binary blobs.
- Both OC1-local. No cloud dependency for Tier 0/1 storage.

### 9.3 Postgres ↔ Google Drive

- `state_drive_sync` table tracks sync metadata. Drive is document authoring platform; Postgres is metadata registry.
- Sync direction: Google Drive → Postgres (metadata pull). Postgres does NOT push to Drive.

### 9.4 Multi-Tenant Readiness (P2 Gate)

Every table already has `tenant_id VARCHAR NOT NULL DEFAULT 'ainchors'`. For P2:
1. Add `tenant_id` to `agent_sessions`
2. Enable RLS: `CREATE POLICY tenant_isolation ON table USING (tenant_id = current_setting('app.tenant_id'))`
3. Add `org_id` to tickets/changes for company-level grouping
4. Cross-tenant access prohibited at schema level

**This costs nothing now but saves weeks in P2.**

---

## 10. Governance & Standards

### 10.1 Naming Conventions

| Object | Convention | Example |
|--------|-----------|---------|
| SSOT tables | `state_<entity>` | `state_tickets`, `state_linkedin` |
| Audit tables | `agent_<entity>` | `agent_events`, `agent_decisions` |
| Knowledge tables | `knowledge_<entity>` | `knowledge_documents` |
| Primary keys | `<table>_id` or `id` | `ticket_id` |
| Foreign keys | `<referenced>_id` | `document_id → knowledge_documents` |
| Indexes | `idx_<table>_<cols>` | `idx_state_tickets_status` |
| Timestamps | `TIMESTAMPTZ`, always UTC | `created_at`, `updated_at`, `deleted_at` |

### 10.2 Audit Trail Requirements

Every state-changing operation:
```
1. BEGIN
2. Write target table
3. INSERT agent_events (agent_id, event_type, table_name, record_id, action)
4. INSERT agent_state_history (old_value, new_value, changed_by)
5. COMMIT
```

**Immutable:** `agent_events`, `agent_decisions`, `agent_state_history` — append-only, no UPDATE/DELETE by application code. Retention: indefinite.

### 10.3 Data Retention

| Category | Retention | Action |
|----------|-----------|--------|
| Audit logs | Indefinite | Never delete. Archive to cold storage at 5 years. |
| Tickets & Changes | Indefinite | Soft-delete only. Archive closed >2 years. |
| Auto-heal logs | 90 days | Partition by month; drop partitions >90 days. |
| Latency metrics | 90 days | Roll up to aggregates. |
| Standups | 1 year | Archive >1 year. |
| Diagnostics | 30 days | Auto-purge via cron. |

---

## 11. Risk Assessment

### Top Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| PG outage during critical operations | Medium | Critical | File fallback in all scripts. Tested before Phase 1. |
| OC1 hardware failure before OC2 | Low | Critical | Daily pg_dump + weekly pg_basebackup to external storage. |
| Rollback complexity after Phase 4 | Medium | High | Keep file writes parallel for 48h. Rollback drill required as Phase 5 gate. |
| Migration script data loss | Low | Critical | Dry-run on restore_test DB. Transactional migrations. Verify row counts. |
| pgvector embedding generation slow | Medium | Medium | Batch generation. Use external API if local model too slow. |
| Agent code bugs during migration | Medium | High | Dual-write transition. File fallback. Comprehensive testing. |

### Risk Matrix

```
                    Likelihood →
                    Low           Medium        High
Impact             ┌────────────┬────────────┬────────────┐
↓                  │            │            │            │
Critical  │        │ OC1 HW     │ PG outage  │            │
          │        │ failure    │            │            │
          │        │            │            │            │
High      │        │ Corrupt    │ Embedding  │            │
          │        │ JSONB      │ slow       │            │
          │        │            │            │            │
Medium    │        │ WAL spike  │ Rollback   │            │
          │        │            │ complexity │            │
          │        │            │            │            │
Low       │        │ Connection │ Index      │            │
          │        │ exhaust    │ bloat      │            │
          └────────────┴────────────┴────────────┘
```

---

## 12. Success Metrics

### 12.1 Fragmentation KPIs

| Metric | Current | Target |
|--------|---------|--------|
| State files outside Postgres | ~190 JSON/MD files | 0 (archive only) |
| Data domains in files vs PG | 100% files | 100% in Postgres |
| Cross-domain queries possible | 0 | All queryable via SQL |
| Version conflicts/week | Unknown (silent loss) | 0 (optimistic locking) |
| Sync divergence incidents | N/A | 0 (sync-check.sh alerts within 1h) |

### 12.2 Operational KPIs

| Metric | Target |
|--------|--------|
| Agent session startup time | No regression (>90% of current) |
| Tier 0 read latency | <10ms p95 |
| Tier 1 read latency | <50ms p95 |
| Vector search latency | <100ms p95 |
| Write latency (with audit) | <50ms p95 |
| LISTEN/NOTIFY propagation | <500ms p95 |
| Backup RPO | <24h (dump), <1h (WAL) |
| Failover RTO | <15 min (P1), <30s (P2) |

### 12.3 Data Quality KPIs

| Metric | Target |
|--------|--------|
| Audit trail coverage | 100% of state writes |
| Config file drift | 0 undetected changes |
| Soft-delete coverage | 100% (no hard deletes without approval) |
| Tenant isolation readiness | tenant_id on 100% of tables |

---

## 13. How This Eliminates Fragmentation

| Pain Point | Before (Files) | After (Postgres SSOT) |
|------------|---------------|----------------------|
| **Fragmented memory** | 78 files, no cross-file query | Single `knowledge_documents` table. Vector search across ALL agent memory. |
| **Context out of sync** | Agents read stale files. No version tracking. | Optimistic locking. `updated_at`. LISTEN/NOTIFY pushes changes. |
| **No single source of truth** | "Which tickets.json is current?" (90+ .bak files) | One row per ticket. One config baseline. |
| **JSON corruption** | No transactional writes. File truncation on crash. | Postgres ACID. Rollback on failure. WAL crash recovery. |
| **Version conflicts** | Two agents write simultaneously → data loss | `version` column. Second writer gets conflict, retries. |
| **Can't query across domains** | `grep` across 200 files | `SELECT ... JOIN ... WHERE` across any table. |
| **No audit trail** | Who changed ticket status? Unknown. | `agent_events` records every write with agent, timestamp, before/after. |
| **Backup fragility** | 90+ `.bak` files, manual rotation | `pg_dump` + WAL archiving. Point-in-time recovery. |

---

## 14. Decision Log

| DEC | Decision | Rationale |
|-----|----------|-----------|
| SSOT-001 | Consolidate LinkedIn 4→1 table | Same domain, same agent ownership. No reason for separate files. |
| SSOT-002 | Keep knowledge files as archive + vectorize to PG | Narrative MD is human-readable; PG is machine-queryable. Both serve different purposes. |
| SSOT-003 | JSONB for flexible payloads, columns for queryable fields | Premature normalization causes migration pain. JSONB gives schema flexibility. |
| SSOT-004 | 28 SSOT tables (not 50+) | Consolidation where domain-aligned. Not every JSON file gets its own table. |
| SSOT-005 | Optimistic locking for shared state (not event sourcing) | P1 execution is sequential. Event sourcing deferred to P4. |
| SSOT-006 | Dual-write transition before PG-only cutover | No big-bang migration. Risk is contained. |
| SSOT-007 | Notion is presentation layer; Postgres is SSOT | Postgres wins on conflict. Notion is human-facing UI. |
| SSOT-008 | `psql` CLI wrapper, not REST API | Agents already use shell commands. No new service to maintain. |
| SSOT-009 | Workspace config files stay as files | They define agent identity at boot time. Hashed + registered, not migrated. |
| SSOT-010 | P2 RLS from day one of multi-tenancy | tenant_id already on every table. RLS is the enforcement layer. |

---

## Appendix A: Reference Files

- Full Atlas assessment: `state/atlas-postgres-ssot-assessment.md` (739 lines)
- Full Thrawn design: `state/thrawn-postgres-ssot-design.md` (1,697 lines)
- 5-tier schema DDL: `forge/schema_p1.sql`
- Migration script: `forge/scripts/migrate-state-to-postgres.sh`
- TKT-0197 Sources of Truth Register
- TKT-0196 Three Work Types Rule

---

*End of Proposal. For review by Ken Mun (CTO) before Sprint 5 planning.*
*This document supersedes any fragmented architecture docs on the Postgres migration topic.*
