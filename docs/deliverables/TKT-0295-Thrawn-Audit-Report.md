# TKT-0295: PG Design-to-Implementation Audit — Thrawn Review
**DRAFT FOR REVIEW — v1.0 — 2026-05-25**
**Author:** Thrawn (Platform Architecture – Nexus Core)
**Joint Audit with:** Atlas (Enterprise Architect)

---

## 1. Executive Summary

This audit reviews the Postgres migration of Nexus core state (TKT-0270, TKT-0271, TKT-0236, TKT-0294) from a platform-architecture perspective. The assessment covers four areas: dual-write path correctness, migration completeness, TQP backend + State Checking compliance, and platform-internal file reference violations.

**⚠️ Methodology Constraint:** This subagent runs with a sandbox restricted to `~/.openclaw/workspace-platform-arch/`. The actual scripts, state files, agent SOUL/RULES files, and cron payloads reside at `~/.openclaw/workspace/`. Direct file inspection was not possible. This report is therefore based on:
1. The detailed context and implementation descriptions provided in the task brief
2. The documented architecture patterns (PLATFORM_ARCH_RULES.md, referenced TKT designs)
3. Architectural pattern analysis against known best practices

**Key Finding:** The described design is architecturally sound but contains implementation gaps. The following require Ken approval before proceeding further.

**Overall Rating:** CONDITIONAL PASS — Proceed to P4 with remediation of 3 high-severity items before production use.

---

## 2. Dual-Write Pattern Assessment (AC2)

### 2.1 Pattern Architecture Review

**Described Pattern:**
- `db-read.sh`: PG → state_v view → JSON file (3-tier fallback)
- `db-write.sh`: PG primary, SQL generation from JSON, unknown columns → metadata JSONB, file fallback on failure
- `state/task-queue.json`: dual-write fallback, cleared after each test

**Architectural Assessment: PASS with observations**

The 3-tier fallback design (PG → view → JSON file) is architecturally correct for a migration-in-progress state. The read path provides graceful degradation.

### 2.2 Edge Cases Identified (Cannot Verify — Requires Direct Inspection)

| # | Edge Case | Risk | Severity |
|---|-----------|------|----------|
| 1 | **View staleness** — `state_v` views may lag behind direct PG queries if materialized views are used without refresh triggers | Reads could return stale data | MEDIUM |
| 2 | **File fallback race condition** — If two writers hit PG failure simultaneously, both fall back to JSON file write without locking | Last write wins, data loss possible | HIGH |
| 3 | **JSONB merge ambiguity** — Unknown columns merged into metadata JSONB could silently swallow data if a known column is misspelled | Silent data loss | MEDIUM |
| 4 | **fsync-after-rename atomicity** — The atomic write pattern (temp → fsync → rename) must be used in ALL write paths. If any path writes directly to the target file, truncation during crash corrupts state | Data corruption on crash | CRITICAL |
| 5 | **Dual-write divergence window** — Between PG write success and file fallback write, a reader could see inconsistent state if PG write succeeds but file write is still in progress | Inconsistent read | LOW |

### 2.3 Atomic Write Pattern Verification

**Architecture Rule:** The atomic write pattern (temp file → fsync → rename) is mandatory for all state file writes during migration.

**Cannot verify implementation.** This requires direct inspection of `db-write.sh` and any other scripts that write to state JSON files. If ANY write path bypasses this pattern (e.g., writing directly to the target file), it introduces a corruption risk.

**Recommendation:** Audit every `>` or `>>` redirect in all scripts that target state files. Each must go through the temp-file pattern.

### 2.4 Fallback Chain Correctness

**Read path (described):** PG → state_v → JSON file

This is architecturally correct. The view layer adds schema stability. However:

**Concern:** Are the views simple SELECTs over the tables, or do they apply business logic? If the latter, view changes could alter the output format and break file-format consumers. Views should be pass-through only during migration.

---

## 3. Migration Completeness (AC3)

### 3.1 Table Population Verification

**Claimed migrated tables (8):**
- `state_tickets`
- `state_cost`
- `state_task_queue`
- `state_model_policy`
- `state_config_baseline`
- `state_sprints`
- `state_linkedin`
- `state_standups`

**Architecture completeness check:** This covers the core operational state domains. However:

**Missing candidates (requires verification):**

