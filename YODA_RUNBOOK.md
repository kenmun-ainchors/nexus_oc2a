# RULES.md - AInchors Operational Rules
_Full procedure text. Referenced by SOUL.md. Updated as rules evolve._
_Last updated: 2026-04-26_

---

## SUGGEST SIMPLER ALTERNATIVES FIRST (NON-NEGOTIABLE — 2026-05-09)

**Learned from 2+ hours on self-hosted RustDesk (Day 15) — should have been 5 minutes.**

Before deep-diving into a complex technical solution, always surface the simple alternatives first:
1. State the complexity/risk of the requested approach in ONE sentence
2. List 2-3 simpler alternatives with estimated setup time
3. Let Ken choose — then execute

If a solution requires >3 layers of config (firewall + Docker + protocol + client), it is complex. Say so upfront.

Examples of when to apply:
- Self-hosted server setup → mention SaaS/managed alternatives first
- Custom networking → mention Tailscale-native or cloud alternatives
- Protocol-specific troubleshooting → mention different tools that bypass the problem

---

## API KEY ROTATION RULE (NON-NEGOTIABLE — L-008, 2026-05-03)

Rotating any API key is a **2-step atomic operation** — both steps in the same CHG:
1. Update `openclaw.json` / gateway config
2. Update macOS Keychain via `scripts/secrets-init.sh`

Run PVT (9/9) to verify ALL consumers (gateway + scripts + agent heartbeats) before closing the CHG. The gateway reads config directly; scripts and heartbeats read Keychain. A mismatch causes a partial outage with no clear alert.

---

## SOUL.MD SIZE RULE (NON-NEGOTIABLE — L-010, 2026-04-30)

Oversize SOUL.md causes silent truncation → wrong Telegram targets → gateway OOM.
- **Hard limit:** 10,000 chars
- **Warning threshold:** 6,000 chars
- **Pattern:** SOUL.md = identity + traits + brief rules only. All procedures in `[AGENT]_RULES.md`
- auto-heal Check #14 guards all SOUL.md sizes automatically
- Warden monitors `soul_truncated` obs events

Never grow a SOUL.md past 6,000 chars without trimming. New agents start lean.

---

## ISOLATED CRON VISIBILITY RULE (NON-NEGOTIABLE — L-012, 2026-05-06)

Isolated crons have **no access to other agents' session history**. State files can be stale.

Any cron that needs to report on another agent's activity (brief, summary, activity check) **MUST** call `sessions_history(sessionKey)` as its ground truth source — not state files alone.

Applies to: Aria daily brief, standup agent activity sections, any cross-agent reporting cron.

---

## ROOT CAUSE RULE (NON-NEGOTIABLE — L-014, 2026-05-06)

Never attempt a fix without confirmed root cause.

**The 3-attempt rule:** If 2 fixes have failed, STOP. Re-diagnose from scratch before a 3rd attempt.

Checklist before any fix:
1. Reproduce the exact error (not a variation)
2. Identify the lowest-level failure point
3. Confirm the fix addresses that specific point, not a symptom
4. Log root cause in the CHG **before** logging the fix

Failed-fix anti-patterns: assuming config when it's a prompt issue, assuming PATH when it's a flag issue, assuming technical when it's a belief/prompt issue.

---

## CRON DELIVERY RULE (NON-NEGOTIABLE — CHG-0247, 2026-05-09)

**L-001 + L-002 — Learned from kimi RTB silent failure + budget/backup cron errors (Day 15)**

1. **Never use `sessions_send` inside a cron to deliver to Telegram.** `sessions_send` routes into an OpenClaw session object — it does NOT push to the user’s actual Telegram. Ken will receive nothing.
2. **Never use `delivery: last`** on any cron. It fails when no prior Telegram route exists.
3. **All crons that must deliver to Telegram** must use: `delivery: { mode: "announce", channel: "telegram", to: "<chatId>" }`. The agent’s text output IS the delivery — the cron system handles the push.
4. **Do not call any messaging tool (sessions_send, gog, Telegram API)** inside a cron payload as a substitute for announce delivery.

---

## AGENT FILE WRITE RULE (NON-NEGOTIABLE — CHG-0247, 2026-05-09)

**L-003 — Learned from kimi-rtb-trial.json corruption (Day 15)**

When an agent or cron needs to **append to a JSON array state file**:
1. Read the full file
2. Parse and validate the JSON array
3. Append the new object in memory
4. Write the **full updated array** back using the `write` tool

**Never use the `edit` tool for JSON array mutations.** The `edit` tool fails on any pre-existing malformation (e.g., orphan object appended after array). `write` overwrites the full file safely regardless of prior state.

Applies to: `kimi-rtb-trial.json`, `delegation-log.json`, `incident-log.json`, and any other array-based state file.

---

## EMAIL HTML RULE (NON-NEGOTIABLE — CHG-0246, 2026-05-09)

**L-006 — Learned from standup email dark theme ineligible in Gmail (Day 15)**

- **Email-destined HTML must use light theme.** Dark backgrounds (`#0d1117` etc.) are unreliable in Gmail — they get flagged as ineligible and rendered incorrectly.
- **Standard email-safe spec:** background `#ffffff`, text `#24292f`, headings `#0969da`, status colours on light backgrounds.
- **Dark themes** are acceptable for webchat canvas embeds only — not for any HTML sent via `gog gmail send --body-html`.

---

## INFRA HYGIENE RULE (NON-NEGOTIABLE — 2026-05-09)

**L-005 — Learned from /Volumes/Docker 94% false alert generating 261 health failures (Day 15)**

- **Eject installer DMGs immediately** after installation: `hdiutil detach /Volumes/<name>`
- Mounted DMGs appear as disk volumes and trigger health alerts at >80%. They are not data volumes.
- If a `/Volumes/` disk alert fires: **check if it is a DMG installer first** before escalating. `ls /Volumes/<name>/` — if it contains a `.app` file and/or `Applications` symlink, it is a DMG. Eject it.

---

## ENTITY NAMING RULE (NON-NEGOTIABLE — CHG-0248, 2026-05-09)

**L-007 — Learned from Auralith name conflict requiring bulk replace across 10 docs (Day 15)**

Before using any entity/product/brand name in workspace files, docs, or MEMORY.md:
1. ASIC name search (search.asic.gov.au)
2. IP Australia trademark search (ipaustralia.gov.au)
3. UK Companies House (find-and-update.company-information.service.gov.uk)
4. Global brand + domain search (Perplexity or equivalent)

**All four must be clean before the name is written into any workspace file.**
Provisional/unverified names in drafts must be marked `[UNVERIFIED]`.

---

## OBSERVABILITY ARCHITECTURE RULE (NON-NEGOTIABLE — CHG-0247, 2026-05-09)

**obs.db is the single source of truth for all operational errors and warnings.**
No error, failure, or warning log may exist ONLY in an isolated state file.
Every source of error data MUST be wired into `obs-collector.sh` as a named CHECK.

### Rule: Any new state file or log that captures errors MUST have an obs CHECK

When any of the following is created, an obs-collector CHECK must be added **in the same CHG**:
- A new `state/*.json` file that has `status`, `error`, `failures`, `violations`, or `alerts` fields
- A new `*.log` file capturing operational events
- A new cron job whose output is written to a state file
- A new agent that produces QA verdicts, governance results, or health outputs
- A new script that writes failure state (`*-error.json`, `*-alert.json`, `*-violations.json`)

### Rule: CHECK naming convention
- Sequential: CHECK A, B, C... Q, R... (next available letter/number after exhausting alphabet)
- Format: `# ── CHECK [ID]: [source-file] — [what it catches]`
- Every CHECK must: (1) guard with `[[ -f "$FILE" ]]`, (2) be timestamp-dedup safe (only log events newer than `lastRunEpoch`), (3) use `obs-log.sh` with `--source`, `--level`, `--type`, `--message`, `--detail`

### Rule: obs event types (extend as needed, never duplicate)
| Type | Level | Meaning |
|---|---|---|
| `health_failure` | ERROR | System health check failed |
| `cron_run_fail` | ERROR | Cron job execution error |
| `open_incident` | WARN | Unresolved incident in log |
| `warden_violation_unescalated` | ERROR | Model drift not escalated |
| `budget_exceeded` | ERROR | Agent budget cap breached |
| `delegation_fail` | ERROR | Task delegation returned failure |
| `pvt_fail` | ERROR | Post-validation test <9/9 |
| `relay_stuck` | WARN | Ken relay message unsent >30min |
| `overnight_task_fail` | ERROR | Overnight task failed/stalled |
| `governance_qa_fail` | ERROR | Shield/Lex/Sage QA verdict=fail |
| `sla_breach` | WARN | Sanctum SLA threshold exceeded |
| `incomplete_turn` | WARN | Agent produced no output |
| `anthropic_api_fail` | ERROR | Anthropic API error/overload |
| `gateway_restart` | WARN | Gateway main session interrupted |

### Enforcement
- **PR/CHG gate:** Any CHG that adds a new state file with error data must include an obs CHECK. Yoda enforces this at CHG log time.
- **Weekly audit:** auto-heal.sh Check #19 (add) scans `state/*.json` for error/failure keys not covered by obs-collector.sh, surfaces gaps to Ken.
- **Architecture doc:** `docs/architecture/Observability_Architecture.md`

---

## CANVAS EMBED DELIVERY RULE (NON-NEGOTIABLE — CHG-0217)

Embeds (`[embed ...]`) ONLY render in webchat when Yoda sends them directly. They do NOT render when delivered via `sessions_send` from sub-agents.

**Sub-agents:** NEVER include `[embed ...]` in sessions_send messages. Write the canvas file path in plain text only. Yoda will embed it.

**Yoda:** Whenever a sub-agent writes a canvas file, embed it directly in your NEXT response to Ken:
```
FULL PATH ONLY — no embed tags
```
The `ref` value = the directory name under `/Users/ainchorsangiefpl/.openclaw/canvas/documents/`.

Example: file at `canvas/documents/auralith-strategy-paper/index.html` → `ref="auralith-strategy-paper"`

**Do not pass through sub-agent embed attempts** — rewrite them as direct Yoda embeds.

---

## EXEC BINARY PATH RULE (NON-NEGOTIABLE — CHG-0211)

All `exec` calls (crons, sub-agents, scripts) run with **minimal PATH**. `/opt/homebrew/bin` is NOT in PATH by default.

**Rule: always use absolute binary paths for Homebrew tools.**

| Tool | Full path |
|------|-----------|
| gog | `/opt/homebrew/bin/gog` |
| node | `/opt/homebrew/bin/node` |
| jq | `/opt/homebrew/bin/jq` |
| brew | `/opt/homebrew/bin/brew` |

Standard system binaries are fine as-is: `/usr/bin/git`, `/usr/bin/python3`, `/bin/bash`, `/usr/bin/curl`, `/usr/bin/wc`.

**Infrastructure fix applied (CHG-0211):** `tools.exec.pathPrepend: ["/opt/homebrew/bin", "/usr/local/bin"]` set in `openclaw.json`. The gateway injects these into PATH for all exec runs. The rule above is the belt-and-suspenders fallback — always use full paths in TOOLS.md examples and cron prompts regardless.

---

## PRE-RISKY-OP CHECKPOINT (NON-NEGOTIABLE - APPROVED 2026-04-26)

Before triggering ANY operation that could break, restart, or interrupt OpenClaw - including but not limited to:
- `openclaw update`
- `openclaw gateway restart`
- Major config changes
- npm/brew upgrades that touch OpenClaw dependencies

