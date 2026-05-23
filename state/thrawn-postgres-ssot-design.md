# Postgres-as-Master SSOT: Platform Architecture Design

**Author:** Thrawn (Platform Architect)
**Date:** 2026-05-23
**Status:** Proposal
**Database:** ainchors_nexus (PostgreSQL 16.14, pgvector 0.8.2)
**Host:** OC1 (Mac Mini M4 24GB)

---

## 1. Migration Plan (Phased)

### 1.1 Phase Overview

```
Phase 0: Foundation (Week 1)           — Connection pool, psql wrapper, access control
Phase 1: Low-Risk State (Week 2)       — Cost, model policy, config baseline, tickets
Phase 2: Session & Audit (Week 3)      — Sessions, events, decisions, lineage
Phase 3: Memory & Knowledge (Week 4)   — Memory files → knowledge_documents/chunks
Phase 4: Shared State & Task Queue (Week 5) — agent_shared_state, state_task_queue
Phase 5: Validation & Cutover (Week 6) — Parallel run validation, agent cutover
Phase 6: Cleanup (Week 7)              — Archive state/ directory, backup files
```

### 1.2 Gate Criteria Per Phase

| Phase | Gate Criteria |
|-------|--------------|
| 0 | `psql` accessible from all agent spawn contexts; connection pool functional; read-only agent role works |
| 1 | All 4 tables populated with >95% data parity vs files; state_v views return backward-compatible JSON |
| 2 | Agent sessions logged to DB; one agent writing events to DB in parallel with file writes |
| 3 | All ~58 memory files ingested into knowledge_documents/chunks; pgvector similarity search validated |
| 4 | agent_shared_state has version-locked UPSERT pattern working; task queue reads/writes from DB |
| 5 | 7+ agents reading from Postgres; file fallback tested; rollback drill completed |
| 6 | state/ directory archived (not deleted); backup files older than 30 days cleaned |

### 1.3 Dependency Order: What Must Move Before What

```
state_cost ──────────────┐
state_model_policy ──────┤  Phase 1 (no dependencies)
state_config_baseline ───┤
state_tickets ───────────┘
       │
       ▼
agent_sessions ──────────┐
agent_events ────────────┤  Phase 2 (needs session tracking)
agent_decisions ─────────┤
decision_lineage ────────┘
       │
       ▼
knowledge_documents ─────┐  Phase 3 (needs document+chunk pipeline)
knowledge_chunks ────────┘
       │
       ▼
agent_shared_state ──────┐  Phase 4 (needs versioned write pattern)
state_task_queue ────────┘  Phase 4 (needs shared state for async)
       │
       ▼
memory_access_log ─────── Phase 5 (populated as agents use DB)
```

**Rationale:** Cost, policy, and config are low-write, read-heavy tables — safest to move first. Sessions must be tracked before events/decisions have context. Memory files need the document→chunk ingestion pipeline built first.

### 1.4 Phase Details

#### Phase 0: Foundation

**Files:** None (infrastructure only)

**Tasks:**
1. Build `db.sh` — a thin `psql` wrapper script accessible from agent tool calls:
   ```bash
   #!/bin/bash
   # db.sh — Agent postgres access wrapper
   psql -U ainchorsangiefpl -d ainchors_nexus -t -A "$@"
   ```
2. Create database roles: `agent_readonly`, `agent_readwrite`, `agent_admin`
3. Create function: `record_agent_event(agent_id, event_type, payload)` for T1 audit
4. Add `state_v` views for all migrated tables (extend existing 2 views)
5. Run connection stress test: 14 concurrent `psql` calls

**Estimated effort:** 2-3 hours
**Risks:** LOW — No data at risk, just infrastructure

#### Phase 1: Low-Risk State Tables

**Files to migrate:** `state/cost-baseline.json`, `state/model-policy.json`, `state/config-baseline.json`, `state/tickets.json`
**Tables:** `state_cost`, `state_model_policy`, `state_config_baseline`, `state_tickets`

**Approach:**
- These are already populated in Postgres (173 tickets, 1 cost row, 1 model policy, 1 config baseline)
- Build state_v views for each (config_baseline and cost_state already exist)
- Validate data parity with source JSON files
- Add write-back to DB in ticket.sh and cost-tracker.sh scripts
- Write-through pattern: write to DB first, file as fallback

**Estimated effort:** 3-4 hours
**Risks:** LOW — These tables are read-heavy, write-rare

#### Phase 2: Session & Audit Tables

**Files to migrate:** Session state currently tracked in-memory or ad-hoc; no persistent file for agent_sessions
**Tables:** `agent_sessions`, `agent_events`, `agent_decisions`, `decision_lineage`

**Approach:**
- Build `begin_agent_session()` and `end_agent_session()` helper functions
- Implement event logging via the `record_agent_event()` function from Phase 0
- Agents write session events at start/end of each spawn
- Decision lineage populated when multi-step decisions occur (e.g., TKT grooming chains)

**Estimated effort:** 4-5 hours
**Risks:** MEDIUM — If agents don't log sessions, we have no historical data. Mitigation: Yoda (T0 orchestrator) enforces session logging.

#### Phase 3: Memory → Knowledge Pipeline

**Files to migrate:** ~58 memory files in `/Users/ainchorsangiefpl/.openclaw/workspace/memory/`
**Tables:** `knowledge_documents`, `knowledge_chunks`

**Approach:**
1. Build ingestion script `ingest-memory-to-pg.sh`:
   - Reads each `.md` file
   - Inserts into `knowledge_documents` (title=filename, source_path=full path)
   - Chunks content by section headers (`## ` boundaries)
   - Generates 768-dim embeddings via pgvector-compatible embedding model
   - Inserts chunks into `knowledge_chunks` with embeddings
2. Auto-ingest: Hook into `changelog-append.sh` to also write to Postgres
3. Memory search: Replace file-based `memory_search` with pgvector similarity query:
   ```sql
   SELECT kc.content, kd.title, 1 - (kc.embedding <=> query_embedding) AS similarity
   FROM knowledge_chunks kc
   JOIN knowledge_documents kd ON kc.document_id = kd.id
   ORDER BY kc.embedding <=> query_embedding
   LIMIT 10;
   ```

**Estimated effort:** 5-6 hours (embedding integration is the main variable)
**Risks:** MEDIUM — pgvector embeddings need a source; if local embedding model isn't fast enough, use API-based embeddings. 768-dim vectors are ~3KB each, negligible storage.

#### Phase 4: Shared State & Task Queue

**Files to migrate:** agent-specific JSON state files, task queue data
**Tables:** `agent_shared_state`, `state_task_queue`

**Approach:**
- `agent_shared_state` uses the existing versioned key-value pattern
- UPSERT pattern with optimistic locking on `version` column:
  ```sql
  INSERT INTO agent_shared_state (state_key, state_value, version, updated_by)
  VALUES ('ticket-cache', '{"lastSync":"2026-05-23"}'::jsonb, 1, 'agent:tarkin')
  ON CONFLICT (state_key) DO UPDATE
  SET state_value = EXCLUDED.state_value,
      version = agent_shared_state.version + 1,
      updated_at = NOW(),
      updated_by = EXCLUDED.updated_by
  WHERE agent_shared_state.version = 1;  -- optimistic lock
  ```
- If version mismatch → retry or escalate
- `state_task_queue` already populated (4 rows); extend columns to use proper types (timestamptz, jsonb for atoms)

**Estimated effort:** 6-8 hours
**Risks:** HIGH — Task queue is the operational backbone. Failure here blocks all async agent work.

#### Phase 5: Validation & Cutover

**Approach:**
- Dual-write for 48 hours: agents write to both files and Postgres
- Compare file state vs DB state at 24h and 48h checkpoints
- Fix discrepancies
- Switch agents to read-from-DB with file fallback
- Run rollback drill: simulate PG outage, verify file fallback works

**Estimated effort:** 4-5 hours + 48h observation window
**Risks:** MEDIUM — Dual-write consistency gap possible. Mitigation: DB is authoritative after cutover, file is best-effort backup only.

#### Phase 6: Cleanup

- Archive `state/*.json` to `state/archive/` (not delete)
- Clean backup files (`*.bak-*`): keep last 7 days, archive rest
- Auto-heal logs: keep as files (append-only logs are better as files; JSON summaries go to Postgres)
- Update all scripts to use `db.sh` as primary, file as fallback

**Estimated effort:** 2 hours
**Risks:** LOW

### 1.5 Handling 90+ Backup Files

