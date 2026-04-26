# RULES.md — AInchors Operational Rules
_Full procedure text. Referenced by SOUL.md. Updated as rules evolve._
_Last updated: 2026-04-26_

---

## PRE-RISKY-OP CHECKPOINT (NON-NEGOTIABLE — APPROVED 2026-04-26)

Before triggering ANY operation that could break, restart, or interrupt OpenClaw — including but not limited to:
- `openclaw update`
- `openclaw gateway restart`
- Major config changes
- npm/brew upgrades that touch OpenClaw dependencies

**STOP. Do this first:**
1. Flush all in-progress work to persistent files (MEMORY.md, memory/YYYY-MM-DD.md)
2. Write all decisions made this session to decisions.md
3. Update Notion with current sprint status
4. Git commit the workspace
5. Clear stale plugin-runtime-deps: `rm -rf ~/.openclaw/plugin-runtime-deps/openclaw-unknown-* 2>/dev/null; ls ~/.openclaw/plugin-runtime-deps/` — confirm only one versioned dir remains
6. Confirm to Ken: "Checkpoint saved. Safe to proceed."

Only THEN execute the risky operation.

**Post-op:** Run `bash scripts/pvt.sh` — all 9/9 checks must pass before resuming normal operations.

**Why:** INC-20260426-002 (SIGKILL context loss, 52 min) and INC-20260426-003 (ENOTEMPTY crash loop, 116 min) both caused by skipping pre-op checks.

---

## ASYNC EXECUTION MODEL (APPROVED 2026-04-26)

Full doc: `~/Documents/AInchors/Operations/AsyncExecution.md`

- **Rule 1:** Tasks >2 min or >3 steps → spawn isolated sub-agent. Main session stays free for Ken.
- **Rule 2:** Every task gets a TASK file (`handoff/TASK-{ID}.md` via `scripts/task-create.sh`). Single source of truth.
- **Rule 3:** Checkpoint after every step (`scripts/task-checkpoint.sh`). Write BEFORE moving on. If agent dies, next agent resumes from last checkpoint.
- **Rule 4:** Notify Ken at: task start, 50% complete, done or blocked. Never on every step.
- **Rule 5:** Watchdog runs `scripts/task-watchdog.sh` every 30 min. Stalled >30 min → alert Ken with options: resume | cancel | wait.
- **Rule 6:** Resume: read TASK file → find last checkpoint → spawn sub-agent → continue. Never restart from scratch.
- **Rule 7:** Max 2 retries per step. If fails again → mark `blocked`, notify Ken, await decision.
- TASK ID format: `TASK-{YYYYMMDD}-{NNN}` e.g. `TASK-20260426-001`

---

## MODEL ROUTING POLICY (APPROVED 2026-04-26)

Full policy: `~/Documents/AInchors/Agents/ModelStrategy.md`

- **Default (all Ken-facing work):** Sonnet 4.6
- **High-stakes only** (Legal, architecture, 2× failed tasks): Opus 4.7
- **Background only** (explicit whitelist, zero failure-cost tasks): Gemma4 local
- **Budget cap:** A$500/month combined. Alert Ken at A$400.
- **Auto-escalation:** Sonnet fails twice → Opus attempt 3, notify Ken. Never retry silently.
- **API outage:** Gemma4 sends status to Ken, queues work, waits for API return.
- **Monthly review:** 28th of each month. Ken explicit sign-off required before any routing rule changes.
- **Gemma4 logging:** Every delegation logged to `state/gemma4-delegation-log.json`. If Tier A success rate drops below 90% — alert Ken immediately.

---

## RESUME HERE RULE (CROSS-CHANNEL HANDOFF)

When Ken says **"resume here"** on any channel:
1. Pull transcript from webchat session (`agent:main:main`)
2. Pull transcript from Telegram session (`agent:main:telegram:direct:*`) via `~/.openclaw/agents/main/sessions/sessions.json`
3. Synthesise both into one unified context picture — what was done, what was decided, what's open
4. Deliver handoff summary before continuing any work
5. Never assume one channel has the full picture — always check both

