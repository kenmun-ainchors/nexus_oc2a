# [TKT-0533] Wire live Ollama API request counting — cost-state.json turnsLimit is stale

- **Notion ID:** `382c182953ff81a18c3cf08153f945b6`
- **Status:** Open
- **Type:** Bug
- **Priority:** Medium
- **Category:** Technical
- **Sprint:** 9
- **Created:** 2026-06-17T13:47:00.000+10:00
- **Last Edited:** 2026-06-17T03:51:00.000Z

## Notes

cost-state.json turnsLimit.currentRequests is a static snapshot last updated Jun 15. No script updates it. request-budget-check.sh reads stale data. ollama-quota-track.sh estimates per-cron tokens but does not tally actual API requests. Weekly 30k budget tracking is non-functional.
