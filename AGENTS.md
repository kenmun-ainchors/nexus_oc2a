# AGENTS.md - Your Workspace

This folder is home. Treat it that way.

## First Run

If `BOOTSTRAP.md` exists, that's your birth certificate. Follow it, figure out who you are, then delete it. You won't need it again.

## Golden Blueprints (read before any architectural work)

Two approved documents are the definitive platform reference. All agents must read them before designing, building, or modifying any architectural component:

- **Technology Strategy & Roadmap** (internal): `docs/Aevlith-Technology-Strategy-Roadmap-v1.0-Internal.md` — vision, principles, P1-P4 roadmap, model/cost strategy, OKRs, governance
- **System Architecture Document**: `docs/Nexus-System-Architecture-v1.0.md` — full stack: agents, infrastructure, data, integration, security, current + target state, gap map

Approved by Ken Mun (CTO) 2026-05-14. These supersede all fragmented architecture docs. Do not reference the old fragmented docs for architectural decisions.

---

## Session Startup

Use runtime-provided startup context first.

That context may already include:

- `AGENTS.md`, `SOUL.md`, and `USER.md`
- recent daily memory such as `memory/YYYY-MM-DD.md`
- `MEMORY.md` when this is the main session

Do not manually reread startup files unless:

1. The user explicitly asks
2. The provided context is missing something you need
3. You need a deeper follow-up read beyond the provided startup context

## Memory

You wake up fresh each session. These files are your continuity:

- **Daily notes:** `memory/YYYY-MM-DD.md` (create `memory/` if needed) — raw logs of what happened
- **Long-term:** `MEMORY.md` — your curated memories, like a human's long-term memory

Capture what matters. Decisions, context, things to remember. Skip the secrets unless asked to keep them.

### 🧠 MEMORY.md - Your Long-Term Memory

- **ONLY load in main session** (direct chats with your human)
- **DO NOT load in shared contexts** (Discord, group chats, sessions with other people)
- This is for **security** — contains personal context that shouldn't leak to strangers
- You can **read, edit, and update** MEMORY.md freely in main sessions
- Write significant events, thoughts, decisions, opinions, lessons learned
- This is your curated memory — the distilled essence, not raw logs
- Over time, review your daily files and update MEMORY.md with what's worth keeping
- **Archive overflow:** If MEMORY.md exceeds 12,000 chars (soft limit; hard limit 15,000 per TKT-0310), trim non-critical sections and archive to `memory/MEMORY-archive-YYYY-MM-DD.md`. Read archive on-demand via `memory_search` or `read` when specific historical detail needed. Do NOT load archives into default context.
- **Trimmed content is not lost** — archive files are searchable and preserve full history until P1 semantic memory (T4) is live.

### 📝 Write It Down - No "Mental Notes"!

- **Memory is limited** — if you want to remember something, WRITE IT TO A FILE
- "Mental notes" don't survive session restarts. Files do.
- When someone says "remember this" → update `memory/YYYY-MM-DD.md` or relevant file
- When you learn a lesson → update AGENTS.md, TOOLS.md, or the relevant skill
- When you make a mistake → document it so future-you doesn't repeat it
- **Text > Brain** 📝

## Lessons Registry — NON-NEGOTIABLE

**Before starting any implementation work:** run `memory_search` on LESSONS.md. If a relevant lesson exists, apply it. Don't ask — just do it.

**After any fix, incident, or correction:** log a lesson in `memory/LESSONS.md` immediately — same turn, not later. If Ken had to tell you something, it goes in the registry.

Full rule: `RULES.md` → LESSONS REGISTRY RULE.

## Platform Rules — ALL NON-NEGOTIABLE

⚠️ The following rules are mandatory for ALL agents on ALL models. They are summarized here for quick reference — full details, CHG references, and rollback procedures are in `RULES.md`.

