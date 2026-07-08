# [TKT-0970] Fix db-ticket.sh create-from-json silent failure

- **Notion ID:** `397c182953ff8175a5d5e3c7ca8dc685`
- **Status:** Done
- **Type:** Bug
- **Priority:** Critical
- **Category:** Technical
- **Sprint:** Sprint 11
- **Created:** 2026-07-08T20:59:00.000+10:00
- **Last Edited:** 2026-07-08T11:22:00.000Z

## Notes

Repair malformed if-block in cmd_create_from_json that placed emit_event/entity_links inside the state/tickets.json mirror block, causing bash parse/execution failure and silent exit 1 on all create-from-json calls.
