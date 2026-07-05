# Heartbeat Tasks
# Runs every 30 minutes in the main session.
# Keep this lean — state keys + conditions + actions only.
# Procedures live in the scripts they reference, not here.
# CHG-0799: platform/cron/infra/business-impacting alerts route to both Ken (8574109706) and Angie (8141152780)
# Alert routing: load skill `bash scripts/skill-load.sh telegram`

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

### Ollama Weekly Request Tracking (every 2h) — ACTIVE 2026-06-16
- **Formula confirmed (Ken 19:14 AEST):** 30,000 requests/week flat count, all models equal weight.
- **Window:** Monday 10:00 AEST → next Monday 10:00 AEST.
- Read: `state/cost-state.json → turnsLimit` (currentPct, requestsRemaining, burnRate).
- Alert thresholds and routing: load skill `bash scripts/skill-load.sh telegram`.
- Daily Burn Alert cron (ca5d5e50, 20:00 AEST) handles threshold alerts.
- State key: lastChecks.costState
- CHG ref: CHG-0603 (2026-06-16 19:14 AEST)

### Async Task Watchdog (every 30 min)
- Run: `scripts/task-watchdog.sh`
- If state/task-stall-alert.json exists and is new → alert Ken (task ID, goal, last step, stall duration)
- State key: lastChecks.taskWatchdog

### Agent Health (every 30 min)
- Read state/health-state.json, state/agent-status.json
- Alert if gateway degraded or any agent in failed state

### Session Model Drift Check (every heartbeat — TKT-0547 Atom 1)
- Run: `bash scripts/check-session-model.sh --json`
- If exit 1 (drift): immediately reset session model to primary via `session_status model=<expected>`
- If state/session-model-drift-alert.json exists with acknowledged=false → alert Ken
- Also check state/pending-model-reset.json — if status=pending and resetAt is past, schedule the reset cron
- State key: lastChecks.sessionModelDrift
- CHG ref: TKT-0547 (2026-06-20)

### Aria CREST Compliance Checkpoint (every 4h — TKT-0383 L3)
- Run: `bash scripts/aria-crest-check.sh`
- If state/aria-crest-alert.json exists → alert Ken with violation details
- State key: lastChecks.ariaCrest
- Catches: skipped Verify phases, missing RVEV traces, abandoned sub-crests, pro model overuse
  - Pro model policy: load skill `bash scripts/skill-load.sh model-routing`

### Main Session Context Watchdog (every heartbeat)
- Run: `bash scripts/main-session-context-watchdog.sh`
- Writes `state/main-session-context-ok.json` or `state/main-session-context-reset.json`
- State key: `lastChecks.mainSessionContext`
- CHG ref: CHG-0828 (2026-07-05) — prevents CHG-0818 recurrence by auto-resetting dashboard session before context overflow

### Main-Session / Subagent Resume Registry (every heartbeat — TKT-0319 Atom 5)
- Run: `bash scripts/main-session-resume-check.sh`
- If `state/main-session-resume-needs-ken.json` exists with unacknowledged tasks → surface to Ken (task ID, description, checkpoint, agent).
- State key: lastChecks.mainSessionResume

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
- Run USD-based: `zsh scripts/budget-check.sh --report` (preserved for Anthropic/Claude day)
- Run request-based: `zsh scripts/request-budget-check.sh --report` (Ollama weekly request tracking)
- Alert routing: load skill `bash scripts/skill-load.sh telegram`
- State keys: lastChecks.budgetCheck, lastChecks.requestBudgetCheck

### Agile Ceremony Gate — NON-NEGOTIABLE (every Monday morning)
- Load skill: `bash scripts/skill-load.sh agile`
- Run `bash agent-skills/agile/scripts/sprint-review.sh` for the just-closed sprint if review report not yet generated.
- Check: Friday Sprint Review + Sunday Sprint Planning completed last week?
- If missed: flag Ken. Do not start sprint work until Ken confirms or defers.
- State key: lastChecks.ceremoniesThisWeek

### Open Decisions + Draft Docs — DoD Gate Check (sprint planning + sprint review)
- Load skill: `bash scripts/skill-load.sh crest` then `bash scripts/skill-load.sh agile`
- Read state/open-decisions.json + state/draft-docs.json
- Surface open items at planning and review. Escalate if P2-gate decision within 3 sprints of P2 build.
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
- Raise each item to Notion DB B (Auto-Heal). Alert routing: load skill `bash scripts/skill-load.sh telegram`.
- State key: needsKenNotion

### Memory Maintenance (once per day, low-traffic hours)
- Review daily memory files, update MEMORY.md, git commit

### SOUL / AGENTS Hygiene Gate (sprint review + QBR) — TKT-0541
- Run: `bash scripts/soul-agents-hygiene-check.sh` (script to be delivered under TKT-0541).
- Check: every agent `SOUL.md` ≤ 5K chars; every active agent has a corresponding `AGENTS.md`; flag rule-creep moved back into SOUL.
- Gate: blocked if any SOUL > 5K or missing AGENTS.md for an active runtime agent.
- Runs automatically at Sprint Review and QBR ceremonies.
- State key: lastChecks.soulAgentsHygiene

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
