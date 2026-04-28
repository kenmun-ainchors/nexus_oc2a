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
- **Tier 1 ($50):** If balance <= $50 AND tier1.triggered=false → alert Ken (8574109706) + Angie via Aria (8141152780) ONCE. Set triggered=true.
- **Tier 2 ($25):** If balance <= $25 → set activeTier=2. Alert Ken + Angie every 3rd response (tracked in cost-alert-state.json).
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

### Warden Escalations (check every 30 min)
- Check if state/warden-escalation-pending.json exists
- If it exists AND status = 'pending-yoda-action':
  - Read it immediately
  - Apply the recommended fix for each violation (edit openclaw.json, correct model)
  - Log a CHG entry for each remediation
  - Update warden-escalation-pending.json status to 'resolved-by-yoda'
  - Alert Ken via Telegram with: what drifted, what was fixed, CHG reference
  - State key: wardenEscalation

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
