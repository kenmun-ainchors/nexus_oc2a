# Yoda 🟢 — Nexus Platform Orchestrator
# Architecture & Operating Model Reference
# Version: 2.0.0 | Updated: 2026-05-10 | Platform Day: 16
# Classification: Internal | Location: workspace/docs/Yoda_ORCHESTRATOR.md
# Author: Yoda 🟢 | Approved by: Ken Mun (CTO)
# This is the companion reference document to SOUL.md and YODA_RULES.md.
# It provides the full architectural picture for Ken's review and as a
# long-form context source. It is NOT loaded directly into Yoda's session —
# reference sections are called explicitly when needed.

---

## 1. Purpose of This Document

This document defines Yoda's full orchestrator design — what Yoda is responsible
for, how Yoda thinks, how Yoda manages the HIVE, and how the entire agent fleet
is coordinated to serve AInchors' mission and commercial goals.

It exists at three levels:
- **Architecture reference** — the definitive picture of Nexus for Ken
- **Operational model** — how Yoda runs the platform day to day
- **Strategic alignment** — how the platform connects to P1→P4 goals and the
  AInchors/Aevlith vision

---

## 2. Yoda's Mandate

Yoda is not an agent that does work. Yoda is the agent that makes sure work
gets done — correctly, efficiently, safely, and aligned to Ken and Angie's
goals at every moment.

**Yoda owns:**
- Full situational awareness of the HIVE at all times
- Task classification and routing to the right agent
- Quality-gating all outputs before Ken or Angie sees them
- Governance enforcement (The Sanctum, HITL gates, CHG discipline)
- Incident response coordination and post-mortem follow-through
- Platform health monitoring and auto-heal orchestration
- Continuous improvement of the platform's own operating model
- Context handoff — ensuring nothing important is ever lost between sessions

**Yoda does not own:**
- Specialist architecture decisions (→ Atlas / Thrawn)
- Content creation (→ Spark)
- Process design (→ Lando)
- Client-facing consulting (→ Ahsoka)
- Change management plans (→ Mon Mothma)
- Legal/security/QA reviews (→ Lex / Shield / Sage)

The distinction is clear: Yoda orchestrates. Specialists deliver.

---

## 3. HIVE Architecture — Full Picture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        NEXUS HIVE (Day 16)                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  OC1 (LIVE — Production)           OC2-A (July 2026 — HA Primary)  │
│  Mac Mini M4 24GB                  Mac Mini M4 Pro 48GB            │
│  All agents P1                     Gemma4:26b inference             │
│  All crons + governance            Aria migration                   │
│  Hard limit: <8B Q4 local          OC1 load balancing               │
│                                                                     │
│                                    OC2-B (July 2026 — HA Secondary) │
│                                    Mac Mini M4 Pro 48GB             │
│                                    Hot standby                      │
│                                                                     │
│  Supporting: Tailscale mesh | NAS (model weights + state, post-OC2) │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                     STORAGE LAYERS (Locked 2026-05-10)             │
│                                                                     │
│  Human Layer (LIVE):  Google Drive — business docs, Brand Code,    │
│                       KL sharing, reports, drafts for Ken review   │
│  Agent Layer (Sprint 3): MinIO — agent-memory, generated-media,    │
│                           workspace-assets, brand-code (4 buckets) │
│  P2+: AWS S3 Sydney — multi-tenant client data                     │
│  Access: Tailscale Serve (internal) | Tailscale Funnel (KL team)   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### HIVE Trigger Events
| Trigger | Condition | Action |
|---|---|---|
| TRIGGER-01 | OC2 arrives | OC2 setup sequence |
| TRIGGER-04 | OpenClaw update available | Forge evaluates, Yoda/Ken decide |
| TRIGGER-06 | OpenClaw v4.0 ships | Agent platform alternatives assessment |
| TRIGGER-08 | API balance reaches reload threshold | Auto-reload fires |

---

## 4. Platform Module Map (Nexus Star Wars Naming)

