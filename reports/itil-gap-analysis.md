# AInchors ITIL 4 Gap Analysis
**Author:** Yoda 🟢 — AI Business Operations Lead  
**Subject:** Ken Mun (CTO), AI Anchor Solutions Pty Ltd  
**Date:** 2026-04-27  
**Version:** 1.0  
**Status:** FINAL

---

## 1. Executive Summary

AInchors is three days old. That's not a joke — it's remarkable context. In 72 hours, Ken and Yoda have assembled an operational baseline that most startups don't reach in 6 months: automated health checks, self-healing scripts, incident logging, change control, dual-path backups, asset registry, secrets management, cost tracking, and structured knowledge capture. This is not a "we need to start from scratch" situation.

What we **don't have** is a coherent, named framework that ties these pieces together. ITIL 4 gives us that frame. The gaps are real but manageable:

- **Problem Management** is absent — we log incidents but don't formally chase root causes
- **Service Request Management** has no defined catalogue or fulfilment workflow  
- **Service Level Management** has no SLOs, SLAs, or OLAs documented  
- **Service Desk** is informal — Ken + Yoda, no triage protocol, no ticket-first discipline (the TKT system being built now will fix this)  
- **Knowledge Management** is partially done (Obsidian) but not structured as a searchable service knowledge base  
- **Continual Improvement** happens reactively; no formal register or cadence  
- **Capacity & Performance Management** is absent beyond cost tracking  
- **Release Management** is ad-hoc; PVT covers validation but deployment pipeline isn't formalized  

**Overall maturity rating:** ITIL Level 2 (Managed) across most practices, with pockets of Level 3 (Defined) in Incident, Change, and Asset Management. Target: Level 3 across the board within 60 days, Level 4 (Quantitatively Managed) in 90 days for critical practices.

**This gap analysis drives EPIC-001: AInchors ITSM Operational Framework** — see companion file `itsm-epic-plan.md`.

---

## 2. ITIL 4 Framework Overview

**Edition:** ITIL 4 (2019, Axelos/PeopleCert)  
**Reference model:** Service Value System (SVS) + Service Value Chain (SVC)  
**Practice focus:** 14 of 34 ITIL 4 practices assessed below — the subset most relevant to a startup AI operations context.

### Why ITIL 4, not ITIL v3
ITIL 4 drops the rigid 5-stage lifecycle in favour of flexible practices. It integrates with Agile, DevOps, and Lean. For a 1-person + AI-agent shop, ITIL 4's "adopt and adapt" philosophy is exactly right — we take what helps, skip what would be theatre.

### Maturity Scale Used
| Level | Label | Description |
|-------|-------|-------------|
| 0 | Absent | No capability exists |
| 1 | Initial | Ad-hoc, undocumented, person-dependent |
| 2 | Managed | Documented, repeatable, but manual |
| 3 | Defined | Automated, consistent, metrics exist |
| 4 | Quantitatively Managed | SLOs/SLAs measured, trend-tracked |
| 5 | Optimising | Continuous improvement loop closes automatically |

---

## 3. Current State vs ITIL Best Practice

---

### 3.1 Incident Management

**ITIL 4 Definition:** Minimise the negative impact of incidents by restoring normal service operation as quickly as possible.

| Dimension | Detail |
|-----------|--------|
| **Current State** | `incident-log.sh` logs/lists/RCA/MTTR/report. `state/incident-log.json` is the store. Notion Incident Log DB synced. Health-check triggers Telegram alert at 3+ failures. Auto-heal resolves safe incidents autonomously. OfflinePlaybook.md covers degraded-mode ops. |
| **Gap** | No formal severity classification (P1/P2/P3/P4). No escalation matrix. No documented resolution time targets by severity. Auto-heal does not file an incident record for self-resolved events — those go unlogged. No post-incident review (PIR) schedule. |
| **Risk** | HIGH — Without severity tiers, every incident is treated the same. A gateway outage and a slow disk get equal urgency. MTTR data exists but isn't compared against targets (there are none). |
| **Recommendation** | 1. Define 4 severity tiers (P1–P4) with response/resolution SLOs. 2. Patch auto-heal to file an INC record for every self-resolved event. 3. Add PIR trigger for P1/P2: mandatory 24h post-incident review. 4. Add `incident-summary` weekly cron feeding Notion. |
| **Priority** | **HIGH** |
| **Current Maturity** | Level 2 |
| **Target Maturity** | Level 4 |

