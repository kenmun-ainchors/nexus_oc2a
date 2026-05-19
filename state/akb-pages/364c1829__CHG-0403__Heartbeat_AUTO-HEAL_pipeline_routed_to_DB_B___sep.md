# [CHG-0403] Heartbeat AUTO-HEAL pipeline routed to DB B — separate from sprint backlog

- **Notion ID:** `364c182953ff812c930ad91c6479df13`
- **Status:** Done
- **Type:** CHG
- **Priority:** 
- **Category:** 
- **Sprint:** 
- **Created:** 2026-05-18
- **Last Edited:** 2026-05-18T11:34:00.000Z

## Notes

Type: rule | Source: ken-prompt | Trigger: Ken: step 3 — connect heartbeat AUTO-HEAL pipeline to use DB B | Changed: HEARTBEAT.md: Auto-Heal NEEDS_KEN section updated — target DB B (364c1829-53ff-81c0) instead of DB A. Status changed from Done→Open for review workflow. Added Category inference rule. Added Notion DB IDs reference section with all 3 DBs. | Why: AUTO-HEAL items were cluttering DB A (Backlog). Now routed to dedicated DB B with Open/Reviewed/Resolved workflow instead of instant-Done. | Verified: HEARTBEAT.md updated with DB B target + ID reference. Pipeline: auto-heal.sh → heartbeat reads → creates pages in DB B via Notion API. | Rollback: N/A
