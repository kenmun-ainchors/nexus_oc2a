# TKT-0720 A1 — Architecture Review: `entity_links` Edge Table

**Reviewer:** Atlas (architect)  
**Date:** 2026-06-22 19:55 AEST  
**Documents reviewed:**
- `.openclaw/tmp/TKT-0720-CREST-plan.md`
- `.openclaw/tmp/TKT-0720-groomed-brief.md`
- `docs/CRESTv2-P1-DM-StructuredFoundation-v1.0.md` §1.3
- `scripts/db-ticket.sh` (live-write hook points)
- `scripts/changelog-append.sh` (live-write hook points)
- `scripts/db-sprint.sh` (live-write hook points)
- `scripts/pg-write-event.sh` (event emission pattern)

---

## 1. Schema Review

### 1.1 Proposed Columns (from CREST plan §1.3 + A2 contract)

| Column | Type | Purpose | Verdict |
|---|---|---|---|
| `id` | `uuid PK` | Surrogate PK | ✅ Standard |
| `link_id` | `text UNIQUE` | Human-readable `LNK-NNNN` | ✅ Good for debugging |
| `from_type` | `text` | Entity type of source | ✅ |
| `from_id` | `text` | Canonical ID of source | ✅ |
| `to_type` | `text` | Entity type of target | ✅ |
| `to_id` | `text` | Canonical ID of target | ✅ |
| `link_type` | `text` | Edge semantics (`relates-to`, etc.) | ✅ |
| `ts` | `timestamptz` | When link was established | ✅ |
| `source` | `text` | How link was created (`migrated-from-md`, `live-write:*`) | ✅ |
| `tenant_id` | `text` | Multi-tenant partition | ✅ |
| `payload` | `jsonb` | Optional extra metadata | ✅ |
| `hash` / `prev_hash` | `text` | Tamper-evident chain | ⚠️ See §4 |

### 1.2 Indexes

| Index | Columns | Purpose | Verdict |
|---|---|---|---|
| `entity_links_pkey` | `id` | PK | ✅ |
| `entity_links_link_id_key` | `link_id` | Unique constraint | ✅ |
| `idx_entity_links_from` | `from_type, from_id` | "What does X link to?" | ✅ |
| `idx_entity_links_to` | `to_type, to_id` | "What links to X?" | ✅ |
| `idx_entity_links_pair` | `from_type, from_id, to_type, to_id` | Pair lookup for upsert | ✅ |

**Recommendation:** Add `idx_entity_links_link_type` on `link_type` alone for filtering by semantic type (e.g. "all `resolves` edges"). Low cost, high query value.

### 1.3 `link_id` Format

`LNK-NNNN` via sequence `entity_links_link_id_seq`. This is consistent with the `TKT-NNNN` / `CHG-NNNN` / `L-NNN` pattern. ✅

**Non-blocking recommendation:** Consider prefixing with the entity type of the `from` side for readability (e.g. `TKT-0546-LNK-0001`), but this adds complexity to the sequence. Keep `LNK-NNNN` for v1.

---

## 2. Verdict: **SIGN-OFF** with non-blocking recommendations

The proposed schema is sound for v1. No blocking concerns. Proceed to A2 (DDL).

---

## 3. Evaluation of Key Design Decisions

### 3.1 String Canonical IDs vs UUID FKs (Assumption A1)

**Decision: SIGN-OFF.** Storing string canonical IDs (`TKT-NNNN`, `CHG-NNNN`, `L-NNN`, sprint number text) is the **correct v1 design** for these reasons:

1. **Entity-type agnosticism:** The edge table spans 5+ entity types (ticket, chg, lesson, sprint, wo) that have different PK schemes. A single `from_type`+`from_id` text pair handles all of them without polymorphic FKs or separate join tables per type.

2. **Referential integrity is deferred anyway:** `state_lessons` and WO tables don't exist yet. UUID FKs would require nullable FKs or conditional constraints — more complexity for no gain.

3. **Human readability:** `TKT-0546` is immediately meaningful in query results, logs, and debugging. UUIDs are opaque.

