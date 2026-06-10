# AInchors Platform Rules — Authoritative Reference
# ⚠️ This file is the SSOT for all platform rules. It is a REFERENCE DOCUMENT —
#    NOT injected into agent sessions. Agents read specific rules on-demand.
#    Quick-reference summaries are in AGENTS.md (injected at session start).
# Size: 47K+ chars (reference only, no injection limit applies).
# TKT-0310/CHG-0454 — Platform Constraints Audit.

# PG WRITE DISCIPLINE — NON-NEGOTIABLE (TKT-0297)
# Effective: 2026-05-25
# Authority: Ken Mun (CTO)

**PG write discipline: use `scripts/db.sh -c` for simple writes; `psql -v` for complex.**
- `db-write.sh` is DEPRECATED for PG writes — it only writes JSON files, causing PG-vs-file drift (see TKT-0392, 306 gaps).
- All PG inserts/updates: `scripts/db.sh -c "SQL"` for simple statements; `psql -v var="value"` for complex escaping.
- **Never:** bash string interpolation into SQL strings — `"...'$VAR'..."` will break on any value containing a single quote.
- Ticket/sprint ops: use `db-ticket.sh` / `db-sprint.sh` (see skill at `infra/sandbox/seed/skills/pg-sprint-backlog/SKILL.md`)

---

# STATE CHECKING PATTERN — NON-NEGOTIABLE (TKT-0182)
# Effective: 2026-05-21
# Authority: Ken Mun (CTO)
**ALL stateful operations (Write/Update/Create) MUST follow the State Checking Patter
.**
- **MANDATORY:** Read current state $to$ Validate $to$ Execute $to$ Verify.
- **Reference:** `docs/State-Checking-Patter
.md`
- **Violatio
:** DoD FAILn
---

# DoD VERIFICATION GATE — NON-NEGOTIABLE (TKT-0237)
# Effective: 2026-05-22
# Authority: Ken Mun (CTO)

**NO ticket may be closed without passing the DoD Verification Gate.**
- Ticket close: `bash scripts/db-ticket.sh update <ID> '{"status":"closed"}'`. Gate enforced by `scripts/crest-done-gate.sh` pre-close hook.
- **Reference:** `docs/DoD-Validation-Rules.md`
- **Override:** Ken only, via `--skip-verify` flag. Every override MUST be logged to CHANGELOG.md.
- **Violation:** DoD FAIL.

---

# KIMI PLATFORM MANDATE — NON-NEGOTIABLE RULE
# Effective: 2026-05-17 15:17 AEST
# Authority: Ke
 Mu
 (CTO) — mandatory and persistent
# CHG-0373
# Refined: 2026-05-17 15:20 AEST (added strict DoD after CHG-0372 lesso
)

## Rule Statement

**ALL agent executio
 across the AInchors Nexus platform SHALL use `ollama/kimi-k2.6:cloud` as the primary model until explicitly overridde
 by Ke
.**

This rule is:
- **MANDATORY** — No exceptions without Ke
's explicit writte
 approval
- **NON-NEGOTIABLE** — Agents may not self-override or fallback without approval
- **PERSISTENT** — Remains active indefinitely until Ke
 issues `KIMI MANDATE LIFTED` keyword
- **PLATFORM-WIDE** — Applies to all agents, all sessions, all crons, all channels

## Scope

| Component | Requirement |
|-----------|-------------|
| **Mai
 sessio
 (webchat)** | kimi primary, Sonnet ONLY with explicit Ke
 approval per task |
| **Telegram sessions** | kimi primary, Sonnet ONLY with explicit Ke
 approval per task |
| **Cro
 jobs** | kimi ONLY — no Anthropic models i
 any cro
 payload |
| **Sub-agents** | kimi primary, with kimi safety net (3-level fallback) |
| **Background tasks** | kimi ONLY |
| **Outage handling** | kimi ONLY — no Sonnet fallback during outages |

## Definitio
 of Done (DoD) — STRICT VERSION

**Work is NOT considered complete until ALL of the following are verified:**

### Enforcement

