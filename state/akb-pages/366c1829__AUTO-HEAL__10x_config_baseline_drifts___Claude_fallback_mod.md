# [AUTO-HEAL] 10x config baseline drifts — Claude fallback models (expected)

- **Notion ID:** `366c182953ff8134b117ed290ee93fc6`
- **Status:** Backlog
- **Type:** task
- **Priority:** Medium
- **Category:** Platform
- **Sprint:** 
- **Created:** 
- **Last Edited:** 2026-05-20T15:02:00.000Z

## Notes

10 config baseline items show drift from Claude-era expected values to current fallback models (deepseek-pro/gemma4-cloud). These are INTENTIONAL — Claude API credits depleted (CHG-0349 CONSERVATIVE MODE). Drifts: main/aria primary=deepseek-pro (vs Sonnet), default primary=gemma4-cloud (vs Haiku), fallbacks count=2 (vs 1), shield/lex/sage/warden primary=gemma4-cloud (vs Haiku), Haiku 4.5 not in models, gemma4:31b-cloud missing from globalAllowedModels. DO NOT FIX until CLAUDE RESTORE. Update critical-config-baseline.json to reflect fallback-era expected values, or acknowledge these as known/intentional.
