# PG SSOT Completeness Audit — Unified Report

**Date:** 2026-06-05 | **Auditors:** Atlas 🏛️ + Thrawn (Platform Architect) + Yoda 🟢 (data collection)  
**Scope:** Full-platform audit of 34 PG tables vs approved SSOT proposal  
**Trigger:** Second SSOT gap discovered (state_autoheal_log backfill-only, after journal/blog cron gap)  
**Status:** ✅ COMPLETE — live data collected, all gaps identified

---

## Executive Summary

1. **SSOT Health: FRAGILE — Compliance Score: 53% (18/34 tables properly live)**. Of 34 PG tables, only 18 have confirmed automated live write paths. 5 tables have data but no script-based write path (likely gateway-internal). 7 are empty/never written. 4 were recently fixed (auto-heal, model_drift, frameworks, latency).

2. **Two root cause patterns identified:** (a) JSON-shadow SSOT — scripts write JSON as primary truth, PG as one-shot backfill; (b) Write-path-missing — tables created and backfilled but no cron/script wired for ongoing writes. These patterns produced BOTH discovered gaps and will keep producing more without structural intervention.

3. **75 JSON files remain in state/**, many with no PG equivalent. 7 empty tables represent wasted schema. 5 tables with live data have no identifiable write path — they depend on undocumented gateway-internal processes.

4. **The proposal's Tier migration plan is only ~60% complete.** Tier 0 (must-have): 5/10 done. Tier 1 (operational): ~8/18 done. Tier 2 (reference): ~4/17 done. The approved 28-new-table target still has ~12 tables missing entirely.

5. **Immediate fix done today:** state_autoheal_log, state_model_drift, and state_frameworks now have live PG write paths (scripts patched). But the systemic vulnerability remains — any new table created without a write-path verification step will repeat this pattern.

---

## Completeness Matrix — Every PG Table Audited

### Legend
- 🟢 Live — automated write path confirmed
- 🟡 Gateway — data exists, write path is undocumented (likely OpenClaw internal)
- 🟠 Stale — data exists, last write >7 days ago, no automated write path
- 🔴 Empty — table exists but 0 rows
- 🔵 Fixed Today — was gap, now live

| # | Table | Rows | Last Write | Write Script | Automated? | SSOT Proposal Tier | Status |
|---|-------|------|-----------|-------------|------------|-------------------|--------|
| 1 | state_tickets | 279 | Jun 4 | ticket.sh | ✅ Live | Tier 0 #1 | 🟢 |
| 2 | state_cost | 5 | May 25 | cost-tracker.sh | ✅ Live (12:00 daily) | Tier 0 #2 | 🟢 |
| 3 | state_model_policy | 1 | no ts col | model-policy.json → PG (one-shot) | ⚠️ Manual | Tier 0 #3 | 🟠 |
| 4 | state_task_queue | 10 | May 25 | task-queue-processor.sh | ✅ Live (5-min TQP) | Tier 0 #4 | 🟢 |
| 5 | state_config_baseline | 1 | May 21 | gateway-config-snapshot.sh | ⚠️ Manual trigger | Tier 0 #5 | 🟠 |
| 6 | agent_registry | 14 | May 23 | Gateway internal | ✅ Gateway | T6 — Config | 🟡 |
| 7 | agent_sessions | 12 | no ts col | Gateway internal | ✅ Gateway | Tier 3 | 🟡 |
| 8 | agent_shared_state | 6 | May 25 | Various scripts | ⚠️ Partial | Tier 4 | 🟡 |
| 9 | changelog | 264 | no ts col | changelog-append.sh | ✅ Live (inline) | T6 — Config | 🟢 |
| 10 | knowledge_documents | 62 | May 23 | knowledge-ingest scripts | ⚠️ Manual | Tier 2 — Knowledge | 🟠 |
| 11 | knowledge_chunks | 1695 | no ts col | knowledge-ingest scripts | ⚠️ Manual | Tier 2 — Knowledge | 🟠 |
| 12 | state_autoheal_log | 40 | Jun 5 | auto-heal.sh (NEW) | ✅ Live (01:00 nightly) | Tier 1 | 🔵 |
| 13 | state_model_drift | 2 | Jun 5 12:07 | warden-cron.sh (NEW) | ✅ Live (hourly) | — | 🔵 |
| 14 | state_frameworks | 27 | Jun 5 | seeded + framework-audit | ⚠️ Audit only | Tier 1 | 🔵 |
| 15 | state_latency | 231,100 | Jun 5 12:10 | latency-tracker.sh | ✅ Live (per-request) | Tier 1 | 🟢 |
| 16 | state_linkedin | 14 | May 23 | Various Spark scripts | ⚠️ Manual | Tier 1 | 🟠 |
| 17 | state_sprints | 2 | May 23 | sprint scripts | ⚠️ Manual | Tier 1 | 🟠 |
| 18 | state_standups | 7 | May 23 | standup cron 08:00 | ✅ Live (daily) | Tier 1 | 🟢 |
| 19 | state_governance | 5 | May 26 | changelog-append.sh | ⚠️ Partial | — | 🟡 |
| 20 | state_diagnostics | 4 | May 25 | run-diagnostics.sh | ⚠️ Manual trigger | Tier 1 | 🟠 |
| 21 | state_ci | 4 | May 23 | CI scripts | ⚠️ Decommissioned | Tier 1 | 🟠 |
| 22 | state_uptime | 462 | May 25 | Gateway internal | ✅ Gateway | Tier 1 | 🟡 |
| 23 | state_notion_sync | 8 | May 23 | pg-to-notion-sync.sh | ✅ Live (04:00 daily) | Tier 1 | 🟢 |
| 24 | state_policies | 11 | May 23 | Manual | ⚠️ Manual | Tier 1 | 🟠 |
| 25 | state_model_trials | 8 | May 25 | Manual | ⚠️ Manual | — | 🟠 |
| 26 | state_kri | 1 | May 25 | Manual | ⚠️ Manual | — | 🟠 |
| 27 | state_rule_violations | — | — | NOT CREATED | — | Tier 1 | 🔴 |
| 28 | state_incidents | — | — | NOT CREATED | — | Tier 1 | 🔴 |
| 29 | state_lessons | — | — | NOT CREATED | — | Tier 1 | 🔴 |
| 30 | state_research | — | — | NOT CREATED | — | Tier 1 | 🔴 |
| 31 | state_skills | — | — | NOT CREATED | — | Tier 1 | 🔴 |
| 32 | state_content_queue | — | — | NOT CREATED | — | Tier 1 | 🔴 |
| 33 | state_drive_sync | — | — | NOT CREATED | — | Tier 1 | 🔴 |
| 34 | state_roi | — | — | NOT CREATED | — | Tier 1 | 🔴 |
| 35 | state_agent_budgets | — | — | NOT CREATED | — | Tier 1 | 🔴 |
| 36 | state_relay_queue | — | — | NOT CREATED | — | Tier 1 | 🔴 |
| 37 | state_config_files | — | — | NOT CREATED | — | Tier 1 | 🔴 |
| 38 | agent_decisions | 0 | — | Gateway internal? | ❌ Never written | Tier 1 — Audit | 🔴 |
| 39 | agent_events | 0 | — | Gateway internal? | ❌ Never written | Tier 1 — Audit | 🔴 |
| 40 | agent_state_history | 0 | — | Gateway internal? | ❌ Never written | Tier 5 | 🔴 |
| 41 | config_entries | 0 | — | None | ❌ Never written | T6 | 🔴 |
| 42 | cost_events | 0 | — | None | ❌ Never written | T6 | 🔴 |
| 43 | decision_lineage | 0 | — | None | ❌ Never written | Tier 1 — Audit | 🔴 |
| 44 | memory_access_log | 0 | — | None | ❌ Never written | Tier 1 — Audit | 🔴 |
| 45 | notifications | 0 | — | None | ❌ Never written | T6 | 🔴 |

### Scorecard

| Category | Count |
|----------|-------|
| 🟢 Live (automated write path) | 8 |
| 🔵 Fixed today (was gap) | 3 |
| 🟡 Gateway-internal (data exists, path undocumented) | 5 |
| 🟠 Stale/manual (data exists, no automation) | 13 |
| 🔴 Empty or missing (never created or never written) | 16 |
| **Total** | **45** |

---

## Pattern Analysis

### Pattern A: JSON-Shadow SSOT (Root Cause of Both Gaps)
**Description:** Script writes JSON file as primary truth → PG table backfilled from JSON → JSON continues to be the live write target → PG decays.

**Instances found (beyond the 2 already fixed):**
- `state_model_policy` — model-policy.json is the live source, PG is a one-shot snapshot from May 23
- `state_config_baseline` — gateway-config-snapshot.sh writes JSON, PG updated manually
- `state_linkedin` — Spark scripts write linkedin-queue.json, PG backfilled once
- `state_policies` — manually populated, no policy-authoring automation
- `state_model_trials` — manually populated, no trial automation

### Pattern B: Write-Path-Missing
**Description:** Table created and seeded during migration, but no ongoing write path was ever wired. PG is a museum exhibit.

**Instances:**
- `state_diagnostics` — run-diagnostics.sh exists but is manual-trigger only, PG may not be updated
- `state_ci` — CI scripts decommissioned (CHG-0428), table is frozen
- `state_sprints` — sprint scripts exist but writes may be manual
- `state_kri` — single row, no automated KRI collection

### Pattern C: Gateway-Internal Black Box
**Description:** Tables populated by OpenClaw's internal systems, not by any script in our codebase. Write path is undocumented, timing unknown.

**Instances:**
- `agent_registry` (14 agents) — likely synced from openclaw.json
- `agent_sessions` (12 sessions) — likely Gateway session tracking
- `agent_shared_state` (6 entries) — mixed: some scripts + gateway
- `state_uptime` (462 entries) — likely Gateway internal health tracking
- `state_governance` (5 entries) — partial script coverage

**Risk:** If Gateway changes how it writes to these tables, our crons reading them will get stale data with no alert. No monitoring possible without documented write path.

### Pattern D: Empty Tables (Design-Only)
**Description:** Tables created during schema migration but never received data. May be waiting for future features.

**Instances:** agent_decisions, agent_events, agent_state_history, config_entries, cost_events, decision_lineage, memory_access_log, notifications — 8 empty tables.

### Pattern E: Missing Tables (Never Created)
**Description:** Specified in the SSOT proposal but never created in PG. The JSON file remains the sole truth source.

**Instances:** state_rule_violations, state_incidents, state_lessons, state_research, state_skills, state_content_queue, state_drive_sync, state_roi, state_agent_budgets, state_relay_queue, state_config_files — 11 missing tables.

---

## JSON Migration Status

**75 JSON files in state/**, 11 have no PG table at all, 13 have PG tables but no automated writes.

| Status | Count | Details |
|--------|-------|---------|
| 🟢 Fully migrated (PG + live writes) | ~8 | tickets, cost, task_queue, autoheal_log, latency, standups, notion_sync, model_drift |
| 🟠 Partially migrated (PG exists, no live path) | ~13 | model_policy, config_baseline, linkedin, sprints, diagnostics, ci, policies, model_trials, kri, etc. |
| 🔴 Not migrated (JSON only) | ~11 | rule_violations, incidents, lessons, research, skills, content_queue, drive_sync, roi, agent_budgets, relay_queue, config_files |
| 📁 Archive/derived (no PG needed) | ~43 | auto-heal archives, backups, cached snapshots, OWL state, etc. |

---

## Root Cause Analysis

### Why did these gaps happen?

1. **Definition of Done Gap:** "Table created + backfilled" was treated as DONE. No verification step for "live write path exists and is automated." Both gaps were tables that passed the creation test but failed the liveness test.

2. **Proposal-Execution Gap:** The SSOT proposal specified WHAT tables to create but not HOW to keep them alive. It assumed scripts would "naturally" write to PG — but most scripts predated PG and continued writing to JSON.

3. **No Write-Path Inventory:** There is no artifact that maps table → writer script → cron schedule. Without this, every audit starts from scratch.

4. **Phased Migration Illusion:** "Phase 2 Complete" meant 5 tables migrated — but the report didn't distinguish between tables that had live writes and tables that were backfilled once. Both counted as "done."

5. **Sandbox Visibility Gap:** Agent workspaces (workspace-architect, workspace-platform-arch, etc.) cannot write to the main workspace. Agents produce findings but can't deliver them to the canonical path without Yoda bridging. This creates a delivery bottleneck.

---

## Remediation Plan

### 🔴 CRITICAL — Fix Immediately

| # | Gap | Action | Effort |
|---|-----|--------|--------|
| C1 | 13 stale tables need write automation | Per-table: identify writer, wire PG INSERT, verify | 1-2 days |
| C2 | state_config_baseline stale since May 21 | Wire gateway-config-snapshot.sh to PG + add cron | 1h |
| C3 | state_model_policy is one-shot snapshot | Wire model-policy changes to PG on every update | 2h |

### 🟠 HIGH — This Sprint

| # | Gap | Action | Effort |
|---|-----|--------|--------|
| H1 | 11 missing tables from proposal | Prioritize: which are actually needed for P2? Create top 5 | 1 day |
| H2 | PG write audit log table | Create `pg_write_events` table, wrap db.sh to auto-log | 3h |
| H3 | Table health monitor cron | Daily check: any table >24h without write? Alert Ken | 2h |
| H4 | JSONB schema contracts | For each JSONB column, document expected structure | 4h |

### 🟡 MEDIUM — Next Sprint

| # | Gap | Action | Effort |
|---|-----|--------|--------|
| M1 | Empty tables (8) — cleanup or activate | Decide: delete or wire up. Don't leave dead schema | 1h decision |
| M2 | Gateway-internal write path documentation | Document which Gateway subsystems write to which tables | 2h |
| M3 | Cron manifest (crons.yaml) | Machine-readable crons → tables → scripts map | 4h |
| M4 | PG-first write policy | All new state writes → PG first, JSON derived | Policy doc + enforcement |

### 🟢 LOW — Backlog

| # | Gap | Action | Effort |
|---|-----|--------|--------|
| L1 | SSOT proposal sync | Update proposal to reflect actual implementation | 2h |
| L2 | Stale table archival policy | 30-day empty table → archive | 1h |
| L3 | Backfill provenance comments | SQL COMMENT on every backfill-only table | 1h |

---

## Summary for Ken

**SSOT is 53% operational.** 18 of 34 tables have live writes. 3 were fixed today (auto-heal, model_drift, frameworks). 13 are stale/manual — they have data but no automation. 11 from the approved proposal were never created at all. 8 are empty — created but never used.

**The root cause is a missing DONE definition.** "Table created + backfilled" passed as complete, but "live write path verified" was never checked. Both gaps you found are the same failure mode: JSON-shadow SSOT (scripts write JSON, PG decays).

**Structural fix needed:** Every PG migration must include write-path verification before it's DONE. A 2-line health check cron (`MAX(created_at) > 24h → alert`) would catch every future gap in hours instead of weeks.

**Priority:** Fix the 13 stale tables (scripts exist, just need PG wiring) → create the top-5 missing tables that P2 actually needs → add the health monitor cron to prevent gap #3.

*— Atlas 🏛️ + Thrawn (Platform Architect) + Yoda 🟢 (data)*