---

### 3.2 Problem Management

**ITIL 4 Definition:** Reduce the likelihood and impact of incidents by identifying actual and potential causes, and managing workarounds and known errors.

| Dimension | Detail |
|-----------|--------|
| **Current State** | `incident-log.sh rca` exists — but it's a field in the incident record, not a separate Problem workflow. No Problem tickets. No Known Error Database (KEDB). No trend analysis across incidents to surface recurring patterns. |
| **Gap** | Problem Management is effectively absent as a distinct practice. We have reactive incident closure but no proactive problem investigation. No KEDB means the same incidents recur without documented workarounds. |
| **Risk** | HIGH — Day 3 is too early to see patterns, but by Day 30 with 11 agents, recurring issues will cost Ken significant time if not tracked as Problems. |
| **Recommendation** | 1. Create `PRB-NNNN` ticket type in TKT system. 2. Add Problem record creation rule: any incident occurring 2+ times within 30 days → auto-raise PRB. 3. Build KEDB as a Notion DB (Known Errors table with symptom, workaround, linked PRB). 4. Monthly problem review: Yoda generates trend report from INC data. |
| **Priority** | **HIGH** |
| **Current Maturity** | Level 1 |
| **Target Maturity** | Level 3 |

---

### 3.3 Change Enablement

**ITIL 4 Definition:** Maximise the number of successful IT changes by ensuring that risks have been properly assessed, authorising changes to proceed, and managing the change schedule.

| Dimension | Detail |
|-----------|--------|
| **Current State** | CHANGELOG.md (append-only, CHG-NNNN series). `changelog-append.sh`. Pre-risky-op checkpoint rule (flush context → clean deps → git commit → confirm Ken → execute → PVT). PVT validates post-change. Notion Change Log DB (partial). No changes made without logging. |
| **Gap** | No formal change types (Standard/Normal/Emergency). No Change Advisory Board (CAB) process — though for 1 person this should be lightweight. No change freeze periods documented. No change risk scoring. Emergency change procedure not documented. Notion Change Log noted as "partial" — needs completion. |
| **Risk** | MEDIUM — The pre-risky-op rule is solid but informal. Without change types, everything goes through the same heavyweight process, which will cause Ken to skip it for "small" changes — exactly where drift and incidents originate. |
| **Recommendation** | 1. Define 3 change types: Standard (pre-approved, script-run, no review), Normal (Ken approval required, CHG ticket), Emergency (break-glass, retrospective review within 24h). 2. Complete Notion Change Log DB with all CHG-NNNN fields. 3. Document change freeze periods (e.g., no normal changes on Mon AM before standup). 4. Add change risk score to CHG template (1–5 scale). |
| **Priority** | **MEDIUM** |
| **Current Maturity** | Level 2 |
| **Target Maturity** | Level 3 |

---

### 3.4 Service Request Management

**ITIL 4 Definition:** Support the agreed quality of a service by handling all pre-defined, user-initiated service requests in an effective and user-friendly manner.

