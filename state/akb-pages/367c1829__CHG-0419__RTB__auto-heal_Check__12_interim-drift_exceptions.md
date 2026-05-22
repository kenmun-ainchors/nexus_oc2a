# [CHG-0419] RTB: auto-heal Check #12 interim-drift exceptions + obs-collector error pattern filter

- **Notion ID:** `367c182953ff8175a391d55b35dce963`
- **Status:** Done
- **Type:** CHG
- **Priority:** 
- **Category:** 
- **Sprint:** 
- **Created:** 2026-05-21
- **Last Edited:** 2026-05-21T01:38:00.000Z

## Notes

Type: config | Source: ken-prompt | Trigger: Ken RTB standup 2026-05-21: 🌵 102 error-level logs for expected state (alert fatigue) + 🌱 File CHG for interim-drift exceptions | Changed: 1) obs-collector.sh: added interim-period awareness for fallback chain (skips validation during interim, logs at INFO). 2) auto-heal.sh Check #12: reads interimNote from critical-config-baseline.json; if interim period active, downgrades all config drift from CRITICAL→WARN and suppresses needs-Ken escalation. Drift still logged but not escalated. | Why: Alert fatigue from expected transient errors (gateway startup UNAVAILABLE, Telegram transport blips) + interim config drift flooding needs-Ken with known-expected items. | Verified: Scripts parse correctly. obs-collector.sh now skips fallback chain alerts during interim. auto-heal.sh Check #12 will WARN but not escalate when interimNote is present in baseline. | Rollback: N/A