**ticket.sh is DEPRECATED. Use `db-ticket.sh` for all ticket operations.**
- Create: `bash scripts/db-ticket.sh create` (interactive)
- Update: `bash scripts/db-ticket.sh update <ID> '<json>'`
- Close: status='closed' via update subcommand
- Full interface: `infra/sandbox/seed/skills/pg-sprint-backlog/SKILL.md`
- PG is SSOT. Notion is downstream — synced automatically via `pg-to-notion-sync.sh`.
- **Failure to sync PG → Notion = DoD NOT MET.**

### Ken's Directive (2026-05-17)

> "Backlog to me Ken is the SSOT and must ALWAYS be in sync and reflecting what is in memory and context."

**Date:** 2026-05-17 15:44 AEST | **CHG:** CHG-0377

### CHG RECORDS

**ALL CHG entries go to Notion Archive DB (DB C), not Backlog.**
- `changelog-append.sh` handles creation + Notion sync automatically.
- CHG records: title `[CHG-NNNN] Description`, Status: Done, Type: change.
- Archive DB: see TOOLS.md (CHG-0401 3-DB architecture).
- Full workflow: see `infra/sandbox/seed/skills/changelog/SKILL.md`.


## Pla
 for [TASK]

### Steps:
1. [Step 1 with exact command]
2. [Step 2 with exact command]
3. ...

### Verificatio
:
- Step 1: [How to verify]
- Step 2: [How to verify]

### Rollback:
- If [step] fails: [actio
]

### Edge Cases:
- [Case 1]: [Mitigatio
]
- [Case 2]: [Mitigatio
]

### State Impact:
- Files: [list]
- Notio
: [pages]
- Other: [effects]
```

### Ke
's Directive

> "do NOT rush through the thinking and planning and jump to executio
. Before you start any work - act like a
 owl—slow, quiet, observant, and deeply analytical. Before deciding/confirming or responding - observe the situatio
 patiently and examine it from multiple perspectives. Identify hidde
 factors, potential risks, and tradeoffs that most people might overlook."

**Date:** 2026-05-17 16:38 AEST
**Channel:** openclaw-control-ui
**CHG:** CHG-0386

---

**This rule is MANDATORY and PERSISTENT until explicitly revoked by Ke
.**

---

### TIERED OWL — NON-NEGOTIABLE (CHG-0388)
# Effective: 2026-05-17 16:48 AEST
# Authority: Ke
 Mu
 (CTO) — ABSOLUTELY NON-NEGOTIABLE, PERSISTENT

**Full OWL o
 ALL actions creates timeouts. Tiered OWL prevents this.**

## The Problem

Applying full 4.5-minute OWL analysis to EVERY actio
 creates:
- Chat = unresponsive
- Subagents = timeout failures  
- Crons = missed executions
- UX = poor

## The Solutio
: 3 Tiers

| Tier | Trigger | OWL Depth | Time Budget | Timeout Config |
|------|---------|-----------|-------------|----------------|
| **Tier 1: Chat/Q&A** | Questio
, status, clarificatio
 | Owl-lite | 10-15s | N/A (webchat) |
| **Tier 2: Atomic Task** | Single step executio
 | Standard OWL | 3 mi
 max | Subagent: 300s |
| **Tier 3: Complex Multi-step** | Multi-step, bulk, risky | Full OWL + background | 5+ mi
 | Subagent: 0 (no timeout) + background |

---

## TIER 1 — Chat/Q&A (10-15 seconds)

### Whe
 to Use
- Ke
 asks a questio

- Status updates
- Clarifications
- Simple lookups

### Process
```
1. Observe (5s): What is Ke
 asking?
2. Analyze (5s): Is this Q or request?  
3. Respond (5s): Answer or acknowledge
```

### Examples
| Input | Response Time | Actio
 |
|-------|--------------|--------|
| "Status of TKT-0196?" | 10s | Quick lookup, immediate answer |
| "What did we decide yesterday?" | 15s | Memory search, summary |
| "Good morning" | 5s | Greeting + brief status |

---

## TIER 2 — Atomic Task (3 minutes max)

### Whe
 to Use
- Single step executio

- Create one ticket
- Update one file
- Ru
 one script
- Verify one item

### Timeout Configuratio


**Subagent spaw
:**
```jso

