# [CHG-0431] tqp-yoda.sh wrapper created for TKT-0309 Phase 2

- **Notion ID:** `36dc182953ff81a9af45c18c04ddaf5b`
- **Status:** Done
- **Type:** CHG
- **Priority:** 
- **Category:** 
- **Sprint:** 
- **Created:** 2026-05-27
- **Last Edited:** 2026-05-27T08:36:00.000Z

## Notes

Type: script | Source: manual | Trigger: TKT-0309 Atom A2 | Changed: Created scripts/tqp-yoda.sh — 3 modes (persist/resume/check) wrapping sc_persist_atom + sc_resume_context + pg_read_task via env vars. Fixed 2 bugs: sc_read_task valid_statuses missing 'open'/'in_progress'/'backlog'/'closed', and zsh setopt localoptions causing brace expansion on JSON default values. | Why: Yoda needs lightweight shell wrapper to persist atoms inline without Python boilerplate every time | Verified: All 7 test cases pass. persist atom_index=2 written to PG. Resume correctly reports last atom 1, next atom 2. | Rollback: N/A
