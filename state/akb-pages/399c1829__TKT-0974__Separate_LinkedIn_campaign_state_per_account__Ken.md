# [TKT-0974] Separate LinkedIn campaign state per account (Ken/Angie/Business)

- **Notion ID:** `399c182953ff81159d0bfc8f6b5f5bd6`
- **Status:** In Progress
- **Type:** epic
- **Priority:** High
- **Category:** Technical
- **Sprint:** Sprint 11
- **Created:** 2026-07-10T02:15:00.000+10:00
- **Last Edited:** 2026-07-10T02:28:00.000Z

## Notes

Ken identified that Spark is struggling to manage 3 LinkedIn campaigns (Ken personal, Angie personal, AInchors business) through a single linkedin-campaign.json + shared Spark crons. This caused missed posts in Week 4 (Tue and Thu personal slots). This epic covers architecture design, implementation, and operational transition to per-account campaign state and per-campaign publish/draft crons.
