---
name: agile
description: AInchors Agile delivery framework — sprint cadence, ceremonies, work-item rules, priority, and Definition of Done.
---

# Agile skill — When to Load

Load this skill whenever you are:

- **Planning, executing, or closing a sprint** (sprint planning, daily standup prep, sprint review, sprint close).
- **Working any TKT, US, INC, CHG, or epic** and need to check the rules for that work-item type (ticket-first, OKR-link, DoD gates).
- **Triaging the backlog** (grooming PBIs, refining acceptance criteria, capacity check).
- **Deciding priority** between competing items (P1–P5 framework, OKR-capacity rule).
- **Capturing a significant decision** (Decision Capture Rule).
- **Reviewing framework maturity** (L2 → L3 → L4 progression).
- **Answering questions about** ceremonies, capacity, velocity, or DoD for any work item.

If you're about to invoke `scripts/ticket.sh`, `scripts/db-ticket.sh`, `scripts/db-sprint.sh`, or any sprint/ticket workflow script — load this skill first.

---

## Old-Code Audit Rule (TKT-0529, LOCKED 2026-06-18)

When a sprint contains a **P0 old-code audit TKT**:
1. **Plan phase must produce a verifier corpus** in `tests/regression/<ticket>/verifier-corpus.md` before any static analysis.
2. **Static analysis atoms are read-only** and dispatched through the `subagent-dispatch` skill with explicit tool budgets and timeouts.
3. **Deep-groom phase** follows subagent reports: Yoda re-reads the scripts, verifies line numbers, and produces a consolidated `audit-report-deep.md` with options and policy questions.
4. **Execution options** must be presented with trade-offs; no A7 work starts until Ken approves an option and answers policy questions.
5. **Remediation policy defaults** (Ken 2026-06-18):
   - Auto-destructive hygiene/health housekeeping in `auto-heal.sh` retained.
   - Context-file rewrites (SOUL.md, AGENTS.md, MEMORY.md, HEARTBEAT.md) gated to `NEEDS_KEN`.
   - Atomic state writes use shared lib `scripts/lib/atomic-write.sh`.

## Quick Reference

### Framework Maturity (where we are)

| Stage | Level | Label | Status |
|-------|-------|-------|--------|
| **Now (this framework)** | **L3** | **Defined** | ← Active. Fixed 1-week cadence, velocity tracking, DoD enforcement, OKR-linked epics, formal ceremonies. |
| P2 target (end Aug 2026) | L3 sustained | Consistent velocity + retrospectives actioned | Target |
| P3 target | L4 | Optimising — data-driven, predictable delivery | Future |

### Delivery Tiers (nesting order)

```
QBR (Quarterly)
  └── Epic (multi-sprint capability, 2–6 sprints)
        └── Sprint (1 week, Mon–Sun AEST)
              └── Story / TKT (atomic unit, ≤1 sprint)
```

### Ceremonies (lean — no ceremony for ceremony's sake)

| Ceremony | Frequency | Duration | Who | Delivery | Purpose |
|----------|-----------|----------|-----|----------|---------|
| **Morning standup** | Daily 8:00 AM AEST | Auto | Yoda → Ken | Telegram | RTB status + agent health + priorities |
| **Sprint planning** | Weekly Sun evening | 30 min | Ken + Yoda | Webchat/Telegram | Approve next sprint items |
| **Sprint review** | Weekly Friday standup | 20 min | Ken + Yoda | Webchat | What shipped, what didn't, velocity update |
| **Epic review** | Per epic (before start) | 30 min | Ken + Atlas + Yoda | Webchat | Gate epic before any work starts |
| **QBR** | Quarterly (Jan/Apr/Jul/Oct) | 1 day | Ken + all streams | Async + Telegram | OKR review + next quarter approval |

**Ceremony rules:** Standup auto-delivered regardless (Ken acknowledges when ready). Sprint planning: Yoda proposes by Sunday 20:00 AEST; Ken approves before midnight or first thing Monday. Epic review: Yoda briefs Atlas for pre-review; Atlas output included in brief to Ken. **No epic starts without epic review.**