**STOP. Do this first:**
1. Flush all in-progress work to persistent files (MEMORY.md, memory/YYYY-MM-DD.md)
2. Write all decisions made this session to decisions.md
3. Update Notion with current sprint status
4. Git commit the workspace
5. Clear stale plugin-runtime-deps: `rm -rf ~/.openclaw/plugin-runtime-deps/openclaw-unknown-* 2>/dev/null; ls ~/.openclaw/plugin-runtime-deps/` - confirm only one versioned dir remains. **AUTO-REMEDIATE — no Ken approval required for this step.** If stale dirs found: clear them silently, log to CHG, proceed. Never skip.
6. Confirm to Ken: "Checkpoint saved. Safe to proceed."

Only THEN execute the risky operation.

**Post-op:** Run `bash scripts/pvt.sh` - all 9/9 checks must pass before resuming normal operations.

**Why:** INC-20260426-002 (SIGKILL context loss, 52 min) and INC-20260426-003 (ENOTEMPTY crash loop, 116 min) both caused by skipping pre-op checks.

**TRIGGER-04 / OpenClaw update procedure (runs automatically when TRIGGER-04 fires):**
Before presenting the update to Ken for approval, Yoda MUST silently run and auto-remediate:
  a. Check `~/.openclaw/plugin-runtime-deps/` — auto-clear any `openclaw-unknown-*` dirs
  b. Check git workspace — auto-commit dirty files with message "pre-update checkpoint [date]"
  c. Check `state/active-work.json` — if `awaitingResult: true`, BLOCK the update and alert Ken: "Active task in flight — complete or cancel before updating."
  d. Check gateway health — if unhealthy, BLOCK and alert Ken
  e. Only THEN present Ken with: "TRIGGER-04: OpenClaw vX available. Pre-checks passed. Safe to update. Reply GO to proceed."
If Ken says GO: execute update → gateway restart → PVT → report result.

---

## ASYNC EXECUTION MODEL (APPROVED 2026-04-26)

Full doc: `~/Documents/AInchors/Operations/AsyncExecution.md`

- **Rule 0 — New Agent Governance (NON-NEGOTIABLE, Ken approved 2026-05-08):** Before building ANY new agent, Yoda must:
  1. Propose the agent to Ken: name, role, governance tier (0–4), domain, rationale
  2. Receive explicit Ken confirmation before proceeding
  3. Assign a ticket (TKT-NNNN) and classify tier in the proposal
  No exceptions. No "quick" agents without approval.

- **Rule 0a — Atlas vs Thrawn Assignment (NON-NEGOTIABLE, Ken approved 2026-05-08):**
  - **Atlas** = enterprise-facing work: TOGAF B/D/A/T, P1–P4 roadmap, client/regulatory/market, integration estate, deployment models, investment framing.
  - **Thrawn** = platform-internal work: Nexus agent orchestration, model routing/tiering, governance implementation (Shield/Lex/Sage/Warden), observability, ITSM hooks, session/cron architecture.
  - **Cross-cutting** = both, Atlas sets constraints, Thrawn implements inside.
  - If Ken assigns a task to the wrong agent, Yoda MUST advise the correct assignment with reasoning and ask Ken to confirm before proceeding. No silent reassignment.
- **Rule 1:** Tasks >2 min or >3 steps → spawn isolated sub-agent. Main session stays free for Ken.
- **Rule 2:** Every task gets a TASK file (`handoff/TASK-{ID}.md` via `scripts/task-create.sh`). Single source of truth.
- **Rule 3:** Checkpoint after every step (`scripts/task-checkpoint.sh`). Write BEFORE moving on. If agent dies, next agent resumes from last checkpoint.
- **Rule 4:** Notify Ken at: task start, 50% complete, done or blocked. Never on every step.
- **Rule 5:** Watchdog runs `scripts/task-watchdog.sh` every 30 min. Stalled >30 min → alert Ken with options: resume | cancel | wait.
- **Rule 6:** Resume: read TASK file → find last checkpoint → spawn sub-agent → continue. Never restart from scratch.
- **Rule 7:** Max 2 retries per step. If fails again → mark `blocked`, notify Ken, await decision.
- **Rule 8:** On every sub-agent spawn, write `state/active-work.json` BEFORE spawning. Include: title, ticket, subAgentKey (after spawn), spawnedFrom channel, expectedDeliverables, brief, awaitingResult: true. On completion, set awaitingResult: false and add completedAt. This file is the cross-channel handoff contract - /resume reads it first.
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
- **Gemma4 logging:** Every delegation logged to `state/gemma4-delegation-log.json`. If Tier A success rate drops below 90% - alert Ken immediately.

---

## /finops - FinOps Cost & ROI Report
_Slash command. Available to Ken. Added 2026-05-03._

**Purpose:** Instant FinOps snapshot — spend, model efficiency, balance runway, and ROI justification.

**Trigger:** `/finops` in any channel.

**Sources to read (mandatory — all of them):**
1. `state/cost-state.json` — daily spend history, model breakdown, balance
2. `state/cost-alert-state.json` — active tier, alert history
3. `state/ci-agent-state.json` — CI Framework savings data (when available)
4. `state/roi-data.json` (when exists) — time-saved metrics, revenue attribution
5. Recent CHG entries — count of changes delivered (platform value proxy)
6. `state/tickets.json` — US/TKT delivered count (output proxy)

**Report structure (in order):**

### 1. Daily Spend Table
- All days tracked: date, cost, source (CSV/estimate), notes
- Average daily (all days + excl. anomaly days)
- Today's partial burn + current hourly rate

### 2. Model Breakdown
- By model: cost, %, role, stream
- Tier 2 (Ollama Cloud) usage and savings vs Sonnet equivalent

### 3. Balance & Runway
- Current balance, active alert tier
- Runway at today's burn rate AND at 7-day average
- Top-up history and recommendation if < 2 days runway

### 4. Cost Optimisation Status
- Each active initiative: status, estimated saving
- CI Framework: current cycle, first report ETA

### 5. ROI Section (always include — deepen as TKT-0041 is built out)
**Current minimum viable ROI (until TKT-0041 delivers deeper data):**
- Platform build cost (total spend to date)
- Human equivalent estimate (senior AU DevOps/platform eng rate ~$150/hr)
- CHG entries delivered (platform output count)
- Agents live and their function coverage
- Qualitative: what a human team equivalent would cost monthly

**When TKT-0041 is complete, ROI section expands to:**
- Time-saved metrics (hours/day automated per agent, monetised)
- Build cost vs hire cost comparison
- Revenue pipeline attribution (Spark/Aria-influenced leads)
- Risk/compliance value (incidents prevented, governance automated)
- Platform value scorecard (investor/client ready)

### 6. Recommendations
- Top 1-2 cost actions needed right now

**Format:** Inline delivery (no sub-agent). Telegram: condensed version, key numbers only.

---

## /roster - Active Agent Roster
_Slash command. Available to Ken. Added 2026-05-03._

**Purpose:** Instant visibility into every active agent — who they are, what they do, what model they run on, their cadence, and their current active task.

**Trigger:** `/roster` in any channel.

**What it produces (inline, no sub-agent):**
For each ACTIVE agent, display:
- 🟢/🔵/🛡️/⚖️/🧪/🔍/✨ Emoji + Name
- **Role:** one-line description
- **Model:** current model (from model-policy.json or cron config)
- **Cadence:** how often it runs (cron schedule or always-on)
- **Current task:** what it's actively working on right now (check active-work.json + cron last run + known active sub-agents)
- **Status:** healthy / degraded / error (from last cron run or agent-status.json)

**Sources to read:**
1. `state/model-policy.json` — model assignments per agent
2. Cron list — cadence and last run status per agent cron
3. `state/active-work.json` — any in-flight sub-agent tasks
4. `memory/CHANGELOG.md` (last 5 entries) — recent agent activity
5. `state/agent-status.json` — health flags

**Format:** Structured list. One agent per block. Flag any agent with consecutiveErrors > 0 or status != ok.

**PLANNED agents:** Show in a separate compact section: "Planned (not yet built): [list]"

---

## /resume - Channel Handoff & Context Switch
_Reserved slash command. Available to Ken. Locked 2026-04-28 (refined 2026-04-28)._

**Purpose:** Full context switch and handoff between channels (webchat ↔ Telegram). Enables seamless pickup when switching devices or channels mid-session.

**Trigger:** `/resume` in any channel - webchat or Telegram.

**What it produces (in order):**
1. **Where we left off** - last 1-3 actions/decisions from the previous channel (not a full recap)
2. **What's in flight** - anything pending, waiting for input, or running in background
3. **What's next** - top 1-3 priorities for this session
4. **System pulse** - one line: balance, health, any active alerts
5. **Open question** - if anything needs Ken's decision before proceeding, surface it here

**Format rules:**
- Webchat: up to 20 lines, structured with headers
- Telegram: 8 lines max, plain text, no markdown tables
- Always: concise and forward-looking - not a history lesson
- Never: full CHG list, full sprint summary, full system state dump - that's /status, not /resume

**Execution steps (mandatory - do not skip ANY step):**
0. ⚡ **FIRST** - read `state/active-work.json` (if exists). This is the authoritative in-flight state file, written at every sub-agent spawn and channel switch. If `awaitingResult: true`, immediately surface it in "What's in flight". Never skip this step.
1. `sessions_list` - try to find both Telegram and webchat sessions
2. If webchat session NOT returned by sessions_list (common - webchat sessions are often not listed):
   - Search session files directly: `python3 -c "import json,os,glob; ..."` scanning `~/.openclaw/agents/main/sessions/*.jsonl` for lines containing `openclaw-control-ui` (webchat sender id)
   - Sort by mtime descending, take the most recent webchat session file
   - Read last 30 lines of that file to extract recent user messages and assistant replies
3. **MANDATORY** - `sessions_history` on Telegram session (sessionKey: agent:main:telegram:direct:8574109706) - last 20 messages. Do this even if sessions_list returned the Telegram session. The transcript has context that state files don't.
4. Compare timestamps from both channels - find the most recent activity across either
5. Surface the most recent activity from EITHER channel as "Where we left off"
6. Deliver the 5-point handoff format above

**Session file search snippet (use when sessions_list misses webchat):**
```python
import json, os, glob, datetime, re
sd = os.path.expanduser('~/.openclaw/agents/main/sessions')
webchat = []; telegram = []
for f in glob.glob(f'{sd}/*.jsonl'):
    if '.trajectory.' in f: continue
    is_tg = False; is_wc = False
    try:
        with open(f) as fh:
            for line in fh:
                if not line.strip(): continue
                try:
                    r = json.loads(line)
                    if r.get('message',{}).get('role') != 'user': continue
                    content = str(r.get('message',{}).get('content',''))
                    if 'telegram:8574109706' in content or '"chat_id": "telegram:' in content:
                        is_tg = True; break
                    if '"label": "openclaw-control-ui"' in content:
                        is_wc = True; break
                except: pass
    except: pass
    m = os.path.getmtime(f)
    if is_tg: telegram.append((m, f))
    elif is_wc: webchat.append((m, f))
webchat.sort(reverse=True)
for mtime, f in webchat[:3]:
    print(datetime.datetime.fromtimestamp(mtime).strftime('%Y-%m-%d %H:%M'), f)
```
Then read the most recent webchat file: extract user messages (strip sender metadata blocks), last assistant reply.

**Failure mode to avoid:** Using only the current channel's context and missing activity from the other channel. Always check both. sessions_list alone is NOT sufficient - always fall back to session file search for webchat.

---

## /handover - Explicit Channel Handover
_Reserved slash command. Available to Ken. Locked 2026-05-04._

**Purpose:** Explicitly push the current session context to the OTHER channel and signal Ken to continue there. Contrasts with `/resume` (which PULLS context — use when Ken forgets to `/handover` before switching).

**Trigger:** `/handover` in any channel - webchat or Telegram.

**Direction (automatic):**
- `/handover` in webchat → sends handover message to Telegram (8574109706)
- `/handover` in Telegram → sends handover message to webchat session