**Cleanup strategy:**
1. **Immediate:** Move all `*.bak-*` files to `state/backups/archive/`
2. **Retention:** Keep 7 days of backup files; auto-purge via cron weekly
3. **Before Postgres activation:** Archive `tickets.json.bak-*` files — the 173 tickets are in Postgres, these are redundant
4. **Pre-merge backups:** `tickets.json.bak-pre-dedup-*` and `tickets.json.pre-dedup-*` — archive as historical artifacts, not operational data

**Command:**
```bash
mkdir -p state/backups/archive
find state/ -name "*.bak-*" -exec mv {} state/backups/archive/ \;
```

### 1.6 Auto-Heal Logs: Keep as Files or Move to Postgres?

**Recommendation: Hybrid approach**

| Content | Storage | Reason |
|---------|---------|--------|
| Auto-heal JSON summaries | `agent_events` table | Queryable, joins with agent_decisions |
| Auto-heal raw logs (.log) | Keep as files in `state/autoheal-logs/` | Append-only, high-volume, not analytical |
| Daily JSON snapshots | `agent_shared_state` key `autoheal-status` | Single source of truth for current status |

The `.log` files are sequential write streams — perfect for files, terrible for database rows. The JSON summaries are the analytical artifacts that belong in Postgres.

---

## 2. Schema Design for Unified SSOT

### 2.1 Additional Tables Needed

Beyond the 14 existing tables, the following new tables are required for a complete SSOT:

```sql
-- T6 (Configuration Management): Structured config beyond JSONB blobs
CREATE TABLE config_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config_path TEXT NOT NULL,           -- e.g., 'agents.aria.model'
    config_value JSONB NOT NULL,
    value_type TEXT NOT NULL DEFAULT 'json', -- 'string', 'number', 'boolean', 'json', 'array'
    description TEXT,
    source_file TEXT,                     -- Original TOML/YAML file
    is_secret BOOLEAN DEFAULT false,      -- For masked values
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    updated_by TEXT,
    tenant_id TEXT DEFAULT 'ainchors',
    UNIQUE(config_path, tenant_id)
);

-- T6: Changelog audit
CREATE TABLE changelog (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    change_id TEXT NOT NULL,              -- e.g., 'CHG-0389'
    description TEXT,
    affected_systems TEXT[],              -- Array: {'tickets', 'cost', 'model_policy'}
    change_type TEXT,                     -- 'config', 'schema', 'policy', 'infrastructure'
    author TEXT,
    approved_by TEXT,
    applied_at TIMESTAMPTZ DEFAULT now(),
    reverted_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'::jsonb,
    tenant_id TEXT DEFAULT 'ainchors'
);

-- T6: Agent registry (canonical agent list, supersedes file-based tracking)
CREATE TABLE agent_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id TEXT NOT NULL UNIQUE,        -- e.g., 'agent:yoda'
    agent_name TEXT NOT NULL,             -- 'Yoda'
    tier INTEGER NOT NULL CHECK (tier BETWEEN 0 AND 4),
    model_preference TEXT,
    capabilities TEXT[],                  -- Array: {'ticket_ops', 'cost_tracking', 'memory_search'}
    status TEXT DEFAULT 'active',         -- 'active', 'paused', 'deprecated'
    budget_limit NUMERIC(10,4),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    tenant_id TEXT DEFAULT 'ainchors'
);

-- T6: Cost tracking (structured, replacing single JSONB row in state_cost)
CREATE TABLE cost_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_date DATE NOT NULL,
    model_id TEXT NOT NULL,
    agent_id TEXT,
    input_tokens INTEGER DEFAULT 0,
    output_tokens INTEGER DEFAULT 0,
    cost_usd NUMERIC(10,6) DEFAULT 0,
    source TEXT,                          -- 'api', 'ollama', 'manual'
    tenant_id TEXT DEFAULT 'ainchors'
);
CREATE INDEX idx_cost_events_date ON cost_events(event_date DESC);
CREATE INDEX idx_cost_events_agent ON cost_events(agent_id, event_date);

-- T6: Notification/alert state
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    severity TEXT NOT NULL CHECK (severity IN ('info', 'warning', 'critical')),
    source_agent TEXT,
    title TEXT NOT NULL,
    body TEXT,
    acknowledged BOOLEAN DEFAULT false,
    acknowledged_by TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    tenant_id TEXT DEFAULT 'ainchors'
);

-- Extend existing tables with missing columns
ALTER TABLE state_task_queue 
  ADD COLUMN IF NOT EXISTS created_at_ts TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at_ts TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS atoms_jsonb JSONB,
  ADD COLUMN IF NOT EXISTS tenant_id TEXT DEFAULT 'ainchors';

ALTER TABLE state_tickets
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now(),
  ADD COLUMN IF NOT EXISTS assigned_to TEXT,
  ADD COLUMN IF NOT EXISTS tags TEXT[],
  ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

ALTER TABLE knowledge_documents
  ADD COLUMN IF NOT EXISTS content TEXT,    -- Full text of small documents
  ADD COLUMN IF NOT EXISTS tags TEXT[],
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();
```

### 2.2 Handling Config Files (TOML/YAML) in Relational Tables

**Strategy: Two-tier approach**

**Tier 1 — `config_entries` table (structured, queryable):**
Parse TOML/YAML into individual config paths. Example:

```yaml
# agents.yaml (conceptual)
agents:
  aria:
    model: ollama/gemma4:31b-cloud
    tier: 2
    thinking: off
```

Becomes:

```sql
INSERT INTO config_entries (config_path, config_value, value_type, source_file) VALUES
('agents.aria.model', '"ollama/gemma4:31b-cloud"', 'string', 'agents.yaml'),
('agents.aria.tier', '2', 'number', 'agents.yaml'),
('agents.aria.thinking', 'false', 'boolean', 'agents.yaml');
```

**Tier 2 — `state_config_baseline` (JSONB blob, backward compat):**
Keep the raw TOML/YAML as JSONB for agents that need the full document:
```sql
UPDATE state_config_baseline 
SET data = jsonb_build_object(
  'source', 'agents.yaml',
  'raw', '<yaml content as JSON>',
  'parsed_at', now()
);
```

**Config write pattern:**
```sql
-- Agent updates a single config value
INSERT INTO config_entries (config_path, config_value, value_type, updated_by)
VALUES ('agents.aria.model', '"ollama/deepseek-v4-pro:cloud"', 'string', 'agent:yoda')
ON CONFLICT (config_path, tenant_id) DO UPDATE
SET config_value = EXCLUDED.config_value,
    updated_at = NOW(),
    updated_by = EXCLUDED.updated_by;
```

### 2.3 Memory Files → knowledge_documents/knowledge_chunks Mapping

| File Pattern | knowledge_documents.title | knowledge_documents.source_path | Chunking Strategy |
|-------------|--------------------------|--------------------------------|-------------------|
| `memory/YYYY-MM-DD.md` (daily logs) | `journal-YYYY-MM-DD` | Full path | By `## ` section headers |
| `memory/journal-*.summary.md` | `summary-YYYY-MM-DD` | Full path | Single chunk (short) |
| `memory/shared/*.md` | `shared-{filename}` | Full path | By section |
| `MEMORY.md` | `long-term-memory` | Full path | By `### ` subsection |

**Metadata enrichment during ingestion:**

```sql
INSERT INTO knowledge_documents (title, source_path, mime_type, content, tags, tenant_id)
VALUES (
  'journal-2026-05-22',
  '/Users/ainchorsangiefpl/.openclaw/workspace/memory/journal-2026-05-22.md',
  'text/markdown',
  '<full content>',
  ARRAY['daily-log', 'journal', '2026-05-22'],
  'ainchors'
);
```

### 2.4 Indexing Strategy for Agent Query Patterns

**Phase 0 indexes (critical path, before agents connect):**

