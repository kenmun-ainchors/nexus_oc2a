# Memory Maintenance Skill

## Purpose
Ensure daily memory and journal facts that change master state are promoted to `MEMORY.md` and context handoff delta documents. Prevents drift between daily source-of-truth files and long-term master references.

## Tag Convention
Use inline tags in daily memory (`memory/YYYY-MM-DD.md`) and journal (`memory/journal-YYYY-MM-DD.md`) files to mark facts that must be promoted to master:

- **`#master-update`** — A fact, decision, or change that should be reflected in `MEMORY.md` and/or the latest context handoff delta. Examples:
  - `#master-update OC2 ETA changed from 6-13 Jul to 13-20 Jul`
  - `#master-update Sprint 9 committed with 16-item exception`
  - `#master-update Yoda model reverted to kimi-k2.7-code:cloud`

- **`#execution-state`** — A completed execution, milestone, or closure that changes the master execution-state picture. Examples:
  - `#execution-state CREST v1.3 fully executed 2026-06-20 TKT-0546 closed`
  - `#execution-state WO-002 7-day monitoring closed Option B`
  - `#execution-state TKT-0698 completed db-write.sh error classification`

## File Structure

| Role | Files | Description |
|------|-------|-------------|
| Source of truth (recent facts) | `memory/YYYY-MM-DD.md` | Daily memory — session summaries, decisions, execution records |
| Source of truth (recent facts) | `memory/journal-YYYY-MM-DD.md` | Daily journal — detailed chronological log |
| Master target | `MEMORY.md` | Long-term memory — durable preferences, decisions, platform facts |
| Master target | `docs/context-handoffs/Context-Handoff-Delta-*.md` | Latest context handoff delta — consolidated master state |

## Promotion Checklist
Before generating a context handoff or performing EOD close:

1. **Scan** — Run `scripts/daily-master-promote-check.sh` with appropriate `--since` window
2. **Review** — Examine the `drift` array in the JSON output for tagged statements not yet reflected in master targets
3. **Resolve** — For each drift entry:
   - If the fact belongs in `MEMORY.md`, add or update the relevant section
   - If the fact belongs in the latest context handoff delta, update the delta document
   - If the fact is transient or already covered, add a note and close the drift
4. **Re-check** — Re-run the promotion check to confirm zero drift
5. **Proceed** — Only generate the handoff or close EOD when drift count is zero

## Canonical Script
- `scripts/daily-master-promote-check.sh` — scans daily memory/journal files for tagged statements and checks whether they are reflected in master targets

## Related
- `MEMORY.md` — long-term memory master
- `docs/context-handoffs/` — context handoff delta documents
- `state/file-contracts.json` — file purpose contracts (MEMORY.md contract)