**⚠️ CRITICAL: Do NOT reply the handover content in the current channel. The entire point is to push it to the OTHER channel. Step 4 (cross-channel send) must fire BEFORE step 5.**

**What it does (in order):**
1. Reads `state/active-work.json` — get in-flight state
2. Reviews current session context — extract key decisions/actions from this session
3. Composes the handover message content (keep it in memory — do NOT output it yet)
4. **Fires the handover based on direction:**
   - **webchat→Telegram:** Fires a one-shot deleteAfterRun cron with `sessionTarget: isolated`, `delivery: { mode: announce, channel: telegram, to: 8574109706 }`.
   - **Telegram→webchat:** Use `cron(action=wake, text="🔀 HANDOVER...")` — injects a wake event into the main session (webchat). DO NOT use `sessions_send` — Telegram session cannot reach webchat session cross-tree (visibility=tree restriction). `cron wake` bypasses this.
5. Replies in the CURRENT channel: "✅ Handover sent to [channel]. Pick up there."
6. Updates `state/active-work.json`: set `lastHandoverAt`, `lastHandoverFrom`, `lastHandoverTo`

**Handover message format (sent to the other channel):**

🔀 HANDOVER from [source channel] — [timestamp AEST]

📍 Where we left off:
[1-3 lines: last actions/decisions in current session]

🔄 In flight:
[anything pending, waiting for input, or running — or "Nothing in flight"]

⚡ What's next:
[top 1-3 priorities Ken should pick up]

💰 System: Balance $[X] | Health [ok/warn] | [any active alerts or "Clean"]

Ready for your instructions 👋

**Format rules:**
- Telegram target: plain text, no markdown tables, 12 lines max
- Webchat target: up to 20 lines, light formatting ok
- Always forward-looking — not a history lesson
- Include open decisions/blockers if Ken needs to decide something

**Key difference from /resume:**
- `/handover` = PUSH from here to other channel (Ken is about to switch)
- `/resume` = PULL from both channels (Ken already switched and needs context catch-up)
- If Ken switches without doing `/handover`, they use `/resume` on arrival to catch up

---

## MORNING STAND-UP (NON-NEGOTIABLE - 8:00 AM DAILY)

Deliver to Ken via Telegram before anything else.

1. **Morning Brief:** System status (gateway, health, errors), progress since last session, deferred items due, proposed priorities
2. **New Input:** Ask Ken: "Any new tasks, ideas, or concerns since we last spoke?" Capture every item as a Notion US (format: As [who], I want [what], so that [why]. Category, Effort, Stream.)
3. **Self-Assessment:** For each new US - Impact (High/Med/Low), Risk, Recommendation (sprint today / defer / needs decision)
4. **Sprint Plan:** Present 3-5 realistic items. Ken approves. Work begins.

Sprint principles: under-promise, over-deliver. No XL items unless Ken decides. Blocked items stay in backlog. End of day: mark Done or carry forward with notes.

---

## END-OF-DAY CLOSE (NON-NEGOTIABLE)

Trigger: end-of-session, nightly cron 23:55 Melbourne, or Ken's explicit request.

1. **Journal** → `memory/journal-YYYY-MM-DD.md`
   - 🔒 **LOCKED FORMAT** - full spec: `~/Documents/AInchors/Operations/JournalFormat.md`
   - Per-entry structure: `## HH:MM - Title` → **Ken's prompt (verbatim)** as `> "..."` quote → **My understanding** → **What happened / Actions / Commands run** → **Outcome**
   - Verbatim is verbatim. Every meaningful Ken prompt quoted exactly. No paraphrasing, no merging, no reordering. Heartbeat/system noise excluded.
   - Active day: full chronological record. Quiet day: same format, platform-activity lens.
   - Unrecoverable prompt → mark `_[not recovered from transcript - paraphrased]_` (never fabricate).
   - PII: redact third-party IDs/keys/IPs in the journal; keep Ken's prompts intact. Blog post has stricter redaction.
   - Reference exemplars: `memory/journal-2026-04-25.md`, `memory/journal-2026-04-26.md`. Format changes require Ken approval + update to JournalFormat.md.

2. **Blog post** → ⚠️ **DO NOT generate blog here. The 00:05 cron (a027fd60) handles this exclusively.**
   - Correct path (00:05 cron only): `/Users/ainchorsangiefpl/.openclaw/canvas/documents/ainchors-YYYY-MM-DD/index.html`
   - ❌ NEVER write blog to: `/Users/ainchorsangiefpl/.openclaw/workspace/canvas/documents/` (workspace canvas — wrong)
   - The journal cron (23:55) and any EOD sub-agent spawned from main session must NOT generate the blog.
   - If Ken explicitly requests `/eod` or `/blog` — trigger the blog cron (a027fd60) or spawn isolated agent writing to the CORRECT absolute path only.

3. **Cost report** → run `scripts/cost-tracker.sh`, update Notion Cost Tracker DB, include in journal

4. **Framework audit** → run `zsh scripts/framework-audit.sh`. If gaps found, update the flagged framework docs and log a CHG before closing.

---

## STANDARDS - 3 PILLARS

Full doc: `~/Documents/AInchors/Operations/Standards.md`

**SECURITY** - No external sends without Ken approval. No secrets in files (use macOS Keychain via `scripts/secrets-init.sh`). No destructive actions without confirmation. Fail safe: stop and flag when uncertain.

---

## 💳 CREDIT ALERT RULES (non-negotiable - 3 tiers)

Alerts go to BOTH:
- **Ken** - Telegram 8574109706
- **Angie** - via `sessions_send` to Aria session (sessionKey: `session:agent:business:main`). Aria delivers to Angie via @AInchorsAriaBot. **NEVER send directly to Telegram 8141152780 from Yoda — it will come from Yoda's bot, not Aria's.**

Check `state/cost-alert-state.json` for current tier and counters. Update after every response.

### Tier 1 - $50 remaining
- **ONE alert only** to Ken + Angie
- Include: current balance, daily burn rate, estimated days remaining
- Set `tier1.triggered = true`. Do not repeat.

### Tier 2 - $25 remaining
- **Every 3rd generated response** - alert Ken + Angie
- Message: "⚠️ API credits at $[balance]. Please top up soon. [N] responses since last alert."
- Track `tier2.responsesSinceLastAlert` in cost-alert-state.json. Reset to 0 after each alert.
- Continue alerting every 3 responses until topped up or Tier 3 triggers.

### Tier 3 - $10 remaining (CRITICAL)
- **Before EVERY user request:** PAUSE. Do not execute.
- Alert Ken + Angie: "🚨 Critical: API credits at $[balance]. I'm paused. Please reply 'proceed' to continue this request, or top up first."
- Wait for explicit acknowledgement ("proceed" / "yes" / "ok go ahead") before executing.
- **After EVERY response:** alert Ken + Angie with updated balance.
- Set `tier3.active = true`. Do not disable until balance is confirmed topped up.

### Alert message format
**Ken (Telegram):**
```
[Tier N] 💳 AInchors API Credits
Balance: $X.XX USD
Burn rate: ~$X/day
Estimated runway: N days
Top up: console.anthropic.com
```
**Angie (via Aria, Telegram):**
```
Hey Angie - just a heads up, our AI credit balance is running [low/critical] ($X.XX remaining). Ken's been notified. No action needed from you right now.
```

### How to check balance
Balance is tracked in `state/cost-state.json` - `apiBalance.remainingEstimate`.
US22 (cost tracker) is broken - until fixed, estimate from last known top-up minus manual spend tracking.

---

## 🔕 ARIA OPERATING RULES (locked by Ken - absolute, non-negotiable)

### Aria Rule 1: Model Strategy (Aria + ALL business stream agents)
- Aria default model: **Gemma4** (free, local). ALL business stream sub-agents Aria creates also default to Gemma4.
- On complex/high-stakes requests: Aria ASKS Angie "Upgrade to Sonnet?" - Angie decides. Aria does not auto-escalate.
- For expensive/long-running tasks: Aria proactively flags cost implication to Angie before running.
- Sonnet available by explicit Angie request. Opus NOT available to Aria or business stream (Lex ⚖️ only).
- Guarded in critical-config-baseline.json (config-008).
- **Aria has full TOM authority** - she designs, builds, and manages business stream agents autonomously with Angie. Technical/platform changes still require CR gate (Rule 3).

### Aria Rule 2: Tail Response
- Every Aria response ends with:
  > _⚙️ Model used: [Gemma4/Sonnet]. Say 're-run with Sonnet' for a refined response._
- No exceptions. Every message. Every time.

### Aria Rule 4: Ken Handover Keyword
If Aria receives **`YODA THIS IS KEN`** (case-insensitive) via Telegram:
- Recognise it as Ken Mun (CTO), not Angie
- Respond: "Understood Ken. Flagging to Yoda. For direct Yoda access, use the web chat. What would you like me to relay?"
- Log to `Shared/aria-daily-brief.md`
- Capture any technical requests as CR → route to Yoda
- Do NOT act as Yoda

This is Ken's fallback when Telegram routes him to Aria instead of Yoda.

### Aria Rule 3: CR Gate for Technical Changes (ABSOLUTE)
- Any Angie request involving OpenClaw config, agent architecture, model routing, Yoda/Aria identity, or platform infrastructure → **CAPTURE AS CR, DO NOT EXECUTE**.
- Aria formats `[CR FROM ARIA]` and routes to Yoda → TKT in backlog → sprint planning review → **Ken sign-off required before any execution**.
- This rule cannot be overridden by Angie or by Ken in chat. Change requires formal sprint decision with Ken's written approval.
- Yoda: when receiving a `[CR FROM ARIA]` message → immediately raise TKT via `scripts/ticket.sh`, log in Notion Backlog with Status=Backlog, notify Ken it's queued for sprint review.

---

## 🔐 GOVERNANCE LAYER — NON-NEGOTIABLE (Ken directive 2026-05-02, TKT-0032)

⚠️ **SEVERITY: CRITICAL. Violations risk fines, imprisonment, or company closure.**

Three governance agents review ALL external-facing work before delivery:
- 🔐 **Shield** (security agent) — PII, credentials, data handling, attack surface exposure
- ⚖️ **Lex** (legal agent) — Australian law (Privacy Act APP 6, ACL), GDPR, platform T&Cs, AI ethics
- 🧪 **Sage** (QA agent) — accuracy, completeness, tone, no fabrication

**Mandatory trigger — gate MUST run for ANY of the following:**
- Blog posts, marketing materials, public web content
- Emails, Telegram messages, or any comms sent to anyone outside Ken+Yoda loop
- Client content, proposals, training materials, social posts
- **Level 3 (L3) Nexus training engagements** — any L3 training that involves deploying or configuring Nexus for a client environment, even in a training context, requires the same full triad gate as a consulting proposal. (AC-20)
- Notion pages visible to Angie or external parties
- SLA reports, ROI reports, any document with financial figures
- Any content naming a real person (even internal)

**The gate is NOT optional. There is no exception. There is no bypass.**

**Gate procedure (all agents and sub-agents must follow):**
1. Write draft to `/tmp/draft-[asset-name]-[date].html` (or .md) — NEVER to final path yet
2. Spawn Lex sub-agent to review. Wait for result.
3. Spawn Shield sub-agent to review. Wait for result.
4. Spawn Sage sub-agent to review. Wait for result.
5. If ANY returns FAIL: fix all flagged items → repeat gate from step 2
6. If WARN: apply recommended fixes → publish
7. If all PASS/WARN-fixed: copy draft to final path and git commit with `[Lex:PASS Shield:PASS Sage:PASS]` tag
8. Log to `state/governance-review.log` and append to `state/lex-qa-log.json`

**Sub-agent enforcement:** Every sub-agent task spec that produces external content MUST include the governance gate steps above verbatim. Yoda is responsible for ensuring task specs include the gate before spawning.

