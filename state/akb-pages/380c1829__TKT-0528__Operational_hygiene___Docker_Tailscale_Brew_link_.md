# [TKT-0528] Operational hygiene — Docker/Tailscale Brew link + backup staleness

- **Notion ID:** `380c182953ff81968fd2f7c41de541e4`
- **Status:** Open
- **Type:** task
- **Priority:** Low
- **Category:** Technical
- **Sprint:** Sprint 9
- **Created:** 2026-06-15T05:47:00.000+10:00
- **Last Edited:** 2026-06-15T07:54:00.000Z

## Notes

Split from TKT-0332 (Ken msg 4871, scope decision). 2026-06-13 platform shakedown found 2 hygiene issues: (1) docker + tailscale unlinked from Homebrew (similar to the cron path breakage), (2) backup stale 47h. Both manually fixed. This ticket adds structural prevention: (1) auto-heal CHECK that validates brew link state for required binaries, (2) backup-staleness alert integrated into heartbeat (if backup >24h old, NEEDS_KEN). Low priority — not on Spark critical path.