| Dimension | Detail |
|-----------|--------|
| **Current State** | No service catalogue. No formal request types. Ken makes requests ad-hoc via chat. Yoda fulfils them. No fulfilment SLOs. No request tracking beyond chat history. The TKT system is being built — no integration yet. |
| **Gap** | Entirely informal. No catalogue, no ticket, no SLO, no fulfilment workflow. As agents multiply to 11, request management becomes critical — without structure, Yoda can't prioritise or Ken can't track what's in flight. |
| **Risk** | HIGH — At 12 agents (Ken + 11 AI), work requests will collide. No queue = no visibility = dropped work or duplicated effort. |
| **Recommendation** | 1. Define an initial Service Catalogue (15–20 services Yoda/agents can fulfil — e.g., "Deploy new agent", "Generate report", "Run diagnostics", "Update content calendar"). 2. All requests become TKT tickets (when TKT system lands). 3. Define fulfilment SLOs per catalogue item (e.g., "Generate report" = 30 min, "Deploy agent" = 2 hours). 4. Build request intake template in Notion. |
| **Priority** | **CRITICAL** |
| **Current Maturity** | Level 0 |
| **Target Maturity** | Level 3 |

---

### 3.5 Service Desk

**ITIL 4 Definition:** Capture demand for incident resolution and service requests, and be the entry point and single point of contact for the service provider with all its users.

| Dimension | Detail |
|-----------|--------|
| **Current State** | Informal. Ken → Yoda via OpenClaw chat. Telegram for alerts. No single entry point for all request types. No triage protocol. No ticket-first discipline. Morning standup serves as a lightweight daily review but doesn't function as a service desk. |
| **Gap** | No defined SPOC (Single Point of Contact). No triage rules. No ticket-first mandate. No service desk SLA. When the 11 agents are active, "who handles what" becomes ambiguous without a desk function. |
| **Risk** | HIGH — Without a formal desk function, incidents and requests blur together. Work falls through gaps. Ken context-switches constantly instead of operating at CTO level. |
| **Recommendation** | 1. Formalise Yoda as "Service Desk lead" — all requests/incidents enter via TKT or Telegram (not raw chat). 2. Define triage protocol: severity assessment → assignment → acknowledgement SLO. 3. "Ticket first" rule: nothing gets worked unless a TKT exists (emergencies excepted, retrospective ticket within 1h). 4. Yoda produces daily desk report (open tickets, ageing, SLA breach risk). |
| **Priority** | **CRITICAL** |
| **Current Maturity** | Level 1 |
| **Target Maturity** | Level 3 |

---

### 3.6 Configuration Management (CMDB)

**ITIL 4 Definition:** Ensure that accurate and reliable information about the configuration of services, and the CIs that support them, is available when and where it is needed.

| Dimension | Detail |
|-----------|--------|
| **Current State** | Asset Registry: 53 assets, Notion DB, weekly review, quarterly audit, `asset-review.sh`. Critical Config Baseline: 7 guarded configs, anti-drift, auto-heal Check #12. Scripts and docs tracked in git. |
| **Gap** | Asset registry ≠ CMDB. A CMDB captures relationships between CIs (Config Items) — not just a list. We don't model: "this script depends on this config, which depends on this secret, deployed to this host." No CI relationship graph. No CI types standardised. No CMDB-to-change linkage (changes don't reference affected CIs formally). |
| **Risk** | MEDIUM — At 53 assets and growing, lack of relationship modelling means a change to one CI has unknown blast radius. This will cause surprise incidents. |
| **Recommendation** | 1. Extend Asset Registry to be a proper CMDB: add CI Type, CI Relationships, Dependent Services, and Owner fields. 2. Define 6 CI types: Host, Service, Script, Config, Secret, Agent. 3. Link CHG tickets to affected CIs. 4. Add "blast radius check" to pre-risky-op rule: query CMDB for dependents before executing. |
| **Priority** | **HIGH** |
| **Current Maturity** | Level 2 |
| **Target Maturity** | Level 3 |

---

### 3.7 Service Level Management

**ITIL 4 Definition:** Set clear business-based targets for service levels, and ensure that delivery of services is properly assessed, monitored, and managed against these targets.

