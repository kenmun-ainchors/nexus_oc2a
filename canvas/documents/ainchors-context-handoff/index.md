# AInchors — Business Context Handoff
> Purpose: Deep research context for Perplexity AI
> Generated: 2026-05-07 | Source: Yoda (AI ops lead) | Classification: Internal
> Covers: Business overview, Nexus platform, agent architecture, strategy, roadmap P1–P4

---

## 1. The Company

**Ainchor Solutions Pty Ltd**
- Founded: 2026-04-25 (Day 1)
- Location: Sydney NSW + Melbourne, Australia
- Structure: Two co-founders, no other staff — AI agents are the team
- Website: ainchors.com
- Focus: AI consulting, AI courses/training, AI solutions & products

### Founders

| Person | Role | Focus |
|---|---|---|
| **Ken Mun** | Co-founder, CTO | Technical platform, AI infrastructure, agent architecture |
| **Angie Foong** | Co-founder, CEO | Business development, marketing, client relationships, revenue |

### Revenue Streams (planned)
1. **AI Courses & Training** — packaged training content on building and operating AI platforms; target: SMEs, consultants, non-technical executives
2. **AI Consulting** — hands-on engagements helping businesses deploy AI agents and automation; target: P2 first client onwards
3. **AI Solutions & Products** — productised AI tooling and platforms; longer term

### Current Stage
- **P1 (now):** Internal platform build — proving the model works on ourselves before selling it
- No external clients yet. First client = P2 trigger event.
- Revenue: pre-revenue. Bootstrap funded by founders.
- Total AI infrastructure spend to date: ~A$1,464 (tech only, USD$309+ in API credits consumed)
- Current API balance: USD$100.13

---

## 2. The Core Thesis

**AInchors is building proof-of-concept that a small founding team can operate at the scale of a 10-person company by deploying an autonomous AI agent platform to run day-to-day business operations.**

Every process AInchors builds, every system it documents, every lesson learned — becomes the curriculum for training products and the methodology for consulting engagements.

The business IS the demo. Ken and Angie are running a live experiment: can two people, with the right AI infrastructure, operate a full-stack business (marketing, operations, legal, QA, finance, strategy) with minimal human toil?

The answer — so far on Day 12 — is yes.

---

## 3. The Platform — Nexus

**Nexus** is AInchors' internal AI platform. It is API-first, agent-driven, and built on [OpenClaw](https://docs.openclaw.ai) (an open-source AI agent framework).

### Naming Convention (Star Wars — confirmed by Ken + Angie, locked)

| Module | Star Wars Name | Description |
|---|---|---|
| Overall platform | **Nexus** | API-first Hive portal |
| Knowledge Base | **Holocron** | Single source of truth (Notion) |
| Command Centre | **The Bridge** | Real-time ops view |
| Client Portal | **The Citadel** | Per-client access |
| Real-time data/API layer | **Holonet** | Live data feeds |
| Monitoring / Health | **Beacon** | Health alerts and observability |
| Governance vault | **The Sanctum** | Shield/Lex/Sage triad |
| Reporting / Dashboards | **Datapad** | Data terminal |

### Platform Architecture — HIVE

```
OC1 (NOW — LIVE PRODUCTION)
Mac Mini M4 24GB — Ken's desk
Runs: Yoda (lead), Aria (business), Spark (social), Governance triad + all crons
Hard limit: No local LLM inference >~8B Q4

OC2-A (INCOMING — ETA July 2026)
Mac Mini M4 Pro 48GB — HA Primary
Runs: Local Gemma4:26b inference, Aria migration, OC1 load balancing

OC2-B (INCOMING — ETA July 2026)
Mac Mini M4 Pro 48GB — HA Secondary / Hot standby

Supporting: Tailscale mesh, NAS (shared model weights + state)
```

