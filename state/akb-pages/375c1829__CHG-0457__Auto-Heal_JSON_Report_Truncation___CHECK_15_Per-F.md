# [CHG-0457] Auto-Heal JSON Report Truncation + CHECK 15 Per-File Limits

- **Notion ID:** `375c182953ff81169d64d2ac7c626923`
- **Status:** Done
- **Type:** CHG
- **Priority:** 
- **Category:** 
- **Sprint:** 
- **Created:** 2026-06-04
- **Last Edited:** 2026-06-04T00:45:00.000Z

## Notes

Type: script | Source: manual | Trigger: Standup reported auto-heal quiet. Found CHECK 14/15/16 ran after write_state, never appeared in JSON. CHECK 15 also had blanket 10K hard limit instead of per-file limits from TKT-0310. | Changed: Moved CHECK 14/15/16 before FINAL REPORT. Per-file hard limits: SOUL=10K, AGENTS=12K, MEMORY=15K, HEARTBEAT=15K. RULES.md excluded. Removed duplicate block. | Why: Standup showed 13/16 checks. 4 nightly false positives buried the real AGENTS.md violation. | Verified: zsh -n clean. Dry-run confirms only AGENTS.md flagged. TKT-0336. | Rollback: N/A
