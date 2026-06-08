# [CHG-0461] CHG-0462: Config baseline refresh — 7 days stale

- **Notion ID:** `377c182953ff81efbc29de04aaefcd84`
- **Status:** Done
- **Type:** CHG
- **Priority:** 
- **Category:** 
- **Sprint:** 
- **Created:** 2026-06-07
- **Last Edited:** 2026-06-06T21:56:00.000Z

## Notes

Type: config | Source: auto-heal | Trigger: Auto-heal CHECK #12 — baseline 8 days old | Changed: Refreshed critical-config-baseline.json + PG state_config_baseline to current state. 14 agents, 59 crons, 32 PG tables verified. All agent model assignments unchanged from CHG-0416 interim config. | Why: Drift detection relies on <=7 day baseline freshness. 8 days = unreliable alerts. | Verified: PG write confirmed (UPDATE 1). JSON fallback updated. All checks validated against live agent configs. | Rollback: N/A
