# TKT-0406: Agile Sprint Working Model Design v2.0

**Author:** Lando (BPM Specialist) — revised per Atlas + Thrawn reviews
**Status:** Draft for Re-Review
**Date:** 2026-06-11
**Scope:** Synchronization of PostgreSQL (SSOT) to Notion DB A (Derived View)

---

## Revision Notes (v1.0 → v2.0)

| Change | Condition Addressed | Description |
|--------|---------------------|-------------|
| Added Sprint Triage step to lifecycle | C-01 (CRITICAL) | New "Sprint Triage" phase between Create and Groom with batch assignment |
| Added Sprint Completion Handling | C-02 (CRITICAL) | Auto-carryover to next sprint with "Carried Over" flag in Notion |
| Clarified sync paths (single vs batch) | C-03 (HIGH) | Event hooks → `db-ticket.sh sync <ID>`; batch → `pg-to-notion-sync.sh --batch` |
| Completed Field Mapping (15 properties) | C-04 (HIGH) | Separated Stream/Category, added Impact, labeled N/A properties |
| Added Testing Strategy section | C-05 (HIGH) | `--dry-run`, 5→50→full pilot, rollback, test cases |
| Sprint column as authoritative source | C-06 (HIGH) | `sprint` column (TKT-0391 first-class) is sync source |
| Added Rate Limiting specification | C-07 (HIGH) | 350ms sleep, 429 backoff, batch math |
| Simplified Status Mapping (Option B) | C-08 (MEDIUM) | 1:1 PG→Notion mapping; "In Sprint" is Notion-native formula |
| Fixed Batch Query to use notion_sync | C-09 (MEDIUM) | `WHERE notion_sync.status != 'synced'` |
| Component Registry section added | C-10 (LOW) | Holocron + SOT register items listed |
| Backfill snapshot + resumable batches | Atlas additional | Save pre-modification state, track progress by ticket |
| Lock file staleness (1h force-acquire) | Atlas additional | Added to error handling |
| DLQ threshold reduced to 3 failures | Atlas additional | 3 failures → DLQ + alert |
| Notion writable property verification | Atlas additional | Pre-implementation audit step |
| Schema drift detection | Atlas additional | Startup validation of DB A properties |

---

## SECTION 1: Data Flow Architecture

### Ticket Lifecycle (Revised)

```
Create → Sprint Triage → Groom → Sprint Commit → Status Change → Close → Archive
```

| Transition | PG Table Update | Notion Properties Synced | Sync Trigger |
|:---|:---|:---|:---|
| **Create** | `state_tickets` (INSERT) | None (deferred to groom) | PG only |
| **Sprint Triage** | `state_tickets` (UPDATE sprint) | Sprint, Planned Date | `db-sprint.sh commit` |
| **Groom** | `state_tickets` (UPDATE metadata) | US Title, Status, Priority, Type, Created Date, Effort, Notes, Yoda Assessment, Stream, Category, Impact | `db-ticket.sh sync <ID>` |
| **Sprint Commit** | `state_tickets` (UPDATE sprint/metadata) | Sprint, Planned Date, Sprint Date, Status → "In Sprint" (via Notion formula) | `db-ticket.sh sync <ID>` |
| **Status Change** | `state_tickets` (UPDATE status) | Status | `db-ticket.sh sync <ID>` |
| **Close** | `state_tickets` (UPDATE status/updated_at) | Status, Delivered Date | `db-ticket.sh sync <ID>` |
| **Archive** | `state_tickets` (UPDATE status) | Status (Deferred/Done) | `db-ticket.sh sync <ID>` |

**Key change from v1.0:** Ticket creation writes to PG only — NO Notion sync. First sync happens at Groom, when all metadata is populated. This eliminates the "sparse page" problem (GAP-04).

### Sprint Triage (NEW)

Between Create and Groom, a mandatory Sprint Triage step:

1. **On `db-ticket.sh create`:** Prompts "Assign to sprint? [current sprint / other / skip]". If assigned, sets `sprint` column.
2. **Batch Triage during Sprint Planning:** `db-sprint.sh plan` displays unsprinted open tickets. Option to batch-assign to current sprint.
3. **Unsprinted Ticket Query:** `SELECT id, title, priority FROM state_tickets WHERE (sprint IS NULL OR sprint = '') AND status = 'open' ORDER BY priority, created_at;`
4. **Weekly Triage Reminder:** Daily integrity audit flags unsprinted open tickets in report.

