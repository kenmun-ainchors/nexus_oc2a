# [CHG-0436] ticket.sh: add JSON payload validation to write_ticket

- **Notion ID:** `36dc182953ff81988c9bcd481c1c5414`
- **Status:** Done
- **Type:** CHG
- **Priority:** 
- **Category:** 
- **Sprint:** 
- **Created:** 2026-05-27
- **Last Edited:** 2026-05-27T08:49:00.000Z

## Notes

Type: script | Source: manual | Trigger: TKT-0309 close — ticket.sh update --notes silently passed bad JSON to db-write.sh | Changed: Added jq empty validation to write_ticket() in scripts/ticket.sh. Non-JSON payload (like --notes flags) now caught before PG write with clear error message showing correct usage. | Why: ticket.sh update accepts raw JSON as $3 with no validation. Bad input (like --notes flag) passes through to db-write.sh which fails with cryptic 'SQL generation failed'. Guard prevents silent failures and gives actionable error. | Verified: Bad input: 'ERROR: Invalid JSON payload'. Good input: update + Notion sync succeeds. | Rollback: N/A
