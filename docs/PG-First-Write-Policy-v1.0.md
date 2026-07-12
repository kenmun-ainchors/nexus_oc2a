# PG-First Write Policy v1.0

**Document ID:** PG-FIRST-WRITE-v1.0  
**Status:** LIVE (pending enforcement gate build by Forge as fast-follow ticket)  
**Owner:** Yoda (policy) · **Enforcement:** Forge (gate implementation)  
**Approved by:** Ken Mun — 2026-07-12  
**CHG:** CHG-0793 (execution umbrella)  

---

## 1. Inverted Default

**PostgreSQL is the primary write target for all durable operational state.**  
JSON files, markdown files, and ad-hoc state blobs are derived caches only.  
The rule is: write to PG first, then optionally derive JSON/md if a consumer still needs it during transition.

## 2. Four-Class Model

| Class | Definition | Where it lives | Examples |
|-------|-----------|----------------|----------|
| **Class 1 — Durable operational state** | Structured, keyed, time-ordered facts that must be queryable, auditable, and linkable by entity_links | **PG-first** | state_standups operational columns, state_changes, state_lessons, state_sprints, CHG records, ticket lifecycle |
| **Class 2 — Derived reports / exports** | Read-only snapshots generated from PG for human review or external sharing | Derived from PG | EOD journal PDF, canvas standup HTML, sprint review reports |
| **Class 3 — Transient shared state** | Short-lived or agent-local flags that can be recomputed | `agent_shared_state`, in-memory, or JSON cache | model override hints, heartbeat flags, transient UI state |
| **Class 4 — Source-of-truth artifacts** | Documents that are the canonical definition themselves (policies, architecture docs, runbooks) | Git-tracked markdown under `docs/` | This policy, AGENTS.md, RULES.md |

## 3. Decision Heuristic

When adding or modifying state, ask:

1. Is it structured, keyed, and time-ordered? → Class 1 → **PG-first**.
2. Is it a read-only export of Class 1? → Class 2 → derive from PG.
3. Is it ephemeral or recomputable? → Class 3 → JSON/KV cache OK.
4. Is it the canonical text of a policy/architecture decision? → Class 4 → Git markdown.

## 4. Migration Discipline

For existing JSON-primary state:

1. **Dual-write** — PG write added alongside existing JSON write.
2. **Shadow-validate** — run parity checks until PG and JSON agree for new writes.
3. **Cutover** — read path switched to PG with JSON as fallback.
4. **Retire JSON** — only after policy enforcement gate is live and behavioral proof exists that JSON regenerates from PG.

No backfill unless the historical data already exists in PG or another trusted source. **You cannot backfill state that was never captured in PG.**

## 5. Enforcement

Until the automated gate is built:

- All new Class 1 writers must be registered in `state/pg-first-write-registry.json`.
- Code reviews for scripts that touch state must confirm the four-class classification.
- Warden will add a compliance check: any new JSON write of structured state without a corresponding PG write is flagged.

## 6. Scope Limits

- This policy does not require rewriting all historical scripts in one sprint.
- It does not apply to Class 3 transient state or Class 4 canonical docs.
- JSON files may remain as derived caches during transition, but they must be provably derived.
