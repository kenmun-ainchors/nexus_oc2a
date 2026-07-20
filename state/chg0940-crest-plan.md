# CHG-0940 CREST Plan — Fix request-budget-check.sh false non-zero exit on warning

## Change Record
- **CHG-0940** — Fix `request-budget-check.sh` false non-zero exit on warning.
- Notion Archive DB C page: `3a2890b6-ece8-814d-a930-c02967e1fd72`
- Trigger: Runtime reports "Exec failed" after `request-budget-check.sh --report` runs successfully but exits 1 when the Ollama request budget crosses the warning threshold (≥50%). This pollutes exec-health alerts.

## Current State
- `scripts/request-budget-check.sh` prints the warning report and exits 1 when usage crosses the warning threshold.
- The OpenClaw runtime treats any non-zero exit as a failed exec, generating noise alerts.
- Real errors (missing `state/cost-state.json`, invalid JSON, auth failure) also use non-zero exits.

## Root Cause
- The script conflates "warning condition" with "execution failure" by returning exit code 1 for both.

## C — Classify
- **Risk:** Low. Script behavior change; no runtime changes.
- **Blast radius:** Ollama budget alerts and exec-health monitoring.
- **Type:** script.

## R — Root-cause summary
`request-budget-check.sh` returns exit code 1 on warning thresholds, which the runtime interprets as an exec failure.

## E — Execute (Forge)
Dispatch `agentId="infra"` with instructions:
1. Modify `/Users/ainchorsoc2a/.openclaw/workspace/scripts/request-budget-check.sh` so that:
   - Warning thresholds (≥50%, ≥80%, etc.) print the warning and exit 0.
   - Only fatal/execution errors exit non-zero: missing `state/cost-state.json`, invalid JSON structure, failed HTTP/auth calls, unknown CLI arguments, or unhandled exceptions.
   - Preserve existing `--report` and `--json` output format and content.
2. Add internal helper/comment clarifying the difference between `WARNING_EXIT=0` and `ERROR_EXIT=1` (or distinct non-zero codes for different error classes).
3. If the script currently relies on exit code 1 to trigger downstream alert logic (e.g., cron dead-letter), ensure the warning is still surfaced via stdout/stderr or JSON output, not via exit code.
4. Run `bash -n scripts/request-budget-check.sh`.
5. Test with current `state/cost-state.json` (usage >50%) and confirm exit code 0 for `--report` and `--json`.
6. Simulate a fatal error by temporarily moving `state/cost-state.json` aside and confirm non-zero exit with clear error message. Restore the file immediately.
7. Stage the modified script for commit. Do NOT commit unless explicitly asked; Yoda will handle commit/closure.
8. Back up original script under `.chg-0940-backup/`.

## S — Stabilize
- Confirm the 20:00 daily burn alert cron (ca5d5e50) still receives warning data from stdout/JSON.
- Verify no new false exec-failed alerts appear the next time the script runs over 50%.

## T — Transfer / Close
- Update `memory/CHANGELOG.md` CHG-0940 entry with completion evidence.
- Close CHG-0940 in Notion Archive DB C.
- Journal entry per Journal Discipline.

## Verification Criteria
1. `bash -n scripts/request-budget-check.sh` passes.
2. With current usage above 50%, `scripts/request-budget-check.sh --report` exits 0 while still printing the warning.
3. With `state/cost-state.json` missing, the script exits non-zero and prints a clear error.

## Scope Boundary
- Only change exit-code behavior of `scripts/request-budget-check.sh`.
- Do not change budget thresholds, the 30,000/week formula, or other scripts unless necessary for the exit-code fix.
