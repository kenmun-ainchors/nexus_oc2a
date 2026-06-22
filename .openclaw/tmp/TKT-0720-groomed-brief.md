# TKT-0720 — Groomed Brief
**Ticket:** Create entity_links edge table + backfill from markdown Linked: mentions  
**Status:** open | critical | Sprint 9 | effort M  
**Groomed:** 2026-06-22 19:46 AEST by Yoda  
**Source:** Design module §1.3 `docs/CRESTv2-P1-DM-StructuredFoundation-v1.0.md`

---

## 1. Goal (refined)
Replace grep-based `Linked:` mentions with a durable, queryable edge table (`entity_links`) so the platform can answer "what is related to X?" via SQL, not `grep`. Every meaningful cross-entity reference currently trapped in markdown becomes an FK-like edge. New live writes (ticket/CHG creation and update, lesson capture) must insert edges atomically.

---

## 2. Scope Boundaries

### In scope (v1)
1. Create `entity_links` table per §1.3 contract.
2. Parse `Linked:` lines from:
   - `memory/CHANGELOG.md`
   - `memory/*.md`
   - `docs/*.md`
   - `agents/**/*.md` if any `Linked:` exist
3. Supported endpoint entity types for v1:
   - `ticket` → canonical `TKT-NNNN`
   - `chg` → canonical `CHG-NNNN`
   - `lesson` → canonical `L-NNN` (target table `state_lessons` does **not** yet exist; see dependency §6)
   - `sprint` → sprint number as text (maps to `state_sprints.sprint_number`)
   - `wo` → `WO-XXX-NNN` (target table does not yet exist; stored as generic endpoint for later migration)
4. Default link type: `relates-to`.
5. Backfill script that is **idempotent** (upsert on `from_type+from_id+to_type+to_id+link_type+source`).
6. Live-write hooks in:
   - `scripts/db-ticket.sh` (ticket creation/update, when `Linked:` or explicit metadata links present)
   - `scripts/changelog-append.sh` (CHG creation)
   - `scripts/db-sprint.sh` (sprint commits, when tickets linked)
   - Future `lesson-append.sh` / `db-lesson.sh` (lesson capture; not built yet)
7. Completeness metric computed against a **ground-truth sample** of 50 randomly selected `Linked:` blocks, manually audited.
8. Rollback script `infra/rollback/TKT-0720-rollback.sql`.

### Out of scope / deferred
- Inferring link semantics from prose (e.g., "resolves", "blocks", "supersedes"). All parsed links default to `relates-to`.
- Backfilling `state_changes` from markdown CHANGELOG (only 4 CHGs in PG vs 1,144 in markdown). Migration of markdown CHGs into `state_changes` is **TKT-0342 / separate work**.
- Creating `state_lessons` table or WO table; entity_links stores `lesson`/`wo` endpoints generically, but referential integrity against those tables is deferred.
- File paths (e.g., `state/crestv2-p1-tracker.json`, `infra/rollback/...`) captured as `file` type but **not counted** in the 90% completeness target.
- Inline prose link detection beyond explicit `Linked:` lines.
- Vector table `knowledge_chunks` / `knowledge_documents` — frozen per TKT-0352/TKT-0171.

---

## 3. Ground Truth & Assumptions

### Evidence gathered
- **707 `Linked:` patterns** found in `memory/` and `docs/`.
- **Entity ID forms referenced:** `TKT-NNNN`, `CHG-NNNN`, `L-NNN`, `WO-XXX-NNN`, `US##`, `Sprint N`, file paths.
- **`state_changes` has only 4 rows** (`CHG-0713`–`CHG-0718`). Markdown CHANGELOG has 1,144 CHG entries.
- **`state_lessons` does not exist**; `memory/LESSONS.md` has L-026 through L-165.
- **`state_sprints` exists** with UUID PK and `sprint_number`. `state_tickets` FKs to it via `sprint_id`.
- **`entity_links` table does not exist**.

