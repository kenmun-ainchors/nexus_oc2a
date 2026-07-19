# CHG-0935 CREST Plan — Native Symlink or memoryPath Support for Shared Memory

## Change Record
- **CHG-0935** — Upstream OpenClaw symlink or `memoryPath` support for shared memory.
- Notion Archive DB C page: `3a2890b6-ece8-81f6-89da-c05535d827cf`
- Trigger: CHG-0929 required hardlinks because OpenClaw 2026.7.1's memory walker skips symbolic links and no config option exists to share a single memory directory across agents.

## Current State
- Per-agent memory directories are hardlinked to the main workspace memory.
- Hardlinks are static and require periodic re-sync (CHG-0933).
- The OpenClaw memory walker explicitly skips symlinks, so a symlink-based shared memory approach fails today.
- No `memoryPath` or `sharedMemoryDir` config option exists in `openclaw.json` to point all agents at one directory.

## Root Cause
- OpenClaw's memory indexing code treats symlinks as non-traversable (likely to avoid loops or security issues).
- The configuration schema does not allow an agent's memory directory to be overridden to an external shared path.

## C — Classify
- **Risk:** Medium. Runtime code change; affects how all agents resolve and index memory.
- **Blast radius:** All 15 agents and their memory indexes.
- **Type:** config / runtime code.

## R — Root-cause summary
OpenClaw lacks native support for shared memory directories, forcing the hardlink workaround.

## E — Execute (Forge)
Dispatch `agentId="infra"` with instructions:
1. Locate the OpenClaw source code for the memory walker. Likely files:
   - `dist/extensions/memory-core/index.js`
   - `dist/internal-D09mvLLj.js` (mentioned in CHG-0929)
   - Any module that enumerates files in the agent workspace `memory/` directory.
2. Determine the current symlink-skipping behavior:
   - Is it a deliberate `lstat`/`followSymlinks: false` setting?
   - Is there an existing config option that can be enabled?
3. Choose and implement the smallest viable change:
   - **Option A (preferred if safe):** Patch the walker to follow symlinks only for the `memory/` directory (or globally), ensuring symlink loops are still prevented.
   - **Option B:** Add a new `memoryPath` or `sharedMemoryDir` agent config option in `openclaw.json` that overrides the default `workspace/memory/` path. If set, the agent indexes from that path directly.
   - Document why the chosen option is best.
4. If a local patch is not feasible without breaking upstream compatibility, prepare a minimal patch plus an upstream issue/PR description, and fall back to keeping hardlinks (CHG-0929 + CHG-0933) as the operational solution.
5. Validate any patched code with `node --check`.
6. Test on one non-core agent first (e.g., `business` or `architect`):
   - Replace its hardlinked `memory/` with a symlink to `workspace/memory/`.
   - Run `openclaw memory index --force --agent business`.
   - Verify `memory_search --agent business "test query"` returns global results.
   - Verify `openclaw memory status --index` shows healthy.
7. If Option B is chosen, update `openclaw.json` for all non-core agents to use the shared memory path, and reindex.
8. Back up all modified runtime files under `.chg-0935-backup/`.
9. Gateway restart will be required if runtime dist files are patched. Only restart with explicit Ken approval.

## S — Stabilize
- After implementation, verify all 15 agents still have healthy memory indexes.
- If switching from hardlinks to symlinks, ensure the old hardlinked per-agent memory dirs are safely backed up or removed after verification.
- Monitor for any memory walker loops or security warnings.

## Completion Summary
- **Forge subagent:** `agent:infra:subagent:d42fc829-04e9-4c5e-a4ee-b2f91b0a9195`
- **Option chosen:** A — patch memory walker to follow symlinks in per-agent `memory/` directory.
- **File patched:** `dist/internal-ss-Qpla0.js` (function `listMemoryFiles`), ~7 LOC changed.
- **Backup:** `state/.chg-0935-backup/`
- **Validation:** `node --check` passes.
- **Test agent:** `business` first, then all 15 agents.
- **Memory status:** all 15 agents healthy, 14/14 files, 1247 chunks, `Dirty: no`.
- **Symlink probe:** created file in main memory, indexed for business, returned in `memory_search` — PASS.
- **Gateway restart:** REQUIRED (old Node process PID 43886 has cached walker code). CLI already uses new code.
- **Verdict: PASS** (pending gateway restart for full runtime effect).

## S — Stabilize
- After gateway restart, verify all 15 agents still have healthy memory indexes.
- If full symlink migration is confirmed after restart, CHG-0933 re-hardlink cron becomes obsolete and should be disabled as a follow-up.

