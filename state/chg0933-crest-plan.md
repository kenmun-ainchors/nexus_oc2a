# CHG-0933 CREST Plan — Periodic Re-Hardlink Job for Per-Agent Memory

## Change Record
- **CHG-0933** — Periodic re-hardlink job for per-agent memory directories.
- Notion Archive DB C page: `3a2890b6-ece8-811a-9b1b-ca846a7d003f`
- Trigger: CHG-0929 used hardlinks to share main workspace memory across per-agent workspaces, but new files added to main memory do not automatically propagate.

## Current State
- 15 agents share the same 13 memory files via hardlinks.
- If a new file is added to `workspace/memory/`, it will not appear in per-agent `workspace-<agent>/memory/` until manually re-hardlinked.
- Over time, per-agent memory indexes will drift and lose access to new durable context.

## Root Cause
- Hardlinking is a one-time copy of existing files. It does not provide a live shared directory.
- No periodic sync job exists to propagate new main-memory files to per-agent directories.

## C — Classify
- **Risk:** Low. Idempotent file linking; no runtime code changes.
- **Blast radius:** All per-agent memory directories and their indexes.
- **Type:** cron / script.

## R — Root-cause summary
CHG-0929 hardlinks are static; new main-memory files need a periodic re-sync job.

## E — Execute (Forge)
Dispatch `agentId="infra"` with instructions:
1. Create a script at `scripts/sync-agent-memory.sh` that:
   - Reads `/Users/ainchorsoc2a/.openclaw/openclaw.json` to enumerate all agents whose `workspace` is not the main workspace.
   - Scans `workspace/memory/` for all files and directories (excluding `.dreams/` unless explicitly desired).
   - For each file, ensures the same inode exists in each per-agent `workspace-<agent>/memory/` via `ln <source> <target>`.
   - Skips files already correctly hardlinked (same inode).
   - Removes stale hardlinks in per-agent dirs that no longer exist in main memory (optional, but keep for now to avoid data loss).
   - Logs actions and errors.
2. Make the script executable and idempotent.
3. Add a cron job (e.g., every 4 hours or daily) to run the script.
   - Use `openclaw` cron if available, or a shell cron entry under the workspace cron directory.
   - Ensure it runs as the same user and has access to all workspace paths.
4. Run the script once manually to baseline all current main-memory files into per-agent dirs.
5. Test by adding a new file to `workspace/memory/` and confirming it propagates to per-agent dirs after the next run.
6. Verify `openclaw memory index --force --agent <agent>` still works for at least 3 agents and shows healthy indexes.

## S — Stabilize
- Monitor the first few cron runs for errors.
- Ensure the script handles main-memory file deletions gracefully (do not delete per-agent copies automatically without Ken approval).
- No gateway restart needed.

## Completion Summary
- **Forge subagent:** `agent:infra:subagent:11c398ce-b06b-466a-a659-9467ba7e7282`
- **Script:** `scripts/sync-agent-memory.sh` created, executable, 272 lines.
- **Cron:** every 4 hours via user crontab, with mkdir lock to prevent overlap.
- **Baseline run:** 12 new hardlinks created, 0 errors.
- **Propagation test:** test file hardlinked to all 12 per-agent dirs, then cleaned up.
- **Memory verification:** 6 agents tested (business, architect, ahsoka, security, legal, qa) — all `dirty: false`, `indexIdentity.status: "valid"`, 14/14 files, 1243 chunks.
- **Discovery:** 10 of 12 per-agent `memory/` dirs were already symlinks to main; the script handles both symlinks and real directories. By end of run, all 12 were uniform symlinks (likely via CHG-0935 probe).
- **No gateway restart required.**
- **Verdict: PASS**

## T — Transfer / Close
- Update `memory/CHANGELOG.md` CHG-0933 entry with completion evidence.
- Close CHG-0933 in Notion Archive DB C with links to this plan and the script.
- Document the cron schedule and manual run command.
- Journal entry per Journal Discipline.

## Verification Criteria (all met)
1. ✅ `scripts/sync-agent-memory.sh` exists, is executable, and is idempotent.
2. ✅ A new file in `workspace/memory/` appears in every per-agent `memory/` directory after the next sync run (same inode).
3. ✅ All agents still show healthy memory indexes after the manual baseline sync.
4. ✅ Cron job is registered and runs without errors.

## Scope Boundary
- This change only adds a sync script and cron job.
- It does not modify CHG-0929 hardlinks, runtime code, or `openclaw.json`.
