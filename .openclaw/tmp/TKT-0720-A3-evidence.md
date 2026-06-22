# TKT-0720 A3 — Shared link helper + markdown backfill parser

**Executed by:** Forge (infra subagent)  
**Date:** 2026-06-22 20:07 AEST  
**Database:** `ainchors_nexus`

---

## D1 — `scripts/db-link.sh`

Created reusable bash library with 3 functions:

### `insert_entity_links(from_type, from_id, link_type, source, ...to_pairs)`
- Inserts edges into `entity_links` via batch SQL with `ON CONFLICT DO NOTHING`
- Uses `format_link_id(nextval('entity_links_link_id_seq'))` for `LNK-NNNN` IDs
- Emits a single `agent_events` row per batch with `event_type='linked'`
- Returns count of inserted rows

### `parse_linked_line(line_text)`
- Strips markdown formatting (bold, inline links, backticks)
- Normalizes en-dash/em-dash to regular hyphen for range detection
- Handles: `TKT-NNNN`, `CHG-NNNN`, `L-NNN`, `WO-XXX-NNN`, `Sprint N`, `INC-YYYYMMDD-NNN`, `CR-NNN`
- Range expansion: `CHG-0604–CHG-0608`, `CHG-0660-0667`, `TKT-0720-TKT-0726` (20-item cap)
- File paths detected as `file:` type
- Returns 0 if any IDs found, 1 if none

### `resolve_from_entity(file_path, line_number)`
- Scans backward from line_number for nearest preceding `##` or `#` heading
- Extracts first canonical ID from heading
- Returns `type:id` (e.g. `chg:CHG-0719`) or empty string

---

## D2 — `scripts/entity-links-backfill.sh`

Self-contained backfill script:
- Sources `scripts/db-link.sh`
- CLI flags: `--dry-run`, `--commit`, `--source-dir DIR`, `--help`
- Scans `memory/CHANGELOG.md`, `memory/*.md`, `docs/*.md` for `Linked:` lines
- Resolves from-entity via `resolve_from_entity`
- Parses to-entities via `parse_linked_line`
- Stores `source` as `migrated-from-md:<relative-file-path>`
- Link type: `relates-to` for all parsed edges
- Skipped/ambiguous lines logged to `.openclaw/tmp/entity-links-backfill-skipped.log`
- File-type edges tracked separately (excluded from completeness)

---

## D3 — Dry-run and Commit

### Dry-run output (summary):
```
Files scanned:     9
Linked: lines:    702
Edges written:    0 (entity edges)  [dry-run mode]
File edges:       0 (file-type edges, excluded from completeness)
Edges skipped:    285
```

### Commit output (summary):
```
Files scanned:     9
Linked: lines:    702
Edges written:    1433 (entity edges)
File edges:       95 (file-type edges, excluded from completeness)
Edges skipped:    285
```

### Row count after commit:
```
$ SELECT COUNT(*) FROM entity_links;
1528
```

### Sample rows:
```
 id                                   | link_id   | from_type | from_id     | to_type   | to_id              | link_type   | ts                         | source                                                       | tenant_id | payload
--------------------------------------+-----------+-----------+-------------+-----------+--------------------+-------------+----------------------------+-------------------------------------------------------------+-----------+--------
 0773c297-398b-475c-95f9-d640da9feadf | LNK-0017  | chg       | CHG-0470    | ticket    | TKT-0332           | relates-to  | 2026-06-22 20:07:12+10     | migrated-from-md:docs/CHANGELOG.md                          | ainchors  | {}
 71a7f5e3-e8cb-4b16-bd3d-b453a2b2dd56 | LNK-0018  | chg       | CHG-0470    | incident  | INC-20260608-001   | relates-to  | 2026-06-22 20:07:12+10     | migrated-from-md:docs/CHANGELOG.md                          | ainchors  | {}
 a11a9146-c41b-4040-93f8-cd722cf52057 | LNK-0019  | chg       | CHG-0470    | lesson    | L-050              | relates-to  | 2026-06-22 20:07:12+10     | migrated-from-md:docs/CHANGELOG.md                          | ainchors  | {}
 4db65989-b24a-45a3-abe7-2b8516f84b17 | LNK-0021  | chg       | CHG-0466    | ticket    | TKT-0333           | relates-to  | 2026-06-22 20:07:12+10     | migrated-from-md:docs/CHANGELOG.md                          | ainchors  | {}
 025dd7e1-ed2a-40dd-a955-bc528ca696ef | LNK-0023  | ticket    | TKT-0184    | ticket    | TKT-0160           | relates-to  | 2026-06-22 20:07:12+10     | migrated-from-md:docs/TKT-0184-Option-D-Investigation.md   | ainchors  | {}
 a21b05ec-9c1b-4064-8df3-d3849fe0391b | LNK-0024  | lesson    | L-065       | ticket    | TKT-0395           | relates-to  | 2026-06-22 20:07:12+10     | migrated-from-md:memory/2026-06-10.md                      | ainchors  | {}
 172d85c0-50e8-406b-be2b-a051dd41a0b9 | LNK-0025  | lesson    | L-065       | wo        | WO-002             | relates-to  | 2026-06-22 20:07:12+10     | migrated-from-md:memory/2026-06-10.md                      | ainchors  | {}
```

### Skipped log summary:
- 7 lines skipped due to no from-entity (no preceding heading with canonical ID)
- 278 lines skipped due to no to-pairs (mostly `**Linked:** none` or prose like `Sprint 9 planning`)
- Total: 285 skipped lines

---

## D5 — Rollback awareness

`infra/rollback/TKT-0720-rollback.sql` drops `entity_links` table and sequence. Not modified by this atom. Backfilled edges will be lost on rollback; can be reconstructed by re-running `--commit`.

---

## Verification Summary

| Check | Status |
|---|---|
| `scripts/db-link.sh` created with 3 functions | ✅ |
| `scripts/entity-links-backfill.sh` created with CLI flags | ✅ |
| Dry-run produces correct output (no DB writes) | ✅ |
| Commit writes 1,433 entity edges + 95 file edges | ✅ |
| Row count after commit: 1,528 | ✅ |
| Sample query returns expected data | ✅ |
| Skipped log correctly captures ambiguous lines | ✅ |
| No existing scripts modified | ✅ |