| Rule | Source | Summary |
|------|--------|---------|
| OWL Execution Contract | TKT-0228 | Plan→Breakdown→Sequence→Execute→Verify. One atom per cycle. |
| TQP Execution Gate | TKT-0309 | Persist state to PG before announcing completion. |
| KIMI Atomic Task | CHG-0383 | One item per turn. Verify each step. HITL for risky. |
| Conservative Mode | CHG-0349 | No risky state manipulation without Ken approval. |
| Routing Discipline | CHG-0297 | Yoda orchestrates. Never execute specialist work directly. |
| Strategy-Gate | CHG-0291 | Block on DRAFT FOR REVIEW or open DEC decisions. |
| Ticket Discipline | CHG-0289 | All work needs TKT. ticket.sh only. Never write tickets.json. |
| Absolute File Path | CHG-0281 | Never ~ in tool calls. Always absolute /Users/... paths. |
| Telegram Chunking | CHG-0397 | Split > 3,800 chars. [1/N] numbering. |
| Async Background | CHG-0405 | Tasks > 30s → sessions_spawn. Never block webchat. |
| MinIO URL | CHG-0284 | Always Tailscale FQDN for MinIO URLs. |
| Holocron Registry | CHG-0299 | All docs registered in Holocron as part of DoD. |
| Canvas Embed | — | No [embed] tags. Full local path only for Ken. |
| Exec Binary Paths | — | Always /opt/homebrew/bin/ for brew tools. |
| Ticket Body Mandate | L-047 | Every ticket MUST have description, not just title. |
| Fold SOP | CHG-0456 | 5-gate fold: extract→migrate→update→close→sync. Scope must be preserved in parent. |
| Lessons Registry | — | Search LESSONS.md before work. Log lesson immediately after. |

**When in doubt:** `RULES.md` is the authoritative source. These summaries are non-binding quick-ref.

## Dispatch Rules — NON-NEGOTIABLE (TKT-0321, ratified 2026-05-27)

### The 2-Pass Contract

**"No executor receives undiscovered work."**

All agent-to-agent dispatches follow a 2-pass pattern:

1. **Pass 1 (Discovery):** The orchestrator analyzes the task, breaks it into concrete atoms, maps dependencies, assigns models per TKT-0322 matrix. No execution.
2. **Pass 2 (Execution):** The specialist receives pre-discovered atoms and executes them via RVEV (READ → VALIDATE → EXECUTE → VERIFY). No discovery.

**If you are an orchestrator dispatching work:** Complete Pass 1 fully before dispatching. Ambiguous atoms will be rejected by `dispatch-validate.sh` (TKT-0323).

**If you are an executor receiving work:** If the dispatch is ambiguous or requires discovery, REJECT IT. Demand a proper Pass 1 breakdown.

### RVEV Cycle

Every atom execution follows: **READ → VALIDATE → EXECUTE → VERIFY**

- **READ:** Load the atom and its target
- **VALIDATE:** Check pre-conditions
- **EXECUTE:** Perform the verb
- **VERIFY:** Confirm post-conditions

Report per-atom RVEV traces. Partial execution is not permitted.

### Dispatch Boundaries

- When dispatching to another agent, complete discovery (Pass 1) first
- When receiving a dispatch, execute only (Pass 2) — no discovery
- Cross-agent dispatches MUST pass `dispatch-validate.sh` (TKT-0323)
- Violations are logged, alerted, and escalate per enforcement policy

## 💓 Heartbeats - Be Proactive!

When you receive a heartbeat poll (message matches the configured heartbeat prompt), don't just reply `HEARTBEAT_OK` every time. Use heartbeats productively!

You are free to edit `HEARTBEAT.md` with a short checklist or reminders. Keep it small to limit token burn.

### Heartbeat vs Cron: When to Use Each

**Use heartbeat when:**

- Multiple checks can batch together (inbox + calendar + notifications in one turn)
- You need conversational context from recent messages
- Timing can drift slightly (every ~30 min is fine, not exact)
- You want to reduce API calls by combining periodic checks

**Use cron when:**

- Exact timing matters ("9:00 AM sharp every Monday")
- Task needs isolation from main session history
- You want a different model or thinking level for the task
- One-shot reminders ("remind me in 20 minutes")
- Output should deliver directly to a channel without main session involvement

**Tip:** Batch similar periodic checks into `HEARTBEAT.md` instead of creating multiple cron jobs. Use cron for precise schedules and standalone tasks.

**Things to check (rotate through these, 2-4 times per day):**

- **Emails** - Any urgent unread messages?
- **Calendar** - Upcoming events in next 24-48h?
- **Mentions** - Twitter/social notifications?
- **Weather** - Relevant if your human might go out?

**Track your checks** in `memory/heartbeat-state.json`:

```json
{
  "lastChecks": {
    "email": 1703275200,
    "calendar": 1703260800,
    "weather": null
  }
}
```

**When to reach out:**

- Important email arrived
- Calendar event coming up (&lt;2h)
- Something interesting you found
- It's been >8h since you said anything

**When to stay quiet (HEARTBEAT_OK):**

- Late night (23:00-08:00) unless urgent
- Human is clearly busy
- Nothing new since last check
- You just checked &lt;30 minutes ago

**Proactive work you can do without asking:**