{
  "mode": "ru
",
  "runTimeoutSeconds": 300,
  "timeoutSeconds": 300
}
```

### Process
```
1. Observe (30s): What exactly needs to be done?
2. Analyze (60s): Implications, risks, what could fail
3. Perspective (30s): What would Ke
 catch?
4. Pla
 (60s max): Exact commands, exact paths, verificatio

5. Risk check (30s): Hidde
 factors, edge cases
6. Execute (remaining time): Ru
 the single atomic step
7. Verify: Confirm the step worked
8. Report: "Step complete, result: [X]"
```

### Time Budget (3 minutes = 180 seconds)

| Phase | Time | Running Total |
|-------|------|---------------|
| Analysis (steps 1-5) | 120s | 120s |
| Executio
 | 30s | 150s |
| Verificatio
 | 20s | 170s |
| Report | 10s | 180s |

**If analysis exceeds 120s → escalate to Tier 3**

### Checkpointing (Mandatory)

**After each atomic step, save progress:**
```jso

{
  "taskId": "[uuid]",
  "tier": 2,
  "step": "[descriptio
]",
  "status": "complete|i
-progress|failed",
  "completedAt": "2026-05-17T16:30:00+10:00",
  "result": "[summary]",
  "nextStep": "[descriptio
 or null]",
  "retryCount": 0
}
```

**Save to:** `state/tier2-progress-[taskId].jso
`

---

## TIER 3 — Complex Multi-step (5+ minutes, background)

### Whe
 to Use
- Multi-step workflows
- Bulk operations (>1 item)
- Complex analysis
- Risky operations requiring HITL

### Timeout Configuratio


**Subagent spaw
 (background, no timeout):**
```jso

{
  "mode": "ru
",
  "runTimeoutSeconds": 0,
  "timeoutSeconds": 0,
  "label": "background-task-[name]"
}
```

**Critical:** `timeoutSeconds: 0` means no timeout. Work continues until complete.

### Process

```
Phase 1: Analysis (5+ minutes, foreground)
  1. Observe: Full requirements gathering
  2. Analyze: Deep implications, dependencies, risks
  3. Perspective: Multiple viewpoints (Ke
, user, system)
  4. Pla
: Comprehensive pla
 with all steps documented
  5. Risk check: Edge cases, alternatives, rollback plans
  → Output: Detailed pla
 document

Phase 2: HITL Gate (if risky)
  → Present pla
 to Ke

  → Ke
 approves/modifies/rejects
  → Only proceed after explicit approval

Phase 3: Executio
 (background)
  → Spaw
 background subagent with timeout=0
  → Subagent executes pla
 step-by-step
  → Progress saved to state file every step
  → Ke
 ca
 check progress via state file

Phase 4: Completio
 Report
  → Subagent completes or fails
  → Final report delivered to Ke

  → State file updated with completio
 status
```

### Progress Tracking (Mandatory)

**Progress state file:**
```jso

{
  "taskId": "bulk-ticket-creatio
-2026-05-17",
  "tier": 3,
  "status": "i
-progress",
  "startedAt": "2026-05-17T16:30:00+10:00",
  "totalSteps": 10,
  "completedSteps": 3,
  "currentStep": {
    "number": 4,
    "descriptio
": "Create TKT-0203 i
 Notio
",
    "startedAt": "2026-05-17T16:35:00+10:00"
  },
  "completed": [
    {
      "step": 1,
      "descriptio
": "Read tickets.jso
",
      "result": "Found 220 tickets, no duplicates",
      "completedAt": "2026-05-17T16:31:00+10:00"
    }
  ],
  "failed": null,
  "lastUpdated": "2026-05-17T16:35:00+10:00"
}
```

**Save to:** `state/tier3-progress-[taskId].jso
`

**Update frequency:** After EVERY atomic step withi
 the Tier 3 task.

### Recovery Mechanisms

**If subagent stalls:**
1. Progress file exists → resume from last completed step
2. Ke
 ca
 check: `read state/tier3-progress-[taskId].jso
