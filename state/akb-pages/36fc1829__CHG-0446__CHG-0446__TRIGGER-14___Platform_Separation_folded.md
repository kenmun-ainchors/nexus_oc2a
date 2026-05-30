# [CHG-0446] CHG-0446: TRIGGER-14 + Platform Separation folded into TRIGGER-01 Master Gate

- **Notion ID:** `36fc182953ff8185b99fce4ec8fc811f`
- **Status:** Done
- **Type:** CHG
- **Priority:** 
- **Category:** 
- **Sprint:** 
- **Created:** 2026-05-29
- **Last Edited:** 2026-05-29T12:09:00.000Z

## Notes

Type: config | Source: ken-prompt | Trigger: Ken directive 2026-05-29 22:07: fold TRIGGER-14 (Claude Restore) and Platform Separation into OC2 trigger | Changed: chg-triggers.json v1.0→v2.0. TRIGGER-01 expanded to Master Gate with 11 sub-actions: hardware setup, OpenClaw install, Claude Restore, Platform Separation, PG migration, qwen3.5 reassessment, MD version bump, SecretRefs, new Google Workspace. TRIGGER-10 retired (business migration replaced by Platform Separation). TRIGGER-14 cleaned up (Claude Restore moved, Phase 3 Event Sourcing preserved). Duplicate TRIGGER-03/TRIGGER-14 root-level entries removed. All triggers re-sequenced. | Why: OC2 arrival is the natural gate for all OC2-era actions. No point doing Claude Restore or Platform Separation on OC1 when hardware is about to change. Single master trigger with ordered sub-actions eliminates sequencing ambiguity. | Verified: JSON syntax valid. All 18 triggers preserved (plus QBR). TRIGGER-01 sub-actions in priority order. Retired trigger explicitly documented with replacement pointer. | Rollback: N/A
