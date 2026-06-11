# TKT-0406 Thrawn Re-Review — Design v2.0

**Date:** 2026-06-11
**Reviewer:** Thrawn, Platform/Infrastructure Architect
**Design:** TKT-0406 Agile Sprint Working Model Design v2.0
**Previous:** Approved With Changes v1.0 (5 technical conditions)

---

## Condition-by-Condition Assessment

| Condition | Status | Notes |
|-----------|--------|-------|
| 1. Rewrite Sync Flow | **MET** | All event-driven triggers now use `db-ticket.sh sync <ID>` (Path A). Three sync paths clearly distinguished: single-ticket (event-driven), batch reconciliation (cron 30min), integrity audit (daily). The `pg-to-notion-sync.sh` is properly relegated to batch/audit/sprint modes. Clean architecture. |
| 2. Implement Throttling | **MET** | 350ms sleep between ALL Notion API calls specified in both sync script and backfill. Exponential backoff on 429 (1s→2s→4s→8s). Batch backfill pauses 5s between groups of 50. Sustained throughput capped at 2.85 req/sec — safely under Notion's 3 req/sec limit. Estimated 331-ticket backfill runtime of ~4 minutes is realistic. |
| 3. Refine Status Logic | **MET** | v2.0 adopts a technically superior approach to what I originally requested. Rather than embedding "In Sprint" derivation in the shell script's `map_status` function, it uses a Notion-native formula: `if(not empty(prop("Sprint")), "In Sprint", prop("Status"))`. The sync script does only 1:1 PG→Notion mapping (10 statuses fully mapped). This eliminates status derivation bugs — no script can produce wrong values because Notion computes the display. I withdraw my original condition in favor of this cleaner approach. |
| 4. Backfill Safety | **MET** | Comprehensive safety: `--dry-run` flag, `--pilot 5` and `--pilot 50` checkpoints before full run, `--resume` from last successful ticket, pre-modification property snapshots saved per-page before any write, progress tracked per-ticket in `state/pg-notion-backfill-state.json`. The explicit testing flow (dry-run → pilot 5 → pilot 50 → full → integrity audit) is exactly what I required. Test cases 10-11 validate rate limiting and dry-run behavior. |
| 5. Field Alignment | **MET** | All 15 Notion DB A properties explicitly mapped with PG source, transform logic, and writability flag. Impact (#13), Category (#12), and Stream (#11) are fully separated with clear mapping rules. Impact maps from priority, Category maps from type with a comprehensive mapping table, Stream maps from agent. No gaps. |

---

## Technical Soundness (re-assessment)

### Implementation Risks

1. **Backfill idempotency (LOW risk):** The backfill logic correctly branches on `notionpageid` existence (PATCH update vs query-by-title vs CREATE). However, the title-matching recovery path still carries a small collision risk if two tickets share the same title — rare in practice given TKT-ID prefix format but worth noting in the script's error handling. If the title query returns >1 match, the backfill should log and skip (not pick arbitrarily).

2. **Lock file in cron context (LOW risk):** `flock -n` with 1h staleness force-acquire is sound. The 30-minute batch cron naturally self-corrects — if one run is stale-locked, the next run 30 minutes later will force-acquire at the 1-hour mark. Acceptable.

3. **Schema drift detection startup cost (LOW risk):** Querying Notion DB A properties on every `pg-to-notion-sync.sh` startup adds ~1 API call per invocation. For the 30-min batch cron, this is negligible. For the daily audit, also negligible. The design correctly says unknown properties are "ignored (not deleted)" — safe.

4. **Sprint completion batch sync (MEDIUM risk):** `db-sprint.sh complete` triggers `pg-to-notion-sync.sh --sprint <name>` which processes all tickets in the sprint. With carryover handling (sprint reassignment + Notes append), this is the most complex single operation. Forge must ensure the sprint completion is atomic — if it fails mid-batch, tickets should not be left in a partially-migrated state. The design doesn't specify atomicity for sprint completion batch; Forge should wrap in a transaction-like pattern (pre-validate all tickets, then process, track completion). **Mitigation:** This is an implementation detail, not a design gap — flag to Forge.

### Phase Plan Realism

| Phase | Assessment |
|-------|------------|
| Phase 0 (Audit) | Trivial. API queries only. 30 minutes. |
| Phase 1 (Rewrite sync) | Significant work — 15-property jq payload construction, three modes (batch/audit/sprint), rate limiting, lock file, schema drift detection, dry-run. All spec'd. Estimate: 2-3 hours for Forge. |
| Phase 2 (Event integration) | Straightforward — 5 hook points in existing scripts, all using `db-ticket.sh sync <ID> &`. 1 hour. |
| Phase 3 (Cron) | Trivial. 30 minutes. |
| Phase 4 (Backfill) | Script complexity is moderate. The 5-stage testing flow (dry-run through integrity audit) is well-structured and paced. The snapshot-before-write safety net covers the primary data loss risk. 1 hour build + time for Ken's manual checks between stages. |
| Phase 5 (Testing) | 12 test cases comprehensively cover the critical paths. Adequate. |
| Phase 6 (Sign-off) | Sensible gates. |

**Verdict:** Phase plan is realistic. Forge has sufficient specification to execute without ambiguity.

---

## Any New Technical Gaps?

### 1. Metadata column reference (observation, not blocker)

The design references `metadata.notion_sync`, `metadata.carried_over`, `metadata.sprint_committed_at`, `metadata.brief`, `metadata.grooming_history`. These are JSONB paths within the `metadata` column. Forge must confirm these paths match the actual PG schema. If `metadata` uses a different structure (e.g., flattened columns), the sync mapping will fail silently. **Recommendation:** Phase 0 should include a `metadata` column schema verification step.

### 2. Stream mapping edge cases (LOW)

The Stream mapping (agent → stream) maps Thrawn to "Technical." Thrawn is Platform/Infrastructure Architect — technically correct for now, but if Thrawn is later used for non-technical architectural work, this mapping produces wrong categorization. Same risk applies to all agent-to-stream mappings. **Recommendation:** Not a design problem; Lando's BPM domain. Flagged for awareness.

### 3. Notion formula fragility (LOW)

The "In Sprint" Notion formula `if(not empty(prop("Sprint")), "In Sprint", prop("Status"))` depends on the Sprint property name in Notion DB A not changing. Schema drift detection catches property changes, but if someone renames "Sprint" to "Sprint Name" in Notion without updating the formula, the formula silently breaks (returns prop("Status") always). **Recommendation:** Add formula validation to the integrity audit — verify the formula exists and references the correct property names.

### 4. No rollback for sprint completion (observation)

The design states: "Bulk rollback: not supported. Backfill is idempotent per-ticket." For sprint completion with carryover, this is insufficient — if the batch sprint completion fails mid-way, some tickets have been migrated to the next sprint and some haven't. The Notes property for migrated tickets has been appended with "⚠️ Carried over from Sprint N" — there's no undo for this. **Recommendation:** Sprint completion batch should either be fully atomic (all-or-nothing) or include a `--rollback` mode that reverses the sprint reassignment and Notes append for tickets already processed.

---

## Final Verdict

### APPROVE

All 5 technical conditions from my v1.0 review are **MET**. The v2.0 design addresses every concern with specific, implementable specifications.

### Remaining Technical Conditions (for Forge implementation, not design revision)

| # | Condition | Priority | Type |
|---|-----------|----------|------|
| C-01 | Metadata column schema verification in Phase 0 | MEDIUM | Implementation guard |
| C-02 | Sprint completion batch atomicity (all-or-nothing or rollback mode) | MEDIUM | Implementation guard |
| C-03 | Integrity audit should validate Notion formula references | LOW | Enhancement |
| C-04 | Backfill title-match: if query returns >1 result, log and skip (don't pick arbitrarily) | LOW | Edge case |

None of these are design-blocking. They are implementation details for Forge to address during build. The design is technically sound and safe to proceed.

---

### Design Quality Assessment

Compared to v1.0, the v2.0 design shows significant maturation:

- **The three-path sync architecture** (event-driven, batch reconciliation, integrity audit) is clean and solves the "which sync when" problem that plagued v1.0.
- **The Notion-native formula for "In Sprint"** is architecturally superior — it eliminates a whole class of sync bugs by moving derived display logic to the view layer.
- **The backfill safety regime** (snapshots, dry-run, pilot stages, resumability, rate limiting) is SRE-grade.
- **The sprint completion carryover** addresses a previously unhandled lifecycle transition that would have caused drift at every sprint boundary.
- **Schema drift detection** is forward-looking — it anticipates the inevitable Notion property drift that would silently corrupt the sync.

This document is ready for Forge to execute.

---

*Thrawn — Platform/Infrastructure Architect, AInchors Nexus Platform*
*Re-Review v2.0, 2026-06-11*
