# TKT-0406: Agile Sprint Working Model Design v1.0

**Author:** Lando (BPM Specialist)
**Status:** Draft for Review
**Date:** 2026-06-11
**Scope:** Synchronization of PostgreSQL (SSOT) to Notion DB A (Derived View)

---

## SECTION 1: Data Flow Architecture

### Ticket Lifecycle
The ticket lifecycle manages the progression of a task from inception to archive.
1. **Create** $\rightarrow$ **Groom** $\rightarrow$ **Sprint Commit** $\rightarrow$ **Status Change** $\rightarrow$ **Close** $\rightarrow$ **Archive**

| Transition | PG Table Update | Notion Properties Synced | Sync Trigger |
| :--- | :--- | :--- | :--- |
| Create | `state_tickets` (INSERT) | US Title, Status, Priority, Type, Created Date | `db-ticket.sh create` |
| Groom | `state_tickets` (UPDATE metadata) | Yoda Assessment, Notes, Effort | `db-ticket.sh update` |
| Sprint Commit | `state_tickets` (UPDATE sprint/metadata) | Sprint, Planned Date, Sprint Date | `db-sprint.sh commit` |
| Status Change | `state_tickets` (UPDATE status) | Status | `db-ticket.sh update` |
| Close | `state_tickets` (UPDATE status/updated_at) | Status, Delivered Date | `db-ticket.sh update` |
| Archive | `state_tickets` (UPDATE status) | Status (Deferred/Done) | `db-ticket.sh update` |

### Sprint Lifecycle
The sprint lifecycle manages the temporal containers for ticket commitment.
1. **Create** $\rightarrow$ **Plan** $\rightarrow$ **Commit** $\rightarrow$ **Active** $\rightarrow$ **Complete**

| Transition | PG Table Update | Notion Impact | Sync Trigger |
| :--- | :--- | :--- | :--- |
| Create/Plan | `sprints` table | N/A | N/A |
| Commit | `state_tickets` (bulk update sprint) | Sprint, Planned Date, Sprint Date | `db-sprint.sh commit` |
| Complete | `sprints` table | N/A | Batch Sync / Audit |

---

## SECTION 2: Sync Mechanism Design

### Full Field Mapping Table
PostgreSQL is the Single Source of Truth (SSOT). All mappings are unidirectional (PG $\rightarrow$ Notion).

| PG Source | Notion Property | Transform | Notes |
| :--- | :--- | :--- | :--- |
| `id` | US Title | `TKT-` + id | Unique identifier in title |
| `status` | Status | See Status Mapping Table | Derived status |
| `priority` | Priority | Direct map | |
| `sprint` | Sprint | Direct map | Handle NULLs gracefully |
| `created_at` | Created Date | ISO Date | |
| `type` | Type | Direct map | |
| `metadata.effort` | Effort | Direct map | |
| `metadata.sprint_committed_at`| Planned Date | ISO Date | |
| `updated_at` (on close) | Delivered Date | ISO Date | Only sync when status $\in$ {done, closed} |
| `metadata.sprint_target` + dates| Sprint Date | Date Range | Combined target and dates |
| `metadata.agent` | Stream/Category | Direct map | |
| `metadata.brief` | Notes | Direct map | |
| grooming summary | Yoda Assessment | Direct map | Extracted from grooming logs |

### Status Mapping Table
| PG Status | Notion Status | Condition/Note |
| :--- | :--- | :--- |
| `open` | Backlog / In Sprint | "In Sprint" if `sprint_target` is set, else "Backlog" |
| `in-progress` | In Progress | |
| `done` / `closed` | Done | Triggers `Delivered Date` update |
| `backlog` | Backlog | |
| `blocked` | Blocked | |
| `cancelled` | Deferred | |
| `pending` | Pending | |
| `monitoring` | In Progress | |

### Sync Triggers
- **Ticket Create:** Immediate single-ticket sync $\rightarrow$ Create Notion page.
- **Ticket Update:** Immediate single-ticket sync $\rightarrow$ Update Notion page.
- **Sprint Commit:** Immediate sync of target ticket's sprint fields.
- **Status Change (Done/Closed):** Immediate sync including `Delivered Date`.
- **Batch Reconciliation:** Every 30 minutes $\rightarrow$ Full sync of all tickets where `updated_at` > last run.
- **Daily Integrity Audit:** 01:00 AEST $\rightarrow$ Full reconciliation and deduplication.

### Deduplication Strategy
To prevent duplicate pages in Notion DB A:
1. **Query-Before-Create:** Before creating a page, query DB A for any page containing the `TKT-ID` in the title.
2. **Link Recovery:** If a match is found but `notionpageid` is NULL in PG, update PG with the found `notionpageid`.
3. **Conflict Resolution:** If a match is found and `notionpageid` differs, the PG value is authoritative. The orphan Notion page is moved to DB C (Archive).
4. **Strict Linkage:** Never create a new page if PG already possesses a valid `notionpageid`.

### Orphan Detection
- **Process:** Query all pages in Notion DB A $\rightarrow$ Extract TKT-IDs from titles.
- **Comparison:** Compare extracted IDs against all IDs in PG `state_tickets`.
- **Action:** Any page existing in Notion but missing from PG is designated an "Orphan" and moved to DB C (Archive).

---

## SECTION 3: Automation Architecture

### Cron Jobs Required
1. `pg-notion-sync-batch`: Every 30 min. Syncs changed tickets since last run.
2. `pg-notion-integrity-audit`: Daily at 01:00 AEST. Full reconciliation, deduplication, and orphan check.
3. `pg-notion-sprint-sync`: Triggered on sprint plan/commit to sync all associated tickets.

