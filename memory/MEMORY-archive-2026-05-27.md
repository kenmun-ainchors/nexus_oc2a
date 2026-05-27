# MEMORY Archive — 2026-05-27
# Archived from MEMORY.md to bring under 10,000 byte limit

## kimi Policy — DECOMMISSIONED 2026-05-26 (preserved for historical record)
DeepSeek is now permanent primary model. kimi remains as fallback only.
- **Original policy (2026-05-15):** kimi = standup only (telegram + email cron)
- **Original restriction:** NEVER use kimi for complex orchestration, multi-ticket routing, state tracking, CHG decisions
- **INCIDENT CONTEXT (2026-05-15):** Claude API credits depleted unexpectedly (CHG-0348/0349). Emergency: all 12 agents switched to kimi→deepseek-pro fallback 17:19 AEST. Reverted 14:47 AEST (CHG-0336) after Sonnet restored. kimi confined to standup only going forward. Root cause investigation: TKT-0165 (cost tracking gaps), TKT-0175 (ephemeral session capture). Cost balance recovered via auto-reload.
