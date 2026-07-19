# CHG-0930 CREST Plan — Change Pre-Compaction Memory Flush Target Path

## Change Record
- **CHG-0930** — Change pre-compaction memory flush target path.
- Notion Archive DB C page: `3a2890b6-ece8-8153-a2d7-fa845367455a`
- Trigger: CHG-0929 hardlinked per-agent `memory/` directories; OpenClaw sandbox now blocks writes to `memory/YYYY-MM-DD.md` with `path alias escape blocked`.

## Current State
- Pre-compaction memory flush now writes to `state/memory-flush/YYYY-MM-DD.md`.
- `memory/YYYY-MM-DD.md` is no longer used for new flushes.
- Existing `memory/YYYY-MM-DD.md` files remain intact for reference.
- Journal entries remain functional and durable.

## Root Cause
- CHG-0929 used hardlinks to share memory across per-agent workspaces.
- The flush target (`memory/YYYY-MM-DD.md`) lived inside the shared/hardlinked directory.
- The OpenClaw sandbox forbade writes to paths that resolved to multiple workspace aliases.

## C — Classify
- **Risk:** Low-medium. Read-only memory recall is preserved; only the flush destination changes.
- **Blast radius:** Main session pre-compaction memory flushes.
- **Type:** config / runtime behavior.

## R — Root-cause summary
The flush target was inside a hardlinked directory, so the sandbox blocked writes.

## E — Execute (Forge) ✅ COMPLETE
- **Runtime file:** `/Users/ainchorsoc2a/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js`
- **Function:** `buildMemoryFlushPlan` (line 77)
- **Change:** `memory/${dateStamp}.md` → `state/memory-flush/${dateStamp}.md` (3 lines + comments)
- **Config vs patch:** Runtime patch required; no config option exists to override the path.
- **Syntax validation:** `node --check` OK.
- **Backup:** `.chg-0930-backup/extensions-memory-core-index.js.orig`

### Test results (pre-restart)
- New path (`state/memory-flush/2026-07-19.md`): accepted by sandbox.
- Old path (`memory/2026-07-19.md`): rejected with `path alias escape blocked`.
- `openclaw memory status --index`: all 15 agents healthy.
- `memory_search --agent business "CHG-0929 hardlink"`: returned results; recall unaffected.

## S — Stabilize ✅ COMPLETE
- **Gateway restart executed** at 2026-07-19 14:05 AEST via `launchctl kickstart -k gui/501/ai.openclaw.gateway`.
- Post-restart `launchctl list`: `43886 0 ai.openclaw.gateway` — service running.
- Post-restart `openclaw memory status --index`: all 15 agents healthy (`13/13` files, `Dirty: no`).
- Post-restart write test to `state/memory-flush/2026-07-19.md`: succeeded.
- Memory recall remained functional across all agents.

### Known limitation (accepted)
- Flushed content in `state/memory-flush/` is **not auto-indexed** by `memory_search`. The indexer only walks `memory/`, `MEMORY.md`, `DREAMS.md`, and configured `extraPaths`. This matches Option B's stated goal: redirect flush, leave recall alone. Adding searchability would be a follow-up CHG.

## T — Transfer / Close
- Update `memory/CHANGELOG.md` CHG-0930 entry with completion evidence.
- Close CHG-0930 in Notion Archive DB C with links to this plan and status output.
- Journal entry per Journal Discipline.

## Verification Criteria
1. ✅ Pre-compaction memory flush can append to the new target path without `path alias escape blocked` errors.
2. ✅ All 15 agents still show healthy memory indexes.
3. ✅ `memory_search` still returns results for non-core agents.
4. ✅ No data loss in existing `memory/2026-07-19.md` or earlier daily memory files.

## Scope Boundary
- This change only affects where the pre-compaction flush writes.
- It does not change the shared memory corpus or CHG-0929 hardlinks.
- It does not change agent config files or `openclaw.json` unless required for the new path.

## Status
- **Implementation:** COMPLETE ✅
- **Gateway restart:** COMPLETE ✅
- **Final verification:** COMPLETE ✅
- **Notion/CHANGELOG closure:** Pending or already completed by Forge; verify separately.