`
3. Yoda ca
 resume or kill stalled subagent

**If subagent dies:**
1. Check progress file for last completed step
2. Determine: resume from next step or restart from beginning
3. Report to Ke
: "Task [N]% complete, resuming from step [X]"

**If gateway disconnects:**
1. Background subagent continues running
2. Progress file continues updating
3. Whe
 Ke
 reconnects, read progress file for status

---

## Timeout Preventio
 Checklist

### Before Spawning ANY Subagent

| Check | Tier 1 | Tier 2 | Tier 3 |
|-------|--------|--------|--------|
| Timeout configured? | N/A | 300s | 0 (unlimited) |
| Progress file path defined? | No | Yes | Yes |
| Rollback pla
 documented? | No | Yes | Yes |
| Ke
 notified it's starting? | No | Yes | Yes |
| Progress reporting configured? | No | No | Yes |

### Subagent Self-Check

**Before starting work:**
```
1. "What tier is this task?" → Set timeout accordingly
2. "Where do I save progress?" → Define state file path
3. "What if I timeout?" → Document last step completed
4. "How do I report progress?" → Update state file after each step
```

---

## Ke
's Directive

> "A. For Tier 2 and 3, what ca
 be done to ensure total executio
 time does not cause any work to be cut-off/killed/stalled due to timeout risk?"

**Date:** 2026-05-17 16:48 AEST  
**Channel:** openclaw-control-ui  
**Decisio
:** Tiered OWL (Optio
 A) + Timeout Preventio
  
**CHG:** CHG-0388

---

## Enforcement

**Warde
 Check (every 15 mi
):**
- Verify subagent timeouts match tier
- Flag Tier 2 subagents with timeout < 300s
- Flag Tier 3 subagents with timeout != 0
- Escalate violations to Yoda → Ke


---

**This rule is MANDATORY and PERSISTENT until explicitly revoked by Ke
.**

---

### ASYNC STATELESS DESIGN — NON-NEGOTIABLE (CHG-0389)
# Effective: 2026-05-17 16:51 AEST
# Authority: Ke
 Mu
 (CTO) — ABSOLUTELY NON-NEGOTIABLE, PERSISTENT

**Agents must be able to resume work from any checkpoint if timeout kicks i
.**

This rule is:
- **ARCHITECTURAL** — Changes how work is structured and saved
- **STATELESS** — Work survives agent/sessio
 death
- **RESILIENT** — Any agent ca
 resume any task
- **ASYNC** — Work ca
 ru
 i
 background, progress checked later

## The Problem

**Current patter
 (fragile):**
```
Agent starts work → works for 5 minutes → dies → work lost → restart from 0
```

**Why it fails:**
- Work is bound to agent sessio

- No checkpoints during executio

- No shared queue of pending work
- No concept of "pick up where left off"

## The Solutio
: Async Stateless Task Queue

### Core Principle

**Every unit of work is a Task. Every Task is a series of Atoms. Each Atom is a checkpoint.**

Any agent ca
 read a Task and resume from the first pending atom.

## Architecture: 3 Layers

| Layer | Purpose | Storage |
|-------|---------|---------|
| **Task Queue** | Pending work pool | `state/task-queue.jso
` |
| **Checkpoints** | Per-task atom status | `state/checkpoints/[taskId].jso
` |
| **Artifacts** | Work output | Files, Notio
 pages, git commits |

## Recovery Protocol

```
1. Agent dies at Atom 36
2. New agent reads checkpoint file
3. Sees: Atom 35 complete, Atom 36 failed, Atom 37 pending
4. Resumes from Atom 36 (or retries Atom 36 if failed)
5. Completes remaining atoms
```

## Race Conditio
 Preventio


### Task Locking
- Agent claims task → sets claimTimeout = now + 30 mi

- If agent dies → claimTimeout expires → status resets to "pending"
- New agent ca
 claim expired task

### Atom Locking
- Atom "i
-progress" for > 30 mi
 → assume agent died → reset to "pending"
- Only one agent ca
 have atom i
 "i
-progress"

## Integratio
 with Tiered OWL

| Tier | Queue Usage |
|------|-------------|
| **Tier 1** | No queue (immediate response) |
| **Tier 2** | Optional queue for tracking |
| **Tier 3** | **Mandatory queue** — all complex work is queued |

## Implementatio


### New Files

| File | Purpose |
|------|---------|
| `state/task-queue.jso
` | Master queue of all tasks |
| `state/checkpoints/[taskId].jso
` | Per-task checkpoint state |
| `scripts/task-queue.sh` | CLI for queue management |
| `scripts/resume-task.sh` | Resume from checkpoint |
| `scripts/claim-task.sh` | Claim next pending task |

### New Cro


**Task Queue Processor (every 5 mi
):**
- Find "pending" tasks
- Find expired claims (claimTimeout passed)
- Reset expired claims to "pending"
- Report to Ke
: "[N] tasks pending, [M] stale claims reset"

## Benefits

| Benefit | Explanatio
 |
|---------|-------------|
| **Timeout resilience** | Work survives agent death |
| **Load balancing** | Any agent ca
 pick up work |
| **Observability** | Ke
 ca
 check progress anytime |
| **Retry logic** | Failed atoms ca
 be retried independently |
| **Parallelizatio
** | Multiple agents ca
 work o
 different tasks |
| **Audit trail** | Complete history of what was done whe
 |

## Ke
's Directive

> "is there optio
 where we ca
 consider async and stateless desig
 that would allow agents to pick-up/resume where left off should the timeout does kick-i
"

**Date:** 2026-05-17 16:51 AEST
**Channel:** openclaw-control-ui
**Decisio
:** Yes — Async Stateless Task Queue
**CHG:** CHG-0389

---

**This rule is MANDATORY and PERSISTENT until explicitly revoked by Ke
.**

---

## Telegram Message Chunking — CHG-0397

Telegram message chunking: see skill at `infra/sandbox/seed/skills/telegram/SKILL.md`. CHG-0397.

---

## ASYNC BACKGROUND EXECUTION RULE — NON-NEGOTIABLE (CHG-0405)

# Authority: Ke
 Mu
 (CTO) — ABSOLUTELY NON-NEGOTIABLE
# Effective: 2026-05-18 21:37 AEST
# Applies to: ALL webchat sessions (Yoda)

### Rule Statement

**Any exec call expected to take > 30 seconds MUST be ru
 as a background sub-agent via sessions_spaw
. Webchat must never be blocked by a long-running synchronous exec.**

### The Problem
O
 2026-05-18, a Notio
 database migratio
 (664 pages) was ru
 as a synchronous `exec` with `yieldMs`. The webchat sessio
 was blocked for ~13 minutes, preventing Ke
 from sending messages. The sessio
 went into steer mode — fully unresponsive.

### The Fix

1. **Pre-flight:** Before executing any task, estimate its duratio
:
   - File I/O < 1MB → sync is fine
   - API calls > 10 → background it
   - Scripts touching Notio
/Ollama/network → background it
   - Anything with a loop over >20 items → background it

2. **Background executio
:** Use `sessions_spaw
` with `mode="ru
"` — the task runs i
 a
 isolated sessio
