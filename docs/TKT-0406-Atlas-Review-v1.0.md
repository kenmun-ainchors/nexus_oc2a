# TKT-0406 Atlas Review — Agile Sprint Working Model Design v1.0

**Reviewer:** Atlas 🏛️ — Enterprise Architect
**Date:** 2026-06-11
**Document Reviewed:** `docs/TKT-0406-Agile-Sprint-Working-Model-Design-v1.0.md` by Lando
**Gap Report Considered:** `state/tkt-0406-verify-gaps.json` by Yoda (7 gaps, verdict: NOT_READY_FOR_REVIEW)
**Reference Architecture:** `docs/Nexus-System-Architecture-v1.0.md` (APPROVED, Ken Mun 2026-05-14)
**Context:** This is Ken's 5th or 6th attempt to fix the PG–Notion working model. The review must be definitive.

---

## 1. Architecture Assessment

### 1.1 Data Flow Soundness

Lando's data flow architecture has a solid conceptual skeleton:

- **Unidirectional sync (PG → Notion)** is architecturally correct and aligns with the SSOT principle.
- **Ticket lifecycle stages** (Create → Groom → Sprint Commit → Status Change → Close → Archive) cover the primary workflow correctly.
- **Sprint lifecycle** (Create → Plan → Commit → Active → Complete) is appropriately defined as a temporal container.
- **Event-driven + batch hybrid** is the right pattern — real-time for writes, batch for reconciliation.

However, the data flow has **structural holes** at two critical junctions:

1. **Create→Groom gap (GAP-04):** The design assumes a full sync on create, but current `db-ticket.sh create` writes with minimal metadata (`notionSynced: false`). A newly created sparse Notion page that later gets enriched creates an unnecessary churn pattern. Worse, it introduces a window where Notion shows incomplete data — undermining the "derived view" purpose.

2. **Sprint assignment flow (GAP-06):** This is the most significant architectural gap. The design covers syncing sprint data *after* assignment but is silent on how 300+ unsprinted tickets get assigned. The entire premise of a "sprint working model" requires sprints to actually have tickets. Without a sprint triage process, we're building a pipeline to nowhere.

### 1.2 Lifecycle State Handling

| State | Covered? | Issue |
|-------|----------|-------|
| Ticket Creation | ✅ | But sparse sync concern |
| Grooming | ✅ | Field completeness addressed |
| Sprint Commit | ✅ | Via `db-sprint.sh commit` |
| Status Transitions | ⚠️ | "In Sprint" derivation has edge case gaps (GAP-03) |
| Ticket Close | ✅ | Delivered Date mapping |
| Archive | ✅ | Move to DB C |
| Sprint Completion with Open Tickets | ❌ | **MISSING** — What happens to tickets in a completed sprint? |
| Orphan Recovery | ✅ | Query-before-create + link recovery |
| Duplicate Prevention | ✅ | Good dedup strategy |
| Concurrent Writes | ⚠️ | Lock file mentioned but untested at scale |

**Critical missing state:** Sprint completion with open/unfinished tickets. Reality: sprints end with unfinished work. What happens to the 2 tickets not done in Sprint 7? Are they auto-moved to Sprint 8? Flagged in Notion? The design treats sprints as clean containers but the real world is messy.

### 1.3 Edge Cases Identified (not in Lando's design)

1. **Ticket re-assigned to different sprint mid-flight:** `sprint_target` changes → old sprint still shows it? Notion sprint property is a single-select — update is trivial but the design should explicitly state it.
2. **Ticket deleted from PG (not archived):** If a ticket is purged from `state_tickets`, the orphan detection picks it up. But what about the reverse — ticket archived in Notion that should NOT be recreated? The orphan detector could recreate deleted-by-design tickets.
3. **Notion API transient failures during event-driven sync:** Event hooks fire at ticket create/update. If Notion API is down, the ticket is created in PG but never synced. The 30-min batch sync catches this, but there's a 0–30 minute staleness window. Acceptable given non-blocking design, but should be documented.
4. **`notionpageid` collision across environments:** If the same TKT-ID exists in both sandbox and production PG (possible during testing), which Notion page wins? PG is SSOT, so production PG wins — but the design should state this explicitly.
5. **Bulk sprint commit of 50+ tickets:** `db-sprint.sh commit` triggers per-ticket sync. 50 tickets × 2 API calls (query-before-create + update) = 100 Notion API calls at 3/sec = ~33 seconds minimum. Should be batched with rate limiting.