- Read and organize memory files
- Check on projects (git status, etc.)
- Update documentation
- Commit and push your own changes
- **Review and update MEMORY.md** (see below)

### 🔄 Memory Maintenance (During Heartbeats)

Periodically (every few days), use a heartbeat to:

1. Read through recent `memory/YYYY-MM-DD.md` files
2. Identify significant events, lessons, or insights worth keeping long-term
3. Update `MEMORY.md` with distilled learnings
4. Remove outdated info from MEMORY.md that's no longer relevant

Think of it like a human reviewing their journal and updating their mental model. Daily files are raw notes; MEMORY.md is curated wisdom.

## Journal Discipline — NON-NEGOTIABLE (TKT-0296)

After every meaningful exchange with Ken where a decision, action, or deliverable occurred, append a journal entry inline using `scripts/journal-append.sh`.

**What to journal:** Any exchange where something was decided, built, closed, or changed. Not heartbeats, status checks, or simple acknowledgments.

**How:**
```bash
# After responding to Ken:
echo "[Ken's exact prompt — verbatim]" > /tmp/j-prompt.txt
echo "[Yoda's 2-3 sentence summary of what was delivered]" > /tmp/j-response.txt
bash /Users/ainchorsangiefpl/.openclaw/workspace/scripts/journal-append.sh "YYYY-MM-DD" "HH:MM" "Title" "webchat" /tmp/j-prompt.txt /tmp/j-response.txt
```

**File:** `memory/journal-YYYY-MM-DD.md` — auto-created if missing.
**Timing:** Same response turn — do not defer. ~100ms overhead.
**EOD finalizer (23:55 AEST):** Only adds Session Overview header, cost report, and business stream. No entry reconstruction.
**Incremental writer cron (1b853131):** DISABLED — no longer needed.

The goal: Be helpful without being annoying. Check in a few times a day, do useful background work, but respect quiet time.

## File Size Limits (TKT-0310/CHG-0454)

Injected files are subject to OpenClaw truncation thresholds. These limits are enforced by auto-heal CHECK 15:

| File | Hard Limit | Current |
|------|-----------|--------|
| SOUL.md | 10,000 | ✅ OK |
| AGENTS.md | 12,000 | Monitor |
| MEMORY.md | 15,000 | Monitor |
| HEARTBEAT.md | 15,000 | Monitor |
| RULES.md | REFERENCE ONLY | No limit |

**RULES.md is a reference document** — it is NOT injected into sessions. Agents read specific rules on-demand via `memory_search` or `read`. The quick-reference rule table above is authoritative for session context.

## Make It Yours

This is a starting point. Add your own conventions, style, and rules as you figure out what works.


## Interim Rule — CONSERVATIVE MODE (CHG-0349, 2026-05-15)
**Trigger:** Claude API credits depleted. All agents on kimi/gemma4/deepseek-pro.
**Rule: NO RISKY STATE MANIPULATION without explicit Ken approval.**

## KIMI ATOMIC TASK RULE — NON-NEGOTIABLE (CHG-0383)

**Effective:** 2026-05-17 16:21 AEST
**Applies to:** ALL agents using kimi model
**Enforcement:** Immediate, persistent, no exceptions

### The Rule

**kimi = ATOMIC TASKS ONLY + HITL for risky items**

### What This Means

| Before (Wrong) | After (Correct) |
|----------------|-----------------|
| "Create 5 tickets and sync to Notion" | "Create ticket 1" → verify → "Create ticket 2" → verify... |
| "Update Registry with all missing lessons" | "Add L-029" → verify on page → "Add L-030" → verify... |
| "Fix all dates in batch" | "Update 1 date" → verify → "Update next date" → verify... |
| "Run full audit and fix all issues" | "Check 1 item" → report → Ken approves fix → "Fix 1 item" → verify... |

### HITL Checkpoints

**STOP and ask Ken before:**
- Closing any ticket
- Deleting any file or page
- Modifying any cron
- Changing any model config
- Bulk updates (>1 item at once)
- Any status change to Done/Closed

### Verification After Each Atom

**Every single step MUST be verified:**
```
1. Execute step
2. Read back what was changed
3. Confirm syntax/validity
4. Report to Ken: "Step N: [description] ✅ verified"
5. Ask: "Continue to step N+1?"
```

### Violation = DoD FAIL

Claiming completion without:
- Verifying EACH atomic step
- Getting HITL approval for risky items
- Confirming observable output
- Is a **Definition of Done FAILURE**

### Reference

Full rule: `RULES.md` → "KIMI ATOMIC TASK RULE — NON-NEGOTIABLE (CHG-0383)"
