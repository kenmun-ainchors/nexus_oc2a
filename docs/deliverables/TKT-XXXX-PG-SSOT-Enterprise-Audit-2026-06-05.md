# PG SSOT Enterprise Audit — 2026-06-05

## ⚠️ Subagent Limitation Notice

**Atlas 🏛️ here.** I was spawned as a sandboxed subagent with only `read`, `write`, `edit`, `web_search`, `web_fetch` tools — **no `exec` capability**. My sandbox is `/Users/ainchorsangiefpl/.openclaw/workspace-architect/` and I cannot:

- Execute shell commands (no `exec` tool available)
- Run `bash .../db-read.sh` to query Postgres
- Read files outside the workspace sandbox (`/Users/ainchorsangiefpl/.openclaw/workspace/docs/`, `state/`, `scripts/`)
- Search the web (no MiniMax API key configured)

### What I CAN do and HAVE done:
1. ✅ Created a comprehensive data collection script at `.openclaw/tmp/collect-audit-data.sh`
2. ✅ Prepared the full audit deliverable framework below
3. ✅ Designed the completeness matrix, gap pattern analysis, and remediation plan structure

### What the main agent needs to do:
**Run this command:**
```bash
bash ~/.openclaw/workspace-architect/.openclaw/tmp/collect-audit-data.sh
```
Then feed me (Atlas) the output files from `.openclaw/tmp/audit-raw-data/` so I can complete the analysis.

**Alternatively:** Respawn me with `exec` capability so I can collect the data myself.

---

## What follows is the AUDIT FRAMEWORK — ready for data population

The structure below is complete. Fields marked `[DATA NEEDED]` will be filled after data collection.

---

# PG SSOT Enterprise Audit: Is Postgres Truly the Single Source of Truth?

**Date:** 2026-06-05
**Auditor:** Atlas 🏛️ — Enterprise Architect
**Scope:** Full-platform audit of PG SSOT implementation fidelity
**Trigger:** Second gap discovered (state_autoheal_log backfill-only, following journal/blog cron gap)

---

## Executive Summary

*[DATA NEEDED — to be completed after data collection]*

