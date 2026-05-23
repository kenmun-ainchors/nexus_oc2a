# Postgres Master SSOT — Execution Runbook

**Document ID:** RUNBOOK_PostgresMasterSSOT_v1.0_2026-05-23
**Based on:** Postgres-Master-SSOT-Proposal-v1.0.md (APPROVED Ken Mun 2026-05-23 10:31 AEST)
**Execution Window:** 2026-05-23 – 2026-05-24 (pre-Sprint 5)
**Owner:** Yoda 🟢 (Orchestrator) | Execution: Forge 🏗️ (Build), Thrawn (Arch Review), Atlas 🏛️ (EA Oversight)

---

## Phase Summary

| Phase | Scope | Tickets | Est. Effort | Dependencies |
|-------|-------|---------|-------------|-------------|
| **P1** | Foundation & New Tables DDL | TKT-0252, TKT-0253, TKT-0254 | 3-4 hrs | None |
| **P2** | Tier 1 Consolidation (LinkedIn, CI, Sprints, Standups, Notion) | TKT-0255, TKT-0256, TKT-0257, TKT-0258, TKT-0259 | 4-5 hrs | P1 complete |
| **P3** | Memory → Knowledge Pipeline | TKT-0260 | 3-4 hrs | P1 complete |
| **P4** | Agent Wiring | TKT-0261, TKT-0262 | 3-4 hrs | P2 + P3 complete |
| **P5** | Validation & Cutover | TKT-0263 | 2-3 hrs + 24h observation | P4 complete |
| **P6** | Cleanup | TKT-0264 | 1-2 hrs | P5 complete |

**Total:** 12 tickets | ~20 hours effort | 2-day execution window

---

## Phase 1: Foundation & New Tables DDL

### TKT-0254 — db.sh Wrapper + Connection Pool Verification
**Agent:** Forge 🏗️
**Priority:** P0 | **Effort:** 1 hr
**Depends on:** None

#### AC
- [ ] `scripts/db.sh` created — thin psql wrapper with correct connection params
- [ ] `db.sh` accessible from all agent spawn contexts (absolute path `/Users/ainchorsangiefpl/.openclaw/workspace/scripts/db.sh`)
- [ ] Connection stress test: 14 concurrent `psql` calls via exec, all succeed
- [ ] Read-only agent role created: `agent_readonly` with SELECT on all tables
- [ ] Read-write agent role created: `agent_readwrite` with SELECT/INSERT/UPDATE on state tables
- [ ] Agent admin role: `agent_admin` with full DDL

#### Implementation
```bash
#!/bin/bash
# db.sh — Agent postgres access wrapper
# Usage: db.sh -c "SELECT ..." | db.sh -f script.sql
export PGHOST=localhost
export PGPORT=5432
export PGUSER=ainchorsangiefpl
export PGDATABASE=ainchors_nexus
export PGOPTIONS="--client-min-messages=warning"
/opt/homebrew/bin/psql -t -A "$@"
```

#### Validation
1. Verify: `db.sh -c "SELECT count(*) FROM state_tickets"` returns integer > 0
2. Verify: 14 concurrent calls in parallel
3. Verify: spawn test — Forge sub-agent runs `db.sh` successfully

---

### TKT-0255 — SSOT New Tables DDL (Phase 1 Set)
**Agent:** Forge 🏗️
**Priority:** P0 | **Effort:** 1.5 hrs
**Depends on:** TKT-0254

#### AC
- [ ] DDL script `forge/schema_p2.sql` created with all new SSOT tables
- [ ] Tables created with correct types, constraints, indexes:
  - `config_entries` — structured config (config_path, config_value JSONB, value_type, is_secret)
  - `changelog` — canonical CHG tracking (change_id UNIQUE, affected_systems TEXT[], change_type, author, approved_by)
  - `agent_registry` — 14 agents with tier, model, capabilities, budget_limit
  - `cost_events` — daily cost tracking (event_date, model_id, agent_id, input_tokens, output_tokens, cost_usd)
  - `notifications` — alert/notification state (severity CHECK, title, body, acknowledged)
