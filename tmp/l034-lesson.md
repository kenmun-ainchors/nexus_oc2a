## L-034 — JSON structure drift: Always verify actual schema before querying (2026-05-17)
**Lesson:** When querying JSON state files, always inspect the ACTUAL structure first — never assume the schema based on variable names or previous usage. The `kimi-confidence-mapping.json` had data in `tickets` (dict) and `executionOrder` (dict), but the script looked for `mapping` (array) which was empty. This caused a false "data lost" panic.
**Rule:** Before querying any JSON state file: (1) Print all top-level keys, (2) Print sample data from each key, (3) Only then write the query.
**Source:** Sprint 4 planning — assumed `mapping` array held confidence data, but actual data was in `tickets` dictionary. File had 95 assessments all along. CHG-0368/Sprint 4 planning incident.
**Prevention:**
- Created `scripts/lib/json-inspector.py` — quick schema discovery tool
- Added `_schema` field to `kimi-confidence-mapping.json` documenting structure
- Agent scripts must validate schema before querying (assert key exists)
**Impact:** Sprint planning delayed 3 minutes, Ken confidence shaken unnecessarily. Easily avoidable.