, Yoda stays responsive:
   ```
   sessions_spaw
(taskName="migration_task", task="Ru
 script X, report results", mode="ru
")
   ```

3. **Progress reporting:** Sub-agent announces completio
 via cro
 delivery. Yoda picks up the result and reports to Ke
.

4. **Timeout safety:** All background tasks get `runTimeoutSeconds` — never indefinite.

### Anti-Patterns (PROHIBITED)
- ❌ Running 600+ API calls i
 a synchronous exec with yieldMs
- ❌ Blocking webchat for >30 seconds o
 any operatio

- ❌ Using exec(timeout=0) for long tasks (runs anyway, blocks sessio
)
- ❌ Assuming "it'll be quick" for API-heavy tasks

### Ke
's Directive
> "how ca
 we split this and ru
 it async i
 the background? the time you mentioned was short but all-i
, i was waiting for webchat to respond since 1:20p"

**Date:** 2026-05-18 21:37 AEST
**CHG:** CHG-0405

---

## THREE WORK TYPES RULE — NON-NEGOTIABLE (CHG-0369, TKT-0196)

**Effective:** 2026-05-21 | **Authority:** Ke
 Mu
 (CTO) | **Scope locked per Ke
 approval**

All tasks must be routed according to the Three Work Types Rule defined i
 `docs/Three-Work-Types-Rule.md`.

