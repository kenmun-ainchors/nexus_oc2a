# CHG-0938 CREST Plan — Fix EmbeddedAttemptSessionTakeoverError for File-Modifying Subagents

## Change Record
- **CHG-0938** — Fix `EmbeddedAttemptSessionTakeoverError` for file-modifying subagents.
- Notion Archive DB C page: `3a2890b6-ece8-81fb-a339-cb5322176417`
- Trigger: Infra subagents repeatedly fail with `EmbeddedAttemptSessionTakeoverError` whenever they try file-modifying work. The error originates in OpenClaw runtime `dist/selection-JInn13lc.js` when the session file fingerprint changes while the embedded attempt lock is released.

## Current State
- Infra subagents fail mid-execution when writing files or modifying workspace state.
- The error message is: `session file changed while embedded prompt lock was released: <sessionFile>`.
- The failure occurs in `createEmbeddedAttemptSessionLockController` in `/Users/ainchorsoc2a/local/lib/node_modules/openclaw/dist/selection-JInn13lc.js` (lines ~5896–~6100).
- The session fingerprint comparison (`sameSessionFileFingerprint`) fails after the lock is temporarily released, causing `takeoverDetected = true` and the error to be thrown.

## Root Cause Hypothesis
- When an embedded subagent performs file-modifying work, it may yield or release the session write lock.
- While the lock is released, the parent session (Yoda/main) continues to append entries to its own `.jsonl` session file.
- When the subagent reacquires the lock and refreshes the session file snapshot, the fingerprint no longer matches, so the runtime concludes another process has "taken over" the session.
- The runtime treats this as a security/error condition instead of recognizing it as benign parent-session activity.

## C — Classify
- **Risk:** High. Runtime patch affects session locking and embedded subagent safety guarantees.
- **Blast radius:** All embedded subagents, parent session integrity, and the session persistence pipeline.
- **Type:** infra / runtime code.

## R — Root-cause summary
The embedded session lock controller treats parent-session writes during lock release as a hostile takeover, blocking file-modifying subagents.

## E — Execute (Forge)
Dispatch `agentId="infra"` with instructions:
1. Read `/Users/ainchorsoc2a/local/lib/node_modules/openclaw/dist/selection-JInn13lc.js` around `createEmbeddedAttemptSessionLockController` and related functions.
2. Map the full call flow:
   - `acquireLock` / `releaseLock`
   - `mergePromptReleasedSessionChange`
   - `reloadPromptReleasedSessionFile`
   - `sameSessionFileFingerprint`
   - `recordOwnedSessionFileWrite`
3. Identify the exact condition that causes `takeoverDetected = true` during file-modifying work.
4. Create a minimal reproduction by spawning an `agentId="infra"` subagent that performs multiple file writes in a loop (e.g., creating small files under `/Users/ainchorsoc2a/.openclaw/workspace/state/chg0938-test/`). Confirm the error can be reproduced.
5. Choose the safest fix path from the options below (document the choice):
   - **Option A:** Distinguish between external takeover and benign parent-session writes by tracking the generation/owner of writes.
   - **Option B:** Extend the lock hold duration for embedded attempts doing file work so the lock is not released mid-operation.
   - **Option C:** Relax the fingerprint check when the only changes are from the parent session and no other embedded attempt is active.
   - **Option D:** If a local patch is unsafe, prepare a minimal upstream issue/PR with the reproduction and proposed change.
6. Implement the chosen patch in the runtime dist file(s).
7. Back up all modified runtime files under `.chg-0938-backup/`.
8. Validate the patched code with `node --check`.
9. Re-run the reproduction subagent and confirm it completes all file writes without `EmbeddedAttemptSessionTakeoverError`.
10. Run a regression test: spawn a normal chat turn and a non-file-modifying subagent to confirm session integrity is preserved.
11. If a gateway restart is required, request explicit Ken approval before restarting.

## S — Stabilize
- After the patch, monitor embedded subagent runs for any new session errors.
- Ensure parent session writes are still safe and that the patch does not allow real session takeovers to go undetected.
- Keep backups of original runtime files.

## T — Transfer / Close
- Update `memory/CHANGELOG.md` CHG-0938 entry with completion evidence.
- Close CHG-0938 in Notion Archive DB C with links to the plan, patch, and test results.
- If the fix is an upstream PR, record the PR/issue URL.
- Journal entry per Journal Discipline.

## Verification Criteria
1. A file-modifying infra subagent can complete without `EmbeddedAttemptSessionTakeoverError`.
2. Normal chat turns and non-file-modifying subagents still work correctly.
3. `node --check` passes on patched runtime files.
4. Session file integrity is preserved (no corruption, no lost entries).

## Scope Boundary
- This change modifies OpenClaw runtime dist files.
- It does not change agent workspace content, scripts, or business logic.
- It must not weaken the session takeover detection for genuinely conflicting processes.

## Dependencies
- CHG-0937 (imessage-bridge fix) is independent and can run in parallel.
