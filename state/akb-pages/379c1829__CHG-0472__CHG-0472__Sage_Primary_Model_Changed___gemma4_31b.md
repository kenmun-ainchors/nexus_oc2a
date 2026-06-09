# [CHG-0472] CHG-0472: Sage Primary Model Changed — gemma4:31b-cloud → deepseek-v4-pro:cloud

- **Notion ID:** `379c182953ff812d936dfb5378892136`
- **Status:** Done
- **Type:** CHG
- **Priority:** 
- **Category:** 
- **Sprint:** 
- **Created:** 2026-06-08
- **Last Edited:** 2026-06-08T12:01:00.000Z

## Notes

Type: agent | Source: ken-prompt | Trigger: Ken Mun instruction — Sage gemma4 context-overflow failures (4 failed QA reviews in 18 min), 1.4M token exhaustion | Changed: openclaw.json qa agent: primary=ollama/deepseek-v4-pro:cloud, fallbacks=[gemma4:31b-cloud, kimi-k2.6:cloud] | Why: gemma4:31b-cloud exceeded context window on mirror writer review (10 files, 1122 lines). deepseek-v4-pro has larger context and completes QA reviews reliably | Verified: openclaw.json qa agent model confirmed; Warden 15-min drift check will detect on next cycle; config backup taken | Rollback: N/A