- [ ] Every table includes `tenant_id TEXT DEFAULT 'ainchors'`
- [ ] Every table includes `created_at TIMESTAMPTZ DEFAULT now()`, `updated_at TIMESTAMPTZ DEFAULT now()`
- [ ] Extensions added to existing tables:
  - `state_task_queue` → `atoms_jsonb JSONB`, `tenant_id`
  - `state_tickets` → `updated_at TIMESTAMPTZ`, `tags TEXT[]`, `metadata JSONB`
  - `agent_sessions` → `agent_status JSONB`, `last_seen_at TIMESTAMPTZ`

#### Validation
1. `\dt` shows 20+ tables
2. Test insert into each new table
3. Verify foreign key constraints work

---

### TKT-0256 — Tier 0 State Migration (P0 Files → PG)
**Agent:** Forge 🏗️
**Priority:** P0 | **Effort:** 1.5 hrs
**Depends on:** TKT-0255

#### AC
- [ ] 6 remaining Tier 0 files migrated:
  - `agent-status.json` → extend `agent_sessions`
  - `chg-registry.json` → `changelog` table
  - `task-queue-dispatch.json` → merge into `state_task_queue`
  - `heartbeat-state.json` → `agent_shared_state`
  - `policy-register.json` → `state_policies` (new table)
- [ ] Migration verification script confirms row count parity
- [ ] `state_v` views created for all Tier 0 tables (for backward compat)
- [ ] Agent registry seeded with all 14 agents + their tier/model/status

#### Validation
1. compare-row-counts.sh → all match
2. `SELECT * FROM state_v.agent_status` returns JSON matching old file
3. `SELECT * FROM agent_registry` returns 14 rows

---

## Phase 2: Tier 1 Consolidation

### TKT-0257 — LinkedIn State Consolidation (4→1)
**Agent:** Forge 🏗️
**Priority:** P1 | **Effort:** 1 hr
**Depends on:** TKT-0256

#### AC
- [ ] `state_linkedin` table created: `id`, `post_id`, `platform`, `status`, `content JSONB`, `metrics JSONB`, `published_at`, `campaign_id`
- [ ] Data migrated from 4 files: `linkedin-queue.json`, `linkedin-metrics.json`, `linkedin-campaign.json`, `linkedin-content-tracker.json`
- [ ] 4 original JSON files archived to `state/archive/`
- [ ] `state_v.linkedin` view created

#### Validation
1. Row count parity: `SELECT count(*) FROM state_linkedin` matches sum of original files
2. Spark agent reads from PG via db.sh

---

### TKT-0258 — CI/CD State Consolidation (4→1)
**Agent:** Forge 🏗️
**Priority:** P1 | **Effort:** 1 hr
**Depends on:** TKT-0256

#### AC
- [ ] `state_ci` table created: `id`, `cycle_name`, `status`, `started_at`, `completed_at`, `agent_id`, `metrics JSONB`, `report TEXT`
- [ ] Data migrated from: `ci-agent-state.json`, `ci-agent-metrics.json`, `ci-register.json`, `ci-cycle-b-active.json`
- [ ] 4 original files archived
- [ ] `state_v.ci` view created

#### Validation
1. Row count parity
2. Krennic agent reads CI status from PG

---

### TKT-0259 — Sprint State Consolidation (4→1)
**Agent:** Forge 🏗️
**Priority:** P1 | **Effort:** 1 hr
**Depends on:** TKT-0256

#### AC
- [ ] `state_sprints` table created: `id`, `sprint_number`, `title`, `start_date`, `end_date`, `status`, `capacity`, `committed_by`, `items JSONB`
- [ ] Data migrated from: `sprint-current.json`, `sprint-next.json`, `sprint-4-commitment.json`, `sprint-4-planning-notes.json`, `sprint-4-unified-scope.json`
- [ ] 5 original files archived
- [ ] `state_v.sprints` view created

#### Validation
1. Current sprint queryable: `SELECT * FROM state_sprints WHERE sprint_number=4`
2. Lando agent reads sprint status from PG

---

### TKT-0260 — Standup State Consolidation (6→1)
**Agent:** Forge 🏗️
**Priority:** P1 | **Effort:** 0.5 hr
**Depends on:** TKT-0256

#### AC
- [ ] `state_standups` table created: `id`, `date`, `standup_data JSONB`, `generated_by`, `issues TEXT[]`
- [ ] Data migrated from: `standup-state.json`, `standup-data-2026-05-09.json` through `standup-data-2026-05-13.json` (5 files)
- [ ] 6 original files archived
- [ ] `state_v.standups` view created