| Module | Name | Status | Purpose |
|---|---|---|---|
| Platform | **Nexus** | LIVE | API-first HIVE portal — the whole platform |
| Knowledge Base | **Holocron** | LIVE | Notion SSOT — all decisions, plans, records |
| Command Centre | **The Bridge** | Design | Real-time ops view — The Bridge dashboard |
| Client Portal | **The Citadel** | P2 build | Per-client secure access portal |
| Real-time data | **Holonet** | P3 build | Live data API feeds |
| Monitoring | **Beacon** | LIVE | health-state.json + obs.db + alerts |
| Governance vault | **The Sanctum** | LIVE | Shield + Lex + Sage triad |
| Reporting | **Datapad** | P3 build | Dashboards and reporting terminal |

---

## 5. Agent Fleet — Full Architecture (Day 16)

### 5.1 Fleet Topology

```
                        KEN MUN (CTO)
                             │
                        YODA 🟢
                    (Lead Orchestrator)
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
   TECHNICAL             BUSINESS          CONSULTING
   STREAM                STREAM            STREAM
     │                     │                   │
   Yoda                  Aria 🔵           Ahsoka
     ├── Atlas 🏛️          ├── Spark ✨         (AI Transformation
     ├── Thrawn            ├── Lando 🟡          Consultant)
     ├── Forge 🏗️          ├── Mon Mothma 🌟
     └── Krennic 🔵        └── Luthen 🔍
         (PLANNED)              (P2 GATE)

                    ANGIE FOONG (CEO)
                        via Aria

          ════════════════════════════════
                 CROSS-STREAM GOVERNANCE
                    (THE SANCTUM)
           Shield 🛡️ | Lex ⚖️ | Sage 🧪
                    + Warden 🔍
               (automated, all agents)
          ════════════════════════════════
```

### 5.2 Agent Detailed Profiles

| Agent | Stream | Core Function | Key Frameworks | Model | Status |
|---|---|---|---|---|---|
| **Yoda 🟢** | Technical/Lead | Platform orchestration, routing, governance, HIVE health | ITIL, Agile, HITL, CHG | Sonnet | LIVE |
| **Aria 🔵** | Business | CEO-facing, marketing orchestration, Brand Code stewardship | Marketing org model (HBR), Brand stewardship | Sonnet | LIVE |
| **Spark ✨** | Business | Social/digital content — LinkedIn, Instagram, X | Content calendar, image pipeline (FLUX.1) | kimi-k2.6:cloud | LIVE |
| **Atlas 🏛️** | Technical | Enterprise architecture, P1–P4 roadmap, EA assurance | TOGAF, BIZBOK, Zachman | Sonnet | LIVE |
| **Thrawn** | Technical | Platform architecture — Nexus Core, model strategy, orchestration | Agent design patterns, model tier strategy | Sonnet | LIVE |
| **Lando 🟡** | Business | Business process design and documentation | BPM/BPMN, Lean, Six Sigma, TQM | Sonnet | LIVE |
| **Mon Mothma 🌟** | Business | Digital transformation, change management | ADKAR, Kotter 8-step, Prosci | Sonnet | SOFT-ACTIVE |
| **Forge 🏗️** | Technical | Infrastructure, SRE, CI framework, model PoC | SRE practices, CI/CD, health monitoring | Sonnet | LIVE |
| **Ahsoka** | Consulting | AI Transformation Consulting — discovery, proposals, business cases | SPIN, Challenger Sale, McKinsey Rewired, BCG AI@Scale | Sonnet | LIVE |
| **Krennic 🔵** | Technical | Incident response, SLO/error budget management | SRE, error budget, runbooks | TBD | PLANNED |
| **Luthen 🔍** | Business | Marketing intelligence — HBR workstreams 1+3 | HBR Agentic Marketing, intelligence frameworks | TBD | P2 GATE |
| **Shield 🛡️** | Governance | Security review — pre-action gate on all external assets | S1–S7, OWASP, security policy | Sonnet | LIVE |
| **Lex ⚖️** | Governance | Legal gate — contracts, APP, privacy, Policy Register | Australian Privacy Act, APP, IP law | Sonnet | LIVE |
| **Sage 🧪** | Governance | QA gate — content accuracy, output quality, policy alignment | Quality frameworks, fact-checking | Sonnet | LIVE |
| **Warden 🔍** | Governance | Automated model compliance — all agents 15-min / T3 hourly | Model3-Policy, compliance monitoring | gemma4:e2b | LIVE |

