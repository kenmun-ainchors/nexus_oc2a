# AInchors Agile Delivery Framework v1.0

**Status:** APPROVED — Ken Mun, CTO, 2026-05-07 16:39 AEST
**Author:** Yoda 🟢
**Produced:** 2026-05-07
**Inputs:** TKT-0089 backlog replan, TKT-0086 Atlas EA roadmap, AInchors OKR 2026-05, frameworks-maturity.json
**TKT:** TKT-0090

---

## 1. Framework Overview

### Purpose

AInchors is now 13 days into P1. We have a locked OKR, a groomed backlog, confirmed sprint sequences, and a P2 target of end August 2026. What we lack is a single governing document that defines exactly how we deliver — the cadences, the work item rules, the ceremonies, and the definition of done.

Without this, every session recreates the rules. With it, Ken and Yoda operate from a shared contract that doesn't need re-negotiation each sprint.

This framework is the answer.

### Scope

Applies to all AInchors delivery streams:

| Stream                  | Lead Agent                     | Accountable Human |
| ----------------------- | ------------------------------ | ----------------- |
| **Technology (Tech)**   | Yoda 🟢                        | Ken Mun           |
| **Business**            | Aria 🟣                        | Angie             |
| **Consulting (Ahsoka)** | Yoda 🟢 (until Aria activated) | Ken Mun           |

Every sprint item, user story, epic, ticket, incident, and change — regardless of stream — operates under this framework.

### Owner

- **Framework Owner:** Ken Mun (sole approver of framework changes)
- **Technology Stream Operator:** Yoda 🟢
- **Business Stream Operator:** Aria 🟣 (when fully activated)

### Maturity Target

| Stage                        | Level        | Label                                          | Status            |
| ---------------------------- | ------------ | ---------------------------------------------- | ----------------- |
| Before this framework        | L2           | Developing                                     | Was current state |
| **This framework activates** | **L3**       | **Defined**                                    | ← We are here     |
| P2 target (end Aug 2026)     | L3 sustained | Consistent velocity + retrospectives actioned  | Target            |
| P3 target                    | L4           | Optimising — data-driven, predictable delivery | Future            |

**What moves us from L2 → L3 with this document:**
- Fixed 1-week sprint cadence (was: ad hoc)
- Formal velocity tracking over rolling 4 sprints (was: none)
- Definition of Done enforced per item type (was: relies on Sage gate only)
- Epic structure with OKR linkage and Ken gate before work starts (was: implicit)
- Formal ceremonies with defined duration and participants (was: informal)

---

## 2. Delivery Tiers

Four tiers structure all AInchors delivery. Each tier nests inside the one above it.

```
QBR (Quarterly)
  └── Epic (multi-sprint capability)
        └── Sprint (1 week)
              └── Story / TKT (atomic unit)
```

---

### Tier 1: QBR — Quarterly Business Review

**Cadence:** 1st week of each quarter (Jan / Apr / Jul / Oct)

**Purpose:** Review OKR progress, approve next quarter's epics, and adjust strategy if needed. This is the strategy layer — not an ops review.

**Participants:**

| Role    | Attendance                | Stream   |
| ------- | ------------------------- | -------- |
| Ken Mun | Mandatory                 | All      |
| Yoda 🟢 | Mandatory                 | Tech     |
| Angie   | Required                  | Business |
| Aria 🟣 | Required (when activated) | Business |

**Inputs required:**
- OKR delta report (actual vs target for each KR)
- Velocity summary: actual sprint completion over the quarter
- Epic completion status: how many epics shipped vs planned
- Proposed epic list for next quarter

**Outputs:**
- Approved epic list for the quarter (Ken sign-off required)
- OKR delta report published to Holocron
- Any strategy amendments (triggers new OKR version if scope changes)
- Framework health review (maturity check against this document)

**Duration:** 1 day (async-first — Yoda prepares pre-read, Ken reviews, decisions captured in Notion)

**Rule:** No epic enters the next quarter without QBR approval. No exceptions.

---

### Tier 2: Epic

**Definition:** A significant capability or outcome that takes 2–6 sprints to deliver. Epics are not tasks — they are outcomes.

**Required fields (every epic must have all of these):**

| Field            | Description                           |
| ---------------- | ------------------------------------- |
| Epic title       | Clear outcome name                    |
| Pillar           | Tech / Business / Consulting          |
| OKR ID           | e.g. X1-KR3 (must link to a live OKR) |
| Owner            | Yoda or Aria                          |
| Target quarter   | e.g. Q2 2026                          |
| Success criteria | Measurable. How do we know it's done? |

