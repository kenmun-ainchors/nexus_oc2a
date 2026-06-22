# Phase 1 — Structured Foundation · Design Module
**Doc ID:** CRESTv2-P1-DM-v1.0 · **Date:** 2026-06-22 · **Track:** A (live platform, `ainchors_nexus`)
**Addressed to:** Yoda (orchestrator) — dispatches **Forge** (build), **Atlas** (EA), **governance** (criteria). **Sage does not harden itself.**
**Delivers:** CRESTv2-PLAN-v1.1 Phase 1 · **Folds in:** CRESTv2-JH-001 (Judge-hardening) · **Hand-off:** §1 Schema Contract → Phase 2 (Claude Code)
**Status:** DESIGN MODULE for Ken review → on approval, this *is* the release.

---

## 0. Purpose & placement
Make the durable substrate reliable, linked, and lean — the prerequisite the controller consumes at convergence (Phase 3). The controller cannot reason on a substrate that cannot answer **"the full history / decisions / actions of X."** Today it can't (proven: the "history of TKT-0546" query fails — no event trail, no lineage, grep-dependent). Phase 1 fixes that, on the live platform, with migration discipline. Track A runs **in parallel with Phase 2** (controller core, Claude Code); the only hard cross-dependency is that **Phase 2 builds against §1 below**, so §1 is published first.

## 0.1 Starting ground truth (WO-MEM-001, design against this — not against the Phase-4 memory design doc)
| Area | Reality today |
|---|---|
| T3 episodic | Schema deployed, **0 rows** — `agent_events`/`agent_decisions`/`decision_lineage`/`memory_access_log` empty. **No write pipeline.** |
| T4 vector | Already partly built — pgvector 0.8.2, `knowledge_chunks` **1,695** @768-dim, `knowledge_documents` 62. **FREEZE.** |
| T5 shared | `agent_shared_state` 6 rows (heartbeat ts only); `agent_state_history` 0. |
| CHGs | **1,144** in markdown, **not PG**. |
| Lessons | **7**, in markdown, not PG. |
| Links | Text-grep `"Linked:"` mentions — **not FK**. |
| Keys/sprints | **11** sprint-name formats; **263/350** tickets unsprinted. |
| Tickets | **350 PG vs 257 JSON** (93-gap dual-write drift). |
| `state_*` tables | **18 of 22 empty.** |
| Verdict store | `state/sage-qa-log.json` — malformed JSON, no unique key, judgment stubbed (WO-JUDGE-001). |

---

## 1. ★ SCHEMA CONTRACT (published first — the Phase 2 hand-off) ★
Design-grade: table name, purpose, key columns, relationships. **Exact DDL/types = Forge's build detail; the shape and keys below are LOCKED** because Phase 2's scoped-context assembly (2D) reads them. Changes after publish require a contract revision both tracks agree to.

### 1.1 Episodic event log — the spine of "history of X"
**`agent_events`** (exists, empty → wire writes). Every meaningful platform/agent action emits one immutable row.
| Column | Purpose |
|---|---|
| `event_id` (PK, unique) | stable identifier |
| `ts` | event time (ISO+tz) |
| `actor` | agent/process that acted |
| `event_type` | created / updated / verdict / dispatched / resolved / linked / … |
| `entity_type` + `entity_id` | **the X** (ticket / chg / lesson / sprint / atom / verdict…) — the query key |
| `payload` (JSONB) | event detail |
| `prev_state` / `new_state` | for state transitions (nullable) |
| `hash` / `prev_hash` | tamper-evident chain (T3 immutability) |

"History of X" = `SELECT … FROM agent_events WHERE entity_id = :X ORDER BY ts` **+** edge traversal (§1.3).

### 1.2 Structured records (out of markdown, into PG)
**`state_changes`** — change_id (`CHG-NNNN`, unique) · ts · title · description · actor · status. Migrate **1,144**.
**`state_lessons`** — lesson_id (`L-NNN`, unique) · ts · title · body · status. Migrate **7**; capture future.
Relationships to other entities are **not** columns here — they live in §1.3.