### Technology Stack
- **Agent Framework:** OpenClaw (self-hosted, version 2026.5.5)
- **Primary AI Model:** Anthropic Claude Sonnet 4.6 (Sonnet default for all agents)
- **Local Models:** Gemma4:e2b (background governance, non-interactive), Ollama runtime
- **Cloud AI (Tier 2):** Ollama Cloud — kimi-k2.6, deepseek-v4-flash, deepseek-v4-pro
- **Knowledge Base:** Notion (Holocron) — migrated from Obsidian 2026-05-05
- **Communication:** Telegram (dual-bot: @AInchorsOC1Bot for Ken/Yoda, @AInchorsAriaBot for Angie/Aria)
- **Source Control:** Git (workspace versioned)
- **Secrets:** macOS Keychain
- **Observability:** obs.db, health-state.json, Warden (15-min compliance checks)

---

## 4. Agent Architecture — The Team

AInchors operates with **two streams** of AI agents, orchestrated by Yoda (technical lead) and Aria (business lead).

### Two-Stream Architecture

```
TECHNICAL STREAM (Ken + Yoda)          BUSINESS STREAM (Angie + Aria)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Yoda 🟢 — Lead Agent (CTO stream)      Aria 🔵 — Business Lead
  ├─ Atlas 🏛️ — Enterprise Architect     ├─ Spark ✨ — Social/Marketing
  ├─ Thrawn — Platform Architect          ├─ Lando 🟡 — BPM Agent
  ├─ Forge 🏗️ — Infra / SRE             └─ Mon Mothma 🌟 — Change Mgmt
  └─ Krennic 🔵 — SRE Agent (planned)
         
CROSS-STREAM GOVERNANCE (The Sanctum)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Shield 🛡️ — Security review
Lex ⚖️ — Legal / compliance
Sage 🧪 — QA / ethics
Warden 🔍 — Automated compliance monitor (every 15 min)
```

### Full Agent Roster

| Agent | Role | Model | Status |
|---|---|---|---|
| **Yoda 🟢** | Lead AI ops agent (CTO stream). Platform, infrastructure, architecture. | Sonnet | LIVE |
| **Aria 🔵** | Business lead agent (CEO stream). Operations, marketing, client comms. | Sonnet | LIVE |
| **Spark ✨** | Social & digital marketing. LinkedIn, Instagram, Facebook, X. Content pipeline. | kimi-k2.6:cloud | LIVE |
| **Atlas 🏛️** | Enterprise architect. TOGAF, P1–P4 roadmap, strategic design. | Sonnet | LIVE |
| **Thrawn** | AI platform architect. Nexus Core, agent orchestration, model strategy. | Sonnet | LIVE |
| **Lando 🟡** | Business process specialist. BPM/BPMN, Lean, Six Sigma, TQM. | Sonnet | LIVE |
| **Mon Mothma 🌟** | Digital transformation & change management. ADKAR, Kotter, Prosci. | Sonnet | LIVE |
| **Forge 🏗️** | Infrastructure/SRE. CI framework, model PoC, infra monitoring. | Sonnet | LIVE |
| **Warden 🔍** | Model compliance officer. Checks all 9 agents every 15 min. Escalates to Yoda. | gemma4:e2b | LIVE |
| **Shield 🛡️** | Security gate. Pre-action security review on all public/external assets. | Sonnet | LIVE |
| **Lex ⚖️** | Legal gate. Privacy, contracts, APP compliance. | Sonnet | LIVE |
| **Sage 🧪** | QA gate. Content accuracy, output quality, policy alignment. | Sonnet | LIVE |
| **Krennic 🔵** | SRE agent. Incident response, SLO/error budget. | TBD | PLANNED |

### Governance Model
Every piece of content or public action goes through **mandatory governance review** before execution:
1. **Shield** — security implications
2. **Lex** — legal/compliance check
3. **Sage** — quality assurance

Warden monitors all agent model assignments every 15 minutes and escalates any drift to Yoda within one heartbeat.

