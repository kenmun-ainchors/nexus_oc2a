# CHG-0928 v4 patch summary

**Applied:** 2026-07-19 09:46 AEST (subagent depth 1/1 — infra dispatch)
**File modified:** `/Users/ainchorsoc2a/local/lib/node_modules/openclaw/dist/workspace-BKXau6p-.js`
**Backup:** `/Users/ainchorsoc2a/.openclaw/workspace/.chg-0928-v4-backup/workspace-BKXau6p-.js.bak`
**Patch size:** +1109 bytes (48,495 → 49,604)

## Function changed: `compactSkillPaths(skills)` — lines 179–225

**Removed (v3 behaviour):**
- `const homes = resolveCompactHomePrefixes();` (line 179, v3)
- `if (homes.length === 0) return skills;` (line 180, v3)
- `filePath: sanitizeForPersistence(compactHomePath(s.filePath, homes))` (line 199, v3) — the actual home-to-tilde compaction call

**Added (v4 behaviour):**
- New comment block explaining the v4 intent (R01 forbids literal `/Users/<u>/.openclaw`; tilde form was a leak vector)
- Replaced `compactHomePath(s.filePath, homes)` with `sanitizeForPersistence(s.filePath)` — sanitizer still rewrites both `~/.openclaw[/...]` and `<home>/.openclaw[/...]` to `$HOME/.openclaw[/...]`
- `shouldPreservePromptSkillPath` short-circuit kept (so config-`skills` / `plugin-skills` paths still get the v3 R01-clean treatment)

## Intentionally left intact

- `compactHomePath(filePath, homes)` (line 250) — function still defined; the testing export (`const testing = { compactHomePath }` line 1049) keeps it accessible for unit tests
- `compactPathForConsoleMessage(filePath)` (line 262) — used by `warnEscapedSkillPath` (lines 421–424) for warning-log console display (NON-persistence use case, scope item 3)

## Why this is the only file touched

`compactHomePath` is centralised in `workspace-BKXau6p-.js` and is only called from inside that file:
- `compactSkillPaths` (DISABLED in v4 — persistence)
- `compactPathForConsoleMessage` (KEPT — console warning display)

A grep across the whole dist/ tree confirms no `sessions-*.js` or `session-manager*.js` file imports `compactHomePath` or `compactPathForConsoleMessage`. The session/trajectory persistence pipeline only hits the compactor through the skills prompt snapshot path that flows from `compactSkillPaths` → `buildWorkspaceSkillSnapshot` → `session-snapshot-mFoFiIO4.js` → `.jsonl` / `.trajectory.jsonl`.

## Verification status

- ✅ `node --check` passes (syntax valid)
- ✅ `diff -u` shows only the targeted `compactSkillPaths` function changed
- ✅ Backup saved in workspace for instant rollback
- ⏳ Yoda must spawn a fresh verification subagent and check its session/trajectory files for 0 tilde hits before gateway restart

## Rollback

```bash
cp /Users/ainchorsoc2a/.openclaw/workspace/.chg-0928-v4-backup/workspace-BKXau6p-.js.bak \
   /System/Volumes/Data/Users/ainchorsoc2a/local/lib/node_modules/openclaw/dist/workspace-BKXau6p-.js
```
