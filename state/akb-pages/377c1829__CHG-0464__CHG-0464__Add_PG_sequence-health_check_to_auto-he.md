# [CHG-0464] CHG-0464: Add PG sequence-health check to auto-heal (CHECK #17, TKT-0367)

- **Notion ID:** `377c182953ff819bbc82d4e10c0996ab`
- **Status:** Done
- **Type:** CHG
- **Priority:** 
- **Category:** 
- **Sprint:** 
- **Created:** 2026-06-07
- **Last Edited:** 2026-06-06T22:01:00.000Z

## Notes

Type: script | Source: auto-heal | Trigger: CHG-0463: PG write failure traced to sequence desync. TKT-0367 raised for permanent prevention. | Changed: Added CHECK 17 to auto-heal.sh: validates last_value vs MAX(id) for all 12 state table sequences. Auto-fixes by calling setval() when drift detected. Inserted between CHECK 16 (bootstrap_size) and final report write. | Why: Silent PG write failures went undetected for 2 days. ON CONFLICT (run_date) doesn't protect against identity-column collisions. Sequence-health check catches and auto-fixes drift before next INSERT fails. | Verified: Test run confirmed: all 12 sequences show OK, check passes cleanly in ~1s. No false positives. AUTO_FIXED array captures any fixed drift for reporting. | Rollback: N/A
