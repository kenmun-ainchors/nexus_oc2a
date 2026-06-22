# TKT-0720 A6 — Multi-hop query demo

**Important note:** Backfilled edges are directed from the document's owning entity (usually a CHG or lesson) to the referenced entity. To traverse from a ticket to its linked CHGs, query where `to_type='ticket' AND to_id=<ticket>`.

**Query:** Starting from `TKT-0546`, find CHGs that link to it, then find tickets linked from those CHGs.

```sql
WITH chgs AS (
  SELECT DISTINCT from_id AS chg_id
  FROM entity_links
  WHERE to_type='ticket' AND to_id='TKT-0546' AND from_type='chg'
),
second_hop AS (
  SELECT DISTINCT e.to_id AS ticket_id
  FROM chgs c
  JOIN entity_links e ON e.from_type='chg' AND e.from_id=c.chg_id
  WHERE e.to_type='ticket'
)
SELECT * FROM second_hop;
```

**Result sample (chg_id | ticket_id):**
CHG-0680|TKT-0382
CHG-0680|TKT-0383
CHG-0680|TKT-0385
CHG-0680|TKT-0387
CHG-0680|TKT-0388
CHG-0680|TKT-0546
CHG-0690|TKT-0546
CHG-0690|TKT-0547
CHG-0708|TKT-0540
CHG-0708|TKT-0546

**CHGs directly linking to TKT-0546:**
3

**Total second-hop tickets reachable:**
8
