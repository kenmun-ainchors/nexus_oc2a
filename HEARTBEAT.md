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

### Ollama Cloud Credit Tracking (check every 2 hours)
- Read state/cost-state.json → apiBalance.remainingEstimate
- Track usage as informational only — Ollama Cloud is a fixed subscription, not a pay-as-you-go balance
- No alerts, no tiers — silent tracking only
- State key: lastChecks.costState

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

### Post-Deliverable Validation Alerts — TKT-0237 A3 (check every 30 min)
- Check if state/dod-validation-alert.json exists
- If it exists AND .alerts[] contains items with acknowledged=false:
  - Read each alert: ticketId, failedCheck, expectedPath, closedAt, detectedAt
  - Alert Ken immediately: "⚠️ DoD Validation failed: [ticketId] deliverable [expectedPath] missing. Closed [closedAt]."
  - Multiple alerts → list all in single Telegram message
  - Ken can acknowledge: set acknowledged=true to stop pinging (alert stays for record)
  - Auto-cleared by dod-validator.sh when deliverable restored
- State key: dodValidation

### Task Verification Alerts (check every 30 min)
- Check if state/task-verification-alert.json exists
- If it exists AND alerts array is non-empty:
  - Read each alert: task_id, title, agent, failed_deliverables, detected_at
  - Alert Ken immediately: "⚠️ Task verification failed: [title] ([task_id]) — [agent] reported done but deliverable missing: [failed_deliverables]"
  - Investigate and remediate (re-run task or manually create missing deliverable)
  - Clear the alert after Ken is notified and issue is resolved
  - Log CHG entry for each remediation
- State key: taskVerificationAlerts

### Allowlist Sync State (check every 30 min)
- Check state/allowlist-sync-state.json → if lastResult = 'changes-applied' AND lastSyncAt is recent (< 1hr ago): surface to Ken with the change summary
- TRIGGER-12 cron (6a059e9e) handles detection automatically — heartbeat only needs to surface if alert was missed
- If state/allowlist-sync-state.json is missing: run `zsh scripts/allowlist-sync.sh --source manual` to initialise

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

### Budget Check — TKT-0092 (check every 30 min)
- Run `zsh scripts/budget-check.sh --report`
- Read `state/budget-alert-state.json` for unacknowledged alerts
- **WARNING (≥alertAt threshold):** Surface to Ken at next natural interaction (non-urgent). Example: "⚠️ Agent `main` at 82% of daily budget ($65.60/$80)"
- **EXCEEDED:** Alert Ken via Telegram immediately: "🚨 Budget exceeded: agent `main` spent $82.50 vs $80.00 cap"
- After alerting, set `acknowledged: true` in the alert entry
- State key: `lastChecks.budgetCheck`

### Agile Ceremony Gate — NON-NEGOTIABLE (check every Monday morning)
⚠️ **Ken has explicitly asked to be held accountable to agile ceremonies before any sprint work begins.**

**Rule (locked 2026-05-11):** At the start of each sprint week (Monday), check if the prior week's ceremonies were completed:
- **Friday Sprint Review** — did it happen? Is it logged?
- **Sunday Sprint Planning** — did it happen? Is Sprint N committed and approved?

If EITHER ceremony was missed:
1. Flag to Ken immediately: "⚠️ Ceremony gap: [ceremony] for Sprint [N] was not completed. Run it now before starting sprint work?"
2. **Do not log any sprint items as started until Ken confirms ceremonies are done OR explicitly defers them**
3. Ken may say "defer" — that's valid. Log the deferral in sprint-current.json and proceed.
4. Ken may say "do it now" — run the ceremony inline before any other sprint work.

This is Ken's rule, not Yoda's suggestion. Enforce it.
- State key: lastChecks.ceremoniesThisWeek

---

### Open Decisions + Draft Docs — DoD Gate Check (check at sprint planning + sprint review)
- Read `state/open-decisions.json` → count decisions where status = "open"
- Read `state/draft-docs.json` → count drafts where status = "draft"
- At sprint planning (Sunday): surface ALL open decisions and draft docs to Ken — nothing can be marked Done until gates clear
- At sprint review (Friday): include gate status in sprint review section
- If any decision has urgency containing "P2 gate" AND sprint is within 3 sprints of P2 build — escalate immediately
- State key: lastChecks.doDGates

### Cron Health Check (check every 30 min)
- Run `bash scripts/cron-health-check.sh`
- If exit 1 OR `state/cron-health-alert.json` exists with `acknowledged: false`:
  - Alert Ken for each failure: ❌ **Cron failed:** `[name]` ([cronId]) — status: [status]
  - Mark `acknowledged: true` after alerting
- **Key rule:** A single failure on a daily cron = alert immediately. Do NOT wait for 3 failures.
- State key: lastChecks.cronHealth

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

### Auto-Heal NEEDS_KEN → Notion (check every morning after auto-heal run)
- Read state/auto-heal-[YESTERDAY].json → needs_ken array
- If needs_ken_count > 0: raise each item as a Notion page in **DB B: Auto-Heal (364c1829-53ff-81c0-9dbd-ff2c907d1a6b)**
- **Status: set to "Open"** — AUTO-HEAL items start open, can be reviewed and marked Resolved/False Positive
- Title format: [AUTO-HEAL] [item description]
- Category: infer from item text (Backup/Config Drift/API Balance/Memory/Cron/Auth/Other)
- Date: today's date
- Type: task | Notes: full item text
- After raising: send Telegram alert to Ken with count + summary (urgent items only)
- Do NOT flood DB A (Backlog) — AUTO-HEAL items belong in DB B, separate from sprint work

### Memory Maintenance (once per day, during low-traffic hours)
- Review recent memory/YYYY-MM-DD.md files
- Update MEMORY.md with anything significant
- Commit workspace changes to git

