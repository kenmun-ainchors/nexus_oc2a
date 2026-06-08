# PR: CP3/P0 — core DDL (p0_core_spine)

## Change reference
- CHG: CHG-____ ← fill from backlog
- TKT: TKT-____ ← fill from backlog

## What & why

Implements the P0 core spine schema (CP3-P0-DDL-v0.2) as three ordered
alembic revisions.  Schema only — no controller daemon, no adapter.

### Revisions

| Rev | Slug | Content |
|-----|------|---------|
| p0c001 | core_tables | `nexus_controller` schema, `pgcrypto`, 7 loop tables with all CHECKs, FKs (ON DELETE CASCADE), UNIQUEs |
| p0c002 | functions_triggers | `touch_updated_at`, `enforce_judge_independence`, `episodic_chain` (advisory-lock serialised), `block_mutation`; 5 triggers |
| p0c003 | indexes | 12 supporting indexes (partial + GIN) |

All three have clean `downgrade()` in reverse dependency order; schema dropped last.

### Tests — `tests/integration/test_p0_schema.py`

| Test | What it checks |
|------|----------------|
| T1 | `judge_model = executor_model` on `verification` INSERT → trigger raises (independence) |
| T1 sanity | `judge_model ≠ executor_model` is accepted |
| T2 update | UPDATE on `episodic_event` → trigger raises (append-only) |
| T2 delete | DELETE on `episodic_event` → trigger raises (append-only) |
| T3 | Append 6 events; walk chain; `row_hash` recomputed via DB `digest()`; `prev_hash` links verified; tampered payload detected |
| T5 | DELETE `loop_plan` cascades to `plan_atom` / `atom_result` / `verification` |
| T6 | Two concurrent `SELECT … FOR UPDATE SKIP LOCKED` claimers grab disjoint atoms; union = full set |

T4 (zero-divergence vs live TQP) is operational — run by Forge post-merge.

### Spec compliance

- Schema `nexus_controller` ✓
- `CREATE EXTENSION IF NOT EXISTS pgcrypto` ✓
- All tables, columns, CHECKs, FKs, UNIQUEs exactly as §3 ✓
- All 4 functions + 5 triggers exactly as §4 ✓
- All 12 indexes exactly as §5 ✓
- `event_type` CHECK limited to 10 locked values ✓
- No T4 / `knowledge_chunk` / pgvector ✓
- No daemon wiring ✓

### No conflicts with NHEA-v0.5 §6

Spec is an exact materialisation of §6.1/§6.2 with all open items resolved
(schema name → `nexus_controller`, hash side → DB trigger, `assigned_model`
persisted as hint, `event_type` vocabulary locked at 10 values).

## Discipline check
- [x] OpenClaw coupling stays inside adapter/ only (schema only — no adapter touched)
- [x] Tests added (T1–T3, T5, T6 in tests/integration/test_p0_schema.py)
- [ ] Runbook updated if ops behaviour changed — N/A (schema only; shadow-deploy runbook to follow in P0 ops slice)
- [x] Schema change has alembic migration (p0c001/p0c002/p0c003)

## Acceptance criteria (from spec §8 / handoff)
- [ ] `alembic upgrade head` clean on sandbox PG
- [ ] `alembic downgrade base` clean on sandbox PG
- [ ] Tests T1–T3, T5, T6 pass in CI on self-hosted runner
- [ ] Schema diff matches v0.2 §3–§5 (no extra/missing objects)

## DoD
- [ ] CI green (self-hosted runner)
- [ ] Atlas arch review
- [ ] Sage QA gate
- [ ] Ken approval

## Notes
- `psycopg2-binary` added to dev deps (required by alembic SQLAlchemy sync driver).
- `asyncio_mode = "auto"` set in `[tool.pytest.ini_options]` (all async def tests auto-collected).
- `tests/chaos/__init__.py` and `tests/adapter_compat/__init__.py` stubs added so CI `pytest tests/chaos -q` etc. collect cleanly (0 tests, no error).
- pgcrypto not dropped in `downgrade()` — may be used by other schemas. Manual step if a full clean-slate is needed.
- **Do NOT merge** — gated by DoD above.
