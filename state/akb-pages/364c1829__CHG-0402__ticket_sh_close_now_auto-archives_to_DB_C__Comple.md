# [CHG-0402] ticket.sh close now auto-archives to DB C (Completed-Archived) on close

- **Notion ID:** `364c182953ff81baae4eef9752ba8cf7`
- **Status:** Done
- **Type:** CHG
- **Priority:** 
- **Category:** 
- **Sprint:** 
- **Created:** 2026-05-18
- **Last Edited:** 2026-05-18T11:20:00.000Z

## Notes

Type: script | Source: ken-prompt | Trigger: Ken directive: step 2 — close ticket should auto-archive to DB C | Changed: ticket.sh close command: after marking Done in DB A, creates a copy in DB C with Type/Priority/Resolution/Completed Date. Uses jq-built JSON payload for safe escaping. Best-effort — failure does not block local close. | Why: 3-DB architecture (CHG-0401): A=active, B=auto-heal, C=archive. Close should move finished work to C for clean board. | Verified: End-to-end test: created TKT-0231, closed with resolution, confirmed entry appears in DB C with correct type=task, status=Archived. DB A entry archived. Test cleaned up. | Rollback: N/A