### Sprint Capacity & Velocity

- **Capacity ceiling:** Max **6 items/sprint** (realistic ceiling for 2-person + AI team).
- **P2 velocity baseline:** **5 items/sprint** (30% headroom factored in).
- **Velocity target:** ≥ **80% sprint completion rate** (rolling 4-sprint window, steady state from Sprint 5 onwards).
- **Early-warning rule:** Any sprint delivers < 4 planned items → flag P2 slip risk immediately.
- **Sprint health gate:** Velocity drops < 60% for 2 consecutive sprints → mandatory retrospective before next sprint starts.

### Sprint 2–9 velocity (pre-OC2, 12 May–6 Jul): 5 items/sprint.
### Sprint 10–12 (OC2 setup, 7–27 Jul): 2–3 items/sprint.
### Sprint 13–17 (post-OC2, 28 Jul–31 Aug): 5 items/sprint (full capacity resumes).
### P2 deadline: end August 2026 (zero slack). Contingency: mid-September.

### Work Item Types

| Type | When to use | OKR link? | Ken gate? |
|------|-------------|-----------|-----------|
| **Epic** | Multi-sprint capability, outcome-level | Yes (mandatory) | Yes (before start) |
| **US** (User Story) | Specific piece of user value within an epic | Yes (inherits from epic) | No (Yoda manages) |
| **TKT** | Ad-hoc task, investigation, fix, config change | If sprint-planned: yes | Sprint approval |
| **INC** | Incident — unplanned, reactive, platform/ops | No (reactive) | Escalate if P1/P2 |
| **CHG** | Configuration or infrastructure change | No (operational) | Required for risky ops |

### Ticket-First Rule (non-negotiable)

> **Any ad-hoc task or request without an existing INC/US/CHG reference → raise TKT-NNNN via `scripts/ticket.sh` BEFORE starting work.**

No exceptions. This is audit + sanity check. If work is worth doing, it's worth tracking.

**Valid narrow exceptions:**
- Immediate P1 incident response — raise INC first, then TKT within 30 minutes
- Auto-heal items triggered by health checks — auto-raised by health check system
- Sub-5-minute inline fixes fully contained within an already-tracked TKT

### Decision Capture Rule

> **Every significant decision must be captured** in Notion (Decisions DB) with: decision text, rationale, alternatives considered, date, Ken approval if required.

Significant = architecture decisions, vendor/tool selections, scope changes to active epic or sprint, anything that would be confusing if Ken saw it for the first time in 3 months.

### Priority Framework (within any sprint)

| Priority | Category | Rule |
|----------|----------|------|
| **P1** | Critical path blocker | P2-blocking or Aevlith incorporation gate dependencies. Must be in sprint if not done. |
| **P2** | OKR-linked, this quarter | Committed OKR KR delivery items for current quarter. |
| **P3** | Platform health / security | S1–S7 posture, model drift corrections, health check failures, backup validation. |
| **P4** | Governance / compliance | ITIL enforcement, governance gate coverage, policy updates. |
| **P5** | Innovation / improvement | Automation, tooling, research. |

**Capacity rule:** Never fill a sprint with more than **2 non-OKR-linked items** (P3 + P4 + P5 combined).
**Tiebreaker:** Pick the item that unblocks more downstream work.

### Ad-hoc Sprint Status Query (any time)

Ken or Yoda may request: **"What is the current sprint status?"**

On that request:
1. Run `bash scripts/db-sprint.sh current` to fetch the active sprint.
2. **Cross-check:** Verify the returned sprint has `status: in_progress` (or `active`) and that its dates include today. If the command returns a `completed` sprint or a stale sprint, immediately run `bash scripts/db-sprint.sh plan --sprint "Sprint N"` (with the sprint you believe is active) and report the discrepancy to Ken.
3. Run `bash scripts/db-ticket.sh list --sprint-current` to list all items in the sprint with statuses.
4. Summarise in a concise Telegram/webchat message:
   - **Sprint name + dates**
   - **Velocity snapshot:** planned / completed / in-progress / blocked / not-started
   - **Critical blockers** (P1/P2, health, security)
   - **Items needing Ken input** (open decisions, draft reviews, approval gates)
   - **Next 24h focus** (top 3 priorities by order of execution)
