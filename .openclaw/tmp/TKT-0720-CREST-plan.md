# TKT-0720 — CREST Step 1 Plan
**Ticket:** Create entity_links edge table + backfill from markdown Linked: mentions  
**Groomed brief:** `.openclaw/tmp/TKT-0720-groomed-brief.md`  
**Plan produced:** 2026-06-22 19:54 AEST by Yoda (orchestrator)  
**CREST model:** `ollama/kimi-k2.7-code:cloud` (yoda_master Plan, CHG-0690)

---

## 0. Pre-execution gates (must pass before A1)

| Gate | Owner | Evidence |
|---|---|---|
| G1 — CHG record | Yoda | `changelog-append.sh` creates `CHG-0719` (or next available) with linked TKT-0720 |
| G2 — Baseline snapshot | Forge | `git status` clean on `scripts/` and `infra/rollback/`; existing rollback scripts untouched |
| G3 — Groom approval | Ken | Groomed brief A1–A6 confirmed (approved 2026-06-22 19:53 AEST) |

---

## 1. Atom DAG

```
G1/G2/G3 ─┬─► A1 Atlas architecture review ─┬─► A2 Forge DDL/table ─┬─► A3 Forge backfill parser ─┐
          │                                    │                        │                             │
          └────────────────────────────────────┴────────────────────────┴─► A4 Forge live-write hooks ─┼─► A5 Yoda completeness audit ─┐
                                                                                                      │                              │
                                                                                                      └─► A6 Atlas/Yoda multi-hop demo ┘
                                                                                                                                    │
                                                                                                                                    ▼
                                                                                                                               A7 Yoda/Sage E2E verify
                                                                                                                                    │
                                                                                                                                    ▼
                                                                                                                               A8 Forge rollback + commit
```

**Parallelism allowed:** A2/A3/A4 share `entity_links` table but are sequential (DDL → backfill → hooks). A5/A6 can run in parallel after A3/A4 complete.

---

## 2. Atoms

### A1 — Architecture review (Atlas)
- **Owner:** `agentId="architect"` (Atlas)
- **Model:** `deepseek-v4-pro:cloud` (design_backend Plan)
- **Task:** Sign off on `entity_links` schema, from-entity resolution rules, edge-case handling for ranges/parentheses/file paths, and live-write hook points.
- **Output:** `.openclaw/tmp/TKT-0720-A1-architecture-note.md` with verdict `SIGN-OFF` / `NEEDS_CHANGES` + non-blocking recommendations.
- **RVEV trace:** Atlas reads design module §1.3 + groomed brief, validates schema against Phase 2 read-interface, produces note.
- **HITL:** If `NEEDS_CHANGES`, Yoda presents to Ken before proceeding.

### A2 — DDL + `entity_links` table (Forge)
- **Owner:** `agentId="infra"` (Forge)
- **Model:** `deepseek-v4-flash:cloud` (build Execute)
- **Task:** Create `entity_links` table per §1.3 + A1 sign-off.
- **Contract columns:** `id` (uuid PK), `link_id` (text unique, `LNK-NNNN`), `from_type` (text), `from_id` (text), `to_type` (text), `to_id` (text), `link_type` (text), `ts` (timestamptz), `source` (text), `tenant_id` (text), `payload` (jsonb optional), `hash`/`prev_hash` (text, chain optional but recommended for parity with `agent_events`).
- **Indexes:** `entity_links_pkey`, `entity_links_link_id_key`, `idx_entity_links_from`, `idx_entity_links_to`, `idx_entity_links_pair`.
- **Sequence:** `entity_links_link_id_seq` starting after max existing `LNK-*` if any (none expected).
- **Output:** SQL file applied to `ainchors_nexus`; evidence in `.openclaw/tmp/TKT-0720-A2-evidence.md`.
- **RVEV:** Forge validates table exists with expected columns/indexes.

### A3 — Markdown backfill parser + script (Forge)
- **Owner:** Forge
- **Model:** deepseek-v4-flash
- **Task:** Build `scripts/entity-links-backfill.sh` that:
  - Accepts `--dry-run`, `--source-dir`, `--commit`.
  - Parses `Linked:` lines from `memory/CHANGELOG.md`, `memory/*.md`, `docs/*.md`.
  - Resolves containing entity from nearest preceding heading (`CHG-NNNN`, `TKT-NNNN`, `L-NNN`).
  - Expands ranges (`CHG-0604–CHG-0608`).
  - Strips prose/parentheses; matches canonical IDs.
  - Upserts edges keyed by `(from_type, from_id, to_type, to_id, link_type, source)`.
  - Emits `agent_events` row per batch (or per file) using `pg_write_event`.
  - Writes summary report: files scanned, links found, links written, ambiguous/skipped lines.
- **Output:** Script + backfill report; evidence in `.openclaw/tmp/TKT-0720-A3-evidence.md`.
- **RVEV:** Run `--dry-run` first; compare output to manual sample; then `--commit`.

### A4 — Live-write hooks (Forge)
- **Owner:** Forge
- **Model:** deepseek-v4-flash
- **Task:** Modify the following scripts to insert `entity_links` rows atomically when cross-entity references are detected:
  - `scripts/db-ticket.sh`: on create/update, parse explicit `links` metadata array and any `Linked:` text in description; emit edges + `agent_events`.
  - `scripts/changelog-append.sh`: on CHG create, parse `Linked:` field from the CHG metadata; emit edges + `agent_events`.
  - `scripts/db-sprint.sh`: on sprint commit, emit edges between sprint and each ticket; emit `agent_events`.
