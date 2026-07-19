# CHG-0936 CREST Plan — Index state/memory-flush for memory_search

## Change Record
- **CHG-0936** — Index `state/memory-flush/` for `memory_search`.
- Notion Archive DB C page: `3a2890b6-ece8-814d-b9e9-e00985796dd0`
- Trigger: CHG-0930 moved the pre-compaction memory flush target to `state/memory-flush/YYYY-MM-DD.md`, but OpenClaw's memory indexer did not walk that directory.

## Current State
- `openclaw.json` now includes `agents.defaults.memorySearch.extraPaths: ["/Users/ainchorsoc2a/.openclaw/workspace/state/memory-flush"]`.
- All 15 agents reindexed and now include the flush directory in their memory indexes.
- Cross-agent search recall verified for the flush corpus.

## Root Cause
- The OpenClaw memory-core indexer has a default set of source directories.
- `state/memory-flush/` was outside those defaults and was not indexed.

## C — Classify
- **Risk:** Low. Adding a read-only memory source; no changes to agent workspace content.
- **Blast radius:** `memory_search` results for all agents (shared memory corpus).
- **Type:** config.

## R — Root-cause summary
The flush target was outside the default memory source paths, so the indexer ignored it.

## E — Execute (Forge) ✅ COMPLETE
- **Approach:** Config change only — added `agents.defaults.memorySearch.extraPaths` in `~/.openclaw/openclaw.json`.
- **Code references:** `dist/memory-search-08jhHZZR.js` `mergeConfig()` and `dist/internal-ss-Qpla0.js` `normalizeExtraMemoryPaths()`.
- **Backup:** `/Users/ainchorsoc2a/.openclaw/workspace/.chg-0936-backup/openclaw.json.before`
- **Reindex:** All 15 agents reindexed successfully (`Memory index updated`).

### Memory status after change
- main: 16 files / 1244 chunks
- business: 14 / 1242
- architect: 14 / 1242
- platform-arch: 15 / 1243
- infra: 14 / 1242
- ahsoka: 15 / 1243
- social: 15 / 1243
- biz-process: 15 / 1243
- change-mgt: 15 / 1243
- security: 14 / 1242
- legal: 15 / 1243
- qa: 15 / 1243
- governance: 15 / 1243
- luthen: 15 / 1243
- foodie: 15 / 1243

### Search verification
- Sentinel `phosphor-rotary-tessellate-quokka-ziggurat` appended to `state/memory-flush/2026-07-19.md`.
- HIT returned for main, business, security, architect, and infra agents (score ~0.661).
- Pre-existing `memory/` recall verified — `CHG-0930` query still returns `memory/journal-2026-07-19.md` with score ~0.69.

## S — Stabilize ✅ COMPLETE
- No gateway restart required. OpenClaw CLI re-reads `openclaw.json` on each invocation; in-process gateway search instances are recreated per call and picked up the new config.
- All agents show `Dirty: no` and `extraPaths` populated.

## T — Transfer / Close
- Forge appended CHG-0936 completion entry to `memory/CHANGELOG.md`.
- Journal entry written per Journal Discipline.
- Close CHG-0936 in Notion Archive DB C with this plan and the subagent report.

## Verification Criteria
1. ✅ `memory_search --agent main "phrase from today's state/memory-flush file"` returns results.
2. ✅ The indexer status shows `state/memory-flush/` files are embedded (chunk counts increased).
3. ✅ All agents still show healthy memory indexes.
4. ✅ Existing `memory/` recall remains functional.

## Scope Boundary
- This change only adds an extra memory source.
- It does not alter where flushes are written (CHG-0930).
- It does not change the per-agent memory sharing mechanism (CHG-0929).

## Status
- **Implementation:** COMPLETE ✅
- **Verification:** COMPLETE ✅
- **Gateway restart:** NOT REQUIRED ✅
