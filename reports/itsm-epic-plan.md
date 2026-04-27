# EPIC-001: AInchors ITSM Operational Framework
**Author:** Yoda 🟢 — AI Business Operations Lead  
**Subject:** Ken Mun (CTO), AI Anchor Solutions Pty Ltd  
**Date:** 2026-04-27  
**Version:** 1.0  
**Status:** READY FOR SPRINT PLANNING  
**Companion:** itil-gap-analysis.md

---

## 1. Epic Overview

| Field | Value |
|-------|-------|
| **Epic ID** | EPIC-001 |
| **Epic Name** | AInchors ITSM Operational Framework |
| **Owner** | Ken Mun (CTO) — executed by Yoda 🟢 |
| **Duration** | 8 weeks (4 phases × 2 weeks) |
| **Start** | Week 1 of operations (immediate) |
| **Status** | Not Started |
| **Total US** | 32 User Stories (ITSM-US-001 to ITSM-US-032) |
| **Dependencies** | TKT system (being built in parallel), Notion workspace, existing scripts |
| **Success Owner** | Ken Mun |

---

## 2. Vision Statement

AInchors will operate with the operational discipline of a mature IT services company from Day 1 — not because we need enterprise process, but because **right-sized ITSM is a competitive advantage**. When we can tell a prospective client "here's our SLA, here's how we handle incidents, here's our change record from the last 30 days," we close deals that competitors lose on trust alone. EPIC-001 takes the strong foundation already built in Days 1–3 and wraps it in a coherent, ITIL 4-aligned framework that scales from 1 agent to 12, from 0 clients to 50, without ever becoming bureaucratic theatre. Every practice in this framework must earn its keep — if it doesn't reduce risk, improve quality, or save Ken time, it doesn't ship.

---

## 3. Guiding Principles

**P1 — Ticket First, Always**  
Nothing gets worked without a ticket. Every request, incident, change, and problem has a TKT record. No exceptions, no "I'll file it later." This single discipline pays for the entire framework.

**P2 — Automate Before You Document**  
If a process can be scripted, script it first. Documentation describes what the automation does — it doesn't replace it. Manual processes are debt.

**P3 — Right-Size for a Startup**  
1 CTO + 1 AI lead + 11 planned agents. Every ITIL practice is adapted to this context. No CAB meetings with 8 people. No change freeze calendar with 40 windows. Keep it lean, keep it fast, keep it real.

**P4 — Notion is the Single Source of Truth**  
No ITSM tool sprawl. Notion is the ITSM tool of record. TKT integrates with Notion. Obsidian is for knowledge drafting; Notion is for operational data. One source, always current.

**P5 — Measure What You Commit To**  
Define SLOs → measure them. Define CI targets → track them. Undefined metrics are useless. Metrics you don't measure are dishonest. Every practice must have at least one measurable outcome.

**P6 — Preserve What Works**  
Existing scripts, docs, and databases are assets. The framework wraps them, extends them, and connects them — it doesn't replace them. auto-heal.sh stays. incident-log.sh stays. They just gain severity fields, CMDB links, and SLO context.

**P7 — Client-Ready from Day One**  
Every operational practice should be something we'd proudly show a client. "Here's our incident management process" should produce documentation, metrics, and a record — not a shrug. Operational excellence is a sales asset.

---

## 4. Framework Architecture

When EPIC-001 is complete, the AInchors ITSM Operational Framework looks like this:

```
┌─────────────────────────────────────────────────────────────────────┐
│                    AInchors ITSM Framework                          │
│                                                                     │
│  DEMAND LAYER                                                       │
│  ┌─────────────────┐  ┌──────────────────┐  ┌───────────────────┐  │
│  │  Service Desk   │  │ Service Catalogue│  │  Event Stream     │  │
│  │  (Yoda + TKT)   │  │  (15-20 items)   │  │  (health/alerts)  │  │
│  └────────┬────────┘  └────────┬─────────┘  └─────────┬─────────┘  │
│           │                   │                        │            │
│  CONTROL LAYER                                                      │
│  ┌─────────▼──────────────────▼────────────────────────▼─────────┐ │
│  │              TKT System (TKT-NNNN)                             │ │
│  │  INC | PRB | CHG | SRQ | TKT types unified                    │ │
│  └──────┬────────┬──────────┬──────────┬──────────────────────── ┘ │
│         │        │          │          │                            │
│  PRACTICE LAYER                                                     │
│  ┌──────▼──┐ ┌───▼───┐ ┌───▼──────┐ ┌─▼─────────────────────────┐ │
│  │Incident │ │Problem│ │ Change   │ │ Service Level Management   │ │
│  │Mgmt P1-4│ │PRB+   │ │Std/Norm/ │ │ SLO/SLA tracking          │ │
│  │PIR flow │ │KEDB   │ │Emergency │ │ Breach alerts             │ │
│  └──────┬──┘ └───┬───┘ └───┬──────┘ └───────────────────────────┘ │
│         │        │         │                                        │
│  INFRASTRUCTURE LAYER                                               │
│  ┌──────────────┐ ┌─────────────────┐ ┌──────────────────────────┐ │
│  │ CMDB         │ │ Monitoring      │ │ Knowledge Base           │ │
│  │ (CI types,   │ │ (metrics.json,  │ │ (Notion KB, Obsidian,    │ │
│  │  relations,  │ │  trend alerts,  │ │  article lifecycle,      │ │
│  │  blast radius│ │  capacity data) │ │  linked to TKT/INC)      │ │
│  └──────────────┘ └─────────────────┘ └──────────────────────────┘ │
│                                                                     │
│  IMPROVEMENT LAYER                                                  │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ Continual Improvement Register → Weekly CI Review → ROI     │   │
│  │ Availability Report → SLO Trend → Capacity Forecast         │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### Key integration points:
- **TKT system** is the hub — INC, PRB, CHG, SRQ all flow through it
- **health-check.sh** feeds Event stream → auto-classifies → raises INC if EXCEPTION
- **auto-heal.sh** resolves INC autonomously + logs result to TKT
- **CMDB** is referenced by CHG (blast radius) and PRB (affected CIs)
- **SLO tracker** reads from TKT (response/resolution times) and health (availability)
- **KB** articles are linked from INC/PRB/TKT records
- **CI Register** aggregates INC trends → raises CI items automatically

---

## 5. Implementation Phases

### Phase 1 — Foundation (Weeks 1–2): "Ticket First + SLOs"
**Goal:** Close the two CRITICAL gaps — Service Desk/Ticket First discipline and Service Level Management. Everything else builds on these.

**Deliverables:**
- TKT system integrated with Notion
- Yoda formally = Service Desk lead with triage protocol
- 4 incident severity tiers (P1–P4) with SLOs
- Service Level SLOs defined and published
- SLO tracking live in Notion

**Definition of Done:** Every request/incident has a TKT. SLOs are defined and being measured.

---

### Phase 2 — Core Practices (Weeks 3–4): "Request + Problem + CMDB"
**Goal:** Fill the highest-impact operational gaps — Service Catalogue, Problem Management, CMDB extension.

**Deliverables:**
- Service Catalogue (15–20 items with SLOs)
- Service Request fulfilment workflow
- Problem Management workflow (PRB type, KEDB)
- CMDB extended (CI types, relationships, blast radius check)
- Continual Improvement Register live

**Definition of Done:** Any service request has a catalogue item and SLO. Recurring incidents auto-raise PRBs.

---

### Phase 3 — Intelligence (Weeks 5–6): "Monitoring + Capacity + Knowledge"
**Goal:** Add trend intelligence to monitoring, close Capacity & Performance gap, structure Knowledge Base.

**Deliverables:**
- Metric time-series logging (state/metrics.json)
- Capacity monitoring: CPU/RAM/disk/API alerts
- Agent performance monitoring
- Knowledge Base index with article lifecycle
- Monthly availability + capacity reports automated

**Definition of Done:** Can produce 30-day trend charts for any key metric. KB articles linked to INC/PRB records.

---

### Phase 4 — Optimisation (Weeks 7–8): "Release + Events + CI Cadence"
**Goal:** Formalise Release Management, harden Event Management taxonomy, establish Continual Improvement cadence.

**Deliverables:**
- Release types defined (Hotfix/Standard/Major)
- Release notes template and release calendar
- Event taxonomy implemented in health-check.sh
- Alert suppression rules
- Weekly CI review cadence running
- ITSM Framework v1.0 retrospective

**Definition of Done:** Framework self-reports on its own health. CI register has a closed loop.

---

## 6. Full User Story Breakdown

---

### PHASE 1 — Foundation

---

#### ITSM-US-001: Define Incident Severity Tiers

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-001 |
| **Title** | Define and implement P1–P4 incident severity tiers |
| **Story** | As Ken (CTO), I want incidents classified by severity (P1–P4) with defined SLOs, so that we prioritise responses appropriately and don't treat a gateway outage the same as a slow disk. |
| **Phase** | 1 |
| **Priority** | CRITICAL |
| **Effort** | S |
| **Category** | Incident Management |
| **Dependencies** | None |
| **Existing artefacts** | scripts/incident-log.sh, state/incident-log.json, Notion Incident Log DB |

**Acceptance Criteria:**
- [ ] P1–P4 severity definitions documented with examples (P1=platform down, P2=degraded, P3=minor impact, P4=cosmetic/info)
- [ ] Severity field added to `incident-log.sh log` command
- [ ] Response and resolution SLOs defined per tier (P1: respond 15m/resolve 1h; P2: respond 1h/resolve 4h; P3: respond 4h/resolve 24h; P4: respond 24h/resolve 72h)
- [ ] Existing INC records back-populated with severity tier
- [ ] Severity field visible in Notion Incident Log DB view

---

#### ITSM-US-002: Formalise Service Desk Function

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-002 |
| **Title** | Formalise Yoda as Service Desk Lead with triage protocol |
| **Story** | As Ken, I want a defined service desk function where Yoda triages all incoming requests/incidents, so that nothing falls through the cracks and I can operate at CTO level instead of being the first responder for everything. |
| **Phase** | 1 |
| **Priority** | CRITICAL |
| **Effort** | S |
| **Category** | Service Desk |
| **Dependencies** | ITSM-US-001 (severity tiers), ITSM-US-005 (TKT integration) |
| **Existing artefacts** | Morning standup (8AM), Telegram alerts, OpenClaw chat |

**Acceptance Criteria:**
- [ ] Yoda's Service Desk role documented in Operations/ServiceDesk.md
- [ ] Triage protocol defined: receive → classify → assign → acknowledge → escalate if P1/P2
- [ ] Acknowledgement SLOs by severity (P1: 5 min, P2: 15 min, P3: 1h, P4: 4h)
- [ ] "Ticket First" rule documented and communicated — no work starts without TKT
- [ ] Yoda generates daily desk report (open tickets, ageing, SLA breach risk) at morning standup

---

#### ITSM-US-003: Define Service Level Objectives (SLOs)

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-003 |
| **Title** | Define and publish internal SLOs for platform and services |
| **Story** | As Ken, I want clearly defined SLOs for platform availability and incident response/resolution, so that we have targets to measure against and can demonstrate operational capability to clients. |
| **Phase** | 1 |
| **Priority** | CRITICAL |
| **Effort** | S |
| **Category** | Service Level Management |
| **Dependencies** | ITSM-US-001 |
| **Existing artefacts** | health-check.sh, state/incident-log.json, MTTR tracking |

**Acceptance Criteria:**
- [ ] Platform availability SLO defined: ≥99.5% monthly (allows ~3.6h downtime/month)
- [ ] Per-severity response and resolution SLOs defined (see ITSM-US-001)
- [ ] SLOs documented in Operations/SLOs.md
- [ ] SLO targets visible in Notion as a reference DB or page
- [ ] SLO measurement methodology documented (how we calculate availability from health-check data)

---

#### ITSM-US-004: Build SLO Measurement Tracking

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-004 |
| **Title** | Implement SLO measurement and weekly reporting |
| **Story** | As Ken, I want actual SLO performance measured and reported weekly, so that we know if we're meeting our commitments and can catch SLA breaches before clients do. |
| **Phase** | 1 |
| **Priority** | CRITICAL |
| **Effort** | M |
| **Category** | Service Level Management |
| **Dependencies** | ITSM-US-003, ITSM-US-001 |
| **Existing artefacts** | health-check.sh, scripts/incident-log.sh, state/incident-log.json |

**Acceptance Criteria:**
- [ ] health-check.sh appends timestamped result to state/uptime-log.json (pass/fail per check)
- [ ] `slo-report.sh` script computes availability % for last 24h, 7d, 30d from uptime-log.json
- [ ] Incident response time vs SLO target computed from INC records
- [ ] Weekly SLO report auto-generated by Yoda (Friday nightly close)
- [ ] SLO breach (actual < target) triggers Telegram alert

---

#### ITSM-US-005: Integrate TKT System with Notion

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-005 |
| **Title** | Connect TKT-NNNN system to Notion as single ITSM record |
| **Story** | As Yoda (Service Desk Lead), I want all TKT tickets mirrored/linked in Notion, so that Notion remains the single source of truth and Ken can view all operational activity in one place. |
| **Phase** | 1 |
| **Priority** | CRITICAL |
| **Effort** | M |
| **Category** | Service Desk |
| **Dependencies** | TKT system build (parallel track) |
| **Existing artefacts** | Notion Backlog DB, Notion Tasks DB, Notion Incident Log DB |

**Acceptance Criteria:**
- [ ] TKT tickets of type INC sync to Notion Incident Log DB
- [ ] TKT tickets of type CHG sync to Notion Change Log DB
- [ ] TKT tickets of type SRQ visible in Notion Tasks or new Service Requests DB
- [ ] TKT ID (TKT-NNNN) is the primary identifier across all linked records
- [ ] Existing INC records migrated to TKT format (CHG-NNNN and INC records get TKT cross-references)

---

#### ITSM-US-006: Post-Incident Review (PIR) Process

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-006 |
| **Title** | Define and automate PIR trigger for P1/P2 incidents |
| **Story** | As Ken, I want every P1 and P2 incident to automatically trigger a Post-Incident Review (PIR), so that we learn from serious incidents and don't repeat them. |
| **Phase** | 1 |
| **Priority** | HIGH |
| **Effort** | S |
| **Category** | Incident Management |
| **Dependencies** | ITSM-US-001, ITSM-US-005 |
| **Existing artefacts** | scripts/incident-log.sh (rca field), Notion Incident Log DB |

**Acceptance Criteria:**
- [ ] PIR template defined: timeline, impact, root cause, contributing factors, action items, owner
- [ ] P1/P2 INC closure automatically creates PIR TKT linked to original INC
- [ ] PIR must be completed within 24h of P1 resolution, 72h of P2 resolution
- [ ] PIR action items become separate TKTs (Problem or CI type)
- [ ] PIR summary added to incident-log.sh report output

---

#### ITSM-US-007: Auto-Heal Incident Logging

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-007 |
| **Title** | Patch auto-heal.sh to file INC record for every self-resolved event |
| **Story** | As Yoda, I want every auto-heal resolution to create an INC record, so that self-healed incidents are visible in our incident history and we can spot patterns even in "handled" failures. |
| **Phase** | 1 |
| **Priority** | HIGH |
| **Effort** | S |
| **Category** | Incident Management |
| **Dependencies** | ITSM-US-001 |
| **Existing artefacts** | scripts/auto-heal.sh, scripts/incident-log.sh |

**Acceptance Criteria:**
- [ ] auto-heal.sh calls incident-log.sh after each auto-resolved check (with severity P3/P4, status=auto-resolved)
- [ ] INC record includes: check name, symptom detected, fix applied, resolution time
- [ ] Auto-resolved INC records tagged "auto-heal" for filtering in Notion
- [ ] Auto-heal weekly summary shows count of auto-resolved vs filed-for-Ken incidents
- [ ] No duplicate INC creation if same check fires and auto-resolves multiple times in same run

---

### PHASE 2 — Core Practices

---

#### ITSM-US-008: Build Service Catalogue

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-008 |
| **Title** | Define and publish AInchors Service Catalogue (v1) |
| **Story** | As Ken, I want a defined catalogue of services that Yoda and agents can fulfil, so that requests have a defined scope, SLO, and fulfilment path — and we can show clients what we offer. |
| **Phase** | 2 |
| **Priority** | CRITICAL |
| **Effort** | M |
| **Category** | Service Request Management |
| **Dependencies** | ITSM-US-003, ITSM-US-005 |
| **Existing artefacts** | Notion Backlog DB, auto-heal.sh (12 service actions), run-diagnostics.sh |

**Acceptance Criteria:**
- [ ] Minimum 15 catalogue items defined (internal ops + client-facing)
- [ ] Each item has: name, description, owner, SLO (fulfilment time), inputs required, output delivered
- [ ] Catalogue published in Notion (Service Catalogue DB)
- [ ] Each item maps to a TKT request type (SRQ subtype)
- [ ] Catalogue v1 reviewed and signed off by Ken

**Starter catalogue items (to be expanded):**
1. Run Platform Diagnostics — 30 min SLO
2. Deploy New Agent — 2h SLO
3. Generate Operational Report — 1h SLO
4. Update Content Calendar — 2h SLO
5. Rotate Secrets — 30 min SLO
6. Run PVT — 15 min SLO
7. Backup On-Demand — 15 min SLO
8. Asset Registry Review — 1h SLO
9. Incident RCA Report — 4h SLO
10. Generate Client Report — 2h SLO
11. Update Knowledge Base Article — 1h SLO
12. Cost Report (on-demand) — 30 min SLO
13. Sprint Planning Brief — 1h SLO
14. Pre-Risky-Op Checkpoint — 15 min SLO
15. Onboard New Agent — 4h SLO

---

#### ITSM-US-009: Service Request Fulfilment Workflow

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-009 |
| **Title** | Implement service request intake and fulfilment workflow |
| **Story** | As Ken, I want service requests to follow a defined intake → assignment → fulfilment → closure workflow, so that requests don't get lost and SLOs are tracked end-to-end. |
| **Phase** | 2 |
| **Priority** | HIGH |
| **Effort** | M |
| **Category** | Service Request Management |
| **Dependencies** | ITSM-US-008, ITSM-US-005 |
| **Existing artefacts** | Notion Tasks DB, scripts/task-create.sh, scripts/task-complete.sh |

**Acceptance Criteria:**
- [ ] SRQ TKT states defined: New → Triaged → In Progress → Pending Ken → Closed
- [ ] Yoda auto-assigns SRQs matching catalogue items within acknowledgement SLO
- [ ] SLO breach alerts sent if SRQ not progressed within 50% of fulfilment SLO
- [ ] SRQ closure requires: output delivered, Ken acknowledgement (for client-facing), TKT note
- [ ] Weekly SRQ fulfilment report: volume, SLO adherence %, average fulfilment time

---

#### ITSM-US-010: Problem Management Workflow

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-010 |
| **Title** | Implement Problem Management (PRB tickets + KEDB) |
| **Story** | As Yoda, I want a formal Problem Management process with PRB tickets and a Known Error Database, so that recurring incidents are tracked, root causes investigated, and workarounds documented for future reference. |
| **Phase** | 2 |
| **Priority** | HIGH |
| **Effort** | M |
| **Category** | Problem Management |
| **Dependencies** | ITSM-US-001, ITSM-US-005 |
| **Existing artefacts** | scripts/incident-log.sh (rca field), state/incident-log.json |

**Acceptance Criteria:**
- [ ] PRB ticket type created in TKT system, synced to Notion (new Problem DB)
- [ ] Auto-rule: any INC with same root cause occurring 2+ times in 30 days → Yoda raises PRB
- [ ] PRB record includes: problem statement, linked INCs, affected CIs, workaround, status, root cause (when found)
- [ ] KEDB created in Notion: Known Error entries with symptom, workaround, linked PRB
- [ ] PRB closure requires: root cause confirmed, fix implemented or permanent workaround documented in KEDB

---

#### ITSM-US-011: Extend Asset Registry to CMDB

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-011 |
| **Title** | Extend Notion Asset Registry to function as a CMDB with CI relationships |
| **Story** | As Ken, I want the asset registry to capture relationships between configuration items (not just a list), so that we know the blast radius of any change before we make it. |
| **Phase** | 2 |
| **Priority** | HIGH |
| **Effort** | L |
| **Category** | Configuration Management |
| **Dependencies** | None |
| **Existing artefacts** | Notion Asset Registry DB (53 assets), scripts/asset-review.sh, state/config-baseline.json |

**Acceptance Criteria:**
- [ ] CI Type field added to Asset Registry: Host / Service / Script / Config / Secret / Agent
- [ ] CI Relationships field added (Notion relation to other Asset Registry records)
- [ ] Dependent Services field added (what breaks if this CI fails)
- [ ] Owner, Lifecycle Stage (Planned/Active/Deprecated/Retired), and Last Reviewed fields verified/added
- [ ] All 53 existing assets updated with CI Type and key relationships
- [ ] New CMDB view in Notion shows CIs grouped by type with relationship count

---

#### ITSM-US-012: Blast Radius Check in Pre-Risky-Op Rule

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-012 |
| **Title** | Add CMDB blast radius check to pre-risky-op checkpoint |
| **Story** | As Ken, I want the pre-risky-op checkpoint to query the CMDB for dependent CIs before any change is approved, so that we know what else might be impacted and can warn appropriately. |
| **Phase** | 2 |
| **Priority** | HIGH |
| **Effort** | M |
| **Category** | Configuration Management |
| **Dependencies** | ITSM-US-011, ITSM-US-013 |
| **Existing artefacts** | scripts/pre-restart-cleanup.sh, pre-risky-op rule (documented in Operations/Standards.md) |

**Acceptance Criteria:**
- [ ] `cmdb-blast-radius.sh <CI-ID>` script queries Notion Asset Registry for dependents of named CI
- [ ] Script outputs: CI name, dependent services, last change date, health status
- [ ] Pre-risky-op rule updated to include blast-radius check step before Ken confirmation
- [ ] If dependents found: output is shown to Ken, Ken explicitly confirms "aware of [N] dependents"
- [ ] CHG ticket references affected CIs (CI field added to CHG TKT template)

---

#### ITSM-US-013: Formalise Change Types (Standard/Normal/Emergency)

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-013 |
| **Title** | Define three change types and formalise change management process |
| **Story** | As Ken, I want change requests classified as Standard, Normal, or Emergency, so that routine changes don't need Ken sign-off but risky changes get appropriate review and we have an emergency break-glass procedure. |
| **Phase** | 2 |
| **Priority** | MEDIUM |
| **Effort** | S |
| **Category** | Change Enablement |
| **Dependencies** | ITSM-US-005 |
| **Existing artefacts** | CHANGELOG.md, scripts/changelog-append.sh, pre-risky-op checkpoint rule, Notion Change Log DB |

**Acceptance Criteria:**
- [ ] Change types documented: Standard (pre-approved scripts/automation, no Ken review), Normal (Ken approval required, CHG ticket), Emergency (break-glass, execute, retrospective review ≤24h)
- [ ] Standard Change catalogue defined (list of pre-approved change patterns)
- [ ] CHG TKT template updated with: change type, risk score (1–5), affected CIs, rollback plan
- [ ] Emergency change procedure documented: who can invoke, notification requirement, retrospective SLA
- [ ] Notion Change Log DB completed with all required fields for all CHG types

---

#### ITSM-US-014: Continual Improvement Register

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-014 |
| **Title** | Create Continual Improvement Register (CIR) in Notion |
| **Story** | As Ken, I want a Continual Improvement Register where all improvement ideas are captured, prioritised, and tracked to completion, so that good ideas don't get lost in journal entries and we can measure our improvement velocity. |
| **Phase** | 2 |
| **Priority** | MEDIUM |
| **Effort** | S |
| **Category** | Continual Improvement |
| **Dependencies** | ITSM-US-005 |
| **Existing artefacts** | Notion Backlog DB, daily journal (improvement notes), auto-heal Notion US filing |

**Acceptance Criteria:**
- [ ] CIR Notion DB created: CI-ID, title, description, source (INC/PRB/manual/audit), raised date, owner, status (Backlog/In Progress/Done/Won't Do), outcome, impact measurement
- [ ] Auto-rule: recurring INC (2x in 30 days) raises CI-ID linked to PRB
- [ ] Weekly Friday CI Review: Yoda generates CIR report, Ken prioritises top 3 for next week
- [ ] Monthly CI retrospective report auto-generated: items closed, average time-to-close, items raised
- [ ] All existing auto-heal "needs-Ken" Notion US migrated to CIR format

---

### PHASE 3 — Intelligence

---

#### ITSM-US-015: Metric Time-Series Logging

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-015 |
| **Title** | Add timestamped metric logging to health-check for trend analysis |
| **Story** | As Yoda, I want health-check results stored as a time series (not just pass/fail at one point), so that we can detect gradual degradation trends before they become incidents. |
| **Phase** | 3 |
| **Priority** | HIGH |
| **Effort** | M |
| **Category** | Monitoring & Event Management |
| **Dependencies** | ITSM-US-003 |
| **Existing artefacts** | scripts/health-check.sh |

**Acceptance Criteria:**
- [ ] health-check.sh appends each run result to state/metrics.json: timestamp, check name, result (pass/fail/value), duration_ms
- [ ] metrics.json has rolling 90-day retention (auto-prune entries older than 90 days)
- [ ] `metrics-trend.sh <check-name> <days>` script computes: pass rate %, average value, trend (improving/stable/degrading)
- [ ] Nightly close includes metrics trend summary for all checks (degrading trends flagged)
- [ ] SLO measurement (ITSM-US-004) reads from metrics.json for availability calculation

---

#### ITSM-US-016: Capacity Monitoring and Alerting

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-016 |
| **Title** | Add system resource capacity monitoring to nightly close |
| **Story** | As Ken, I want CPU, RAM, disk, and API usage tracked and alerted at threshold, so that we don't hit capacity walls during client work or agent scale-out. |
| **Phase** | 3 |
| **Priority** | HIGH |
| **Effort** | M |
| **Category** | Capacity & Performance Management |
| **Dependencies** | ITSM-US-015 |
| **Existing artefacts** | scripts/health-check.sh (disk check), state/cost-state.json, scripts/cost-tracker.sh |

**Acceptance Criteria:**
- [ ] `capacity-snapshot.sh` collects: CPU% (5-min avg), RAM used/total, disk used/total, API calls today vs daily limit, Ollama inference queue depth
- [ ] Capacity snapshot runs at nightly close and appends to state/capacity-log.json
- [ ] Alert thresholds: disk >80% = WARNING, >90% = CRITICAL; RAM >85% = WARNING; API usage >70% of limit = WARNING
- [ ] Capacity trend (7-day) included in Friday CI review
- [ ] `capacity-forecast.sh` projects days-to-threshold based on 7-day trend (e.g., "disk full in 23 days at current rate")

---

#### ITSM-US-017: Agent Performance Monitoring

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-017 |
| **Title** | Implement per-agent performance tracking (token usage, task rate, errors) |
| **Story** | As Ken, I want to see how each AI agent is performing — token spend, task completion rate, error rate — so that I can identify underperforming agents and optimise model assignment. |
| **Phase** | 3 |
| **Priority** | MEDIUM |
| **Effort** | L |
| **Category** | Capacity & Performance Management |
| **Dependencies** | ITSM-US-016, ITSM-US-015 |
| **Existing artefacts** | state/cost-state.json, Notion Agent Status DB |

**Acceptance Criteria:**
- [ ] Per-agent metrics tracked: task count (daily/weekly), token usage (daily/weekly), error count, average task duration
- [ ] Agent metrics stored in state/agent-metrics.json (per agent, rolling 30 days)
- [ ] Notion Agent Status DB updated with current metrics (automated daily)
- [ ] Weekly agent performance report generated by Yoda: top performer, most errors, cost-per-task per agent
- [ ] Alert if any agent has >20% error rate over 24h

---

#### ITSM-US-018: Availability Reporting

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-018 |
| **Title** | Automate monthly availability report generation |
| **Story** | As Ken, I want a monthly availability report generated automatically, so that we have objective evidence of platform reliability to share with clients and track improvement over time. |
| **Phase** | 3 |
| **Priority** | MEDIUM |
| **Effort** | S |
| **Category** | Availability Management |
| **Dependencies** | ITSM-US-004, ITSM-US-015 |
| **Existing artefacts** | state/uptime-log.json (from ITSM-US-004), scripts/incident-log.sh |

**Acceptance Criteria:**
- [ ] `availability-report.sh` generates: availability % for month, downtime events (count, duration, cause), SLO target vs actual, planned vs unplanned downtime split
- [ ] Report runs first day of each month for prior month
- [ ] Report saved to reports/availability-YYYY-MM.md
- [ ] Report linked in Notion (monthly review page)
- [ ] Report format is client-presentable (clean markdown, no internal jargon)

---

#### ITSM-US-019: Knowledge Base Index and Article Lifecycle

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-019 |
| **Title** | Create Knowledge Base index with article lifecycle management |
| **Story** | As Yoda, I want all operational knowledge organised in a searchable index with a defined lifecycle (Draft → Approved → Retired), so that agents can find accurate, current information without digging through scattered docs. |
| **Phase** | 3 |
| **Priority** | MEDIUM |
| **Effort** | M |
| **Category** | Knowledge Management |
| **Dependencies** | ITSM-US-010 |
| **Existing artefacts** | ~/Documents/AInchors (Obsidian vault), Operations/ docs (13 files), Standards.md, Compliance.md |

**Acceptance Criteria:**
- [ ] KB Index created in Notion: KB-ID, title, ITIL practice area, status (Draft/Active/Retired), last reviewed, author, linked TKT/INC/PRB records
- [ ] All 13 Operations/ docs registered in KB Index with KB-IDs
- [ ] Article lifecycle enforced: Active articles reviewed quarterly (auto-reminder to Yoda)
- [ ] INC and PRB records have KB link field: "resolved using KB-NNN"
- [ ] "Onboarding KB" package created: essential articles for any new agent type

---

#### ITSM-US-020: Maintenance Window Policy

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-020 |
| **Title** | Define planned maintenance window policy and schedule |
| **Story** | As Ken, I want defined maintenance windows where planned work can occur with reduced incident risk, so that clients know when to expect planned downtime and we have protected time for infrastructure work. |
| **Phase** | 3 |
| **Priority** | LOW |
| **Effort** | S |
| **Category** | Availability Management |
| **Dependencies** | ITSM-US-013 |
| **Existing artefacts** | scripts/backup.sh (02:00 scheduled), scripts/auto-heal.sh (23:30 scheduled) |

**Acceptance Criteria:**
- [ ] Standard maintenance window defined: Sundays 02:00–04:00 AEST (pre-existing backup/heal window)
- [ ] Emergency maintenance window procedure: 1h notice minimum, Telegram notification
- [ ] Maintenance window schedule maintained in Notion (calendar view)
- [ ] Normal CHG tickets scheduled within maintenance windows by default
- [ ] Availability SLO excludes planned maintenance downtime from calculation

---

### PHASE 4 — Optimisation

---

#### ITSM-US-021: Event Taxonomy Implementation

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-021 |
| **Title** | Implement INFO/WARNING/EXCEPTION event taxonomy in health-check |
| **Story** | As Yoda, I want health-check events classified as INFO, WARNING, or EXCEPTION, so that we don't treat all events the same and can implement appropriate automated responses per event class. |
| **Phase** | 4 |
| **Priority** | MEDIUM |
| **Effort** | M |
| **Category** | Event Management |
| **Dependencies** | ITSM-US-015 |
| **Existing artefacts** | scripts/health-check.sh, scripts/auto-heal.sh |

**Acceptance Criteria:**
- [ ] Event classes defined: INFO (log only), WARNING (log + Yoda reviews at next standup), EXCEPTION (log + raise INC + alert Ken immediately)
- [ ] health-check.sh output includes event class tag per check result
- [ ] Event class drives automated response: INFO → metrics.json, WARNING → Notion note, EXCEPTION → INC creation + Telegram alert
- [ ] Alert suppression rule: same EXCEPTION in <10 min → suppress repeat alerts, escalate once with count
- [ ] Event class visible in Notion Incident Log for EXCEPTION events

---

#### ITSM-US-022: Release Types and Release Notes Template

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-022 |
| **Title** | Define release types (Hotfix/Standard/Major) and release notes template |
| **Story** | As Ken, I want a defined release process with typed releases and standard release notes, so that anyone (including future team members) knows what changed, what the risk was, and how to roll back. |
| **Phase** | 4 |
| **Priority** | MEDIUM |
| **Effort** | S |
| **Category** | Release Management |
| **Dependencies** | ITSM-US-013 |
| **Existing artefacts** | scripts/pvt.sh, scripts/changelog-append.sh, CHANGELOG.md, pre-risky-op rule |

**Acceptance Criteria:**
- [ ] Release types documented: Hotfix (immediate, retrospective CHG ≤1h), Standard (planned, CHG ticket, maintenance window preferred), Major (Ken sign-off, maintenance window required, advance notice)
- [ ] Release notes template defined: version/date, change summary, affected components, test evidence (PVT result), rollback procedure
- [ ] Release notes generated automatically from CHG ticket + PVT result for Standard/Major releases
- [ ] Release calendar maintained in Notion
- [ ] PVT failure on Standard/Major release = auto-rollback trigger

---

#### ITSM-US-023: Release Calendar and Communication

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-023 |
| **Title** | Maintain release calendar and release communication workflow |
| **Story** | As Ken, I want a release calendar and communication workflow so that planned releases are visible in advance, clients are notified for major releases, and we can plan work around release dates. |
| **Phase** | 4 |
| **Priority** | LOW |
| **Effort** | S |
| **Category** | Release Management |
| **Dependencies** | ITSM-US-022, ITSM-US-020 |
| **Existing artefacts** | Notion Projects DB, Notion Content Calendar |

**Acceptance Criteria:**
- [ ] Release Calendar Notion DB (or view): release date, version, type, affected services, CHG reference, status
- [ ] Major release communication template: what's changing, when, expected downtime, contact if issues
- [ ] Upcoming releases included in weekly morning standup brief
- [ ] Releases aligned with maintenance windows by default (Standard/Major)
- [ ] Past releases viewable as release history with release notes linked

---

#### ITSM-US-024: Weekly CI Review Cadence

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-024 |
| **Title** | Establish weekly Continual Improvement review cadence |
| **Story** | As Ken, I want a regular (weekly, Friday) CI review where Yoda presents open CIR items and we prioritise the top 3 for next week, so that improvements don't stall and the improvement loop actually closes. |
| **Phase** | 4 |
| **Priority** | MEDIUM |
| **Effort** | S |
| **Category** | Continual Improvement |
| **Dependencies** | ITSM-US-014 |
| **Existing artefacts** | scripts/roi-update.sh, daily journal (Friday format), morning standup template |

**Acceptance Criteria:**
- [ ] Friday nightly close includes CI Review section: all open CIR items, items closed this week, top 3 recommended for next week (by Yoda, based on impact/effort)
- [ ] Monthly CI retrospective: items raised, closed, abandoned; average time-to-close; improvement impact
- [ ] CIR items that are >30 days In Progress flagged as stalled → Yoda escalates to Ken
- [ ] CI velocity metric tracked: CI items closed per month (target: ≥4/month)
- [ ] Closed CI items include: what changed, measurable outcome (e.g., "P3 incidents reduced 30%")

---

#### ITSM-US-025: ITSM Framework Health Dashboard

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-025 |
| **Title** | Build ITSM Framework health dashboard in Notion |
| **Story** | As Ken, I want a single Notion page showing the health of all ITSM practices at a glance, so that I can assess operational posture in 60 seconds without reading 15 separate reports. |
| **Phase** | 4 |
| **Priority** | MEDIUM |
| **Effort** | M |
| **Category** | Service Level Management |
| **Dependencies** | ITSM-US-004, ITSM-US-015, ITSM-US-016, ITSM-US-018 |
| **Existing artefacts** | Notion workspace, all reporting scripts |

**Acceptance Criteria:**
- [ ] ITSM Dashboard Notion page exists with sections per practice area
- [ ] Each practice shows: current RAG status (Red/Amber/Green), last updated, key metric, open actions
- [ ] Dashboard auto-updated by Yoda weekly (Friday nightly close)
- [ ] Platform availability % displayed prominently (current month vs SLO)
- [ ] Open tickets by type (INC/PRB/CHG/SRQ) and age displayed
- [ ] CI velocity and CIR backlog count visible

---

#### ITSM-US-026: ITSM Framework v1.0 Retrospective

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-026 |
| **Title** | Conduct ITSM Framework v1.0 retrospective at end of Phase 4 |
| **Story** | As Ken, I want a formal retrospective at the end of the 8-week epic, so that we assess what we built, what worked, what didn't, and plan EPIC-002 improvements from an evidence base. |
| **Phase** | 4 |
| **Priority** | MEDIUM |
| **Effort** | S |
| **Category** | Continual Improvement |
| **Dependencies** | All Phase 1–4 US |
| **Existing artefacts** | daily journal, CI register, SLO reports, availability reports |

**Acceptance Criteria:**
- [ ] Retrospective report produced: US completion rate, SLO performance, incident metrics, CMDB coverage %, KB article count
- [ ] Maturity re-assessment: score all 15 ITIL practices against gap analysis baseline (target: all ≥3)
- [ ] Top 5 items for EPIC-002 identified (from CIR and retrospective)
- [ ] Retrospective published as Obsidian note + Notion page
- [ ] EPIC-001 marked complete in Notion Projects DB

---

## 7. Migration User Stories

These US migrate/restructure EXISTING work to align under the new framework. They don't build new capabilities — they formalise and connect what already exists.

---

#### ITSM-US-027: Migrate Existing INC Records to P1–P4 Severity

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-027 |
| **Title** | Back-populate severity tier on all existing INC records |
| **Story** | As Yoda, I want all historical INC records (from state/incident-log.json and Notion) to have a severity tier, so that our historical MTTR data is comparable against SLO targets. |
| **Phase** | 1 |
| **Priority** | HIGH |
| **Effort** | S |
| **Category** | Incident Management |
| **Dependencies** | ITSM-US-001 |
| **Existing artefacts** | state/incident-log.json, Notion Incident Log DB |

**Acceptance Criteria:**
- [ ] All existing INC records reviewed and severity assigned (P1–P4 per new definitions)
- [ ] incident-log.json updated with severity field for all records
- [ ] Notion Incident Log DB severity field populated for all existing records
- [ ] MTTR calculated per severity tier from historical data
- [ ] Baseline established: "pre-EPIC-001 MTTR by severity" documented

---

#### ITSM-US-028: Migrate CHG Records to Complete Change Log

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-028 |
| **Title** | Complete Notion Change Log DB with all historical CHG records |
| **Story** | As Ken, I want the Notion Change Log to be complete and current (all CHG-NNNN entries from CHANGELOG.md present), so that our change history is queryable and we have an audit trail from Day 1. |
| **Phase** | 1 |
| **Priority** | MEDIUM |
| **Effort** | M |
| **Category** | Change Enablement |
| **Dependencies** | ITSM-US-013 |
| **Existing artefacts** | CHANGELOG.md (all CHG-NNNN entries), Notion Change Log DB (partial) |

**Acceptance Criteria:**
- [ ] All CHG entries from CHANGELOG.md present in Notion Change Log DB
- [ ] Each Notion CHG record has: CHG-ID, date, type, description, author, affected components, PVT result, status
- [ ] Change type field back-populated (Standard/Normal/Emergency as best-fit for historical changes)
- [ ] Notion Change Log DB has correct views: by type, by date, by status
- [ ] Going forward: changelog-append.sh also creates/updates Notion CHG record

---

#### ITSM-US-029: Migrate Existing Assets to CMDB CI Types

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-029 |
| **Title** | Classify all 53 existing assets with CI type and key relationships |
| **Story** | As Yoda, I want all existing assets in the registry classified by CI type and with at least their primary relationships documented, so that the CMDB is immediately useful for blast-radius analysis. |
| **Phase** | 2 |
| **Priority** | HIGH |
| **Effort** | L |
| **Category** | Configuration Management |
| **Dependencies** | ITSM-US-011 |
| **Existing artefacts** | Notion Asset Registry DB (53 assets), scripts/asset-review.sh |

**Acceptance Criteria:**
- [ ] All 53 assets classified with CI Type (Host/Service/Script/Config/Secret/Agent)
- [ ] Primary relationships documented for all CIs (at minimum: "depends on" and "used by" for each)
- [ ] Lifecycle stage assigned to all CIs
- [ ] At least the 7 Critical Config CIs have full relationship graphs
- [ ] asset-review.sh updated to include CMDB completeness check in weekly review

---

#### ITSM-US-030: Migrate Operations Docs to KB Index

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-030 |
| **Title** | Register all existing Operations/ docs in the Knowledge Base Index |
| **Story** | As Yoda, I want all 13 existing Operations docs registered in the KB Index with KB-IDs and practice area tags, so that agents can find them by category without knowing the filename. |
| **Phase** | 3 |
| **Priority** | MEDIUM |
| **Effort** | S |
| **Category** | Knowledge Management |
| **Dependencies** | ITSM-US-019 |
| **Existing artefacts** | ~/Documents/AInchors/Operations/ (13 files: Reliability.md, ResiliencyFramework.md, AutoHeal.md, RunDiagnostics.md, IncidentLog.md, OfflinePlaybook.md, AsyncExecution.md, SecretsManagement.md, Standards.md, Compliance.md, JournalFormat.md, BlogFormat.md, ROIModel.md) |

**Acceptance Criteria:**
- [ ] All 13 Operations docs registered in KB Index Notion DB with KB-ID (KB-001 to KB-013)
- [ ] Each doc tagged with ITIL practice area (may have multiple)
- [ ] Each doc has last-reviewed date (set to Day 3 as baseline)
- [ ] Article status set to Active for all 13 (they're current)
- [ ] Quarterly review reminder set for all 13 (trigger: 90 days from registration)

---

#### ITSM-US-031: Migrate Auto-Heal "Needs Ken" Items to CIR

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-031 |
| **Title** | Migrate existing auto-heal Notion US to Continual Improvement Register |
| **Story** | As Ken, I want all existing auto-heal "needs Ken" US migrated to the CIR format, so that they're tracked with proper CI-IDs, priority, and don't get lost in the general backlog. |
| **Phase** | 2 |
| **Priority** | MEDIUM |
| **Effort** | S |
| **Category** | Continual Improvement |
| **Dependencies** | ITSM-US-014 |
| **Existing artefacts** | Notion Backlog DB (auto-heal US entries), scripts/auto-heal.sh |

**Acceptance Criteria:**
- [ ] All existing auto-heal Notion US items reviewed and migrated to CIR DB
- [ ] Each item assigned CI-ID, source=auto-heal, priority assessed by Yoda
- [ ] Items with existing TKT/US references cross-linked
- [ ] auto-heal.sh updated to file new items directly to CIR DB (not general Backlog)
- [ ] Old auto-heal US entries in Backlog archived (not deleted — audit trail)

---

#### ITSM-US-032: Document SLA Template for Client Onboarding

| Field | Value |
|-------|-------|
| **US ID** | ITSM-US-032 |
| **Title** | Create client-facing SLA template based on internal SLOs |
| **Story** | As Ken, I want a client-ready SLA template derived from our internal SLOs, so that when the first client comes aboard we have a professional SLA to present rather than scrambling to create one under pressure. |
| **Phase** | 2 |
| **Priority** | HIGH |
| **Effort** | M |
| **Category** | Service Level Management |
| **Dependencies** | ITSM-US-003, ITSM-US-004 |
| **Existing artefacts** | Operations/Compliance.md, Operations/Standards.md |

**Acceptance Criteria:**
- [ ] SLA template document created (reports/client-sla-template.md)
- [ ] Template includes: service scope, availability targets, incident response times, exclusions, measurement methodology, reporting cadence, escalation contacts
- [ ] SLA targets are ≤ internal SLOs (never promise clients more than we promise ourselves)
- [ ] Template reviewed by Ken and marked "approved"
- [ ] Template stored in Obsidian (Legal/SLA-Template.md) and Notion (Compliance page)

---

## 8. Quick Wins (< 1 Day, No Migration Required)

These can be done immediately — no phase, no dependencies, no migration. Each takes 1–4 hours.

| # | Quick Win | Action | Value |
|---|-----------|--------|-------|
| QW-1 | **Define SLOs on paper today** | Write Operations/SLOs.md with P1–P4 response/resolution times and 99.5% availability target. No automation needed yet — just make the commitment. | Closes the most critical gap immediately, even before tooling |
| QW-2 | **Add severity field to INC CLI** | One-line addition to `incident-log.sh log` command to accept `--severity P1\|P2\|P3\|P4` parameter | INC records become comparable against SLOs |
| QW-3 | **Declare Yoda = Service Desk** | Add one paragraph to Standards.md: "Yoda is Service Desk lead. All requests/incidents via TKT or Telegram. Ticket First." | Zero cost, immediate clarity |
| QW-4 | **Add uptime logging to health-check.sh** | Append `{"ts": "...", "check": "...", "result": "pass\|fail"}` to state/uptime-log.json each run | Starts accumulating SLO measurement data immediately |
| QW-5 | **Create CI Register Notion DB** | Duplicate Backlog DB, rename to CIR, add CI-ID field. Migrate top 5 improvement ideas from journal | CI register exists and is immediately useful |
| QW-6 | **Add change type to pre-risky-op rule** | Update pre-risky-op rule to ask: "Is this Standard/Normal/Emergency?" and document the answer in CHG entry | Change classification starts immediately |
| QW-7 | **Tag Operations docs with ITIL practice** | Add 1-line header to each of 13 Operations docs: `ITIL Practice: [name]` | Knowledge classification starts without building Notion DB yet |
| QW-8 | **File PRB-001** | Look at incident history — pick the most likely recurring issue, file it as PRB-001 in Notion | Problem Management has its first record; the practice is real |

---

## 9. What NOT to Do (Anti-Patterns for Startup-Scale ITSM)

**DON'T implement a Change Advisory Board (CAB) with meetings.**  
For 1 CTO + AI, "CAB approval" = Ken says yes. Document it that way. CAB meetings are process theatre for teams of 20+.

**DON'T introduce a second ITSM tool (Jira, ServiceNow, Zendesk).**  
We're already in Notion. Adding Jira creates two sources of truth. Tool sprawl kills small teams. Extend Notion instead.

**DON'T define SLOs you can't measure.**  
"99.99% availability" sounds great but requires precision monitoring we don't have yet. Start with 99.5% and tighten it as measurement matures. An SLO you don't measure is a lie.

**DON'T build CMDB relationship graphs for all 53 assets at once.**  
Start with the 7 critical configs + 5 most-changed assets. Full CMDB coverage takes months even in enterprises. Prioritise the high-blast-radius CIs.

**DON'T require Ken to approve every ticket.**  
The goal is to free Ken to operate at CTO level. Yoda approves SRQs from the Service Catalogue. Ken only approves Normal/Emergency changes and P1 incident response. Define the delegation model clearly.

**DON'T over-document before automating.**  
A 20-page SLA document that describes a manual process is worse than no SLA — it's a liability and it won't be followed. Write the script first, then write 2 paragraphs about what the script does.

**DON'T skip the PIR because "we're a startup."**  
P1 incidents are rare — but each one is a $1,000+ learning opportunity. A 30-minute PIR that prevents the next P1 pays for itself 10x. Make PIRs lightweight but mandatory for P1/P2.

**DON'T let the TKT system delay everything.**  
While TKT is being built, use Notion Incident Log + Backlog as interim ticket stores. Don't freeze ITSM work waiting for perfect tooling. Migrate to TKT when it lands.

**DON'T measure everything from Day 1.**  
Pick 5 key metrics (availability %, MTTR P1, SRQ fulfilment rate, CI velocity, open PRBs). Get those right first. Adding 20 metrics before you understand 5 creates noise, not insight.

**DON'T treat ITIL as compliance.**  
ITIL is a toolbox, not a regulation. Every practice should pass the "does this help Ken or Yoda?" test. If it doesn't, don't implement it.

---

## 10. Success Metrics

### Phase 1 Complete (Week 2)
| Metric | Target |
|--------|--------|
| % of work items with TKT ticket | 100% |
| SLOs defined and documented | Yes (all P1–P4 + availability) |
| SLO measurement running | Yes (uptime-log.json populated) |
| INC records with severity tier | 100% |
| Yoda Service Desk role documented | Yes |

### Phase 2 Complete (Week 4)
| Metric | Target |
|--------|--------|
| Service Catalogue items defined | ≥15 |
| SRQ fulfilment SLO adherence | ≥90% |
| PRB tickets raised for recurring INCs | ≥1 (if applicable) |
| CMDB CI Type coverage | 100% of 53 assets |
| CMDB relationship documentation | ≥7 critical CIs fully mapped |
| CIR items tracked | ≥5 |

### Phase 3 Complete (Week 6)
| Metric | Target |
|--------|--------|
| Metric time-series data available | ≥14 days of data |
| Capacity alerts configured | All 4 thresholds active |
| Agent performance tracked | All active agents |
| KB articles registered | All 13 + 5 new |
| Availability report generated | Month-1 report complete |

### Phase 4 Complete (Week 8)
| Metric | Target |
|--------|--------|
| ITIL practice maturity (avg) | ≥3.0 / 5.0 |
| Practices at maturity ≥3 | ≥12 of 15 |
| Platform availability (monthly) | ≥99.5% |
| P1 MTTR | ≤1 hour |
| P2 MTTR | ≤4 hours |
| SLO breach rate | 0% (no SLO missed for full month) |
| CIR items closed in Phase 4 | ≥4 |
| CI velocity (CI items/month) | ≥4 |
| ITSM Dashboard live | Yes |
| EPIC-001 retrospective complete | Yes |

### Ongoing (Post EPIC-001)
| Metric | Cadence | Target |
|--------|---------|--------|
| Platform availability | Monthly | ≥99.5% |
| P1 MTTR | Per incident | ≤1h |
| SRQ SLO adherence | Weekly | ≥95% |
| CI velocity | Monthly | ≥4 items closed |
| Open PRBs (unresolved) | Weekly | ≤3 |
| CMDB accuracy | Quarterly audit | ≥95% CIs current |
| KB article freshness | Quarterly | 100% reviewed within 90 days |
| ITSM maturity re-assessment | Every 6 months | Target Level 4 by Month 6 |

---

## Appendix: User Story Summary Table

| US ID | Title | Phase | Priority | Effort | Category |
|-------|-------|-------|----------|--------|----------|
| ITSM-US-001 | Define P1–P4 incident severity tiers | 1 | CRITICAL | S | Incident Management |
| ITSM-US-002 | Formalise Yoda as Service Desk Lead | 1 | CRITICAL | S | Service Desk |
| ITSM-US-003 | Define internal SLOs | 1 | CRITICAL | S | Service Level Management |
| ITSM-US-004 | Build SLO measurement tracking | 1 | CRITICAL | M | Service Level Management |
| ITSM-US-005 | Integrate TKT system with Notion | 1 | CRITICAL | M | Service Desk |
| ITSM-US-006 | PIR process for P1/P2 incidents | 1 | HIGH | S | Incident Management |
| ITSM-US-007 | Auto-heal INC logging patch | 1 | HIGH | S | Incident Management |
| ITSM-US-008 | Build Service Catalogue | 2 | CRITICAL | M | Service Request Management |
| ITSM-US-009 | Service Request fulfilment workflow | 2 | HIGH | M | Service Request Management |
| ITSM-US-010 | Problem Management workflow + KEDB | 2 | HIGH | M | Problem Management |
| ITSM-US-011 | Extend Asset Registry to CMDB | 2 | HIGH | L | Configuration Management |
| ITSM-US-012 | Blast radius check in pre-risky-op | 2 | HIGH | M | Configuration Management |
| ITSM-US-013 | Define change types (Std/Normal/Emergency) | 2 | MEDIUM | S | Change Enablement |
| ITSM-US-014 | Continual Improvement Register | 2 | MEDIUM | S | Continual Improvement |
| ITSM-US-015 | Metric time-series logging | 3 | HIGH | M | Monitoring & Event Management |
| ITSM-US-016 | Capacity monitoring and alerting | 3 | HIGH | M | Capacity & Performance Management |
| ITSM-US-017 | Agent performance monitoring | 3 | MEDIUM | L | Capacity & Performance Management |
| ITSM-US-018 | Automated availability reporting | 3 | MEDIUM | S | Availability Management |
| ITSM-US-019 | KB Index and article lifecycle | 3 | MEDIUM | M | Knowledge Management |
| ITSM-US-020 | Maintenance window policy | 3 | LOW | S | Availability Management |
| ITSM-US-021 | Event taxonomy in health-check | 4 | MEDIUM | M | Event Management |
| ITSM-US-022 | Release types and release notes template | 4 | MEDIUM | S | Release Management |
| ITSM-US-023 | Release calendar and communication | 4 | LOW | S | Release Management |
| ITSM-US-024 | Weekly CI review cadence | 4 | MEDIUM | S | Continual Improvement |
| ITSM-US-025 | ITSM Framework health dashboard | 4 | MEDIUM | M | Service Level Management |
| ITSM-US-026 | ITSM Framework v1.0 retrospective | 4 | MEDIUM | S | Continual Improvement |
| ITSM-US-027 | Migrate INC records to severity tiers | 1 | HIGH | S | Incident Management (Migration) |
| ITSM-US-028 | Complete Notion Change Log DB | 1 | MEDIUM | M | Change Enablement (Migration) |
| ITSM-US-029 | Classify all 53 assets with CI types | 2 | HIGH | L | Configuration Management (Migration) |
| ITSM-US-030 | Register Operations docs in KB Index | 3 | MEDIUM | S | Knowledge Management (Migration) |
| ITSM-US-031 | Migrate auto-heal US to CIR | 2 | MEDIUM | S | Continual Improvement (Migration) |
| ITSM-US-032 | Client SLA template | 2 | HIGH | M | Service Level Management (Migration) |

**Total: 32 User Stories**  
- CRITICAL: 6 | HIGH: 13 | MEDIUM: 11 | LOW: 2  
- Phase 1: 9 US | Phase 2: 12 US | Phase 3: 8 US | Phase 4: 6 US  
- New capabilities: 26 US | Migration/formalisation: 6 US  
- Effort breakdown: S×17, M×12, L×3, XL×0

---

*End of EPIC-001 AInchors ITSM Operational Framework v1.0*  
*Companion: itil-gap-analysis.md*  
*Next action: Ken reviews and approves Phase 1 US for Sprint 1. Ticket First starts Day 4.*