### 1.3 Linking model — replaces grep
**`entity_links`** (edge table). Replaces text `"Linked:"` mentions; enables multi-hop traversal.
| Column | Purpose |
|---|---|
| `link_id` (PK) | identifier |
| `from_type`+`from_id` / `to_type`+`to_id` | the two endpoints (any entity) |
| `link_type` | relates-to / caused-by / resolves / supersedes / blocks … |
| `ts` · `source` | when established · how (migrated-from-md / live-write) |

### 1.4 Hardened verdict store (JH item 4) — replaces `sage-qa-log.json`
**`verdict_log`** (PG, keyed, well-formed).
| Column | Purpose |
|---|---|
| `verdict_id` (PK, unique) | **the missing unique key** |
| `ts` · `judge` | when · which judge (sage) |
| `subject_type`+`subject_id` | deliverable / work-atom judged |
| `verdict` | pass / fail / needs_human |
| `checks_run` (JSONB) | **which checks actually executed** (no provisional auto-pass) |
| `evidence_ref` | primary evidence the verdict was rendered against |
| `checkout_ref` | tree/commit the verdict was against (freshness, TKT-0403) |

This is the population **WO-JUDGE-002** will sample. PASS must mean judgment was made, not assumed.

### 1.5 Canonical keys & sprints
**`state_sprints`** — sprint_id (single canonical form) · name · start_date · end_date · status. Tickets FK → sprint_id (fixes 11 formats + 263 unsprinted).
Canonical ID forms (enforced): `TKT-NNNN` · `CHG-NNNN` · `L-NNN` · `WO-XXX-NNN`. PG is ticket **SSOT**; JSON → fallback-then-retire after parity.

### 1.6 What Phase 2 reads (the locked read-interface)
`agent_events` (by `entity_id`) · `entity_links` (traversal) · `state_changes` / `state_lessons` (records) · `verdict_log` (subject history) · `state_sprints` + ticket FK. **Phase 2's 2D assembles scoped context from exactly these. No other read coupling.**

---

## 2. Workstreams

| WS | Title | Core work | Owner |
|---|---|---|---|
| **WS-1** | Memory backbone | Wire **T3 write pipeline** (`pg_write_events`, TKT-0357) so `agent_events` actually fills; migrate **CHGs→`state_changes`**, **lessons→`state_lessons`** | Forge build |
| **WS-2** | Linking model | Build `entity_links`; **backfill** from markdown `"Linked:"` with **completeness measurement** (not best-effort) | Forge build |
| **WS-3** | Key/sprint/JSON normalization | Collapse 11 sprint formats → `state_sprints`; FK 263 unsprinted; reconcile **93-gap** JSON↔PG; PG=SSOT | Forge build |
| **WS-4** | DNA leanness (Pivot B) | Split DNA by purpose; **dedupe rules to one canonical source** (kills 215/234 dup); **rules→deterministic gates**; JIT skills; size budgets; shrink Yoda **64.9KB→target** | Forge + governance |
| **WS-5** | Judge-hardening (CRESTv2-JH-001) | **Item 0 first** (does real LLM judgment exist?); item 1 criteria (deliverable DoD); item 2 **wire judgment to gate**; item 3 evidence-grounded (TKT-0403); item 4 = `verdict_log` (§1.4) | Forge build · Atlas/gov criteria · **not Sage** |
| **WS-6** | Vector freeze | Park **TKT-0352** + **TKT-0171**; do **not** touch the 1,695 chunks | hold |

### 2.1 DNA leanness detail (WS-4)
- **Split by purpose:** identity / rules / skills / memory / status — per agent.
- **Single-source rules:** one canonical rules file referenced by all; only agent-specific deltas local. Target: eliminate the 92% duplication.
- **Rules→gates:** enforceable rules become deterministic checks, not soft context (e.g. FORGE EXECUTE GATE; **L-162** Yoda-not-editing-scripts-directly). A gated action is *blocked*, not *reminded*.
- **JIT skills:** load a skill into context only when the task needs it (manifest + loader), not all 9 always.
- **Budgets:** per-file caps, enforced (extend auto-heal CHECK 15).

---

