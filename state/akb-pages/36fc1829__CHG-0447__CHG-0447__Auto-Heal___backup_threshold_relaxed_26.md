# [CHG-0447] CHG-0447: Auto-Heal — backup threshold relaxed 26h→30h + Anthropic balance suppressed until TRIGGER-01

- **Notion ID:** `36fc182953ff81019a78f5463418e8c7`
- **Status:** Done
- **Type:** CHG
- **Priority:** 
- **Category:** 
- **Sprint:** 
- **Created:** 2026-05-29
- **Last Edited:** 2026-05-29T12:12:00.000Z

## Notes

Type: script | Source: ken-prompt | Trigger: Ken acknowledged both auto-heal needs_ken items 2026-05-29 22:12 | Changed: auto-heal.sh CHECK 3: backup freshness threshold relaxed from 26h→30h to allow for cron drift. CHECK 9: Anthropic API balance check suppressed while TRIGGER-01 status=pending — re-enables automatically when TRIGGER-01 fires (OC2 arrival → CLAUDE RESTORE). Ollama Cloud is /mo fixed sub, not pay-as-you-go. | Why: Item 1: 26h threshold too tight, 3h overage on 29h-old backup. TKT-0326 covers real fix. Item 2: Anthropic balance is intentionally /bin/zsh until OC2 arrival — suppressing eliminates false-positive alert until then. | Verified: grep confirms 30h threshold applied. CLAUDE_SUPPRESS gate reads TRIGGER-01 status from chg-triggers.json. auto-heal-current.json acknowledged with resolution notes. | Rollback: N/A
