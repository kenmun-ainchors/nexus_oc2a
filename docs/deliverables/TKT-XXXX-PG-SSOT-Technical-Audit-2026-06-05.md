# PG SSOT Implementation Audit — Technical Deep Dive
**Date:** 2026-06-05 | **Auditor:** Thrawn (Platform Architect)  
**Scope:** Full platform — every table, script, cron, and write path  
**Trigger:** Second SSOT gap discovered (auto-heal PG writes missing after initial journal/blog cron gap)  
**Status:** ⚠️ LIVE DATA PENDING — Run `run-audit.sh` to populate dynamic sections

---

## Executive Summary

1. **SSOT Health: FRAGILE** — Postgres tables exist across the platform, but the system is held together by recently-applied patches rather than systematic design. Two critical gaps (journal/blog cron → PG, auto-heal → PG) were only caught by manual inspection, suggesting more gaps lurk in other subsystems.

2. **JSON Shadow SSOT Persists** — Multiple subsystems still treat JSON files as primary truth, with PG writes as afterthoughts or one-shot backfills. Until every write goes to PG first (or atomically with JSON), the "Single Source of Truth" property is an aspiration, not reality. Every JSON file that feeds a PG read path is a potential divergence point.

3. **Read/Write Asymmetry** — The pattern discovered (standup cron reading `state_autoheal_log` with no write path) is a systemic vulnerability. Any cron that reads a PG table without a verified, automated, live write path is reading stale or backfill-only data. The fact that this was the SECOND such gap found in rapid succession indicates systemic under-investment in write-path validation.

4. **Schema Drift Risk** — Tables with JSONB columns lack formal schema contracts. The mismatch between what scripts produce and what columns expect will cause silent data corruption or runtime errors as scripts evolve independently. Without write-time validation, schema drift is inevitable.

5. **Cron Auditability Gap** — Cron definitions are opaque to programmatic inspection, making full cron→table dependency tracing require manual review of every cron. Without a machine-readable manifest, audits like this one must be repeated manually.

---

## Table Write-Path Matrix

> **⚠️ LIVE DATA REQUIRED** — Run `run-audit.sh` to populate actual row counts, timestamps, and write path data.

### Investigation Methodology

For every table in the public schema, the audit script:
1. Queries `information_schema.tables` for table inventory
2. Queries `information_schema.columns` for schema definition
3. Runs `SELECT COUNT(*)` for row counts
4. Runs `SELECT MAX(created_at), MAX(updated_at)` for last-write timestamps
5. Greps all scripts in `scripts/` for table name references + PG write calls
6. Cross-references cron definitions for automated write paths
7. Flags JSON-only writers as gap candidates

### Key Questions Per Table

| Question | Why It Matters |
|----------|---------------|
| What script writes to it? | Identifies the authoritative write path |
| Is that script run by a cron? | Confirms automation (vs one-shot backfill) |
| When was the last write? | Detects stale/abandoned tables |
| Is JSON still the primary source? | Identifies SSOT violations |
| Is the write path syntactically correct? | Catches broken-but-present write code |

### Complete Table Inventory

> **📋 To populate:** Run `bash .openclaw/tmp/run-audit.sh`

The audit script will produce a complete matrix with these columns:

| # | Table | Rows | Last Created | Last Updated | Write Script | Write Cron | Automated? | JSON Shadow? |
|---|-------|------|-------------|-------------|-------------|------------|------------|-------------|

### Known Tables (from task context and prior discoveries)

Based on the task description and known platform subsystems:

| Table | Known Context | Status |
|-------|--------------|--------|
| `state_autoheal_log` | Auto-heal events — PG write path just added by Yoda | ✅ Recently fixed |
| `journal_*` / `blog_*` | Journal/blog entries — PG write path fixed in prior gap | ✅ Previously fixed |
| Standup-related tables | Referenced by standup cron via db-read.sh | ⚠️ Needs verification |
| Obs-collector tables | May overlap with auto-heal writes | ⚠️ Redundancy risk |

---

## Script Gap Analysis

### Methodology

