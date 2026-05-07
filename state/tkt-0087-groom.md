# TKT-0087 — Strategy & Governance Alignment: Resolve Conflicts, Close Gaps, Update Policies
**Raised:** 2026-05-07 | **Source:** TKT-0086 Steps 1+2 output | **Priority:** CRITICAL | **Assignee:** Yoda

---

## Purpose

Fix all conflicts, gaps, and realignments identified in TKT-0086 Steps 1 (Coherence Review) and 2 (Governance Gap Analysis). These must be resolved before AInchors can move to P2 (first SME clients) and before any Ahsoka consulting engagement.

---

## Groomed Backlog — Prioritised

### 🔴 P0 — P2 Blockers (cannot onboard first SME client without these)

**AC-1: Auralith governance coverage**
- AI Charter v1.0 and AI Governance Framework reference only "AInchors" — Auralith is unregistered
- Create Auralith addendum to AI Charter: data sovereignty ownership, Nexus operator responsibilities, DPA applicability, IP/liability delineation between AInchors and Auralith
- Lex to draft; Ken to approve
- Done when: AI Charter Section 1 covers both AInchors and Auralith with clear scope split

**AC-2: P2 pre-conditions elevated to critical path**
- TKT-0060 (Client DPA), TKT-0061 (Warden escalation thresholds), TKT-0062 (S4 tool scope), TKT-0063 (Ollama Cloud DPA exclusion) are now on the critical path for C1-KR3
- Re-open or confirm status of each. Any incomplete = sprint blocker
- Done when: All 4 TKTs closed or confirmed done with Lex sign-off

**AC-3: Per-client environment isolation policy**
- No governance document defines what isolation means technically for SME clients
- Write "Client Isolation Policy" doc: min requirements = separate config namespaces, separate logging paths, separate Sanctum review contexts, separate Warden monitoring per client_id
- Done when: Policy doc in Holocron, Warden updated to monitor per client_id, Shield/Lex approved

**AC-4: Nexus-first mandate in global policy**
- Nexus-first rule exists only in guardrails doc — absent from AI Charter, Governance Framework, RULES.md global section
- Add to RULES.md non-negotiable section AND AI Charter Section 3
- Done when: Warden can check that no client-facing proposal/implementation bypasses Nexus without explicit Ken CHG approval

---

### 🔴 P1 — Operational Blockers (block Ahsoka going live)

**AC-5: Fix R1 vs C4 deadlock (Aria + Ahsoka)**
- R1: Aria can only sell productised offers (requires CHG for exceptions)
- C4: Deals >A$50K escalated to Aria for approval
- These conflict — Aria cannot approve a non-productised deal even when escalated by Ahsoka
- Fix: Add explicit exception clause to R1: "Deals >A$50K escalated per C4 may be approved by Ken with written session approval, no CHG required"
- Done when: ARIA_RULES.md and Ahsoka spec both updated with the exception clause; no deadlock scenario possible

**AC-6: Ahsoka registered in AI Charter**
- Ahsoka operating without formal Charter registration (Charter violation)
- Add Ahsoka to AI Charter Section 6 agent table: agentId, role, scope, guardrails reference (C1-C4), model policy, SOUL.md confirmation
- Done when: AI Charter updated, CHG logged, Notion agent registry updated

**AC-7: Confirm R1-R3 written into ARIA_RULES.md**
- Guardrails doc specifies R1-R3 should be in ARIA_RULES.md — unconfirmed
- Read ARIA_RULES.md, confirm or add R1/R2/R3 sections with exact rule text
- Done when: ARIA_RULES.md contains R1, R2, R3 explicitly; CHG logged

**AC-8: Confirm C1-C4 written into Ahsoka spec**
- Guardrails doc specifies C1-C4 should be in ahsoka_role.md — unconfirmed
- Read agents/ahsoka/ahsoka_role.md, confirm or add C1-C4 under Behavioural Principles
- Done when: ahsoka_role.md contains C1, C2, C3, C4 explicitly; CHG logged

---

### 🟡 P2 — Governance Infrastructure (needed before first client is live)

**AC-9: Sanctum SLA logging (G2 implementation)**
- G2 defines <24h/<72h turnaround targets — no logging or measurement exists
- Create `state/sanctum-sla-log.json` schema. Every Sanctum review writes startAt + completedAt
- Add monthly SLA report to the 28th cadence cron
- Done when: First Sanctum review after implementation writes to log; monthly report produces <24h/<72h compliance %

**AC-10: Warden interval compliance tracking**
- OKR X1-KR3 requires <0.5% missed 15-min intervals over 30 days — no measurement mechanism
- Warden state file to log every run timestamp; monthly script calculates missed % 
- Done when: Warden logs run timestamps, monthly compliance report runs automatically

