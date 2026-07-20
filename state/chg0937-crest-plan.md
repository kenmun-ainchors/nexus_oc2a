# CHG-0937 CREST Plan — Fix imessage-bridge.sh Pre-Commit Syntax Errors

## Change Record
- **CHG-0937** — Fix imessage-bridge.sh pre-commit bash syntax errors.
- Notion Archive DB C page: `3a2890b6-ece8-81d1-a0a2-dabd163ae722`
- Trigger: During CHG-0933/0935/0936 closure commit, pre-commit hook `bash -n` failed on `projects/imessage-bridge/legacy/imessage-bridge.sh` and `scripts/imessage-bridge.sh` with "syntax error: unexpected end of file" at line 199.

## Current State
- Two imessage-bridge.sh files are unstaged and cannot be committed.
- Pre-commit hook reports syntax errors at line 199, likely a missing closing keyword (`fi`, `done`, `}`, etc.).
- No functional impact is known, but the files are blocked from the commit pipeline.

## Root Cause
- A bash control structure was left unclosed during a prior edit, causing `bash -n` to fail.

## C — Classify
- **Risk:** Low. Script-only fix; no runtime changes.
- **Blast radius:** iMessage bridge functionality (if used).
- **Type:** script.

## R — Root-cause summary
Unclosed bash control structure at or before line 199.

## E — Execute (Forge)
Dispatch `agentId="infra"` with instructions:
1. Inspect `projects/imessage-bridge/legacy/imessage-bridge.sh` and `scripts/imessage-bridge.sh`.
2. Run `bash -n` on each file to confirm the exact syntax error and line.
3. Identify the unclosed structure (e.g., missing `fi`, `done`, `esac`, `}`) and any other syntax issues.
4. Fix the files. Preserve intended logic and behavior; do not refactor unless necessary.
5. Re-run `bash -n` until both files pass.
6. If a test or dry-run command exists for the bridge, run it. Otherwise, note that functional testing was not available.
7. Stage the two files and commit them with an appropriate message, or leave them staged for a follow-up commit by Yoda.
8. Backup the original files under `.chg-0937-backup/` before editing.

## S — Stabilize
- Verify pre-commit hook no longer blocks on these files.
- Ensure no regressions in iMessage bridge behavior if tests exist.

## T — Transfer / Close
- Update `memory/CHANGELOG.md` CHG-0937 entry with completion evidence.
- Close CHG-0937 in Notion Archive DB C with links to the plan and the diff.
- Journal entry per Journal Discipline.

## Verification Criteria
1. `bash -n projects/imessage-bridge/legacy/imessage-bridge.sh` returns no errors.
2. `bash -n scripts/imessage-bridge.sh` returns no errors.
3. Pre-commit hook passes when these files are staged.

## Scope Boundary
- Only fix syntax errors in the two named files.
- Do not change business logic unless required to resolve the syntax error.