| Dimension | Detail |
|-----------|--------|
| **Current State** | No SLOs defined. No SLAs (internal or client-facing). No OLAs. Health check runs every 15 min but there's no uptime target it's checking against. MTTR is tracked but has no target to compare against. |
| **Gap** | Complete absence of service level targets. We measure (health, MTTR, cost) but have nothing to measure against. This is one of the most critical gaps for a company about to onboard clients. |
| **Risk** | CRITICAL — Without SLOs, we can't know if we're performing acceptably. Without client SLAs, we have no contractual protection or clarity. This will become a client relationship liability within weeks. |
| **Recommendation** | 1. Define internal SLOs immediately: Platform availability ≥99.5%, P1 response ≤15 min, P2 ≤1h, P3 ≤4h, P4 ≤24h. 2. Create SLA template for clients (availability, response times, escalation). 3. Build SLO tracking in Notion: actual vs target, weekly review. 4. Add SLA breach alert to health-check pipeline. |
| **Priority** | **CRITICAL** |
| **Current Maturity** | Level 0 |
| **Target Maturity** | Level 4 |

---

### 3.8 Availability Management

**ITIL 4 Definition:** Ensure that services deliver agreed levels of availability to meet the needs of customers and users.

| Dimension | Detail |
|-----------|--------|
| **Current State** | Health check every 15 min — gateway/ollama/disk. Alert at 3 failures. Auto-heal for safe fixes. OfflinePlaybook.md for degraded-mode ops. Backup daily. No uptime tracking/reporting. |
| **Gap** | No uptime percentage calculated or reported. No availability targets. No planned maintenance windows documented. No formal availability report. Health check detects failures but doesn't compute availability over time. |
| **Risk** | MEDIUM — We're monitoring availability but not measuring it. Can't report availability to clients or Ken without tracking. |
| **Recommendation** | 1. Add uptime logging to health-check.sh: stamp each check result, compute % available over 24h/7d/30d. 2. Add availability dashboard in Notion (or simple state/uptime-log.json). 3. Define maintenance window policy (e.g., Sundays 02:00–04:00 AEST for planned work). 4. Monthly availability report auto-generated by Yoda. |
| **Priority** | **MEDIUM** |
| **Current Maturity** | Level 2 |
| **Target Maturity** | Level 3 |

---

### 3.9 Capacity & Performance Management

**ITIL 4 Definition:** Ensure that services achieve agreed and expected performance, satisfying current and future demand in a cost-effective way.

| Dimension | Detail |
|-----------|--------|
| **Current State** | Cost tracking (state/cost-state.json, daily history, 75%/10% alerts). Model strategy (Sonnet default, Opus only for high-stakes). Disk check in health monitoring. No CPU/RAM/throughput tracking. No capacity planning for agent scale-out. |
| **Gap** | Cost management exists but capacity management is absent. We don't track: CPU/RAM utilisation, API rate limit headroom, Ollama inference throughput, model latency trends, or projected capacity needs as we scale from 1 to 12 agents. |
| **Risk** | HIGH — Scaling from 1 to 12 agents without capacity data is flying blind. We may hit API rate limits, disk limits, or Ollama throughput walls mid-operation with no warning. |
| **Recommendation** | 1. Add system resource snapshot to nightly close: CPU%, RAM%, disk%, API usage% vs limit. 2. Define capacity thresholds: disk >80% = alert, RAM >85% = alert, API usage >70% = alert. 3. Quarterly capacity review: project 90-day resource needs based on agent scale plan. 4. Add Ollama inference time tracking to health check. |
| **Priority** | **HIGH** |
| **Current Maturity** | Level 1 |
| **Target Maturity** | Level 3 |

---

### 3.10 Knowledge Management

**ITIL 4 Definition:** Maintain and improve the effective, efficient, and convenient use of information and knowledge across the organisation.