**Epic gate:** Ken approves before any work starts. Atlas/Thrawn review required for all Tech epics before Ken gates them.

**Minimum viable format:**

```
EPIC-XXXX | [Title] | [Pillar] | [OKR ID] | Owner: [Yoda/Aria] | Target: [Q] | Success criteria: [measurable statement]
```

**Rules:**
- An epic without an OKR ID is not an epic — it is a parking lot item
- An epic that takes > 6 sprints must be split or re-scoped
- An epic that exceeds its target quarter requires Ken to re-approve continuation

---

### Tier 3: Sprint

**Cadence:** 1 week, Monday–Sunday AEST

**Capacity:** Max 6 items per sprint (realistic ceiling for a 2-person + AI team)

**Velocity targets (locked 2026-05-08, based on P2 deadline analysis):**
- **Sprints 2–9 (pre-OC2, 12 May–6 Jul):** 5 items/sprint — 30% headroom applied (3–4 planned + 1–2 ad-hoc/critical/debt)
- **Sprints 10–12 (OC2 setup, 7–27 Jul):** 2–3 items/sprint — reduced capacity, setup work runs in parallel
- **Sprints 13–17 (post-OC2, 28 Jul–31 Aug):** 5 items/sprint — full capacity resumes
- **P2 deadline:** End August 2026 (achievable, zero slack in likely scenario). Contingency: mid-September.
- **Early warning:** If any sprint delivers < 4 planned items, flag P2 slip risk immediately.
- **OC2 gate items (cannot start until TRIGGER-03 fired):** Gemma4 production validation, HA architecture, NAS encryption, client-facing data sovereignty workloads.

**Sprint planning:**
- **When:** Sunday evening, as part of the standup review
- **Who:** Yoda proposes sprint items; Ken approves before work starts
- **How:** Yoda presents proposed sprint with rationale per item; Ken confirms or adjusts
- **Rule:** No sprint starts without Ken approval. Not even one item.

**Sprint review:**
- **When:** Friday standup
- **What:** What shipped, what didn't, why — brief and honest
- **Output:** Sprint close summary added to Notion; velocity updated

**Velocity tracking:**
- Metric: % of committed sprint items completed
- Rolling window: 4 sprints
- Reviewed: Every sprint close + QBR
- Target: ≥ 80% sprint completion rate (steady state from Sprint 5 onwards)
- P2 velocity baseline: 5 items/sprint (30% headroom factored in)
- Baseline revision: reassess after Sprint 4 (first clean full sprint post-foundations)

**Sprint health rule:** If velocity drops below 60% for 2 consecutive sprints, mandatory retrospective before the next sprint starts.

---

### Tier 4: Story / Task (TKT)

**Definition:** The smallest unit of tracked delivery work. Atomic. Completable within one sprint.

**Required fields:**

| Field               | Required?                                                          |
| ------------------- | ------------------------------------------------------------------ |
| TKT ID              | Always (ticket-first rule — see Section 4)                         |
| Title               | Always                                                             |
| Parent epic         | If applicable                                                      |
| OKR ID              | Always (if work is sprint-planned; can be "—" for auto-heal items) |
| Stream              | Always (Tech / Business / Consulting)                              |
| Acceptance criteria | Required for any TKT that produces a deliverable                   |

**Done definition:** See Section 6.

---

## 3. Ceremonies

Lean ceremonies for a 2-person + AI team. Every ceremony has a purpose, a duration, and an owner. No ceremony exists just to have a ceremony.

| Ceremony            | Frequency                   | Duration       | Who                | Delivery         | Purpose                                    |
| ------------------- | --------------------------- | -------------- | ------------------ | ---------------- | ------------------------------------------ |
| **Morning standup** | Daily 8:00 AM AEST          | Auto-delivered | Yoda → Ken         | Telegram         | RTB status + agent health + priorities     |
| **Sprint planning** | Weekly Sunday evening       | 30 min         | Ken + Yoda         | Webchat/Telegram | Approve next sprint items                  |
| **Sprint review**   | Weekly Friday standup       | 20 min         | Ken + Yoda         | Webchat          | What shipped, what didn't, velocity update |
| **Epic review**     | Per epic (before start)     | 30 min         | Ken + Atlas + Yoda | Webchat          | Gate epic before any work starts           |
| **QBR**             | Quarterly (Jan/Apr/Jul/Oct) | 1 day          | Ken + all streams  | Async + Telegram | OKR review + next quarter approval         |

