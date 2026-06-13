# Sprint 8 Plan — 2026-06-13 15:30 AEST

**Sprint:** 8
**Planning date:** 2026-06-13 15:30 AEST (Saturday)
**Capacity rule:** 5/sprint (pre-OC2). Ken 15:28 AEST approved 8-item scope (3 stub briefs locked-in despite overcommit).
**Forecast dates:** 2026-06-15 → 2026-06-21 (6 days, following Sprint 7 cadence)

## Committed items (9 total, 160% of capacity)

| # | TKT | Title | Status | Priority | Effort | Owner | Notes |
|---|---|---|---|---|---|---|---|
| 1 | TKT-0317 | Epic: Agent Context Optimization | **closed** | critical → closed | XS | Yoda | Hygiene sync 2026-06-13 15:30. Scope replaced by skills extraction + CREST v1.3. |
| 2 | TKT-0137 | Policy Register (original) | **closed** | high → closed | XS | Yoda | Folded into TKT-0221. TKT-0221 also hygiene-closed. Policy Register work retired. |
| 3 | TKT-0318 | Aria TQP Integration Phase 2 | **closed** | high → closed | XS | Yoda | Hygiene sync 2026-06-13 15:30. Scope superseded by CREST v1.3. |
| 4 | TKT-0405 | Mirror Tombstone Reconcile | **closed** | P3 → closed | XS | Yoda | Hygiene sync 2026-06-13 15:30. Actual work shipped via WO-002 cleanup (CHG-0554) earlier today. |
| 5 | TKT-0340 | P2: Constraint Hardening (long-ID stub) | **done** | Critical | — | Yoda/Atlas/Thrawn | Real work shipped. Stub housekeeping. Re-scope note + depends_on=[TKT-0368]. |
| 6 | TKT-0503 | Obs.db noise reduction closeout | open | P1 | M | Yoda | In progress, 7/7 atoms done. 24h review window closes 14:17 AEST 2026-06-14 (Telegram ping 14:00). Likely closes Monday. |
| 7 | TKT-0410 | Fix SUB_CREST_TRANSITIONS (verified → terminal) | open | high | S | Forge (execute) → Yoda (verify) | Carry-forward from Sprint 7. L-084 recovery pattern documented. Blocks every verified task from completing through typed path. |
| 8 | TKT-0319 | TQP Phase 3 — Global Agent Auto-Resume Protocol | open | critical | ? | Yoda (plan) | Stub brief. **Ken 15:28 AEST: lock into Sprint 8.** Needs full groom before commit-to-execute. |
| 9 | TKT-0324 | TQP Integration + Rollout Test for 2-Pass Dispatch | open | medium | ? | Yoda (plan) | Stub brief. **Ken 15:28 AEST: lock into Sprint 8.** Needs full groom before commit-to-execute. |

## Hygiene sweep status syncs (closed today, 2026-06-13 15:30 AEST)

- TKT-0317 (CRITICAL) — closed. Scope: replaced by skills extraction + CREST v1.3.
- TKT-0137 (high) — closed. Folded into TKT-0221 (also closed).
- TKT-0318 (high) — closed. Scope: superseded by CREST v1.3.
- TKT-0405 (P3) — closed. Scope: no longer applicable. Real work shipped via CHG-0554.
- TKT-0221 (REPLACEMENT) — closed. Same hygiene reason as TKT-0137.

**Pattern observed:** Ken's 2026-06-12 hygiene sweep closed 5 tickets in brief, but the PG status column didn't get applied. Today I synced 5 statuses (4 + TKT-0137 fold) via direct PG UPDATE workaround for the `db-ticket.sh update` script's JSONB conflict bug. **This is a hygiene-sweep mechanism gap — TKT candidate to investigate.**

## In-progress work

- **TKT-0503 (P1):** 7/7 atoms done. obs.db 24h baseline=123 events. 24h review window closes 14:17 AEST 2026-06-14. Telegram ping scheduled 14:00 AEST. **If clean, close Monday.**

## Locked-in stub briefs (needs groom before execute)

- **TKT-0319 (CRITICAL):** TQP Phase 3 — Global Agent Auto-Resume Protocol. Stub brief. Brief should be expanded before committing to specific Forge work.
- **TKT-0324 (medium):** TQP Integration + Rollout Test for 2-Pass Dispatch. Stub brief. Brief should be expanded before committing to specific Forge work.
- **TKT-0340 (Critical, done):** P2 Constraint Hardening. Real work shipped. The long-ID stub (TKT-0340 with full title) is the L-077 stub-victim variant. The actual work TKT-0340 is closed. **Housekeeping only — clear the stub from active sprint view.**

## Risk callouts

1. **Capacity overcommit:** 9 items vs 5 capacity. 4 are hygiene syncs (XS, done in 1 turn). 1 is in-progress review (likely closes Mon). 1 is S-effort real work. 2 are stub briefs that may not ship if not groomed.
2. **db-ticket.sh update bug:** The script silently drops status changes when both metadata + status are in the same payload. Workaround: direct PG UPDATE. Worth a TKT.
3. **TKT-0319 (CRITICAL) has stub brief:** The critical-priority work needs grooming to define scope. Without it, this is an "intent to work" not a deliverable.
4. **TKT-0503 24h review window:** 14:00 AEST Telegram ping is scheduled. If issues found, reopens.

## Carry-forward from Sprint 7

- TKT-0410 (state-machine gap, HIGH priority, carry-forward approved by Yoda 15:22 AEST retro)

## Deferred to Sprint 9 (3 items)

- TKT-0293 (Regression Testing Framework, stub)
- TKT-0326 (NAS Setup, stub)
- TKT-0394 (Tribal Knowledge Audit QBR 2026-Q3, stub)
- TKT-0504 (already closed in Sprint 9 — TQP executor bridge)

## Sprint 9 forecast (per Ken 15:28 AEST)

- 4 stub briefs deferred: TKT-0293, TKT-0326, TKT-0394
- TKT-0221 was also flagged for Sprint 9 by Ken 15:28, but it's hygiene-closed; no action needed
- TKT-0504 already in Sprint 9 (closed)
- 1 TKT-0503 24h review outcome may add to Sprint 9 (if issues found)