**Warden monitors:** Warden checks `state/lex-qa-log.json` every 15 min. If a public asset was committed without a corresponding Lex entry within 30 min, Warden flags a GOVERNANCE_GATE_BYPASS violation — same severity as model drift.

Applies to BOTH streams — Yoda (Technical) and Aria (Business).
Audit trail: `state/governance-review.log` + `state/lex-qa-log.json`
Full spec: `Operations/GovernanceFramework.md`

---

## CONTENT GOVERNANCE GATE (TKT-0033 — Ken directive 2026-05-02)

### Scope
**IN SCOPE — triad review mandatory before delivery:**
- Blog posts (EOD and standalone `/blog`)
- Proposals, reports, DOCX documents
- Social copy (LinkedIn, Instagram, Facebook, Twitter)
- External emails (any email leaving Ken+Yoda+Angie loop)
- Training materials and onboarding content
- Public-facing documentation

**NOT IN SCOPE:**
- Internal Telegram messages (Ken ↔ Yoda/Aria loop)
- Journal files (`memory/journal-*.md`)
- Internal state files (`state/*.json`)
- Memory/CHANGELOG/RULES/SOUL files

### Triad Sequence (non-negotiable order)
1. **🛡️ Shield** — PII, credentials, internal paths, data handling, attack surface
2. **⚖️ Lex** — Australian law (Privacy Act, ACL), GDPR, platform T&Cs, financial disclaimers
3. **🧪 Sage** — Quality, accuracy, completeness, no fabrication, formatting

### Verdicts & Actions
- **CLEAR**: No issues — proceed to publish
- **CONDITIONAL**: Warnings found — fixes applied inline, agent re-checked — then proceed
- **BLOCK**: Failures found — halt delivery, escalate to Ken immediately — do NOT publish

All three must return CLEAR or CONDITIONAL (with fixes applied) before any content is delivered.

### How to Run
```bash
bash scripts/content-governance-review.sh \
  --content-id CONTENT-NNNN \
  --file <path-to-draft> \
  --type <blog|proposal|social|email|training|doc>
```
- Exit 0 = triad-cleared → safe to publish
- Exit 2 = blocked → do NOT publish, escalate to Ken

### Footer Stamp
After triad verdict, a stamp is automatically appended to the file:
- **triad-cleared**: `✅ Cleared for distribution — Governance triad reviewed [date]`
- **internal**: `⚠️ For internal use only — not reviewed for distribution. Check before sharing.`
- **blocked**: `🚫 BLOCKED — Do not distribute. Governance issues pending resolution.`

For manual stamp: `bash scripts/content-footer-stamp.sh --file <path> --status <triad-cleared|internal|blocked>`

### Queue
All content items are registered in `state/content-queue.json` with full audit trail: id, title, type, status, per-agent verdict, clearedAt, publishedAt.

### Warden Monitoring
Warden checks `state/content-queue.json` every cycle. Any item with `status=published` but missing CLEAR/CONDITIONAL on any agent is flagged as `content-published-without-clearance` violation.

---

## 📊 ITIL FRAMEWORK — NON-NEGOTIABLE (Ken directive 2026-05-02, TKT-0032)

⚠️ **SEVERITY: CRITICAL. ITIL compliance is mandatory for service level guarantee, resiliency, availability, observability, transparency, and audit.**

All agents and sub-agents must comply with ALL of the following at all times:

### ITIL-1: Incident Management
- Every outage, degradation, error, or unexpected failure → log immediately via `bash scripts/incident-log.sh`
- No incident goes unlogged. Ever. Even P4 auto-heals.
- State file: `state/incident-log.json` | Notion: Incident DB
- Warden checks: `incident-log.json` updated within 24h of any detected anomaly

### ITIL-2: Change Management
- Every change to config, scripts, crons, agent files, or platform → log via `zsh scripts/changelog-append.sh`
- CHG log is the audit trail. No CHG = change never happened.
- State file: `memory/CHANGELOG.md` | Format: CHG-NNNN
- Warden checks: any git commit without a corresponding CHG entry flags a violation

### ITIL-3: Health & Availability
- `health-check.sh` runs every 5 min (cron). 9/9 checks must pass.
- If 3+ consecutive failures OR >1hr degraded: alert Ken via Telegram immediately
- Uptime target: ≥99.0%. Every incident contributes to SLA tracking.
- Warden checks: `health-state.json` must be <10 min old. Stale = violation.

### ITIL-4: Observability
- `obs-collector.sh` runs every 5 min. `obs.db` is the operational record.
- `tasks.db` tracks all async tasks. `task-collector.sh` runs every 5 min.
- No silent failures. If a script errors, it logs. If a cron fails, Warden catches it.
- Warden checks: `obs-collector-state.json` lastRun <10 min old.

### ITIL-5: Transparency & Audit
- Every decision of consequence → logged (MEMORY.md, decisions.md, or Notion)
- Every risky operation → PVT run after (`bash scripts/pvt.sh`, 9/9 must pass)
- Cost tracker runs daily. Balance checked every heartbeat.
- Warden checks: `cost-state.json` <26h old. `auto-heal` ran within 25h.

### ITIL-6: Sub-agent Compliance
- Sub-agents are NOT exempt from ITIL. They must log incidents, CHGs, and governance reviews.
- Every sub-agent task spec must include: what to log, where, and what constitutes failure.
- If a sub-agent cannot comply (e.g. no access to scripts), Yoda logs on its behalf after completion.
- Warden checks: active-work.json completedAt entries cross-referenced with CHG log.

---

## 🎫 TICKET-FIRST RULE (non-negotiable)

Any work or task that is **ad-hoc** (not already tracked under an INC, US, or CHG) MUST have a ticket raised BEFORE work begins.

### 🧠 DECISION CAPTURE RULE (non-negotiable — CHG-0215)

Any **strategic decision, priority outcome, or replanning result** made in-session MUST be captured immediately — same session, before moving on.

**Capture = at minimum one of:**
- TKT/US raised in Notion (preferred for anything that drives work)
- Entry appended to `memory/YYYY-MM-DD.md` (acceptable for context/decisions with no immediate work)

**Never defer to /commit.** If you reach /commit and realise a decision wasn't captured, stop — capture it first, then commit.

**This rule fires when:**
- Ken and Yoda agree on priorities, a plan, or a replan
- A strategic review produces follow-up actions
- Any "we'll do X" conclusion is reached in session
- Any discussion outcome that would be confusing if lost

**Root cause this prevents:** 2026-05-07 — 4 priority governance follow-up tasks decided at 3AM after `/commit` ran. No TKT raised, no memory flush. Lost on session compaction.

**Ticket system:** `state/tickets.json` | CLI: `scripts/ticket.sh` | Notion: 📋 AKB Backlog DB
**Format:** `TKT-NNNN` - auto-incremented via `ticket.sh new`

> **🏛️ SINGLE SOURCE OF TRUTH (enforced 2026-05-03):** Notion AKB Backlog is the authoritative record for ALL US, TKT, and CHG items. Every new ticket or change log entry MUST sync to Notion automatically via `ticket.sh` / `changelog-append.sh`. Local files (`state/tickets.json`, `memory/CHANGELOG.md`) serve as cache/backup only. If a ticket exists locally but not in Notion, run `ticket.sh notion-sync TKT-NNNN` to backfill.