- **Output:** Modified scripts + evidence in `.openclaw/tmp/TKT-0720-A4-evidence.md`.
- **RVEV:** Create/update a test ticket/CHG/sprint and verify edges appear.

### A5 — Completeness audit (Yoda)
- **Owner:** Yoda (orchestrator)
- **Model:** kimi-k2.7-code (current)
- **Task:**
  - Randomly sample 50 `Linked:` blocks across files/time.
  - Manually audit expected vs actual edges in PG.
  - Compute completeness = captured / discoverable (excluding file paths).
  - Target: >90%.
- **Output:** `.openclaw/tmp/TKT-0720-A5-completeness-audit.md`.
- **RVEV:** Sample selection documented; counts reproducible; raw mismatch list attached.

### A6 — Multi-hop query demo (Atlas or Yoda)
- **Owner:** Atlas preferred; Yoda fallback if Atlas lacks exec.
- **Model:** deepseek-v4-pro (design_backend Verify) or kimi-k2.7-code
- **Task:** Demonstrate PG-only query: `TKT-0546` → linked CHGs → linked tickets, time-ordered. Compare against prior grep baseline.
- **Output:** `.openclaw/tmp/TKT-0720-A6-multihop-demo.md` with query and result.
- **RVEV:** Query executable; result complete vs sample.

### A7 — End-to-end verification + rollback dry-run (Yoda / Sage)
- **Owner:** Yoda orchestrates; Sage renders verdict.
- **Verify model:** gemma4:31b-cloud (Sage judge)
- **Checks:**
  1. `entity_links` schema matches contract.
  2. Indexes present.
  3. Backfill links >90% completeness.
  4. Live writes (ticket/CHG/sprint) produce edges and events.
  5. Hash chain (if implemented) intact.
  6. Multi-hop query returns expected results.
  7. Rollback script `infra/rollback/TKT-0720-rollback.sql` dry-runs safely (copy + replace final `COMMIT;` with `ROLLBACK;`).
- **Output:** `.openclaw/tmp/TKT-0720-A7-verification.md` + Sage verdict file.
- **RVEV:** Read → Validate → Execute → Verify per atom; evidence-only.

### A8 — Rollback script + commit (Forge)
- **Owner:** Forge
- **Model:** deepseek-v4-flash
- **Task:**
  - Create `infra/rollback/TKT-0720-rollback.sql` that drops `entity_links` table + sequence + index, deletes related `agent_events` rows if necessary, and reverts script changes (git revert or patch).
  - Commit all artifacts with message `TKT-0720: entity_links edge table + markdown backfill + live hooks`.
- **Output:** Commit SHA; evidence appended to `.openclaw/tmp/TKT-0720-A2-A3-A4-evidence.md` or new A8 evidence file.
- **RVEV:** `git log -1 --stat` confirms expected files; rollback script syntax-checked via safe dry-run.

---

## 3. Schedule

| Atom | Owner | Estimated effort | Dependency |
|---|---|---|---|
| A1 | Atlas | S (≤30 min review) | G1–G3 |
| A2 | Forge | S | A1 |
| A3 | Forge | M | A2 |
| A4 | Forge | M | A2 |
| A5 | Yoda | M | A3/A4 |
| A6 | Atlas/Yoda | S | A3/A4 |
| A7 | Yoda/Sage | M | A5/A6 |
| A8 | Forge | S | A7 |

**Total wall time:** ~2–3 hours, mostly Forge build. A5 audit is manual and may span into next day.

---

## 4. Rollback Plan

- **Before commit:** All changes are in git working tree; `git checkout -- scripts/db-ticket.sh scripts/db-sprint.sh scripts/changelog-append.sh` + drop `entity_links` table manually.
- **After commit:** Run `infra/rollback/TKT-0720-rollback.sql` (safe dry-run method: copy, replace final `COMMIT;` with `ROLLBACK;`, run; then run production artifact only after verification). Script drops table, sequence, indexes, and reverts git changes.
- **Data loss:** `entity_links` rows are derived from markdown; backfill script can reconstruct them. Live-only edges since backfill are lost if rolled back after live use.
- **Co-dependency:** Does not modify `agent_events` schema; live events emitted by hooks remain valid even if `entity_links` rolled back (though they may reference a missing table).

---

## 5. Evidence Standards

- Every atom must produce an evidence artifact in `.openclaw/tmp/`.
- Every script change must pass `--dry-run` before `--commit`.
- Every PG schema change must show `\d table` output.
- Every verification must include raw tool output, not prose-only claims.
- Sage renders A7 verdict pass/fail/needs_human.

---

## 6. CHG Record

Pre-execution CHG to create once this plan is approved:
- **CHG-0719** (or next available): `TKT-0720 execution: entity_links edge table + backfill + live hooks`
- Linked: TKT-0720, `docs/CRESTv2-P1-DM-StructuredFoundation-v1.0.md`, `state/crestv2-p1-tracker.json`

---

## 7. Approval Gate

- [ ] Ken approves this CREST Step 1 Plan.
- [ ] Ken confirms A1–A6 assumptions from groomed brief remain valid.
- [ ] Yoda records CHG-0719.
- [ ] Yoda dispatches A1 to Atlas.