## T — Transfer / Close
- Update `memory/CHANGELOG.md` CHG-0935 entry with completion evidence.
- Close CHG-0935 in Notion Archive DB C with links to this plan, patch, and test results.
- Document the new symlink-based memory sharing approach.
- Journal entry per Journal Discipline.

## Verification Criteria (all met)
1. ✅ Memory walker follows symlinks to directories in per-agent `memory/`.
2. ✅ At least one non-core agent indexes and searches global memory via symlink.
3. ✅ All 15 agents show healthy memory indexes.
4. ✅ No symlink loops or broken-link errors.

## Scope Boundary
- This change may modify OpenClaw runtime dist files and/or `openclaw.json`.
- It does not change agent workspace content files (SOUL.md, AGENTS.md, etc.).
- If only an upstream PR is possible, the local operational solution remains CHG-0929 + CHG-0933.

## Dependencies
- CHG-0929 (shared memory hardlinks) is the baseline.
- CHG-0933 (re-hardlink job) becomes obsolete if this CHG succeeds in replacing hardlinks with symlinks/shared paths.

---

## 2026-07-19 15:00 MYT — Implementation Complete (Forge)

**Option chosen:** A — patch the walker to follow symlinks for the per-agent `memory/` directory.

**Why Option A over Option B:**
- Smallest viable change. Single file, single function, ~7 LOC of behavioral change.
- Loop prevention is already provided by `walkDirectory` via its `visitedDirs` set keyed by realpath.
- No schema changes, no migration of openclaw.json across 15 agents.
- Backward compatible: real (non-symlink) `memory/` directories still work exactly as before.

**Why not Option C (upstream only):**
- Local change is minimal, low-risk, and immediately useful.
- Upstream PR is still recommended (see "Upstream PR" section below) but does not block the local fix.

**Patch summary:**
- File: `dist/internal-ss-Qpla0.js`
- Function: `listMemoryFiles`
- Change: the `if (!dirStat.isSymbolicLink() && dirStat.isDirectory())` guard is replaced with a lstat-then-stat pattern that follows symlinks into directories. Symlink-to-file is rejected (would return 0 files anyway). Broken symlinks are silently ignored (no change from prior behavior).
- Validation: `node --check` passes. Reindex and search verified across all 15 agents.

**Backup location:** `/Users/ainchorsoc2a/.openclaw/workspace/state/.chg-0935-backup/`
- `internal-ss-Qpla0.js.bak` — pre-patch dist file
- `business-memory-manifest.txt` — listing of per-agent memory dir before symlink swap
- `business-memory-listing.txt` — detailed listing with sizes

**Test results:**
- Single-agent test: `business` reindexed, `Indexed: 15/15 files · 1243 chunks` → after symlink swap → reindex → `Indexed: 14/14 files · 1242 chunks` → after CHANGELOG append → `Indexed: 14/14 files · 1247 chunks`. (Drop is `test-propagation-2026-07-19.md`, a CHG-0933 cron test marker that existed only in the per-agent hardlinked dir. Net chunks went up because main's CHANGELOG.md grew during the patch.)
- All-15 reindex: 15/15 `Indexed: 14/14 files · 1247 chunks · Dirty: no`.
- Search: `openclaw memory search --agent <id> "CREST plan"` returns identical top hit across main, business, architect, ahsoka, luthen.
- End-to-end probe: created `workspace/memory/chg0935-probe.md` with unique phrase, reindexed `business`, search returned the file. PASS.

**Memory status after change:** All 15 agents healthy, 14/14 files, 1247 chunks, no dirty state.

**Gateway restart:** REQUIRED (gateway PID 43886 has the old `internal-ss-Qpla0.js` cached in memory). CLI uses a fresh Node process and works without restart. **Ken approval requested before restarting.**

**Errors/deviations:** None. The drop from 15/15 to 14/14 files in the per-agent index is expected (test-propagation marker was a per-agent hardlink artifact, not real memory content). All agents are now consistent with the single shared main memory corpus.

**Upstream PR (recommended):**
- Title: `feat(memory-core): follow symlinks in per-agent memory/ directory`
- File: `dist/internal-ss-Qpla0.js` (or the upstream source file it was bundled from)
- Change: same 7-LOC change applied here.
- Test: add a unit test that creates a `tmp/memory` symlink and confirms `listMemoryFiles` returns the target's files.
- Reference: `walkDirectory` in `@openclaw/fs-safe` already supports `symlinks: "skip" | "include" | "follow"`; the upstream fix could expose this as a per-agent config option for finer control.

**Final verdict:** PASS.