4. **Phase 2 read-interface compatibility:** The design module §1.6 specifies that Phase 2 reads `entity_links` for traversal. String IDs are the natural key that Phase 2 will use to identify entities.

5. **Migration path to FKs:** If referential integrity is needed later, a `CHECK` constraint or trigger can validate that `from_id` exists in the appropriate `state_*` table. This is additive, not breaking.

**Future improvement (v2):** Add a materialized view or trigger-based validation that cross-references `from_id`/`to_id` against the appropriate `state_*` tables, once all target tables exist.

### 3.2 From-Entity Resolution (Assumption A3)

**Decision: SIGN-OFF** with clarification.

The rule — "nearest preceding heading containing a canonical ID" — is correct for the primary use case (CHANGELOG.md where each entry is `## ... [CHG-NNNN]`). However, the groomed brief's A3 text says:

> For other docs, the containing entity is derived from the nearest preceding heading that contains a `TKT-NNNN` or `CHG-NNNN` or `L-NNN`.

**Clarification needed (non-blocking, document in backfill script):**
- What if a heading contains multiple canonical IDs? E.g. `## TKT-0546 / CHG-0719 — entity_links work`. Which is the "from" entity?
  - **Recommendation:** Use the **first** canonical ID found in the heading. Log the others as potential secondary edges.
- What if no heading contains a canonical ID? The brief says "skip and log" — ✅ correct.
- What about `agents/**/*.md` files? These may have `Linked:` lines without clear entity headings. The backfill should handle gracefully (skip + log).

**Edge case:** A `Linked:` line that appears in a preamble section (before any heading). This should be skipped and logged — the "from" entity is ambiguous.

### 3.3 Range Expansion (Assumption A4)

**Decision: SIGN-OFF.** Expanding `CHG-0604–CHG-0608` to individual edges is correct. The regex should handle:
- En-dash (`–`), em-dash (`—`), and hyphen-minus (`-`) as range separators
- Both `CHG-0604–CHG-0608` and `CHG-0604 - CHG-0608` (with spaces)
- Only expand when both endpoints are the same entity type and the numeric range is valid (start ≤ end)

**Non-blocking recommendation:** Cap range expansion at 20 items to prevent accidental expansion of prose like "TKT-0001–TKT-9999". Log a warning if a range exceeds the cap.

### 3.4 Prose/Parentheses Handling

**Decision: SIGN-OFF** with implementation guidance.