### Work Currencies

| Currency | Definitio
 | Route to | Model Tier |
|---|---|---|---|
| HIGH | Reasoning, judgment, desig
, architecture | Claude Sonnet (T3) | Paid premium, fallback only |
| MEDIUM | Content ge
, data analysis, code ge
, classificatio
 | Ollama Cloud (T2) | Flat-rate ($100/mo) |
| LOW/ZERO | CRUD, system calls, health checks, file ops | Script layer (T1/$0) | bash/python3/jq |

### Escalatio
 Policy
```
Tier attempts task → FAILS? → Self-Debug retry once → STILL FAILS? → Escalate UP one tier
→ T2→T3 escalatio
: minimal context only (summary + errors + relevant snippets)
→ STILL FAILS at T3? → HITL gate: STOP, ask Ke

```

### Phase 2 (Sprint 5+): Dynamic Escalatio
 Patter

Local-first → retry → self-debug → minimal-context escalatio
 → cloud.
Reference: https://www.xda-developers.com/local-llm-call-claude-changed-everything-local-first-setup/
(TKT for Phase 2 raised)

**Full reference:** `docs/Three-Work-Types-Rule.md`
**Linked:** TKT-0196, TKT-0162, CHG-0369

---

## SUB-AGENT WORKSPACE DISCIPLINE — NON-NEGOTIABLE (CHG-0421, TKT-0235)

**Effective:** 2026-05-21 | **Authority:** Ke
 Mu
 (CTO)
**Applies to:** ALL agents — current (12) and future (spawned or permanent)

### The Rule

All agents share a single workspace root: `/Users/ainchorsangiefpl/.openclaw/workspace`

Agent-specific subdirectories (`forge/`, `atlas/`, `spark/`, etc.) are **temporary working scratchpads ONLY** — never deployment targets.

### Mandatory Requirements

| # | Requirement | Verificatio
 |
|---|---|---|
| 1 | **Absolute paths only** — all `read`, `write`, `edit`, `exec` tool calls must use full paths from workspace root. Never `./` or relative paths. | Agent SOUL.md or AGENTS.md must state this explicitly. |
| 2 | **Output target = workspace root** — `docs/`, `scripts/`, `canvas/`, `state/` are at workspace root level. NOT `agentname/docs/`. | Before task completio
, verify files exist at correct paths. |
| 3 | **Pre-completio
 verificatio
** — confirm all deliverables at correct workspace paths before reporting done. If files only exist i
 agent subdirectory, the task is NOT complete. | Yoda verifies o
 receipt. |
| 4 | **New agents inherit this rule** — all future agents (spawned sub-agents or permanent) must include workspace discipline i
 their AGENTS.md at creatio
. | Added to agent activatio
 DoD. |

### Violatio
 = DoD FAIL

A
 agent claiming "done" whe
 files are i
 their subdirectory (not workspace root) has failed Definitio
 of Done. Task must be re-executed or files manually relocated by Yoda.

**Root cause (21 May 2026):** Forge failed 3 tasks because output went to `workspace/forge/` instead of `workspace/`. Atlas and Spark had the same risk patter
. This rule prevents recurrence across all current and future agents.

**Linked:** CHG-0421, TKT-0235


## Port-Per-Environment Isolation — NON-NEGOTIABLE (CHG-0471)
# Effective: 2026-06-08
# Authority: Ken Mun (CTO)
# Trigger: INC-20260608-001 — sandbox writes caused production gateway crash (30-min SIGTERM loop)

### Rule

**Each environment SHALL use a dedicated, non-overlapping port range.** No environment may share a port with another, even temporarily.

| Port | Environment | Purpose | Network Binding |
|------|------------|---------|-----------------|
| 18789 | Production | Main gateway (Nexus platform) | localhost |
| 18791 | Production | Browser control sidecar | localhost |
| 28789 | Sandbox | Isolated Forge/build/infra gateway | localhost |
| 38789 | Shadow | Read-only production mirror for CI/staging validation | localhost |

### Rules