## 3. Migration discipline (this is live — open-heart surgery)
**Standing rule: no big-bang on live state.** Every migration runs **dual-write → shadow-validate → cutover → rollback-ready**:
| Migration | Specific discipline |
|---|---|
| CHGs→PG (WS-1) | Dual-write md+PG; validate counts+content; cutover read to PG; rollback to md read on fail. Backfill 1,144 with completeness check. |
| Key/sprint normalization (WS-3) | **Riskiest** (mutates live identifiers). **Reversible map table**, dual-key acceptance window, validate, cutover, keep rollback map. Never rename in-place. |
| JSON↔PG ticket reconcile (WS-3) | PG SSOT; reconcile 93-gap; JSON→read-only fallback; **retire only after parity proven**. |
| T3 write pipeline (WS-1) | Additive (new writes); shadow-run, confirm events land + chain valid before relying on them. |

---

## 4. Sprint mapping (per the agreed triage — no re-plan)
| Sprint | Keep / Elevate | Defer | Add |
|---|---|---|---|
| **S9** (Jun 22–28, committed) | Elevate **TKT-0390** (deploy T3 episodic) + **TKT-0357** (pg_write_events). JH **item 0** here. | — | CHGs→PG start |
| **S10** | Keep wiring | **Defer TKT-0352** (vector write pipeline) | Linking model + backfill |
| **S11** | Keep table creation; elevate **TKT-0362** (`state_lessons`) | **Defer TKT-0171** (RAG pipeline) | Key/sprint/JSON normalization; verdict_log |
| Across | DNA leanness (WS-4); JH items 1–4 | — | — |

**Net descope = exactly two tickets (TKT-0352, TKT-0171).** Most of epic **TKT-0342** (PG SSOT) is correctly structured-backbone and stays.

---

## 5. Exit gate (sustained + sampled — primary evidence)
**Primary acceptance — "history of several real X":** re-run *full history of <X>* for **multiple real entities including known-messy ones** — at minimum a reused-ID case (e.g. `CONTENT-0001`, reused for 3 assets), a heavily-cross-referenced ticket (e.g. `TKT-0546`), and a CHG with many links. Each returns a **complete, linked, time-ordered** answer **entirely from PG** (events + edges + records), no grep.
**Completeness, not existence:** measure backfill completeness against ground truth (what fraction of true events/links captured) — an answer that *returns* is not the bar; an answer that is *complete* is.
**Sustained:** held green **over a window** while the platform keeps writing — not a one-shot. (WO-002's window discipline.)
**Sub-gates:**
- **DNA:** Yoda T1 injection reduced to target band; rule duplication eliminated (one canonical source); a gated rule demonstrably **blocks** a violating action.
- **Judge:** `verdict_log` live, keyed, well-formed; judgment checks **gate** (a known-bad deliverable is FAILed; a genuinely-done one PASSes) over a window → **unlocks WO-JUDGE-002**.
**Verification:** by primary evidence (query results, row counts, blocked-action demo) — **not** an agent's report.

---

## 6. Roles & independence
- **Yoda** orchestrates; dispatches and verifies — does **not** build scripts directly (L-162, now a WS-4 gate).
- **Forge** builds. **Atlas** EA-assesses. **Governance (Atlas/Yoda+Ken)** defines deliverable-DoD criteria (WS-5 item 1).
- **Sage does not design, build, or certify its own hardening.** Independent verification of the hardened Judge = WO-JUDGE-002 (Ken+Claude adjudicate).
- **Primary evidence, not prose. Flag contradictions; do not resolve.** Ground-truth-before-green on every sub-gate.

## 7. Dependencies & hand-offs
- **§1 Schema Contract → Phase 2** (Claude Code): publish first; both tracks then run parallel; converge at Phase 3.
- **JH item 0 runs first** — shapes WS-5 effort (wire-a-stub vs build-from-scratch); does not block the §1 hand-off.
- **OC2 (~Jul 6–13) is not a Phase 1 dependency** — Phase 1 is live-platform, pre-OC2.
- **On approval:** release to Yoda for S9 slotting; I produce the **Phase 2 controller-core module** targeting §1.

---
*CRESTv2-P1-DM-v1.0. Structured foundation, Track A. Schema contract locked for Phase 2; live-migration discipline; sustained+sampled exit gate. Build = Forge; criteria = governance; Judge verification = independent.*