### Sprint Lifecycle (Revised)

```
Create → Plan → Commit → Active → Complete (with carryover handling)
```

| Transition | PG Table Update | Notion Impact | Sync Trigger |
|:---|:---|:---|:---|
| Create/Plan | `state_sprints` (INSERT/UPDATE) | N/A | N/A |
| Commit | `state_tickets` (bulk update sprint) | Sprint, Planned Date, Sprint Date | Per-ticket `db-ticket.sh sync <ID>` |
| Active | `state_sprints` (UPDATE status) | N/A | N/A |
| Complete | `state_sprints` (UPDATE status) + ticket migration | Sprint reassignment for open tickets | Batch sync |

### Sprint Completion Handling (NEW — C-02)

When a sprint completes:
1. **Completed tickets (status = done/closed):** No change. Delivered Date already set. Sprint field preserved for historical record.
2. **Open tickets (status = open/in-progress/blocked):** Auto-migrated to next sprint:
   - `sprint` column updated to next sprint name
   - `metadata.carried_over` set to `true`
   - `metadata.carried_over_from` set to completed sprint name
   - `metadata.carried_over_at` set to current timestamp
   - Notion: Sprint property updated to next sprint; Notes appended with "⚠️ Carried over from Sprint N"
3. **Notion formula for "In Sprint":** `if(not empty(prop("Sprint")) and prop("Sprint") != "Backlog", "In Sprint", prop("Status"))` — computed natively, NOT in shell script.
4. **Alert:** Sprint completion with > 3 open tickets triggers Telegram alert to Ken.

---

## SECTION 2: Sync Mechanism Design

### Full Field Mapping Table (COMPLETE — C-04)

PG is SSOT. All mappings unidirectional (PG → Notion). Notion DB A has 15 properties. Every property mapped:

| # | Notion Property | Property Type | PG Source | Transform | Writable? |
|:--|:---|:---|:---|:---|:--|
| 1 | US Title | title | `id` | `[TKT-XXXX] ` + `title` | ✅ |
| 2 | Status | select | `status` | See Status Mapping Table | ✅ |
| 3 | Priority | select | `priority` | Direct map (capitalize first letter) | ✅ |
| 4 | Sprint | select | `sprint` column (TKT-0391) | Direct map; NULL → empty (no selection) | ✅ |
| 5 | Type | select | `type` | Direct map | ✅ |
| 6 | Effort | select | `metadata.effort` | Direct map | ✅ |
| 7 | Created Date | date | `created_at` | ISO date string → Notion date | ✅ |
| 8 | Planned Date | date | `metadata.sprint_committed_at` | ISO date string; NULL if not committed | ✅ |
| 9 | Delivered Date | date | `updated_at` (when status ∈ {done, closed}) | Only set on close; NULL for all other states | ✅ |
| 10 | Sprint Date | date | `state_sprints.start_date` for assigned sprint | Sprint's start date from sprints table | ✅ |
| 11 | Stream | select | `metadata.agent` | Maps agent → stream: Forge→Technical, Aria→Business, Yoda→Technical, Thrawn→Technical, Atlas→Technical, Lando→Business, Spark→Business, Mon Mothma→Business, Shield/Lex/Sage→Cross-stream | ✅ |
| 12 | Category | select | `type` with mapping | task→Technical, bug→Technical, build→Platform, epic→Platform, feature→Platform, story→Business, chg→Operations, policy→Operations | ✅ |
| 13 | Impact | select | `priority` with mapping | critical→High, high→High, medium→Medium, low→Low | ✅ |
| 14 | Notes | rich_text | `metadata.brief` | Direct map; append carried_over note if applicable | ✅ |
| 15 | Yoda Assessment | rich_text | Latest `metadata.grooming_history[].decisions` | Most recent grooming entry's decisions text | ✅ |

**Notion-native properties (NOT written by sync):**
- "In Sprint" status display: Notion formula `if(not empty(prop("Sprint")), "In Sprint", prop("Status"))` — computed entirely in Notion, never from shell script.

