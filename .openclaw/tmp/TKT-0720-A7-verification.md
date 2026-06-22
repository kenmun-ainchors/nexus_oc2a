# TKT-0720 A7 — End-to-end Verification

**Date:** 2026-06-22 20:27 AEST  
**Verifier:** Yoda (orchestrator)  
**Database:** ainchors_nexus

## 1. Schema Contract
                           Table "public.entity_links"
  Column   |           Type           | Collation | Nullable |      Default       
-----------+--------------------------+-----------+----------+--------------------
 id        | uuid                     |           | not null | gen_random_uuid()
 link_id   | text                     |           | not null | 
 from_type | text                     |           | not null | 
 from_id   | text                     |           | not null | 
 to_type   | text                     |           | not null | 
 to_id     | text                     |           | not null | 
 link_type | text                     |           | not null | 'relates-to'::text
 ts        | timestamp with time zone |           | not null | now()
 source    | text                     |           | not null | 
 tenant_id | text                     |           | not null | 'ainchors'::text
 payload   | jsonb                    |           |          | '{}'::jsonb
Indexes:
    "entity_links_pkey" PRIMARY KEY, btree (id)
    "entity_links_link_id_key" UNIQUE CONSTRAINT, btree (link_id)
    "entity_links_upsert_key" UNIQUE CONSTRAINT, btree (from_type, from_id, to_type, to_id, link_type, source)
    "idx_entity_links_from" btree (from_type, from_id)
    "idx_entity_links_link_type" btree (link_type)
    "idx_entity_links_pair" btree (from_type, from_id, to_type, to_id)
    "idx_entity_links_to" btree (to_type, to_id)


## 2. Indexes
entity_links_link_id_key
entity_links_pkey
entity_links_upsert_key
idx_entity_links_from
idx_entity_links_link_type
idx_entity_links_pair
idx_entity_links_to

## 3. Row Counts
Total entity_links rows: 1599
Entity edges (excluding file): 1504
File edges: 95

## 4. Completeness
A5 audit: 1,504 entity edges captured; ≤31 missed discoverable edges; completeness ≥97.99%.

## 5. Live-write Hook Artifacts
Test ticket TKT-9991 edges:
LNK-1556|ticket|TKT-9991|ticket|TKT-0546|live-write:db-ticket:create-from-json
LNK-1557|ticket|TKT-9991|chg|CHG-0719|live-write:db-ticket:create-from-json
LNK-1558|ticket|TKT-9991|ticket|TKT-0720|live-write:db-ticket:update
LNK-1559|ticket|TKT-9991|chg|CHG-0604|live-write:db-ticket:update
LNK-1560|ticket|TKT-9991|lesson|L-065|live-write:db-ticket:update
LNK-1561|ticket|TKT-9991|ticket|TKT-0546|live-write:db-ticket:update
LNK-1562|ticket|TKT-9991|chg|CHG-0719|live-write:db-ticket:update

Test CHG-0731 edges:
LNK-1594|chg|CHG-0731|ticket|TKT-0720|live-write:changelog-append
LNK-1595|chg|CHG-0731|ticket|TKT-9991|live-write:changelog-append
LNK-1596|chg|CHG-0731|chg|CHG-0719|live-write:changelog-append
LNK-1636|chg|CHG-0731|ticket|TKT-0720|migrated-from-md:memory/CHANGELOG.md
LNK-1637|chg|CHG-0731|ticket|TKT-9991|migrated-from-md:memory/CHANGELOG.md
LNK-1638|chg|CHG-0731|chg|CHG-0719|migrated-from-md:memory/CHANGELOG.md

Latest linked agent_events:
EVT-519|linked|chg|CHG-0720|2026-06-22 20:22:54.997378+10
EVT-518|linked|chg|CHG-0721|2026-06-22 20:22:54.879109+10
EVT-517|linked|chg|CHG-0722|2026-06-22 20:22:54.760812+10
EVT-516|linked|chg|CHG-0723|2026-06-22 20:22:54.642603+10
EVT-515|linked|chg|CHG-0724|2026-06-22 20:22:54.523683+10

## 6. Multi-hop Query
Query: TKT-0546 ← CHGs → tickets
Second-hop tickets reachable: 8

## 7. Safe Rollback Dry-run
BEGIN
DROP TABLE
psql:.openclaw/tmp/TKT-0720-rollback-safe-test.sql:3: NOTICE:  sequence "entity_links_link_id_seq" does not exist, skipping
DROP SEQUENCE
ROLLBACK
Rollback dry-run completed without dropping live table.

## Verdict
All A7 checks pass. TKT-0720 is ready for A8 commit.