Template bullets:
- **SSOT Fidelity Score:** X% — Y of Z planned tables are live and receiving writes
- **Critical Gaps:** N tables exist but have no live write path (backfill-only or stale)
- **Missing Tables:** M planned tables were never created (design-only)
- **JSON Migration Debt:** K state/*.json files remain with no PG equivalent
- **Root Cause:** [Pattern analysis result]

---

## Completeness Matrix

### Legend
- **Exists?** — Present in PG public schema
- **Has Data?** — COUNT(*) > 0
- **Live Writes?** — Has an ongoing INSERT/UPDATE path (cron, event handler, API endpoint)
- **Gap Severity:** CRITICAL / HIGH / MEDIUM / LOW / NONE

### Tier 0 — Core Platform State (Must Have)

| # | Planned Table | Exists? | Has Data? | Live Writes? | Gap Severity | Notes |
|---|--------------|---------|-----------|-------------|-------------|-------|
| 1 | state_agents | [DATA] | [DATA] | [DATA] | [DATA] | |
| 2 | state_sessions | [DATA] | [DATA] | [DATA] | [DATA] | |
| 3 | state_users | [DATA] | [DATA] | [DATA] | [DATA] | |
| 4 | state_workspaces | [DATA] | [DATA] | [DATA] | [DATA] | |
| 5 | state_channels | [DATA] | [DATA] | [DATA] | [DATA] | |
| 6 | state_messages | [DATA] | [DATA] | [DATA] | [DATA] | |
| 7 | state_memory | [DATA] | [DATA] | [DATA] | [DATA] | |
| 8 | state_plugins | [DATA] | [DATA] | [DATA] | [DATA] | |
| 9 | [DATA] | [DATA] | [DATA] | [DATA] | [DATA] | From design docs |

### Tier 1 — Operational State

| # | Planned Table | Exists? | Has Data? | Live Writes? | Gap Severity | Notes |
|---|--------------|---------|-----------|-------------|-------------|-------|
| 10 | state_autoheal_log | [DATA] | [DATA] | [DATA] | **KNOWN GAP** | ⚠️ One-time backfill, no live writes |
| 11 | state_taskflow | [DATA] | [DATA] | [DATA] | [DATA] | |
| 12 | state_cron_jobs | [DATA] | [DATA] | [DATA] | [DATA] | |
| 13 | state_heartbeats | [DATA] | [DATA] | [DATA] | [DATA] | |
| 14 | state_feedback | [DATA] | [DATA] | [DATA] | [DATA] | |
| 15 | state_tool_calls | [DATA] | [DATA] | [DATA] | [DATA] | |
| 16 | state_errors | [DATA] | [DATA] | [DATA] | [DATA] | |
| 17 | state_audit_log | [DATA] | [DATA] | [DATA] | [DATA] | |
| 18 | [DATA] | [DATA] | [DATA] | [DATA] | [DATA] | From design docs |

### Tier 2 — Analytical / Auxiliary

| # | Planned Table | Exists? | Has Data? | Live Writes? | Gap Severity | Notes |
|---|--------------|---------|-----------|-------------|-------------|-------|
| 19 | state_model_drift | [DATA] | [DATA] | [DATA] | **KNOWN GAP** | ⚠️ In design, never created |
| 20 | state_frameworks | [DATA] | [DATA] | [DATA] | **KNOWN GAP** | ⚠️ In design, never created |
| 21 | state_journal_entries | [DATA] | [DATA] | [DATA] | [DATA] | |
| 22 | state_blog_posts | [DATA] | [DATA] | [DATA] | **KNOWN GAP** | ⚠️ Prior gap — cron was missing |
| 23 | [DATA] | [DATA] | [DATA] | [DATA] | [DATA] | From design docs |

**Additional tables discovered in PG (not in original design):**

| Table | Has Data? | Live Writes? | Notes |
|-------|-----------|-------------|-------|
| [DATA] | [DATA] | [DATA] | |

---

## JSON Migration Status

**Target:** Migrate 28+ state/*.json files to PG tables per the SSOT proposal.

*[DATA NEEDED — populate after running collect-audit-data.sh]*

| Status | Count | Details |
|--------|-------|---------|
| ✅ Migrated (PG table exists, live writes) | [DATA] | |
| ⚠️ Migrated but stale (table exists, no live writes) | [DATA] | |
| ❌ Not migrated (JSON-only, no PG table) | [DATA] | |
| 🔄 In progress | [DATA] | |
| **Total JSON files in state/** | **[DATA]** | |

### Remaining JSON-Only Files (Critical Debt):

*[DATA NEEDED — list each JSON file with no PG equivalent]*

---

## Pattern Analysis

### Recurring Gap Patterns Identified

#### Pattern 1: 🚫 **One-Time Backfill, No Live Writes**
**Description:** Table was created and backfilled during Phase N migration, but no cron job, event handler, or API endpoint was wired up for ongoing writes. The table decays immediately after backfill.

**Examples:**
- `state_autoheal_log` — populated by migration script, no auto-heal reporting writes to it live
- [DATA — additional examples from audit]

**Risk:** Data becomes stale within hours. The "SSOT" is a snapshot, not a live system.

#### Pattern 2: 📋 **Design-Only Tables**
**Description:** Table was specified in the SSOT proposal and runbook but never actually created in PG. The JSON file remains the de facto truth.

**Examples:**
- `state_model_drift` — in proposal, never migrated
- `state_frameworks` — in proposal, never migrated
- [DATA — additional examples from audit]

**Risk:** False confidence. The proposal says "done" but PG is empty.

#### Pattern 3: 🔌 **Write Path Missing**
**Description:** Table exists and may even have data, but the code that generates new data still writes to JSON files or in-memory, never touching PG. The PG table is a ghost.

**Examples:**
- [DATA — examples from audit]

#### Pattern 4: 📝 **Cron/Trigger Gap**
**Description:** PG table was created and write code exists, but the cron job or trigger that invokes it was never deployed or scheduled.

**Examples:**
- `state_blog_posts` / `state_journal_entries` — prior gap, cron was missing
- [DATA — additional examples]

#### Pattern 5: [DATA — emergent patterns from audit]

---

## Root Cause Analysis

### Why did these gaps happen?

*[DATA NEEDED — full analysis after data collection]*

**Preliminary assessment (from known gaps):**

1. **Process Gap — No "Done" Definition:**
   The execution runbook defines "creating the table and backfilling data" as completion. It does NOT define verifying live write paths as part of "done." A table without a write path is not truly migrated; it's a museum exhibit.

2. **Execution Gap — Phased Without Verification:**
   Phase 2 Migration Assessment was written as a self-assessment, not an audit. It counted tables created, not tables operational. The assessment reports Phase 2 as "complete" based on table existence, not live write verification.

3. **Design Gap — Missing Write Path Inventory:**
   The SSOT proposal has a comprehensive Tier system for TABLE importance, but no corresponding WRITE PATH inventory. For each table, the design should specify:
   - What code writes to it
   - When (cron schedule / event trigger / API endpoint)
   - Who maintains it

4. **Governance Gap — No Continuous Verification:**
   There is no automated check that compares PG table state against JSON file modified times. A dashboard or health check that says "PG last wrote to X 3 days ago, but state/x.json was modified 5 minutes ago" would catch this immediately.

---

## Remediation Plan

### CRITICAL — Fix Immediately (Sprint 0)

| # | Action | Gap Pattern | Effort |
|---|--------|-------------|--------|
| 1 | Wire auto-heal event handler → `state_autoheal_log` INSERT | Pattern 1 | 2h |
| 2 | Create `state_model_drift` table + migrate JSON | Pattern 2 | 3h |
| 3 | Create `state_frameworks` table + migrate JSON | Pattern 2 | 3h |
| 4 | Verify journal/blog cron is live and writing | Pattern 4 | 1h |
| [DATA — additional critical items] | | | |

### HIGH — This Sprint (Sprint 1)

| # | Action | Gap Pattern | Effort |
|---|--------|-------------|--------|
| [DATA] | [DATA] | [DATA] | [DATA] |

### MEDIUM — Next Sprint (Sprint 2)

| # | Action | Gap Pattern | Effort |
|---|--------|-------------|--------|
| [DATA] | [DATA] | [DATA] | [DATA] |

### LOW — Backlog

| # | Action | Gap Pattern | Effort |
|---|--------|-------------|--------|
| [DATA] | [DATA] | [DATA] | [DATA] |

---

## Verification Framework (Prevent Recurrence)

### Must-Have Checks for Every PG Table:

```sql
-- Check 1: Does the table exist?
SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'state_X');

-- Check 2: Does it have data?
SELECT COUNT(*) FROM state_X;

-- Check 3: Is it receiving live writes? (last INSERT timestamp)
SELECT MAX(created_at) FROM state_X;

-- Check 4: Is the JSON source still being written to more recently than PG?
-- (Compare file mtime vs MAX(created_at))
```

### Proposed Continuous Monitoring:
- Add a `pg_ssot_health_check` cron (runs every 6 hours)
- Compares PG `MAX(created_at)` against JSON file `mtime` for each migrated table
- Alerts if JSON is newer than PG for any migrated table
- Flags tables with >24h since last write that should be receiving live data

### Proposed "Done" Definition Update:
A PG SSOT migration is **DONE** only when ALL of:
1. ✅ CREATE TABLE executed
2. ✅ Historical data backfilled
3. ✅ Live write path implemented and tested
4. ✅ JSON source deprecated (writes redirected to PG, or confirmed read-only)
5. ✅ Health check monitoring active

---

## Recommendations for Ken

1. **Pause all new feature work** until the CRITICAL gaps are closed — the SSOT foundation must be solid before building on it
2. **Run the data collection script** and feed me the results for a complete populated audit
3. **Establish a PG SSOT governance role** — someone who owns the SSOT integrity, not just migrations
4. **Audit the audit** — schedule a follow-up verification 2 weeks after remediation to confirm gaps stay closed
5. **Consider automatic PG write interception** — a proxy layer that catches all state writes and ensures PG is always the first write target

---

## Appendix A: Data Collection Script

Located at: `.openclaw/tmp/collect-audit-data.sh`

Run with:
```bash
bash ~/.openclaw/workspace-architect/.openclaw/tmp/collect-audit-data.sh
```

Output goes to: `.openclaw/tmp/audit-raw-data/`

## Appendix B: Subagent Capability Gap

This subagent was spawned without `exec` capability, making it unable to:
- Query the Postgres database
- Read files outside the workspace sandbox
- Run shell scripts
- Search the web

**Fix:** Respawn with exec capability, OR run the collection script manually and feed me the output.

---

*Atlas 🏛️ — Enterprise Architect*
*Audit initiated: 2026-06-05 12:04 AEST*
*Status: ⚠️ AWAITING DATA COLLECTION for completion*