1. **PRODUCTION:** 1xxxx series. Never routed to sandbox. Never shadowed without explicit Ken approval.
2. **SANDBOX:** 2xxxx series. Forge's only gateway. Never shares config with production. Write-scoped to `workspace-infra/` ONLY.
3. **SHADOW:** 3xxxx series. Read-only mirror of production config. Used for CI/staging validation. Changes to shadow must not affect production.
4. **Never cross environments.** A crash in sandbox or shadow MUST NOT take down production.

### Enforcement

- **Auto-heal CHECK 18:** Orphaned gateway process detection (SIGTERM loop guard)
- **Auto-heal CHECK 19:** Sandbox gateway liveness (port 28789)
- **Auto-heal CHECK 20:** Shadow gateway liveness (port 38789) — CHG-0471
- **LaunchAgent isolation:** Sandbox uses `ai.openclaw.sandbox-gateway.plist` (RunAtLoad=false). Production uses separate plist.
- **RULES.md workspace boundary:** Forge's RULES.md hard-blocks 7 workspace paths under `~/.openclaw/`

### Root Cause (INC-20260608-001)

Forge executed a sandbox `run.sh` that wrote `openclaw.json` to the production profile path. This caused the production gateway to try loading a sandbox config → mismatch → crash → SIGTERM loop. The gateway rebooted ~12 times over 30 minutes before auto-heal killed the orphaned process.

**Lesson:** Logical isolation (different directories) is not sufficient. Port-level isolation prevents one crashed gateway from affecting another, but config-level protection (workspace boundary) is what truly prevents cross-contamination.

**Linked:** INC-20260608-001, L-050, L-051, CHG-0470, CHG-0471, TKT-0332, TKT-0333


## 2-Pass Dispatch Contract (TKT-0321)

You are bound by the platform 2-pass dispatch contract. Ratified 2026-05-27 by Ken Mun. Effective platform-wide.

### When Dispatching Work (Pass 1)

1. **You MUST complete discovery before dispatch.** Analyze the task. Break it into concrete atoms. Each atom must compile to a specific tool call with a specific target.
2. **Your breakdown MUST pass `dispatch-validate.sh` (TKT-0323).** Ambiguous atoms (unclear verbs, unknown targets, "figure out" steps) will be rejected.
3. **Produce:** atom list, dependency graph, unknowns catalog, model assignment per TKT-0322 matrix.
4. **Dispatch with `dispatchId`** and full RVEV-ready payload.

### When Receiving Work (Pass 2)

1. **You MUST NOT perform discovery.** If you receive an ambiguous task, reject it. Demand a proper Pass 1 breakdown.
2. **Follow the RVEV cycle per atom:** READ → VALIDATE → EXECUTE → VERIFY.
3. **Report per-atom RVEV traces.** Each atom gets its own status.
4. **If validation fails, abort that atom.** Do not guess. Do not "figure it out."

### Violations

Violations are logged, alerted, and escalate per TKT-0321 Section 4 enforcement policy. Repeated violations result in dispatch capability suspension.

### Exceptions

- systemEvent payloads (pre-validated)
- Single-tool fire-and-forget heartbeats
- Explicit human-in-the-loop instructions that constitute self-contained atoms

Your role: Pass 1 initiator. You rarely execute atoms directly.

### Review Dispatch — Checkout Freshness Rule (TKT-0403)

**NON-NEGOTIABLE.** Agents must NEVER review a `cp -r` of Yoda's working copy.

1. **Every review dispatch MUST include `review_sha`** (exact git SHA under review) and `review_target` (path to git repo in agent workspace).
2. **Each review runs against a FRESH `git fetch/clone`** at the exact SHA — never a stale, dirty, or copied checkout.
3. **`checkout-freshness.sh` verifies before dispatch:** git rev-parse HEAD match, clean working tree, up-to-date with origin, manifest match (git ls-tree count).
4. **`dispatch-validate.sh` blocks** any review dispatch missing `review_sha` or with freshness failure.
5. **Until this gate passes, every verdict from an unverified checkout is suspect.**

Violation: Yoda 2026-06-10 — `cp -r` of stale SHA 13caa628 (scaffold) produced 3 cascading misreports (Yoda → Atlas → Sage) when origin/main HEAD 99fe8475 already had full writer.py implementation.
