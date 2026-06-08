# T4 Shadow Divergence Measurement Contract

**Document ID:** CP3-P0-T4-DIVERGENCE-v0.1
**Status:** DRAFT (resolves Sage condition C1) — for Sage validation, Forge implementation
**Date:** 2026-06-08
**Refs:** CP3-P0-DDL-v0.2 §6–§7 (T4); NHEA-v0.5 §10 (P0 exit gate)
**Owner:** Forge (harness) · **Validates:** Sage · **Runs:** post-merge, before P0 closure

---

## 1. Purpose
Define, measurably, what "zero divergence" means for the P0 exit gate (T4). In shadow mode the controller runs **observe/mirror only** — it reads live work and writes mirrored rows into `nexus_controller`, driving no execution. T4 proves the controller's representation of live state is **faithful** before P1 lets it drive anything.

## 2. What is compared
- **Source of truth (live):** the existing TQP / tickets state (live work items + their dependencies/status).
- **Mirror (under test):** `nexus_controller.loop_plan` + `nexus_controller.plan_atom` produced by the controller in observe mode.

## 3. Correlation key
Each mirrored row carries the originating live id (e.g. `loop_plan.metadata->>'source_tkt'`, `plan_atom.metadata->>'source_atom'`). Comparison correlates live ↔ mirror on this key. Rows with no resolvable key are an automatic divergence (class EXTRA).

## 4. Field & status mapping
The harness compares a defined field set, not the whole row:

| Live field | Mirror field | Notes |
|---|---|---|
| work item id | `metadata.source_tkt` / `source_atom` | correlation key |
| status | `loop_plan.status` / `plan_atom.status` | via status map below |
| dependencies | `plan_atom.dependencies[]` | set-equality on mapped ids |
| owner/tenant | `tenant_id` | exact |
| data classification | `data_class` | exact (`own_ops`/`client`) |

**Status map (live → mirror)** must be enumerated explicitly (e.g. live `done` → `complete`, live `in_progress` → `running`, …). Any live status with no mapping entry is an automatic divergence (class FIELD_MISMATCH) until the map is extended.

## 5. Divergence classes
- **MISSING** — live item present, no correlated mirror row.
- **EXTRA** — mirror row present, no correlated live item.
- **FIELD_MISMATCH** — correlated, but a compared field differs (incl. unmapped status).
- **STALE** — correlated and equal, but mirror lag exceeds the bound (default **≤ 5 min** after the live change).

## 6. Explained vs unexplained
- An **allowlist** enumerates explained divergences (e.g. live item types deliberately not mirrored in P0, archived/closed items outside the window). Each entry has a reason + owner.
- **Unexplained = any divergence not matching an allowlist entry.**

## 7. Metric
Per comparison cycle: counts per class, plus `unexplained_total` and `unexplained_rate = unexplained_total / live_item_count`. Recorded cumulatively over the window.

## 8. Pass / fail (T4 gate)
- **PASS:** `unexplained_total = 0` sustained across **7 consecutive daily cycles** (strict zero — tolerance is zero for *unexplained*; explained divergences are documented and allowed).
- **FAIL:** any unexplained divergence → investigate, fix mapping/controller or extend the allowlist with justification, reset the 7-day count.

## 9. Harness mechanism (Forge)
Per cycle (daily, or per sync): snapshot live state + mirror state → correlate on key → classify each diff → apply allowlist → emit a divergence report (per-class counts + up to N examples each) → write report to obs.db and an `episodic_event` (`event_type='system'`). Alert Ken on any unexplained divergence (existing Telegram path).

## 10. Definition of Done (C1)
Status map fully enumerated · allowlist seeded · harness emits the report + metric · 7-day strict-zero run green · Sage validates the contract is met. Then T4 is satisfied and P0 can close.

---
*Resolves Sage C1. Harness is post-merge operational — does not block the migration PR merge; it gates P0 closure.*

---

## v1.1 Amendment — 2026-06-08 22:50 AEST (CHG-0473, Ken Mun)

**Correction:** Harness v2.0 had a STALE definition drift. The implementation was checking "live ticket not updated in >7 days" (dormancy) rather than the C1 §5 definition of STALE = mirror lag > 5 min after a live change.

**Resolution:**
1. STALE per C1 §5: correlated & equal, but mirror `updated_at` > 5 min behind live `updated_at`. This is the replication lag check that proves the mirror keeps up.
2. Dormant tickets (>7 days no update) moved to `info.dormant_tickets` — informational only, not a C1 divergence class.
3. Harness v2.2 implements the correct STALE check using `live_row.updated_at - shadow_row.updated_at > 5 min`.
4. No contract text changed — the original C1 §5 was correct. Only the implementation was corrected.

**Verified:** Re-run with v2.2 → STALE=0, Match=616, Unexplained=0. Mirror lag check is operational.
