# TKT-0089 — Backlog Replan: Atlas EA Roadmap + Section 10 Decisions
**Produced:** 2026-05-07 | **Author:** Yoda 🟢 | **Source inputs:** TKT-0086 Atlas EA Roadmap, TKT-0088 Section 10 decisions, TKT-0087 groom, AInchors OKR 2026-05, IT Strategy 2026-05
**P2 Target:** End August 2026 | **Incorporation Gate:** End May 2026

---

## Key Constraints (Decision Memo)

| # | Decision | Impact |
|---|----------|--------|
| D1 | P2 target = **end August 2026** | All critical-path items must close by 31 Aug |
| D2 | FinOps: BYOK = track+report only; default = Ollama Cloud only | TKT-0092 scope adjusted accordingly |
| D3 | **Auralith incorporation: end May 2026** — HARD GATE before client data | TKT-0060/0061/0063 locked to end-May |
| D4 | TKT-0060/0061/0062/0063 deferred → revisit end-May | Sprint 2 must-do |
| D5 | Managed tenant timing conflict → TKT-0091 groom required | Must resolve before P2 |
| D6 | Ahsoka Charter registration → DONE (CHG-0218) | No action needed |
| D7 | Nexus-first in RULES.md + Charter → DONE (CHG-0218) | No action needed |
| D8 | Ken = sole Tier 3 approver until P2 | Governance applies to all Ahsoka outputs |

---

## Section A — Full Backlog Assessment