### Status Mapping Table (SIMPLIFIED — C-08)

**Design decision: Option B — Notion-native formula for "In Sprint".** Shell script does simple 1:1 mapping. No derived/computed statuses in sync code.

| PG Status | Notion Status (synced) | Notion Display (formula) |
|:---|:---|:---|
| `open` | Open | "In Sprint" if Sprint field set, else "Open" |
| `in-progress` | In Progress | "In Sprint" if Sprint field set, else "In Progress" |
| `done` | Done | Done |
| `closed` | Closed | Closed |
| `backlog` | Backlog | Backlog |
| `blocked` | Blocked | Blocked |
| `cancelled` | Cancelled | Cancelled |
| `pending` | Pending | Pending |
| `monitoring` | In Progress | In Progress |
| `folded` | Done | Done |

### Sync Triggers (CLARIFIED — C-03)

Three distinct sync paths:

**Path A — Single-Ticket Sync (event-driven, immediate):**
- Trigger: `db-ticket.sh sync <TKT-ID>`
- Called from: `db-ticket.sh update`, `db-ticket.sh groom`, `db-sprint.sh commit`, `db-sprint.sh defer`
- Behavior: Query-before-create if no `notionpageid`, else PATCH update. Writes all 15 properties.
- Execution: Backgrounded (`&`) so ticket operations don't block on sync

**Path B — Batch Reconciliation (periodic, every 30 min):**
- Trigger: Cron `pg-notion-sync-batch`
- Script: `pg-to-notion-sync.sh --batch`
- Query: `SELECT * FROM state_tickets WHERE notion_sync->>'status' != 'synced' ORDER BY updated_at`
- Behavior: Process each unsynced ticket via Path A logic. Track progress.
- Self-healing: catches tickets whose event-driven sync failed

**Path C — Integrity Audit (daily, 01:00 AEST):**
- Trigger: Cron `pg-notion-integrity-audit`
- Script: `pg-to-notion-sync.sh --audit`
- Behavior: Full reconciliation — count check, duplicate check, freshness check, status check, reference check. Report to Telegram.

### Deduplication Strategy (unchanged from v1.0, validated by both reviewers)

1. **Query-Before-Create:** Before creating a Notion page, query DB A for any page containing the TKT-ID in the title.
2. **Link Recovery:** If match found but `notionpageid` is NULL in PG, update PG with the found Notion page ID.
3. **Conflict Resolution:** If match found and `notionpageid` differs, PG value is authoritative. Orphan Notion page moved to DB C (Archive).
4. **Strict Linkage:** Never create a new page if PG already has a valid `notionpageid`.

### Orphan Detection (unchanged, validated)
- Query all Notion DB A pages, extract TKT-IDs from titles.
- Compare against all PG `state_tickets` IDs.
- Orphans (Notion-only) → move to DB C (Archive) with reason "Orphan: no PG ticket".
- Log all orphan moves.

---

## SECTION 3: Automation Architecture

### Cron Jobs Required

| Cron | Schedule | Script | Purpose |
|:---|:---|:---|:---|
| `pg-notion-sync-batch` | Every 30 min | `pg-to-notion-sync.sh --batch` | Sync all tickets with `notion_sync.status != 'synced'` |
| `pg-notion-integrity-audit` | Daily 01:00 AEST | `pg-to-notion-sync.sh --audit` | Full reconciliation + dedup + orphan check + report |
| `pg-notion-sprint-sync` | On sprint commit | `pg-to-notion-sync.sh --sprint <name>` | Sync all tickets in a sprint (bulk commit trigger) |

### Event-Driven Sync (CLARIFIED — C-03)

Integration hooks within existing scripts:

```
db-ticket.sh create  → NO sync (PG only, defer to groom)
db-ticket.sh groom   → on success: db-ticket.sh sync <TKT-ID> &
db-ticket.sh update  → on success: db-ticket.sh sync <TKT-ID> &
db-sprint.sh commit  → on success: db-ticket.sh sync <TKT-ID> &
db-sprint.sh defer   → on success: db-ticket.sh sync <TKT-ID> &
db-sprint.sh complete → on success: pg-to-notion-sync.sh --sprint <name> (batch)
```