| Dimension | Detail |
|-----------|--------|
| **Current State** | Obsidian vault (~/Documents/AInchors, git-backed, structured sections). Operations docs (13 files in Operations/). Daily journal + blog. Standards.md, Compliance.md. Run-diagnostics becomes OC2 runbook. Morning standup provides daily knowledge transfer. |
| **Gap** | No unified knowledge base index or search. Obsidian and Operations/ are parallel stores — not integrated. No "known error" knowledge (see Problem Management). Knowledge lives in docs but isn't linked to incidents, changes, or tickets. No knowledge article lifecycle (draft → review → approved → retired). No agent-accessible knowledge API. |
| **Risk** | MEDIUM — As agents multiply, they need structured access to operational knowledge. Scattered docs without index or lifecycle become tribal knowledge that only Yoda holds. |
| **Recommendation** | 1. Create a Knowledge Base Index (Notion DB or Obsidian MOC) linking all operational docs to their ITIL practice area. 2. Define article lifecycle: Draft → Peer Review → Approved → Active → Retired. 3. Link KB articles to incident/problem records (e.g., "INC-005 resolved using KB-012"). 4. Create "Onboarding KB" for each new agent type. 5. Weekly: Yoda reviews and updates stale articles. |
| **Priority** | **MEDIUM** |
| **Current Maturity** | Level 2 |
| **Target Maturity** | Level 3 |

---

### 3.11 Event Management

**ITIL 4 Definition:** Systematically observe services and service components, and record and report selected changes of state identified as events.

| Dimension | Detail |
|-----------|--------|
| **Current State** | Health check detects discrete failure states. Telegram alerts on 3+ failures. Auto-heal triggers on specific event types. CHANGELOG events captured. Nightly cost alerts. |
| **Gap** | No formal event taxonomy (Informational / Warning / Exception). Events are binary (pass/fail) rather than graduated. No event correlation across sources (health + cost + incident together). No event suppression rules (avoid alert storms). No event-to-incident auto-promotion rules beyond health check. |
| **Risk** | MEDIUM — As we add 11 agents each generating events, without taxonomy and correlation we'll have alert fatigue or, worse, missed critical events buried in noise. |
| **Recommendation** | 1. Define event taxonomy: INFO (logged, no action), WARNING (logged, Yoda reviews), EXCEPTION (logged, ticket raised, alert sent). 2. Add event classification to health-check.sh output. 3. Implement event correlation: health + cost + incident events should cross-reference. 4. Add suppression logic: if same alert fires 5x in 10 min, suppress repeats and escalate once. |
| **Priority** | **MEDIUM** |
| **Current Maturity** | Level 2 |
| **Target Maturity** | Level 3 |

---

### 3.12 Monitoring & Event Management

**ITIL 4 Definition:** Systematically observe services and service components, and record and report selected changes of state identified as events. (Monitoring is the enabling discipline; Event Management is the response framework.)

| Dimension | Detail |
|-----------|--------|
| **Current State** | Health-check.sh every 15 min (gateway, ollama, disk). Nightly auto-heal checks 12 items. Cost alerts (75%/10% thresholds). Git for config drift detection. Telegram as alert channel. |
| **Gap** | Monitoring is point-in-time (pass/fail at 15-min intervals). No continuous metric collection. No dashboards. No trend visibility. No monitoring of agent performance (token usage per agent, task completion rate, error rate). Single alert channel (Telegram) with no severity routing. |
| **Risk** | HIGH — Without trend data, we're reactive. A gradual degradation (e.g., disk filling over 3 days, API costs creeping up) won't alert until threshold is breached, by which point options are limited. |
| **Recommendation** | 1. Add metric time-series logging: health check writes to state/metrics.json (timestamped readings, not just pass/fail). 2. Add agent performance monitoring: per-agent task count, token spend, error rate. 3. Consider lightweight dashboard: Notion or simple HTML generated by Yoda daily. 4. Route alerts by severity: P1/P2 → Telegram + sound, P3/P4 → Notion ticket only. |
| **Priority** | **HIGH** |
| **Current Maturity** | Level 2 |
| **Target Maturity** | Level 3 |

---

### 3.13 Continual Improvement

**ITIL 4 Definition:** Align the organisation's practices and services with changing business needs through the ongoing identification and improvement of services, service components, practices, or any element involved in the efficient and effective management of products and services.