```sql
-- Primary key indexes already exist (15 total)

-- Agent event queries: "What did agent X do in the last hour?"
CREATE INDEX idx_agent_events_agent_ts 
  ON agent_events(agent_id, timestamp DESC);

-- Decision queries: "What decisions did agent X make?"
CREATE INDEX idx_agent_decisions_agent_ts 
  ON agent_decisions(agent_id, timestamp DESC);

-- Session queries: "Which sessions are active?"
CREATE INDEX idx_agent_sessions_agent_status 
  ON agent_sessions(agent_id, status);
CREATE INDEX idx_agent_sessions_status 
  ON agent_sessions(status) WHERE status = 'active';

-- State lookups: "Get value for key X"
-- (UNIQUE constraint on state_key already handles this)

-- Ticket queries: "Show all open tickets"
CREATE INDEX idx_state_tickets_status 
  ON state_tickets(status);
CREATE INDEX idx_state_tickets_priority 
  ON state_tickets(priority);

-- Task queue: "Next pending task"
CREATE INDEX idx_state_task_queue_status 
  ON state_task_queue(status) WHERE status = 'pending';
CREATE INDEX idx_state_task_queue_priority 
  ON state_task_queue(priority);

-- Memory search: pgvector similarity index
CREATE INDEX idx_knowledge_chunks_embedding 
  ON knowledge_chunks 
  USING ivfflat (embedding vector_cosine_ops) 
  WITH (lists = 100);
-- Note: ivfflat is approximate; refine lists as chunk count grows
-- When chunk count > 1000, rebuild with:
--   lists = max(10, rows/1000)
-- For exact search on small datasets, don't create this index

-- Cost queries: "Costs for date range"
CREATE INDEX idx_cost_events_date_agent 
  ON cost_events(event_date, agent_id);

-- Config lookups: "Get config value for path"
-- (UNIQUE constraint on config_path handles this)

-- Changelog: "Recent changes"
CREATE INDEX idx_changelog_applied_at 
  ON changelog(applied_at DESC);

-- Full-text search for knowledge documents
CREATE INDEX idx_knowledge_docs_content_fts 
  ON knowledge_documents 
  USING gin(to_tsvector('english', COALESCE(content, '')));
```

