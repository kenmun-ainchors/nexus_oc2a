# CHG-0939 CREST Plan — Add Canonical Notion Page-Status Update Helper

## Change Record
- **CHG-0939** — Add canonical Notion page-status update helper.
- Notion Archive DB C page: `3a2890b6-ece8-81eb-b196-dda393378979`
- Trigger: During CHG-0938 closure, an ad-hoc Python inline script tried to update Notion via the macOS keychain and failed because the token was not stored there. The canonical Notion auth file `~/.config/notion/api_key` works, but there is no reusable helper.

## Current State
- No reusable script exists to update a Notion page's Status field.
- Ad-hoc API calls risk using wrong token sources (keychain vs auth file) and leaking tokens.
- Future CHG closures will benefit from a reliable helper.

## Root Cause
- Missing reusable helper for a common operation (Notion page status update).
- Ad-hoc scripts use fragile token discovery.

## C — Classify
- **Risk:** Low. New helper script; no runtime changes.
- **Blast radius:** CHG closure workflow.
- **Type:** script.

## R — Root-cause summary
No canonical helper exists for Notion page status updates, so ad-hoc scripts use unreliable token discovery.

## E — Execute (Forge)
Dispatch `agentId="infra"` with instructions:
1. Create `scripts/notion-update-page-status.sh` in the workspace.
2. The script must:
   - Read the Notion integration token from `~/.config/notion/api_key`.
   - Accept positional arguments: `PAGE_ID` and `STATUS_NAME`.
   - Validate that both arguments are present and non-empty.
   - Use curl with headers `Authorization: Bearer $NOTION_KEY`, `Notion-Version: 2022-06-28`, `Content-Type: application/json`.
   - PATCH `https://api.notion.com/v1/pages/$PAGE_ID` with body `{"properties": {"Status": {"select": {"name": "$STATUS_NAME"}}}}`.
   - Implement rate-limit retry: on HTTP 429, respect `Retry-After` up to 3 retries.
   - Handle HTTP 401, 5xx, and missing page errors gracefully with clear messages.
   - Never print the token in output or errors.
   - Exit 0 on success, non-zero on failure.
3. Run `bash -n scripts/notion-update-page-status.sh` to verify syntax.
4. Validate auth by running the script with the `--auth-check` option (or a direct curl to `/v1/users/me` using the helper's token read logic).
5. Optional end-to-end test: update CHG-0939's own Notion status to "In Progress" and back to "Planned" (or original value) to confirm the script works.
6. Stage the new script for commit. Do NOT commit unless explicitly asked; Yoda will handle commit/closure.
7. Back up any existing file with the same name under `.chg-0939-backup/`.

## S — Stabilize
- Verify the helper works for the CHG-0939 status update itself before closure.
- Ensure no token leakage in logs or error output.

## T — Transfer / Close
- Update `memory/CHANGELOG.md` CHG-0939 entry with completion evidence.
- Close CHG-0939 in Notion Archive DB C.
- Journal entry per Journal Discipline.

## Verification Criteria
1. `bash -n scripts/notion-update-page-status.sh` passes.
2. Auth check call to `/v1/users/me` succeeds.
3. End-to-end status update on CHG-0939 page succeeds without token leakage.

## Scope Boundary
- Only add the new helper script and validate it.
- Do not change changelog-append.sh or notion skill unless required for the helper to function.
