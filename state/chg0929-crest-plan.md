# CHG-0929 CREST Plan — Shared Per-Agent Memory

## Change Record
- **CHG-0929** — Shared per-agent memory via symlink to main workspace memory.
- Notion Archive DB C page: `3a2890b6-ece8-81fe-b0a0-f8182264029e`
- Trigger: Memory recall degraded for 12 non-core agents; `memory_search` returned "No matches" because per-agent `workspace/<agent>/memory` directories did not exist.

## Current State
- 12 non-core agents have empty memory indexes (`Indexed: 0/0 files · 0 chunks`).
- `openclaw memory status --index` reports `Memory index failed: no such table: memory_index_chunks_vec` for these agents.
- Main/infra/foodie share the main `~/.openclaw/workspace/memory` and are healthy (`13/13 files · 1219 chunks`).

## Root Cause
- `openclaw.json` assigns each agent a dedicated workspace (e.g., `workspace-business`, `workspace-architect`).
- Those workspace `memory/` directories were never created or seeded.
- `openclaw memory index --force` builds SQLite metadata tables but has no files to embed, so the sqlite-vec semantic table (`memory_index_chunks_vec`) is never created and `memory_search` returns no results.

## C — Classify
- **Risk:** Low. Read-only memory sharing; no runtime code changes.
- **Blast radius:** All 12 non-core agents gain ability to recall global memory corpus.
- **Type:** config / workspace.

## R — Root-cause summary
Per-agent workspaces lack memory directories, leaving their memory indexes empty and disabling semantic recall.

## E — Execute (Forge)
Dispatch `agentId="infra"` with strict instructions:
1. Read `~/.openclaw/openclaw.json` and enumerate all agents whose `workspace` path is NOT `~/.openclaw/workspace`.
2. For each such agent, create a relative symlink `<agent-workspace>/memory -> ../workspace/memory` (or absolute symlink to `/Users/ainchorsoc2a/.openclaw/workspace/memory`). Use relative symlinks where possible to remain portable.
3. Back up any pre-existing `<agent-workspace>/memory` directory by renaming it to `memory.bak.<timestamp>` if it exists (unlikely).
4. Run `openclaw memory index --force --agent <agent>` for each affected agent.
5. Run `openclaw memory status --index` and confirm every agent reports:
   - `Indexed: 13/13 files · 1219 chunks`
   - `Dirty: no`
   - No `Memory index failed` errors.
6. Run spot-check `openclaw memory search --agent <agent> "CREST WS-3"` for at least 3 agents and confirm global results are returned.
7. Do NOT restart the gateway.

## S — Stabilize
- After indexing, verify no agent reverts to `Dirty: yes` on a subsequent status check.
- No operational services depend on immediate change; memory recall is opportunistic.

## T — Transfer / Close
- Update `memory/CHANGELOG.md` CHG-0929 entry with completion evidence.
- Close CHG-0929 in Notion Archive DB C with links to this plan and status output.
- Journal entry per Journal Discipline.

## Verification Criteria
1. `openclaw memory status --index` shows all agents healthy.
2. `memory_search --agent business "CREST WS-3"` (and other spot-checks) returns results from global memory.
3. No agent shows 0/0 chunks or missing vec table errors.

## Rollback
- Remove the symlinks.
- Re-create empty `<agent-workspace>/memory` directories.
- Run `openclaw memory index --force --agent <agent>` for each to revert to 0/0 empty state.

## Scope Boundary
- This change only affects agent memory directories. It does not change agent workspace config files (SOUL.md, AGENTS.md, etc.) or `openclaw.json`.

## Status / Completion
- **Completed:** 2026-07-19 12:28 AEST
- **Verdict:** PASS ✅
- **Implementation deviation:** The planned relative-symlink approach did **not** work because OpenClaw 2026.7.1's memory walker (`dist/internal-D09mvLLj.js`) explicitly skips symbolic links. Forge reverted symlinks and used real per-agent `memory/` directories with hardlinks to main workspace files instead.
- **Result:** All 15 agents report `Indexed: 13/13 files · 1226 chunks · Dirty: no`; memory search returns global results for all spot-checked agents.
- **Evidence:** `state/chg0929-evidence/` (index.log, status.log, status-final.log)
- **Gateway:** Not restarted.
- **Main memory:** Untouched; hardlinks share inodes.
- **Follow-up CHGs identified:**
  1. Periodic re-hardlink job to propagate new main-memory files to per-agent dirs.
  2. Upstream OpenClaw patch or `memoryPath` config to allow symlinks/shared memory paths.
- **Notion:** CHG-0929 page marked Done.
