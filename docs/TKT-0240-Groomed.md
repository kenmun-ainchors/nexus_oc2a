# TKT-0240 — Sprint 4 Architecture Audit (Groomed)
**Sprint 4 | Owner: Yoda | Effort: 45 min | 4 atoms | Sequential**

## Why This Exists
TKT-0196, 0197, 0198, 0182 were all closed BEFORE the DoD gate was built. They were reported "done" by agents (some by kimi, some by Forge/Atlas) without any platform verification. CHG-0401 proved this pattern is unreliable.

Now that TKT-0237 is complete, these 4 tickets must pass the same verification gate before Sprint 4 can be signed off. Not "assumed done" — observable proof only.

## What It Does
For each of the 4 tickets, run the DoD gate check (`verify_before_close()` from TKT-0237 A1) against their declared deliverables. Each ticket either PASSES (deliverable exists + git committed) or FAILS (missing/broken — needs remediation).

---

## Atom 1 — Verify TKT-0196: Three Work Types Rule
**Effort:** 10 min

| Check | Expected | Method |
|-------|----------|--------|
| Primary deliverable | `docs/Three-Work-Types-Rule.md` exists | `test -f` + `git log -1` |
| RULES.md updated | Contains "Three Work Types" section | `grep "Three Work Types" RULES.md` |
| TKT-0234 raised | Phase 2 Dynamic Escalation ticket exists | `ticket.sh show TKT-0234` returns valid |

**AC:**
- [ ] AC1: `docs/Three-Work-Types-Rule.md` exists and is git committed
- [ ] AC2: RULES.md contains Three Work Types rule reference
- [ ] AC3: TKT-0234 exists with status=open (Phase 2 follow-on)
- [ ] AC4: Run `verify_before_close TKT-0196 task docs/Three-Work-Types-Rule.md` → exits 0

---

## Atom 2 — Verify TKT-0197: Sources of Truth Register
**Effort:** 10 min

| Check | Expected | Method |
|-------|----------|--------|
| Primary deliverable | `docs/Sources-of-Truth-Register.md` exists | `test -f` + `git log -1` |
| 10 domains covered | Document references 10 data domains | `grep -c "Domain:" docs/Sources-of-Truth-Register.md` >= 10 |
| Agent access matrix | Document contains access matrix | `grep "access matrix\|access.*matrix" docs/Sources-of-Truth-Register.md` |

**AC:**
- [ ] AC1: `docs/Sources-of-Truth-Register.md` exists and git committed
- [ ] AC2: Document covers 10+ data domains
- [ ] AC3: Access matrix present
- [ ] AC4: Run `verify_before_close TKT-0197 task docs/Sources-of-Truth-Register.md` → exits 0

---

## Atom 3 — Verify TKT-0198: JSON→Postgres Migration
**Effort:** 15 min

| Check | Expected | Method |
|-------|----------|--------|
| Migration script | `scripts/migrate-state-to-postgres.sh` exists | `test -f` + `git log -1` |
| Postgres tables | 5 tables in `ainchors_nexus` | `psql -c "SELECT tablename FROM pg_tables WHERE schemaname='public'" \| grep -c tablename` |
| Idempotent | Re-run script doesn't fail | Run script with `--dry-run` or check exit 0 |
| Backward compat | `state_v` view exists | `psql -c "SELECT count(*) FROM state_v"` succeeds |
| Backfill script | `scripts/state-migration-backfill.sh` exists | `test -f` |

**AC:**
- [ ] AC1: `scripts/migrate-state-to-postgres.sh` exists and git committed
- [ ] AC2: 5 tables exist in `ainchors_nexus` database
- [ ] AC3: Migration script is idempotent (re-run safe)
- [ ] AC4: Backward-compatible `state_v` view exists
- [ ] AC5: `scripts/state-migration-backfill.sh` exists (complete migration tooling)
- [ ] AC6: Run `verify_before_close TKT-0198 task scripts/migrate-state-to-postgres.sh` → exits 0

---

## Atom 4 — Verify TKT-0182: State Checking Pattern
**Effort:** 10 min

| Check | Expected | Method |
|-------|----------|--------|
| Primary deliverable | `docs/State-Checking-Pattern.md` exists | `test -f` + `git log -1` |
| RULES.md updated | Contains State Checking Pattern section | `grep "STATE CHECKING PATTERN" RULES.md` |
| Pattern applied | Recent ticket actions show READ → VALIDATE → EXECUTE → VERIFY | Check today's TKT-0237 + TKT-0228 execution (closed with verified deliverables) |
| Workspace discipline | File is at workspace root (not forge/) | `test -f docs/State-Checking-Pattern.md` (not `docs/forge/State-Checking-Pattern.md`) |

**AC:**
- [ ] AC1: `docs/State-Checking-Pattern.md` exists and git committed
- [ ] AC2: RULES.md contains State Checking Pattern section at top
- [ ] AC3: Pattern verified applied — TKT-0237 and TKT-0228 both closed with real verified deliverables
- [ ] AC4: File at correct path (workspace root, not subdirectory)
- [ ] AC5: Run `verify_before_close TKT-0182 task docs/State-Checking-Pattern.md` → exits 0

---

## Summary

| Atom | Ticket | Effort | ACs |
|------|--------|--------|-----|
| 1 | TKT-0196 — Three Work Types | 10m | 4 |
| 2 | TKT-0197 — SoT Register | 10m | 4 |
| 3 | TKT-0198 — Postgres Migration | 15m | 6 |
| 4 | TKT-0182 — State Checking Pattern | 10m | 5 |

**Total: 45 min, 19 ACs, 4 atoms, sequential.**

## Dependencies
- TKT-0237 complete ✅ (DoD gate function available)
- TKT-0228 complete ✅ (OWL guard active)

## DoD
- [ ] All 4 tickets pass `verify_before_close()` with exit 0
- [ ] All 19 ACs verified
- [ ] Any FAILED ticket → remediation ticket created, Sprint 4 sign-off deferred for that ticket
- [ ] Sprint 4 sign-off: only tickets that PASS this audit are accepted as Done