#### Validation
1. Row count matches expected
2. Standup cron points to PG

---

### TKT-0261 — Notion Sync State Consolidation (7→1)
**Agent:** Forge 🏗️
**Priority:** P1 | **Effort:** 0.5 hr
**Depends on:** TKT-0256

#### AC
- [ ] `state_notion_sync` table created: `id`, `sync_type`, `db_name`, `last_sync_at`, `record_count`, `status`, `errors JSONB`
- [ ] Data migrated from 7 notion-*.json files
- [ ] 7 original files archived
- [ ] `state_v.notion_sync` view created

---

## Phase 3: Memory → Knowledge Pipeline

### TKT-0262 — Memory Ingestion Pipeline + pgvector Setup
**Agent:** Forge 🏗️
**Priority:** P1 | **Effort:** 3-4 hrs
**Depends on:** TKT-0255 (DDL), TKT-0254 (db.sh)

#### AC
- [ ] `scripts/ingest-memory-to-pg.sh` created:
  - Reads each .md file in `memory/`
  - Inserts into `knowledge_documents` (title, source_path, mime_type, content, tags)
  - Chunks content by `## ` section headers
  - Inserts chunks into `knowledge_chunks` (document_id, chunk_index, content, token_count)
- [ ] Embedding generation validated (Nomic embedding model for 768-dim vectors)
- [ ] All ~78 memory files ingested with verification
- [ ] pgvector indexes created: IVFFlat for similarity search, GIN for full-text
- [ ] `scripts/memory-search.sh` created — thin wrapper for pgvector similarity query
- [ ] Performance: search returns <500ms for top-10 results

#### Validation
1. `SELECT count(*) FROM knowledge_documents` = ~78
2. `SELECT count(*) FROM knowledge_chunks` > 200
3. Similarity search returns relevant results for known queries
4. Verify chunk boundaries are correct (no mid-sentence cuts)

---

## Phase 4: Agent Wiring

### TKT-0263 — Dual-Write Scripts + state_v Views
**Agent:** Forge 🏗️
**Priority:** P1 | **Effort:** 2 hrs
**Depends on:** TKT-0256, TKT-0257 through TKT-0261

#### AC
- [ ] `scripts/db-write.sh` created:
  ```bash
  # Usage: db-write.sh <table> <json_payload>
  # Writes to PG, falls back to file
  ```
- [ ] `scripts/db-read.sh` created:
  ```bash
  # Usage: db-read.sh <table> [--file-fallback]
  # Reads from PG, falls back to file
  ```
- [ ] `scripts/sync-check.sh` created:
  ```bash
  # Compares PG row counts vs JSON file records
  # Reports discrepancies
  ```
- [ ] `state_v` views completed for ALL migrated tables (10+ views)
- [ ] `scripts/sync-out.sh` — exports PG → JSON files every 5 min for file-based readers

#### Validation
1. Write to PG via db-write.sh → verify JSON file updated
2. Kill PG → db-read.sh falls back to file
3. sync-check.sh runs clean (all green)

---

### TKT-0264 — LISTEN/NOTIFY Infrastructure
**Agent:** Forge 🏗️ (build) | Thrawn (design review)
**Priority:** P1 | **Effort:** 2 hrs
**Depends on:** TKT-0263

#### AC
- [ ] NOTIFY triggers installed on 10 key tables:
  - `state_tickets` → channel `ticket_changed`
  - `state_task_queue` → channels `task_queued`, `task_claimed`, `task_completed`
  - `agent_shared_state` → channel `state_changed`
  - `cost_events` → channel `cost_updated`
  - `config_entries` → channel `config_changed`
  - `notifications` → channel `alert_raised`
  - `agent_sessions` → channels `session_started`, `session_ended`
- [ ] `scripts/pg-listen.sh` — persistent listener for agents:
  ```bash
  # Usage: pg-listen.sh <agent_id> [channels...]
  # Listens and outputs JSON events
  ```
- [ ] `scripts/pg-poll.sh` — polling fallback for stateless agents:
  ```bash
  # Usage: pg-poll.sh <table> <last_version>
  # Returns changes since last check
  ```
- [ ] `agent_state_history` auto-trigger on every `agent_shared_state` UPDATE

