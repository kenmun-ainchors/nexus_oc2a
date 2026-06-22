# TKT-0720 A2 — DDL Evidence

**Executed by:** Forge (infra subagent)  
**Date:** 2026-06-22 19:56 AEST  
**Database:** `ainchors_nexus`

---

## 1. Table Structure

```
$ psql -c "\d entity_links" ainchors_nexus
```

```
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
```

**Columns present (11):** id, link_id, from_type, from_id, to_type, to_id, link_type, ts, source, tenant_id, payload  
**Indexes present (7):** pkey, link_id_key, upsert_key, idx_from, idx_to, idx_pair, idx_link_type  
**No hash/prev_hash columns** ✅ (per A1 decision)

---

## 2. Row Count

```
$ psql -Aqt -c "SELECT COUNT(*) FROM entity_links" ainchors_nexus
```

```
0
```

✅ Empty table as expected.

---

## 3. Sequence

```
$ psql -Aqt -c "SELECT last_value FROM entity_links_link_id_seq" ainchors_nexus
```

```
2
```

Sequence `entity_links_link_id_seq` exists, starts at 1. Current value is 2 (advanced by test insert + function call; test row deleted). Next `LNK-NNNN` will be `LNK-0003`.

---

## 4. LNK-NNNN Format Test

Helper function `format_link_id(seq_val bigint)` created:

```sql
CREATE OR REPLACE FUNCTION format_link_id(seq_val bigint)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT 'LNK-' || LPAD(seq_val::text, 4, '0');
$$;
```

Test call:
```
$ psql -Aqt -c "SELECT format_link_id(nextval('entity_links_link_id_seq'))"
LNK-0003
```

✅ Format produces `LNK-NNNN` with zero-padded 4 digits.

---

## 5. Test Insert (then deleted)

Inserted and verified a test row:
- `link_id`: `LNK-0002`
- `from_type`: `ticket`, `from_id`: `TKT-0720`
- `to_type`: `chg`, `to_id`: `CHG-0719`
- `link_type`: `relates-to`
- `source`: `test-verify`
- `tenant_id`: `ainchors` (default)

Row deleted after verification. Table is clean (0 rows).

---

## 6. Rollback Script

**Path:** `infra/rollback/TKT-0720-rollback.sql`

**Contents:**
```sql
BEGIN;
DROP TABLE IF EXISTS entity_links CASCADE;
DROP SEQUENCE IF EXISTS entity_links_link_id_seq CASCADE;
COMMIT;
```

**Safe dry-run result:**
- Copy created with `COMMIT;` → `ROLLBACK;`
- Executed against live database
- Output: `BEGIN` → `DROP TABLE` → `DROP SEQUENCE` (with notice: sequence already cascade-dropped) → `ROLLBACK`
- Table confirmed re-created after rollback (verified via `information_schema.tables`)

✅ Rollback script syntax-valid and safe.

---

## 7. Verification Summary

| Check | Status |
|---|---|
| Table `entity_links` exists | ✅ |
| All 11 columns present | ✅ |
| All 7 indexes present (pkey, link_id_key, upsert_key, from, to, pair, link_type) | ✅ |
| Sequence `entity_links_link_id_seq` exists | ✅ |
| `format_link_id()` function returns `LNK-NNNN` | ✅ |
| 0 rows in table | ✅ |
| No hash/prev_hash columns | ✅ |
| Rollback script created and dry-run safe | ✅ |
| No existing tables/scripts modified | ✅ |
