# [CHG-0404] Async Background Execution Rule — webchat must never be blocked by long-running tasks

- **Notion ID:** `364c182953ff816b82efea5067b3a44f`
- **Status:** Done
- **Type:** CHG
- **Priority:** 
- **Category:** 
- **Sprint:** 
- **Created:** 2026-05-18
- **Last Edited:** 2026-05-18T11:39:00.000Z

## Notes

Type: rule | Source: ken-prompt | Trigger: Ken reported webchat was blocked from 1:20p during DB migration — session went into steer, couldn't send messages | Changed: RULES.md: new NON-NEGOTIABLE rule CHG-0405 — tasks >30s must use sessions_spawn. AGENTS.md: added 'Don't block webchat' to Red Lines. SOUL.md: non-negotiable #11 added. scripts/async-task.sh: created async task queue helper. | Why: The Notion migration (664 pages × API calls) ran synchronously, blocking webchat for ~13 minutes. Ken couldn't interact during that time. All future long-running ops must be backgrounded. | Verified: RULES.md, AGENTS.md, SOUL.md updated. async-task.sh created with register/complete/status commands. | Rollback: N/A