**Ceremony rules:**
- Morning standup: auto-delivered regardless. Ken acknowledges when ready.
- Sprint planning: Yoda proposes by Sunday 20:00 AEST; Ken approves before midnight or first thing Monday.
- Sprint review: Yoda generates the review summary; Ken adds any commentary; Notion updated same session.
- Epic review: Yoda briefs Atlas for pre-review; Atlas output included in brief to Ken. No epic starts without this.
- QBR: Yoda prepares the QBR pack (OKR delta, velocity summary, proposed epics) at least 2 days before the QBR session.

---

## 4. Work Item Types and Rules

### Work Item Definitions

| Type                | When to use                                        | OKR link required?       | Ken gate?              |
| ------------------- | -------------------------------------------------- | ------------------------ | ---------------------- |
| **Epic**            | Multi-sprint capability, outcome-level             | Yes (mandatory)          | Yes (before start)     |
| **US** (User Story) | A specific piece of user value within an epic      | Yes (inherits from epic) | No (Yoda manages)      |
| **TKT**             | Ad-hoc task, investigation, fix, config change     | If sprint-planned: yes   | Sprint approval        |
| **INC**             | Incident — unplanned, reactive, platform/ops issue | No (reactive)            | Escalate if P1/P2      |
| **CHG**             | Configuration or infrastructure change             | No (operational)         | Required for risky ops |

### Ticket-First Rule (non-negotiable)

> **Any ad-hoc task or request without an existing INC/US/CHG reference → raise TKT-NNNN via `scripts/ticket.sh` BEFORE starting work.**

No exceptions. This is both an audit requirement and a sanity check. If work is worth doing, it's worth tracking.

**Script:** `bash scripts/ticket.sh`

**Valid exceptions (narrow):**
- Immediate P1 incident response — raise INC first, then TKT within 30 minutes
- Auto-heal items triggered by health checks — auto-raised by the health check system
- Sub-5-minute inline fixes that are fully contained within an already-tracked TKT

### Decision Capture Rule

> **Every significant decision must be captured.** In Notion (Decisions DB), with: decision text, rationale, alternatives considered, date, and Ken approval if required.

What counts as "significant":
- Architecture decisions
- Vendor or tool selections
- Scope changes to any active epic or sprint
- Any decision that would be confusing if Ken saw it for the first time in 3 months

---

## 5. Priority Framework

Within any sprint, prioritise in this order:

| Priority | Category                       | Rule                                                                                          |
| -------- | ------------------------------ | --------------------------------------------------------------------------------------------- |
| P1       | **Critical path blocker**      | P2-blocking items or Auralith incorporation gate dependencies. Must be in sprint if not done. |
| P2       | **OKR-linked, this quarter**   | Committed OKR KR delivery items for current quarter.                                          |
| P3       | **Platform health / security** | S1-S7 security posture, model drift corrections, health check failures, backup validation.    |
| P4       | **Governance / compliance**    | ITIL enforcement, governance gate coverage, policy updates.                                   |
| P5       | **Innovation / improvement**   | Automation, tooling improvements, research items.                                             |

**Capacity rule:** Never fill a sprint with more than 2 non-OKR-linked items (P3 + P4 + P5 combined).

**Tiebreaker:** When two items have the same priority, pick the one that unblocks more downstream work.

**Current critical path items (as at Sprint 1):**
- Auralith incorporation gate: TKT-0060/0061/0062/0063 (hard gate: end May 2026)
- P2 go-live: OC2 deployment, Beacon v2 (TKT-0075), FinOps caps (TKT-0092), Docker isolation
- Atlas Q1 must-do: Doc gen pipeline (TKT-0095), NAS+backup (TKT-0093)

---

## 6. Definition of Done (non-negotiable)

"Done" means the work is complete, verified, and recorded. Not "mostly done." Not "working on my machine." Done.

### Universal DoD Gates (apply to ALL item types — locked 2026-05-08)

Before ANY ticket, US, epic, or architecture task can be marked Done, ALL three gates must pass:

**Gate 1 — Open Decisions Closed**
All decisions raised during the work (unanswered, blocked, dependent, or triggered) must be resolved and confirmed by Ken. Tracked in `state/open-decisions.json`. A ticket with open decisions is BLOCKED — not Done.

**Gate 2 — No Draft Outputs**
Any document, framework, policy, or architecture artefact produced as a deliverable must be explicitly endorsed/accepted/confirmed by Ken before the item closes. "DRAFT FOR REVIEW" status = not Done. Ken's explicit confirmation (in webchat or Telegram) = accepted. Yoda updates doc status and logs CHG.

**Gate 3 — Gates 1 and/or 2 fully cleared**
Only when all open decisions are closed AND all drafts are accepted is the item considered Done. Partial closure is not Done.