**Index maintenance:**
- `REINDEX` on ivfflat index after bulk inserts (it's not incrementally updated well)
- `VACUUM ANALYZE` daily after ingestion
- Monitor index sizes: `SELECT pg_size_pretty(pg_total_relation_size('idx_name'));`

### 2.5 JSONB vs Normalized Columns: When to Use Each

| Use JSONB When... | Use Normalized Columns When... |
|-------------------|-------------------------------|
| Schema is fluid/evolving | Schema is stable |
| Data is queried as whole document | Data is queried by individual fields |
| Nested structures are common | Flat structure with relational joins |
| Backward compat with file-based readers (state_v) | Performance-critical queries with WHERE clauses |
| Rarely filtered/joined | Frequently filtered, sorted, or joined |
| **Example: agent_shared_state.state_value** | **Example: state_tickets.status, priority** |
| **Example: agent_events.payload** | **Example: agent_sessions.agent_id, status** |
| **Example: config_entries.config_value** | **Example: cost_events.event_date, model_id** |

**Specific recommendations for existing tables:**

| Table | Column | JSONB or Normalized? | Reason |
|-------|--------|---------------------|--------|
| state_tickets | All current | Normalized → **Good** | Queried by status, priority, id |
| state_tickets | metadata (new) | JSONB | Extensible without schema changes |
| state_cost | data | JSONB → **Migrate to cost_events** | Cost should be queryable by date/model |
| state_model_policy | All | JSONB-flavored text → **Migrate to config_entries** | Structured config management |
| state_config_baseline | data | JSONB → **Keep + add config_entries** | Both: blob for compat, entries for queries |
| agent_events | payload | JSONB → **Good** | Variable event data |
| agent_decisions | context | JSONB → **Good** | Variable decision context |
| agent_shared_state | state_value | JSONB → **Good** | Key-value store, variable shapes |
| state_task_queue | atoms | text → **Migrate to atoms_jsonb (JSONB)** | Need to query atom statuses |

### 2.6 state_v View Pattern for Backward Compatibility

The `state_v` schema already exists with 2 views. Extend to cover all state tables:

```sql
-- state_v.tickets — mirrors old tickets.json structure
CREATE OR REPLACE VIEW state_v.tickets AS
SELECT jsonb_build_object(
  'tickets', jsonb_agg(
    jsonb_build_object(
      'id', id, 'sequence', sequence, 'title', title,
      'status', status, 'priority', priority, 'type', type,
      'createdAt', createdat, 'notionPageId', notionpageid, 'url', url
    ) ORDER BY id
  )
) AS data FROM state_tickets;

-- state_v.model_policy — mirrors model-policy.json
CREATE OR REPLACE VIEW state_v.model_policy AS
SELECT row_to_json(state_model_policy.*)::jsonb AS data
FROM state_model_policy;

-- state_v.cost_state — EXISTS ✓
-- state_v.config_baseline — EXISTS ✓

-- state_v.task_queue — mirrors task-queue.json
CREATE OR REPLACE VIEW state_v.task_queue AS
SELECT jsonb_build_object(
  'tasks', jsonb_agg(
    jsonb_build_object(
      'id', id, 'title', title, 'tier', tier,
      'status', status, 'priority', priority,
      'source', source, 'atoms', 
      CASE WHEN atoms_jsonb IS NOT NULL THEN atoms_jsonb ELSE atoms::jsonb END
    ) ORDER BY id
  )
) AS data FROM state_task_queue;

-- state_v.shared_state — key-value lookup
CREATE OR REPLACE VIEW state_v.shared_state AS
SELECT jsonb_object_agg(state_key, state_value) AS data
FROM agent_shared_state;

-- state_v.agent_status — mirrors agent-status.json
CREATE OR REPLACE VIEW state_v.agent_status AS
SELECT jsonb_object_agg(agent_id, 
  jsonb_build_object('name', agent_name, 'tier', tier, 'status', status)
) AS data FROM agent_registry WHERE status = 'active';
```

**Compatibility contract:** Any agent reading `state/filename.json` today can instead query:
```sql
SELECT data FROM state_v.<view_name>;
```
And get the same JSON structure it expects.

---

## 3. Agent Read/Write Architecture

### 3.1 Connectivity Model

**Decision: `psql` CLI wrapper (`db.sh`), not REST API**

Rationale:
- Agents already use shell commands (`exec` tool) for everything
- Adding a REST API layer adds latency, another service to maintain, and another failure mode
- `psql` is already installed and tested on OC1 (PostgreSQL 16.14 via Homebrew)
- Direct `psql` gives agents the full power of SQL (JSONB queries, aggregations, CTEs)
- Zero network overhead via Unix socket (`/tmp/.s.PGSQL.5432`)

**Architecture:**

```
Agent (tool call) → exec("db.sh -c '...'") → psql → PostgreSQL (Unix socket)
                                              ↓ (fallback)
                                         read/write state/*.json
```

**Connection string:** Standard Unix socket — no network overhead, no credentials needed (same OS user).

### 3.2 Connection Pooling

**Current state:** `max_connections=100` — sufficient for 14 agents + growth to 30+

**Recommendation:** Start without pgbouncer. Add it only if:
- Agent count exceeds 50
- Connection churn becomes visible (>100 connects/second)
- Memory pressure from idle connections

**Connection management:**
- Each `db.sh` call opens and closes a connection — stateless, safe
- For agents that need multiple sequential queries, use `db.sh` with heredoc:
  ```bash
  db.sh <<'SQL'
  BEGIN;
  SELECT ...;
  INSERT ...;
  COMMIT;
  SQL
  ```

### 3.3 Access Control Matrix

Building on TKT-0196 work types, using PostgreSQL role-based access:

```sql
-- Roles
CREATE ROLE agent_readonly;
CREATE ROLE agent_readwrite;
CREATE ROLE agent_admin;

-- Agent-tier mapping
-- T0 (Yoda): agent_admin
-- T1 (Tarkin, Thrawn): agent_readwrite  
-- T2 (Aria, Andor, Krennic): agent_readwrite
-- T3 (subagents): agent_readonly
-- T4 (utility agents): agent_readonly

-- Table-level grants
GRANT SELECT ON ALL TABLES IN SCHEMA public TO agent_readonly;
GRANT SELECT, INSERT, UPDATE ON agent_events, agent_decisions, 
  decision_lineage, agent_sessions, agent_shared_state, 
  agent_state_history, memory_access_log TO agent_readwrite;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO agent_admin;

-- state_v views: read-only access for backward compat
GRANT SELECT ON ALL TABLES IN SCHEMA state_v TO agent_readonly;
```

**Per-agent access:**

| Agent | Tier | Reads | Writes |
|-------|------|-------|--------|
| Yoda | T0 | All tables | All tables |
| Tarkin | T1 | All | events, sessions, shared_state, task_queue |
| Thrawn | T1 | All | events, decisions, lineage, state_history |
| Aria | T2 | state_v views, knowledge_* | agent_events, sessions |
| Cost Tracker | T2 | state_v.cost_state, cost_events | cost_events |
| Ticket Manager | T2 | state_v.tickets, state_tickets | state_tickets |
| Subagents | T3 | state_v views only | None (write via parent) |
| Utility agents | T4 | state_v views only | None |

### 3.4 Write Patterns

#### INSERT vs UPSERT by Table

| Table | Pattern | Rationale |
|-------|---------|-----------|
| agent_events | **INSERT only** | Immutable audit log |
| agent_decisions | **INSERT only** | Immutable decisions |
| decision_lineage | **INSERT only** | Immutable relationships |
| agent_sessions | **INSERT + UPDATE** (status, ended_at) | Session lifecycle |
| agent_shared_state | **UPSERT with version lock** | Key-value state store |
| agent_state_history | **INSERT (triggered)** | Auto-insert on shared_state change |
| state_tickets | **UPSERT by id** | Tickets evolve |
| state_cost | **UPDATE** | Single-row aggregate |
| state_config_baseline | **UPDATE** | Single-row config |
| memory_access_log | **INSERT only** | Immutable access log |
| knowledge_documents | **UPSERT by source_path** | Re-ingestion updates |
| knowledge_chunks | **DELETE + INSERT** (per document) | Chunks change on re-ingestion |
| cost_events | **INSERT only** | Immutable cost records |
| config_entries | **UPSERT by (config_path, tenant_id)** | Config values update in place |
| changelog | **INSERT only** | Immutable change record |
| notifications | **INSERT + UPDATE** (acknowledged) | Notification lifecycle |

#### Optimistic Locking via Version Column

`agent_shared_state` is the only table needing concurrency control. Pattern:

```sql
-- Read current version
SELECT version FROM agent_shared_state WHERE state_key = 'ticket-cache';

-- Write with version check (returns 0 rows if version changed by another agent)
UPDATE agent_shared_state
SET state_value = '{"lastSync":"2026-05-23T10:00:00Z"}'::jsonb,
    version = version + 1,
    updated_at = NOW(),
    updated_by = 'agent:tarkin'
WHERE state_key = 'ticket-cache' AND version = 1;

-- If 0 rows updated → conflict → agent re-reads, merges, retries
```

#### Trigger for Automatic History

```sql
CREATE OR REPLACE FUNCTION record_state_change()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO agent_state_history (state_id, state_value, version, changed_by)
  VALUES (NEW.id, NEW.state_value, NEW.version, NEW.updated_by);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger if not already present
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_state_history') THEN
    CREATE TRIGGER trg_state_history
      AFTER UPDATE ON agent_shared_state
      FOR EACH ROW
      EXECUTE FUNCTION record_state_change();
  END IF;
END $$;
```

### 3.5 Read Patterns

#### Cached Reads

For high-read, low-write data (cost, config, policy):
- Agent reads from Postgres on first access
- Caches in-memory for remainder of session
- Re-reads only if cache age > 5 minutes

#### Polling Intervals

| Data | Poll Interval | Rationale |
|------|--------------|-----------|
| Ticket state | 60s | Tickets change slowly |
| Task queue | 15s | Async tasks need faster reaction |
| Agent sessions | On spawn/despawn only | Event-driven, not polled |
| Shared state | 30s | Config changes are rare |
| Cost state | 300s | Cost updates are daily |
| Notifications | 60s | Alerts should be seen within a minute |

#### LISTEN/NOTIFY Pattern (see Section 4)

For real-time updates, agents subscribe to channels and react to notifications instead of polling.

### 3.6 state_v Views for Backward Compatibility

The `state_v` schema already exists with 2 views. Extend to cover all state tables (see Section 2.6 for full view definitions).

**Compatibility contract:** Any agent reading `state/filename.json` today can instead query `SELECT data FROM state_v.<view_name>` and get the same JSON structure it expects.

---

## 4. Sync & Real-Time Patterns

### 4.1 LISTEN/NOTIFY Design

PostgreSQL's `LISTEN`/`NOTIFY` provides real-time, push-based event distribution. This is the primary mechanism for inter-agent coordination after migration.

#### Channel Design

| Channel | Trigger Event | Payload | Subscribers |
|---------|--------------|---------|-------------|
| `ticket_changed` | INSERT/UPDATE on state_tickets | `{"id":"TKT-0201","status":"done","op":"UPDATE"}` | Tarkin, Aria, Ticket Manager |
| `task_queued` | INSERT on state_task_queue | `{"id":"task-...","title":"...","priority":"high"}` | Yoda, all T1 agents |
| `task_claimed` | UPDATE status→claimed | `{"id":"task-...","agent":"agent:tarkin"}` | Yoda (orchestration), Tarkin |
| `task_completed` | UPDATE status→complete | `{"id":"task-...","result":"ok"}` | Yoda |
| `state_changed` | UPDATE on agent_shared_state | `{"key":"ticket-cache","version":2}` | All agents reading that key |
| `cost_updated` | INSERT on cost_events | `{"date":"2026-05-23","total":"$4.23"}` | Cost Tracker, Yoda, Tarkin |
| `session_started` | INSERT on agent_sessions | `{"agent_id":"agent:aria","session_key":"..."}` | Yoda (monitoring) |
| `session_ended` | UPDATE ended_at | `{"agent_id":"agent:aria","duration_sec":120}` | Yoda |
| `decision_made` | INSERT on agent_decisions | `{"id":"uuid","agent":"agent:thrawn","type":"architecture"}` | Tarkin, Yoda |
| `knowledge_ingested` | INSERT on knowledge_documents | `{"title":"journal-2026-05-23","chunks":5}` | Aria, Yoda |
| `alert_raised` | INSERT on notifications WHERE severity='critical' | `{"title":"PG outage detected"}` | All T1 agents |
| `config_changed` | UPDATE on config_entries | `{"path":"agents.aria.model","new_value":"..."}` | Affected agent, Yoda |

#### NOTIFY Trigger Implementation

```sql
-- Ticket change notification
CREATE OR REPLACE FUNCTION notify_ticket_change()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM pg_notify('ticket_changed', 
    json_build_object(
      'id', COALESCE(NEW.id, OLD.id),
      'status', NEW.status,
      'title', NEW.title,
      'op', TG_OP
    )::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ticket_notify
  AFTER INSERT OR UPDATE ON state_tickets
  FOR EACH ROW EXECUTE FUNCTION notify_ticket_change();

-- Task queue notification
CREATE OR REPLACE FUNCTION notify_task_change()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM pg_notify('task_queued', 
      json_build_object('id', NEW.id, 'title', NEW.title, 'priority', NEW.priority)::text);
  ELSIF NEW.status = 'claimed' AND OLD.status = 'pending' THEN
    PERFORM pg_notify('task_claimed', 
      json_build_object('id', NEW.id, 'agent', NEW.claimedby)::text);
  ELSIF NEW.status = 'complete' AND OLD.status != 'complete' THEN
    PERFORM pg_notify('task_completed', 
      json_build_object('id', NEW.id, 'result', 'ok')::text);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_task_notify
  AFTER INSERT OR UPDATE ON state_task_queue
  FOR EACH ROW EXECUTE FUNCTION notify_task_change();

-- Shared state notification
CREATE OR REPLACE FUNCTION notify_state_change()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM pg_notify('state_changed',
    json_build_object('key', NEW.state_key, 'version', NEW.version)::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_state_notify
  AFTER UPDATE ON agent_shared_state
  FOR EACH ROW EXECUTE FUNCTION notify_state_change();

-- Alert notification for critical events
CREATE OR REPLACE FUNCTION notify_critical_alert()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.severity = 'critical' THEN
    PERFORM pg_notify('alert_raised',
      json_build_object('id', NEW.id, 'title', NEW.title)::text);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_alert_notify
  AFTER INSERT ON notifications
  FOR EACH ROW EXECUTE FUNCTION notify_critical_alert();
```

#### Agent LISTEN Implementation

Agents subscribe via a polling wrapper that uses LISTEN with a timeout:

```bash
#!/bin/bash
# db-listen.sh — Listen for NOTIFY events with timeout
# Usage: db-listen.sh ticket_changed,state_changed 30
CHANNELS=$1
TIMEOUT=${2:-30}

# Subscribe to channels
IFS=',' read -ra CHAN_ARRAY <<< "$CHANNELS"
for chan in "${CHAN_ARRAY[@]}"; do
  psql -U ainchorsangiefpl -d ainchors_nexus -c "LISTEN $chan;" 2>/dev/null
done

# Wait for notifications with timeout
# pg_notify doesn't queue across connections, so we need a persistent connection
# For agents: use a keep-alive psql process or polling-based approach

# Simpler approach for agents: polling with sleep
for ((i=0; i<TIMEOUT; i+=5)); do
  RESULT=$(psql -U ainchorsangiefpl -d ainchors_nexus -t -A -c "
    SELECT json_agg(json_build_object('channel', channel, 'payload', payload))
    FROM (SELECT pg_notification_queue_usage()) t;
  " 2>/dev/null)
  if [ -n "$RESULT" ] && [ "$RESULT" != "null" ]; then
    echo "$RESULT"
    exit 0
  fi
  sleep 5
done
```

**Production recommendation:** For agents that need true real-time behavior, use a persistent `psql` process with `LISTEN` in a background exec, and poll for notifications from the main agent loop.

### 4.2 Polling Fallback

Agents that can't use LISTEN/NOTIFY (e.g., stateless T3 subagents) use polling with version checks:

```
┌──────────────┐         ┌──────────────┐
│ Polling Agent │ ──15s──→│ PostgreSQL    │
│ (T3 subagent) │ ←──data─│               │
└──────────────┘         └──────────────┘

┌──────────────┐         ┌──────────────┐
│ Push Agent    │ LISTEN──│ PostgreSQL    │
│ (T1/T2)       │ ←NOTIFY─│               │
└──────────────┘         └──────────────┘
```

**Polling implementation:**
```bash
#!/bin/bash
# db-poll.sh — Poll a state key with version check
STATE_KEY="$1"
LAST_VERSION="${2:-0}"
psql -U ainchorsangiefpl -d ainchors_nexus -t -A -c "
  SELECT state_value::text, version 
  FROM agent_shared_state 
  WHERE state_key = '$STATE_KEY' AND version > $LAST_VERSION;
"
# If output → state changed, agent processes update
# If no output → no change, agent skips
```

### 4.3 Handling Writes During Migration (Dual-Write)

**Phase 2-4: Dual-write period**

```
Agent Write ──→ db.sh (Postgres) ──→ PostgreSQL  ← PRIMARY
            └──→ write(state/file.json) ──→ Filesystem ← FALLBACK
```

**Implementation in scripts:**

```bash
# ticket.sh — Dual-write pattern for create/update
create_ticket() {
  local ticket_json="$1"
  
  # PRIMARY: Write to Postgres
  echo "$ticket_json" | psql -U ainchorsangiefpl -d ainchors_nexus -c "
    INSERT INTO state_tickets (id, title, status, priority, type, createdat)
    SELECT id, title, status, priority, type, createdat
    FROM jsonb_to_recordset('[$ticket_json]'::jsonb) 
    AS x(id text, title text, status text, priority text, type text, createdat text)
    ON CONFLICT (id) DO UPDATE 
    SET status = EXCLUDED.status, title = EXCLUDED.title, updated_at = NOW();
  " 2>/dev/null && echo "[OK] Written to Postgres" || echo "[FALLBACK] PG write failed"
  
  # FALLBACK: Also write to file (during transition)
  local tickets_file="state/tickets.json"
  if [ -f "$tickets_file" ]; then
    # Append to existing file's tickets array (simplified — production would use jq)
    echo "$ticket_json" >> "$tickets_file.fallback" 2>/dev/null || true
  fi
}
```

**Read priority during transition:**
1. Try Postgres (`state_v` view)
2. If PG unavailable → fall back to `state/*.json` file
3. If both fail → return error

### 4.4 Conflict Resolution

**Scenario: Two agents write to same shared_state key simultaneously**

```
Time:  Agent A reads version=1     Agent B reads version=1
       Agent A writes (version=1)  Agent B writes (version=1)
       → UPDATE succeeds           → UPDATE returns 0 rows (version now 2)
       → version becomes 2         → Agent B detects conflict, re-reads
                                   → Agent B retries with version=2
```

**Resolution strategies (depends on data type):**

| Conflict Type | Strategy | Example |
|--------------|----------|---------|
| Config/policy values | **Last-write-wins** (retry with fresh version) | Model policy update |
| Lists (tickets, tasks) | **JSONB merge** (`||` operator) | Adding tickets to cache |
| Atomic claims (tasks) | **Exactly-once** (WHERE status='pending') | Task claim |
| Counters | **Increment** (`value + 1`) not read-modify-write | Session count |

**Implementation:**

```sql
-- Strategy 1: Last-write-wins (retry)
-- Agent retries the UPDATE with the new version after conflict

-- Strategy 2: JSONB merge for list data
UPDATE agent_shared_state
SET state_value = state_value || '{"newTickets": [...]}'::jsonb,
    version = version + 1,
    updated_at = NOW()
WHERE state_key = 'ticket-cache';

-- Strategy 3: Exactly-once claim (atomic — no version needed)
UPDATE state_task_queue
SET status = 'claimed', claimedby = 'agent:tarkin', claimedat = NOW()::text
WHERE id = 'task-001' AND status = 'pending';
-- If 0 rows updated → someone else claimed it first → agent moves to next task

-- Strategy 4: Atomic increment
UPDATE agent_shared_state
SET state_value = jsonb_set(state_value, '{sessionCount}', 
                   to_jsonb((state_value->>'sessionCount')::int + 1)),
    version = version + 1
WHERE state_key = 'metrics';
```

---

## 5. Backward Compatibility & Transition

### 5.1 Coexistence Model

During transition (Phases 1-5), file-based and Postgres-based agents coexist:

```
┌──────────────────────────────────────────┐
│              Yoda (T0 Orchestrator)        │
│         Reads/Writes: Postgres             │
│         Fallback: Files                    │
└──────────────┬───────────────────────────┘
               │
    ┌──────────┼──────────┐
    ▼          ▼          ▼
┌─────────┐ ┌─────────┐ ┌──────────┐
│ Tarkin  │ │ Thrawn  │ │ Aria     │
│ PG+File │ │ PG+File │ │ PG+File  │
└─────────┘ └─────────┘ └──────────┘
    │          │          │
    ▼          ▼          ▼
┌─────────┐ ┌─────────┐ ┌──────────┐
│ T3 Subs │ │ T3 Subs │ │ T3 Subs  │
│ Files   │ │ Files   │ │ Files    │  ← Still file-based initially
└─────────┘ └─────────┘ └──────────┘
```

**Rule:** T0-T2 agents get Postgres access first. T3 subagents continue reading files via the state_v pattern until Phase 5 cutover.

### 5.2 state_v View Pattern

The `state_v` schema provides file-identical JSON output via SQL views. An agent that previously read:

```
read("state/tickets.json") → {"tickets": [...]}
```

Now does:

```sql
SELECT data FROM state_v.tickets; → {"tickets": [...]}
```

Same JSON shape, different source. No agent code changes needed for the read path — only the tool call changes from `read` to `exec("db.sh -c 'SELECT data FROM state_v.tickets'")`.

**Full list of state_v views:**

| View | Mirrors File | JSON Structure |
|------|-------------|----------------|
| `state_v.tickets` | `state/tickets.json` | `{"tickets": [...]}` |
| `state_v.cost_state` ✓ | `state/cost-baseline.json` | `{"data": {...}}` |
| `state_v.config_baseline` ✓ | `state/config-baseline.json` | `{"data": {...}}` |
| `state_v.model_policy` | `state/model-policy.json` | Full row as JSON |
| `state_v.task_queue` | `state/async-tasks.json` | `{"tasks": [...]}` |
| `state_v.shared_state` | Various agent state files | `{"key1": val1, "key2": val2}` |
| `state_v.agent_status` | `state/agent-status.json` | `{"agent:yoda": {...}, ...}` |

✓ = already exists

### 5.3 Cutover Strategy

**For each agent, switch in this order:**

1. **Read path:** Switch from `read(state/file.json)` to `exec("db.sh -c 'SELECT data FROM state_v.<view>'")`
2. **Verify:** Agent reads Postgres data, confirms it matches expected JSON structure
3. **Write path:** Switch from `write(state/file.json)` to `exec("db.sh -c 'INSERT/UPDATE ...'")`
4. **Observe:** 24-hour monitoring period with data parity checks
5. **Decommission file write:** Remove fallback file writes (keep files as archive)

**Agent cutover sequence (staged):**

| Week | Agents | Change |
|------|--------|--------|
| Week 5 | Yoda (T0) | Full Postgres read+write |
| Week 5 | Cost Tracker (T2) | Full Postgres read+write |
| Week 5 | Ticket Manager (T2) | Full Postgres (already writing) |
| Week 5 | Tarkin (T1) | Read PG via state_v, write both |
| Week 6 | Thrawn (T1) | Read PG via state_v, write both |
| Week 6 | Aria (T2) | Read PG via state_v, file writes |
| Week 6 | Andor, Krennic (T2) | Read PG via state_v |
| Week 6 | All T3 subagents | Read PG via state_v (no writes) |
| Week 6 | T4 utility agents | Read PG via state_v |

### 5.4 Rollback Plan

If Postgres becomes unavailable:

```
┌─────────────────────────────────────────────────┐
│ DETECT: Agent write to PG fails                  │
│   ↓                                              │
│ TRY: Retry 3 times with exponential backoff      │
│   ↓ (all fail)                                   │
│ ALERT: Log to notifications table (if PG up)     │
│        OR write to agent_events file             │
│   ↓                                              │
│ FALLBACK: Write to state/*.json file instead     │
│   - Use state/pg-fallback-{timestamp}.json       │
│   ↓                                              │
│ RECOVER: When PG returns, replay file writes     │
│   via replay-fallback-to-pg.sh                   │
└─────────────────────────────────────────────────┘
```

**Fallback write pattern in scripts:**

```bash
write_with_fallback() {
  local sql="$1"
  local fallback_file="$2"
  local fallback_data="$3"
  
  if ! echo "$sql" | psql -U ainchorsangiefpl -d ainchors_nexus 2>/dev/null; then
    echo "[WARN] PG unavailable, writing to fallback file: $fallback_file"
    echo "$fallback_data" >> "$fallback_file"
    
    # Log the fallback event
    echo "$(date -Iseconds) | PG_FALLBACK | $fallback_file" >> state/pg-fallback.log
    
    return 1
  fi
  return 0
}
```

**Replay script:**

```bash
#!/bin/bash
# replay-fallback-to-pg.sh — Replay file-based writes to Postgres after outage
FALLBACK_DIR="state/pg-fallback"
for f in "$FALLBACK_DIR"/*.json; do
  [ -f "$f" ] || continue
  echo "Replaying: $f"
  # Parse and replay based on file naming convention
  case "$f" in
    *ticket*) 
      cat "$f" | psql -U ainchorsangiefpl -d ainchors_nexus -c "
        INSERT INTO state_tickets SELECT * FROM jsonb_populate_recordset(NULL::state_tickets, pg_read_file('$f')::jsonb)
        ON CONFLICT (id) DO NOTHING;"
      ;;
    *state*)
      # Parse key from filename and upsert
      ;;
  esac
  mkdir -p "$FALLBACK_DIR/replayed"
  mv "$f" "$FALLBACK_DIR/replayed/"
done
```

**Full rollback (nuclear option):**
1. Stop all agent Postgres writes
2. Restore files from `state/` directory (files are kept in parallel during transition)
3. Agents revert to file-based reads/writes
4. Postgres outage is diagnosed and fixed
5. Replay PG writes from files when recovered

**Rollback thresholds:**
- **Automatic fallback:** Individual PG query failure → retry 3x → use file
- **Partial rollback (single agent):** Agent's PG queries failing >50% → revert agent to file-only
- **Full rollback:** PG unavailable >5 minutes → all agents revert to file-only mode

---

## 6. OC2 HA & Future Readiness

### 6.1 PostgreSQL Replication Strategy for OC2

OC2 (arriving July 2026) will serve as the HA standby. 

**Recommended: Streaming Replication (Primary-Standby)**

```
OC1 (Mac Mini M4, 24GB)          OC2 (arriving Jul 2026)
┌─────────────────────┐         ┌─────────────────────┐
│ PostgreSQL 16        │  WAL    │ PostgreSQL 16        │
│ PRIMARY (read/write) │ ──────→ │ STANDBY (read-only)  │
│                      │ stream  │                      │
│ pgvector 0.8.2       │         │ pgvector 0.8.2       │
│                      │         │                      │
│ All agent writes ────┤         │ Read-only queries    │
│ (14+ agents)         │         │ (dashboards, reports) │
└─────────────────────┘         └─────────────────────┘
```

**Configuration:**

On OC1 (primary), add to `postgresql.conf`:
```ini
wal_level = replica
max_wal_senders = 3
wal_keep_size = 1GB
archive_mode = on
archive_command = 'cp %p /Users/ainchorsangiefpl/.openclaw/workspace/state/pg-wal-archive/%f'
```

On OC1, in `pg_hba.conf`:
```
# Allow replication connection from OC2
host replication ainchorsangiefpl oc2.local trust
```

On OC2 (initial setup):
```bash
# Stop any existing PG on OC2
brew services stop postgresql@16

# Clear data directory and sync from OC1
rm -rf /opt/homebrew/var/postgresql@16/data
pg_basebackup -h oc1.local -U ainchorsangiefpl -D /opt/homebrew/var/postgresql@16/data -P -R

# -R creates standby.signal file and adds connection settings
# Start PG on OC2 — it will be in standby mode
brew services start postgresql@16
```

**Replication options comparison:**

| Option | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| **Streaming replication** | Simple, built-in, real-time | Standby is read-only | **USE THIS** |
| Logical replication | Selective table replication | pgvector support TBD, more complex | Future consideration |
| Patroni HA | Automatic failover, etcd | Overkill for 2-node setup | Not needed yet |
| pgBackRest | Advanced PITR, parallel backup | Added complexity | Evaluate when DB >1GB |

### 6.2 Failover Process

```
STEP 1: DETECT — OC1 Postgres unresponsive (>30s)
  Health check: psql -h oc1 -c "SELECT 1" fails
  Alert: Yoda detects via heartbeat or NOTIFY timeout

STEP 2: DECIDE — Automated or manual?
  • OC1 hardware failure (power loss) → AUTOMATED failover
  • Network partition (OC1 running but unreachable) → MANUAL (avoid split-brain)

STEP 3: PROMOTE OC2
  $ ssh oc2 "pg_ctl promote -D /opt/homebrew/var/postgresql@16/data"
  OC2 becomes read/write primary
  Promotion time: ~5-10 seconds

STEP 4: RECONFIGURE AGENTS
  db.sh auto-detects primary:
    try OC1 → if pg_is_in_recovery() → try OC2
  Agents retry failed writes to new primary
  Any lost transactions: replay from OC1 WAL if recoverable

STEP 5: RECOVER OC1 (when fixed)
  pg_basebackup from OC2 → OC1
  OC1 becomes new standby
  Optional: switch back (manual promotion)

DOWNTIME TARGET: < 2 minutes
DATA LOSS WINDOW: Last un-replicated WAL segment (<1 second with streaming)
```

**Health check implementation:**

```bash
#!/bin/bash
# pg-health-check.sh — Check if PG is healthy on a given host
HOST="${1:-localhost}"
TIMEOUT=5

if psql -h "$HOST" -U ainchorsangiefpl -d ainchors_nexus -t -A -c "SELECT 1" --connect-timeout="$TIMEOUT" 2>/dev/null | grep -q "1"; then
  # Check if this host is primary (not in recovery)
  if psql -h "$HOST" -U ainchorsangiefpl -d ainchors_nexus -t -A -c "SELECT pg_is_in_recovery();" 2>/dev/null | grep -q "f"; then
    echo "PRIMARY_OK"
  else
    echo "STANDBY_OK"
  fi
else
  echo "DOWN"
fi
```

**Connection string management during failover:**

Agents use `db.sh` which auto-discovers the primary:

```bash
#!/bin/bash
# db.sh — Auto-discovering Postgres wrapper
PRIMARY=""
for HOST in oc1.local oc2.local; do
  if [ "$(pg-health-check.sh $HOST)" = "PRIMARY_OK" ]; then
    PRIMARY=$HOST
    break
  fi
done

if [ -z "$PRIMARY" ]; then
  echo "[ERROR] No PostgreSQL primary found" >&2
  exit 1
fi

psql -h "$PRIMARY" -U ainchorsangiefpl -d ainchors_nexus -t -A "$@"
```

### 6.3 Backup Strategy

**Layered approach:**

| Layer | Method | Frequency | Retention | Storage |
|-------|--------|-----------|-----------|---------|
| WAL Archiving | `archive_command` → disk | Continuous | 7 days | `state/pg-wal-archive/` |
| Logical backup | `pg_dump -Fc` | Daily 03:00 AEST | 30 days | `state/backups/pg/` |
| Physical backup | `pg_basebackup` | Weekly Sunday 04:00 | 4 weeks | External drive or OC2 |
| Offsite backup | `rclone` to cloud | Weekly | 12 weeks | Cloud storage (optional) |

**pg_dump script:**

```bash
#!/bin/bash
# pg-backup.sh — Scheduled PostgreSQL backup
BACKUP_DIR="/Users/ainchorsangiefpl/.openclaw/workspace/state/backups/pg"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RETENTION_DAYS=30

mkdir -p "$BACKUP_DIR"

# Logical backup (custom format, compressed)
pg_dump -U ainchorsangiefpl -d ainchors_nexus \
  --format=custom \
  --compress=9 \
  --file="$BACKUP_DIR/nexus-$TIMESTAMP.dump" \
  --verbose 2>> "$BACKUP_DIR/backup.log"

# Verify backup is valid
pg_restore --list "$BACKUP_DIR/nexus-$TIMESTAMP.dump" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "[$(date)] Backup OK: nexus-$TIMESTAMP.dump" >> "$BACKUP_DIR/backup.log"
else
  echo "[$(date)] BACKUP CORRUPT: nexus-$TIMESTAMP.dump" >> "$BACKUP_DIR/backup.log"
fi

# Cleanup old backups
find "$BACKUP_DIR" -name "nexus-*.dump" -mtime +$RETENTION_DAYS -delete
```

**Restore procedure (tested monthly):**

```bash
# 1. Create restore test database
createdb -U ainchorsangiefpl ainchors_nexus_restore_test

# 2. Restore from dump
pg_restore -U ainchorsangiefpl -d ainchors_nexus_restore_test \
  --clean --if-exists \
  "$BACKUP_DIR/nexus-20260523-030000.dump"

# 3. Verify
psql -U ainchorsangiefpl -d ainchors_nexus_restore_test -c "
  SELECT 'tickets', count(*) FROM state_tickets
  UNION ALL SELECT 'task_queue', count(*) FROM state_task_queue;
"

# 4. Clean up
dropdb -U ainchorsangiefpl ainchors_nexus_restore_test
```

### 6.4 Performance Considerations on M4 24GB

**Current sizing (8.7 MB database):**

| Metric | Current | Projected (6 months) | Projected (12 months) |
|--------|---------|---------------------|----------------------|
| Database size | 8.7 MB | ~100 MB | ~200 MB |
| Active connections | 2-3 | 14-20 | 25-35 |
| Queries/second | ~1 | ~50 | ~100 |
| WAL generation/day | Minimal | ~50 MB | ~100 MB |
| knowledge_chunks rows | 0 | ~500 | ~2000 |
| agent_events rows | 0 | ~10,000 | ~50,000 |

**M4 24GB capacity assessment:**
- PostgreSQL with pgvector on M4 can handle: 500+ connections, 10,000+ queries/second, 50GB+ database
- Our projected load is well within comfortable operating range
- 24GB RAM is ample — PostgreSQL uses ~512MB shared_buffers + ~100MB per active connection max

**Recommended tuning for agent workload:**

```ini
# postgresql.conf optimizations
shared_buffers = 512MB              # Up from 128MB (~20% of 24GB system RAM)
effective_cache_size = 16GB         # Tell planner about available RAM
work_mem = 16MB                     # Up from 4MB (helps JSONB operations)
maintenance_work_mem = 256MB        # For VACUUM, CREATE INDEX, REINDEX
random_page_cost = 1.1              # SSD-optimized (default 4.0 is for HDD)
effective_io_concurrency = 200      # SSD can handle many concurrent IOs

# WAL for replication
wal_level = replica
max_wal_senders = 3
wal_keep_size = 1GB

# Query parallelism
max_parallel_workers_per_gather = 4  # Help vector similarity searches
max_parallel_workers = 8            # M4 has 10 cores

# Autovacuum (aggressive for frequent JSONB updates)
autovacuum_max_workers = 3
autovacuum_naptime = 30s
```

**Monitoring metrics to track:**

```sql
-- Connection count
SELECT count(*) FROM pg_stat_activity WHERE datname = 'ainchors_nexus';

-- Cache hit ratio (should be >99%)
SELECT sum(blks_hit)*100/sum(blks_hit+blks_read) AS cache_hit_ratio 
FROM pg_stat_database WHERE datname = 'ainchors_nexus';

-- Table sizes
SELECT relname, pg_size_pretty(pg_total_relation_size(relid)) AS size
FROM pg_stat_user_tables ORDER BY pg_total_relation_size(relid) DESC;

-- Slow queries (>100ms)
SELECT query, mean_exec_time, calls 
FROM pg_stat_statements 
WHERE mean_exec_time > 100 
ORDER BY mean_exec_time DESC LIMIT 10;
-- Note: requires CREATE EXTENSION pg_stat_statements;
```

---

## 7. Risk Assessment

### 7.1 What Breaks If Postgres Goes Down?

| System | Impact | Severity | Mitigation |
|--------|--------|----------|------------|
| Ticket operations | Cannot create/update tickets | **CRITICAL** | File fallback in ticket.sh; tickets.json always kept in sync |
| Task queue | Cannot claim/complete tasks | **CRITICAL** | File-based backup queue; async tasks pause |
| Agent sessions | New sessions not logged | MEDIUM | Log locally, replay on recovery |
| Cost tracking | Cost updates fail | LOW | Daily batch; retry next cycle |
| Config/policy reads | Agents can't read config | MEDIUM | Cache in-memory; file fallback |
| Knowledge search | pgvector search fails | LOW | Fall back to grep/file search |
| Agent shared state | Shared state unavailable | **CRITICAL** | Local file cache with stale-while-revalidate |
| Inter-agent NOTIFY | Real-time events stop | MEDIUM | Agents fall back to polling |
| Memory access log | Access logging gaps | LOW | Not mission-critical; backfill later |

### 7.2 Data Loss Scenarios

| Scenario | Data at Risk | Loss Window | Prevention |
|----------|-------------|-------------|------------|
| PG crash without backup | Everything since last backup | Up to 24h (daily pg_dump) | WAL archiving + streaming replication to OC2 |
| Accidental DELETE/TRUNCATE | Table-specific | Immediate | No DELETE grants to agent roles; row-level security |
| Disk full on OC1 | New writes | Until disk freed | Monitor disk usage; 24GB → plenty of headroom for 200MB DB |
| Migration script bug | Data during migration | Migration window | Dry-run on restore_test database first |
| Agent writes corrupted JSONB | One state key | One write | JSONB validation; version-locked updates prevent overwrites |
| Dual-write inconsistency | Divergence between file and PG | 48h transition window | PG is authoritative; file is best-effort. Reconciliation script available |
| OC1 hardware failure | All data since last OC2 sync | <1 second with streaming replication | OC2 standby promotion |
| WAL corruption | Point-in-time recovery gap | Last WAL segment | Archive_command to separate disk; pg_basebackup weekly |

### 7.3 Performance Bottlenecks

| Bottleneck | Likelihood | Impact | Mitigation |
|------------|-----------|--------|------------|
| Connection exhaustion | LOW | Agents can't connect | Start with 100 max_connections; monitor; add pgbouncer if needed |
| pgvector search slowdown | MEDIUM | Slow memory search | ivfflat index with appropriate lists; limit candidate results |
| JSONB write contention on shared_state | LOW | Brief blocking on one key | Row-level locking (not table); retry-on-version-conflict pattern |
| WAL disk usage spikes | LOW | Disk fills up | wal_keep_size=1GB limit; monitor disk with cron |
| 14 agents polling simultaneously | LOW | 14 queries/second is trivial for PG | Use LISTEN/NOTIFY to reduce polling overhead |
| Embedding generation bottleneck | MEDIUM | Slow memory ingestion | Batch embedding generation; use external API if local model is slow |
| Index bloat after bulk inserts | LOW | Slower queries over time | Scheduled REINDEX after bulk memory ingestion; autovacuum tuning |
| Full-table scans on state_v views | LOW | Slow reads for large datasets | Views use primary key indexes; add partial indexes for filtered queries |

### 7.4 Migration Rollback Complexity

| Phase | Rollback Difficulty | Time to Rollback | Notes |
|-------|-------------------|-----------------|-------|
| Phase 0 (foundation) | **TRIVIAL** | <5 min | Stop db.sh, revert to file-only |
| Phase 1 (state tables) | **EASY** | <30 min | Files still authoritative; stop PG writes |
| Phase 2 (sessions/audit) | **EASY** | <30 min | No files existed before; no rollback data loss |
| Phase 3 (memory/knowledge) | **MEDIUM** | <1 hour | Files still exist; chunks in PG are supplementary |
| Phase 4 (shared state) | **HARD** | 2-4 hours | Files may be stale after dual-write; reconciliation needed |
| Phase 5 (cutover) | **HARD** | 4-8 hours | Full rollback requires pg_dump → file conversion |
| Phase 5 (post-cutover >7 days) | **VERY HARD** | 8+ hours | Files are stale; pg_dump → file reconstruction required; potential data discrepancy |

**Rollback decision matrix:**

```
If failure is in Phase 0-2 → Rollback. Cost: <1 hour.
If failure is in Phase 3   → Rollback with knowledge re-ingestion later. Cost: <1 hour.
If failure is in Phase 4   → Rollback with file reconciliation. Cost: 2-4 hours.
If failure is in Phase 5   → Fix forward if possible. Rollback only if PG is fundamentally broken.
                             Cost: 4-8 hours for full rollback + file reconstruction.
If post-cutover failure    → Fix forward. Postgres IS the system now.
                             Treat as PG outage → follow HA failover procedures.
```

### 7.5 Risk Matrix Summary

```
                    Likelihood →
                    Low           Medium        High
Impact             ┌────────────┬────────────┬────────────┐
↓                  │            │            │            │
Critical  │        │ OC1 HW     │ PG outage  │            │
          │        │ failure    │ (no HA)    │            │
          │        │            │            │            │
High      │        │ Corrupt    │ Embedding  │ Ticket     │
          │        │ JSONB      │ slowdown   │ break      │
          │        │            │            │            │
Medium    │        │ WAL spike  │ Memory     │            │
          │        │            │ ingest spd │            │
          │        │            │            │            │
Low       │        │ Connection │ Index      │            │
          │        │ exhaust    │ bloat      │            │
          └────────────┴────────────┴────────────┘
```

### 7.6 Top 3 Risks to Mitigate Before Phase 1

1. **PG outage during critical operations** (Critical/Medium)
   - *Mitigation:* File fallback pattern in all scripts before Phase 1 starts
   - *Validation:* Kill PG during ticket creation → verify file fallback works

2. **OC1 hardware failure** (Critical/Low)
   - *Mitigation:* Streaming replication to OC2 when it arrives (Jul 2026)
   - *Before OC2:* Daily pg_dump + off-machine backup
   - *Interim:* Weekly pg_basebackup to external storage

3. **Rollback complexity after Phase 4** (High/Low)
   - *Mitigation:* Keep file writes running in parallel for 48h after cutover
   - *Validation:* Run rollback drill at end of Phase 4
   - *Decision gate:* Don't proceed to Phase 5 without passing rollback drill

---

## Appendix A: db.sh Reference Implementation

```bash
#!/bin/bash
# db.sh — Agent Postgres access wrapper with auto-primary discovery
# Location: /opt/homebrew/lib/node_modules/openclaw/scripts/db.sh
#
# Usage:
#   echo "SELECT * FROM state_v.tickets;" | db.sh
#   db.sh -c "SELECT count(*) FROM state_tickets;"
#   db.sh <<'SQL'
#   BEGIN;
#   INSERT INTO agent_events ...;
#   COMMIT;
#   SQL

set -euo pipefail

PGUSER="${PGUSER:-ainchorsangiefpl}"
PGDB="${PGDB:-ainchors_nexus}"
PGHOST="${PGHOST:-localhost}"

# Try primary
if psql -U "$PGUSER" -d "$PGDB" -h "$PGHOST" -t -A "$@" 2>/dev/null; then
  exit 0
fi

# Fallback: try OC2 if configured
PGHOST2="${PGHOST2:-oc2.local}"
if [ "$PGHOST" != "localhost" ] && psql -U "$PGUSER" -d "$PGDB" -h "$PGHOST2" -t -A "$@" 2>/dev/null; then
  exit 0
fi

echo "[WARN] Postgres unavailable. Use file fallback." >&2
exit 1
```

## Appendix B: Migration Validation Queries

```sql
-- Validate ticket count parity between PG and file
SELECT 'pg' AS source, count(*) FROM state_tickets
UNION ALL
SELECT 'file', jsonb_array_length(data->'tickets') 
FROM (SELECT pg_read_file('state/tickets.json')::jsonb AS data) t;

-- Validate cost parity
SELECT 'pg' AS source, data FROM state_cost
UNION ALL
SELECT 'file', pg_read_file('state/cost-baseline.json')::jsonb;

-- Check for orphaned knowledge chunks (none expected)
SELECT kc.id FROM knowledge_chunks kc
LEFT JOIN knowledge_documents kd ON kc.document_id = kd.id
WHERE kd.id IS NULL;

-- Verify all state_v views return valid JSON
SELECT 'state_v.tickets' AS view_name, jsonb_typeof(data) FROM state_v.tickets
UNION ALL SELECT 'state_v.cost_state', jsonb_typeof(data) FROM state_v.cost_state
UNION ALL SELECT 'state_v.config_baseline', jsonb_typeof(data) FROM state_v.config_baseline;

-- Check for duplicate state keys (should be 0)
SELECT state_key, count(*) FROM agent_shared_state 
GROUP BY state_key HAVING count(*) > 1;

-- Verify version consistency
SELECT state_key, version, updated_at 
FROM agent_shared_state 
ORDER BY updated_at DESC;

-- Check table bloat
SELECT schemaname, relname, 
       n_dead_tup, n_live_tup,
       CASE WHEN n_live_tup > 0 
         THEN round(100.0 * n_dead_tup / (n_dead_tup + n_live_tup), 1) 
         ELSE 0 
       END AS dead_ratio
FROM pg_stat_user_tables 
WHERE n_dead_tup > 100 
ORDER BY n_dead_tup DESC;
```

## Appendix C: Agent Migration Checklist

```
Agent: ________________  Date: ________________  Tier: ________________

Read Path:
☐ state_v view returns expected JSON structure
☐ File fallback tested (kill PG, agent still reads from file)
☐ Response time < 500ms from PG

Write Path:
☐ INSERT/UPSERT works for primary table
☐ File fallback tested
☐ Version-locked update works (if using shared_state)
☐ Transaction rollback tested (INSERT fails, state unchanged)

Monitoring:
☐ Agent events logged to agent_events table
☐ Session started/ended logged to agent_sessions
☐ Errors logged with context in payload
☐ Query timing logged (>500ms queries flagged)

Cutover:
☐ 24h dual-write observation passed
☐ Data parity validated (file vs PG — same row counts, same JSON structure)
☐ Rollback drill completed
☐ Agent switched to PG primary
☐ File fallback confirmed working

Sign-off: ________________  Date: ________________
```

## Appendix D: NOTIFY Trigger Installation Script

```sql
-- Install all NOTIFY triggers at once
-- Run: psql -U ainchorsangiefpl -d ainchors_nexus -f this_file.sql

-- 1. Ticket changes
CREATE OR REPLACE FUNCTION notify_ticket_change()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM pg_notify('ticket_changed', 
    json_build_object('id', COALESCE(NEW.id, OLD.id), 'status', NEW.status, 'op', TG_OP)::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_ticket_notify ON state_tickets;
CREATE TRIGGER trg_ticket_notify
  AFTER INSERT OR UPDATE ON state_tickets
  FOR EACH ROW EXECUTE FUNCTION notify_ticket_change();

-- 2. Task queue changes
CREATE OR REPLACE FUNCTION notify_task_change()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM pg_notify('task_queued', 
      json_build_object('id', NEW.id, 'title', NEW.title, 'priority', NEW.priority)::text);
  ELSIF TG_OP = 'UPDATE' AND NEW.status = 'claimed' AND OLD.status = 'pending' THEN
    PERFORM pg_notify('task_claimed', 
      json_build_object('id', NEW.id, 'agent', NEW.claimedby)::text);
  ELSIF TG_OP = 'UPDATE' AND NEW.status = 'complete' AND OLD.status != 'complete' THEN
    PERFORM pg_notify('task_completed', 
      json_build_object('id', NEW.id, 'status', 'complete')::text);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_task_notify ON state_task_queue;
CREATE TRIGGER trg_task_notify
  AFTER INSERT OR UPDATE ON state_task_queue
  FOR EACH ROW EXECUTE FUNCTION notify_task_change();

-- 3. Shared state changes
CREATE OR REPLACE FUNCTION notify_state_change()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM pg_notify('state_changed',
    json_build_object('key', NEW.state_key, 'version', NEW.version, 'updated_by', NEW.updated_by)::text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_state_notify ON agent_shared_state;
CREATE TRIGGER trg_state_notify
  AFTER UPDATE ON agent_shared_state
  FOR EACH ROW EXECUTE FUNCTION notify_state_change();

-- 4. Auto-history tracking
CREATE OR REPLACE FUNCTION record_state_change()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO agent_state_history (state_id, state_value, version, changed_by)
  VALUES (NEW.id, NEW.state_value, NEW.version, NEW.updated_by);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_state_history ON agent_shared_state;
CREATE TRIGGER trg_state_history
  AFTER UPDATE ON agent_shared_state
  FOR EACH ROW
  EXECUTE FUNCTION record_state_change();
```
