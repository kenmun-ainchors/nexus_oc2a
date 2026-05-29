# [CHG-0434] DoD Gate updated with TQP persist requirement

- **Notion ID:** `36dc182953ff814ab163ed9709ffe976`
- **Status:** Done
- **Type:** CHG
- **Priority:** 
- **Category:** 
- **Sprint:** 
- **Created:** 2026-05-27
- **Last Edited:** 2026-05-27T08:43:00.000Z

## Notes

Type: doc | Source: manual | Trigger: TKT-0309 Atom A5 — Phase 2 complete | Changed: YODA_RULES.md R25 DoD Gate: added TQP PERSIST GATE subsection (4 requirements: persist each atom, resume before close, TQP = authoritative, gaps = re-execute). Ticket Discipline DoD Gate: now 2-step close — (1) tqp-yoda.sh resume to verify all atoms, (2) ticket.sh close. Both reference TKT-0309 contract doc. | Why: DoD gate must enforce TQP persistence — without it, the gate is incomplete and atoms can still be lost to session compaction | Verified: Resume shows all 5 atoms (A1-A5) accounted, last_atom_index=5. Contract doc linked in both sections. | Rollback: N/A