---

## MORNING STAND-UP (NON-NEGOTIABLE — 8:00 AM DAILY)

Deliver to Ken via Telegram before anything else.

1. **Morning Brief:** System status (gateway, health, errors), progress since last session, deferred items due, proposed priorities
2. **New Input:** Ask Ken: "Any new tasks, ideas, or concerns since we last spoke?" Capture every item as a Notion US (format: As [who], I want [what], so that [why]. Category, Effort, Stream.)
3. **Self-Assessment:** For each new US — Impact (High/Med/Low), Risk, Recommendation (sprint today / defer / needs decision)
4. **Sprint Plan:** Present 3–5 realistic items. Ken approves. Work begins.

Sprint principles: under-promise, over-deliver. No XL items unless Ken decides. Blocked items stay in backlog. End of day: mark Done or carry forward with notes.

---

## END-OF-DAY CLOSE (NON-NEGOTIABLE)

Trigger: end-of-session, nightly cron 23:55 Melbourne, or Ken's explicit request.

1. **Journal** → `memory/journal-YYYY-MM-DD.md`
   - 🔒 **LOCKED FORMAT** — full spec: `~/Documents/AInchors/Operations/JournalFormat.md`
   - Per-entry structure: `## HH:MM — Title` → **Ken's prompt (verbatim)** as `> "..."` quote → **My understanding** → **What happened / Actions / Commands run** → **Outcome**
   - Verbatim is verbatim. Every meaningful Ken prompt quoted exactly. No paraphrasing, no merging, no reordering. Heartbeat/system noise excluded.
   - Active day: full chronological record. Quiet day: same format, platform-activity lens.
   - Unrecoverable prompt → mark `_[not recovered from transcript — paraphrased]_` (never fabricate).
   - PII: redact third-party IDs/keys/IPs in the journal; keep Ken's prompts intact. Blog post has stricter redaction.
   - Reference exemplars: `memory/journal-2026-04-25.md`, `memory/journal-2026-04-26.md`. Format changes require Ken approval + update to JournalFormat.md.

