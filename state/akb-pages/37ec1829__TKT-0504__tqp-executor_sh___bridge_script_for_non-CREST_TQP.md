# [TKT-0504] tqp-executor.sh — bridge script for non-CREST TQP atoms (L-096)

- **Notion ID:** `37ec182953ff8130b0eed3fe5b7150e8`
- **Status:** Done
- **Type:** task
- **Priority:** Medium
- **Category:** Technical
- **Sprint:** 9
- **Created:** 2026-06-13T00:39:00.000+10:00
- **Last Edited:** 2026-06-13T05:27:00.000Z

## Notes

Build tqp-executor.sh bridge so non-CREST TQP atoms (source=agent:tqp, no parent_ticket) actually execute instead of re-claiming every 5 min. Splits into TKT-0504-A0 (Sprint 7 quick-fix: signal-only) + TKT-0504-A1..A5 (Sprint 9 full bridge: tqp-executor.sh). L-096 silence-class failure.