### AI Charter & Governance Framework
Approved 2026-05-04 (Ken Mun, CTO):
- 7 guiding principles: Human Authority, Honesty, Transparency, Data Sovereignty, Responsible Autonomy, Security by Default, Continuous Improvement
- 5-tier HITL (Human-in-the-Loop) framework
- Data residency: client data = local only (Tier 0/1 models), never crosses to cloud APIs
- Security controls S1–S7 enforced by Warden

---

## 5. Platform Phases — Roadmap P1–P4

### P1 — Foundation (NOW — ~Day 1–90)
**Theme:** Build, validate, prove internally

- Deploy full AI platform on OC1 (Mac Mini M4)
- Establish all core agents and governance layer
- Build knowledge base (Holocron/Notion)
- Develop content pipeline (33 training content ideas captured)
- Document everything as curriculum
- LinkedIn content programme (AIOps theme, 6 cycles)
- No external clients yet

**Key milestones completed (Day 1–12):**
- Platform operational with 12 active agents
- AI Charter + Governance Framework approved
- Notion Holocron live (38 pages migrated)
- Spark running LinkedIn content: W1P1 published
- Ollama Cloud PoC complete (kimi-k2.6 Tier 2 live)
- Warden model compliance live
- Full CI framework (Cycle A + B) for model strategy

### P2 — First Client (~Q3 2026, post OC2 arrival)
**Theme:** Prove the model externally

**Triggers:**
- OC2 nodes arrive (July 2026) → TRIGGER-01 setup sequence
- OC2 validated → Aria migrates to OC2 (business stream isolated)
- First P2 client → onboarding checklist, S1-S7 audit

**Key deliverables:**
- The Citadel (client portal) designed and built
- Client data sovereignty enforced (Tier 0/1 local models only for client data)
- Client Telegram bot per client
- Consulting methodology productised from P1 learnings
- AI training course(s) packaged

