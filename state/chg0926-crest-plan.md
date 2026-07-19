# CHG-0926 CREST Plan — R01 Gateway Runtime Fix

## Change Record
- **CHG-0926** (created 2026-07-19) — R01 gateway runtime fix: expand tilde paths in session metadata before persistence/response.
- Notion Archive DB C page: `3a1890b6-ece8-81e4-a383-d123a10c114d`

## Problem Statement
R01 audit reports **88 residual violations** because the OpenClaw gateway emits the unexpanded tilde path `/Users/ainchorsoc2a/.openclaw` in active session metadata every turn. External auto-heal (`scripts/r01-session-sweep.sh`, cron `ad213be3...`) prevents the count from growing but cannot reach true PASS because the source is the runtime itself.

True R01 PASS = 0 violations and the gateway emits absolute paths.

## CREST Plan

### C — Classify
- **Risk:** Medium. Touches live runtime source on OC2A PROD. Scope is narrow: path normalization only.
- **Type:** infra / runtime patch.
- **Affected runtime:** OpenClaw `2026.7.1` at `/Users/ainchorsoc2a/local/lib/node_modules/openclaw/`.

### R — Root-cause emitters (recon complete)
1. **`dist/session-utils-BjEgE3FM.js` `buildGatewaySessionRow()` (line ~1310)**  
   Returns `spawnedWorkspaceDir: entry?.spawnedWorkspaceDir` and `spawnedCwd: entry?.spawnedCwd` in the session row. These are included in `sessionInfo` returned by `chat.history` / `chat.startup`.
2. **`dist/chat-DPrylHin.js` `handleChatHistoryRequest()` (line ~2170)**  
   Calls `buildGatewaySessionInfo({ cfg, storePath, store, key, entry, agentId, modelCatalog })`, which returns the lightweight row containing the unexpanded tilde fields.
3. **Write-side source (subagent spawn / session entry creation)**  
   `spawnedWorkspaceDir` and `spawnedCwd` are written with raw workspace paths, including `~/.openclaw`, before persistence.

### E — Execute (Forge only)
Patch the runtime in two places:

#### 1. Write-time normalization (session entry creation / update)
- Wherever `spawnedWorkspaceDir` and `spawnedCwd` are set on a new or updated session entry, run `resolveTildePath(value)` (or `path.resolve` with homedir expansion) so the stored value is absolute.
- Expected helper location: `dist/agent-runner.runtime-DYRSfwOn.js` already contains tilde expansion helpers around line 4659 (`if (p === "~") return homedir(); if (p.startsWith("~/")) return resolve(homedir(), p.slice(2));`). Extract or reuse this helper for session entry writes.

#### 2. Read-time defense-in-depth (`buildGatewaySessionRow`)
- In `dist/session-utils-BjEgE3FM.js`, when returning `spawnedWorkspaceDir` and `spawnedCwd`, normalize any value through the same tilde-to-absolute helper before inclusion in the row.
- This ensures existing sessions with stale tilde values immediately return absolute paths after the patch, without requiring a migration sweep.

### S — Stabilize
- Restart OpenClaw gateway service on OC2A PROD (port 18789) after patch deployment.
- Re-run `scripts/r01-audit.sh` (or the R01 rule checker) to confirm violations drop from 88 → 0.
- Monitor for 30 min across chat turns and one subagent spawn to ensure no regression.
- Keep auto-heal cron `ad213be3...` enabled as a safety net for the first 24 h; disable only after stable PASS.

### T — Transfer / Close
- Update `docs/RUNBOOK.md` or equivalent infra runbook with the normalization rule: "session metadata paths must be absolute before persistence and before client response."
- Close CHG-0926 in Notion Archive DB C and append evidence (audit output + git commit).
- Journal entry per Journal Discipline (TKT-0296).

## Verification Criteria
1. `r01-audit.sh` reports **0 violations**.
2. A fresh session’s `chat.startup` `sessionInfo` contains absolute paths only (no `~/.openclaw` literal).
3. Subagent spawn produces `spawnedWorkspaceDir` / `spawnedCwd` as absolute paths.
4. No new exceptions in gateway logs for 30 min post-deploy.

## Rollback
- Reinstall previous OpenClaw runtime build or revert the two source-normalization sites.
- Re-enable auto-heal cron `ad213be3...` as the safety net.

## Decision Needed
Ken: **Approve CREST Plan and Forge dispatch?**  
If yes, I will spawn Forge (`agentId="infra"`) with this plan, a read-only recon context, and a strict budget. If no, tell me what to adjust.
