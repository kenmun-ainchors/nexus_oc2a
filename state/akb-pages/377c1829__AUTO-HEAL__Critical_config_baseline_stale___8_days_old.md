# [AUTO-HEAL] Critical config baseline stale — 8 days old

- **Notion ID:** `377c182953ff8155be58dcba91f98d31`
- **Status:** Backlog
- **Type:** US
- **Priority:** Medium
- **Category:** Platform
- **Sprint:** 
- **Created:** 
- **Last Edited:** 2026-06-06T15:02:00.000Z

## Notes

Auto-heal CHECK 12 (2026-06-07 01:00 AEST): critical-config-baseline.json is 8 days old. The baseline is the anti-drift reference for openclaw.json config, agent models, cron jobs, and PG tables. Without a fresh baseline, drift detection is unreliable. Fix: run scripts/capture-baseline.sh to regenerate. Consider adding baseline regeneration to auto-heal auto-fix bucket or scheduling separately.
