# [CHG-0458] Auto-Heal: Fix JSON Report Truncation + CHECK 15 Per-File Limits + Delegated Auth Pre-flight (TKT-0336)

- **Notion ID:** `375c182953ff8134ba74fc9580e008d3`
- **Status:** Done
- **Type:** CHG
- **Priority:** 
- **Category:** 
- **Sprint:** 
- **Created:** 2026-06-04
- **Last Edited:** 2026-06-04T00:50:00.000Z

## Notes

Type: script | Source: manual | Trigger: Blog reported 2nd Angie gog auth expiry in two weeks. Auto-heal also reported as quiet in standup. Root cause: CHECK 14/15/16 ran after write_state, never appeared in JSON. CHECK 15 had blanket 10K limit instead of per-file limits. No delegated auth token check existed. | Changed: (1) Moved CHECK 14/15/16 before FINAL REPORT. (2) Per-file hard limits: SOUL=10K, AGENTS=12K, MEMORY=15K, HEARTBEAT=15K. RULES.md excluded. (3) New check-delegated-auth.sh — pre-flight gog auth check for kenmun + angie.foong accounts. (4) Integrated into auto-heal CHECK 1a. (5) Integrated into Yoda→Aria context sync (23:00). (6) Added HEARTBEAT.md 4-hour delegated auth check. | Why: Proactive detection beats reactive queuing. Angie hit auth failure twice — the fix isn't re-auth, it's pre-flight detection before she encounters the failure. | Verified: zsh -n clean on both scripts. Dry-run confirms correct per-file limits. Delegated auth check writes delegated-auth-status.json with account-level status. | Rollback: N/A
