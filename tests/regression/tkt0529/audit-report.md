# TKT-0529 — Old-Code Audit Report (A6 Consolidated)

## Executive Summary
Five high-risk live scripts were audited using the verifier corpus at `tests/regression/tkt0529/verifier-corpus.md`. All five scripts predate the current governance model (CREST v1.2+, skill-gate, TQP, verifier-corpus rule). 

| Script | Risk | Lines | Critical/Blocker Findings |
|---|---|---|---|
| `scripts/auto-heal.sh` | **HIGH** | ~1376 | Auto-destructive ops without explicit HITL gate; in-place state overwrites |
| `scripts/state-health-assert.sh` | **MEDIUM** | 176 | Non-atomic writes; hardcoded paths; missing `set -euo pipefail` |
| `scripts/ollama-quota-track.sh` | **MEDIUM** | 128 | Hardcoded paths; non-atomic writes; no `--dry-run`; JSON instead of PG |
| `scripts/cron-migration-advisor.sh` | **MEDIUM** | 140 | Non-atomic JSON writes; no lockfile; no `--dry-run`; missing PG SSOT |
| `scripts/check-cooldown-gate.sh` | **MEDIUM** | 155 | Missing `set -euo pipefail`; hardcoded workspace default; Python exit code not checked |

**No script is P2-ready without remediation.** The single highest risk is `auto-heal.sh`, which can run destructive operations unattended.

## Cross-Cutting Findings

### 1. Hardcoded Absolute Paths (all 5 scripts)
Every script defaults to or references `/Users/ainchorsoc2a/.openclaw/workspace`. This breaks portability across OC1/OC2 and violates the Workspace File Contract.

**Remediation:** Replace with `${WORKSPACE_ROOT}` sourced from a common config or environment. For embedded Python HEREDOCs, pass `${WORKSPACE_ROOT}` via `sys.argv` or `os.environ`.

### 2. Non-Atomic State Writes (4 of 5)
`auto-heal.sh`, `state-health-assert.sh`, `ollama-quota-track.sh`, and `cron-migration-advisor.sh` write state files via direct `cat >` / `open(..., 'w')`. A crash mid-write corrupts state used by crons.

**Remediation:** Adopt a shared atomic-write helper:
```bash
atomic_write() { tmp=$(mktemp "${1}.XXXXXX"); cat > "$tmp" && mv -f "$tmp" "$1"; }
```
For Python, use `tempfile.NamedTemporaryFile` + `os.replace`.

### 3. Missing / Inconsistent Error Handling (3 of 5)
`auto-heal.sh`, `state-health-assert.sh`, and `check-cooldown-gate.sh` do not use `set -euo pipefail` consistently. `auto-heal.sh` and `check-cooldown-gate.sh` do not verify exit codes of subordinate processes.

**Remediation:** Add `set -euo pipefail` to every production script. Check Python/Python HEREDOC exit codes in bash wrappers.

### 4. JSON State Files as De Facto SSOT (3 of 5)
`ollama-quota-track.sh` and `cron-migration-advisor.sh` read/write JSON snapshots under `state/` as their primary data source. PG is canonical for ticket, sprint, cron, and cost state.

**Remediation:** Migrate reads to PG first; keep JSON only as a cache or offline fallback. Document which source is canonical.

### 5. Missing HITL / Dry-Run Gates (3 of 5)
`auto-heal.sh`, `ollama-quota-track.sh`, and `cron-migration-advisor.sh` modify state or execute actions without a `--dry-run` or explicit `--yes` gate.

**Remediation:** Add `--dry-run` to every state-modifying script. Destructive ops require `--yes` or equivalent HITL confirmation.

### 6. Concurrency / Lockfile Gaps (2 of 5)
`auto-heal.sh` and `cron-migration-advisor.sh` run via cron/auto-heal but lack robust lockfiles. Cooldown timestamp is not a lock.