**Tracking:** Yoda maintains `state/open-decisions.json` for Gate 1 and `state/draft-docs.json` for Gate 2. Both are checked at sprint planning (Sunday) and sprint review (Friday standup). Any item with open gates cannot be carried forward as "Done" — it is "Blocked" or "In Review".


### TKT (Task / Ticket)

A TKT is done when ALL of the following are true:

- [ ] Deliverable exists and works as specified in the acceptance criteria
- [ ] If it's a config change → CHG logged in CHANGELOG.md and Notion Change Log DB
- [ ] Notion status updated to `Closed`
- [ ] If any testing was required → test outcome documented (pass/fail, method)
- [ ] No open issues flagged in PVT (if applicable — `bash scripts/pvt.sh`)

### US (User Story)

A US is done when ALL of the following are true:

- [ ] All acceptance criteria met (each AC has a pass/fail result documented)
- [ ] End-to-end test run (not just unit-level)
- [ ] Ken review completed (mandatory for any client-facing or external output)
- [ ] Notion status updated to `Done`
- [ ] Any dependencies on other items updated (downstream items unblocked)

### Epic

An Epic is done when ALL of the following are true:

- [ ] All child User Stories are closed (DoD met for each US)
- [ ] Operational playbook written and published to Holocron (Y3 guardrail — every shipped capability must have a playbook)
- [ ] Ken sign-off given
- [ ] Epic entry in Notion updated to `Complete` with actual completion date
- [ ] OKR delta noted: did this epic move its KR? Record the delta.

### INC (Incident)

An Incident is resolved when ALL of the following are true:

- [ ] Service restored to normal
- [ ] Root cause identified (or "unknown — under investigation" if not yet resolved)
- [ ] `scripts/incident-log.sh` updated
- [ ] Notion Incident DB updated
- [ ] P1/P2 incidents: PIR scheduled within 48 hours, PIR report completed within 5 days
- [ ] Preventive action raised as TKT if recurrence is possible

---

## 7. Framework Maturity Progression

### Current State (before this framework): L2 — Developing

What was in place:
- Notion backlog with User Stories, priority, effort, stream, category
- Ticket-first rule enforced
- Sprint planning with Ken each session
- Morning standup automated (8:00 AM)
- Ken approves sprint before work starts

What was missing:
- No fixed sprint length or cadence (sprint duration was session-dependent)
- No velocity tracking
- No formal Definition of Done enforcement
- No epic structure with OKR gate
- No formal ceremonies with defined duration/participants
- No retrospectives

### This Framework: L3 — Defined

What this adds:
- Fixed 1-week sprint cadence (Mon–Sun AEST)
- Capacity ceiling: 6 items per sprint
- Velocity tracking: % completion, rolling 4-sprint trend
- Epic structure: OKR-linked, Ken-gated, Atlas-reviewed
- Ceremonies: defined duration, participants, purpose
- Definition of Done: per item type, enforced
- Priority framework: 5-tier, OKR-capacity rule

### P2 Target (end August 2026): L3 Sustained

Evidence of L3 sustained:
- ≥ 80% sprint completion rate over 8 consecutive sprints
- Zero epics started without Ken gate
- 100% of shipped epics have Holocron playbooks
- Retrospective actions tracked and actioned (not just raised)
- QBR held at July 2026 with full OKR delta report

### P3 Target: L4 — Optimising

What L4 looks like:
- Predictable velocity within ±15% over rolling 8 sprints
- Data-driven sprint sizing (velocity → capacity)
- Cycle time measurement per work item type
- Retrospective action closure rate ≥ 90%
- Automated sprint analytics in Mission Control
- Epic throughput rate feeds next quarter planning

---

## 8. Sprint 1 — First Formally Planned Sprint Under This Framework

**Sprint:** 1
**Period:** 2026-05-07 to 2026-05-14
**Theme:** Unblock Ahsoka. Close strategy sequence. Fix critical drifts.
**Committed capacity:** 9 items (over the 6-item standard due to several quick-win auto-heal items)
**Sprint gate approved by:** Ken Mun (via TKT-0089 replan session, 2026-05-07)

