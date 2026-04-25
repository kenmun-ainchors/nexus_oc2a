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

### Agent Health (check every 30 min)
- Read state/health-state.json — is gateway OK?
- Read state/agent-status.json — any agents in failed state?
- Alert if anything is degraded

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
