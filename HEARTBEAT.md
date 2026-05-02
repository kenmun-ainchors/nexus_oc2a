# Heartbeat Tasks
# Runs every 30 minutes in the main session.
# Keep this lean — only what's worth checking regularly.

## Checks (rotate, don't do all every time)

### Email (check every 2 hours)
- Once Gmail is connected: scan kenmun@ainchors.com for unread urgent emails
- Flag: client inquiries, anything from Angie, anything marked urgent
- State key: lastChecks.email

### Calendar (check every 2 hours)
- Once Google Calendar connected: any events in next 2 hours?
- Alert Ken if event starts in < 30 minutes with no prior notice
- State key: lastChecks.calendar

### API Balance — 3-Tier Alert System (check every 30 min)
- Read state/cost-state.json → apiBalance.remainingEstimate
- Read state/cost-alert-state.json → activeTier, tier states
- **Tier 1 ($80):** If balance <= $80 AND tier1.triggered=false → alert Ken (8574109706) directly + send to Angie via sessions_send to Aria session (NOT direct Telegram — Angie must receive via @AInchorsAriaBot). ONCE. Set triggered=true.
- **Tier 2 ($40):** If balance <= $40 → set activeTier=2. Alert Ken directly + Angie via Aria session every 3rd response.
- **Tier 3 ($10):** If balance <= $10 → set activeTier=3, tier3.active=true. PAUSE before every request. Alert Ken + Angie. Require explicit acknowledgement before proceeding.
- Alert format and message templates in RULES.md Credit Alert Rules section.
- State key: cost-alert-state.json

### Async Task Watchdog (check every 30 min)
- Run `scripts/task-watchdog.sh`
- If `state/task-stall-alert.json` exists and is new → alert Ken immediately with task ID, goal, last step, stall duration
- Options to present Ken: resume task | cancel task | wait longer
- Delete alert file after notifying Ken
- State key: lastChecks.taskWatchdog

### Agent Health (check every 30 min)
- Read state/health-state.json — is gateway OK?
- Read state/agent-status.json — any agents in failed state?
- Alert if anything is degraded

### Standby Mode & Outage Banner (check every heartbeat)
- Check if state/standby-mode.json exists
- If it does: **IMMEDIATELY** include this banner at the top of the next response to Ken:
  > ⚠️ **STANDBY MODE ACTIVE** — Anthropic API unavailable since [since]. Fallback: [model]. Check billing at console.anthropic.com or run `zsh scripts/validate-fallback-chain.sh`
- Check state/system-banner.json — if active=true, display it
- When Anthropic recovers, files are auto-cleared by health-check.sh
- State key: standbyMode

### Task Verification Alerts (check every 30 min)
- Check if state/task-verification-alert.json exists
- If it exists AND alerts array is non-empty:
  - Read each alert: task_id, title, agent, failed_deliverables, detected_at
  - Alert Ken immediately: "⚠️ Task verification failed: [title] ([task_id]) — [agent] reported done but deliverable missing: [failed_deliverables]"
  - Investigate and remediate (re-run task or manually create missing deliverable)
  - Clear the alert after Ken is notified and issue is resolved
  - Log CHG entry for each remediation
- State key: taskVerificationAlerts

### CHG Trigger Monitoring (check every heartbeat)
- Read state/chg-triggers.json
- **TRIGGER-01/02/03** (OC2 arrival, HA live, Gemma4 validated): If Ken mentions hardware arrived or OC2 online → raise CHG immediately, execute setup sequence
- **TRIGGER-05** (PoC PASS): Check if poc sub-agent has completed. If chg-triggers.json TRIGGER-05 status = 'passed' → surface to Ken for Phase 6 approval
- **TRIGGER-07** (First P2 client): If Aria reports first client onboarded → run S1-S7 audit, execute onboarding checklist
- **TRIGGER-10** (Business migration): If OC2 live + Angie signals business ready → initiate migration plan
- Note: TRIGGER-04/06 = automated cron (6bd53c89). TRIGGER-08 = cost-tracker.sh. TRIGGER-09 = Warden. These do NOT need heartbeat checks.

### Warden Escalations (check every 30 min)
- Check if state/warden-escalation-pending.json exists
- If it exists AND status = 'pending-yoda-action':
  - Read it immediately
  - Apply the recommended fix for each violation (edit openclaw.json, correct model)
  - Log a CHG entry for each remediation
  - Update warden-escalation-pending.json status to 'resolved-by-yoda'
  - Alert Ken via Telegram with: what drifted, what was fixed, CHG reference
  - State key: wardenEscalation

### Cron Dead-Letter Alerts (check every 30 min)
- Check if `state/cron-dead-letter-alert.json` exists
- If it exists and has any entry with `acknowledged = false`:
  - For each unacknowledged entry, alert Ken:
    > ⚠️ **Cron dead-lettered:** `[name]` ([cronId]) — **[failCount] failures** in 1h
    > Last error: [lastError]
    > **Recommendation:** Disable or fix cron before next run to stop API burn. Check cron jobs.json for this ID.
  - After notifying Ken, mark all entries as acknowledged: set `acknowledged: true` in the JSON
  - Do NOT delete the file (auto-heal.sh manages cleanup)
- State key: lastChecks.cronDeadLetter

### Memory Maintenance (once per day, during low-traffic hours)
- Review recent memory/YYYY-MM-DD.md files
- Update MEMORY.md with anything significant
- Commit workspace changes to git

### End-of-Day Close (check at 23:30–23:59)
- Has journal been created today? Check: memory/journal-YYYY-MM-DD.md
- Has blog post been created today? Check: canvas/documents/ainchors-YYYY-MM-DD/index.html
- If EITHER is missing — create both now before midnight
- Use verbatim prompts from today's session for the journal
- State key: lastChecks.dailyClose

## State Tracking
State file: state/heartbeat-state.json