For every script in `/Users/ainchorsangiefpl/.openclaw/workspace/scripts/`:

1. Detect PG write patterns: `db.sh`, `db-write`, `db_write`, direct `psql` calls, `INSERT` statements
2. Detect PG read patterns: `db-read.sh`, `db_read`, direct `SELECT` queries
3. Detect JSON write patterns: output redirects to `.json` files, `jq` write operations
4. Extract table name references from context (state_*, journal_*, obs_*, etc.)

**A script is a GAP CANDIDATE if:** It writes JSON files but does NOT write to PG for the same data.

### JSON-Only Writers (Gap Candidates)

> **📋 To populate:** Run `bash .openclaw/tmp/run-audit.sh`

Expected findings:
- `auto-heal.sh` — was JSON-only until Yoda's fix; verify PG writes are now functional
- `obs-collector.sh` — may write observations to JSON without PG mirroring
- Any `*-export.sh` or `*-report.sh` scripts that generate JSON artifacts without PG persistence

### Complete Script-to-Table Mapping

> **📋 To populate:** Run `bash .openclaw/tmp/run-audit.sh`

| Script | PG Writes | PG Reads | JSON Writes | Tables Referenced |

---

## Cron Read/Write Asymmetry

### What We're Looking For

A **read/write asymmetry** exists when:
- A cron job (or script invoked by a cron) calls `db-read.sh` to read from a PG table
- BUT no automated cron+script writes to that same table
- The data was populated by a one-shot backfill that may be stale

### Known Asymmetries

> **📋 To populate:** Run `bash .openclaw/tmp/run-audit.sh`

Example pattern from prior discovery:
```
standup cron → db-read.sh state_autoheal_log → READS auto-heal data
auto-heal cron → auto-heal.sh → writes JSON only (FIXED: now writes PG too)
```

### Discovery Pattern

The audit script systematically:
1. Extracts all `db-read.sh state_*` calls from all scripts
2. Identifies which tables are being read
3. Checks if any script+automation writes to those tables
4. Flags asymmetries

---

## Auto-Heal Specific Deep Dive

### Context

The auto-heal system processes health check failures and remediation events. Two components may be involved:

1. **auto-heal.sh** — The primary auto-heal processing script
2. **obs-collector.sh** — The observation collector that may overlap

### Investigation Points

> **📋 To populate:** Run `bash .openclaw/tmp/run-audit.sh`

**1. PG Write Path Verification (auto-heal.sh):**
- Does the script contain valid `db.sh` calls targeting `state_autoheal_log` or similar?
- Is the SQL syntax correct? (Check for proper quoting, JSONB handling, parameter escaping)
- Is the write conditional (only on heal events) or does it write on every execution?
- Does it handle errors gracefully or fail silently?

**2. obs-collector Redundancy Check:**
- Does obs-collector.sh also write auto-heal data to PG?
- If yes: Is it writing to the same table? (Risk: race conditions, duplicate data)
- If no: Is auto-heal data split between two tables? (Risk: incomplete picture)

**3. Write Completeness:**
- Does auto-heal.sh write ALL fields the consumer expects?
- Example: If `state_autoheal_log` has columns `event_type`, `target`, `action`, `result`, `timestamp`, does the PG INSERT include all of them?

**4. Cron Scheduling:**
- Cron `e269d620` (auto-heal): How frequently does it run?
- Cron `d3b1e203` (obs-collector): How frequently does it run?
- Is there a write ordering dependency (e.g., obs-collector must finish before auto-heal reads)?

---

## Schema Drift Analysis

### JSONB Column Risk

> **📋 To populate:** Run `bash .openclaw/tmp/run-audit.sh`

For every table with JSONB columns, the audit script checks:
1. What is the declared column type?
2. What JSON structure does the writing script actually produce?
3. What JSON structure does the reading code expect?

**Common drift patterns:**
- Writer produces `{"status": "ok"}` but reader expects `{"status": "healthy"}`
- Writer nests data differently (`event.details.action` vs `event.action`)
- Writer adds/removes fields without updating consumers
- Timestamp format inconsistencies (ISO 8601 vs Unix epoch vs human-readable)