| State File | Likely Owner | Risk if Not Migrated |
|------------|-------------|---------------------|
| `state/minio-routing-policy.json` | Infrastructure | LOW — static config, less benefit from PG |
| `state/rules.json` | Governance | MEDIUM — rules change over time, PG would give audit trail |
| `state/heartbeat-state.json` | Platform operations | LOW — ephemeral state |
| `state/model-routing.json` | Model routing | MEDIUM — if T0/T1/T2 routing uses this, PG gives observability |
| Any Notion sync state | Integration | MEDIUM — could be in one of the 8 tables but need to verify |

### 3.2 Agent SOUL/RULES Reference Verification

**Cannot verify directly.** The task brief states agents were updated in TKT-0270 to reference `db-read.sh`. The audit must confirm:

1. Every agent SOUL file that previously read state files directly now uses `db-read.sh`
2. Every agent RULES file that previously wrote state files directly now uses `db-write.sh`
3. No agent has a dual path (sometimes db-read, sometimes direct file read)

**Architecture Concern:** If an agent's SOUL/RULES say to use `db-read.sh` but the implementation falls back to direct file read on error, that's a silent violation. The fallback must be visible in logs.

### 3.3 State Files That Should Have Been Migrated

Based on Nexus platform architecture, the following state domains are candidates for migration but may not have been covered:

1. **Model routing state** — If not in `state_model_policy`, how is T0/T1/T2 routing persistence handled?
2. **Governance approval state** — S1–S7 gates may have pending approvals that need persistence
3. **Observability/ITSM correlation state** — Event-to-incident mappings

**Recommendation:** Cross-reference the 8 migrated tables against the full Nexus data model. Any state domain without PG coverage is a migration gap.

---

## 4. TQP Backend + State Checking Review (AC4)

### 4.1 pg_task_queue.py Architecture Assessment

**Described pattern:**
- Core functions operate on PG task_queue table
- State Checking wrappers (`sc_add`, `sc_claim`, `sc_complete`, `sc_fail`, `sc_reset`)
- Implements TKT-0182 4-step cycle: READ → VALIDATE → EXECUTE → VERIFY

**Architectural Assessment: PASS — pattern is correct**

The State Checking wrapper pattern is architecturally sound:
- `sc_add`: READ queue state → VALIDATE no duplicate → EXECUTE insert → VERIFY row exists
- `sc_claim`: READ queue + claim state → VALIDATE task unclaimed → EXECUTE UPDATE claim → VERIFY claim persisted
- `sc_complete`: READ queue + status → VALIDATE task was claimed → EXECUTE UPDATE status → VERIFY completion
- `sc_fail`: READ queue + retry count → VALIDATE under max retries → EXECUTE UPDATE fail → VERIFY fail state
- `sc_reset`: READ queue → VALIDATE reset eligibility → EXECUTE UPDATE reset → VERIFY reset state

### 4.2 State Checking Coverage Gaps

**Identified gaps (architectural analysis):**

| Gap | Description | Severity |
|-----|-------------|----------|
| **No sc_read** | No State Checking wrapper for reading queue state. Direct reads bypass the VERIFY step. | MEDIUM |
| **No sc_retry** | Retry logic appears to be in `sc_fail` but may not follow a separate cycle with its own VERIFY | LOW |
| **No sc_health** | No health-check wrapper that validates the full TQP pipeline end-to-end | MEDIUM |
| **No batch operations** | If batch claim/complete operations exist, they may bypass per-item State Checking | MEDIUM |

### 4.3 task-queue-processor.sh Integration

**Architecture Assessment: Cannot verify**

Key architectural questions for the processor:
1. Does it use `sc_claim` before processing any task? (Mandatory — prevents double-processing)
2. Does it use `sc_complete` or `sc_fail` after processing? (Mandatory — prevents orphaned tasks)
3. Is there a heartbeat/timeout mechanism for tasks that stall mid-processing?
4. Does it handle PG connection failures gracefully, or does it crash?

### 4.4 State Checking — TKT-0182 Cycle Compliance

**The TKT-0182 4-step cycle is: READ → VALIDATE → EXECUTE → VERIFY**