5. Do not wait for a ceremony. This is ad-hoc status-on-demand.

### Sprint Planning Carry-Forward Rule

When planning the next sprint (Sunday evening or any ad-hoc planning request):
1. Run `bash scripts/db-ticket.sh list --sprint-current --status open,in_progress,blocked` to find all unclosed items in the current sprint.
2. Propose to Ken: **"Carry forward N items to Sprint [N+1]?"** with the list and recommended slotting.
   - Default assumption: carry all open/in-progress/blocked items unless Ken explicitly drops one.
   - Exceptions: items marked `wontfix`, `duplicate`, or `parking_lot` are not carried.
3. On Ken's confirmation:
   - Run `bash scripts/db-sprint.sh create --week-start <date>` to create the next sprint.
   - Run `bash scripts/db-ticket.sh bulk-update --sprint-new <sprint-id> --ids <id1,id2,...>` to move carried items.
   - Run `bash scripts/db-sprint.sh update <new-sprint-id> --status in_progress` to mark the new sprint as active (canonical state).
   - Run `bash scripts/db-sprint.sh update <old-sprint-id> --status closed` to close the old sprint.
4. **Auto-mark next sprint in-progress** only after Ken confirms carry-forward. Never pre-create a sprint without approval.

### Ken Says "Groom TKT-XXXX" — Groom Format

When Ken says "groom TKT-XXXX", produce a concise groom summary in this order. This is **pre-execution shaping**, not the mechanical `db-ticket.sh groom` helper.

1. **What it is** — one-sentence identity of the ticket.
2. **Problem statement** — why it matters; the pain or risk being addressed.
3. **Context** — relevant history, dependencies, related tickets/CHG/lessons, current state.
4. **What we should do** — the possible approaches or options (labelled A, B, C…).
5. **Considerations** — constraints, assumptions, trade-offs, known unknowns.
6. **Risks** — what could go wrong with each option.
7. **Recommendation** — which option you favour and why.
8. **Ask for decision** — stop here. Do not begin execution, CREST planning, or tool work until Ken confirms the approach.

Use evidence from PG, CHANGELOG, LESSONS, and memory. If data is missing, say so. Do not fabricate options or context. After Ken confirms the approach, then proceed to CREST Plan phase (load `crest` skill) and execution.

### Backlog Grooming Requirements (every PBI needs all of these before Sprint start)

- Acceptance Criteria (AC) — clear and testable
- Owner / Assignee — named human or agent
- Timeline / Estimate — sized
- Risk Assessment — flagged
- Blockers / Dependencies — declared
- DoD Criteria — type-specific checklist applied

---

## Key Rules (DO / DON'T)

### DO

- ✅ **Raise a TKT before any ad-hoc work.** Ticket-first is audit + sanity.
- ✅ **Link every PBI to an OKR ID** (or explicitly "—" for auto-heal items).
- ✅ **Gate every epic** with Ken approval after Atlas/Thrawn review before any work starts.
- ✅ **Enforce the 6-item sprint ceiling** (realistic for the team size).
- ✅ **Track velocity over rolling 4 sprints** — review at every sprint close + QBR.
- ✅ **Run daily standup auto-delivered** at 8:00 AM AEST — every day, no exceptions.
- ✅ **Capture every significant decision** in Notion Decisions DB.
- ✅ **Apply the universal DoD gates** before marking any item Done (Gates 1, 2, 3 below).

### DON'T

- ❌ **Skip the Plan / Plan phase.** No silent execution, even for one-atom tasks.
- ❌ **Start an epic without an OKR ID.** Without OKR ID it's a parking-lot item, not an epic.
- ❌ **Run an epic > 6 sprints** without splitting or re-scoping.
- ❌ **Close a ticket via self-report.** DoD gates 1–3 must pass — open decisions closed, drafts accepted.
- ❌ **Fill a sprint with > 2 non-OKR items** (P3+P4+P5 combined).
- ❌ **Trust specialist self-report for Done.** Verify independently (L-054).
- ❌ **Let "DRAFT FOR REVIEW" status pass as Done.** Ken explicit confirmation required.

