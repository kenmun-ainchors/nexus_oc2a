# TKT-OLD-CODE-AUDIT — Master Spec (3 sub-TKTs)
**Filed:** 2026-06-15 17:18 AEST | **Author:** Yoda 🟢 | **Approved by:** Ken Mun (CTO)
**Trigger:** L-138 (today) — subagent-trap exposed that L-126/L-131/L-132/L-137 anti-regression checkers were 4 separate incidents, all same shape, all in auto-heal.sh. Defense-in-depth stack grew organically, never had a systematic audit. **Result: gaps slipped through.**
**Linked:** L-138, L-137, L-132, L-131, L-126, L-122, L-113, L-139, CHG-0586, CHG-0590

## Why split into 3 sub-TKTs (one per sprint)
- **Ship partial value**: each sub-TKT closes 1 sprint of work, delivers verified audit + fixes
- **Manageable scope**: 4-5 scripts per sub-TKT, audit + fix + test = 1 sprint effort
- **Independent rollback**: if Sprint 8 audit finds something that needs to wait, Sprint 9/10 not blocked
- **Audit pattern lock-in**: each sub-TKT uses L-139 (Yoda-authored test corpus) from day 1

## Sub-TKTs (in order)

### 1. TKT-OLD-AUDIT-P0 — High-risk live code (Sprint 8)
**Scope (5 scripts):**
- `scripts/auto-heal.sh` (CHECKs 1-37 + 28a-h) — the file L-138 cracked open
- `scripts/state-health-assert.sh` (215 lines) — L-120 EOD gate
- `scripts/ollama-quota-track.sh` (152 lines) — L-128 per-cron tracker
- `scripts/cron-migration-advisor.sh` (157 lines) — L-130
- `scripts/check-cooldown-gate.sh` (173 lines) — L-137

**DoD (3 ACs):**
- AC1: Per-script static analysis report in `state/audit-tickets/P0-static-<script>.json` with findings classified HIGH/MEDIUM/LOW
- AC2: Per-script functional test (input → expected output, plus failure modes) — all tests pass with evidence in `state/audit-tickets/P0-functional-<script>.log`
- AC3: End-to-end dry-run of each script in isolation — clean exit, no warnings. Audit report at `state/audit-tickets/P0-final-report.md`

**Why P0:** These are the scripts that already had multiple L- lessons in the last 2 weeks. The L-138 lesson proves there's more in this surface. Audit immediately, before adding any new code that depends on them.

### 2. TKT-OLD-AUDIT-P1 — Infrastructure layer (Sprint 9)
**Scope (4 scripts):**
- `scripts/hooks/pre-commit` (L-129 bash -n hook)
- `scripts/file-size-guard.sh` (L-133 thresholds)
- `scripts/safe-path.sh` (L-134 tilde path enforcement)
- `scripts/long-id-stub-check.sh` (L-085 detector)

**DoD (same 3 ACs, output to `state/audit-tickets/P1-...`)**

**Why P1:** These are defense-in-depth checkers. If they have gaps (L-138 had a regex gap), they fail silently and the protection disappears. Audit before next sprint builds on them.

### 3. TKT-OLD-AUDIT-P2 — State DB CRUD + crons (Sprint 10)
**Scope (4 scripts):**
- `scripts/db-ticket.sh` (L-088 + L-115 metadata merge)
- `scripts/db-sprint.sh` (sprint planning + commit)
- `scripts/journal-cron.sh` (L-0296 journal appender)
- `scripts/pg-to-notion-sync.sh` (L-0408 + TKT-0525)

**DoD (same 3 ACs, output to `state/audit-tickets/P2-...`)**

**Why P2:** Lower risk (each call is short, errors get caught by user). But these are the foundation for the audit output. Audit last, after P0+P1 fix any patterns.

## Audit methodology (consistent across all 3 sub-TKTs)

**Phase 1: Static analysis** (Yoda)
- Read full source, comment trail, CHG records
- Run existing static checkers (L-129 pre-commit, L-132 null-safe, L-137 cooldown-gate, L-138 pipefail-trap)
- Classify findings: HIGH (crash/loss-of-data), MEDIUM (incorrect output), LOW (style/perf)

**Phase 2: Per-script functional test** (Yoda + L-139 test corpus)
- Yoda authors the test corpus BEFORE running (L-139 rule)
- For each script: happy path + 3-5 edge cases + 2-3 negative cases
- Use SCRIPTS_TO_SCAN or equivalent override env vars where supported
- All test inputs go to `state/audit-tickets/<P>-test-corpus-<script>/`

**Phase 3: End-to-end integration** (Yoda)
- Run each script in isolation against realistic state files
- Verify outputs match expected (L-113 evidence-only)
- Cross-check state files before/after for unexpected mutations

**Phase 4: Fix any findings** (Yoda + subagent with verifier corpus)
- Any HIGH/MEDIUM finding → fix or document deferred-to-future
- LOW findings → batched fix or document
- Subagent dispatches include `verifier_corpus` field (L-139 rule)
- Yoda re-runs the entire audit after fixes (regression check)

**Phase 5: Final report + CHG** (Yoda)
- `state/audit-tickets/<P>-final-report.md` with findings + fixes + tests
- CHG entry per sub-TKT
- Commits with full evidence

## Success criteria
- **3/3 sub-TKTs closed with status=closed** in PG
- **All HIGH findings fixed** with tests proving the fix
- **All MEDIUM findings either fixed or explicitly deferred with rationale**
- **No regressions**: any script that worked before the audit still works after
- **Test corpora preserved** in `state/audit-tickets/` for future regression runs
- **L-139 pattern validated**: at least 1 fix in each sub-TKT used Yoda-authored test corpus + subagent execution + L-113 verify

## Out of scope (separate TKTs)
- `scripts/dispatch-validate.sh` (already audited via L-139 today)
- `scripts/auto-heal-debug.sh` (debug tool, not prod path)
- `scripts/cron-timeout-apply.sh` (L-135 just shipped, audited as part of TKT-0339)
- `scripts/llm-eval-*.sh` (eval infra, separate audit)

## Estimated effort
- Each sub-TKT: 1 sprint (5-7 working days of Yoda-side work, including audit + fix + verify)
- Total: 3 sprints (15-21 days)
- Sprint 8: 2026-06-15 to 2026-06-21
- Sprint 9: 2026-06-22 to 2026-06-28
- Sprint 10: 2026-06-29 to 2026-07-05

## Rollback strategy
- Per sub-TKT: revert commits if audit finds no value-add (e.g., 0 findings, all defensive)
- Master rollback: no global flag, each sub-TKT independent
- No production modifications during audit (read-only where possible)