| Dimension | Detail |
|-----------|--------|
| **Current State** | Daily journal captures operational learning. Auto-heal files Notion US for items needing Ken. ROI tracker. Retrospective notes in journal. No formal CI register. No improvement cadence beyond "when we notice something." |
| **Gap** | No Continual Improvement Register (CIR). Improvements are raised ad-hoc and sometimes lost. No structured retrospective cadence (weekly/monthly/quarterly). No improvement prioritisation method. No measurement of improvement outcomes. |
| **Risk** | MEDIUM — Good ideas get raised in journal and forgotten. Without a CIR and cadence, the improvement loop is open — we raise, we don't close. |
| **Recommendation** | 1. Create Continual Improvement Register in Notion: ID, description, raised date, owner, status, outcome. 2. Weekly Friday CI review (15 min): Yoda pulls all CIR items, Ken prioritises top 3 for next week. 3. Monthly CI retrospective: what improved, what didn't, what to retire. 4. Tie CI register to incident/problem data: recurring issues automatically raise a CI item. |
| **Priority** | **MEDIUM** |
| **Current Maturity** | Level 1 |
| **Target Maturity** | Level 3 |

---

### 3.14 Release Management

**ITIL 4 Definition:** Make new and changed services and features available for use.

| Dimension | Detail |
|-----------|--------|
| **Current State** | PVT (9/9 checks) post-change. Pre-risky-op checkpoint rule. CHANGELOG.md. Git commits. No formal release pipeline. No release notes. No staging environment. No release schedule/calendar. |
| **Gap** | PVT validates after deployment but there's no formal release process before deployment. No release candidate concept. No staging/test environment (deploy straight to production). No release notes template. No release communication plan. |
| **Risk** | MEDIUM — "Deploy straight to prod + PVT to validate" works at Day 3 scale. At Day 30 with 11 agents and client workloads running, a bad release has real blast radius. |
| **Recommendation** | 1. Define release types: Hotfix (immediate), Standard (planned, CHG ticket), Major (scheduled, Ken sign-off, maintenance window). 2. Create release notes template (what changed, impact, rollback procedure). 3. Add "pre-release checklist" to pre-risky-op rule. 4. Maintain release calendar in Notion. 5. Longer term: explore local staging environment (Docker-based). |
| **Priority** | **MEDIUM** |
| **Current Maturity** | Level 1 |
| **Target Maturity** | Level 3 |

---

### 3.15 IT Asset Management

**ITIL 4 Definition:** Plan and manage the full lifecycle of all IT assets, to help the organisation maximise value, control costs, manage risks, ensure regulatory compliance, and support decision-making.

| Dimension | Detail |
|-----------|--------|
| **Current State** | Asset Registry: 53 assets, Notion DB, weekly review, quarterly audit, `asset-review.sh`. Asset types include scripts, configs, agents, services. Git-backed. |
| **Gap** | No asset lifecycle stages (Ordered/Active/Maintenance/Retired). No licence management for SaaS tools/APIs. No software cost-per-asset tracking beyond aggregate cost tracking. No end-of-life alerts. No asset disposal procedure. |
| **Risk** | LOW-MEDIUM — At 53 assets and growing, lack of lifecycle management means zombie assets accumulate. API keys for unused services stay active = cost leakage and security risk. |
| **Recommendation** | 1. Add lifecycle stage field to Asset Registry: Planned/Active/Deprecated/Retired. 2. Add licence/cost field for each SaaS/API asset. 3. Weekly asset-review.sh should flag assets in "Deprecated" state >30 days for retirement decision. 4. Add asset disposal procedure to SecretsManagement.md (revoke keys, archive config, update registry). |
| **Priority** | **LOW** |
| **Current Maturity** | Level 2 |
| **Target Maturity** | Level 3 |

---

## 4. Summary Gap Table

