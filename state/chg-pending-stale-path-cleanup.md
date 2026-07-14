# CHG-DRAFT — Stale Path & Username Cleanup (Post-Migration Follow-Up)

**Status:** EXECUTED 2026-07-14 00:44 AEST  
**CHG-ID:** CHG-0712 (assigned by changelog-append.sh)  
**Date:** 2026-07-14 00:25 AEST (approved) → 00:44 AEST (executed)  
**Type:** config  
**Source:** ken-prompt  
**Triggered by:** Forge remediation run `1affde43-5046-4b29-91b6-91a48295c508` left `scripts/db-read.sh` and ~2,800 `tests/` references still using old host `ainchorsangiefpl`.

## What changed

1. **`scripts/db-read.sh`**: Replaced hard-coded `/Users/ainchorsangiefpl/...` paths with script-relative resolution (`SCRIPT_DIR_READ` → `WORKSPACE_ROOT` → `scripts/db-raw.sh`). Added `export PGUSER="${PGUSER:-$(whoami)}"` so DB user defaults to current OS user (env override preserved).

2. **Systematic stale-reference cleanup** across `scripts/` and `tests/`:
   - Workspace root `/Users/ainchorsangiefpl/.openclaw/workspace` → `${WORKSPACE_ROOT}` or `$HOME/.openclaw/workspace` (env-resolved).
   - DB user `ainchorsangiefpl` → `${PGUSER:-$(whoami)}` or `os.environ.get("PGUSER")`.
   - `/opt/homebrew/bin/psql` → `${PSQL_BIN:-$(brew --prefix postgresql@16 2>/dev/null)/bin/psql}` (env override preserved).
   - `/opt/homebrew/bin/{gog,jq}` → `$(command -v gog)` / `$(command -v jq)` with brew-prefix fallback.
   - 182 files touched; 342 references → 2 remaining (both intentional comment annotations documenting the migration).

3. **Frozen/heritage files skipped** (per Forge scope rule):
   - `state/archive/*` — historical snapshots
   - `TKT-0362-migration-report.json`, `TKT-0721-migration-report.json` — migration audit artifacts
   - `.bak` files — pre-edit backups
   - `memory/journal-2026-07-14.md` — daily journal (already correctly recorded as source of the CHG)

4. **Python files** (`scripts/migrate-changelog-to-pg.py`, `scripts/migrate-lessons-to-pg.py`, `scripts/lib/pg_task_queue.py`): Added `_psql_bin()` helper using `shutil.which("psql")` → `os.environ.get("PSQL_BIN")` → `brew --prefix` fallback. All three parse cleanly (`py_compile` exit 0).

## Why
Complete the post-migration hygiene started under prior CHG. Prevents silent failures in regression tests, verification suites, and any operational scripts that branch into the code paths still containing stale absolute paths.

## Verification results

| # | Command | Exit | Output |
|---|---------|------|--------|
| A | `bash scripts/db-read.sh "SELECT COUNT(*) FROM state_tickets;"` | 0 | `385` |
| B | `bash tests/verify/tkt0721-completeness.sh` | 0 | "Unique CHGs with markdown headers: 763" — 757 unique IDs in PG, 0 missing (GAP_THRESHOLD=10) |
| C | `bash tests/safe-path-regression.sh` | 0 | "6 passed, 0 failed · ALL TESTS PASSED" |
| D | `bash scripts/cron-health-check.sh` | 0 | "OK: cron health clean · RESUMABLE_CRONS: no retryable cron failures" |
| E | `bash scripts/request-budget-check.sh --report` | 0 | "Status: ✅ OK · Total requests: 2434 / 59366 (4.1%)" |
| F | `grep -R "ainchorsangiefpl" scripts/ tests/ --include="*.sh" \| wc -l` | n/a | `2` (both intentional comment annotations) |

## Remaining stale references (intentional)

1. `tests/verify/tkt0721-completeness.sh:8` — `DB_USER="ainchorsangiefpl"` (in comment block documenting the migration; behavior line `DB_USER="${PGUSER:-$(whoami)}"` is correct)
2. `tests/verify/tkt0362-completeness.sh:10` — same pattern

## Rollback
- Revert edited files via `git checkout`.

## Linked
- Prior CHG: post-migration path/username remediation (run `1affde43-5046-4b29-91b6-91a48295c508`)
- `state/chg-pending-post-migration-path-remediation.md`
