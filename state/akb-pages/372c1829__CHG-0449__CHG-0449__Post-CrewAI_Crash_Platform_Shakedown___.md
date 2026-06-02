# [CHG-0449] CHG-0449: Post-CrewAI Crash Platform Shakedown — Findings, Fixes & Regression Learnings

- **Notion ID:** `372c182953ff814ca678edee3a3e284f`
- **Status:** Done
- **Type:** CHG
- **Priority:** 
- **Category:** 
- **Sprint:** 
- **Created:** 2026-06-01
- **Last Edited:** 2026-06-01T01:35:00.000Z

## Notes

Type: infra | Source: incident-recovery | Trigger: CrewAI setup on 2026-05-31 crashed OpenClaw, corrupted Homebrew (node, llhttp). Ken updated/upgraded/reinstalled to restore. Full shakedown initiated. | Changed: Platform shakedown performed: Gateway OK, PG intact (31 tables/258 tickets), Colima/Docker OK, MinIO OK, Tailscale OK, Telegram OK, Notion OK. 3 issues found: (1) 2 crons failed (9ce7f295 TZ Drift Monitor + 3c279099 Morning Stand-Up) due to Homebrew path breakage, (2) docker+tailscale unlinked in Brew, (3) backup stale 47h. Docker CLI symlink manually recreated. TKT-0332 raised for fixes. TKT-0333 raised to package learnings into regression suite. | Why: CrewAI venv installation pulled in incompatible dependencies that collided with Homebrew-managed node/llhttp. Recovery required brew update/upgrade/reinstall. Shakedown verifies no platform data was lost. | Verified: All 14 agents intact, all RULES.md present, PG fully queryable, 527 sessions no orphans, all integrations responding. Diagnostics script ran (crashed mid-run but core phases completed). | Rollback: N/A — no config changes made. Docker symlink fix is reversible.