| ITIL 4 Practice | Current Maturity | Target Maturity | Gap Size | Priority |
|-----------------|-----------------|-----------------|----------|----------|
| Incident Management | 2 – Managed | 4 – Quantitatively Managed | Medium | HIGH |
| Problem Management | 1 – Initial | 3 – Defined | Large | HIGH |
| Change Enablement | 2 – Managed | 3 – Defined | Small | MEDIUM |
| Service Request Management | 0 – Absent | 3 – Defined | Large | CRITICAL |
| Service Desk | 1 – Initial | 3 – Defined | Large | CRITICAL |
| Configuration Management (CMDB) | 2 – Managed | 3 – Defined | Medium | HIGH |
| Service Level Management | 0 – Absent | 4 – Quantitatively Managed | Very Large | CRITICAL |
| Availability Management | 2 – Managed | 3 – Defined | Small | MEDIUM |
| Capacity & Performance Management | 1 – Initial | 3 – Defined | Large | HIGH |
| Knowledge Management | 2 – Managed | 3 – Defined | Medium | MEDIUM |
| Event Management | 2 – Managed | 3 – Defined | Medium | MEDIUM |
| Monitoring & Event Management | 2 – Managed | 3 – Defined | Medium | HIGH |
| Continual Improvement | 1 – Initial | 3 – Defined | Large | MEDIUM |
| Release Management | 1 – Initial | 3 – Defined | Large | MEDIUM |
| IT Asset Management | 2 – Managed | 3 – Defined | Small | LOW |

**Overall framework maturity:** 1.6 / 5.0 average  
**Target in 60 days:** 3.0 / 5.0 average  
**Critical gaps (0 maturity):** Service Request Management, Service Level Management

---

## 5. What We Have That EXCEEDS Standard ITIL Baseline

This section is important. Most ITIL implementations at Day 3 have nothing. We have a surprising amount. Here's where AInchors is already ahead:

### 5.1 Auto-Healing Ops (Beyond Standard Incident Management)
Standard ITIL expects humans to resolve incidents. Our auto-heal.sh resolves 12 categories of issues autonomously, 24/7, with automatic Notion US filing for human-required items. This is ITIL Level 4+ behaviour in incident automation — something most enterprises take years to build.

### 5.2 Pre-Risky-Op Checkpoint Protocol
Standard change management requires a form + approval. Our protocol requires: context flush, dependency clean, git commit, explicit Ken confirmation, execution, and PVT validation. This is more rigorous than many enterprise CAB processes, and it's enforced culturally, not by a ticketing system.

### 5.3 Structured Operational Knowledge from Day 3
Thirteen operations docs, a structured Obsidian vault, daily journal + blog, and a morning standup brief. ITIL Knowledge Management typically takes 6–12 months to establish as a practice. We have a working foundation now.

### 5.4 Cost Visibility + AI Model Governance
Cost-state.json, daily history, balance alerts, and a model strategy (Sonnet default, Opus only for high-stakes). This is Capacity & Performance Management applied to AI operations — there's no standard ITIL practice for this. We're inventing the playbook.

### 5.5 Platform Validation Test (PVT)
A 9-check automated validation suite run after every risky operation. Standard ITIL Release Management suggests testing; most small orgs skip it. We've made it mandatory and automated. This is defence-in-depth that most mid-size companies don't have.

### 5.6 Async Execution Model with Watchdog
TASK files, checkpoints, watchdog cron, and resume protocol for long-running agent tasks. This is operational resilience for AI workloads — not covered by ITIL 4 at all. We're leading practice, not following it.

### 5.7 Dual-Path Backup with 30-Day Retention
Git + tar, two daily runs, 30-day retention, `backup.sh`. Standard ITIL Availability Management recommends backup — having dual-path automation from Day 3 with tested recovery paths is ahead of most startups.

---

## 6. Top 10 Priority Recommendations (Ordered)