### Assumptions (require confirmation)
1. **A1 — Link endpoint ID format:** Use canonical string IDs (`TKT-NNNN`, `CHG-NNNN`, `L-NNN`, `WO-XXX-NNN`) and sprint number text. The edge table stores strings, not foreign-key UUIDs, so it is entity-type-agnostic. Confirmed acceptable?
2. **A2 — Default link type:** All parsed `Linked:` entries become `relates-to`. Semantic inference (resolves/blocks/supersedes/causes) is future work. Confirmed?
3. **A3 — From-entity resolution:** For `CHANGELOG.md`, the containing CHG is derived from the nearest preceding `## ... [CHG-NNNN]` heading. For other docs, the containing entity is derived from the nearest preceding heading that contains a `TKT-NNNN` or `CHG-NNNN` or `L-NNN`. If no containing entity is found, the link is skipped and logged. Confirmed?
4. **A4 — Range expansion:** Patterns like `CHG-0604–CHG-0608` expand to individual edges `CHG-0604`, `CHG-0605`, ..., `CHG-0608`. Confirmed?
5. **A5 — Idempotency:** Backfill script upserts edges keyed by `(from_type, from_id, to_type, to_id, link_type, source)`. Re-runs do not duplicate. Confirmed?
6. **A6 — Completeness target:** 90% of discoverable `TKT/CHG/L/WO/Sprint` references captured, measured against a manually audited sample of 50 `Linked:` blocks. File-path links excluded from the metric. Confirmed?

---

## 4. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| R1 — Markdown parsing is fragile (parentheses, em-dashes, commas, prose in Linked: lines) | False-positive/negative edges | Conservative regex + manual sample audit; parser logs ambiguous lines for review |
| R2 — Ambiguous "from" entity (multi-entity docs without clear headings) | Dangling or misattributed edges | Skip and log when containing entity cannot be resolved; include in completeness gap |
| R3 — Re-running backfill after live writes creates duplicates unless upsert | Duplicate edges | Upsert key includes source; source distinguishes `migrated-from-md` vs `live-write:*` |
| R4 — `state_lessons` / WO tables missing means lesson/wo links have no referential integrity | Orphan endpoints | Store generically; defer FK enforcement until those tables exist |
| R5 — Live-write hook misses manual edits that don't go through scripts | Missing edges | Accept for v1; policy is "PG-first writes via scripts" per TKT-0359 |
| R6 — Completeness metric sampling bias | Over/under-stated coverage | Random sample across files and time; document methodology |

---

## 5. Open Questions for Decision

1. **Q1 — File-path links:** Should we store file paths as `file` entity links, or skip them entirely for v1? (Recommendation: store as `file` but exclude from 90% target.)
2. **Q2 — Sprint link normalization:** Sprint references like "Sprint 9" should map to `state_sprints.sprint_number` (text `9`) or to the UUID `id`? (Recommendation: text `9` for human readability, with a view that joins on `sprint_number`.)
3. **Q3 — `state_changes` migration scope:** Do we migrate the 1,144 markdown CHGs into `state_changes` now, or keep TKT-0720 focused on edges only? (Recommendation: keep TKT-0720 edges-only; CHG migration is separate.)
4. **Q4 — Live-write hook granularity:** Should `db-ticket.sh` parse `Linked:` inside ticket `description`/`metadata`, or only explicit `linked` metadata field? (Recommendation: parse a `links` array in metadata plus any `Linked:` line in description.)
5. **Q5 — Link directionality:** Are edges directed (`from` → `to`) or undirected with symmetric pairs? (Recommendation: directed with an optional reverse index or symmetric insertion for `relates-to`; keep table directed.)

---

## 6. Dependencies

| Dependency | Status | Notes |
|---|---|---|
| TKT-0726 (event pipeline) | ✅ done | `agent_events` emits for writes; `entity_links` live writes should also emit events. |
| TKT-0330 (canonical IDs) | ✅ done | Ensures `TKT-NNNN` / `CHG-NNNN` forms are stable. |
| `state_sprints` canonical IDs | ✅ exists | `sprint_number` is stable. |
| `state_lessons` table | ❌ missing | Lesson links stored generically; FK deferred. |
| WO table | ❌ missing | WO links stored generically; FK deferred. |
| TKT-0342 (CHG markdown → PG) | 🚧 later | Not a hard dependency for v1 edges. |

---

## 7. Definition of Groomed-Done
- [x] Evidence gathered from markdown, PG schema, and entity ID forms.
- [x] Scope boundaries documented (in/out).
- [x] Assumptions listed and framed as confirm-or-correct questions.
- [x] Risks and mitigations documented.
- [x] Dependencies mapped.
- [ ] User confirms/corrects A1–A6 and Q1–Q5.
- [ ] Then proceed to CREST Step 1 Plan.

---

## 8. Artifacts
- Groomed brief: `.openclaw/tmp/TKT-0720-groomed-brief.md` (this file)
- Design module: `docs/CRESTv2-P1-DM-StructuredFoundation-v1.0.md` §1.3
- Tracker: `state/crestv2-p1-tracker.json`
