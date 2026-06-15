# Heartbeat Tasks
# Runs every 30 minutes in the main session.
# Keep this lean — state keys + conditions + actions only.
# Procedures live in the scripts they reference, not here.
# Alert routing: see skill at `infra/sandbox/seed/skills/telegram/SKILL.md`

## Checks

### Email (every 2h)
- Scan kenmun@ainchors.com for unread urgent — client, Angie, marked urgent
- State key: lastChecks.email

### Calendar (every 2h)
- Any events in next 2h? Alert Ken if < 30 min with no prior notice
- State key: lastChecks.calendar

### Delegated Auth Health (every 4h — TKT-0336)
- Run: `zsh scripts/check-delegated-auth.sh --json`
- If allValid=false: alert Ken with list of accounts needing re-auth
- State key: lastChecks.delegatedAuth

### Ollama Cloud Credit Tracking (every 2h) — DEPRECATED 2026-06-15
- **Billing model change (Ken 13:23 AEST):** Monthly turns-limit, NOT API credit.
- Old tracking: read `state/cost-state.json → apiBalance.remainingEstimate` (informational only — fixed subscription).
- New tracking: `state/cost-state.json → turnsLimit` (pending Ken input on monthly budget number).
- Spend alerts switched from USD tiers to turns-based (provisional).
- Auto-reload deactivated.
- Cost model: see skill at `infra/sandbox/seed/skills/model-routing/SKILL.md`
- State key: lastChecks.costState
- CHG ref: see billingModelHistory in cost-state.json

### Async Task Watchdog (every 30 min)
- Run: `scripts/task-watchdog.sh`
- If state/task-stall-alert.json exists and is new → alert Ken (task ID, goal, last step, stall duration)
- State key: lastChecks.taskWatchdog

### Agent Health (every 30 min)
- Read state/health-state.json, state/agent-status.json
- Alert if gateway degraded or any agent in failed state

### Aria CREST Compliance Checkpoint (every 4h — TKT-0383 L3)
- Run: `bash scripts/aria-crest-check.sh`
- If state/aria-crest-alert.json exists → alert Ken with violation details
- State key: lastChecks.ariaCrest
- Catches: skipped Verify phases, missing RVEV traces, abandoned sub-crests, pro model overuse
  - Pro model policy: see skill at `infra/sandbox/seed/skills/model-routing/SKILL.md`

### Standby Mode & Outage Banner (every heartbeat)
- If state/standby-mode.json exists → include standby banner in next response to Ken
- If state/system-banner.json active=true → display it
- Auto-cleared by health-check.sh on recovery
- State key: standbyMode

### Post-Deliverable Validation (every 30 min — TKT-0237 A3)
- If state/dod-validation-alert.json exists with unacknowledged alerts → alert Ken
- State key: dodValidation

### Task Verification (every 30 min)
- If state/task-verification-alert.json exists with non-empty alerts → alert Ken
- State key: taskVerificationAlerts

### CHG Trigger Monitoring (every heartbeat)
- Read state/chg-triggers.json
- Active triggers: TRIGGER-01/02/03 (OC2), TRIGGER-05 (PoC), TRIGGER-07 (P2 client), TRIGGER-10 (business migration)
- TRIGGER-04/06/08/09 = automated crons — no heartbeat check needed

### Budget Check — TKT-0092 (every 30 min)
- Run: `zsh scripts/budget-check.sh --report`
- WARN (≥alertAt): surface at next natural interaction. EXCEEDED: Telegram immediately
- State key: lastChecks.budgetCheck

### Agile Ceremony Gate — NON-NEGOTIABLE (every Monday morning)
- Check: Friday Sprint Review + Sunday Sprint Planning completed last week?
- If missed: flag Ken. Do not start sprint work until Ken confirms or defers.
- State key: lastChecks.ceremoniesThisWeek

### Open Decisions + Draft Docs — DoD Gate Check (sprint planning + sprint review)
- Read state/open-decisions.json + state/draft-docs.json
- Surface open items at planning. Escalate if P2-gate decision within 3 sprints of P2 build.
- State key: lastChecks.doDGates

### Cron Health Check (every 30 min)
- Run: `bash scripts/cron-health-check.sh`
- If exit 1 or state/cron-health-alert.json unacknowledged → alert Ken
- Single failure = alert immediately. Never wait for 3.
- State key: lastChecks.cronHealth

### Cron Dead-Letter Alerts (every 30 min)
- If state/cron-dead-letter-alert.json has unacknowledged entries → alert Ken
- State key: lastChecks.cronDeadLetter

### Auto-Heal NEEDS_KEN → Notion (every morning after auto-heal)
- Read state/auto-heal-[YESTERDAY].json → needs_ken array
- Raise each item to Notion DB B (Auto-Heal). Telegram alert for urgent items.
- State key: needsKenNotion

### Memory Maintenance (once per day, low-traffic hours)
- Review daily memory files, update MEMORY.md, git commit

### End-of-Day Close
🚫 HEARTBEAT NEVER TOUCHES EOD. Journal (4d926b2c), Blog (a027fd60), Drive (c5a3911d) — all cron-owned.

### OWL Compliance Self-Check (every heartbeat)
- Run: `bash scripts/owl-compliance-check.sh`. Alert Ken if exit 1.
- State key: lastChecks.owlCompliance

### EOD Blog Verification (every morning at 06:00 AEST)
- Verify blog file exists for yesterday's date at ~/.openclaw/canvas/documents/ainchors-YYYY-MM-DD/index.html
- Missing → alert Ken
- State key: lastChecks.blogVerification

### Journal Completeness Check (every night at 23:00 AEST)
- Verify journal file exists for today and is > 500 bytes
- Missing/empty → alert Ken
- State key: lastChecks.journalCompleteness

## State Tracking
State file: state/heartbeat-state.json
