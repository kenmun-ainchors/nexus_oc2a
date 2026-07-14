# CHG-DRAFT — Cron State File Cleanup

**Status:** DRAFT — pending Ken approval  
**Proposed CHG-ID:** CHG-0BBB  
**Date:** 2026-07-14 00:41 AEST  
**Type:** Normal  
**Source:** Full cron health audit  
**Triggered by:** Stale cron state files remaining from pre-migration / deleted crons.

## Current findings
- **Live crons:** 38 jobs, all enabled, all healthy (`scripts/cron-health-check.sh` EXIT=0).
- **No live cron payloads contain** `ainchorsangiefpl`, old Tailscale hostname, or `/opt/homebrew` paths.
- **No duplicate cron names** detected.
- **No erroring live crons** in current state.
- **Stale state files:**
  - `state/cron-list-snapshot.json` — captured 2026-07-10 (pre-migration), contains old `ainchorsangiefpl` paths in cron payloads. Likely used by backup/comparison logic.
  - `state/cron-retry-state.json` — last updated 2026-06-09, contains retry/timeout entries for crons that no longer exist or have been replaced (e.g. `85595417` PG-Notion Integrity Audit, `34880aaa` Memory Dreaming Promotion, etc.).
  - `state/cron-health-alert.json` — acknowledged alert referencing deleted cron `85595417`.
  - Other files: `cron-disabled-34880aaa.json`, `cron-error-triage-2026-07-01.json`, `cron-migration-advisor-last-run.json`, `cron-migration-suggestions.json`, `cron-noop-detect.json`, `cron-timeout-apply-pending.json`, `cron-timeout-baseline.json` — stale from old triage/experiments.

## What changed (proposed)
1. Refresh `state/cron-list-snapshot.json` from current live cron list (`openclaw cron list --json`).
2. Clean `state/cron-retry-state.json` — remove entries for cron IDs that no longer exist in the live cron list; keep entries for live crons if they have meaningful retry state.
3. Clear/archive `state/cron-health-alert.json` (it is acknowledged and references a deleted cron).
4. Review remaining `cron-*.json` state files and move obviously stale/one-off files to `state/cron-archived/`.
5. Do NOT modify any live cron job.

## Verification plan
1. `bash scripts/cron-health-check.sh` → EXIT 0.
2. `openclaw cron list --json | wc -c` approximately matches refreshed snapshot size and contains no old paths.
3. `state/cron-retry-state.json` only contains IDs present in live cron list.
4. `state/cron-health-alert.json` no longer contains unacknowledged deleted-cron entries.

## Rollback
- Restore `state/cron-list-snapshot.json` and other state files from git backup before the edit.
