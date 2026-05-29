# [CHG-0432] AGENTS.md TQP Execution Gate updated with concrete invocation paths

- **Notion ID:** `36dc182953ff814d897de0bd0e016df9`
- **Status:** Done
- **Type:** CHG
- **Priority:** 
- **Category:** 
- **Sprint:** 
- **Created:** 2026-05-27
- **Last Edited:** 2026-05-27T08:39:00.000Z

## Notes

Type: doc | Source: manual | Trigger: TKT-0309 Atom A3 | Changed: Replaced abstract sc_persist_atom/sc_read references in AGENTS.md OWL Execution Contract with concrete tqp-yoda.sh invocations: persist (with JSON payload args), resume (returns last/next atom), check. Added schema contract doc link. | Why: Yoda needs actionable commands in AGENTS.md, not abstract function names — the contract must be executable on session load | Verified: Section reads correctly with bash commands, absolute paths, and contract doc reference | Rollback: N/A
