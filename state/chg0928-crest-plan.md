# CHG-0928 CREST Plan v2 — R01 Runtime Emitter + Composer Quality (Revised After Investigation)

## Change Record
- **CHG-0928** — Complete R01 gateway runtime fix and restore standup composer JSON validation quality.
- Notion Archive DB C page: `3a2890b6-ece8-81fe-8a7a-d8b011fdfdc6`
- Original CREST plan: `state/chg0928-crest-plan.md` (this file overwrites it)
- Investigation journal: `memory/journal-2026-07-19.md` 08:32 entry

## Current State
- **CHG-0928 v4/v6 COMPLETE** — runtime path emitter fixed and R01 audit narrowed to path fields only.
- `rule-audit.sh` R01 **PASS** with **0 violations** (2026-07-19 10:24 AEST); all 10 rules PASS.
- New helper: `scripts/r01-path-field-scan.py` — JSON-aware, path-field-only tilde scanner.
- Backup: `.chg-0928-v6-backup/rule-audit.sh.bak`.
- Composer degraded-mode issue is **next** (CHG-0928 v7), pending dispatch.

## Investigation Findings (Yoda)

### Primary Session Header Emitter
- File: `/Users/ainchorsoc2a/local/lib/node_modules/openclaw/dist/session-manager-BKz2VYho.js`
- Function `newSession()` writes the session header with:
  ```js
  cwd: this.cwd,
  ```
  at approximately line 1519.
- Function that creates a branched session also writes the same header at approximately line 2438.
- `this.cwd` is set in the `SessionManager` constructor and passed in from `SessionManager.create(cwd, sessionDir)`.
- Callers in `/Users/ainchorsoc2a/local/lib/node_modules/openclaw/dist/sessions-DrsnOdf0.js`:
  - Line 12292: `SessionManager.create(cwd, getDefaultSessionDir(cwd, agentDir))`
  - Line 12686: `SessionManager.create(this.cwd, sessionDir)`
  - Line 12725: `SessionManager.create(this.cwd, sessionDir)`
- `this.cwd` in those callers is set from `options.cwd` or `config.cwd` (lines 2621, 8391, 9645, 11670 of `sessions-DrsnOdf0.js`).
- **Conclusion**: the runtime passes a workspace `cwd` that still contains `~/.openclaw` (unexpanded) when sessions are created, and `SessionManager` persists it verbatim.

### Secondary Emitters
- Trajectory files are written by:
  - `/Users/ainchorsoc2a/local/lib/node_modules/openclaw/dist/run-attempt-V636cwT5.js`
  - `/Users/ainchorsoc2a/local/lib/node_modules/openclaw/dist/channel-YrfEVd9X.js`
  - and the `paths-*.js` helpers
- These may either re-serialize the session `cwd` or write their own path fields.

### Earlier Patches
- CHG-0926 patched read-time normalization in `dist/session-utils-BjEgE3FM.js`.
- CHG-0926 patched some write-time emitters in `dist/get-reply-CknL88Yv.js` and `dist/openclaw-tools-CIBcX9Ku.js`.
- **None of the earlier patches touched `SessionManager` or runtime workspace path expansion at startup.** This is why new sessions continue to be written with tilde paths.

## CREST Plan v2

### C — Classify
- **Risk:** Medium-High. Patching the live runtime on PROD OC2A, but the fix is targeted (two known write paths + startup expansion).
- **Blast radius:** Session persistence only. No client data exposure.
- **Auto-heal:** CHG-0924 auto-heal cron (`ad213be3...`) remains active throughout; it is masking the symptom by cleaning files retroactively, but it does NOT fix the emitter.

### R — Root-cause summary
1. **R01:** `SessionManager.newSession()` writes `cwd: this.cwd` without normalizing `~/.openclaw` → `/Users/ainchorsoc2a/.openclaw`. The `cwd` value originates from the runtime's workspace configuration, which is not expanded before being passed to `SessionManager.create()`.
2. **R01 (trajectory):** Trajectory serialization either copies the same `cwd` or writes its own un-normalized path fields.
3. **Composer:** Standup composer JSON validation fails on primary and fallback models, forcing a placeholder-only fallback. Root cause to be confirmed during execution (schema vs model output vs routing).

### E — Execute (Forge, targeted, no restart until verified)
Dispatch `agentId="infra"` with these **strict** instructions:

#### Target 1 — Session header write-time normalization
1. Patch `/Users/ainchorsoc2a/local/lib/node_modules/openclaw/dist/session-manager-BKz2VYho.js`:
   - In `newSession()` (line ~1519), normalize `this.cwd` before writing it into the header.
   - In the branch-session writer (line ~2438), normalize `this.cwd` before writing it into the header.
   - Also normalize `parentSession` if it contains a path string.
   - Use the same normalization helper that was added to `session-utils-BjEgE3FM.js`, or inline a safe `~` → `process.env.HOME` expansion for `~/.openclaw`.
2. Patch `/Users/ainchorsoc2a/local/lib/node_modules/openclaw/dist/sessions-DrsnOdf0.js`:
   - Normalize `cwd`/`this.cwd` at the points where it is passed to `SessionManager.create()` (lines 12292, 12686, 12725).
   - Also normalize where `cwd` is first assigned from `options.cwd` or `config.cwd` (lines 2621, 8391, 9645, 11670).
3. Do **not** restart the gateway yet.

#### Target 2 — Trajectory write-time normalization
1. Patch trajectory emitters in `run-attempt-V636cwT5.js` and `channel-YrfEVd9X.js` so any path fields they write are normalized.
2. If they re-use the session `cwd`, Target 1 may already fix them; verify before editing.

#### Target 3 — Read-time defense in `SessionManager.open()`
1. In `SessionManager.open()` (line ~2515), when reading the header `cwd` from an existing session file, normalize it before returning the new `SessionManager` instance.
2. This prevents old sessions with tilde paths from re-injecting the violation into new writes.

#### Target 4 — Verification before any restart
1. After applying the patches, create a **test subagent** or trigger a lightweight runtime operation that creates a new session.
2. Run `rule-audit.sh` and confirm that new sessions do **not** add tilde-path violations.
3. Only after R01 violations are stable/declining (not increasing), perform a safe gateway restart.
4. After restart, run `rule-audit.sh` again and confirm R01 trend is toward zero.

#### Target 5 — Composer degraded-mode fix
1. Locate the standup composer pipeline and the 2026-07-19 08:00 JSON-validation failure logs.
2. Identify whether the failure is:
   - model output malformed,
   - schema too strict,
   - token truncation,
   - model routing issue.
3. Implement the minimal safe fix:
   - If schema/parsing issue: loosen/fix the JSON parser.
   - If prompt issue: improve composer prompt/instructions.
   - If model routing issue: route composer to a model with reliable JSON output.
   - Add retry with a stronger model before placeholder fallback.
4. Validate with a test standup/composer run — confirm no degraded-mode warning and real content in all sections.

### S — Stabilize
- After R01 patches, observe `rule-audit.sh` for at least 30 minutes of normal operation and several new session creations.
- After composer fix, observe at least one scheduled standup run.
- Keep CHG-0924 auto-heal cron active until R01 PASS has been stable for 24 hours.
- Do not disable auto-heal until stable PASS.

### T — Transfer / Close
- Update `docs/RUNBOOK.md` with:
  - Map of session/trajectory write-time emitters.
  - Composer JSON-validation notes.
- Close CHG-0928 in Notion Archive DB C with evidence:
  - `rule-audit.sh` PASS output (or stable declining trend).
  - Successful standup generation log without degraded-mode warning.
- Journal entry per Journal Discipline (TKT-0296).

## Verification Criteria
1. New session files are written with `cwd: "/Users/ainchorsoc2a/.openclaw/workspace"` (absolute), never `~/.openclaw/workspace`.
2. `rule-audit.sh` R01 violations stop increasing when new sessions are created and begin decreasing as old files age out / are cleaned.
3. `rule-audit.sh` eventually reports R01 PASS.
4. Standup composer generates content without degraded-mode warning and without placeholder-only sections.

## Rollback
- Revert the patched lines in `session-manager-BKz2VYho.js` and `sessions-DrsnOdf0.js`.
- Revert trajectory emitter patches if any.
- Keep CHG-0924 auto-heal cron active to maintain status quo.

## Scope Boundary
- CHG-0928 does **not** touch operational notification fixes (CHG-0927, complete).
- CHG-0928 does **not** re-run broad auto-heal or bulk-sweep existing files; that is the auto-heal cron's job.
- CHG-0928 only fixes the **runtime emitters** so new files are clean.

## v7 — Composer Degraded-Mode Fix (Pending Dispatch)
- Investigate `scripts/generate-standup.sh` JSON validation failure from 2026-07-19 08:00 MYT.
- Identify root cause: schema, parser, prompt, token truncation, or model routing.
- Implement minimal safe fix and validate with a test standup generation run.
- No gateway restart expected.

## Status
- v4 Runtime path fix: ✅
- v5 Config investigation: ✅ (no config change needed)
- v6 Narrow R01 audit to path fields: ✅
- v7 Composer fix: ⏳ in progress