**Target segment:** SMEs in Southeast Asia (Malaysia/Australia focus based on Angie's network); AI-ready businesses wanting to deploy autonomous operations without hiring a team

### P3 — Scale (~Q4 2026–Q1 2027)
**Theme:** Multiple clients, systemised delivery

- Multiple client instances of Nexus
- Productised onboarding (< 1 week to deploy)
- Datapad (reporting/dashboards) live
- Holonet (real-time data API layer) live
- Revenue from both consulting + course sales
- Possible first hire or partner network

### P4 — Platform (~2027)
**Theme:** Nexus as a product

- Nexus offered as a managed AI operations platform
- Self-serve tier for smaller clients
- AInchors as a case study / reference architecture
- Training business at scale
- OpenClaw-based; potential contribution back to open source

---

## 6. Content & Marketing Strategy

### LinkedIn (Primary Channel — Ken)
- **Theme:** AIOps — building a real AI-operated business in public
- **Cadence:** 3 posts/week (Tue, Thu, Wed midday)
- **6-cycle content roadmap locked:**
  - C1: The Infrastructure (what we built and why)
  - C2: The Agents (who does what)
  - C3: The Operations (how it runs day-to-day)
  - C4: The Lessons (what broke, what we learned)
  - C5: The Client Story (first engagement)
  - C6: The Product (Nexus as an offering)
- **First post published:** 2026-05-05 (W1P1) — urn:li:activity:7457186904363421696
- **Target audience:** Tech leaders, CTOs, founders, digital transformation practitioners

### Social Media (Angie — Brand Channels)
- Instagram, Facebook, X — pending Meta API connection (TKT-0034)
- Aria manages brand content, Ken approves personal content

### Training Content Pipeline
- **33 content ideas** captured (TC-001 to TC-033), all sourced from real platform events
- Format: Long-form articles → structured courses → live workshops
- First workshop target: KL June 2025 (Angie's network, Malaysia)

---

## 7. Model & Cost Strategy

### 4-Tier Model Strategy (Post-OC2)

| Tier | Model | Cost | Use Case |
|---|---|---|---|
| Tier 0 | No LLM (systemEvent crons) | $0 | Health checks, observability, task monitoring |
| Tier 1 | Gemma4:26b local on OC2 | $0 (local) | Governance, client workloads, data-sovereign tasks |
| Tier 2 | Ollama Cloud (kimi-k2.6 / deepseek) | ~$100/mo flat | AInchors ops only — NEVER client data |
| Tier 3 | Claude Sonnet 4.6 | Pay-per-token | Complex reasoning, high-stakes decisions |

**Current (pre-OC2):** Sonnet primary + Ollama Cloud Tier 2 active. Full 4-tier pending July 2026.

**Budget cap:** A$500/month hard limit. Alert at A$400.
**Spend to date (12 days):** ~USD$409 (~A$636) — heavy infrastructure build phase, expected to normalise at P2.

### Data Sovereignty (non-negotiable)
- Client data = Tier 0/1 (local) ONLY
- AInchors operational data = Tier 2/3 acceptable
- Enforced by Warden + DS-1 to DS-5 policy controls

---

## 8. Operations Cadence

### Daily Automated Rhythm

| Time (AEST) | Task | Who |
|---|---|---|
| 12:00 AM | Midday cost snapshot | Forge |
| 1:00 AM | Auto-heal (12 checks, auto-fix) | Yoda (systemEvent) |
| 2:00 AM | Workspace backup | Forge |
| 3:00 AM | Holocron daily update (Notion sync) | Yoda isolated |
| 6:00 AM | OpenClaw update check + TRIGGER-04/06 | Forge |
| 7:45 AM | Daily memory hygiene | Yoda isolated |
| 8:00 AM | Morning stand-up → Telegram (Ken) | Yoda isolated |
| 10:00 AM | Warden model compliance (every 15 min) | Warden isolated |
| 10:00 PM | Shield / Lex / Sage daily review | Each isolated |
| 11:00 PM | Yoda → Aria context sync | Yoda (main) |
| 11:45 PM | Aria daily summary | Aria (business session) |
| 11:55 PM | End-of-day close (journal + blog) | Yoda (main) |

### Weekly
- Tuesday + Thursday 7:30AM AEST: LinkedIn posts (Spark)
- Wednesday 12PM AEST: LinkedIn post (Spark)
- Sunday 5PM AEST: Weekly Business ROI summary → Angie (Aria)
- Sunday 5PM AEST: Asset registry review (Forge)

### Monthly/Quarterly
- 28th: Model strategy review (Ken sign-off)
- 1st Jan/Apr/Jul/Oct: Full asset audit (Ken sign-off)

---

## 9. Key Infrastructure Decisions Made

| Decision | Rationale | Date |
|---|---|---|
| OpenClaw as platform (final — no replatforming) | Native multi-agent, self-hosted, extensible | Apr 2026 |
| Notion as single KB (Obsidian retired) | Better collaboration (Angie access), API-first | May 3 2026 |
| Dual-bot Telegram (Yoda + Aria separate) | Prevents cross-contamination; Angie receives from Aria only | Apr 2026 |
| Star Wars naming convention | Differentiates, memorable, aligns team culture | May 3 2026 |
| SOUL.md < 5,000 chars (hard standard) | Prevents gateway OOM crashes (confirmed incident Apr 30) | Apr 30 2026 |
| 4-tier model strategy | Cost control + data sovereignty; Tier 0/1 for client data | May 2 2026 |
| AI Charter + Governance Framework | Legal/ethical foundation before first client | May 4 2026 |
| HIVE architecture (OC1 + OC2-A/B) | HA, local inference, cost control post-OC2 | May 2026 |

---

## 10. Security & Compliance Controls (S1–S7)

| Control | What | Status |
|---|---|---|
| S1 | OpenClaw ≥ v2026.1.29 (CVE-2026-25253 patched) | ✅ Live (v2026.5.5) |
| S2 | Gateway bind = loopback only. Port 18789 never public. Remote via Tailscale. | ✅ Live |
| S3 | No ClawHub skills on production. All skills custom-built. Weekly audit. | ✅ Live |
| S4 | Least privilege per agent. Governance agents read-only filesystem. | ✅ Live (CHG-0176) |
| S5 | No hardcoded credentials. Keychain + env vars only. | ✅ Live |
| S6 | All CHG entries logged. Warden model compliance. Incident log current. | ✅ Live |
| S7 | Workspace encrypted. NAS encrypted (post-OC2). | ⚠️ Partial (NAS pending OC2) |

---

## 11. Open Strategic Questions (for Research)

These are the questions AInchors is actively thinking through as it scales from P1 to P2+:

1. **Market positioning:** How do AI-native consulting firms differentiate from traditional IT/digital transformation firms that are adding AI to their service line? What's the right value proposition for SMEs in Southeast Asia?

2. **Pricing model:** What pricing models work for AI consulting and managed AI platforms? Retainer? Per-agent? Outcome-based? What do comparable firms charge?

3. **First client acquisition:** What's the most effective GTM for a bootstrapped AI consulting firm with no case studies yet? How do firms convert a founder's personal brand (LinkedIn) into B2B leads?

4. **Course market:** What AI training content is most in demand for non-technical executives and business operators in Australia/SE Asia? What platforms (Udemy, self-hosted, corporate) work best at this stage?

5. **Competitive landscape:** Who are the key players in the SME AI consulting and managed AI operations space in Australia and SE Asia? What's their offer, pricing, and positioning?

6. **OC2 readiness:** What HA patterns work best for a 2-node Mac Mini M4 Pro setup running Ollama + OpenClaw? What are the failure modes and mitigations?

7. **Agent platform alternatives:** How does OpenClaw compare to CrewAI, AutoGen, LangGraph, and other agent orchestration frameworks at the SME consulting scale? (TRIGGER-06: OpenClaw v4.0 ships → assess)

8. **Data sovereignty compliance:** What are the Australian Privacy Principles (APP) requirements most relevant to a firm running AI agents that process client data? What's the compliance checklist for P2 client onboarding?

9. **Training content format:** What's the optimal format for practical AI operations training — cohort-based live workshops, async video, structured written guides? What conversion rates do AI training products typically see?

10. **LinkedIn AIOps content:** What content formats and angles are performing best for technical founders building in public on LinkedIn in 2025–2026? What's the typical trajectory from 0 to first B2B inquiry?

---

## 12. Key Files & References (Internal)

| Resource | Location | Contents |
|---|---|---|
| MEMORY.md | `workspace/MEMORY.md` | Yoda's long-term memory — all key decisions, facts, IDs |
| AI Charter v1.0 | `workspace/docs/AI_CHARTER_v1.0.md` | Approved governance principles |
| AI Governance Framework | `workspace/docs/AI_GOVERNANCE_FRAMEWORK_v1.0.md` | Operational governance machinery |
| RULES.md | `workspace/RULES.md` | Yoda's full operating procedures |
| YODA_RULES.md | `workspace/YODA_RULES.md` | Yoda-specific rules |
| ARIA_RULES.md | `workspace-business/ARIA_RULES.md` | Aria's operating rules |
| Training Pipeline | `workspace/state/training-pipeline.md` | 33 content ideas |
| Holocron | Notion (AKB) | Single KB — architecture, backlog, decisions, agent ops |
| CHANGELOG.md | `workspace/memory/CHANGELOG.md` | All CHG entries (CHG-0001 to CHG-0199+) |

---

*Generated by Yoda 🟢 | AInchors AI Ops Lead | 2026-05-07 00:04 AEST*
*This document reflects the state of the platform as of Day 12 of AInchors' operation.*