All sync calls are backgrounded (`&`) — non-blocking. Ticket operations succeed regardless of sync outcome.

### Error Handling (UPDATED)

- **Concurrency:** Lock file at `/tmp/pg-notion-sync.lock`. `flock -n` (non-blocking, exit if locked).
- **Lock Staleness:** If lock file is > 1 hour old, force-acquire (kill stale process if any).
- **Retries:** Max 3 retries with exponential backoff (30s, 60s, 120s).
- **Logging:** Final failures logged to `state/pg-notion-sync-errors.json` with timestamp, ticket ID, error message, retry count.
- **Alerting:** 3 consecutive failures for same ticket → Telegram alert to Ken.
- **DLQ (Dead-Letter Queue):** Tickets failing 3 times (not 5) → flagged for manual review in `state/pg-notion-sync-dlq.json`.
- **Non-Blocking:** Sync is best-effort. PG operations always succeed independently.
- **Rate Limiting:** 350ms sleep between ALL Notion API calls. On HTTP 429: exponential backoff (1s, 2s, 4s, 8s) then fail.

---

## SECTION 4: Data Integrity Guarantees

### Duplicate Prevention
- **Query-before-create** pattern on every Notion page creation.
- `notionpageid` is the single unique link between systems.
- Atomic write-back: immediately update PG `notionpageid` after Notion page creation.
- Title-based matching as secondary recovery only (when `notionpageid` is NULL).

### Field Completeness
- **Full Write Policy:** Every sync writes all 15 properties. Unknown/missing values written as null/empty.
- **Notion Writable Verification (NEW):** Before implementation, audit live DB A to identify formula/rollup/created_time properties. Exclude non-writable properties from sync payload. Current assessment: all 15 above are writable; "In Sprint" display formula is Notion-native (not writable, handled separately).
- **Spot-Check:** After batch sync, randomly sample 5 pages and verify all 15 properties populated.
- **Conditional Properties:** Delivered Date only synced on close (NULL otherwise). Planned Date only synced on sprint commit (NULL otherwise).

### Failure Handling
- **Error Log:** `state/pg-notion-sync-errors.json` (PG T3 migration path noted).
- **Escalation:** 3 consecutive failures → Telegram alert to Ken.
- **DLQ:** 3 failures (reduced from 5) → manual review flag.
- **Self-Healing:** Batch reconciliation catches all tickets with `notion_sync.status != 'synced'`, including those whose event-driven sync failed.

### Validation Checks (Daily Integrity Audit)
1. **Count Check:** PG total vs Notion total; alert if mismatch > 5.
2. **Duplicate Check:** Scan Notion titles for duplicate TKT-IDs.
3. **Freshness Check:** Verify last 20 created tickets exist in Notion.
4. **Status Check:** Verify last 20 updated tickets have matching Status in Notion.
5. **Reference Check:** Ensure no `notionpageid` values point to deleted pages.
6. **Unsprinted Check (NEW):** Identify open tickets with no sprint assignment. Report count.
7. **Carryover Check (NEW):** Identify tickets flagged `carried_over` that are still open after 2 sprints. Flag for Ken.

### Schema Drift Detection (NEW)
On startup of `pg-to-notion-sync.sh`:
1. Query Notion DB A properties via API.
2. Compare against expected property list (15 properties above).
3. If mismatch (added/removed/renamed properties): log warning, continue with known properties, alert via Telegram.
4. Known properties are synced; unknown properties are ignored (not deleted).

---

## SECTION 5: Implementation Plan

### Phase 0: Pre-Implementation Audit (Forge)
- Verify Notion DB A properties — which are writable vs. computed (formula/rollup/created_time).
- Verify `sprint` column is populated in PG for all tickets that have `metadata.sprint_target` set (TKT-0391 reconciliation).
- Confirm Notion API key has write access to DB A and DB C.

