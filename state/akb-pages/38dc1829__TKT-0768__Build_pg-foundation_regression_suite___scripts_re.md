# [TKT-0768] Build pg-foundation regression suite + scripts/regression-runner.sh

- **Notion ID:** `38dc182953ff81a3bf7cd1a48d0ed4f0`
- **Status:** Backlog
- **Type:** build
- **Priority:** High
- **Category:** Platform
- **Sprint:** 
- **Created:** 2026-06-28T00:38:00.000+10:00
- **Last Edited:** 2026-06-28T00:39:00.000Z

## Notes

Create a foundational regression runner script scripts/regression-runner.sh that accepts --suite pg-foundation and runs core platform checks (health-check.sh, model-drift-check.sh, cron-health-check.sh, check-delegated-auth.sh, budget-check.sh). Exits non-zero on any failure and integrates with CI/nightly auto-heal.