### Event-Driven Sync
Integration hooks within existing scripts:
- `db-ticket.sh create` $\rightarrow$ call `pg-to-notion-sync.sh` at completion.
- `db-ticket.sh update` $\rightarrow$ call `pg-to-notion-sync.sh` at completion.
- `db-sprint.sh commit` $\rightarrow$ call `pg-to-notion-sync.sh` for the affected ticket.
- `db-sprint.sh defer` $\rightarrow$ call `pg-to-notion-sync.sh` for the affected ticket.

### Error Handling
- **Concurrency:** Lock file used at `/tmp/pg-notion-sync.lock` to prevent race conditions.
- **Retries:** Max 3 retries with exponential backoff (30s, 60s, 120s).
- **Logging:** Final failures logged to `state/pg-notion-sync-errors.json`.
- **Alerting:** Failures logged to the error file trigger a Telegram alert.
- **Non-Blocking:** Sync is a "best-effort" side effect. Ticket creation/updates in PG must succeed regardless of sync outcome.

---

## SECTION 4: Data Integrity Guarantees

### Duplicate Prevention
- Implementation of the **Query-before-create** pattern.
- `notionpageid` serves as the unique link between the two systems.
- Atomic write-back: Immediately update PG with the `notionpageid` after a successful Notion page creation.

### Field Completeness
- **Full Write Policy:** Every sync operation must attempt to write all 14 properties. Unknown or missing values must be written as null/empty to ensure Notion is not left with stale data.
- **Spot-Check Validation:** After batch syncs, the system will randomly sample 5 pages to verify all 14 properties are populated.

### Failure Handling
- **Error Log:** `state/pg-notion-sync-errors.json` tracks timestamp, ticket ID, and error message.
- **Escalation:** 3 consecutive failures for a specific ticket $\rightarrow$ Telegram alert to Ken.
- **DLQ (Dead-Letter Queue):** Tickets failing 5+ times are flagged for manual review.

### Validation Checks (Daily Integrity Audit)
1. **Count Check:** Compare total PG tickets vs total Notion pages; alert if mismatch $> 5$.
2. **Duplicate Check:** Scan Notion titles for duplicate TKT-IDs.
3. **Freshness Check:** Verify the last 20 created tickets exist in Notion.
4. **Status Check:** Verify the last 20 updated tickets have matching statuses in Notion.
5. **Reference Check:** Ensure no `notionpageid` values point to deleted/non-existent pages.

---

## SECTION 5: Implementation Plan

### Phase 1: Fix `pg-to-notion-sync.sh` (Forge)
- Expand field mapping to include all 14 required properties.
- Implement the query-before-create deduplication logic.
- Update status mapping to the comprehensive list (including "In Sprint" logic).
- Map `metadata.sprint_target` to Notion Sprint fields.
- Map `created_at` to "Created Date".

### Phase 2: Add Event-Driven Sync (Forge)
- Integrate sync triggers into `db-ticket.sh` (create/update).
- Integrate sync triggers into `db-sprint.sh` (commit/defer).

### Phase 3: Add Cron Jobs (Yoda)
- Schedule the 30-minute batch sync.
- Schedule the daily 01:00 AEST integrity audit.

### Phase 4: Backfill (Forge)
- **Tool:** One-time script `scripts/pg-notion-backfill.sh`.
- **Logic:** 
    - For existing `notionpageid`: Update all 14 properties.
    - For missing `notionpageid`: Match by title $\rightarrow$ Link or Create.
- **Throttling:** Process in batches of 50 to prevent Notion API rate limiting.
- **Tracking:** Progress logged in `state/pg-notion-backfill-state.json`.

### Phase 5: Validation & Sign-off
- Execute a full daily integrity audit.
- Ken review of Notion DB A for visual completeness.
- Atlas/Thrawn spot-check 20 random tickets for accuracy.

---

## SECTION 6: Governance

### Ownership
| Role | Agent | Responsibility |
| :--- | :--- | :--- |
| **Process Owner** | Lando | Defines process, field mappings, and business rules. |
| **Implementation**| Forge | Develops and maintains sync scripts. |
| **Oversight** | Yoda | Monitors sync health and manages alerts. |
| **Review** | Atlas + Thrawn| Technical design review prior to implementation. |
| **Approval** | Ken | Final sign-off on design and go-live. |

### Monitoring
- **Integrity Reports:** Daily audit results sent via Telegram to Ken.
- **Real-time Alerts:** Sync failures sent via Telegram to Ken.
- **Health Summary:** Weekly automated sprint health summary generated in Notion.

### Regular Audits
- **Daily:** Automated integrity check (Cron).
- **Weekly:** Manual spot-check of 10 random tickets by Yoda.
- **Sprint Boundary:** Full reconciliation performed before the sprint review.

### Ken's Review Cadence
- **Design:** Review and approve this document before Phase 1.
- **Backfill:** Review Notion DB A after Phase 4 completion.
- **Weekly:** 30-second visual check of AKB Backlog against PG reality.

---

## CONSTRAINTS & NOTES
- **SSOT:** PostgreSQL is the ONLY source of truth. Notion is a read-only derived view. **Writing from Notion to PG is strictly forbidden.**
- **Scale:** System must handle 300+ tickets without sprint assignments without crashing or skipping.
- **Idempotency:** All sync operations must be safe to run multiple times without creating duplicates.
- **Persistence:** All existing `notionpageid` links must be preserved.
- **Location:** All scripts must reside in `/Users/ainchorsangiefpl/.openclaw/workspace/scripts/`.