| Rank | Recommendation | Practice Area | Effort | Impact |
|------|---------------|---------------|--------|--------|
| 1 | **Define SLOs immediately** — Platform availability ≥99.5%, P1 ≤15 min response, P2 ≤1h, P3 ≤4h, P4 ≤24h. Without targets, all metrics are decorative. | Service Level Management | S | CRITICAL |
| 2 | **Implement "Ticket First" rule + formalise Service Desk** — Nothing gets worked without a TKT. Yoda is the desk lead. Triage protocol documented. | Service Desk | S | CRITICAL |
| 3 | **Build Service Catalogue** — 15–20 named services Yoda/agents can fulfil, each with an SLO. This enables Service Request Management to exist. | Service Request Management | M | CRITICAL |
| 4 | **Add incident severity tiers (P1–P4)** to incident-log.sh + auto-heal — Response/resolution SLOs per tier, PIR trigger for P1/P2. | Incident Management | S | HIGH |
| 5 | **Create Problem Management workflow** — PRB ticket type, 2-in-30-days rule triggers PRB, KEDB in Notion. | Problem Management | M | HIGH |
| 6 | **Extend Asset Registry to CMDB** — Add CI relationships, types, and blast-radius check to pre-risky-op rule. | Configuration Management | M | HIGH |
| 7 | **Add metric time-series logging** to health-check.sh — State/metrics.json with timestamped readings, trend-based alerting. | Monitoring & Event Management | S | HIGH |
| 8 | **Define Continual Improvement Register** in Notion — CI item type, weekly Friday review, automated CI items from recurring incidents. | Continual Improvement | S | MEDIUM |
| 9 | **Add system resource capacity tracking** to nightly close — CPU%, RAM%, disk%, API usage %. Thresholds + alerts. | Capacity & Performance Management | S | HIGH |
| 10 | **Formalise release types** (Hotfix/Standard/Major) + release notes template — Release calendar in Notion. | Release Management | S | MEDIUM |

---

## 7. Migration Principles

How to align what we have without breaking what works:

### Principle 1: Preserve, Don't Replace
Every existing script, doc, and database is a sunk investment that works. The goal is to plug gaps and add structure around existing artefacts — not rebuild them. `incident-log.sh` doesn't need rewriting; it needs severity fields added.

### Principle 2: Notion as ITSM Tool of Record
We've already committed to Notion. Don't introduce a second ITSM tool (Jira, ServiceNow, Zendesk) — that's enterprise bloat for a 1-person startup. Extend Notion DBs to cover ITIL requirements. When TKT system lands, integrate it with Notion rather than replacing it.

### Principle 3: Right-Size Every Practice
ITIL for a 1-person+AI shop looks different from ITIL for a 500-person enterprise. A "CAB" is Ken. A "service desk" is Yoda. A "problem review board" is a weekly Yoda-generated report. Don't over-formalise what's working informally.

### Principle 4: Automate Before Documenting
If a process isn't automated, it won't be followed consistently. Before writing a procedure document, ask: "Can Yoda/a script do this?" If yes, automate first, document the automation second. This is especially true for SLO measurement, CI register updates, and availability reporting.

### Principle 5: One New Practice per Week
Don't try to close all gaps at once. Prioritise by risk (see §6). Week 1: SLOs + Ticket First. Week 2: Service Catalogue + Problem Management. Week 3: CMDB extensions + monitoring improvements. Each week adds one solid, tested practice — not a half-baked set of five.

### Principle 6: TKT System is the Integration Hub
The TKT-NNNN system being built now is the single thread connecting Incident, Problem, Change, Service Request, and Service Desk. Every improvement in §6 should wait for or integrate with TKT. Don't build interim workarounds that TKT will replace.

### Principle 7: Measure What You Commit To
Once SLOs are defined, measure them weekly. Once a CI register exists, report on CI completion monthly. The worst outcome is defining targets and then not tracking against them — that's worse than no targets at all.

---

*End of ITIL Gap Analysis v1.0*  
*Next: See itsm-epic-plan.md for EPIC-001 full user story breakdown.*
