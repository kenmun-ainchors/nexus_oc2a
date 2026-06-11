# TKT-0406 Thrawn Review

## 1. Implementation Feasibility
The implementation plan is feasible, but the "Phases" are overly optimistic regarding the existing script state. Lando treats the scripts as modular components to be "updated," whereas they currently contain hard-coded logic that contradicts the new design (e.g., `pg-to-notion-sync.sh` has its own status mapping that differs from Lando's table).

- **Phase 1 (Fix Sync):** Feasible. However, expanding to 14 properties requires a careful migration of the `jq` payloads.
- **Phase 2 (Event-Driven):** Feasible. The hooks are already partially present in `db-ticket.sh` (calling `pg-to-notion-sync.sh` in background), but need to be standardized.
- **Phase 3 (Cron):** Trivial.
- **Phase 4 (Backfill):** High risk without the rate-limiting identified by Yoda.

## 2. Script Integration Accuracy
Lando's understanding of the script integration is **partially inaccurate**:

- **`pg-to-notion-sync.sh`:** Lando views this as the primary "sync engine." In reality, it is currently a batch script. The design needs to distinguish between a `sync-single <ID>` mode and a `sync-all` mode to avoid the "wasteful batch" problem (GAP-02).
- **`db-ticket.sh`:** The design assumes a simple "call sync at completion." However, `db-ticket.sh` already has a `sync` subcommand that wraps the sync script and updates `metadata.notion_sync`. Lando should be utilizing the `sync` subcommand rather than raw script calls to maintain the `notion_sync` state tracking.
- **`db-sprint.sh`:** Integration is accurate; `commit` and `defer` are the correct trigger points for sprint-related Notion updates.

## 3. Technical Risks & Edge Cases
- **Notion API Rate Limits:** Lando ignores the 3 req/sec limit. A batch sync of 331 tickets with "Query-before-create" (1 read + 1 write per ticket) will trigger 4029 errors without strict throttling.
- **Race Conditions:** While a lock file is mentioned, the background execution of `pg-to-notion-sync.sh` from `db-ticket.sh` (using `&`) can lead to multiple sync processes fighting for the lock, causing some updates to be dropped silently.
- **Status Mapping Drift:** There is a discrepancy between the design's "In Sprint" logic and the actual `map_status` function in `pg-to-notion-sync.sh`.
- **PG Lock Contention:** Low risk for 300 tickets, but the "Daily Integrity Audit" performing full table scans and Notion API dumps could cause transient timeouts if not optimized.

## 4. Backfill Safety Assessment
The backfill is **UNSAFE** as currently designed.
- **Risk:** 331 tickets $\times$ (Search + Create/Update) = ~660+ API calls. Without the 350ms sleep identified in GAP-05, the script will be rate-limited by Notion within seconds.
- **Data Loss:** "Matching by title" is fragile. If a ticket title was changed in PG but not Notion, the backfill will create a duplicate. The `notionpageid` must be the primary key; title-matching should be a secondary "recovery" only.

## 5. Yoda Gap Report — Technical Assessment
- **GAP-01 (Field Mapping): AGREE.** Severity: MEDIUM. Technical Note: Lando's mapping is missing specific select properties (Impact/Category). Forge must explicitly define these in the `jq` payload.
- **GAP-02 (Sync Path): AGREE.** Severity: HIGH. Technical Note: Critical architectural flaw. `db-ticket.sh sync <ID>` must be the atomic operation, not a call to the batch script.
- **GAP-03 (Status Edge Case): AGREE.** Severity: MEDIUM. Technical Note: Notion Status is a derived view. The logic `(Status=Open && Sprint=Active) ? 'In Sprint' : 'Backlog'` must be implemented in the sync script's mapping logic.
- **GAP-04 (Create Flow): AGREE.** Severity: HIGH. Technical Note: Creating "empty" Notion pages is noisy. Deferring sync until the first `groom` or `update` is technically cleaner.
- **GAP-05 (Rate Limiting): AGREE.** Severity: HIGH. Technical Note: Mandatory. Notion API is strictly 3 req/sec.
- **GAP-06 (Sprint Assignment): AGREE.** Severity: HIGH. Technical Note: This is a process gap, but technically, `db-ticket.sh create` needs a prompt for `sprint_target` to prevent the "300 empty sprints" problem.
- **GAP-07 (Testing): AGREE.** Severity: LOW. Technical Note: Standard SRE practice. `--dry-run` is required for the backfill script.

## 6. Verdict
**APPROVE WITH CHANGES**

**Conditions for Safe Implementation:**
1. **Rewrite Sync Flow:** Replace "call `pg-to-notion-sync.sh`" with "call `db-ticket.sh sync <ID>`" for all event-driven triggers.
2. **Implement Throttling:** Add a mandatory 350ms sleep between all Notion API calls in `pg-to-notion-sync.sh` and the backfill script.
3. **Refine Status Logic:** Update `map_status` to include the "In Sprint" vs "Backlog" derivation based on `sprint_target` and sprint activity.
4. **Backfill Safety:** The backfill script must implement `--dry-run` and a "Verify 5 tickets" phase before proceeding to the full 331.
5. **Field Alignment:** Explicitly map 'Impact' and 'Category' as separate Notion properties.
