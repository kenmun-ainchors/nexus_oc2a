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

## Platform Rules — Summary (full text in RULES.md)

All platform rules: see `RULES.md` for full text + CHG references + rollback procedures. Quick-reference: rules belong in RULES.md; this file is summary + conventions + workspace structure. CHANGELOG.md is the authoritative source of record for what rules have changed.

## 3 Strikes Principle — Summary (TKT-0401, CHG-0503; full text in RULES.md)

**Strike-1** plan before execute (load `crest` skill: `bash scripts/skill-load.sh crest`). **Strike-2** flash by default, pro only when flagged (model routing: `bash scripts/skill-load.sh model-routing`). **Strike-3** check LESSONS.md before acting (`scripts/lessons-staleness-check.sh`).

## Dispatch Rules — Summary (TKT-0321; full text in RULES.md §Dispatch)

**2-Pass Contract:** orchestrator plans (Pass 1), executor executes (Pass 2). `dispatch-validate.sh` (TKT-0323) rejects ambiguous dispatches. **RVEV:** READ → VALIDATE → EXECUTE → VERIFY per atom. **Skill-Gate (TKT-0396):** load skill via `bash scripts/skill-load.sh <name>` before domain scripts. **Review (TKT-0403):** NO `cp -r` of working copy; fresh `git fetch/clone` at exact SHA.

### Anti-Subagent-Trap (L-139, Ken directive 2026-06-15)
**verifier_corpus is MANDATORY for any dispatch with `execute` or `verify` atom.** Yoda authors the test corpus BEFORE dispatch (passed in dispatch JSON as string or array of file paths). Subagent runs the verifier and reports raw totals; subagent MUST NOT modify the verifier, the corpus, or the system under test. Subagent-written tests always pass — they validate the subagent's own (potentially broken) implementation. The Yoda-side corpus + L-113 evidence-only verify is the catch-all. Doc: `docs/SUBAGENT-DISPATCH-PATTERN.md`.

## 💓 Heartbeats

Use heartbeats productively — don't just reply HEARTBEAT_OK. Batch checks (email/calendar/mentions/weather), use cron for precise schedules. Full heartbeat protocol in `HEARTBEAT.md`. Track state in `memory/heartbeat-state.json`. Stay quiet 23:00-08:00 unless urgent. Periodically maintain MEMORY.md during slow heartbeats.

## Journal Discipline — NON-NEGOTIABLE (TKT-0296)

After every meaningful exchange with Ken (decisions, actions, deliverables): append via `bash scripts/journal-append.sh "<title>" "<multiline-summary>"`. Same turn, ~30ms. File: `memory/journal-YYYY-MM-DD.md`. Simple 2-arg model — no temp files. EOD finalizer (23:55 AEST) adds header+cost+business stream only. NON-NEGOTIABLE — if you made a decision or delivered something, write it to journal NOW.

## File Size Limits (TKT-0310)

Injected files are subject to OpenClaw truncation thresholds. These limits are enforced by auto-heal CHECK 15:

| File | Hard Limit | Current |
|------|-----------|--------|
| SOUL.md | 10,000 | ✅ OK |
| AGENTS.md | 12,000 | Monitor |
| MEMORY.md | 15,000 | Monitor |
| HEARTBEAT.md | 15,000 | Monitor |
| RULES.md | REFERENCE ONLY | No limit |

**RULES.md is a reference document** — it is NOT injected into sessions. Agents read specific rules on-demand via `memory_search` or `read`. The quick-reference rule table above is authoritative for session context.

## Workspace File Contracts — NON-NEGOTIABLE (TKT-0341, 2026-06-09)

Every .md file in workspace root has a registered purpose contract at `state/file-contracts.json`. No new .md file may be created in root without: (1) a contract registered, (2) Ken approval, (3) file-size-guard updated.

**Subdirectory rules:** Reference docs → `docs/`, Agent-specific → `agents/<id>/`, Completed/stale → `archive/`, State → `state/`, Scripts → `scripts/`. Files outside root are NOT auto-injected.

**Audit:** CHECK 21 (auto-heal, daily) verifies: no untracked root .md files, all files within declared limits, no cross-contamination (procedures living in checklists, config in soul files). Run `file-size-guard.sh --root` for manual audit.

**Root files allowed (8):** SOUL.md, AGENTS.md, MEMORY.md, HEARTBEAT.md, USER.md, IDENTITY.md, TOOLS.md, RULES.md (reference only, not injected).

## KIMI Atomic Task Rule — Summary (full text in RULES.md §KIMI)

kimi = ONE ATOM PER TURN + VERIFY EACH STEP + HITL for risky ops (close/delete/cron/model/bulk/Done). Conservative Mode decommissioned 2026-06-12 08:02 AEST by CHG-0500 (CREST v1.3 + TKT-0368 risk framework).