The backfill parser should:
1. Extract only lines starting with `**Linked:**` (or `Linked:` at the start of a line).
2. Strip markdown formatting (bold `**`, links `[text](url)`, backticks).
3. Match canonical ID patterns: `TKT-\d{4,}`, `CHG-\d{4,}`, `L-\d{2,}`, `WO-\w{3}-\d{2,}`, `Sprint \d+`.
4. Ignore IDs inside parentheses that are clearly prose context (e.g. "see TKT-0546 for details" — but this is in the `Linked:` line, so it's intentional).
5. **Do not** attempt to parse inline prose links outside `Linked:` lines (out of scope per groomed brief).

**Edge case:** `Linked:` lines that contain file paths like `state/crestv2-p1-tracker.json`. The groomed brief says to store as `file` type but exclude from the 90% completeness target. ✅

**Edge case:** Non-canonical mentions like `US##` (user story format). The groomed brief lists these as found in the corpus. **Recommendation:** Skip non-canonical forms for v1. Log them in the ambiguous/skipped report for potential v2 normalization.

### 3.5 Idempotency (Assumption A5)

**Decision: SIGN-OFF.** Upsert key `(from_type, from_id, to_type, to_id, link_type, source)` is correct. The `source` field distinguishes `migrated-from-md` from `live-write:*` entries, preventing duplicates when backfill is re-run after live writes have occurred.

**Non-blocking recommendation:** Add a `UNIQUE` constraint on `(from_type, from_id, to_type, to_id, link_type, source)` to enforce idempotency at the database level, not just in the script. This prevents race conditions.

### 3.6 Default Link Type (Assumption A2)

**Decision: SIGN-OFF.** All parsed `Linked:` entries default to `relates-to`. Semantic inference is deferred. This is the correct v1 scope boundary.

**Future improvement (v2):** When semantic inference is added, the `link_type` column is ready. The backfill can be re-run with a smarter parser to upgrade `relates-to` to more specific types.

---

## 4. Hash Chain Evaluation

**Decision: OPTIONAL — do NOT include `hash`/`prev_hash` in v1 `entity_links`.**

Rationale:
1. **Tamper-evidence for edges is lower priority** than for events. `agent_events` is the immutable history spine (§1.1). Edges are derived data that can be reconstructed from markdown.
2. **The backfill is idempotent** — re-running produces the same edges. Tamper-evidence adds complexity (hash computation, chain management) for minimal security benefit.
3. **If tamper-evidence is needed later**, it can be added as a migration (add columns, backfill hashes). The `agent_events` hash chain pattern is well-understood and can be replicated.
4. **The CREST plan says "chain optional but recommended for parity with agent_events"** — I recommend against it for v1. The parity argument is weak because edges are derived, not primary records.

**Non-blocking recommendation:** Document in the DDL comments that `hash`/`prev_hash` columns are reserved for v2 if tamper-evidence is needed.

---

## 5. Live-Write Hook Points

### 5.1 `scripts/db-ticket.sh`

**Hook points identified:**

| Subcommand | Hook location | What to insert |
|---|---|---|
| `create` (interactive) | After PG write + event emission (~line 540) | Parse `Linked:` in description if present; emit edges |
| `create-from-json` | After PG write + event emission (~line 720) | Parse `Linked:` in `metadata.links` array or `description`; emit edges |
| `update` | After PG write + event emission (~line 780, ~line 830) | Parse updated `Linked:` or `links` metadata; diff old vs new; emit edges |
| `groom` | After metadata update + event emission (~line 900+) | Parse `Linked:` in grooming decisions if present |

**Recommendation:** Add a shared helper function `insert_entity_links()` that:
- Accepts `from_type`, `from_id`, a list of `(to_type, to_id)` pairs, `link_type`, and `source`
- Inserts edges via a single SQL batch (not one-by-one)
- Emits a single `agent_events` row per batch with `event_type: "linked"`
- Is best-effort (like `emit_event`) — never blocks the primary mutation

**Hook pattern (consistent with existing `emit_event`):**
```bash
insert_entity_links() {
  local from_type="$1" from_id="$2" link_type="$3" source="$4"
  shift 4
  # Remaining args are "to_type:to_id" pairs
  # Build batch INSERT ... ON CONFLICT DO NOTHING
  # Emit agent_events row
}
```

### 5.2 `scripts/changelog-append.sh`

**Hook point identified:**

| Location | What to insert |
|---|---|
| After PG insert into `state_changes` + event emission (~line 175) | Parse `--linked` flag value; emit edges from the new CHG to each linked entity |

**Current behavior:** The `--linked` flag is stored in `metadata.linked` as a raw string. The hook should:
1. Parse the `--linked` value for canonical IDs (same regex as backfill)
2. Insert edges with `from_type="chg"`, `from_id=$CHG_ID`, `link_type="relates-to"`, `source="live-write:changelog-append"`
3. Emit `agent_events` row

**Edge case:** The `--linked` value may contain prose like "TKT-0546, TKT-0720 (entity_links work)". The parser should extract only canonical IDs.

### 5.3 `scripts/db-sprint.sh`

**Hook point identified:**

| Subcommand | Hook location | What to insert |
|---|---|---|
| `commit` | After PG write + event emission (~line 330) | Emit edge from sprint to committed ticket |

**Current behavior:** The `commit` subcommand already emits an `agent_events` row with `event_type: "committed"`. The hook should additionally:
1. Insert an edge: `from_type="sprint"`, `from_id=$sprint_num`, `to_type="ticket"`, `to_id=$tkt_id`, `link_type="relates-to"`, `source="live-write:sprint-commit"`
2. Emit a second `agent_events` row with `event_type: "linked"` (or extend the existing event)

**Non-blocking recommendation:** Consider whether the sprint→ticket edge should be `link_type="sprint-committed"` instead of `relates-to`, to distinguish sprint assignments from general cross-references. This is a v1 scope question — if semantic inference is deferred, `relates-to` is fine.

### 5.4 Future: `lesson-append.sh` / `db-lesson.sh`

Noted as a future hook point. The pattern is the same: after lesson creation, parse `Linked:` and insert edges. The `entity_links` table is ready for this.

---

## 6. Open Questions Requiring Ken/Yoda Decision

### Q1: File-path links — store or skip? (Groomed brief Q1)

**My recommendation:** Store as `file` type but exclude from 90% completeness target. This gives us the data for future use (e.g., "what documents reference this CHG?") without blocking the v1 metric.

**Decision needed:** Confirm this approach.

### Q2: Sprint link normalization — text or UUID? (Groomed brief Q2)

**My recommendation:** Text sprint number (e.g., `"9"`). This is human-readable and matches the existing `state_sprints.sprint_number` column. A view can join on `sprint_number` if needed.

**Decision needed:** Confirm text sprint number.

### Q3: `state_changes` migration scope (Groomed brief Q3)

**My recommendation:** Keep TKT-0720 edges-only. The 1,144 markdown CHG migration is TKT-0342. TKT-0720 should not expand scope.

**Decision needed:** Confirm no CHG migration in this ticket.

### Q4: Live-write hook granularity (Groomed brief Q4)

**My recommendation:** Parse both:
- A `links` array in ticket metadata (explicit structured links)
- Any `Linked:` line in the ticket description (free-form)

This covers both structured and unstructured input paths.

**Decision needed:** Confirm dual parsing approach.

### Q5: Link directionality (Groomed brief Q5)

**My recommendation:** Directed edges with `from` → `to`. For `relates-to`, the direction is arbitrary but consistent. The `idx_entity_links_to` index enables reverse traversal. Symmetric insertion (always inserting both directions) is unnecessary for v1 and doubles storage.

**Decision needed:** Confirm directed edges, no symmetric pairs.

### Q6: Hash chain in `entity_links`?

**My recommendation:** Skip for v1. See §4 above.

**Decision needed:** Confirm no hash chain in v1.

---

## 7. Non-Blocking Recommendations Summary

1. **Add `idx_entity_links_link_type` index** for semantic filtering.
2. **Add `UNIQUE` constraint** on `(from_type, from_id, to_type, to_id, link_type, source)` for DB-level idempotency.
3. **Cap range expansion at 20 items** to prevent accidental blow-up.
4. **Resolve multi-ID headings** by using the first canonical ID found; log others.
5. **Reserve `hash`/`prev_hash` columns** in DDL comments for v2.
6. **Create shared `insert_entity_links()` helper** in a common script (e.g., `scripts/db-link.sh`) for reuse across all live-write hooks.
7. **Log all skipped/ambiguous lines** in the backfill report for manual review.
8. **Consider `link_type="sprint-committed"`** for sprint→ticket edges instead of generic `relates-to` (v1 scope decision).

---

## 8. Assumptions Confirmed

| # | Assumption | Status |
|---|---|---|
| A1 | String canonical IDs | ✅ Confirmed |
| A2 | Default `relates-to` | ✅ Confirmed |
| A3 | Nearest preceding heading resolution | ✅ Confirmed (with clarification on multi-ID headings) |
| A4 | Range expansion | ✅ Confirmed (with 20-item cap recommendation) |
| A5 | Idempotent upsert | ✅ Confirmed |
| A6 | 90% completeness target (file paths excluded) | ✅ Confirmed |

---

## 9. Conclusion

**Verdict: SIGN-OFF** ✅

The `entity_links` schema is well-designed for v1. String canonical IDs are the right choice. The from-entity resolution rule is sound. Range expansion, prose handling, and non-canonical mention handling are adequately scoped. Live-write hook points are clearly identified with a consistent pattern.

Proceed to A2 (DDL creation by Forge). No blocking concerns. The 6 open questions (Q1–Q6) need Ken confirmation but do not block A2 — the schema is stable regardless of the answers.