| ID | Title | Current Priority | Status | Assessment | New Classification | OKR Link |
|----|-------|-----------------|--------|------------|--------------------|----------|
| **EPIC / STRATEGY SEQUENCE** |
| TKT-0086 | Strategy coherence, governance gap analysis, Atlas EA roadmap + replan | High | Open | Parent epic. Steps 1-3 complete; Steps 4-5 in progress. | SPRINT NOW | X2-KR1 |
| TKT-0087 | Strategy & Governance Alignment — resolve conflicts/gaps | High | Open | TKT-0087 ACs in progress. P0 ACs must complete before Ahsoka live. | SPRINT NOW | G1, X2-KR1 |
| TKT-0088 | Atlas EA roadmap review + Section 10 decisions | High | Open | Decisions captured. Complete when decisions committed to Holocron. | SPRINT NOW | X2-KR1 |
| TKT-0089 | Backlog replan against Atlas EA roadmap | High | Open | This document. | SPRINT NOW | X2-KR1, X2-KR2 |
| TKT-0090 | Agile framework lock — QBR cadence, epic scope, sprint definition | High | Open | Sprint 5 in the current sequence. Must follow replan. | SPRINT NOW | X2-KR1 |
| **AHSOKA / CONSULTING** |
| TKT-0082 | Ahsoka Pilot Case 1 — AInchors internal AI transformation | High | In Progress | Active now. Reference case before external clients. CRITICAL path for P1→P2. | SPRINT NOW — CRITICAL PATH | S1-KR1, S1-KR2, S2-KR1 |
| TKT-0083 | Ahsoka Pilot Case 2 — ASM (external) | High | Backlog | Blocked on Pilot 1 completion. Auralith incorporation hard gate also applies (D3). | SPRINT SOON | S1-KR2, C1-KR2 |
| [TKT-0087] Doc gen pipeline | Document generation pipeline (DOCX/XLSX/PPTX/PDF) — Ahsoka Q1 blocker | Critical | Backlog | **Atlas Q1 Must-Do #1. Ahsoka cannot produce proposals without this.** Mislabeled TKT-ID (conflicts with TKT-0087 governance). Recommend renaming to TKT-0095. | SPRINT NOW — CRITICAL PATH | S1-KR2, S2-KR1 |
| TKT-0069 | Vision & Mission — Nexus VMS | High | In Progress | VMS complete. Needs Ken review + Holocron commit. | SPRINT NOW | X2-KR1 |
| TKT-0091 | D5 Managed Tenant Groom — Atlas A1 vs VMS timing conflict | High | Open | Must resolve before P2 go-live. Section 10 D5 decision. | SPRINT SOON | X2-KR1 |
| **FINOPS / COST** |
| TKT-0092 *(new)* | FinOps Q1: Per-agent token budget limits + per-workflow cost caps | Critical | Open | **Atlas Q1 Must-Do #2. R3 (cost multiplier) live risk. No client work without this.** | SPRINT NOW — CRITICAL PATH | X1, G1 |
| TKT-0028 / US38 | Cost tracker — scan all agents, breakdown by stream | High | Backlog | 30-min fix. Foundation for TKT-0092. Do first. | SPRINT NOW | X1 |
| TKT-0041 / US-FinOps | Deepen ROI data and FinOps /finops report | High | Backlog | Builds on US38. Sprint 2 logical sequence. | SPRINT SOON | X1 |
| TKT-0079 | Holocron — Cost & Billing Page | Medium | Backlog | FinOps visibility. Sprint 2 with other Holocron pages. | SPRINT SOON | X1 |
| **INFRASTRUCTURE / OC2 / BACKUP** |
| TKT-0093 *(new)* | NAS encryption + 3-2-1+1 backup strategy (S7 completion) | Critical | Open | **Atlas Q1 Must-Do #3+#4. S7 security gap. Pre-OC2 blocker.** | SPRINT NOW — CRITICAL PATH | X1-KR1, X1-KR4, G1-KR3 |
| TKT-0094 *(new)* | OC2 deployment playbook in Holocron (TRIGGER-01 pre-documentation) | High | Open | **Atlas Q1 Must-Do #5. OC2 arrives July 2026. Must document before arrival.** | SPRINT SOON | X1-KR4 |
| US19 | HA Design Exploration — OC1/OC2 redundancy, failover | High | Backlog | Design work can start now (feeds TKT-0094 playbook). OC2 dependent for execution. | SPRINT SOON | X1-KR4 |
| US34 | OC2 — Revisit Gemma4:26b delegation across agents | Medium | Backlog | Explicitly blocked until OC2 arrives July 2026. | PARK — Blocked (OC2) | X1-KR4 |
| TKT-0080 | Holocron — Infrastructure (HIVE) Current-State Ops Page | Medium | Backlog | Useful reference but not blocking. Sprint 2 with other Holocron work. | SPRINT SOON | X1-KR4 |
| **GOVERNANCE / SECURITY / COMPLIANCE** |
| TKT-0032 | P1 POLICY: Governance + ITIL enforcement across all agents | Critical | Backlog | Ken directive — non-negotiable. TKT-0087 covers most of scope but this is broader Warden enforcement. | SPRINT NOW — CRITICAL PATH | G1 |
| TKT-0075 | Audit Log Architecture — Beacon v2 (unified audit spine) | High | Backlog | **P2 blocker per own description.** Structured trace ID, tool-call logging, policy event log. | CRITICAL PATH — Sprint 2 | G1-KR1, X1-KR3 |
| TKT-0077 | Persistent Agent Configuration — stateless bootstrap + Shield/Lex/Sage dirs | High | Backlog | Foundation for governance baseline. Needed for TKT-0087 AC-3. | SPRINT NOW | G1 |
| TKT-0076 | AI Governance Framework v1.1 (S4, HITL thresholds, gateway PII) | Medium | Backlog | Lex review required. Sprint 2 after TKT-0087 P0/P1 ACs. | SPRINT SOON | G1-KR1 |
| TKT-0070 | AI Policies — Define AI Policies, Processes, Procedures & Controls | High | Backlog | Sequence 2/4. TKT-0071 superseded by TKT-0086, but policies still needed for P2 compliance. | SPRINT SOON | G1, X2-KR1 |
| TKT-0081 | Holocron — Security Posture Page (S1-S7) | Medium | Backlog | Ops visibility. Sprint 2 with other Holocron work. | SPRINT SOON | G1-KR3 |
| TKT-0043 | Deep review of governance triad scope, skills, rules | Medium | Backlog | TKT-0087 partially covers this. Remaining scope: hardening for production. Sprint 3. | SPRINT SOON | G1 |
| **AURALITH INCORPORATION (end-May GATE)** |
| TKT-0060 | Client DPA | (Deferred D4) | Backlog | **Must complete before P2. Revisit end-May. Incorporation gate hard dependency.** | CRITICAL PATH — Sprint 2 | G1-KR3, C1-KR3 |
| TKT-0061 | Warden escalation thresholds | (Deferred D4) | Backlog | **Must complete before P2. Revisit end-May.** | CRITICAL PATH — Sprint 2 | G1, X1-KR3 |
| TKT-0062 | S4 tool scope | (Deferred D4) | Backlog | **Must complete before P2. Revisit end-May.** | CRITICAL PATH — Sprint 2 | G1 |
| TKT-0063 | Ollama Cloud DPA exclusion | (Deferred D4) | Backlog | **Must complete before P2. Revisit end-May.** | CRITICAL PATH — Sprint 2 | G1-KR3 |
| **PLATFORM / OBSERVABILITY / RELIABILITY** |
| TKT-0025 / US40 | Observability sub-agent — SQLite obs.db | High | Backlog | Foundational for X1-KR3. Required before P2 client work. | SPRINT NOW | X1-KR3 |
| TKT-0026 / US41 | Task monitoring sub-agent — cross-agent task tracker | High | Backlog | Pairs with US40. Sprint 2 logical sequence. | SPRINT SOON | X1-KR3 |
| ITSM-US-004 | SLO measurement and weekly reporting | Critical | Backlog | OKR X1-KR3 requires this. Foundation metric. | SPRINT NOW | X1-KR3 |
| QW-4 | Add uptime logging to health-check.sh | Medium | Backlog | Quick win. Feeds ITSM-US-004. Do first. | SPRINT NOW | X1-KR3 |
| US39 | Preventable downtime enforcement — automated pre-risky-op gate | Medium | Backlog | Addresses 85% preventable downtime finding. Sprint 2. | SPRINT SOON | X1-KR1, X1-KR3 |
| US44 | generate-standup-brief.sh — Tier 0 pre-computation | Medium | Backlog | Cost + speed win. Quick implementation. Sprint 2. | SPRINT SOON | X1 |
| US32 | Session recovery after gateway restart | Medium | Backlog | Reliability. Sprint 2 or 3. | SPRINT SOON | X1-KR1 |
| TKT-0044 | Disaster Recovery strategy — multi-level outage playbooks | High | Backlog | Critical for P2. Pairs with TKT-0093 backup work. Sprint 2. | SPRINT SOON | X1-KR1 |
| US36 | AInchors Hub — real-time data feeds replacing snapshots | High | Backlog | Architecture design needed; OC2 dependent for real-time. Design sprint 3, build post-OC2. | PARK — Design only | X1-KR4 |
| TKT-0046 | EPIC-NEXUS: AInchors Portal (Citadel v1 design) | High | Backlog | Citadel is Q3 work per Atlas roadmap. Design concept only in Q1. | PARK — Q3 | X1-KR2 |
| TKT-0037 | Warden per-agent model gating — real-time routing enforcement | Medium | Backlog | Post-OC2 when model routing is first-class infra. | PARK — Post OC2 | G1-KR3 |
| **ITSM FOUNDATION** |
| ITSM-US-008 | Define and publish AInchors Service Catalogue (v1) | Critical | Backlog | Phase 2 critical. Client onboarding prerequisite. Sprint 2. | SPRINT SOON | C1-KR3 |
| ITSM-US-013 | Define three change types + formalise change management | Medium | Backlog | Phase 2. Good governance foundation. Sprint 2. | SPRINT SOON | G1-KR1 |
| ITSM-MIG-006 / ITSM-US-032 | Client-facing SLA template | High | Backlog | P2 prerequisite. Sprint 2. | SPRINT SOON | C1-KR3 |
| ITSM-US-011 | Extend Asset Registry to CMDB with CI relationships | High | Backlog | Phase 2. Sprint 2-3. | SPRINT SOON | X1-KR3 |
| ITSM-US-012 | CMDB blast radius check in pre-risky-op | High | Backlog | Depends on ITSM-US-011. Sprint 3. | SPRINT SOON | G1-KR1 |
| ITSM-US-009 | Service request intake and fulfilment workflow | High | Backlog | Phase 2. Sprint 3. | SPRINT SOON | G1-KR1 |
| ITSM-US-010 | Problem Management (PRB tickets + KEDB) | High | Backlog | Phase 2. Sprint 3. | SPRINT SOON | G1-KR1 |
| ITSM-US-028 / ITSM-MIG-002 | Complete Notion Change Log DB | Medium | Backlog | Phase 1 migration. ITSM-MIG-002 is duplicate — close one. Sprint 3. | SPRINT SOON (ITSM-US-028); CLOSE (ITSM-MIG-002 — duplicate) | G1 |
| ITSM-US-014 | Create Continual Improvement Register (CIR) in Notion | Medium | Backlog | Phase 2. Sprint 3. | SPRINT SOON | G1-KR1 |
| ITSM-US-029 / ITSM-MIG-003 | Classify 53 assets with CI type + relationships | High | Backlog | ITSM-MIG-003 is duplicate of ITSM-US-029. Close one. Sprint 3. | SPRINT SOON (ITSM-US-029); CLOSE (ITSM-MIG-003 — duplicate) | X1-KR3 |
| ITSM-US-031 | Migrate auto-heal Notion US to CIR | Medium | Backlog | Depends on ITSM-US-014. Sprint 3. | SPRINT SOON | G1 |
| QW-5 | Create CI Register Notion DB | Medium | Backlog | Quick win. Feeds ITSM-US-014. Sprint 2. | SPRINT SOON | G1-KR1 |
| QW-6 | Add change type to pre-risky-op rule | Medium | Backlog | Quick win. Feeds ITSM-US-013. Sprint 2. | SPRINT SOON | G1 |
| QW-7 | Tag all 13 Operations docs with ITIL practice header | Low | Backlog | Quick win. Sprint 2-3. | SPRINT SOON | G1 |
| QW-8 | File PRB-001 — first Problem record | Medium | Backlog | Quick win. Feeds ITSM-US-010. Sprint 2. | SPRINT SOON | G1-KR1 |
| ITSM-US-015 | Timestamped metric logging to health-check | High | Backlog | Phase 3 foundation. Sprint 3. | SPRINT SOON | X1-KR3 |
| ITSM-US-016 | System resource capacity monitoring | High | Backlog | Phase 3. Sprint 3. | SPRINT SOON | X1-KR3 |
| ITSM-US-017 | Per-agent performance tracking | Medium | Backlog | Phase 3. Sprint 3. | SPRINT SOON | X1-KR3 |
| ITSM-US-025 | Build ITSM Framework health dashboard | Medium | Backlog | Phase 4. Sprint 3-4. | SPRINT SOON | X1-KR3 |
| ITSM-US-021 | INFO/WARNING/EXCEPTION event taxonomy | Medium | Backlog | Phase 4. Sprint 3-4. | SPRINT SOON | X1-KR3 |
| ITSM-US-024 | Weekly CI review cadence | Medium | Backlog | Phase 4. Ops cadence. Sprint 3. | SPRINT SOON | G1-KR1 |
| ITSM-US-004 | SLO measurement and weekly reporting | Critical | Backlog | Already listed above. | SPRINT NOW | X1-KR3 |
| ITSM-US-019 | KB index with article lifecycle | Medium | Backlog | Phase 3. Low priority now. | PARK | G1 |
| ITSM-US-020 | Maintenance window policy | Low | Backlog | Phase 3. Low urgency. | PARK | G1 |
| ITSM-US-022 | Release types and release notes template | Medium | Backlog | Phase 4. | PARK | G1 |
| ITSM-US-023 | Release calendar and communication workflow | Low | Backlog | Phase 4. | PARK | G1 |
| ITSM-US-026 | ITSM retrospective at Phase 4 | Medium | Backlog | Phase 4 end. | PARK | G1 |
| ITSM-US-030 | Register Ops docs in KB Index | Medium | Backlog | Phase 3 migration. | PARK | G1 |
| **AGENT TEAM / ARCHITECTURE** |
| TKT-0077 | Persistent Agent Configuration — Shield/Lex/Sage dirs | High | Backlog | Already listed above. | SPRINT NOW | G1 |
| TKT-0078 | Holocron Comprehensive Audit & Update | High | Backlog | One-off audit. Sprint 2. | SPRINT SOON | X2-KR2 |
| TKT-0053 | Data and Memory Architecture — extending Holocron | Medium | Backlog | Atlas Q1 should-do: Holocron API + data architecture. Sprint 3. | SPRINT SOON | X2-KR1 |
| US-AgentTeam | AInchors Agent Team — design and build remaining agents | High | Backlog | Depends on OC2 for local model options. Sprint 3. | SPRINT SOON | X1-KR4 |
| TKT-0068 | Agent Team Design & Build | High | Backlog | Duplicate scope with above US. | CLOSE (covered by US-AgentTeam above) | X1-KR4 |
| TKT-0051 | Architecture Assurance Agent | Medium | Backlog | P2 feature. Design in Sprint 3, build post-OC2. | PARK — P2 | X2-KR1 |
| TKT-0072 | BPM Agent (Lando) | Medium | Backlog | Depends on TKT-0071 (now covered by TKT-0086). Sprint 3-4. | SPRINT SOON | X2-KR1 |
| TKT-0071 | Nexus P1-P4 Roadmap (Sequence 3/4) | Critical | Backlog | **CLOSE — superseded by TKT-0086 Atlas EA roadmap (produced 2026-05-07).** | CLOSE — superseded | X2-KR1 |
| TKT-0085 | Sprint: Strategy & Governance Integration tie-together | High | Backlog | **CLOSE — this IS TKT-0089 (backlog replan). Same scope.** | CLOSE — superseded | X2-KR2 |
| **AUTO-HEAL / MAINTENANCE** |
| AUTO-HEAL: MEMORY.md oversized | MEMORY.md 15570 chars — trim or increase bootstrapMaxChars | Medium | Backlog | Quick maintenance fix. Do immediately. | SPRINT NOW | — |
| AUTO-HEAL: Sage model drift | Sage model = haiku, expected sonnet | High | Backlog | Model drift. Quick fix — confirm correct model per TRIGGER-12, update baseline. | SPRINT NOW | G1-KR3 |
| AUTO-HEAL: Shield model drift | Shield model = haiku, expected sonnet | High | Backlog | Same as Sage. Quick fix. | SPRINT NOW | G1-KR3 |
| AUTO-HEAL: Lex model drift | Lex model = haiku, expected sonnet | High | Backlog | Same as above. Quick fix. | SPRINT NOW | G1-KR3 |
| AUTO-HEAL: Cost tracker remainingEstimate | remainingEstimate=0 false alarm | Medium | Backlog | Quick bug fix in cost-tracker.sh. | SPRINT NOW | X1 |
| **CONTENT / BUSINESS STREAM** |
| TKT-0027 | Marketing collaterals for Angie — client/student pitch assets | High | Backlog | Business stream activation. Sprint 2 once Pilot 1 baseline exists. | SPRINT SOON | T1-KR3, C1-KR1 |
| TKT-0056 | Spark: LinkedIn Authority Pipeline Campaign | Medium | Backlog | Activate when campaign created. Sprint 2-3. | SPRINT SOON | T1-KR3 |
| US37 | Mission Control redesign — Kanban format | Medium | Backlog | Needs design session with Ken. Not urgent. | PARK — needs Ken design session | X1 |
| TKT-0084 | Formalise ITSM ticket taxonomy (US vs TKT vs CHG) | Medium | Backlog | Housekeeping. Sprint 3. | SPRINT SOON | G1 |
| TKT-0035 | Dedicated Content Agent | Medium | Backlog | Depends on TKT-0033 (not in backlog). Design only now; build when TKT-0033 done. | PARK — dependency missing | C1-KR1 |
| TKT-0055 | Spark: Instagram Growth Campaign | Medium | Backlog | Instagram PoC (Instagram US) not done. | PARK — blocked on Instagram PoC | C1-KR1 |
| TKT-0057 | Spark: Facebook Growth Campaign | Medium | Backlog | Facebook not connected. | PARK — blocked | C1-KR1 |
| TKT-0058 | Spark: YouTube Growth Campaign | Medium | Backlog | YouTube not connected. | PARK — blocked | C1-KR1 |
| TKT-0034 | Automated social posting | Low | Backlog | Social accounts not connected. | PARK — blocked | C1-KR1 |
| Instagram PoC | Instagram PoC — define US, plan, success criteria | High | Backlog | Prerequisite for TKT-0055/0057. No OKR linkage to P2 critical path. | PARK | C1-KR1 |
| Apply Meta API | Apply for Meta Developer API access | High | Backlog | Same as above. | PARK | C1-KR1 |
| US-BlogPost | Write Model Strategy Blog Post | Medium | Backlog | Wait for 30-day cost data. Sprint 3-4. | PARK | T1-KR3 |
| **PLATFORM IMPROVEMENTS** |
| TKT-0031 | Per-request latency tracking — model benchmarking | High | Backlog | Useful for model strategy decisions. Sprint 3. | SPRINT SOON | X1-KR3 |
| TKT-0048 | Developer sub-agent framework (containerised) | High | Backlog | OC2 dependent. P2 build. | PARK — OC2 required | X1-KR4 |
| TKT-0047 | Explore Fabric framework — feasibility | Medium | Backlog | Research item. No urgent OKR link. | PARK — research | — |
| US31 | Yoda-Aria context sync — increase frequency | Medium | Backlog | OC2 required for real-time bridge. | PARK — OC2 | — |
| **MISC** |
| US33 | Telegram voice message support for Aria | Low | Backlog | Nice-to-have. No P2 path. | PARK | — |
| Design OC2 (Angie instance) | Design and plan OC2 deployment (Angie instance) | Medium | Backlog | Angie instance is separate from OC2-A/B HIVE deployment. Needs scoping. Park until HIVE is stable. | PARK | — |