**AC-11: Warden W2 extension — client data tier enforcement**
- W2 requires Warden to track whether client-identified workloads run on Tier 2/3 (violation)
- Define `client_id` metadata field for tasks. Warden check #10: if task has client_id + model is Tier 2/3 = violation
- Done when: Warden reports check #10 results; model-policy.json updated with W2 definition

**AC-12: Training-led 80/20 enforcement mechanism**
- No metric, report, or alert enforces the training-led strategy split
- Add monthly business stream metric: consulting vs training pipeline ratio to `state/business-roi.json`
- Alert Aria/Angie if consulting pipeline exceeds 30% of total activity
- Done when: Monthly metric runs; first report produced

---

### 🟢 P3 — Rule Completions (should-do before first client, could defer if pressed)

**AC-13: New agent roster in AI Charter**
- Ahsoka, Thrawn, Lando, Mon Mothma not in AI Charter agent table
- Update Section 6 with all active agents; confirm Spark status (active/retired)
- Done when: Charter agent table matches openclaw.json agent list

**AC-14: Atlas A1 managed tenant timing clarification**
- Atlas A1 implies managed tenants at 3yr; VMS says 3-5yr
- Add clarification sentence to Atlas guardrail A1: "3yr horizon covers 3-5 SME PILOT managed clients; mass MSP scale is Year 5 only"
- Done when: ainchors-guardrails-rules-2026-05.md Section 4 A1 updated; CHG logged

**AC-15: NPS/quality tracking rule**
- OKR T1-KR2 requires NPS ≥40 but no rule mandates capture
- Add R4 to Aria rules: post-workshop NPS logged to Holocron within 48h
- Done when: ARIA_RULES.md has R4; Notion Holocron has NPS tracking template

**AC-16: Use-case pattern capture rule**
- OKR T1-KR4 requires 10+ SME use-case patterns in Holocron — no capture rule exists
- Add Aria rule: 1 SME use-case pattern captured after each workshop; Ahsoka captures during consulting
- Done when: Rule in ARIA_RULES.md and Ahsoka spec; Holocron has use-case template page

**AC-17: Case study publication guardrail**
- C1-KR4 requires 2 case studies — no rule about client consent or governance gate before publication
- Extend C3: case studies require written client sign-off AND full triad clearance before publication
- Done when: Ahsoka spec C3 updated; RULES.md content governance section references case studies

**AC-18: Architecture review cadence guardrail**
- OKR X2-KR3 requires 2 architecture reviews/quarter — no rule mandates this
- Add A4 to Atlas guardrails: Atlas triggers quarterly review in first 2 weeks of each quarter; Yoda schedules, Ken approves finding
- Done when: Guardrails doc updated; first Q3 review scheduled

**AC-19: SEA market extension guardrail**
- No rule for Ahsoka handling prospects from SEA markets outside AU/MY
- Add C5: non-AU/MY SEA prospects require Lex regulatory check + Ken/Angie approval before any proposal
- Done when: Ahsoka spec C5 added

**AC-20: L3 training governance trigger**
- L3 Nexus training engagements could deploy Nexus without governance gate
- Classify L3 training explicitly as requiring Shield→Lex→Sage gate (same as consulting proposals)
- Done when: RULES.md governance gate section lists L3 training as in-scope

---

## Sprint Recommendation

**Next sprint (execute in order):**
1. AC-1 (Auralith Charter) — Lex sub-agent draft, Ken approval
2. AC-2 (P2 pre-conditions) — status check TKT-0060-0063, re-open if needed
3. AC-7 + AC-8 (ARIA_RULES + Ahsoka spec confirmations) — quick reads, patch if missing
4. AC-5 (R1 vs C4 deadlock fix) — 2-line rule change
5. AC-6 (Ahsoka in AI Charter) — table update
6. AC-3 (Client isolation policy) — Yoda + Atlas draft
7. AC-4 (Nexus-first in global policy) — RULES.md + Charter update
8. AC-9 (Sanctum SLA log) — schema + cron

AC-10 through AC-20: next sprint after above are closed.

---

## Acceptance Criteria — DONE Definition

TKT-0087 is DONE when:
- All P0 ACs (1-4) are closed with Ken sign-off
- All P1 ACs (5-8) are closed
- TKT-0086 Step 4 (backlog replan) has been completed using Atlas output
- TKT-0086 Step 5 (Agile framework lock) has been triggered

**Gate:** TKT-0087 P0+P1 must be complete before ANY Ahsoka client engagement goes live.