| Wrapper | READ | VALIDATE | EXECUTE | VERIFY | Compliant? |
|---------|------|----------|---------|--------|------------|
| sc_add | ✅ Reads queue | ✅ No duplicate check | ✅ INSERT | ✅ Row exists check | YES (by description) |
| sc_claim | ✅ Reads queue+claim | ✅ Unclaimed check | ✅ UPDATE claim | ✅ Claim persisted | YES (by description) |
| sc_complete | ✅ Reads status | ✅ Was claimed check | ✅ UPDATE status | ✅ Completion verified | YES (by description) |
| sc_fail | ✅ Reads retry | ✅ Under max retries | ✅ UPDATE fail | ✅ Fail state verified | YES (by description) |
| sc_reset | ✅ Reads queue | ✅ Eligibility check | ✅ UPDATE reset | ✅ Reset verified | YES (by description) |

**Architecture Note:** The pattern is correct but its effectiveness depends on:
1. What constitutes "VERIFY" — is it a simple `SELECT` to confirm the row changed, or does it validate semantic correctness (e.g., status transitions are valid)?
2. Are VERIFY failures handled? Does the wrapper retry or raise an alert?

---

## 5. Platform File Reference Violations (AC5 — Platform-Internal)

**⚠️ Cannot perform live audit due to sandbox restrictions.** The following is an architectural framework for the audit. Atlas should coordinate with the main agent to execute the actual grep scan.

### 5.1 Audit Framework

**Target pattern to scan for:**
```bash
# Direct file reads of state JSON (bypassing db-read.sh)
grep -rn 'state/' --include='*.sh' --include='*.py' --include='*.md' \
  --exclude='db-read.sh' --exclude='db-write.sh' \
  /Users/ainchorsangiefpl/.openclaw/workspace/
```

**Flag these patterns:**
- `cat state/*.json` — raw read, bypasses PG layer
- `jq` directly on `state/*.json` — bypasses PG layer  
- `> state/*.json` — raw write, bypasses atomic write + PG
- `python -c` or inline Python reading state files — may bypass sc_* wrappers

### 5.2 Known Likely Violation Points (Architectural Analysis)

These are files that commonly hold state and may not have been updated in the migration:

| Location | Likely Issue | Risk |
|----------|-------------|------|
| Agent SOUL/RULES for non-core agents | May not have been updated in TKT-0270 if agents were added after migration | MEDIUM |
| `scripts/ticket.sh` | May read `state/tickets.json` directly instead of via db-read.sh | HIGH |
| `scripts/cron-*.sh` | Cron payloads may have hardcoded file paths that weren't updated | HIGH |
| `scripts/task-queue-processor.sh` | May have dual paths — some PG, some file | MEDIUM |
| Integration scripts (Notion, Drive, MinIO sync) | Often hardcode state paths for config | MEDIUM |
| Test scripts | 44 regression tests may read state directly for assertions | LOW (tests are isolated) |

### 5.3 Hardcoded State File Audit Checklist

For each file found referencing `state/` directly:

1. **Does it write?** → Must use `db-write.sh` or `sc_*` wrapper. If direct write flagged: CRITICAL.
2. **Does it read?** → Must use `db-read.sh`. If direct read flagged: HIGH (bypasses PG, loses consistency).
3. **Is it infrastructure config?** → May be exempt if purely static (e.g., MinIO routing policy).
4. **Is it a test?** → May be acceptable if test isolation is needed, but should use test fixtures.

---

## 6. Gaps & Risks

### 6.1 Critical Gaps

| # | Gap | Impact | Mitigation |
|---|-----|--------|------------|
| G1 | **No verified atomic write audit** | Data corruption on crash if writes bypass temp-file pattern | Audit all `>` redirects targeting state files |
| G2 | **No schema versioning in JSONB** | Unknown columns silently merged into metadata; no way to detect schema drift between PG and file | Add `schema_version` to metadata JSONB |
| G3 | **No migration rollback plan** | If PG fails, agents fall back to file but file may be stale from dual-write lag | Define rollback SLA and trigger conditions |

### 6.2 Medium Gaps

| # | Gap | Impact | Mitigation |
|---|-----|--------|------------|
| G4 | **No observability hooks in dual-write** | Cannot monitor divergence between PG and file state | Add metrics: write_success_pg, write_success_file, write_divergence_detected |
| G5 | **No sc_read wrapper** | Reads bypass State Checking VERIFY step | Add sc_read wrapper with VERIFY |
| G6 | **View semantics not documented** | If state_v views contain business logic, consumers break when views change | Document views as pass-through only during migration |
| G7 | **No dead-letter queue for failed writes** | When both PG and file write fail, data is lost | Add dead-letter mechanism |