### End-of-Day Close
🚫 **HEARTBEAT NEVER TOUCHES EOD. FULL STOP.**
Journal is owned by cron `4d926b2c` (23:55 AEST).
Blog is owned by cron `a027fd60` (00:05 AEST).
Drive sync is owned by cron `c5a3911d` (23:00 AEST).
Heartbeat must NEVER create, update, or trigger journal/blog/drive-sync regardless of time, state, or any other condition.
Root cause of Day 16 journal corruption: heartbeat ran EOD at 15:27 AEST because dailyClose=null and time was not checked. Fixed 2026-05-11.

## State Tracking
State file: state/heartbeat-state.json

### Notion DB IDs (CHG-0401 3-DB architecture — corrected 2026-05-22)
- DB A (Backlog): 34dc1829-53ff-814b-8257-d3a3bf351d44 (API integration ID)
- DB B (Auto-Heal): 364c1829-53ff-81c0-9dbd-ff2c907d1a6b  ← AUTO-HEAL items go HERE
- DB C (Archive): 364c1829-53ff-818e-a783-ebafcb6a9880  ← closed tickets auto-archive HERE

### Ahsoka Pilot Completion Gate (check every heartbeat)
- Check `state/ahsoka-pilot-state.json`
- If `pilots.pilot1.status = "complete"` AND `pilots.pilot2.status = "complete"` AND `confirmationTriggered = false`:
  - Alert Ken immediately:
    > 🤍 **Ahsoka — Both Pilots Complete**
    > Pilot 1 (TKT-0082) ✅ and Pilot 2 (TKT-0083) ✅ are done.
    > **Ready for your final call:** Reply `APPROVED` to activate Ahsoka for business operations and notify Angie.
    > Or flag any issues for Yoda to fix first.
  - Set `confirmationTriggered = true` in the state file
  - Do NOT notify Angie until Ken explicitly says APPROVED
- State key: ahsokaPilot

### Google Drive EOD Sync
🚫 **HEARTBEAT NEVER TOUCHES DRIVE SYNC.**
Drive sync is owned by cron `c5a3911d` (00:30 AEST — runs after blog). Heartbeat must not run or duplicate it.

### OWL Compliance Self-Check (check every heartbeat — NON-NEGOTIABLE)
⚠️ **Platform-enforced via TKT-0228 + TKT-0237.** OWL applies to ALL models on MEDIUM+ currency work.

**Check:** Run `bash /Users/ainchorsangiefpl/.openclaw/workspace/scripts/owl-compliance-check.sh`
- If exit 1 (compliance <70%): read `state/owl-drift-alert.json` → surface to Ken via Telegram
- If exit 0: compliance OK, no action needed.
- State key: `lastChecks.owlCompliance`

**Automatic enforcement:**
- `scripts/owl-guard.sh` activates OWL at session start for MEDIUM+ work — including Yoda's webchat + Telegram sessions
- Yoda is NOT exempt. The orchestrator is audited by the same rules as every sub-agent.
- If Yoda's compliance drops below 70%, the same alert fires to Ken
- `owl-compliance-state.json` tracks every atom with model attribution
- TKT-0237 R05 (State Checking) audits OWL compliance in rule-audit.sh

**Self-check questions (model-agnostic):

**Self-check questions:**
- [ ] Did I pause before the last execution?
- [ ] Did I show my thinking to Ken?
- [ ] Did I assess risk before acting?
- [ ] Did I verify each atom before proceeding to the next?
- [ ] Did I stop on error or chain-react?

**Drift detection:**
- If Ken says "you're rushing" or "slow down" → **IMMEDIATE STOP**, recommit to OWL
- If I notice myself chaining 3+ atoms without pause → **SELF-CORRECT**, insert thinking block
- If error occurs and I immediately try fix #2 without assessing → **VIOLATION**, log to LESSONS.md

**Execution:**
OWL Compliance: 100% (Tier 1, 1 atoms)
✅ Compliant
Daily: 68% | Drifts today: 1
OWL Compliance: 68% (daily: 68%)
Responses today: 3 | Drifts: 1
⚠️ LOW COMPLIANCE — Review needed

**State key:** owl-compliance-state.json
**Logged in:** LESSONS.md L-039 (OWL drift), TKT-0229 (OWL drift prevention)

### EOD Blog Verification (check every morning at 06:00 AEST)
🚨 OVERRIDES the "HEARTBEAT NEVER TOUCHES EOD" rule — this is a safety check, not EOD generation.
- Check: does `/Users/ainchorsangiefpl/.openclaw/workspace/canvas/documents/ainchors-YYYY-MM-DD/index.html` exist for YESTERDAY's date?
- If MISSING: alert Ken via Telegram: "🚨 Blog missing: no blog file produced for [date]. Blog cron reported OK but no output file."
- If EXISTS: no action needed. Do NOT read or modify the file — just verify it exists.
- State key: lastChecks.blogVerification
- Raised: PIA 2026-05-23 (12-day silent blog failure)

### Journal Completeness Check (check at 23:00 AEST)
🚨 OVERRIDES the "HEARTBEAT NEVER TOUCHES EOD" rule — this is a safety check, not EOD generation.
- Check: does `/Users/ainchorsangiefpl/.openclaw/workspace/memory/journal-YYYY-MM-DD.md` exist for TODAY's date and is >500 bytes?
- If MISSING or EMPTY: alert Ken via Telegram: "⚠️ Journal may be incomplete: today's journal file is [missing/undersized]. Journal incremental writer may be failing."
- If EXISTS and >500 bytes: no action.
- State key: lastChecks.journalCompleteness
- Raised: PIA 2026-05-23 (journal incremental writer timeout)