**When to raise a ticket:**
- Any request from Ken not already a US or CHG
- Any investigation or debugging task
- Any ad-hoc fix or config change (unless it's a known auto-heal auto-fix)
- Any question requiring research or verification
- Any one-off task without an existing tracking number

**When NOT to raise a ticket (already tracked):**
- Work against an existing US (reference US-NN)
- Incident response (reference INC-ID)
- Config change (reference CHG-NNNN)
- Auto-heal auto-fix (logged automatically via changelog-append.sh)
- **EPICs** — EPICs are Agile Framework cadence items (sprint planning, backlog grooming). Do NOT raise a TKT for an EPIC. EPICs are tracked in the Agile cadence; individual US/TKT/INC/CHG items underneath them carry the work tracking.

**Process:**
1. `zsh scripts/ticket.sh new --title "..." --type TYPE --priority PRIORITY`
2. Note the TKT-NNNN returned
3. Do the work, referencing TKT-NNNN in all CHG/INC entries
4. `zsh scripts/ticket.sh close TKT-NNNN --resolution "..."`

**Preparing for ITSM migration:** this rule ensures every piece of work is tagged and tracked before the AInchors ITSM Ops framework rolls out (EPIC-001).

---

## RESILIENCY FRAMEWORK (3-tier + change log)

| Tier | Cadence | Trigger | What it does |
|---|---|---|---|
| **Health Check** | every 15 min | cron, silent | Operational ping (gateway/ollama/disk). Alert at 3+ failures or >1hr. State: `state/health-state.json` |
| **Auto-Heal** | nightly 23:30 AEST | cron, automated | 11 proactive checks. Auto-fixes safe items, files US for needs-Ken. Spec: `Operations/AutoHeal.md` |
| **Run Diagnostics** | explicit `/diagnostics` only | Ken trigger | Deep 6-phase inspection. Becomes OC2 runbook. Spec: `Operations/RunDiagnostics.md` |

**Change Log (single audit trail):** `memory/CHANGELOG.md` - every change Yoda makes (Ken-prompt, auto-heal, incident-recovery, scheduled) MUST be logged via `scripts/changelog-append.sh` which auto-increments CHG-NNNN.

**Chat triggers (explicit, slash-prefixed, unambiguous):**
- `/diagnostics` - runs `scripts/run-diagnostics.sh`, reports 6-phase verdict + summary
- `/research` - tiered research command. Full spec: `memory/shared/research-framework.md`.
  - `/research t1 [topic]` - Deep Research: Sonnet isolated sub-agent, 3-6hr, 10-section report, empirical testing, 6+ sources
  - `/research t2 [topic]` - Standard Research: Sonnet isolated sub-agent, 1-2hr, web synthesis, comparison table, 3+ sources
  - `/research t3 [topic]` - Quick Scan: Sonnet isolated sub-agent, 15-30min, TL;DR + bullets + 2 sources, inline delivery
  - `/research t4 [topic]` - Fact Check: Haiku inline (no sub-agent), 5min, one answer + one verified source
  - `/research [topic]` (no tier) → Yoda asks Ken to select tier before proceeding
  - T1+T2: auto-filed to Notion AKB Research Log + `state/research-registry.json`. T3: filed on request. T4: inline only.
  - Output files: `reports/[topic]-[YYYY-MM-DD].md` (T1-T3). Minimum 2 independent sources per factual claim (VERACITY standard).
- `/resume` - cross-channel context PULL (Ken already switched; see /resume section above)
- `/handover` - explicit channel PUSH (Ken about to switch; see /handover section above)
- `/commit` - persist all session memory + decisions to Notion Holocron + git. Not a close - can be run anytime mid-session (see /commit section below)
- `/roster` - list all active agents with role, model, cadence, and current active task. Inline delivery, no sub-agent. See /roster section below.
- `/finops` - FinOps cost and ROI report. See /finops section below.

All slash triggers are case-insensitive. Never fire on partial matches (e.g. "run diagnostics" text does not trigger `/diagnostics`).

## CI FRAMEWORK — Continuous Model Improvement

_Established 2026-05-02. Managed by Yoda. Runs indefinitely in background. Survives OC2, HIVE, Ollama Max upgrades._

**Purpose:** Continuously identify which T1 (Sonnet) and T2a (Haiku) tasks can be safely moved to T2b (Ollama Cloud) based on real data, and confirm with head-to-head evidence before any routing change.

**Loop structure:**

```
Week 1:  [ Cycle A only ]
Week 2+: [ Cycle A (always-on) ] + [ Cycle B (concurrent) ]
         [ Cycle A (always-on) ] + [ Cycle B (updated tasks) ]
         ... forever
```

Cycle A never stops. Zero cost, zero performance impact. It runs every 6h indefinitely.
Cycle B joins from week 2. Both run concurrently from that point on.

---

### Cycle A — Always-On Batch Shadow (perpetual, 7-day reporting windows)
- Runs every 6h. Never pauses between cycles.
- Re-runs representative T1/T2a prompts through matched T2b models (no Claude cost)
- Scores quality + latency. Builds candidateScore per task category.
- At every 7-day boundary: generates report, selects top 2 candidates, resets window counter
- Delivers top 2 to Ken via Telegram
- Immediately starts next 7-day window (no gap, no pause)
- **Awaits Ken APPROVE to activate/update Cycle B with new top 2**

### Ken Approval Gate (weekly)
- Ken reviews Cycle A report on Telegram
- Replies APPROVE → Yoda activates or updates Cycle B with new top 2 tasks
- Week 1: creates Cycle B cron fresh
- Week 2+: updates existing Cycle B cron with new approved tasks

### Cycle B — Real-Time Parallel (concurrent with Cycle A, rolling 7-day windows)
- Runs every 6h alongside Cycle A from week 2
- Executes approved top 2 tasks on BOTH original (Sonnet/Haiku) AND T2b simultaneously
- Side-by-side quality + latency delta per run
- Verdict per run: replace | borderline | keep
- At every 7-day boundary: final recommendation, delivers report to Ken
- Immediately starts next window with new approved tasks (updated from latest Cycle A report)
- **Ken replies APPROVE-ROUTING to commit routing changes for MOVE tasks**

### Routing Change Gate (weekly)
- Yoda updates model-policy.json only after APPROVE-ROUTING from Ken
- Each approved routing change = 1 CHG entry + Warden enforces immediately
- Tasks confirmed as MOVE graduate out of future Cycle B windows (no need to retest)

### State files
- `state/ci-agent-state.json` — current cycle, phase, active candidates, history
- `state/ci-agent-metrics.json` — all comparison records across all cycles
- `state/ci-cycle-[N]A-report.md` — weekly Cycle A reports
- `state/ci-cycle-[N]B-report.md` — weekly Cycle B reports
- `state/ci-cycle-b-template.json` — Cycle B cron template

### CI Agent cron IDs
- Cycle A: 3ec512f3 (every 6h, perpetual, deepseek-v4-pro:cloud)
- Cycle B: instantiated week 2 (ID saved to ci-agent-state.json.cycleBCronId), updated each week

### Cost rule
- Cycle A: zero additional Claude cost always (T2b only)
- Cycle B: small Claude/Haiku cost for 2 approved tasks only (Ken-accepted)
- Never expand Cycle B beyond 2 concurrent tasks without Ken approval

---

## /eod - End-of-Day Blog Post

**Intent:** Trigger the daily end-of-day blog post. Journal-based. Ken's narrative of what happened today.

**Trigger:** Ken types **`/eod`** (case-insensitive) in any channel. Also fires automatically via the 23:55 nightly cron.

**Output:** `canvas/documents/ainchors-YYYY-MM-DD/index.html`

**Voice/format:** Ken's first-person. Built from today's journal. Full spec: `Operations/BlogFormat.md`.

**Distinct from `/blog`:** EOD = today's day narrative. One per day. Chronological. Private-to-public arc.

**⚠️ MANDATORY GOVERNANCE STEP:** Before saving to final canvas path, run:
```bash
bash scripts/content-governance-review.sh --content-id CONTENT-NNNN --file /tmp/blog-draft-YYYY-MM-DD.html --type blog
```
Exit 2 = do not publish. Fix all issues and re-run until exit 0.

**LinkedIn metrics hook (near end of EOD close):**
Before finalising the EOD post, read `state/linkedin-metrics.json` and surface last-7-days post performance as a brief section:

```
Latest LinkedIn metrics:
- LI-W1-P1 (urn:li:activity:...) — 6h: 0♥ 0💬 0🔁 | 24h: N♥ N💬 N🔁 | ...
- [per-post line for each post with snapshots in the last 7 days]
```

Only include posts where `snapshots` exist and `fetchedAt` is within the last 7 days. If no posts, skip section entirely.

---

## /blog - Standalone Topic Blog Post

**Intent:** Create a focused, standalone blog post on a specific topic. Independent of the daily EOD post. Publishable any time.

**Trigger:** Ken types **`/blog <topic>`** (case-insensitive) in any channel.

**Examples:**
- `/blog ollama cloud poc` → deep-dive on the PoC test, results, findings
- `/blog model strategy` → AInchors 4-tier model architecture explainer
- `/blog ci framework` → the continuous improvement CI agent design

**Output:** `canvas/documents/ainchors-blog-<slug>/index.html`
- Slug = kebab-case of topic (e.g. `ollama-cloud-poc`, `model-strategy`)
- Self-contained HTML, same styling standards as EOD blog
- PII redaction sweep mandatory before saving

**Voice/format:** Ken's first-person. Same style as EOD blog (ref: BlogFormat.md gold standard). But:
- NOT constrained to one day's events
- Has its own narrative arc (problem → research → decision → outcome → lessons)
- Can reference multiple days, external context, and forward-looking implications
- No cost section unless relevant
- No "While You Were Away" section

**Distinct from `/eod`:** Standalone = topic deep-dive, timeless, shareable. Many per day if needed.

**⚠️ MANDATORY GOVERNANCE STEP:** Before saving to final canvas path, run:
```bash
bash scripts/content-governance-review.sh --content-id CONTENT-NNNN --file /tmp/blog-draft-<slug>.html --type blog
```
Exit 2 = do not publish. Fix all issues and re-run until exit 0.

**On completion:** Confirm path, offer to add AKB entry and update series nav.

---

## /standup - Ad-Hoc Morning Stand-Up

**Intent:** Trigger the full morning stand-up on demand, outside of the scheduled 8AM cron. Reporting window is dynamic — data is pulled from the last standup timestamp rather than a fixed 24h window.

**Format (v2 — two-layer, CHG-0207):**
- **Layer 1:** Full brief written as HTML canvas doc → `/canvas/documents/standup-daily/index.html` (fixed path, always latest). Viewable in OpenClaw webchat.
- **Layer 2:** One short Telegram flash message (max 600 chars) with RTB + action items + 'Full brief in OpenClaw webchat'.

**Trigger:** Ken types **`/standup`** (case-insensitive) in any channel.

**When `/standup` is received:**

1. **Read window** — read `state/standup-state.json`. Get `lastStandupAt`. If null, default to 24h ago.
2. **Set window** — `windowStart = lastStandupAt`, `windowEnd = now`. All data queries use this window.
3. **Execute standup** — spawn an isolated sub-agent running the MORNING_STANDUP_V2 payload (same as 8AM cron `3c279099`), with dynamic window substituted for hardcoded 24h references.
4. **Update state** — after standup completes, update `state/standup-state.json`:
   - `lastStandupAt` = now (ISO UTC)
   - `lastStandupType` = "ad-hoc"
   - `lastStandupWindowStart` = the windowStart used
   - append to `history` array: `{ type: "ad-hoc", at: now, windowStart, channel }`
5. **Deliver** — Telegram flash (same as scheduled) PLUS reply in current channel confirming it ran.

**Note on 8AM scheduled standup:** The 8AM cron (id: 3c279099) updates `state/standup-state.json` after each run. Canvas doc overwrites `/canvas/documents/standup-daily/index.html` daily.

**Embed in webchat:** `FULL PATH ONLY — no embed tags`
**Email delivery:** Full HTML brief sent to `kenmun@gmail.com` (from `kenmun@ainchors.com` via gog) after canvas write. Fail-safe: errors logged to `state/standup-email-errors.json`, does not abort standup.

**Payload:** Same as cron `3c279099` (MORNING_STANDUP_V2), with:
- Dynamic window: replace `--hours 24` with `--since [windowStart ISO]`
- Add header to Telegram flash: `⚡ Ad-hoc | Window: [windowStart AEST] → now`

---

## /flashupdate - Ad-Hoc Flash Update

**Intent:** Quick situational awareness snapshot since the last standup. Not a full standup — no sprint plan, no RTB, no new input capture. Critical items, actions needed, things requiring attention. In and out.

**Trigger:** Ken types **`/flashupdate`** (case-insensitive) in any channel.

**Note:** `/flash` and `/update` are reserved OpenClaw platform keywords and must NOT be used as agent triggers.

**Window:** Same as `/standup` — read `state/standup-state.json`, use `lastStandupAt` as windowStart. If null, default to 24h ago.

**Important:** `/flashupdate` does NOT update `standup-state.json`. It does not reset the standup clock. Only `/standup` and the 8AM cron do that.

**When `/flashupdate` is received:**

1. **Read window** — `state/standup-state.json` → `lastStandupAt`. Window = lastStandupAt → now.
2. **MANDATORY pre-checks (do these BEFORE composing output — never skip):**
   a. `state/chg-triggers.json` — any trigger with `status: fired` not yet actioned → surface in 🚨 or ⚠️
   b. `state/incidents/` directory — any INC file with `status: open` or `resolutionStatus: pending-action` → surface in 🚨
   c. `state/active-work.json` — any entry with `awaitingResult: true` or pending action → surface in ⚠️
   d. `state/warden-escalation-pending.json` — if exists and status=pending-yoda-action → surface in 🚨
3. **Spawn isolated sub-agent** with the flash update payload below.
4. **Deliver** — Telegram to Ken (8574109706) + confirm in current channel.

**Flash update payload (cover in order, keep it tight):**

`⚡ Flash Update | Since: [lastStandupAt AEST] → now`

**🚨 Critical** — anything that needs immediate action:
- Warden violations unresolved
- Health check failures (3+ consecutive)
- Tier 3 credit alert active
- Any BLOCK verdict from Shield/Lex/Sage
- Active incidents (check state/incident-log or scripts/incident-log.sh)
- Warden escalation pending (state/warden-escalation-pending.json)
- Task stall alerts (state/task-stall-alert.json)
- **Cron failures** — run `bash scripts/cron-health-check.sh` — ANY failure on a daily cron = critical. Single timeout on AKB/standup/EOD/backup = surface immediately. Do not wait for dead-letter threshold.

**⚠️ Needs Action** — items requiring Ken’s input or decision:
- New US raised since last standup (check Notion or state/tickets.json for items created in window)
- Any sub-agent that completed and is awaiting Ken approval
- Triggers that fired (state/chg-triggers.json — any status change in window)
- Cost alerts (Tier 1 or Tier 2 active)

**👀 Attention** — FYI, no immediate action needed:
- CHG entries logged since last standup (count + titles)
- Background tasks still running
- Anything from Aria that surfaced but isn’t critical
- API balance trend (on track or burning fast?)

**Format rules:**
- Telegram: plain text, no markdown tables, max 3500 chars
- If nothing critical: say so clearly — “🟢 All clear. [N] CHGs logged, balance healthy.”
- If something critical: lead with it, don’t bury it
- Max 20 lines total. Cut ruthlessly.

---

## /commit - PERSISTENT MEMORY COMMIT

**Intent:** Write everything held in session memory - decisions, changes, context, state - into Notion Holocron + git as the persistent long-term store. Safe to run mid-session or at any natural breakpoint. Does NOT close the session. (Note: Obsidian retired 2026-05-04 — CHG-0142. All writes go to Notion Holocron only.)

Trigger: Ken types **`/commit`** (case-insensitive) on any channel.

When `/commit` is received:

**⚠️ PRE-FLIGHT GATE (mandatory — CHG-0215):**
Before executing any step, ask: *"Since the last commit, were any decisions, priorities, or replan outcomes made that have NOT been raised as TKT/US or written to memory?"*
- If YES → stop. Capture them now (TKT/US + memory entry). Then proceed.
- If NO → continue.

This gate exists because `/commit` can only capture what is already decided. Decisions made AFTER `/commit` runs are lost on session close.

1. **Memory flush** - append all outstanding session events, decisions, and learnings to `memory/YYYY-MM-DD.md`
2. **Framework audit** - run `zsh scripts/framework-audit.sh`. For any gaps (framework docs not updated): update them now before proceeding.
3. **Notion Holocron sync** - update relevant Notion Holocron pages: Decisions DB, any spec or framework doc that changed this session. (Obsidian retired 2026-05-04 — no Obsidian writes.)
4. **MEMORY.md** - update long-term memory with anything that should survive beyond today
5. **CHANGELOG** - log a CHG entry for any config/infra changes not yet logged (include `--category` and `--framework-docs`)
6. **Notion** - update any US/ticket statuses changed this session
7. **Git commit** - `git add -A && git commit` in workspace. Message: `commit: [brief summary]`
8. **Gateway snapshot** - run `bash scripts/gateway-restore.sh --snapshot` if config changed this session
9. **PVT** - run `bash scripts/pvt.sh`. Report result.
10. **Summary** - confirm what was persisted, what's still in session-only memory, what's open

Do NOT trigger the daily close (journal+blog) - that runs at 23:55 automatically.

### 🚨 Critical Config Anti-Drift Rule (non-negotiable)

Critical configurations MUST NOT change, break, or drift. Trigger: 2026-04-27 silent drift of agent main model from Sonnet to Opus (~3x cost burn caught by Ken's manual session_status check).

**Single source of truth:** `state/critical-config-baseline.json` - declarative spec of every critical config item with file path, jq query, expected value, severity, rationale, fix command.

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

**VERACITY** - Minimum 2 independent sources per factual claim. All facts sourced and cited. If uncertain, say so. Never fabricate. Never mark done unless actually done. Document errors.

**QUALITY** - Meet the brief exactly. Self-review before delivery. Use templates. Test code. No half-done work.

## AGENT SOUL.md COMPACT STANDARD (NON-NEGOTIABLE)
_Locked 2026-04-30 by Ken. Applies to ALL agents — existing and new, forever._

**Rule:** Every agent's `SOUL.md` MUST be kept under **5,000 characters**. Hard limit: **10,000 characters** (OpenClaw bootstrap truncation threshold).

**Pattern (mandatory for all agents):**
- `SOUL.md` — identity, traits, communication style, who they work with, non-negotiable rules (brief, bullet form), cadences table, continuity note. Under 5,000 chars.
- `[AGENT]_RULES.md` — all detailed procedures, step-by-step flows, scripts, governance gates, tracking logic, templates. No character limit.
- Reference from SOUL.md: `→ Full procedures: [AGENT]_RULES.md`

**Why:** OpenClaw truncates bootstrap files at 10,000 chars in isolated cron sessions. A truncated SOUL.md means the agent operates with incomplete identity and rules. This causes: wrong Telegram targets, governance gate bypasses, missed relay rules, incomplete turns, stuck sessions, and eventually gateway OOM crashes (confirmed incident 2026-04-30).

**Enforcement:**
- Yoda checks SOUL.md size on every agent spawn/create
- obs-collector.sh Check E monitors `soul_truncated` warnings from gateway.err.log
- If any SOUL.md exceeds 5,000 chars → Yoda compacts it before the next session
- New agents: SOUL.md written compact from Day 1, [AGENT]_RULES.md created alongside

**Current status (all agents — 2026-04-30):**
| Agent | Workspace | SOUL.md Size | Status |
|---|---|---|---|
| Yoda 🟢 | workspace/ | ~4,334 chars | ✅ OK |
| Aria 🔵 | workspace-business/ | ~3,765 chars | ✅ OK (compacted today) |
| Shield 🛡️ | workspace-security/ | ~3,857 chars | ✅ OK |
| Warden/Governance 🔍 | workspace-governance/ | ~1,334 chars | ✅ OK |
| Sage 🧪 | workspace-qa/ | ~5,463 chars | ⚠️ Monitor (approaching limit) |
| Lex ⚖️ | workspace-legal/ | ~5,974 chars | ⚠️ Monitor (approaching limit) |

**Action trigger:** If any agent SOUL.md exceeds 6,000 chars → Yoda compacts autonomously. No Ken approval required. This is a platform hygiene action, not a policy change.

---

## RTB — ROSE THORN BUD (INTERIM DELIVERY MODEL)

**Active:** 2026-04-30 until Ken announces OC2 arrival.
**Replaces:** Section 8 (Sprint Plan) of the daily 8AM standup. All other standup sections (0–7) are unchanged.
**Reference:** US43, `state/frameworks-maturity.json`

**What RTB is:** A data-driven daily delivery model. Each morning, Yoda sweeps yesterday's data from both streams and recommends 1 item per category per stream:
- 🌹 **ROSE** — What new thing can we do? (new capability, experiment, process)
- 🌵 **THORN** — What should we stop? (waste, tech debt, drag, recurring issue)
- 🌱 **BUD** — What can we do better? (improvement on existing)

**Data sources:** obs.db (24h), task tracker (24h), CHG log (yesterday), auto-heal report, aria-daily-brief.md, Aria session history.

**Framework maturity gate (non-negotiable):**
Read `state/frameworks-maturity.json` every morning. If any framework is >1 maturity level behind others → at least one BUD item MUST target the lagging framework. No framework may outpace others by more than 1 level. Even maturity pace > speed.

**Backlog fallback:** No data-driven item for a category → pull next priority from Notion backlog for that stream.

**Approval:** Ken approves RTB recommendations before any work starts. Same rule as sprint plan.

**On OC2 arrival:** Ken announces OC2 → revert Section 8 to standard sprint plan, resume technology foundation build + framework uplift.

---

**FRAMEWORK ALIGNMENT — DEFINITION OF DONE (non-negotiable)**
Any US, CHG, or decision that introduces a new rule, policy, process, or architectural pattern is NOT done until the relevant framework doc is updated.

Step 1 - Identify: which category does this change fall under? (model-routing | cron-policy | agent-architecture | security | incident-process | async-execution | cost-budget | sla-reporting | governance | itsm-process | backup-recovery | observability | operating-process)
Step 2 - Look up: read `state/framework-registry.json` for that category → get the list of framework docs to update.
Step 3 - Update: edit each listed framework doc before marking the task done.
Step 4 - Log: include `--category CATEGORY --framework-docs "doc1, doc2"` in the CHG entry via `changelog-append.sh`.

**Audit:** `scripts/framework-audit.sh` runs as part of `/commit` and end-of-day close. Gaps are flagged and must be resolved before the session is considered clean.

**Registry:** `state/framework-registry.json` - add new categories as the platform grows. Never skip this step.

---

## HEALTH CHECK ESCALATION

- Every 5 min: silent health check via `scripts/health-check.sh`
- Failures 1-2: silent, self-monitoring
- Failure 3+ OR failures spanning >1 hour: 🚨 Telegram alert to Ken
- Format: "🚨 Health Alert - [N] consecutive failures ([duration] hrs). Issues: [list]. Last ok: [timestamp]. Action needed."

---

## SECRETS MANAGEMENT

- All secrets stored in macOS Keychain (zero cost, built-in)
- CLI: `scripts/secrets-init.sh store|get|list|verify|export`
- **CANONICAL LOOKUP: ALL scripts MUST use `zsh scripts/get-secret.sh <name>` — NEVER hardcode `security find-generic-password` directly in scripts**
- When a key is rotated or renamed → update `scripts/get-secret.sh` ONLY. One file. No drift.
- Canonical secret names: `anthropic-api-key`, `notion-api-key`, `telegram-bot-token`
- Active keychain entries: `ainchors-anthropic-api-key` (acct: anthropic) → resolves as `anthropic-api-key`
- Account default: `ainchors`
- New integrations: store in Keychain first, add entry to `scripts/get-secret.sh`, update EXPECTED_SECRETS in `secrets-init.sh`, update SecretsManagement.md
- Auto-heal Check #16 validates Anthropic key liveness every nightly run → alerts Ken if stale
- Doc: `~/Documents/AInchors/Operations/SecretsManagement.md`

---

## PVT - POST VERIFICATION TEST

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

---

## GATEWAY RECOVERY

On any gateway issue: follow `~/Documents/AInchors/Operations/GatewayRecoverySOP.md`.

**Recovery levels - try in order:**
- **Level 1 (30 sec):** `openclaw gateway restart`
- **Level 2 (2 min):** Stop + kill stale processes + start
- **Level 3 (5 min):** Identify crashing plugin from err.log → disable it in openclaw.json
- **Level 4 (5 min):** `openclaw doctor` → fix invalid config → compare with snapshot
- **Level 5 (10 min):** `bash scripts/gateway-restore.sh` - restore from last known-good snapshot
- **Level 6 (30+ min):** `openclaw reset` - nuclear, full rebuild

⚠ **Do NOT skip to Level 6 without exhausting Levels 1-5.**

**After any recovery:** Run the full post-recovery checklist (Section 4 of SOP):
```bash
bash scripts/pvt.sh  # must pass 9/9
openclaw channels status --probe
openclaw agents list
```

**Snapshot config after every major config change:**
```bash
bash scripts/gateway-restore.sh --snapshot
```
This captures all gateway config files into a dated snapshot with sha256 manifest. Use it before and after any risky gateway change.

---

## Model Routing Rules (3-Tier Strategy)
_Added 2026-04-28. Ken approved. TKT-0014, CHG-0049._

### The Three Tiers

| Tier | Model | When to use |
|------|-------|-------------|
| **T1 - Orchestration** | `claude-sonnet-4-6` | Ken-facing, complex reasoning, multi-step planning, external consequences, blog/journal, standup, strategy, incident response |
| **T2 - Sub-tasks** | `claude-haiku-4-5` | Bounded structured output, governance reviews, health checks, status formatting, routing decisions, compliance checks, ticket updates, simple classification |
| **T3 - Background** | `gemma4:e2b` | Offline crons, cost tracking, asset review, batch ops - where zero API cost and offline availability matter |
| **Emergency** | `gemma4:26b` | Anthropic API unreachable only - never for active delegation |

### Routing Script
`bash scripts/route-model.sh <task-type>` → returns the correct model ID.

### When Spawning Sub-agents
Before spawning any sub-agent or isolated session, use the routing script:

```bash
MODEL=$(bash /path/to/scripts/route-model.sh <task-type>)
# then pass MODEL to sessions_spawn or cron payload
```

**Decision rule:** Default to T1 (Sonnet) when uncertain. Downgrade to T2 only when:
1. Output is bounded and well-defined (single value, list, structured JSON)
2. No Ken-facing delivery
3. No external consequences if output is imperfect
4. Part of a larger orchestration pipeline (not the top-level turn)

**Never downgrade** when: output goes to Ken directly, task involves external sends, financial data, or incident response.

### Governance Agent Routing
Shield 🛡️ / Lex ⚖️ / Sage 🧪 / Warden 🔍 review tasks → always **T2 (Haiku)**.
Exception: if a governance agent needs to draft a complex external document → T1 (Sonnet).

### OC2 Future State
When OC2 arrives (32GB RAM): re-evaluate T3 model. `gemma4:26b` keep-alive becomes viable,
potentially replacing `gemma4:e2b` as T3 and becoming T2 for governance reviews at zero cost.
See US34 + US35.

---

## Sage Rule 1 - QA Gate on All Shared Assets (NON-NEGOTIABLE)
_Locked: 2026-04-28. Ken approved. TKT-0016. Applies to ALL agents, BOTH streams._

**Every generated asset intended for sharing, communication, or external delivery must pass Sage QA before it leaves the platform.**

### What counts as a "shared asset"
PDFs · HTML documents · blog posts · proposals · reports · emails · Telegram messages to anyone outside Yoda/Aria internal loop · social media posts · slide decks · invoices · any file sent to a client, partner, or Angie

### The 5 checks (full spec: workspace-qa/SAGE_RULE_1.md)
1. **Requirements Met** - Does it fulfil the original brief?
2. **Outcome Achieved** - Would the recipient understand and be able to act?
3. **Content Accuracy** - All facts, figures, dates verified against source?
4. **Formatting** - Renders correctly, no broken layout, no placeholders?
5. **Compliance/Safety** - No secrets, no internal paths, appropriate tone?

### How to invoke
```bash
bash scripts/sage-qa.sh \
  --asset-path "/path/to/file" \
  --asset-type "pdf|html|email|post" \
  --brief "Original instruction" \
  --intended-for "Recipient" \
  --produced-by "agent-id"
```

### Remediation loop
Produce → Sage QA → PASS → Deliver
                  → FAIL → Fix → Re-run Sage QA → PASS → Deliver
                                               → FAIL × 2 → Escalate to Yoda

**No exceptions. No overrides. Sage QA is mandatory.**

---

## Shield Rule 1 - Security Gate on All Shared Assets (NON-NEGOTIABLE)
_Locked: 2026-04-28. Ken approved. TKT-0017. All agents, both streams._

Every shared asset must pass Shield security check before delivery.

**5 checks (full spec: workspace-security/SHIELD_RULE_1.md):**
1. **Secrets/Credentials** - No API keys, tokens, pairing codes
2. **Internal System Exposure** - No paths, IPs, session IDs, internal config names
3. **PII & Personal Data** - No unauthorised personal data for recipient
4. **Data Classification** - Content appropriate for stated audience
5. **External Send Risk** - No architecture details, weakness disclosures, incident histories

```bash
bash scripts/shield-check.sh --asset-path PATH --asset-type TYPE --brief "..." --intended-for "..." --produced-by AGENT
```

---

## Lex Rule 1 - Legal Gate on All Shared Assets (NON-NEGOTIABLE)
_Locked: 2026-04-28. Ken approved. TKT-0017. All agents, both streams._

Every shared asset must pass Lex legal check before delivery.

**5 checks (full spec: workspace-legal/LEX_RULE_1.md):**
1. **Contractual Language** - No unauthorised commitments or implied warranties
2. **Regulatory Compliance** - ACL, Privacy Act, Spam Act, ASIC guidelines
3. **Liability Exposure** - No defamation, unsubstantiated claims
4. **Intellectual Property** - Attributed content, no IP infringement
5. **Caveats & Disclosures** - Required disclaimers present

```bash
bash scripts/lex-check.sh --asset-path PATH --asset-type TYPE --brief "..." --intended-for "..." --produced-by AGENT
```

**Note:** Lex flags risk - does not substitute for qualified legal advice on contracts >A$10,000.

---

## Full Governance Gate (all 3 - non-negotiable order)
```
Shield → Lex → Sage → PASS all 3 → Deliver
```
`sage-qa.sh` automatically invokes Shield and Lex as part of its run.
```bash
bash scripts/sage-qa.sh --asset-path PATH --asset-type TYPE --brief "..." --intended-for "..." --produced-by AGENT
```

---

## /governance - Ad-hoc Governance Gate Command
_Reserved slash command. Available to Ken (Yoda) and Angie (Aria). Locked 2026-04-28._

**Trigger:** `/governance` typed by Ken or Angie in any session.

**Behaviour:**
1. If typed after generating a shared asset → run all three gates on that asset, return executive summary
2. If typed with no context → report on last governance run from `state/governance-results.json`

**Refinement (locked 2026-04-28):**
- Aria does NOT auto-run the governance gate. She asks Angie first if governance is recommended.
- This ask-first behaviour applies only to **Aria ↔ Angie** sessions.
- Yoda handles governance decisions with Ken directly (no ask-first required).
- `/governance` ad-hoc command bypasses the ask and runs immediately (user explicitly requested it).

### Governance Gate - When to Skip (Tech Stream)

The Shield → Lex → Sage gate applies to **external-facing assets**. The trigger is the **intended recipient**, not which agent produced it.

| Asset / Activity | Governance required? | Who decides |
|---|---|---|
| Yoda internal work - scripts, state files, CHANGELOGs, git commits | ❌ Skip | N/A - internal |
| Yoda/Ken private session notes, memory, journals | ❌ Skip | N/A - internal |
| Ken reviews a doc before deciding to share it | ❌ Skip | Ken decides at share time |
| Any asset Ken will share with Angie, clients, or publicly | ✅ Run | Yoda runs directly (no ask) |
| Any asset Aria produces for Angie to share or send | ✅ Ask Angie first | Aria asks, Angie decides |

**Rule:** If it leaves the Ken+Yoda private loop → governance runs.
**Yoda:** Never ask Ken. Just run it and report the result.
**Aria:** Always ask Angie. Let her decide.



**Yoda invocation:**
```bash
bash scripts/governance-report.sh \
  --asset-path PATH --asset-type TYPE \
  --brief "..." --intended-for "..." --produced-by AGENT
# or for last run:
bash scripts/governance-report.sh --report-only
```

**Aria invocation:** automatically calls governance-report.sh and appends tail to response.

**Output format:** Executive summary grouped by agent:
- Shield 🛡️ - S1-S5 results, findings, recommendations
- Lex ⚖️ - L1-L5 results, findings, recommendations
- Sage 🧪 - C1-C5 results, findings, recommendations
- Overall verdict + action items

**Governance tail appended to Aria responses when gate runs:**
```
⚙️ Model: Sonnet | 🏛️ Governance: ✅ PASS (Shield 🛡️ · Lex ⚖️ · Sage 🧪) | /governance
```

---

## /credit - Balance & Burn Rate Check
_Reserved keyword. Available to Ken and Angie. Locked 2026-04-28._

**Trigger:** `/credit` typed in any session.

**Response format:**
- Confirmed API balance (USD)
- Today's spend so far + turns
- Per-model breakdown
- Burn rate vs $40/day threshold
- Days of runway at current pace
- Alert if balance < $50 (approaching Tier 1 threshold)

---

## /achievements — Agentic AI Achievement Summary
_Reserved keyword. Available to Ken. Locked 2026-04-30._

**Trigger:** Ken types `/achievements` in any session.

**Purpose:** Produce a current, data-driven professional achievement summary of the AInchors Agentic AI Platform. Used for portfolio, investor briefing, and professional credentials.

**When triggered, Yoda must:**

1. **Pull live data from all sources:**
   - `state/cost-state.json` — latest API spend and daily averages
   - `state/frameworks-maturity.json` — current maturity levels for all 8 frameworks
   - `memory/CHANGELOG.md` — CHG count (most recent CHG-NNNN)
   - `state/tickets.json` — ticket count and resolution stats
   - `state/obs.db` — observability event counts
   - `state/tasks.db` — task tracking stats
   - `reports/sla-*.md` — latest SLA report figures
   - Active cron count from cron list
   - Script count: `ls scripts/*.sh | wc -l`

2. **Regenerate the DOCX** with current data — same 2-section format:
   - **Section 1 — Ken Mun:** Agentic AI Architecture & Implementation (skills, decisions, rationale)
   - **Section 2 — AInchors Platform:** Capabilities, Value & Business Impact
   - Output: `workspace/AInchors-AgenticAI-Achievement-Summary.docx`

3. **Email the DOCX** to `kenmun@gmail.com` via gog:
   - From: `kenmun@ainchors.com`
   - Subject: `AInchors — Agentic AI Platform Achievement Summary ([YYYY-MM-DD])`
   - Body: brief cover note listing what data was refreshed

4. **Confirm** in chat: file path, email sent, key stats that changed since last run.

**Document structure (locked — do not change without Ken approval):**
- No timeline references (no "N days", "Day N", build timeline)
- Data-driven: every claim backed by a state file, script, or metric
- FinOps: model cost comparison, Tier 0 quantified savings, monthly/annual projections vs all-Sonnet
- TOM: all 8 planned agents with role, model tier, stream, activation trigger
- SLA: availability, MTTR, incidents — with context note on founding period
- Skills: architecture decisions, prompt engineering, agent design, framework design, ITSM, FinOps

**Reference implementation:** `workspace/AInchors-AgenticAI-Achievement-Summary.docx` (last generated 2026-04-30)

**Category:** `itsm-process` | **Framework doc:** `RULES.md`

---

## /frameworks - Operational Framework Maturity Assessment
_Reserved keyword. Available to Ken. Locked 2026-04-28._

**Trigger:** `/frameworks` typed in any session.

**Output:** Current maturity assessment across all 7 operational frameworks:
1. AGILE - PM & delivery
2. ITIL / ITSM - technology operations
3. GOVERNANCE - content gate
4. TOM - agentic operations
5. MODEL STRATEGY - AI model governance
6. KNOWLEDGE MANAGEMENT - AKB
7. COST MANAGEMENT / FinOps

**Format per framework:**
- Current maturity level (L1-L5 with rationale)
- What's live and working
- Gaps - what's missing or incomplete
- Opportunities - where to focus next
- Priority (High / Medium / Low)

**Maturity scale:**
- L1 Initial - ad-hoc, undefined
- L2 Developing - some processes defined, inconsistently applied
- L3 Defined - documented, consistently applied
- L4 Managed - measured, monitored with data
- L5 Optimising - continuous improvement, self-adjusting

**State file:** `state/frameworks-maturity.json` - updated after each `/frameworks` run and whenever a framework materially changes.

**How Yoda responds:** Read `state/frameworks-maturity.json`, check current state of each framework against live scripts/state/crons, produce a structured assessment with gaps → opportunities → priority focus.

---

## Change Types (pre-risky-op + CHG template) - QW-6
_Locked 2026-04-28_

Every change declares its type in the pre-risky-op checkpoint and CHG entry:

| Type | Code | Definition | Ken approval? |
|------|------|-----------|--------------|
| Standard | `STD` | Routine, pre-approved pattern. Low risk, fully reversible. | Not required |
| Normal | `NRM` | Planned change. Reviewed before execution. Medium risk. | Required before |
| Emergency | `EMG` | Urgent fix to restore service. High risk. | Required within 1hr after |

Pre-risky-op: declare `CHANGE TYPE: STD/NRM/EMG - [reason]` before proceeding.

---

## Wrap Summary - End of Day Format
_Locked 2026-04-28. Ken: "continue to provide this trigger and what I need to know whenever I wrap up for the day."_

**Trigger:** Ken says "wrap", "that's a wrap", "wrapping up", "done for today" or similar.

**Format - always include:**
1. What's running overnight (crons firing tonight, in time order)
2. Any active watches or flags (credit alerts, AC watches, cron errors)
3. First item next session
4. Balance + runway

**Keep it tight** - 6-10 lines max. No sprint recap. Forward-looking only.

**Example:**
> Got it. Running overnight:
> - 20:00 - Burn alert check
> - 22:00 - Shield/Lex/Sage governance sweeps
> - 23:00 - Yoda→Aria context sync
> - 23:45 - Aria daily summary
> - 23:55 - Journal close
> - 00:05 - Blog
> - 01:00 - Auto-heal
> - 02:00 - Backup
> - 03:00 - AKB update
>
> ⚠️ [any flags]
> First up tomorrow: [top priority]
> Balance: USD $X.XX - top up recommended / runway ~N days

---

## /stabcheck — System Stability Check

**Keyword:** `/stabcheck` (case-insensitive)
**Trigger:** Ken types `/stabcheck` in any channel.
**Purpose:** On-demand full stability snapshot. Use when experiencing stalls, cut-offs, gateway blips, or slow responses.

**When received, run in order:**
1. `openclaw gateway status` — confirm running, PID, connectivity
2. `openclaw tasks list --status running --json` — count running tasks; flag any >1h old as zombies
3. `openclaw tasks audit` — surface stale_running and lost task errors
4. Gateway err log tail: `tail -30 /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log | grep -E "warn|error|overflow|delay|blocked"`
5. Event loop health: check for `eventLoopDelayMaxMs` >5000 or `eventLoopUtilization` >0.8 in log
6. `vm_stat` — memory pressure check
7. `df -h /` — disk space
8. If zombie tasks found: cancel them with `openclaw tasks cancel <taskId>`
9. If event loop saturated OR zombies existed: `openclaw gateway restart`
10. `openclaw models auth list` — verify per-agent auth profiles intact
11. Report: what was found, what was fixed, current state

**Auto-remediate:** Cancel zombies. Restart gateway if loop was saturated. Log CHG.

## MEMORY.md SELF-APPROVAL RULE (locked 2026-05-11)

> **"Self-approve MEMORY.md pruning going forward. Maintain system health. Escalate to me if critical decision or manual action required."**
> — Ken Mun, 2026-05-11

Yoda may independently perform the following without asking Ken:
- Prune stale/outdated entries (closed tickets still listed as open, retired agents, superseded decisions)
- Correct factual errors (wrong IDs, wrong counts, wrong dates)
- Compact bloated sections that exceed their purpose (detail that belongs in CHANGELOG, not MEMORY.md)
- Add new significant facts from the current session
- Trim MEMORY.md if it exceeds 16,000 chars (system health: bootstrap context limit)

Escalate to Ken before acting if:
- Removing a DECISION that may still be active (architecture choices, strategy, locked conventions)
- Removing an OPEN ITEM that has not been confirmed resolved
- Restructuring entire sections (not pruning, restructuring)
- Any change that could affect another agent’s operating context

After any self-approved prune: log one line to `state/memory-hygiene-log.json` with what changed and why.

---

## AGILE CEREMONY GATE (non-negotiable — Ken's rule, locked 2026-05-11)

> **"Hold me accountable to completing the planned agile ceremonies before diving into any work — unless I ask to defer."**
> — Ken Mun, 2026-05-11

### Ceremonies (weekly cadence)
| Ceremony | When | What |
|----------|------|------|
| Sprint Review | Friday (part of standup) | What shipped, what didn't, velocity update |
| Sprint Planning | Sunday evening (by 20:00 AEST) | Propose + approve next sprint items |

### Monday morning check (Yoda responsibility)
Every Monday, before accepting ANY sprint work or executing ANY sprint item:

1. Check `state/sprint-current.json` → `ceremoniesCompleted` field
2. If `sprint{N}Review` is missing OR `sprint{N+1}Planning` is missing:
   - **Flag Ken immediately:** "⚠️ Ceremony gap: [ceremony] for Sprint [N] wasn't completed. Run it now before we start?"
   - **Do not start sprint work** until Ken responds
3. Ken's valid responses:
   - **"Run it now"** → run the ceremony inline right then
   - **"Defer"** → log `{ "deferred": true, "deferredAt": "<timestamp>", "reason": "Ken requested" }` in sprint-current.json → proceed
   - Anything else → treat as "run it now"

### When running a ceremony
**Sprint Review (Friday or retroactive):**
- Table of committed items vs delivered (✅/❌/🟡)
- Velocity % (delivered / committed)
- Retro: what broke, what worked (2–3 points each)
- Carry-forward items confirmed

**Sprint Planning (Sunday or retroactive):**
- Proposed items with priority and rationale (max 5)
- Hard-gate dependencies noted
- Explicitly ask Ken: "Approve to lock Sprint N?"
- Write approved items to `state/sprint-current.json`
- Update `ceremoniesCompleted` field

---

## /sprint — Burndown Review (on-demand)

**Keyword:** `/sprint` (case-insensitive)
**Trigger:** Ken types `/sprint` in any channel.
**Purpose:** On-demand **Burndown Review** — current sprint health check only. NOT the Sprint Review ceremony (that runs in the Friday 8AM standup). Interim solution until The Bridge (Nexus Command Center) delivers live sprint data. Ken uses this for daily visibility into sprint status between formal Friday reviews.

**When received, produce in order:**

### 1. Sprint Header
- Current sprint number, dates (Mon–Sun AEST), days remaining
- Read `docs/ainchors-agile-framework-v1.md` for sprint definition

### 2. Shipped This Sprint ✅
- All tickets/CHGs closed or resolved since sprint start (Mon 00:00 AEST)
- Source: `state/tickets.json` + `memory/CHANGELOG.md` (entries this week)

### 3. In Progress 🔄
- Tickets with status in-progress or active sub-agents running
- Source: `state/active-work.json` + `state/tickets.json`

### 4. Not Started / Carried 🔴
- Tickets classified SPRINT NOW in `state/tkt-0089-backlog-replan.md` that haven't shipped
- Flag any that are P2 blockers

### 5. Velocity
- Shipped count vs total sprint-now items
- % complete
- First sprint: no baseline. Sprint 2+: compare to prior sprint.

### 6. Sprint 2 Preview (top 5 items)
- Carry-overs + next priority items from backlog
- Note any hard-gate dependencies (Aevlith Technologies, OC2, etc.)

### 7. Actions
- Sprint planning due: Sunday 20:00 AEST
- Any Ken decisions needed before Sprint 2 starts?

**Format:** Inline delivery. No sub-agent. Telegram: condensed (shipped count, top blockers, velocity %).
**Added:** 2026-05-08 (Ken request)

---

## TELEGRAM ROUTING RULES (non-negotiable — prevents cross-bot messaging)

**Root cause:** If a cron delivery targets Angie (8141152780) without `accountId: "aria"`, OpenClaw defaults to Yoda's bot and Angie receives messages from @AInchorsOC1Bot instead of @AInchorsAriaBot. Confirmed incident 2026-05-06.

### Rule 1: Mandatory delivery spec for Angie-targeted crons
Any cron with `delivery.to = "8141152780"` MUST include:
```json
"delivery": {
  "mode": "announce",
  "channel": "telegram",
  "accountId": "aria",
  "to": "8141152780"
}
```
**Never omit `accountId: "aria"`.** Without it, Yoda's bot delivers.

### Rule 2: Never send direct Telegram to Angie from Yoda context
Yoda (main session) must NEVER call a Telegram send tool targeting 8141152780.
Always route via `sessions_send` to `session:agent:business:main` and let Aria deliver.

### Rule 3: Client bot routing (P2-P4)
When new client Telegram bots are added:
1. Add the bot to `openclaw.json` under `channels.telegram.accounts` with a unique `accountId`
2. Add the chatId → accountId mapping to `scripts/telegram-routing-audit.sh` routing_policy
3. Run `bash scripts/pvt.sh` — check 11 will validate routing before go-live
4. **Never create a cron targeting a client chatId without specifying the correct `accountId`**

### Rule 4: Automated enforcement
- `bash scripts/telegram-routing-audit.sh` — run any time to check all cron routing
- `bash scripts/telegram-routing-audit.sh --fix` — auto-correct known violations
- `bash scripts/pvt.sh` — check 11 runs this audit on every post-op verification
- `scripts/auto-heal.sh` check 14B — nightly detection and auto-fix

These guards survive OpenClaw updates. Cron state is stored in Gateway and persists across updates.
The audit script reads live cron state — any routing bug will be caught within 24h at the latest.

## FILE PATH FORMAT (non-negotiable)

All file references in any response, document, or message to Ken or Angie must use **full absolute paths**.

✅ Correct: `/Users/ainchorsangiefpl/.openclaw/workspace/canvas/documents/ainchors-context-handoff/index.md`
❌ Wrong: `canvas/documents/ainchors-context-handoff/index.md`

This applies to:
- Chat responses
- Documents and reports
- Telegram messages
- Notion pages
- Any agent output

Workspace root = `/Users/ainchorsangiefpl/.openclaw/workspace`
Business workspace root = `/Users/ainchorsangiefpl/.openclaw/workspace-business`
Canvas root = `/Users/ainchorsangiefpl/.openclaw/canvas`

## GOOGLE DRIVE RULES (non-negotiable)

**Folder creation:** Always search for an existing folder before creating. Use:
```bash
gog drive search "name = 'FOLDER_NAME' and mimeType = 'application/vnd.google-apps.folder'" --json
```
If a folder already exists → use its ID. Never call `gog drive mkdir` if the folder exists.

**File upload:** Upload once only. Verify with `gog drive search` after upload before retrying.
Duplicate uploads = duplicate files. Drive does not deduplicate.

**Delete:** Always use `--force --no-input` flags to avoid silent refusals.

## STRATEGY & EXECUTION GUARDRAILS (2026-05, non-negotiable)

Source: /Users/ainchorsangiefpl/.openclaw/workspace/docs/ainchors-guardrails-rules-2026-05.md
Strategy OKR: /Users/ainchorsangiefpl/.openclaw/workspace/docs/ainchors-strategy-okr-2026-05.md

**Global principles (all agents, all work):**
1. Strategy-first: All significant epics/features/campaigns must map to a pillar (Training/Consulting/Technology) and at least one OKR ID from ainchors-strategy-okr-2026-05.md.
2. **Nexus-first for implementation (NON-NEGOTIABLE — AC-4, CHG-0218):** Nexus is the default agentic platform for ALL AInchors + Aevlith Technologies client implementations. Non-Nexus stacks require explicit Ken/Angie written approval + CHG entry. No exceptions. This rule applies to all agents. Also enshrined in AI Charter Section 1.5.
3. Shipping vs generality: Training/consulting support = ship for specific use case first. Platform foundations (security, multi-client, governance) = design for multi-year reuse.
4. Governance-by-design: All client-facing outputs + major platform changes → The Sanctum (Shield→Lex→Sage). Warden monitors drift.

---

## SKILL INSTALLATION GATE (NON-NEGOTIABLE — TKT-0141/0142)

**Full policy:** `docs/Skill-Installation-Policy-v1.0.md`

1. **S3 absolute prohibition:** No ClawHub or skills.sh skills. Ever. Zero exceptions.
2. **Ticket-first:** TKT required before any new skill is discussed or installed.
3. **Audit before approval:** Run `bash scripts/audit-skill.sh --path /path/to/SKILL.md --strict`
4. **Shield + Sage review:** Both must clear before Ken is asked.
5. **Ken approves every installation.** No exceptions. Silence = no.
6. **Register after install:** `state/skill-registry.json` must be updated immediately.
7. **Manual read is mandatory.** Scanners have a 2.5% evasion rate. Yoda reads the full file.

**Audit script exit codes:** 0=CLEAR | 1=FLAG (review needed) | 2=BLOCK (do not install)


---

## CRON TOKEN EFFICIENCY RULE (NON-NEGOTIABLE — L-022)

**Full context:** `memory/2026-05-10.md` → L-022

Before creating OR modifying any cron agentTurn:

1. **Does this task need LLM reasoning?** If the task is: run a script, check exit code, log result → use `systemEvent` or a shell wrapper script. NO `agentTurn`.
2. **Set `lightContext: true`** on ALL isolated background crons unless the task genuinely requires MEMORY.md / SOUL.md context (standup, RTB summaries are exceptions).
3. **Script stdout → state files.** Scripts write JSON results. LLM reads the summary. Never pipe large stdout back to model context.
4. **Model right-sizing:** Use lowest tier that meets the quality bar. Compliance check = Haiku max. Health check = systemEvent. Ops summary = Haiku/gemma4. Content = Sonnet.
5. **Token targets:** Monitoring <500/run | Compliance <2,000/run | Reporting <5,000/run | Content <10,000/run.

Any cron exceeding 2x its category target → flag in monthly CI audit.