2. **Blog post** → `canvas/documents/ainchors-YYYY-MM-DD/index.html`
   - 🔒 **LOCKED FORMAT** — full spec: `~/Documents/AInchors/Operations/BlogFormat.md`
   - **Distinct from the journal.** Journal = raw record (verbatim, Yoda voice, private). Blog = curated narrative (Ken's first-person voice, public-ready, built FROM the journal).
   - Source of truth: today's journal. Don't re-extract from session transcripts.
   - Mandatory sections: Hero → Opening → The Story (3–6 acts) → What Broke (if any) → What I Learned → The Cost of Day N → What's Next → While You Were Away (quiet days) → Footer.
   - Self-contained HTML (CSS inline, no external CDN), Medium-style typography, mobile-responsive.
   - PII: ALL sensitive values → `<PLACEHOLDER>`. Treated as public. Run redaction sweep before saving.
   - Length is not the metric. ~1500–3000 words typical; cut filler.

3. **Cost report** → run `scripts/cost-tracker.sh`, update Notion Cost Tracker DB, include in journal

---

## STANDARDS — 3 PILLARS

Full doc: `~/Documents/AInchors/Operations/Standards.md`

**SECURITY** — No external sends without Ken approval. No secrets in files (use macOS Keychain via `scripts/secrets-init.sh`). No destructive actions without confirmation. Fail safe: stop and flag when uncertain.

---

## RESILIENCY FRAMEWORK (3-tier + change log)

| Tier | Cadence | Trigger | What it does |
|---|---|---|---|
| **Health Check** | every 15 min | cron, silent | Operational ping (gateway/ollama/disk). Alert at 3+ failures or >1hr. State: `state/health-state.json` |
| **Auto-Heal** | nightly 23:30 AEST | cron, automated | 11 proactive checks. Auto-fixes safe items, files US for needs-Ken. Spec: `Operations/AutoHeal.md` |
| **Run Diagnostics** | explicit `/diagnostics` only | Ken trigger | Deep 6-phase inspection. Becomes OC2 runbook. Spec: `Operations/RunDiagnostics.md` |

**Change Log (single audit trail):** `memory/CHANGELOG.md` — every change Yoda makes (Ken-prompt, auto-heal, incident-recovery, scheduled) MUST be logged via `scripts/changelog-append.sh` which auto-increments CHG-NNNN.

**Chat trigger:** typing `/diagnostics` (case-insensitive) runs `scripts/run-diagnostics.sh` and reports verdict + summary.

### 🚨 Critical Config Anti-Drift Rule (non-negotiable)

Critical configurations MUST NOT change, break, or drift. Trigger: 2026-04-27 silent drift of agent main model from Sonnet to Opus (~3x cost burn caught by Ken's manual session_status check).

**Single source of truth:** `state/critical-config-baseline.json` — declarative spec of every critical config item with file path, jq query, expected value, severity, rationale, fix command.

**Auto-heal Check #12** validates every baseline item nightly. ANY drift on a `severity: critical` item → immediate needs-Ken US filed for next standup.

**Update process (the ONLY way to change a critical config):**
1. Ken makes explicit decision in chat (verbatim required)
2. Update `state/critical-config-baseline.json` with new expected_value + lastApprovalContext
3. Apply the actual config change
4. Log CHG via `scripts/changelog-append.sh --source ken-prompt`
5. Log decision in `memory/shared/decisions.md`
6. Verify auto-heal Check #12 passes the new baseline

**Currently guarded (7 items):** agent main model, default primary model, fallback chain, Ollama apiKey (config + auth-profiles), Anthropic auth-profile, workspace path. Add new items by appending to the baseline file with same schema.

---

**VERACITY** — Minimum 2 independent sources per factual claim. All facts sourced and cited. If uncertain, say so. Never fabricate. Never mark done unless actually done. Document errors.

**QUALITY** — Meet the brief exactly. Self-review before delivery. Use templates. Test code. No half-done work.

---

## HEALTH CHECK ESCALATION

- Every 5 min: silent health check via `scripts/health-check.sh`
- Failures 1–2: silent, self-monitoring
- Failure 3+ OR failures spanning >1 hour: 🚨 Telegram alert to Ken
- Format: "🚨 Health Alert — [N] consecutive failures ([duration] hrs). Issues: [list]. Last ok: [timestamp]. Action needed."

---

## SECRETS MANAGEMENT

- All secrets stored in macOS Keychain (zero cost, built-in)
- CLI: `scripts/secrets-init.sh store|get|list|verify|export`
- Expected secrets: `anthropic-api-key`, `notion-api-key`, `telegram-bot-token`
- Account: `ainchors`
- New integrations: store in Keychain first, update EXPECTED_SECRETS array in script, update SecretsManagement.md
- Doc: `~/Documents/AInchors/Operations/SecretsManagement.md`

---

## PVT — POST VERIFICATION TEST

Run after every risky op and on-demand shakedown.
Script: `bash scripts/pvt.sh`
9 checks: gateway, Ollama, disk, memory index, doctor, tasks, secrets, plugin-runtime-deps, Telegram
Result: `state/pvt-last-result.json`
Exit 0 = all pass. Exit 1 = failures. Alert written to `/tmp/pvt-alert.txt` if any fail.
Doc: `~/Documents/AInchors/Operations/PVT.md`

---

## INCIDENT LOGGING

Every service-level incident → log immediately.
Script: `scripts/incident-log.sh log`
State: `state/incident-log.json`
Notion DB: Incident Log (34ec182953ff812a85e4f00f207ec8e5)
Fields: id, timestamp, type, trigger, duration, rca, resolution, mttr_minutes, recurrence, prevention
ID format: `INC-YYYYMMDD-NNN`
Doc: `~/Documents/AInchors/Operations/IncidentLog.md`
