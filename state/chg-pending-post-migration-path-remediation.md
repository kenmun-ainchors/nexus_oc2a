# CHG-DRAFT — Post-Migration Path & Username Remediation

**Status:** DRAFT — pending Ken approval  
**Proposed CHG-ID:** CHG-0XXX (to be assigned by changelog-append.sh after script fix)  
**Date:** 2026-07-14 00:19 AEST  
**Type:** Normal  
**Source:** CREST post-migration shakedown  
**Triggered by:** OC1 migration to user `ainchorsoc2a`; systematic hard-coded paths/usernames from previous host `ainchorsangiefpl`.

## What changed (proposed)
- Fix `scripts/db.sh` and `scripts/db-raw.sh` to resolve `psql` from the active brew prefix (`$(brew --prefix)/bin/psql` with fallback to `which psql`) and default `PGUSER` to the current OS user (`$(whoami)` / `$USER`), preserving env overrides.
- Fix `scripts/gateway-config-snapshot.sh` to resolve workspace root from script location instead of hard-coded `/Users/ainchorsangiefpl/.openclaw/workspace`.
- Fix `scripts/check-delegated-auth.sh` to handle a missing `/opt/homebrew/bin/gog` gracefully and report the missing binary rather than failing opaque.
- Disable OpenClaw cron `a4cc9221-e424-499a-af53-a0f9043ba78e` (PG→JSON Daily Reconcile) — its own description says "DISABLED 2026-06-02" yet it remains enabled and is erroring/timeouting.
- Verify `scripts/skill-load.sh` fix already delivered by Forge (child run 902bda2a) is still working.

## Why
Post-migration regression: every PG-first operation, gateway config snapshot, and several heartbeat checks fail because they assume `/opt/homebrew/bin/psql`, user `ainchorsangiefpl`, and the old home directory. The database is live at `/tmp:5432` with owner `ainchorsoc2a` and psql at `~/homebrew/bin/psql`, so only the script wrappers are wrong.

## Verification plan
1. `bash scripts/db.sh -c "SELECT current_user, current_database();"` returns `ainchorsoc2a|ainchors_nexus`.
2. `bash scripts/db-read.sh state_tickets` and `bash scripts/db-write.sh` smoke test succeed.
3. `bash scripts/gateway-config-snapshot.sh` exits 0 and writes to the correct workspace path.
4. `zsh scripts/check-delegated-auth.sh --json` returns a clear "gog binary missing" or valid result, not exit 2.
5. `openclaw cron get a4cc9221-...` shows `enabled: false` after disable.
6. Re-run heartbeat suite (`bash scripts/cron-health-check.sh`, `bash scripts/request-budget-check.sh --report`) and confirm clean.

## Rollback
- Revert the edited scripts via git.
- For cron disable: re-enable via `openclaw cron update a4cc9221-... '{"enabled":true}'`.

## Linked tickets / skills
- Memory: `MEMORY.md` migration notes.
- Skills: `pg-sprint-backlog`, `changelog`, `crest`.