### Phase 1: Fix `pg-to-notion-sync.sh` (Forge)
- Rewrite field mapping to cover all 15 properties (Section 2 mapping table).
- Implement query-before-create deduplication.
- Update status mapping to 1:1 (Section 2 status table).
- Map `sprint` column → Notion Sprint property.
- Map `created_at` → Created Date.
- Implement `--batch` mode (process unsynced tickets).
- Implement `--audit` mode (integrity checks).
- Implement `--sprint <name>` mode (sync all tickets in a sprint).
- Implement `--dry-run` flag.
- Implement rate limiting (350ms sleep, 429 backoff).
- Implement lock file with staleness detection (> 1 hour force-acquire).
- Implement schema drift detection on startup.

### Phase 2: Event-Driven Sync Integration (Forge)
- `db-ticket.sh create`: add sprint assignment prompt (C-01).
- `db-ticket.sh groom`: trigger `db-ticket.sh sync <ID> &` on success.
- `db-ticket.sh update`: trigger `db-ticket.sh sync <ID> &` on success.
- `db-sprint.sh commit`: trigger `db-ticket.sh sync <ID> &` on success.
- `db-sprint.sh defer`: trigger `db-ticket.sh sync <ID> &` on success.
- `db-sprint.sh complete`: trigger `pg-to-notion-sync.sh --sprint <name>` (sprint completion handling, C-02).
- `db-sprint.sh plan`: show unsprinted tickets section (C-01).

### Phase 3: Cron Jobs (Yoda)
- Register `pg-notion-sync-batch` (every 30 min).
- Register `pg-notion-integrity-audit` (daily 01:00 AEST).
- Verify lock file compatibility with cron execution.

### Phase 4: Backfill (Forge)
- **Script:** `scripts/pg-notion-backfill.sh`
- **Modes:**
  - `--dry-run`: Log what would happen without executing.
  - `--pilot 5`: Process first 5 tickets, pause for manual verification.
  - `--resume`: Resume from last successful ticket (tracked in state file).
  - No flag: Full backfill of all tickets.
- **Logic for each ticket:**
  1. Check if `notionpageid` exists → if yes, PATCH update all 15 properties.
  2. If no `notionpageid`, query Notion by title → if match, link `notionpageid` and update.
  3. If no match, create new Notion page with all 15 properties, write back `notionpageid`.
  4. On each write: update `metadata.notion_sync` to `{status: "synced", last_synced: now}`.
- **Rate Limiting:** 350ms sleep between API calls. 429 → exponential backoff.
- **Batching:** Process in groups of 50. Pause 5 seconds between groups.
- **Tracking:** Progress saved to `state/pg-notion-backfill-state.json` after each ticket (resumable).
- **Safety:** Before modifying a Notion page, save current property snapshot to `state/pg-notion-backfill-snapshots/` (named by `notionpageid`).
- **Estimated runtime:** ~4 minutes for full 331-ticket backfill.
- **Testing Flow:** 
  1. `--dry-run` → verify output
  2. `--pilot 5` → Ken verifies 5 tickets in Notion
  3. `--pilot 50` → spot-check
  4. Full run
  5. Run integrity audit to validate

### Phase 5: Testing & Validation (C-05)

**Test Cases:**

| # | Scenario | Test | Expected |
|:--|:---|:---|:---|
| 1 | Ticket create + groom | Create TKT-TEST-001, groom, check Notion | Page created with all 15 properties |
| 2 | Ticket create (no sprint) | Create without sprint assignment, check Notion | No Notion page created (deferred to groom) |
| 3 | Sprint commit | Commit ticket to sprint, check Notion | Sprint + Planned Date + Sprint Date set |
| 4 | Status change | Update status to in-progress, check Notion | Notion Status = "In Progress" |
| 5 | Ticket close | Close ticket, check Notion | Status = "Closed", Delivered Date set |
| 6 | Sprint completion | Complete sprint with 2 open tickets | Tickets carried over, Notes updated, Telegram alert |
| 7 | Dedup prevention | Sync same ticket twice | No duplicate Notion page |
| 8 | Orphan detection | Create Notion page manually, run audit | Orphan detected and moved to DB C |
| 9 | Batch reconciliation | Create ticket, kill event sync, run batch | Batch catches and syncs the ticket |
| 10 | Rate limiting | Run backfill, monitor API calls | No 429 errors, consistent 2.85 req/sec |
| 11 | Dry-run | Run backfill --dry-run | No Notion changes, accurate log of what would happen |
| 12 | Lock contention | Start two syncs simultaneously | Second exits immediately (flock -n) |

