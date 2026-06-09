# [CHG-0473] CHG-0473: C1 STALE Definition Drift Corrected — Harness v2.2

- **Notion ID:** `379c182953ff81e98ecbf1624f519522`
- **Status:** Done
- **Type:** CHG
- **Priority:** 
- **Category:** 
- **Sprint:** 
- **Created:** 2026-06-08
- **Last Edited:** 2026-06-08T12:29:00.000Z

## Notes

Type: config | Source: ken-prompt | Trigger: Ken Mun identified: harness STALE was '>7 days no update' (dormancy), but C1 §5 defines STALE as mirror lag > 5 min after live change — different semantics | Changed: divergence-harness.py v2.0→v2.2: STALE now checks mirror updated_at vs live updated_at with 5-min bound. Dormant tickets (>7d) moved to info.dormant_tickets (informational only, not a C1 class). status-map.json v1.0→v1.1: separated plan_map and atom_map. T4-Divergence-Contract v0.1→v1.1: amendment documenting correction. | Why: The old STALE definition conflated ticket dormancy with replication lag. C1's STALE is the metric that proves the mirror keeps up — it must measure replication freshness, not whether upstream data is stale. Without this fix, the mirror could be 6 min behind with zero alert. | Verified: Re-run with v2.2: STALE=0, Match=616, Unexplained=0. Mirror lag check operational. Contract v1.1 published. | Rollback: N/A