### 5.3 Atlas Architecture Assurance Role (Model3-Policy v1.0)
Atlas reviews outputs from Thrawn, Lando, and Mon Mothma when enterprise
implications exist. SLA: 24 hours. Verdicts:
- **ALIGNED** — proceed
- **NEEDS-REVISION** — agent revises before Ken sees it
- **FLAG-TO-YODA** — Yoda holds and escalates to Ken

---

## 6. Orchestration Decision Framework

### 6.1 Task Classification Model

Every task that arrives at Yoda passes through a 3-level classification:

```
LEVEL 1 — DOMAIN
  ├── Platform/Technical    → Technical stream
  ├── Business/Marketing    → Business stream
  ├── Client/Consulting     → Consulting stream
  ├── Governance/Security   → The Sanctum
  └── Cross-cutting         → Multi-stream coordination

LEVEL 2 — SCOPE
  ├── P1 (internal ops)     → Current fleet, no new build required
  ├── P2 trigger            → Flag to Ken; may require OC2, Citadel, new agents
  └── P3/P4 strategic       → Atlas for roadmap implication; Ken approval

LEVEL 3 — HITL TIER
  ├── Tier 1–2 (auto)       → Execute, log
  ├── Tier 3 (draft+notify) → Produce, present to Ken summary
  ├── Tier 4 (approval)     → Draft, hold for Ken/Angie explicit approval
  └── Tier 5 (full human)   → Do not proceed until human initiates
```

### 6.2 Conflict Resolution Protocol
When Atlas and Thrawn produce conflicting outputs on a cross-cutting task:
1. Yoda identifies the specific conflict point (not the whole document)
2. Yoda briefs both agents on the conflict point only
3. Each produces a focused reconciliation proposal
4. Yoda presents reconciled options + Yoda's recommendation to Ken
5. Ken decides. Yoda implements.

### 6.3 Escalation Ladder
```
Agent detects issue
    → Yoda first (most issues resolved here)
    → Ken (requires human judgment, budget, or external commitment)
    → Angie (business/commercial/client-facing matters)
    → External (legal, compliance — only with Lex + Ken approval)
```

---

## 7. Governance Architecture

### 7.1 The Sanctum — Mandatory Governance Triad
All external and client-facing outputs pass through The Sanctum before delivery.
No exceptions. Sequence is always: Shield → Lex → Sage.

```
Shield 🛡️ checks:
  - Security implications of the output
  - No credential, PII, or sensitive data exposure
  - S1–S7 compliance of any referenced systems
  - SKILL.md poisoning risk on any new tool references

Lex ⚖️ checks:
  - Legal compliance (Australian Privacy Act, APP)
  - Contract and IP implications
  - Regulatory risk flags
  - Policy Register alignment (TKT-0137, Lex owns)

Sage 🧪 checks:
  - Factual accuracy of all claims
  - Output quality and completeness
  - Policy and charter alignment
  - Definition of Done criteria met
```

### 7.2 Warden Compliance Loop
```
Every 15 minutes:
  Warden checks all agents → expected model vs actual model
  T3 specialist agents (Atlas, Thrawn, Lando, Mon Mothma): checked hourly
  Any drift → Warden escalates to Yoda (1 heartbeat)
  3 consecutive failures on same agent → failureAlert → Telegram Ken
  Yoda resolves drift in same session or flags to Ken
```

### 7.3 AI Charter Enforcement (7 Principles)
Yoda actively enforces all 7 charter principles at the platform level:

| Principle | Yoda Enforcement Mechanism |
|---|---|
| Human Authority | HITL gates; no self-approval; all Tier 4/5 hold for human |
| Honesty | Sage QA gate on all outputs; no fabrication tolerated |
| Transparency | Sources always available; reasoning always provided |
| Data Sovereignty | Model routing enforced; Tier 0/1 for all client data |
| Responsible Autonomy | Scope boundaries in every agent RULES.md; escalation ladder |
| Security by Default | S1–S7 always live; skill gate non-negotiable; Shield pre-action |
| Continuous Improvement | INC post-mortems → rule updates; QBR fleet reviews |

---

## 8. Operational Rhythms

### 8.1 Daily Automated Operations (Yoda-Orchestrated)

```
TIME (AEST)  EVENT                                          AGENT
──────────────────────────────────────────────────────────────────
00:00        Midday cost snapshot → Telegram Ken            Forge
01:00        Auto-heal: 12 checks, auto-fix, log           Yoda (systemEvent)
02:00        Workspace backup to NAS/Drive                 Forge
03:00        Holocron daily update (Notion sync)           Yoda isolated
06:00        OpenClaw update check + TRIGGER-04/06         Forge
07:45        Daily memory hygiene (MEMORY.md pruning)      Yoda isolated
08:00        Morning stand-up → @AInchorsOC1Bot (Ken)      Yoda isolated
10:00        Warden compliance check loop begins           Warden (every 15 min)
22:00        Shield / Lex / Sage daily governance review   Each isolated
23:00        Yoda → Aria context sync (cross-stream brief) Yoda (main)
23:00        Google Drive nightly sync                     drive-sync.sh
23:45        Aria daily summary → @AInchorsAriaBot (Angie) Aria (business)
23:55        End-of-day close: journal + blog draft        Yoda (main)
```

### 8.2 Weekly Ceremonies
| Day/Time | Ceremony | Owner |
|---|---|---|
| Tue + Thu 7:30AM | LinkedIn posts | Spark |
| Wed 12PM | LinkedIn post | Spark |
| Sun 5PM | Weekly Business ROI summary → Angie | Aria |
| Sun 5PM | Asset registry review | Forge |

### 8.3 Monthly / Quarterly Ceremonies
| Schedule | Ceremony | Owner | Approval |
|---|---|---|---|
| 28th monthly | Model strategy review | Thrawn/Forge | Ken |
| 1st Jan/Apr/Jul/Oct | Full asset audit | Forge | Ken |
| Jan/Apr/Jul/Oct | QBR Agent Fleet Review (TKT-0130) | Yoda | Ken |

### 8.4 Strategy-to-Backlog Pipeline
After every strategy artefact delivery (Atlas, Thrawn, Lando):
1. Agent appends backlog seeding list to the artefact
2. Tickets raised in Holocron
3. Artefact marked Done only after tickets are live
Ref: docs/Strategy_to_Backlog_Pipeline_v0.1.md

---

## 9. AInchors Strategic Alignment

### 9.1 Company Vision (Core Thesis)
AInchors proves that a small founding team can operate at 10-person scale using
autonomous AI agents. Every process built, every system documented, every lesson
learned = training product curriculum and consulting methodology.
The business IS the demo.

### 9.2 P1 → P4 Roadmap (Yoda's North Star)

| Phase | Status | Theme | Key Yoda Responsibilities |
|---|---|---|---|
| **P1** | NOW (Day 16) | Build, validate internally | All platform operations, proving model |
| **P2** | ~Q3 2026 | First external client | OC2 setup, Citadel build, Ahsoka client delivery, tenant isolation |
| **P3** | ~Q4 2026–Q1 2027 | Multi-client scale | Systemised onboarding, Datapad, Holonet, fleet expansion |
| **P4** | ~2027 | Nexus as product | Managed platform product, self-serve tier, open source contribution |

### 9.3 Revenue Streams Yoda Enables
1. **AI Consulting** — Ahsoka delivers; Yoda orchestrates the supporting fleet
2. **AI Courses & Training** — Content from real platform events; Yoda generates
   the raw material through operational excellence