**Rollback Procedure:**
- Individual ticket: restore Notion page from `state/pg-notion-backfill-snapshots/` snapshot.
- Bulk rollback: not supported. Backfill is idempotent per-ticket. Fix the script and re-run.

### Phase 6: Sign-off
- Run integrity audit → must pass all 7 checks.
- Ken reviews Notion DB A for visual completeness.
- Atlas/Thrawn spot-check 20 random tickets.
- Yoda confirms cron health for 48 hours.

---

## SECTION 6: Governance

### Ownership

| Role | Agent | Responsibility |
|:---|:---|:---|
| **Process Owner** | Lando | Defines process, field mappings, business rules, sprint lifecycle |
| **Implementation** | Forge | Builds and maintains sync scripts, crons, backfill |
| **Oversight** | Yoda | Monitors sync health, alerts, integrity audit review |
| **Architecture Review** | Atlas + Thrawn | Design review and technical validation |
| **Approval** | Ken | Final sign-off on design and go-live |

### Component Registry (NEW — C-10)

**New scripts to register in Holocron:**
- `scripts/pg-to-notion-sync.sh` v2 (rewritten) — batch + audit + sprint sync
- `scripts/pg-notion-backfill.sh` — one-time backfill with dry-run + resumable batches

**New cron jobs to register:**
- `pg-notion-sync-batch` — 30-min batch reconciliation
- `pg-notion-integrity-audit` — daily 01:00 AEST integrity check

**New state files to register in Sources of Truth Register:**
- `state/pg-notion-sync-errors.json` — sync error log (migration path → PG T3 noted)
- `state/pg-notion-sync-dlq.json` — dead-letter queue
- `state/pg-notion-backfill-state.json` — backfill progress tracker
- `state/pg-notion-backfill-snapshots/` — pre-modification snapshots
- `state/pg-notion-last-sync.txt` — existing, already registered

### Monitoring

- **Integrity Reports:** Daily audit results → Telegram to Ken.
- **Real-time Alerts:** Sync failures (3 consecutive) → Telegram to Ken.
- **Unsprinted Tickets:** Flagged in daily audit if count > 10.
- **Health Summary:** Weekly sprint health posted to Notion via automated cron.
- **API Rate Limit Headroom:** Tracked in integrity audit (count 429 responses).

### Regular Audits

- **Daily:** Automated 7-check integrity audit (cron).
- **Weekly:** Manual spot-check of 10 random tickets by Yoda.
- **Sprint Boundary:** Full reconciliation before sprint review.
- **Monthly:** Lando reviews process effectiveness, proposes improvements.

### Ken's Review Cadence

- **Design (now):** Review and approve this v2.0 document.
- **Post-Phase 1:** Verify sync script works on 5 test tickets.
- **Post-Backfill:** Review Notion DB A for completeness.
- **Weekly:** 30-second glance at AKB Backlog — should match reality.
- **Sprint Review:** Review sprint health summary in Notion.

---

## CONSTRAINTS & NOTES

- **SSOT:** PostgreSQL is the ONLY source of truth. Notion is a read-only derived view. Writing from Notion to PG is STRICTLY FORBIDDEN.
- **Scale:** System must handle 331 tickets gracefully. 300 currently have no sprint — sprint triage addresses this.
- **Idempotency:** All sync operations safe to run multiple times. Query-before-create prevents duplicates.
- **Persistence:** All existing `notionpageid` links preserved.
- **Non-Blocking:** Sync failures never block PG ticket operations.
- **Rate Limiting:** 350ms sleep between API calls. Max 2.85 req/sec sustained.
- **Scripts:** All at `/Users/ainchorsangiefpl/.openclaw/workspace/scripts/`.
- **Sprint Column:** `sprint` column (first-class, TKT-0391) is authoritative for sync. `metadata.sprint_target` is maintained for backward compatibility but sync reads `sprint` column.

---

*Lando — BPM Specialist, AInchors Nexus Platform*
*Revised v2.0 incorporating Atlas (6 blocking) + Thrawn (5 conditions) + Yoda (7 gaps)*
*Ready for Atlas + Thrawn re-review*