### 1.4 Verdict on Architecture

**Conceptually sound, structurally incomplete.** The event-driven + batch hybrid is correct. The deduplication strategy is well-designed. But the design is an *integration spec*, not a *working model* — it describes how bits move between systems but doesn't address the operational reality of how work actually flows through the system. The missing sprint triage flow is a functional blocker.

---

## 2. Platform Alignment

### 2.1 PG SSOT Compliance

| Principle | Compliant? | Assessment |
|-----------|------------|------------|
| PG is SSOT | ✅ | Design explicitly declares PG → Notion as unidirectional |
| Notion is read-only derived view | ✅ | "Writing from Notion to PG is strictly forbidden" |
| Idempotency | ⚠️ | Query-before-create is idempotent for creation; but `pg-to-notion-sync.sh` currently only synced 4 properties — full-write policy (14 props) is a significant expansion that must be tested for idempotency on repeated runs |
| Non-blocking sync | ✅ | "Best-effort side effect. Ticket creation/updates in PG must succeed regardless of sync outcome" — architecturally correct |

**PG SSOT gap:** The design references `metadata.sprint_target` and `metadata.sprint` but the PG schema for these fields was only recently deployed (TKT-0391, 2026-06-10). The design must explicitly reference the current schema state. The `sprint` column in `state_tickets` is now a first-class column (not just in metadata JSONB) — this matters for query patterns.

### 2.2 Three Work Types Rule (TKT-0165) Alignment

The sync operations fall into Work Type routing:

| Operation | Work Type | Current Routing | Correct? |
|-----------|-----------|-----------------|----------|
| PG ticket CRUD | T0 (shell script) | `db-ticket.sh` | ✅ |
| Notion API calls | T0 (curl/http) | `pg-to-notion-sync.sh` | ✅ |
| Status derivation logic | T0/1 (light logic in shell) | In script | ✅ |
| Orphan analysis/reporting | Could be T2 | Not specified | ⚠️ |
| Integrity audit reporting | Could be T2 | Not specified | ⚠️ |

**Issue:** The design is silent on work currency routing. The integrity audit's "alert if mismatch > 5" and Telegram reporting are shell-scriptable (T0), but the weekly health summary "generated in Notion" (Section 6) implies LLM involvement for narrative generation — this should be classified and routed correctly.

### 2.3 Data Architecture Tiers (5-Tier Model)

| Tier | Relevant to Design? | Addressed? |
|------|---------------------|------------|
| T2 (Session Memory) | Not directly | N/A |
| T3 (Episodic/Audit Log) | Sync errors, integrity results | ⚠️ Error log is JSON file (`state/pg-notion-sync-errors.json`), not T3's `agent_events` table. Architecture says T3 must be Postgres. |
| T4 (Semantic Memory) | Not directly | N/A |
| T5 (Shared Multi-Agent State) | `notion_sync` metadata in tickets | ✅ Stored in PG ticket metadata |

**Gap:** The error/audit logs (Section 3, 4) use flat JSON files (`state/pg-notion-sync-errors.json`, `state/pg-notion-backfill-state.json`). Per the approved System Architecture (Section 5.2), structured event data must eventually land in Postgres T3 tables. Flat files are acceptable as P1 interim, but the design should acknowledge the migration path and register these files in the Sources of Truth Register.

### 2.4 Integration Architecture Alignment

The design uses:
- **Event-driven sync** (hooks in db-ticket.sh / db-sprint.sh) — aligns with Coordination Work pattern
- **Cron-based batch reconciliation** — aligns with scheduled T0 work
- **No Postgres LISTEN/NOTIFY** — acceptable for P1; this is a shell-script integration, not an async agent handoff

**Missing:** The design doesn't register these new cron jobs or scripts in the Component Map (Architecture Section 7) or Holocron. Per DoD, new platform components require registration.

### 2.5 Existing Script Architecture Alignment

The current `db-ticket.sh` already has a `sync` subcommand (line 882+) that calls `pg-to-notion-sync.sh`. This confirms Yoda's GAP-02 concern — the design was ambiguous about whether to call the batch script or a single-ticket path. The existing implementation already does single-ticket sync via the `sync` subcommand. The design should reflect reality.

---

## 3. Missing Elements

### 3.1 Sprint Triage Process (BLOCKING)