---

## Definition of Done — Universal Gates (locked 2026-05-08)

Before ANY ticket, US, epic, or architecture task can be marked Done, **ALL three gates must pass**:

### Gate 1 — Open Decisions Closed
All decisions raised during the work (unanswered, blocked, dependent, or triggered) must be resolved and confirmed by Ken. Tracked in `state/open-decisions.json`. **A ticket with open decisions is BLOCKED — not Done.**

### Gate 2 — No Draft Outputs
Any document, framework, policy, or architecture artefact produced as a deliverable must be **explicitly endorsed/accepted/confirmed by Ken** before the item closes. "DRAFT FOR REVIEW" status = not Done. Ken's explicit confirmation (webchat or Telegram) = accepted. Yoda updates doc status and logs CHG.

### Gate 3 — Gates 1 and/or 2 fully cleared
Only when all open decisions are closed AND all drafts are accepted is the item considered Done. **Partial closure is not Done.**

**Tracking:** Yoda maintains `state/open-decisions.json` (Gate 1) and `state/draft-docs.json` (Gate 2). Both checked at sprint planning (Sunday) and sprint review (Friday standup). Any item with open gates cannot be carried forward as "Done" — it is "Blocked" or "In Review".

### TKT (Task / Ticket) — additional checklist

- [ ] Deliverable exists and works as specified in the acceptance criteria
- [ ] If config change → CHG logged in `memory/CHANGELOG.md` and Notion Change Log DB
- [ ] Notion status updated to `Closed`
- [ ] Any testing required → test outcome documented (pass/fail, method)
- [ ] No open issues flagged in PVT (if applicable — `bash scripts/pvt.sh`)

### US (User Story) — additional checklist

- [ ] All acceptance criteria met (each AC has pass/fail result documented)
- [ ] End-to-end test run (not just unit-level)
- [ ] Ken review completed (mandatory for any client-facing or external output)
- [ ] Notion status updated to `Done`
- [ ] Any dependencies on other items updated (downstream items unblocked)

### Epic — additional checklist

- [ ] All child User Stories are closed (DoD met for each US)
- [ ] Operational playbook written and published to Holocron (every shipped capability must have a playbook)
- [ ] Ken sign-off given
- [ ] Epic entry in Notion updated to `Complete` with actual completion date
- [ ] OKR delta noted: did this epic move its KR? Record the delta.

### INC (Incident) — additional checklist

- [ ] Service restored to normal
- [ ] Root cause identified (or "unknown — under investigation" if not yet resolved)
- [ ] `scripts/incident-log.sh` updated
- [ ] Notion Incident DB updated
- [ ] P1/P2 incidents: PIR scheduled within 48 hours, PIR report completed within 5 days
- [ ] Preventive action raised as TKT if recurrence is possible

---

## Related Skills & Scripts

- **Sprint/Ticket DB ops:** `agent-skills/pg-sprint-backlog/SKILL.md`
- **CREST execution:** `agent-skills/crest/SKILL.md` (DoD close gate enforces universal gates above)
- **CHG records:** `agent-skills/changelog/SKILL.md`
- **Scripts:** `scripts/ticket.sh`, `scripts/db-ticket.sh`, `scripts/db-sprint.sh`, `scripts/incident-log.sh`, `scripts/pvt.sh`, `scripts/changelog-append.sh`

---

## Reference

Full canonical framework (Sections 1–8: tiers, ceremonies, work-item rules, priority, DoD, maturity, Sprint 1 worked example):

→ `references/agile-framework-v1.md`

Authority: **AInchors Agile Delivery Framework v1.0** — APPROVED Ken Mun, CTO, 2026-05-07. Author: Yoda 🟢. TKT-0090.
