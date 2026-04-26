# Infra Agent — Design & State
_Last updated: 2026-04-26 | Status: active_

## Identity
- **Agent ID**: infra
- **Role**: Infrastructure Monitoring & Recovery Agent
- **Owner**: Yoda (main session)
- **Trigger**: system-event (cron every 5 min health check, gateway restart hook, watchdog every 30 min)

---

## Responsibilities

### Primary
1. **Gateway health monitoring** — curl localhost:18789 every 5 min; alert Ken on consecutive failures
2. **Ollama process monitoring** — pgrep ollama; alert if process missing
3. **Disk space monitoring** — df checks; alert if any volume >85% full
4. **State file freshness** — flag health-state.json / cost-state.json if not updated in >15 min
5. **Stale lock file detection & cleanup** — remove .lock files older than 5 min on startup and on health check
6. **Task spawn detection** — detect tasks created but no checkpoint after 15 min (spawn-but-not-started)
7. **Post-restart recovery** — run startup-recovery.sh after every gateway restart; notify Ken

### Secondary
- Log all events to ~/Backups/ainchors/logs/health.log
- Write structured state to state/health-state.json after each run
- Write startup-report.json after each gateway restart
- Write /tmp/startup-alert.txt for Yoda main session to dispatch to Ken

---

## Trigger Conditions

| Trigger | Action |
|---------|--------|
| Gateway restart / boot | Run startup-recovery.sh |
| Every 5 minutes (cron system-event) | Run health-check.sh |
| Every 30 minutes (heartbeat) | Run task-watchdog.sh |
| health-state.json age > 10 min | Flag as stale, escalate to Ken |
| Consecutive gateway failures >= 2 | Alert Ken via Telegram |
| Ollama process missing | Alert Ken — degraded state |
| Disk >85% | Alert Ken — degraded state |
| Stale lock file detected (>5 min) | Auto-clear + log |
| Task pending with no checkpoint >15 min | Alert Ken — spawn-queue issue |

---

## Escalation Rules

### Level 0 — Self-heal (no notification)
- Clear stale lock files
- Auto-restart gateway on first failure (launchctl kickstart)
- Reset failure counters on recovery

### Level 1 — Notify Ken (Telegram)
- Gateway unreachable after 2 consecutive failures
- Ollama process not found
- Disk >85% on any volume
- health-state.json or cost-state.json age >15 min
- Task pending >15 min with no checkpoint (spawn queue problem)
- Post-restart summary (always)

### Level 2 — Critical (Telegram + log + state=critical)
- Gateway unreachable after 6+ consecutive failures
- Multiple services down simultaneously
- Disk >95%

---

## Known Failure Patterns

### PATTERN-001: Cron Auth Failure (Ollama/isolated session)
- **Discovered**: 2026-04-26 power trip incident
- **Symptom**: Health check cron using Gemma4/Ollama in isolated session context → "No API key found for provider ollama" → 6 consecutive failures → 1hr backoff → monitoring dark for hours
- **Root cause**: Ollama auth is only configured in main session context, not isolated sessions
- **Fix applied**: Health check cron moved to main session system-event (not isolated)
- **Detection**: If health-state.json stops updating for >10 min AND gateway appears up, suspect cron auth failure
- **Prevention**: Never run health check crons in isolated session contexts; always use main session system-event

### PATTERN-002: Lock Files Surviving Crashes
- **Discovered**: 2026-04-26 power trip incident
- **Symptom**: .lock files from pre-crash persist on recovery, block state writes
- **Fix**: startup-recovery.sh clears all .lock files in workspace on every boot
- **Detection**: Check state/*.lock on startup; log any found

### PATTERN-003: Stale Health State (invisible monitoring gap)
- **Discovered**: 2026-04-26 power trip incident
- **Symptom**: health-state.json last updated 10:05am, power out at unknown time, no update until 17:39 restart. Gap invisible.
- **Fix**: health-check.sh now checks its own state file age; flags if >15 min since last successful check
- **Detection**: Compare health-state.json mtime to current time on every run

### PATTERN-004: Sub-agent Spawn Queue Delay
- **Discovered**: 2026-04-26 power trip incident
- **Symptom**: Sub-agent spawned at 12:38, didn't execute until 17:39 (5hr delay). No visibility.
- **Fix**: task-watchdog.sh now detects tasks with status "pending" and no checkpoint after 15 min
- **Detection**: async-tasks.json — compare task createdAt vs lastCheckpoint; alert if gap >15 min

---

## State Files
- `state/health-state.json` — latest health check result
- `state/startup-report.json` — latest post-restart summary
- `state/task-stall-alert.json` — watchdog stall alerts
- `/tmp/startup-alert.txt` — Telegram message pending send (transient)

---

## Asset Registry Monitoring

### Responsibility: Asset Registry — Weekly Evergreen Review
- **Trigger:** Sunday 17:00 Melbourne time (OpenClaw cron ID: e8b17c79-89e0-443b-996b-ee48de874b2b)
- **Script:** `~/.openclaw/workspace/scripts/asset-review.sh`
- **Registry:** `~/.openclaw/workspace/state/asset-registry.json`
- **Notion DB:** Asset Registry — ID `34ec182953ff810f8af9c8f9d5468400` (under Agent Operations)
- **Log:** `~/Backups/ainchors/logs/asset-review.log`

### What the cron does:
1. Runs `asset-review.sh` to check all 53 registered assets
2. Compares file mtime vs `last_updated` in registry
3. Flags assets with newer mtime as `Needs Review` in registry + Notion
4. Reviews flagged assets against `memory/shared/decisions.md`
5. Updates assets to reflect current state
6. Updates Notion with new `Last Updated` and `Status`
7. Logs summary to asset-review.log

### Escalation Rule:
- If any asset has `Status=Stale` for >2 weeks → alert Ken immediately
- Stale threshold: `last_updated` >14 days old AND `status=Stale`
- Alert method: note in next heartbeat report + flag in Notion

---

## Current Queue
- None

## Last Run
- 2026-04-26 (initial design + scripts deployed)
- 2026-04-26 (asset registry built — 53 assets catalogued, Notion DB seeded, weekly cron activated)
