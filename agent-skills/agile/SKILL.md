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

### Sprint Review (automated report)

Run the canonical review report before the Friday standup or on-demand:

```bash
bash agent-skills/agile/scripts/sprint-review.sh
# or for a specific sprint:
bash agent-skills/agile/scripts/sprint-review.sh --sprint "Sprint 8"
```

This produces a Markdown report at `.openclaw/tmp/sprint-review-report-<Sprint-N>.md` covering:

- Sprint identity and committed scope
- Delivery status and velocity snapshot
- Platform health, budget, and cron health
- Open decisions and draft docs
- Next-sprint signals

See the checklist: `agent-skills/agile/references/sprint-review-checklist.md`.

### Ad-hoc Sprint Status Query (any time)

Ken or Yoda may request: **"What is the current sprint status?"**

1. Run `bash scripts/db-sprint.sh current` to fetch the active sprint.
2. **Cross-check:** Verify the returned sprint has `status: in_progress` and dates include today. If stale, run `bash scripts/db-sprint.sh plan --sprint "Sprint N"` and report the discrepancy.
3. Run `bash scripts/db-ticket.sh list --sprint-current`.
4. Summarise: sprint name + dates, velocity snapshot, critical blockers, items needing Ken input, next 24h focus.
5. Do not wait for a ceremony. This is ad-hoc status-on-demand.

### Sprint Planning Carry-Forward Rule

When planning the next sprint:
1. Run `bash scripts/db-ticket.sh list --sprint-current --status open,in_progress,blocked`.
2. Propose carry-forward to Ken. Default: carry all open/in-progress/blocked unless explicitly dropped.
3. On confirmation, create the new sprint, move items, mark new sprint active, close old sprint.

For full groom/planning guidance and type-specific DoD checklists, see `agent-skills/agile/references/agile-framework-v1.md`.

---

## Key Rules (DO / DON'T)

### DO

- ✅ **Raise a TKT before any ad-hoc work.**
- ✅ **Link every PBI to an OKR ID** (or "—" for auto-heal items).
- ✅ **Gate every epic** with Ken approval after Atlas/Thrawn review.
- ✅ **Enforce the 6-item sprint ceiling**.
- ✅ **Track velocity over rolling 4 sprints**.
- ✅ **Run daily standup auto-delivered** at 8:00 AM AEST.
- ✅ **Capture every significant decision** in Notion Decisions DB.
- ✅ **Apply the universal DoD gates** before marking any item Done.

### DON'T

- ❌ **Skip the Plan / Plan phase.**
- ❌ **Start an epic without an OKR ID.**
- ❌ **Run an epic > 6 sprints** without splitting.
- ❌ **Close a ticket via self-report.** DoD gates 1–3 must pass.
- ❌ **Fill a sprint with > 2 non-OKR items** (P3+P4+P5 combined).
- ❌ **Trust specialist self-report for Done.** Verify independently (L-054).
- ❌ **Let "DRAFT FOR REVIEW" pass as Done.** Ken explicit confirmation required.

---

## Definition of Done — Universal Gates (locked 2026-05-08)

Before ANY ticket, US, epic, or architecture task can be marked Done, **ALL three gates must pass**:

### Gate 1 — Open Decisions Closed
Tracked in `state/open-decisions.json`. A ticket with open decisions is **BLOCKED — not Done**.

### Gate 2 — No Draft Outputs
Any deliverable must be **explicitly endorsed/accepted/confirmed by Ken** before close. "DRAFT FOR REVIEW" = not Done.

### Gate 3 — Gates 1 and/or 2 fully cleared
Only when all open decisions are closed AND all drafts are accepted is the item Done.

For type-specific DoD checklists (TKT / US / Epic / INC), see `agent-skills/agile/references/agile-framework-v1.md`.

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