3. **AI Solutions & Products** — Nexus itself becomes the product at P4

### 9.4 Commercial Product Stack (In Development)
| TKT | Product | Status |
|---|---|---|
| TKT-0136 | Consulting Playbook — AI Transformation IP library | In backlog |
| TKT-0138 | Business Jumpstart — 3-part entry consulting engagement | In backlog |
| TKT-0139 | Consulting Product Portfolio — AI maturity + P2–P4 map | In backlog |

### 9.5 Aevlith Technologies
Strategic partnership in progress. TKT-0114 (partnership agreement) is a hard
gate for TKT-0115–0119 (full Aevlith incorporation track). Status: requires
Ken + Angie action.

{{AEVLITH_PLACEHOLDER}}
<!-- Replace this block with full Aevlith context when TKT-0114 is resolved.
     Include: entity structure, shared vision/mission, Yoda's role in serving
     both entities, data/platform boundary between AInchors and Aevlith. -->

---

## 10. Key Decisions Log (Architecture-Level)

| Decision | Rationale | Date | CHG |
|---|---|---|---|
| OpenClaw as platform — final, no replatform | Native multi-agent, self-hosted, extensible | Apr 2026 | — |
| Notion as Holocron SSOT (Obsidian retired) | API-first, Angie collaboration | 2026-05-03 | — |
| Dual-bot Telegram | Prevents cross-contamination | Apr 2026 | — |
| Star Wars naming convention | Differentiates, memorable, team culture | 2026-05-03 | — |
| SOUL.md ≤ 5,000 chars (hard standard) | Prevents gateway OOM (confirmed INC Apr 30) | 2026-04-30 | — |
| 4-tier model strategy | Cost control + data sovereignty | 2026-05-02 | — |
| AI Charter + Governance Framework | Legal/ethical foundation pre-first client | 2026-05-04 | — |
| HIVE architecture (OC1 + OC2-A/B) | HA, local inference, cost control | May 2026 | — |
| Google Drive as interim file bridge | Until MinIO (TKT-0124) is live | 2026-05-10 | CHG-0265 |
| MinIO hybrid model locked | Human = Drive, Agent = MinIO, P2 = S3 | 2026-05-10 | TKT-0124 |
| Model3-Policy v1.0 | Formalised routing; Atlas assurance role | 2026-05-10 | CHG-0258 |
| Skill Installation Gate | SKILL.md poisoning vulnerability response | 2026-05-10 | CHG-0270 |
| Warden T3 hourly checks + failureAlert | Improved compliance coverage | 2026-05-10 | CHG-0259 |
| Telegram fallback alert (API-independent) | INC-20260509-001 root cause fix | 2026-05-09 | CHG-0262 |

---

## 11. Active Sprint & Backlog Snapshot (Day 16)

### Sprint 3 (In Progress)
| TKT | Title | Status |
|---|---|---|
| TKT-0124 | MinIO agent layer (4 buckets) | In-progress |
| TKT-0135 | Sandbox environment | Open |
| TKT-0128 | Aria expanded mandate (gated on TKT-0124) | In-progress |

### Critical High-Priority Backlog
| TKT | Title | Blocker? |
|---|---|---|
| TKT-0130 | QBR Agent Fleet Review ceremony | July 2026 |
| TKT-0136 | Consulting Playbook | — |
| TKT-0137 | Policy Register (Lex) | — |
| TKT-0138 | Business Jumpstart | — |
| TKT-0139 | Consulting Product Portfolio | — |
| TKT-0108 | Document Generation Pipeline | Ahsoka blocker |
| TKT-0114 | AInchors–Aevlith partnership | Ken + Angie action |
| TKT-0141 | CLI-Anything supply chain security | Atlas in progress |

---

## 12. File & Reference Map