| # | Item | TKT | OKR | Priority | Rationale |
|---|------|-----|-----|----------|-----------|
| 1 | Complete TKT-0087 governance ACs (P0: AC-1 to AC-4; P1: AC-5 to AC-8) | TKT-0087 | G1, X2-KR1 | P1 — Critical path | P0 ACs are P2 blockers. P1 ACs are Ahsoka live prerequisites. This item gates everything else in the sprint. |
| 2 | Close TKT-0088 — commit Section 10 decisions to Holocron | TKT-0088 | X2-KR1 | P1 — OKR-linked | Decisions are made but not persisted to SSOT. 30-min task. Must be done before decisions drift or are forgotten. |
| 3 | Fix model drift: Sage / Shield / Lex haiku → correct model | AUTO-HEAL ×3 | G1-KR3 | P3 — Platform health | Three governance agents running on the wrong model tier. Critical compliance gap — agents may be producing lower-quality governance outputs. |
| 4 | Fix cost tracker remainingEstimate bug | AUTO-HEAL | X1 | P3 — Platform health | False alarm risk. Burns Ken's attention with incorrect cost alerts. Quick fix (< 30 min). |
| 5 | TKT-0082 Ahsoka Pilot 1 — AInchors internal (continue) | TKT-0082 | S1-KR1, S2-KR1 | P1 — Critical path | In progress. The reference case for the consulting pillar. Every sprint it stalls is a sprint the consulting pipeline is blocked. |
| 6 | TKT-0069 VMS — Ken review + commit to Holocron | TKT-0069 | X2-KR1 | P2 — OKR-linked | VMS is complete but not reviewed or committed. Unblocks TKT-0070 (AI Policies) and TKT-0072 (BPM Agent/Lando). |
| 7 | TKT-0077 Persistent Agent Config — create Shield/Lex/Sage dirs | TKT-0077 | G1 | P4 — Governance | Governance baseline. Required for TKT-0087 AC-3 (persistent agent config). Quick structural fix. |
| 8 | MEMORY.md trim (15,570 chars → within bootstrapMaxChars) | AUTO-HEAL | — | P3 — Platform health | Oversized MEMORY.md degrades context loading and increases token burn on every session start. 15-min maintenance. |
| 9 | TKT-0090 Agile framework lock — this document | TKT-0090 | X2-KR1 | P1 — Strategy sequence | Final step in the TKT-0086 strategy coherence sequence. Cannot close the sequence without a locked delivery framework. |

**Sprint 1 Gate Criteria:**
- TKT-0087 P0 + P1 ACs closed (no partial credit)
- TKT-0086 sequence steps 4 + 5 complete (TKT-0089 + TKT-0090)
- All three model drifts resolved and confirmed by Warden
- TKT-0082 Pilot 1 continues with at least one concrete deliverable this sprint

---

## Appendix A — Quick Reference

### Ticket Hierarchy

```
Epic → US → TKT
           → INC (reactive)
           → CHG (operational)
```

### Sprint Week Rhythm

```
Sunday evening   → Sprint planning: Yoda proposes, Ken approves
Monday           → Sprint starts
Friday           → Sprint review: what shipped, what didn't, why
Sunday           → Velocity updated; next sprint proposed
```

### Priority Quick Check

```
Before picking the next item, ask:
1. Is this on the critical path? (P2 blocker or Auralith gate) → P1
2. Is this OKR-linked with this quarter delivery commitment? → P2
3. Is this a platform health / security gap? → P3
4. Is this governance / compliance? → P4
5. Is this innovation / improvement? → P5

If you're about to pick a P5 item and there are P1-P3 items open → stop. Pick the P1-P3 first.
```

### Definition of Done Cheat Sheet

```
TKT  → Deliverable works + CHG logged (if config) + Notion Closed + PVT pass
US   → All ACs met + tested + Ken reviewed (if client-facing) + Notion Done
Epic → All US closed + Holocron playbook + Ken sign-off + OKR delta recorded
INC  → Service restored + root cause documented + incident-log.sh updated + PIR (P1/P2)
```

---

## Appendix B — Framework Change Control

This is a locked operating document. It does not change informally.

**To propose a change:**
1. Raise a TKT with the proposed change and rationale
2. Yoda reviews against current OKR + maturity state
3. Ken approves change in writing (Notion or Telegram)
4. Document is updated with version increment and change log entry

**Minor changes** (clarifications, corrections): TKT + Ken verbal approval
**Major changes** (new tier, new ceremony, changed DoD): TKT + formal Ken sign-off + version increment

| Version | Date | Author | Summary |
|---------|------|--------|---------|
| v1.0 DRAFT | 2026-05-07 | Yoda 🟢 | Initial framework. TKT-0090. For Ken approval. |

---

*Document: `docs/ainchors-agile-framework-v1.md`*
*Produced by Yoda 🟢 | TKT-0090 | 2026-05-07*
*Inputs: TKT-0089 backlog replan, TKT-0086 Atlas EA roadmap, AInchors OKR 2026-05, frameworks-maturity.json*
