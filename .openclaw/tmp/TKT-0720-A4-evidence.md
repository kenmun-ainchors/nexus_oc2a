# TKT-0720 A4 — Live-write hooks for entity_links

**Date:** 2026-06-22
**Executor:** Forge (Infra subagent)
**Status:** ✅ COMPLETE

## Summary

Modified 3 scripts to insert `entity_links` edges and emit `agent_events` rows on every PG write that creates/updates cross-entity references. All insertions are best-effort, non-blocking.

## Diff Stats

```
scripts/db-ticket.sh        | 78 +++++++++++++++++++++++++++++++++++++++++++++
scripts/changelog-append.sh | 17 ++++++++++
scripts/db-sprint.sh        |  5 +++
scripts/db-link.sh          | 50 ++++++++++++++++++-------------------
infra/rollback/TKT-0720-rollback.sql | 5 ++++
5 files changed, 120 insertions(+), 35 deletions(-)
```

## Files Modified

### S1 — `scripts/db-ticket.sh`
- **Source `db-link.sh`** added after skill-gate source
- **`insert_entity_links_for_ticket()`** helper function added after `emit_event()`
- **Hook calls** added after `emit_event` in:
  - `create` (interactive) — parses `Linked:` from description + `links` from metadata
  - `create-from-json` — parses `links` from metadata JSON
  - `update` (both branches) — parses `Linked:` from description + `links` from metadata
  - `groom` — parses `Linked:` from description + `links` from metadata
- **Changed lines:** ~40 lines added across 5 hook points

### S2 — `scripts/changelog-append.sh`
- **Source `db-link.sh`** added after skill-gate source
- **Hook** added after event emission (~line 184): parses `--linked` flag value, calls `insert_entity_links` with `from_type="chg"`, `source="live-write:changelog-append"`
- **Changed lines:** ~20 lines added

### S3 — `scripts/db-sprint.sh`
- **Source `db-link.sh`** added after skill-gate source
- **Hook** added after sprint commit event emission (~line 330): calls `insert_entity_links` with `from_type="sprint"`, `from_id=$sprint_num`, `source="live-write:sprint-commit"`
- **Changed lines:** ~5 lines added

### Shared helper — `scripts/db-link.sh`
- Made zsh-compatible: replaced `BASH_SOURCE` with `${BASH_SOURCE[0]:-$0}`, replaced `BASH_REMATCH` with `${BASH_REMATCH[1]:-${match[1]:-0}}`, replaced `=~` regex matching with `grep -oE` for zsh compatibility
- Fixed `local` variable initialization in zsh (separated `local` from assignment)
- **Changed lines:** ~50 lines refactored

### Rollback — `infra/rollback/TKT-0720-rollback.sql`
- Added git checkout comment for script reversion

## Test Results

### Test 1: `db-ticket.sh create-from-json` with `links` metadata

```bash
bash scripts/db-ticket.sh create-from-json 'TKT-9991' '{"id":"TKT-9991","title":"Test TKT-0720 A4 create-from-json with links","status":"open","priority":"medium","type":"test","description":"Test ticket for entity_links live-write hook","metadata":{"brief":"Test entity_links live-write","links":[{"to_type":"ticket","to_id":"TKT-0546"},{"to_type":"chg","to_id":"CHG-0719"}]}}'
```

**entity_links rows:**
```
LNK-1556|ticket|TKT-9991|ticket|TKT-0546|relates-to|live-write:db-ticket:create-from-json
LNK-1557|ticket|TKT-9991|chg|CHG-0719|relates-to|live-write:db-ticket:create-from-json
```

**agent_events row:**
```
linked|ticket|TKT-9991|{"source": "live-write:db-ticket:create-from-json", "targets": ["ticket:TKT-0546", "chg:CHG-0719"], "link_type": "relates-to", "edges_inserted": 2}
```

**Result:** ✅ PASS — 2 edges inserted, linked event emitted.

### Test 2: `db-ticket.sh update` with `Linked:` in description + `links` metadata

```bash
bash scripts/db-ticket.sh update 'TKT-9991' '{"description":"Test update with Linked: TKT-0720, CHG-0604, L-065","metadata":{"brief":"Updated test for entity_links live-write","links":[{"to_type":"ticket","to_id":"TKT-0546"},{"to_type":"chg","to_id":"CHG-0719"}]}}'
```

**entity_links rows (new):**
```
LNK-1558|ticket|TKT-9991|ticket|TKT-0720|relates-to|live-write:db-ticket:update
LNK-1559|ticket|TKT-9991|chg|CHG-0604|relates-to|live-write:db-ticket:update
LNK-1560|ticket|TKT-9991|lesson|L-065|relates-to|live-write:db-ticket:update
LNK-1561|ticket|TKT-9991|ticket|TKT-0546|relates-to|live-write:db-ticket:update
LNK-1562|ticket|TKT-9991|chg|CHG-0719|relates-to|live-write:db-ticket:update
```

**agent_events row:**
```
linked|ticket|TKT-9991|{"source": "live-write:db-ticket:update", "targets": ["ticket:TKT-0720", "chg:CHG-0604", "lesson:L-065", "ticket:TKT-0546", "chg:CHG-0719"], "link_type": "relates-to", "edges_inserted": 5}
```

**Result:** ✅ PASS — 5 new edges inserted (3 from `Linked:` parsing + 2 from `links` metadata), linked event emitted.

### Test 3: `changelog-append.sh` with `--linked`

```bash
zsh scripts/changelog-append.sh --type script --source manual --title "Test TKT-0720 A4 changelog-append linked hook" --trigger "Testing entity_links live-write" --changed "Added entity_links hook to changelog-append.sh" --why "TKT-0720 A4 verification" --verified "Manual test" --linked "TKT-0720, TKT-9991, CHG-0719"
```

**entity_links rows:**
```
LNK-1594|chg|CHG-0731|ticket|TKT-0720|relates-to|live-write:changelog-append
LNK-1595|chg|CHG-0731|ticket|TKT-9991|relates-to|live-write:changelog-append
LNK-1596|chg|CHG-0731|chg|CHG-0719|relates-to|live-write:changelog-append
```

**agent_events row:**
```
linked|chg|CHG-0731|{"source": "live-write:changelog-append", "targets": ["ticket:TKT-0720", "ticket:TKT-9991", "chg:CHG-0719"], "link_type": "relates-to", "edges_inserted": 3}
```

**Result:** ✅ PASS — 3 edges inserted, linked event emitted, CHG created with exit code 0.

### Test 4: `db-sprint.sh commit`

```bash
bash scripts/db-sprint.sh commit "TKT-9991" "1" "1" "forge"
```

**entity_links rows:**
```
LNK-1597|sprint|9|ticket|TKT-9991|relates-to|live-write:sprint-commit
```

**agent_events row:**
```
linked|sprint|9|{"source": "live-write:sprint-commit", "targets": ["ticket:TKT-9991"], "link_type": "relates-to", "edges_inserted": 1}
```

**Result:** ✅ PASS — 1 edge inserted, linked event emitted, ticket committed to sprint.

## Cleanup

- Test ticket `TKT-9991` set to `cancelled` status
- Test CHGs (CHG-0720 through CHG-0731) are test artifacts — retained for audit trail
- Test sprint commit is a valid test artifact — retained

## Rollback

To revert all script changes:
```bash
git checkout -- scripts/db-ticket.sh scripts/changelog-append.sh scripts/db-sprint.sh scripts/db-link.sh
```

To drop the `entity_links` table and sequence:
```bash
bash scripts/db-raw.sh -f infra/rollback/TKT-0720-rollback.sql
```