---

## Section B — New Items Raised

The following items were checked against the backlog and either found (existing) or newly raised:

| # | Item | Status | TKT ID | Notes |
|---|------|--------|--------|-------|
| 1 | Document generation pipeline (Ahsoka Q1 #1 blocker) | **EXISTS** — mislabeled | [TKT-0087] in Notion | Title in Notion references TKT-0087 which conflicts with the Strategy & Governance ticket. Recommend renaming Notion entry title to reference TKT-0095 and raising TKT-0095 properly. Item is tracked; classified as CRITICAL PATH Sprint 1. |
| 2 | Per-agent token budget limits + per-workflow cost caps (FinOps Q1) | **NEW — RAISED** | **TKT-0092** | Atlas Q1 Must-Do #2. BYOK caveat per D2. |
| 3 | NAS encryption + 3-2-1+1 backup strategy (S7, Q1) | **NEW — RAISED** | **TKT-0093** | Combines S7 closure + backup hardening per Atlas Q1 Must-Do #3+#4. |
| 4 | OC2 deployment playbook in Holocron (Q1) | **NEW — RAISED** | **TKT-0094** | Atlas Q1 Must-Do #5. TRIGGER-01 pre-documentation. |
| 5 | TKT-0091 — D5 managed tenant groom | **EXISTS — already raised** | **TKT-0091** | Already in tickets.json. Confirmed in Notion backlog. |

**Tickets raised this session:** TKT-0092, TKT-0093, TKT-0094 (TKT-0091 confirmed pre-existing)
**Action required:** Raise TKT-0095 to properly resolve the [TKT-0087] doc gen pipeline ID conflict in Notion.

---

## Section C — Sprint Plan

### Sprint 1 — THIS WEEK (2026-05-07 to ~2026-05-14)
**Theme: Unblock Ahsoka. Close strategy sequence. Fix critical drifts.**
Target: 7 items. Focus: P0/P1 blockers + Auralith gate prep + Atlas Q1 must-do starters.

| # | Item | TKT | Rationale |
|---|------|-----|-----------|
| 1 | **Complete TKT-0087 strategy & governance ACs (P0: AC-1 to AC-4; P1: AC-5 to AC-8)** | TKT-0087 | P0 = P2 blocker. P1 = Ahsoka live prerequisite. Block everything else if these fail. |
| 2 | **Close TKT-0088 — commit Section 10 decisions to Holocron** | TKT-0088 | Decisions made; need to persist to SSOT. 30-min task. |
| 3 | **Fix model drift: Sage/Shield/Lex haiku→correct model** | AUTO-HEAL × 3 | Governance agents on wrong models. Critical compliance risk. Quick fix. |
| 4 | **Fix cost tracker remainingEstimate bug** | AUTO-HEAL | False alarm risk — burns Ken's attention. Quick bug fix. |
| 5 | **TKT-0082 Ahsoka Pilot 1 — AInchors internal (continue)** | TKT-0082 | In progress. Reference case for consulting pillar. Don't let it stall. |
| 6 | **TKT-0069 VMS — Ken review + commit to Holocron** | TKT-0069 | In progress. Unblock TKT-0070 + 0072. |
| 7 | **TKT-0077 Persistent Agent Config — create Shield/Lex/Sage dirs** | TKT-0077 | Governance baseline. Needed for TKT-0087 AC-3. Quick structural fix. |
| 8 | **MEMORY.md trim (auto-heal item)** | AUTO-HEAL | 15-min maintenance. Do before session ends. |
| 9 | **TKT-0090 Agile framework lock (once replan delivered)** | TKT-0090 | Final step in current sequence. |

**Sprint 1 Gate:** TKT-0087 P0+P1 ACs closed, TKT-0086 sequence steps 4+5 done, model drifts resolved.

---

### Sprint 2 — NEXT SPRINT (~2026-05-14 to ~2026-05-21)
**Theme: Auralith incorporation gate prep. Atlas Q1 must-do foundation.**
Target: 7 items. Focus: end-May incorporation gate + FinOps + backup + platform observability.

| # | Item | TKT | Rationale |
|---|------|-----|-----------|
| 1 | **TKT-0060/0061/0062/0063 — revisit + complete (Auralith incorporation gate)** | TKT-0060 to 0063 | D4: Must complete before P2. Revisit trigger = end-May. Start now to avoid rush. |
| 2 | **TKT-0092 FinOps: per-agent token budgets + per-workflow cost caps** | TKT-0092 | Atlas Q1 Must-Do #2. R3 live risk. Must be live before any client work. |
| 3 | **TKT-0093 NAS encryption + 3-2-1+1 backup (S7 completion)** | TKT-0093 | Atlas Q1 Must-Do #3+#4. Security gap closure. |
| 4 | **[Doc gen pipeline] — raise TKT-0095, begin build** | [TKT-0087 mislabeled] | Atlas Q1 Must-Do #1. Ahsoka cannot generate proposals without this. |
| 5 | **TKT-0025/US40 Observability sub-agent (obs.db)** | TKT-0025 | Foundation for X1-KR3. Warden + standup feed. Quick wins from QW-4 first. |
| 6 | **ITSM quick wins: QW-4, QW-5, QW-6, QW-7, QW-8** (batch) | QW-4/5/6/7/8 | Each is 30-60min. Together they complete ITSM Phase 1 foundation. Batch in one session. |
| 7 | **TKT-0028/US38 Cost tracker — scan all agents** | TKT-0028 | 30-min fix. Foundation data for TKT-0092. |

**Sprint 2 Gate:** Auralith incorporation dependencies unblocked. FinOps controls in place. S7 closure in progress. Doc gen pipeline build started.

---

### Sprint 3 — (~2026-05-21 to ~2026-06-04)
**Theme: Atlas Q1 should-do completions. TKT-0087 P2 governance ACs. Client-readiness.**
Target: 7 items. Focus: governance infrastructure + ITSM Phase 2 + OC2 preparation.

| # | Item | TKT | Rationale |
|---|------|-----|-----------|
| 1 | **TKT-0094 OC2 deployment playbook in Holocron** | TKT-0094 | OC2 arrives July 2026. Pre-document TRIGGER-01 now. Cannot improvise OC2 setup. |
| 2 | **TKT-0087 P2 governance ACs (AC-9 to AC-12): Sanctum SLA log, Warden interval tracking, W2 client data enforcement, training-led 80/20 metric** | TKT-0087 | These are Sprint 3 per original TKT-0087 sprint plan. |
| 3 | **TKT-0075 Audit Log Architecture — Beacon v2** | TKT-0075 | P2 blocker. Needs Atlas+Thrawn design, Forge+Krennic build. Start design in Sprint 3. |
| 4 | **TKT-0091 D5 managed tenant groom — Atlas A1 vs VMS** | TKT-0091 | Must resolve before P2. Ken + Atlas grooming session. |
| 5 | **TKT-0078 Holocron Comprehensive Audit** | TKT-0078 | One-off audit. Agent Architecture page, Agent Status DB gap fill. |
| 6 | **ITSM Phase 2: ITSM-US-011 (CMDB), ITSM-US-013 (change types), ITSM-US-008 (Service Catalogue), client SLA template** | ITSM Phase 2 | P2 client-readiness prerequisites. |
| 7 | **TKT-0083 Ahsoka Pilot Case 2 — ASM** | TKT-0083 | Start once Pilot 1 complete + Auralith incorporated. |

**Sprint 3 Gate:** OC2 playbook ready. Governance ACs 9-12 done. Beacon v2 design approved. Auralith incorporation complete (end-May gate).

---

### Parking Lot

Items with no OKR link to P2 critical path and no P2 gate dependency. Review at P2 planning (August 2026) or when OC2 is stable.

| Item | TKT | Reason for Parking | Reactivation Trigger |
|------|-----|--------------------|---------------------|
| OC2 — Angie instance design | — | Angie instance is post-HIVE. Scope unclear. | HIVE stable, Angie onboarded |
| Instagram PoC | — | No P2 path. Business stream not yet active. | Angie + Aria business stream activation |
| Apply for Meta API access | — | Same as above. | Instagram PoC approved |
| Write Model Strategy Blog Post | — | Wait for 30-day cost data. Content, not ops. | 30 days post-Tier-2 activation |
| Spark: Instagram Campaign | TKT-0055 | Blocked — Instagram PoC not done | Instagram PoC complete |
| Spark: Facebook Campaign | TKT-0057 | Blocked — Facebook not connected | Facebook account connected |
| Spark: YouTube Campaign | TKT-0058 | Blocked — YouTube not connected | YouTube account connected |
| Automated social posting | TKT-0034 | Social accounts not connected + TKT-0033 missing | TKT-0033 done + accounts connected |
| Dedicated Content Agent | TKT-0035 | Dependency TKT-0033 not in backlog | TKT-0033 raised + completed |
| Yoda-Aria context sync (real-time) | US31 | OC2 required for Tailscale bridge | OC2 live |
| AInchors Hub — real-time feeds | US36 | Architecture design needed; OC2 dependent | OC2 live + design approved |
| OC2 Gemma4:26b delegation | US34 | Explicitly blocked until OC2 | OC2 TRIGGER-01 complete |
| Developer sub-agent framework | TKT-0048 | OC2 + containerisation prerequisite | OC2 Docker isolation live |
| Mission Control Kanban redesign | US37 | Needs Ken design session | Ken signs off design |
| Warden per-agent model gating | TKT-0037 | Post-OC2 feature | OC2 live, model routing first-class |
| Architecture Assurance Agent | TKT-0051 | P2 build | P2 gate passed |
| Citadel v1 (AInchors Portal) | TKT-0046 | Q3 work per Atlas | Q2 OC2 deployment complete |
| Explore Fabric framework | TKT-0047 | Research only, no urgent OKR link | Available sprint capacity |
| Telegram voice for Aria | US33 | Nice-to-have | Sprint backlog capacity |
| ITSM Phase 3+4 items | Various | Phase 3/4 per ITSM epic. Out of current scope. | ITSM Phase 2 complete |
| ISO/IEC 42001 gap analysis | — | P3 requirement | P3 gate |
| KB Index + article lifecycle | ITSM-US-019 | Phase 3 | Phase 2 complete |
| BPM Agent (Lando/TKT-0072) | TKT-0072 | TKT-0069 VMS first; then agent design | TKT-0069 committed + Sprint 3 |

---

### Items to CLOSE

| Item | TKT | Reason |
|------|-----|--------|
| Nexus P1-P4 Roadmap (sequence 3/4) | TKT-0071 | **Superseded by TKT-0086 Atlas EA roadmap (produced 2026-05-07, approved).** |
| Sprint: Strategy & Governance Integration | TKT-0085 | **This IS TKT-0089 (backlog replan). Same scope, executed.** |
| Agent Team Design & Build | TKT-0068 | **Duplicate of "AInchors Agent Team" US in backlog.** Merge/close. |
| ITSM-MIG-002 (Complete Notion Change Log) | ITSM-MIG-002 | **Duplicate of ITSM-US-028.** Close migration copy, keep ITSM-US-028. |
| ITSM-MIG-003 (Classify 53 assets) | ITSM-MIG-003 | **Duplicate of ITSM-US-029.** Close migration copy, keep ITSM-US-029. |
| ITSM-US-032 (Client-facing SLA template) | ITSM-US-032 | **Duplicate of ITSM-MIG-006.** Close one, keep ITSM-MIG-006. |

---

## Section D — Critical Path Summary (P2 End August 2026)

```
NOW → END MAY 2026 (Auralith Incorporation Gate)
├── TKT-0087: P0+P1 governance ACs ← SPRINT 1
├── TKT-0060/0061/0062/0063: Client DPA + Warden thresholds + S4 + Ollama DPA ← SPRINT 2
└── Auralith incorporation (legal, external) ← Ken action

MAY → JULY 2026 (Atlas Q1 Must-Do)
├── [TKT-0095]: Document generation pipeline ← SPRINT 2+3
├── TKT-0092: FinOps per-agent + per-workflow caps ← SPRINT 2
├── TKT-0093: NAS encryption + 3-2-1+1 backup ← SPRINT 2
├── TKT-0094: OC2 deployment playbook ← SPRINT 3
└── TKT-0082: Ahsoka Pilot 1 complete ← SPRINT 1+2

JULY → AUGUST 2026 (OC2 + P2 Gate)
├── OC2-A/B hardware arrives → TRIGGER-01 execution
├── HIVE live: Tailscale mesh, Ollama, Tier 1 inference
├── Docker per-client isolation (2 SME test envs)
├── TKT-0075: Audit Log / Beacon v2 live
├── Failover test documented
└── P2 GO-LIVE: end August 2026
```

---

## Appendix — OKR Tag Summary

| OKR | Items Linked |
|-----|-------------|
| C1-KR1/KR2/KR3 | TKT-0082, TKT-0083, ITSM-MIG-006, TKT-0027 |
| S1-KR1/KR2, S2-KR1 | TKT-0082, [doc gen pipeline], TKT-0083 |
| X1-KR1 | TKT-0093, ITSM-US-004, US39 |
| X1-KR2 | TKT-0082, TKT-0092, Docker isolation (OC2) |
| X1-KR3 | ITSM-US-004, TKT-0025/US40, QW-4, ITSM-US-015/016, TKT-0075 |
| X1-KR4 | TKT-0094, TKT-0093, US19, OC2 deployment |
| X2-KR1 | TKT-0086/0087/0088/0089/0090, TKT-0069, TKT-0070 |
| X2-KR2 | TKT-0089, TKT-0078, OKR tagging |
| G1-KR1/KR2/KR3 | TKT-0032, TKT-0077, TKT-0087 ACs, ITSM Phase 2 |
| T1-KR1/KR3 | TKT-0027, TKT-0056, workshop prep |

---

*Document: `state/tkt-0089-backlog-replan.md` | Produced by Yoda 🟢 | TKT-0089 | 2026-05-07*
*Inputs: TKT-0086 Atlas EA Roadmap, TKT-0088 Section 10 decisions, TKT-0087 groom, AInchors OKR 2026-05*
*New tickets raised: TKT-0092 (FinOps caps), TKT-0093 (NAS+backup), TKT-0094 (OC2 playbook)*
*TKT-0091 confirmed pre-existing (D5 managed tenant groom)*