| Resource | Location | Purpose |
|---|---|---|
| SOUL.md | workspace/SOUL.md | Yoda identity core (≤5,000 chars) |
| YODA_RULES.md | workspace/YODA_RULES.md | Full operating rules (this document's operational companion) |
| ORCHESTRATOR.md | workspace/docs/Yoda_ORCHESTRATOR.md | This document — architecture reference |
| MEMORY.md | workspace/MEMORY.md | Long-term memory — all decisions, facts, IDs |
| AI Charter v1.0 | workspace/docs/AI_CHARTER_v1.0.md | Governance principles |
| AI Governance Framework | workspace/docs/AI_GOVERNANCE_FRAMEWORK_v1.0.md | Operational governance |
| Model3-Policy.md | workspace/docs/Model3-Policy.md | T3 agent routing SOPs |
| Skill-Installation-Policy | workspace/docs/Skill-Installation-Policy-v1.0.md | SKILL gate procedure |
| Strategy-to-Backlog Pipeline | workspace/docs/Strategy_to_Backlog_Pipeline_v0.1.md | Strategy → ticket process |
| Agent TOM Review | workspace/docs/Agent_TOM_Review_2026-05-10.md | Fleet TOM assessment |
| Holocron | Notion (AKB) | SSOT — architecture, backlog, decisions, agent ops |
| CHANGELOG.md | workspace/memory/CHANGELOG.md | All CHG records |
| skill-registry.json | workspace/state/skill-registry.json | 63 registered skills |
| health-state.json | workspace/ | Live OC1 health state |
| obs.db | workspace/ | Observability events database |

---

## 13. How Ken Uses This Document

This document is DRAFT FOR REVIEW until Ken explicitly approves it.

**Ken's primary use cases:**
1. **Onboarding new sessions** — load this alongside SOUL.md + RULES.md to give
   any agent or assistant full platform context immediately
2. **Architecture decisions** — section 6 (orchestration model) and section 7
   (governance) as reference when evaluating changes
3. **Strategic alignment** — section 9 as a reminder of why everything is built
   the way it is, tied to P1→P4 goals
4. **Fleet changes** — section 5 as the authoritative agent roster; update here
   first when agents are added, changed, or retired

**Update protocol:**
Any change to this document = CHG record + version bump + Ken review.
Yoda presents changes as "DRAFT FOR REVIEW" via @AInchorsOC1Bot with a
1-paragraph summary of what changed and why.

**Formal update triggers (locked 2026-05-10, Ken approved):**
- TRIGGER-QBR: Every Jan/Apr/Jul/Oct QBR — full version bump of SOUL.md,
  YODA_RULES.md, and ORCHESTRATOR.md as part of Agent Fleet Review (TKT-0130)
- TRIGGER-OC2: OC2 commissioning (~27 Jul 2026) — version bump to reflect
  new hardware, HA architecture, Gemma4:26b local inference, NAS storage
- TRIGGER-P2: First external client onboarding — version bump to reflect
  multi-tenant model, Citadel activation, Ahsoka live delivery
- TRIGGER-MAJOR: Any significant mandate change, new agent stream, or
  structural governance change — version bump same session, Ken approves

**Between triggers:** Yoda manages SOUL.md, YODA_RULES.md, YODA_RUNBOOK.md
incrementally as decisions are made. No ceremony required for routine updates.

---

## Version History

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-05-07 | Initial orchestrator architecture document |
| 2.0.0 | 2026-05-10 | Full rewrite: Day 16 state, delta context integrated, full 3-stream fleet (14 agents), HIVE topology, storage hybrid model, Model3-Policy, SKILL gate, Warden T3 hourly, Ahsoka live, commercial product stack, KL team, Aevlith placeholder, QBR ceremony, all decision log entries, active sprint snapshot |

---
*Location: workspace/docs/Yoda_ORCHESTRATOR.md*
*Maintained by: Yoda 🟢 | Ken Mun (CTO) approval required for changes*
*Source context: 20260507_AInchors Context.md + Context-Handoff-Delta-20260507-20260510.md*
*Platform Day 16 — 2026-05-10*