### 6.3 Risks

| Risk | Likelihood | Impact | Status |
|------|-----------|--------|--------|
| R1: File fallback masks PG outage | Medium | High — state divergence grows silently | No alerting described |
| R2: JSONB merge loses structured data | Low-Medium | Medium — data integrity | Mitigated by TKT-0294 but not verified |
| R3: PG migration increases cold-start latency | Low | Low — acceptable trade-off | Mitigated by 3-tier fallback |
| R4: Two concurrent writers cause JSON file corruption | Low | Critical | Depends on file locking, not described |

---

## 7. Recommendations (Prioritized)

### Priority 1 — Must Fix Before Production

1. **Atomic Write Audit (G1):** Scan every write path to state files. Confirm all use temp-file → fsync → rename. This is CRITICAL for data integrity.

2. **Hardcoded File Reference Scan (AC5):** Execute the grep-based audit described in Section 5. Flag every direct state file read/write outside `db-read.sh` and `db-write.sh`. Fix before production.

3. **Dual-Write Divergence Monitoring (G4):** Add observability: log every PG write result and file write result. Alert on divergence.

### Priority 2 — Should Fix Before P4 Completion

4. **Schema Versioning (G2):** Add `_schema_version` to every table's metadata JSONB. This enables future schema migrations and detects drift.

5. **sc_read Wrapper (G5):** Complete State Checking coverage by adding a read wrapper with VERIFY.

6. **Dead-Letter Queue (G7):** Implement a dead-letter mechanism for writes that fail on both PG and file paths.

### Priority 3 — Nice to Have

7. **Rollback Plan (G3):** Document conditions that trigger rollback from PG to file-only mode, and the SLA for recovery.

8. **View Documentation (G6):** Document state_v as pass-through only during migration phase. Plan to deprecate views once migration is complete and verified.

9. **File Locking for Concurrent Writers (R4):** Implement advisory file locking (flock) for the file fallback path.

### Shared Recommendation with Atlas

10. **Cross-reference state domain coverage:** Atlas should verify that all enterprise-mandated state domains (especially governance/approval state for S1–S7 gates) are captured in the 8 migrated tables.

---

## Appendix A: Audit Scope Limitations

This audit was conducted with the following limitations:

1. **Sandbox restriction:** Subagent confined to `~/.openclaw/workspace-platform-arch/`. Cannot read scripts at `~/.openclaw/workspace/scripts/` or state at `~/.openclaw/workspace/state/`.
2. **No execution capability:** Cannot run the 44 regression tests to verify pass rates.
3. **No live PG access:** Cannot query tables to verify population and data integrity.

**Remediation:** The main agent (or Atlas's subagent) must execute the grep scans, table queries, and test verifications described in this report. This report provides the architectural framework and risk assessment; the implementation-level findings (specific file:line violations) require direct filesystem access.

---

## Appendix B: Verification Checklist for Main Agent

The following checks require direct filesystem/DB access and should be performed by the main agent to complete this audit:

- [ ] AC2.1: Grep `db-read.sh` for the temp-file atomic write pattern
- [ ] AC2.2: Grep `db-write.sh` for all `>` redirects — confirm all use temp-file
- [ ] AC3.1: `psql` query to count rows in all 8 tables
- [ ] AC3.2: Grep all agent SOUL/RULES files for `db-read.sh` reference
- [ ] AC3.3: Grep all agent SOUL/RULES files for direct `state/` reads
- [ ] AC4.1: Read `pg_task_queue.py` — verify sc_* wrappers implement full 4-step cycle
- [ ] AC4.2: Read `task-queue-processor.sh` — verify sc_claim/sc_complete usage
- [ ] AC5.1: Full grep scan for direct state file references (as described in Section 5)
- [ ] AC5.2: Check `scripts/ticket.sh` for direct state file access
- [ ] AC5.3: Check all `cron-*.sh` scripts for state file references
- [ ] AC5.4: Check all integration scripts (Notion, Drive, MinIO) for state file access

---

**Document Status:** DRAFT FOR REVIEW
**Next Step:** Atlas review → Ken approval → Remediation items assigned
**Architecture Rule:** No implementation until Ken approves. This is audit only.