**Remediation:** Use `flock` or a dedicated `.lock` file with trap-based cleanup.

## Per-Script Remediation Plan

### auto-heal.sh — HIGH risk
1. Add `set -euo pipefail` and trap-based cleanup.
2. Introduce `atomic_write` helper; convert every state write.
3. Replace hardcoded paths with `${WORKSPACE_ROOT}`.
4. Add per-check skill-gate calls or route through `run-*` wrappers.
5. Gate destructive operations behind `--yes`; add `--dry-run`.
6. Add lockfile and per-check timeout.
7. Regression test: run in dry-run mode; verify no state changes.

### state-health-assert.sh — MEDIUM risk
1. Add `set -euo pipefail`.
2. Convert `cat >` state writes to atomic writes with backups.
3. Replace hardcoded paths.
4. Regression test: run assertions against known-good/bad state.

### ollama-quota-track.sh — MEDIUM risk
1. Replace hardcoded paths including inside Python block.
2. Implement atomic write for `cron-ollama-usage.json` and last-run file.
3. Add `--dry-run` flag.
4. Migrate primary read from JSON snapshot to PG cron state.
5. Regression test: compare quota output against known cron list.

### cron-migration-advisor.sh — MEDIUM risk
1. Replace hardcoded paths in Python HEREDOC.
2. Use atomic write for `cron-migration-suggestions.json` and cooldown file.
3. Add lockfile (`flock`).
4. Add `--dry-run` flag.
5. Migrate state reads to PG where canonical.
6. Regression test: verify suggestions JSON format stable.

### check-cooldown-gate.sh — MEDIUM risk
1. Add `set -euo pipefail`.
2. Replace hardcoded default workspace path with `${WORKSPACE_ROOT}` or `$HOME` derivation.
3. Check Python HEREDOC exit code before emitting final status.
4. Regression test: run against known cooldown state.

## Risk Matrix

| Finding | Scripts | Risk | Effort | Priority |
|---|---|---|---|---|
| Auto-destructive ops without HITL | auto-heal.sh | CRITICAL | medium | 1 |
| Non-atomic state writes | auto-heal, state-health, quota, migration-advisor | HIGH | low | 2 |
| Hardcoded paths | all 5 | HIGH | low | 3 |
| Missing `set -euo pipefail` | auto-heal, state-health, cooldown-gate | HIGH | low | 4 |
| No `--dry-run` | auto-heal, quota, migration-advisor | MEDIUM | low | 5 |
| JSON as SSOT | quota, migration-advisor | MEDIUM | medium | 6 |
| No lockfile | auto-heal, migration-advisor | MEDIUM | low | 7 |
| Python exit code unchecked | cooldown-gate | LOW | low | 8 |

## Recommended Execution Order (A7)
1. **quick-hygiene bundle**: add `set -euo pipefail` + hardcoded-path fixes to all 5 scripts.
2. **atomic-write bundle**: add atomic write helper and convert state writes.
3. **auto-heal safety bundle**: HITL gate, dry-run, lockfile, skill-gate wiring.
4. **SSOT migration bundle**: move JSON-centric scripts to PG-first reads.
5. **Regression sweep**: run per-script tests + integration check.

## A6 Status
All 5 static analyses complete. Consolidated report authored. Ready to move to A7 (remediation execution) with per-bundle HITL approval.

## Deliverables
- Verifier corpus: `tests/regression/tkt0529/verifier-corpus.md`
- Per-script reports:
  - `.openclaw/tmp/tkt0529_a1_autoheal_report.md`
  - `.openclaw/tmp/tkt0529_a2_statehealth_report.md`
  - `.openclaw/tmp/tkt0529_a3_quota_report.md`
  - `.openclaw/tmp/tkt0529_a4_migration_report.md`
  - `.openclaw/tmp/tkt0529_a5_cooldown_report.md`
- Consolidated report: `tests/regression/tkt0529/audit-report.md`
