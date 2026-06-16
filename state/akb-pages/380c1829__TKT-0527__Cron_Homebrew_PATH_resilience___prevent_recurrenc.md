# [TKT-0527] Cron Homebrew PATH resilience — prevent recurrence of 9ce7f295 + 3c279099 failures

- **Notion ID:** `380c182953ff81beb9d3e13323035e46`
- **Status:** Open
- **Type:** task
- **Priority:** Medium
- **Category:** Technical
- **Sprint:** Sprint 9
- **Created:** 2026-06-15T05:47:00.000+10:00
- **Last Edited:** 2026-06-15T07:54:00.000Z

## Notes

Split from TKT-0332 (Ken msg 4871, scope decision). 2026-06-13 platform shakedown found 2 crons (9ce7f295 TZ Drift Monitor + 3c279099 Morning Stand-Up) failing because Homebrew path was broken — docker CLI symlink missing from /opt/homebrew/bin/. Manual fix was symlink recreation. This ticket adds structural hardening: (1) absolute paths in all cron agentTurn payloads (no $PATH reliance), (2) auto-heal CHECK that validates cron-referenced binaries exist at known absolute paths, (3) launchd PATH environment injection via LaunchAgent plists. Linked: TKT-0332 (parent), 2026-06-13 shakedown.
