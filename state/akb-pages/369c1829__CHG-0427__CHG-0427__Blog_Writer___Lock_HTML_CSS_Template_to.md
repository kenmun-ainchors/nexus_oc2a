# [CHG-0427] CHG-0427: Blog Writer — Lock HTML/CSS Template to Prevent Style Drift

- **Notion ID:** `369c182953ff8148aa72e227877c064a`
- **Status:** Done
- **Type:** CHG
- **Priority:** 
- **Category:** 
- **Sprint:** 
- **Created:** 2026-05-24
- **Last Edited:** 2026-05-23T21:55:00.000Z

## Notes

Type: cron | Source: ken-prompt | Trigger: TKT-0277 — Ken noticed Day 29 blog style drifted from approved Day 23 template (purple vs amber, missing metrics, missing sections) | Changed: Updated blog writer cron (a027fd60) to mandate copying CSS from the locked Day 23 reference template. Added mandatory template compliance checklist (7 items) that must pass BEFORE the triad governance gate. CSS is now immutable — only content between body tags changes. | Why: Blog writer (gemma4) was improvising CSS each run, producing different color schemes, different class structures, missing required sections (metrics grid, cost trend, What Broke). The locked BlogFormat.md describes content rules but doesn't contain the HTML/CSS template. The approved Day 23 blog is now the canonical CSS reference. | Verified: Cron updated with locked CSS reference + compliance checklist. Day 23 template confirmed as approved reference. | Rollback: N/A