#### Validation
1. Create ticket → `pg-listen.sh yoda ticket_changed` receives event within 500ms
2. Update state → `pg-listen.sh aria state_changed` receives event
3. Kill PG → pg-poll.sh reports connection error

---

## Phase 5: Validation & Cutover

### TKT-0265 — Dual-Write Validation + Agent Cutover
**Agent:** Yoda 🟢 (orchestrate) | Forge 🏗️ (execute)
**Priority:** P1 | **Effort:** 2-3 hrs + 24h observation
**Depends on:** TKT-0263, TKT-0264

#### AC
- [ ] `scripts/cutover-check.sh` — full parity verification across all migrated tables
- [ ] Dual-write activated on all Tier 0 agents (Yoda, Spark): write to PG + file
- [ ] 24h observation period:
  - Hourly sync-check.sh runs
  - Any divergence >1% → alert
- [ ] Rollback drill: simulate PG outage → all agents revert to files within 2 min
- [ ] After 24h with <1% divergence → cutover to PG-primary
- [ ] File writes become `sync-out.sh` exports (every 5 min)
- [ ] Agent migration checklist completed for 7+ agents

#### Validation
1. `cutover-check.sh` returns all green at T+24h
2. Rollback drill passes
3. Agent response times within 110% of file-only baseline
4. No data divergence events

---

## Phase 6: Cleanup

### TKT-0266 — State Directory Cleanup
**Agent:** Forge 🏗️
**Priority:** P2 | **Effort:** 1-2 hrs
**Depends on:** TKT-0265

#### AC
- [ ] `state/archive/` directory created
- [ ] All migrated JSON files moved to `state/archive/` (not deleted)
- [ ] `state/backups/archive/` created for 90+ backup files
- [ ] `tickets.json.bak-*` moved to archive
- [ ] Auto-heal logs consolidated: JSON summaries → PG, .log files retained
- [ ] Script references updated: `ticket.sh` reads from PG via db.sh
- [ ] Final sync-out.sh export to confirm all files reconstructable from PG
- [ ] `state/file-inventory.json` generated as permanent record

#### Validation
1. `ls state/*.json | wc -l` → 0 (all archived)
2. `ls state/archive/ | wc -l` → expected count
3. PG → file reconstruction verified via sync-out.sh
4. Ticket.sh operates without file dependency

---

## Execution Sequence

```
Day 1 (Sat 2026-05-23):
[10:00] TKT-0254 → db.sh + connection pool
[11:00] TKT-0255 → New tables DDL
[12:30] TKT-0256 → Tier 0 state migration
[14:00] TKT-0257 → LinkedIn consolidation
[15:00] TKT-0258 → CI consolidation
[16:00] TKT-0259 → Sprints consolidation
[17:00] TKT-0260 → Standups consolidation
[17:30] TKT-0261 → Notion consolidation

Day 2 (Sun 2026-05-24):
[10:00] TKT-0262 → Memory pipeline + pgvector
[14:00] TKT-0263 → Dual-write scripts
[16:00] TKT-0264 → LISTEN/NOTIFY
[18:00] TKT-0265 → Cutover + 24h observation starts
[18:30] TKT-0266 → Cleanup (after cutover confirmed)
```

## Go/No-Go Gates

| Gate | Criterion | Action if FAIL |
|------|-----------|---------------|
| G1: P1 complete | All Tier 0 tables migrated, db.sh operational | Rollback to files, fix blocker |
| G2: P2 complete | 25+ files consolidated into 5 tables | Fix migration script, re-run |
| G3: P3 complete | All 78 memory files ingested, search <500ms | Check embedding model, batch size |
| G4: P4 complete | 7+ agents writing to PG, rollback drill passed | Debug connection/access |
| G5: P5 complete | 24h dual-write with <1% divergence | Extend observation, investigate |

## Rollback by Phase

| Phase | Rollback Cost | Method |
|-------|--------------|--------|
| P1 | Low | Drop new tables, files untouched |
| P2 | Low | Restore files from archive, drop tables |
| P3 | Medium | Files preserved, drop knowledge tables |
| P4 | Medium-High | Stop PG writes, restore file authority |
| P5 | High | Cut back to files, PG as read-only |
| P6 | Low | Restore files from archive |

*Never proceed past P3 without passing a rollback drill.*

---

*End of Runbook. Execute atomically. Verify each ticket before proceeding to next.*
