# CHG-0930 Evidence — Pre-Compaction Memory Flush Path Patch

**CHG-0930** — Change pre-compaction memory flush target path (Option B).
**CREST plan:** `state/chg0930-crest-plan.md`.
**Notion DB C:** `3a2890b6-ece8-8153-a2d7-fa845367455a`.

## What Changed

Runtime file: `/Users/ainchorsoc2a/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js`

- `MEMORY_FLUSH_TARGET_HINT` and `MEMORY_FLUSH_APPEND_ONLY_HINT` updated so the
  model is told to use the new path.
- `buildMemoryFlushPlan` `relativePath` changed from `memory/${dateStamp}.md`
  to `state/memory-flush/${dateStamp}.md`.

The path is hardcoded inside the built-in `memory-core` plugin and is not
exposed via `openclaw.json` (`AgentCompactionMemoryFlushConfig` has no
`relativePath` field). A runtime patch is the only way to change it.

The new path is **inside the main workspace sandbox** and **outside the
hardlinked `memory/` directory**, so the OpenClaw fs-safe sandbox no longer
rejects the append with `path alias escape blocked`.

## Backups

- Original (pre-patch): `workspace/.chg-0930-backup/extensions-memory-core-index.js.orig`
- Patched copy: `workspace/.chg-0930-backup/extensions-memory-core-index.js.patched`
- Smoke tests: `sandbox-smoke-test.mjs`, `plan-smoke-test.mjs`, `sandbox-smoke-test.out.log`

## Gateway Restart

**Required.** The patched code lives in the OpenClaw `dist/` bundle. The
running gateway (PID 16903, started at 09:50 AEST on 2026-07-19) holds the
old code in memory. Restart to load the new `buildMemoryFlushPlan`. The
subagent did **not** restart silently — explicit approval requested via
this evidence file.

## Verification

1. **`node --check`** on the patched file → OK.
2. **Sandbox smoke test** (sandbox-smoke-test.mjs):
   - `state/memory-flush/2026-07-19.md` (new) → `ACCEPTED ✓`
   - `memory/2026-07-19.md` (legacy, nlink=13) → `REJECTED: path alias escape blocked`
3. **Plan resolver test** (plan-smoke-test.mjs): confirms the live
   `buildMemoryFlushPlan` returns `relativePath: state/memory-flush/2026-07-19.md`
   and that both `prompt` and `systemPrompt` reference the new path
   consistently (no stale `memory/...` text).
4. **`openclaw memory status`** → 13/13 files indexed per agent, `Dirty: no`
   (no impact on the memory corpus).
5. **`openclaw memory search --agent business "CHG-0929 hardlink"`** → returns
   matching chunks from the existing `memory/` corpus. Recall unchanged.

## Impact on Memory Search

`state/memory-flush/` is **not** in the indexer's `extraPaths` and is not
matched by the `isMemoryPath` helper. Flushed content is **not**
auto-indexed by `memory_search`. The `memory/` corpus (and hardlinks) is
preserved and continues to be the search target. This is consistent with
Option B's stated goal: redirect the flush, leave recall alone.

## Test Hooks Removed

The temporary `export { buildMemoryFlushPlan as _chg0930_test }` hook used
to import the live function for the plan smoke test was removed. The
patched file matches the `.patched` copy in the backup directory.

## Out of Scope (intentionally not done by this subagent)

- Notion Archive DB C page close-out (will be done by the orchestrator).
- `CHANGELOG.md` CHG-0930 entry append (will be done by the orchestrator).
- Gateway restart (requires explicit Ken approval; reported, not performed).
- `journal-2026-07-19.md` entry (will be done by Yoda from main session).