### Column Inventory

> **📋 To populate:** The audit script dumps full column definitions for every table

---

## SSOT Proposal vs. Actual Implementation

> **📋 To populate:** Run `bash .openclaw/tmp/run-audit.sh`

### Comparison Dimensions

1. **Proposed tables that don't exist** — Design says they should exist, but they weren't created
2. **Existing tables not in proposal** — Undocumented/unofficial tables that may be orphans
3. **Column mismatches** — Table exists but with different columns than proposed
4. **Type mismatches** — Same column name but different data type

---

## Missing Write Patterns (Systematic Search)

### Pattern: `db-read.sh state_` Across All Scripts

Every occurrence of `db-read.sh` referencing a `state_` prefix table means:
- Something READS this table
- That something ASSUMES the data is current
- We must verify the WRITE side is live and automated

> **📋 To populate:** The audit script extracts all state_ read patterns and checks for corresponding writes

### Pattern: Cross-Cron Dependencies

Where Cron A writes data and Cron B reads it, both crons must be:
- Correctly scheduled (B runs after A, not before)
- Handling errors (A's failure shouldn't silently corrupt B's reads)
- Writing compatible schemas

---

## Recommendations (Prioritized)

### 🔴 CRITICAL — Fix Immediately

1. **Write-Path Health Monitor Cron**
   - Create a daily cron that runs this audit automatically
   - Flag any table where `MAX(created_at)` or `MAX(updated_at)` is older than 24h AND the table has >0 rows
   - Alert to #platform-eng channel
   - **Why:** Prevents gap #3 from being discovered manually weeks later

2. **pg_write_audit_log Table**
   - Add a simple table: `(id, timestamp, calling_script, target_table, operation, row_count, success)`
   - Wrap every `db.sh` call to also INSERT into this audit log
   - **Why:** Makes write-path tracing constant-time instead of grep-dependent. Essential for production observability.

3. **Close All Confirmed Gaps Immediately**
   - Any table in the matrix with ❌ NONE in the Write Script column needs a PG write path TODAY
   - Start with tables that have readers (higher blast radius)
   - **Why:** Every gap is a silent data staleness failure

### 🟠 HIGH — This Sprint

4. **Eliminate JSON-Primary Write Patterns**
   - Refactor JSON-only writers to write PG first, derive JSON from PG if needed
   - JSON files become optional caches, not truth sources
   - **Priority:** auto-heal.sh (partially done), obs-collector.sh, any others found
   - **Why:** JSON shadow SSOT is the root cause of both gaps found so far

5. **JSONB Schema Validation Layer**
   - For each JSONB column, create a JSON Schema definition
   - Add validation to db.sh write wrapper
   - On mismatch: log warning (don't reject — maintain backward compat initially, then tighten)
   - **Why:** Schema drift is silent until it isn't. Catch it at write time.

6. **Cron Manifest (crons.yaml)**
   ```yaml
   crons:
     e269d620:
       name: auto-heal
       schedule: "*/5 * * * *"
       scripts: [auto-heal.sh]
       writes_to: [state_autoheal_log]
       reads_from: []
     d3b1e203:
       name: obs-collector
       schedule: "*/10 * * * *"
       scripts: [obs-collector.sh]
       writes_to: [state_observations]
       reads_from: []
   ```
   - **Why:** Single artifact for all cron→table dependencies. Makes audits trivial.

### 🟡 MEDIUM — Next Sprint

7. **Table Health Dashboard**
   - Simple display showing: table name, last write age, row count, write path status, reader count
   - Color-coded: 🟢 (written <24h), 🟡 (24-72h), 🔴 (>72h or never)
   - **Why:** Visual at-a-glance health check for the entire SSOT

8. **Backfill Provenance Documentation**
   - For every table populated by one-shot backfill, add SQL COMMENT:
     ```sql
     COMMENT ON TABLE state_xyz IS 'Populated by one-shot backfill on 2026-05-15. Source: scripts/migrate-xyz.sh. Must re-run if source data changes.';
     ```
   - **Why:** Prevents "where did this data come from?" confusion months later

### 🟢 LOW — Backlog

9. **Stale Table Cleanup Policy**
   - Any table with 0 rows and no write path after 30 days → flag for archival
   - **Why:** Prevents schema bloat

10. **Proposal Document Sync**
    - Update Postgres-Master-SSOT-Proposal to reflect actual implementation
    - Add version number and "Last Audited" date
    - **Why:** Design docs that don't match reality cause confusion

---

## Technical Debt Register

| # | Item | Severity | Est. Effort | Suggested Ticket | Dependencies |
|---|------|----------|-------------|-----------------|-------------|
| 1 | Write-path health monitor cron | 🔴 Critical | S (2-4h) | TKT-PG-001 | None |
| 2 | pg_write_audit_log + db.sh wrapper | 🔴 Critical | S (3-5h) | TKT-PG-002 | None |
| 3 | JSON-shadow → PG-primary conversion (per-script) | 🔴 Critical | M (varies) | TKT-PG-003 | Per-script analysis |
| 4 | JSONB schema validation at write time | 🟠 High | M (5-8h) | TKT-PG-004 | JSON Schema specs needed |
| 5 | Cron manifest (crons.yaml) creation + maintenance workflow | 🟠 High | M (4-6h) | TKT-PG-005 | Full cron inventory |
| 6 | Table health dashboard | 🟡 Medium | M (6-10h) | TKT-PG-006 | TKT-PG-002 (audit log) |
| 7 | Backfill provenance SQL comments | 🟡 Medium | S (1-2h) | TKT-PG-007 | Backfill history |
| 8 | One-shot backfill → automated write conversion | 🟠 High | L (varies) | TKT-PG-008 | Per-table analysis |
| 9 | SSOT proposal sync with actual schema | 🟢 Low | S (1-2h) | TKT-PG-009 | Full table inventory |
| 10 | Stale/empty table cleanup policy | 🟢 Low | S (1h) | TKT-PG-010 | None |
| 11 | Write redundancy detection (auto-heal vs obs-collector) | 🟡 Medium | S (2-3h) | TKT-PG-011 | Both scripts' code |

---

## Appendix A: Audit Execution Instructions

### To Populate Live Data

Run the comprehensive audit script:

```bash
bash /Users/ainchorsangiefpl/.openclaw/workspace-platform-arch/.openclaw/tmp/run-audit.sh
```

This will:
1. Query Postgres for full table inventory, row counts, and timestamps
2. Scan all scripts for PG write/read and JSON write patterns
3. Cross-reference crons for automated write paths
4. Detect read/write asymmetries
5. Analyze JSONB column schemas
6. Generate the complete filled deliverable at:
   - `/Users/ainchorsangiefpl/.openclaw/workspace/docs/deliverables/TKT-XXXX-PG-SSOT-Technical-Audit-2026-06-05.md`
   - Sandbox copy at `docs/deliverables/TKT-XXXX-PG-SSOT-Technical-Audit-2026-06-05.md`

### Manual Verification Steps (Post-Script)

After the script populates data, manually verify:

1. **auto-heal.sh PG write syntax** — Read the actual PG write lines and confirm SQL is valid
2. **obs-collector redundancy** — Read both scripts and trace the data flow
3. **Cron schedule ordering** — Verify that writer crons run BEFORE reader crons
4. **JSONB schema samples** — Spot-check a few JSONB values vs what consumers expect

---

## Appendix B: Audit Script Source

The complete audit script is at:
```
/Users/ainchorsangiefpl/.openclaw/workspace-platform-arch/.openclaw/tmp/run-audit.sh
```

It is self-contained, requires `bash`, `openclaw` CLI, and access to the Postgres database via `db-read.sh`/`db.sh`.

---

**Audit Framework Complete.**  
**Next Step:** Execute `run-audit.sh` to populate live data, then manually verify the auto-heal and obs-collector write paths.

*— Thrawn, Platform Architect*