The single largest omission. The design describes how to sync sprint assignments *after* they exist but provides no mechanism for creating those assignments. The original problem: 300/331 tickets have no sprint. A "sprint working model" that doesn't address sprint assignment is building the plumbing without connecting the water source.

**Required:** A sprint triage step in the ticket lifecycle, between Create and Groom, with:
- Default sprint assignment on creation (optional, with `--sprint` flag)
- Batch triage during sprint planning (`db-sprint.sh plan` already has commit functionality — extend)
- PG query to identify unsprinted tickets: `SELECT id FROM state_tickets WHERE sprint IS NULL AND status = 'open'`

### 3.2 Sprint Completion Handling (BLOCKING)

What happens when a sprint completes but has open tickets?
- Auto-migrate to next sprint?
- Mark as "Carried Over" in Notion?
- Downgrade priority?
- Flag for Ken review?

Without this, every sprint boundary requires manual cleanup. This is the operational reality that caused the current mess.

### 3.3 Testing Strategy (GAP-07 confirms)

No dry-run mode, no staging validation, no test cases. For a system handling 331 tickets across 2 platforms, this is unacceptable.

**Required:**
- `--dry-run` flag on `pg-to-notion-sync.sh` (log what would happen, don't execute)
- `--dry-run` flag on backfill script
- Test plan: 5-ticket pilot → 50-ticket batch → full backfill
- Rollback procedure: how to undo a bad sync

### 3.4 Monitoring & Observability (PARTIAL)

The design mentions:
- Error logging to JSON file ✅
- Telegram alerts on failure ✅
- Daily integrity audit ✅

**Missing:**
- **Sync latency monitoring:** How long does a single-ticket sync take? Is it degrading?
- **Notion API rate limit headroom:** Current usage vs. Notion's 3 req/sec limit. Backfill will consume significant budget.
- **Success metrics:** What does "healthy" look like? % of tickets synced within X seconds? % of audits passing?
- **Notion API quota tracking:** Notion has undocumented rate limits beyond 3 req/sec. Need tracking of 429 responses.

### 3.5 Schema Versioning

The Notion DB A properties may change over time (add/remove fields). How does the sync script detect schema drift? If Ken adds a "Points" property to DB A, does the sync fail silently (extra property ignored) or break (missing field in update)?

**Required:** Schema validation on startup — compare expected Notion DB A properties against actual, alert on mismatch.

### 3.6 Idempotency Key Strategy

The design says "idempotency" but doesn't specify the idempotency key mechanism. Notion API doesn't support idempotency keys natively — the query-before-create pattern is the idempotency mechanism. But on updates, repeated calls to the same Notion page ID with the same data are naturally idempotent. This should be stated explicitly.

### 3.7 Backfill Rollback

Phase 4 backfill modifies 331 Notion pages. If something goes wrong halfway through (e.g., wrong status mapping discovered at ticket #150), how do we rollback? The design has no undo mechanism.

**Required:** Backfill should snapshot Notion page state before modification, or at minimum, process in a way that allows resumption from last successful ticket.

### 3.8 Field Mapping Completeness

Lando claims "14 properties" but lists 13 PG→Notion mappings. Yoda's GAP-01 identifies Impact and Category as missing. Additionally:

- The "Full Write Policy" says "14 properties" but the mapping table only enumerates 12 (counting each row once). The actual Notion DB A property count needs to be verified against the live database.
- "Delivered Date" is conditionally synced (only on close) — this means it's NULL/empty for open tickets. The full-write policy should explicitly handle conditional properties.

### 3.9 `metadata.sprint_target` vs. `sprint` Column

TKT-0391 (2026-06-10) added a first-class `sprint` column to `state_tickets`. Lando's design references `metadata.sprint_target` and `metadata.sprint`. The design must clarify which PG source is authoritative for sprint data — the first-class column or the JSONB metadata field. They SHOULD be synchronized (TKT-0391 backfill did this), but the sync script must be unambiguous about which it reads.

---

## 4. Design Issues

### 4.1 Event Hook Architecture (ISSUE — GAP-02 related)

The design says event hooks call `pg-to-notion-sync.sh`. Reality: `db-ticket.sh` already has a `sync` subcommand that calls `pg-to-notion-sync.sh`. The design should distinguish between:

- **Single-ticket path:** `db-ticket.sh sync <TKT-ID>` (fast, targeted, already exists)
- **Batch path:** `pg-to-notion-sync.sh --batch` (processes all tickets with `notion_sync.status != 'synced'`, runs every 30 min)
- **Trigger hook:** `db-ticket.sh create` → on success → `db-ticket.sh sync <TKT-ID> &` (backgrounded)

The design conflates these, which creates implementation ambiguity.

### 4.2 Status Mapping Complexity (ISSUE)

The "In Sprint" derived status is clever but fragile:

```
If status=open AND sprint_target IS NOT NULL AND sprint is active → "In Sprint"
If status=open AND no sprint → "Backlog"
If status=open BUT sprint is completed → ?
```

This is 3-condition logic in a shell script with no test harness. A simpler approach: "In Sprint" is a separate Notion formula or rollup property derived from Sprint field — Notion computes it, not the sync script. Alternatively, make "In Sprint" a dedicated status in PG and sync it directly. Computed statuses in shell scripts are bug-prone.

**Recommendation:** Either eliminate "In Sprint" as a derived status (map directly from PG status), or if "In Sprint" is valuable, make it a first-class PG status value to keep the mapping a simple 1:1 lookup.

### 4.3 Batch Reconciliation Window (ISSUE)

"Every 30 minutes — Full sync of all tickets where `updated_at` > last run."

Problem: `updated_at` in PG is updated on ANY ticket change. But `notion_sync.status` already tracks whether a ticket is synced. Using `updated_at > last_run` as the batch filter is fragile — if a ticket was updated 31 minutes ago and the event-driven sync failed, the batch reconciliation might miss it unless there's overlap. 

**Recommendation:** Batch reconciliation should query `WHERE notion_sync.status != 'synced'` (or `WHERE notion_sync.last_synced IS NULL OR notion_sync.status = 'failed'`) — this is the true backlog of unsynced work, not a time window.

### 4.4 Lock File Location (ISSUE)

Lock file at `/tmp/pg-notion-sync.lock`. On macOS, `/tmp` is cleaned on reboot. This is fine for a runtime lock but if the process crashes, stale lock handling matters. The design uses `flock -n` (non-blocking, exit if locked), which is correct. But add a lock staleness check: if lock file is > 1 hour old, force-acquire.

### 4.5 DLQ Thresholds (ISSUE)

"Tickets failing 5+ times are flagged for manual review."

Why 5? Why not 3? The escalation threshold (3 failures → Telegram alert) and DLQ threshold (5 failures → manual review) feel arbitrary. Given the non-blocking design, a ticket that fails sync 3 times likely has a structural issue (bad `notionpageid`, deleted Notion page, API key issue), not a transient one. 

**Recommendation:** 3 failures → DLQ + Telegram alert. Don't wait for 5.

### 4.6 "Full Write Policy" — 14 Properties (ISSUE)

"Every sync operation must attempt to write all 14 properties."

The current `pg-to-notion-sync.sh` creates pages with only 4 properties (US Title, Status, Type, Priority). Updating to 14 properties for every operation is a major expansion. Notion API `PATCH /pages/{id}` only updates properties you include — writing all 14 is safe but expensive (larger payloads). More critically: Notion properties that are formula/rollup types CANNOT be written via API. If any of the 14 properties are computed (Notion-side), the sync will fail.

**Recommendation:** Verify which DB A properties are writable vs. computed BEFORE implementing full-write policy. Exclude formula/rollup/created_time properties from writes.

### 4.7 Orphan Move Strategy (ISSUE)

"Move to DB C (Archive)." DB C has a different schema than DB A. The current `pg-to-notion-sync.sh` creates archive pages with 4 properties. Moving a fully-populated page (14 properties) to DB C will lose data unless DB C has matching schema. 

**Recommendation:** Verify DB C schema compatibility before orphan moves. If DB C has a subset of properties, log what's being lost.

---

## 5. Yoda Gap Report Assessment

### GAP-01: Field Mapping — Missing Impact and Category

| Attribute | Assessment |
|-----------|------------|
| **Yoda Severity:** | MEDIUM |
| **Atlas Assessment:** | **AGREE** |
| **Atlas Severity:** | **MEDIUM** |
| **Notes:** | Verified against existing script — only 4 properties currently synced. Lando claims 14 but lists 12–13 mappings. Impact and Category are separate Notion properties. The design says "metadata.agent → Stream/Category" which conflates two distinct fields. Stream should map to agent/team, Category should map to ticket type or work stream. Need explicit mapping for every DB A property, including those marked "not applicable" (formula/rollup fields). |

### GAP-02: Single-Ticket vs. Batch Sync Ambiguity

| Attribute | Assessment |
|-----------|------------|
| **Yoda Severity:** | HIGH |
| **Atlas Assessment:** | **AGREE** |
| **Atlas Severity:** | **HIGH** |
| **Notes:** | Confirmed by examining `db-ticket.sh` — the `sync` subcommand already exists and calls `pg-to-notion-sync.sh` for a single ticket. The design's event hooks section is ambiguous about calling the batch script vs. single-ticket sync. This MUST be clarified before Phase 2 implementation, otherwise we'll either (a) trigger full batch sync on every ticket create (wasteful, 600+ API calls/hr at worst) or (b) miss the single-ticket path entirely. |

### GAP-03: "In Sprint" Status Edge Cases

| Attribute | Assessment |
|-----------|------------|
| **Yoda Severity:** | MEDIUM |
| **Atlas Assessment:** | **AGREE** |
| **Atlas Severity:** | **MEDIUM → HIGH** (conditional) |
| **Notes:** | Yoda correctly identifies three edge cases. I'm elevating to HIGH because this is status derivation logic in a shell script with no test harness. If the sprint completion edge case (open ticket in completed sprint → "Backlog") is mishandled, Notion will show misleading statuses on sprint review day. I recommend eliminating derived statuses entirely and using a 1:1 PG→Notion status mapping. The "In Sprint" display can be a Notion-native formula based on Sprint field population, NOT computed by the sync script. |

### GAP-04: Sparse Create Sync

| Attribute | Assessment |
|-----------|------------|
| **Yoda Severity:** | HIGH |
| **Atlas Assessment:** | **AGREE** |
| **Atlas Severity:** | **HIGH** |
| **Notes:** | This is architecturally important. Yoda's recommendation (A — create only to PG, sync deferred to first groom) is the correct choice. Creating a sparse Notion page on ticket create and then immediately updating it on groom creates two API calls per ticket. Deferring to first groom means the Notion page is created once with complete metadata. Less churn, more efficient, better data quality. The ticket lifecycle should be: Create (PG only) → Groom (PG metadata + Notion sync) → Sprint Commit (Notion sprint fields) → ... |

### GAP-05: Backfill Rate Limiting

| Attribute | Assessment |
|-----------|------------|
| **Yoda Severity:** | MEDIUM |
| **Atlas Assessment:** | **AGREE** |
| **Atlas Severity:** | **MEDIUM** |
| **Notes:** | Yoda's math is directionally correct but slightly conservative. Notion's rate limit is 3 req/sec averaged, but they allow short bursts. 350ms sleep between calls provides ~2.85 req/sec — safe. For 331 tickets × 2 calls (query + write or update) = 662 calls: at 350ms sleep = ~232 seconds (~4 minutes). In practice, existing tickets with `notionpageid` skip the query step, reducing calls. Add: track 429 responses and implement exponential backoff (not just fixed sleep). |

### GAP-06: No Sprint Assignment Mechanism

| Attribute | Assessment |
|-----------|------------|
| **Yoda Severity:** | HIGH |
| **Atlas Assessment:** | **STRONG AGREE** |
| **Atlas Severity:** | **CRITICAL** |
| **Notes:** | This is the **root cause** of the problem Ken has tried to fix 5+ times. 300 unsprinted tickets exist because there was never a sprint assignment workflow. The design builds a beautiful sync pipeline that faithfully reproduces the problem. Without a sprint triage process: (1) all tickets will remain unsprinted forever, (2) the "In Sprint" status is useless, (3) sprint health metrics are meaningless. The sprint triage must be Part 1 of the solution — assign tickets to sprints first, THEN sync the assignments. |

### GAP-07: No Testing Strategy

| Attribute | Assessment |
|-----------|------------|
| **Yoda Severity:** | LOW |
| **Atlas Assessment:** | **AGREE** |
| **Atlas Severity:** | **MEDIUM** |
| **Notes:** | I'm elevating from LOW to MEDIUM because this is Ken's 5th+ attempt. Previous failures were likely caused by untested edge cases. For a permanent fix, the testing strategy is non-negotiable. Dry-run mode is essential. Pilot batch of 5 tickets before full backfill is essential. Without these, we risk repeating the cycle. |

### Gap Severity Summary (Atlas-adjusted)

| Gap | Yoda Sev | Atlas Sev | Delta |
|-----|----------|-----------|-------|
| GAP-01 (Fields) | MEDIUM | MEDIUM | — |
| GAP-02 (Sync Ambiguity) | HIGH | HIGH | — |
| GAP-03 (Status Edge Cases) | MEDIUM | MEDIUM→HIGH | ↑ (no test harness concern) |
| GAP-04 (Sparse Create) | HIGH | HIGH | — |
| GAP-05 (Rate Limiting) | MEDIUM | MEDIUM | — |
| GAP-06 (Sprint Triage) | HIGH | **CRITICAL** | ↑ (root cause) |
| GAP-07 (Testing) | LOW | MEDIUM | ↑ (repeat-failure risk) |

---

## 6. Verdict

### **VERDICT: REJECT (revise and resubmit)**

Lando's design is a competent integration spec but is not a complete working model. The architecture is sound in concept — unidirectional PG→Notion sync, event-driven + batch hybrid, deduplication strategy — but **structurally incomplete** at the operational level. A document that defines how data flows but not how the system operates is a technical spec, not a working model.

### Conditions for Approval

**BLOCKING (must address before re-review):**

1. **Add Sprint Triage Process (C-01):** Define how tickets get assigned to sprints. Minimum: `db-ticket.sh create --sprint <name>` flag, batch triage via `db-sprint.sh plan`, PG query for unsprinted tickets. Without this, the "sprint working model" has no sprints.

2. **Add Sprint Completion Handling (C-02):** Define behavior when a sprint completes with open tickets. Auto-migration strategy or explicit carry-over flagging in Notion.

3. **Resolve Single-Ticket vs. Batch Sync (C-03):** Clarify event hooks call `db-ticket.sh sync <ID>` (existing), not the batch script. Add explicit distinction between sync paths.

4. **Resolve Field Mapping Completeness (C-04):** Audit live Notion DB A properties. Map every property to a PG source or mark as "not applicable" (formula/rollup/computed). Separate Stream and Category mappings.

5. **Add Testing Strategy (C-05):** `--dry-run` flag on sync and backfill scripts. 5-ticket pilot before full backfill. Rollback procedure.

6. **Clarify Sprint Data Source (C-06):** Specify whether `sprint` column (first-class, TKT-0391) or `metadata.sprint_target` (JSONB) is authoritative for sync. They should agree, but the sync script needs an unambiguous source.

**STRONGLY RECOMMENDED (approval likely with these):**

7. **Simplify Status Mapping (C-07):** Eliminate derived "In Sprint" status from shell script. Use either a dedicated PG status or a Notion-native formula. Reduces bug surface area significantly.

8. **Fix Batch Reconciliation Filter (C-08):** Query `notion_sync.status != 'synced'` instead of `updated_at > last_run`. More robust, self-healing.

9. **Register New Components (C-09):** Register cron jobs, new scripts, and state files in Holocron and the Sources of Truth Register per DoD.

10. **Add Observability (C-10):** Sync latency metric, Notion API rate limit headroom monitoring, success rate dashboard.

**NICE TO HAVE:**

11. Schema version detection for Notion DB A property drift.
12. Backfill rollback/snapshot mechanism.
13. Lock file staleness detection (>1 hour → force acquire).

### Summary for Ken

Ken, Lando's design gets the data plumbing right but misses the operational reality. The sync mechanism is well-designed — event-driven for write-time consistency, batch for reconciliation, query-before-create for dedup. I trust the pipes.

What's missing is what makes this a **working model**: how tickets get into sprints, what happens when sprints end, and how we know the system is healthy.

The 6 blocking conditions above are the minimum viable bar. Address those and this becomes APPROVE WITH CHANGES. Skip them and we'll be doing a 7th attempt in a few weeks.

The sprint triage gap (C-01) is the single most important fix. Everything else flows from tickets having sprint assignments. Build the triage first, then sync the results. Not the other way around.

---

**Recommendation to Yoda:** Return to Lando with this review. Require revision addressing all 6 blocking conditions before Atlas re-review. The re-review should be faster — the conceptual architecture is sound and the changes are additive, not structural.

---

*Atlas 🏛️ — Enterprise Architect, AInchors Nexus Platform*
*Review conducted against System Architecture v1.0 (APPROVED, 2026-05-14)*
