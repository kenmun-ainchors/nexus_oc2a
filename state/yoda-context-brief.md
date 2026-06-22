# Yoda Telegram Context Brief
# Auto-refreshed: Monday, June 22nd, 2026 - 2:00 PM AEST
# Platform Day: 58 (from 2026-04-25)
# Current Sprint: Sprint 9 (2026-06-22 to 2026-06-28) — COMMITTED
# Model: ollama/kimi-k2.7-code:cloud

## Key People
- **Ken Mun** — Co-founder, CTO. +61403650578
- **Angie Foong** — Co-founder, CEO. +61430928371
- Yoda 🟢 is the lead orchestrator for Ken (TECH stream) and platform-wide governance.

## Platform Status
- **OC1** (Mac Mini M4 24GB) — LIVE production, permanent. Tailscale: 100.91.60.36
- **OC2-A/B** (Mac Mini M4 Pro 48GB ×2) — ETA 6–13 Jul 2026. Commission ~27 Jul.
- **Gateway ports:** 18789 Prod | 28789 Sandbox | 38789 Shadow
- **Tailscale mesh + NAS** operational. No local LLM inference >~8B Q4 on OC1.

## Current Sprint (Sprint 9)
- Dates: 2026-06-22 to 2026-06-28
- Status: committed (planning completed 2026-06-20)
- Committed items: 16 (exception to 6-item capacity rule per Ken 2026-06-21)
- Priority stack: TKT-0342 (PG SSOT Gap Remediation) and TKT-0368 (CREST v2.0 / Nexus Foundational Architecture) take precedence
- Auto-rollover enabled — unfinished items roll into Sprint 10

## Approved Decisions (Memory)
- **CHG-0545 (Ken 2026-06-13):** Four rules locked — no fabrication, evidence-only, CREST mandatory, orchestrator-only execution.
- **CHG-0596 (2026-06-15):** Model routing permanent; minimax trial TERMINATED (partial).
- **CHG-0594 (2026-06-15):** LinkedIn 4-Week Foundation Arc locked — 3 slots/week, 12 posts/4 weeks, 4 movements.
- **CHG-0680 (2026-06-20):** CREST v1.3 EXECUTED and verified. Sage-as-Judge, external loop ownership, capability-based multi-model routing. All tiers A–D complete. UAT passed.
- **CHG-0690 (2026-06-20):** Yoda/Aria CREST Plan/Replan primary → `kimi-k2.7-code:cloud` (91.5% benchmark).
- **CHG-0691 (2026-06-20):** Aria default chat model = `kimi-k2.7-code:cloud`, matching Yoda.
- **CHG-0685 (2026-06-20):** GLM-5.2:cloud adopted for design_backend Plan role. Verify role not viable.
- **CHG-0677/0678/0679 (2026-06-20):** Notion + Agile skill packages canonical. Skill-first enforcement for all Notion scripts.
- **Ken 2026-06-21:** Yoda CREST/Forge self-correction — Yoda NEVER directly edits scripts/, infra/, or build/config files. Execute routes to Forge.

## Open Tickets (Top 10 by Priority)
| ID | Title | Status | Priority | Sprint |
|----|-------|--------|----------|--------|
| TKT-0125 | Roadmap Refinement — QBR 2026-Q3 instance | open | P1 | |
| TKT-0130 | Agent Fleet Review — QBR 2026-Q3 instance | open | P1 | |
| TKT-0114 | AInchors–Aevlith Technologies partnership structure | pending | high | |
| TKT-0127 | Agentic Marketing Org Design — activation | backlog | high | |
| TKT-0128 | Aria: expanded marketing orchestration | backlog | high | |
| TKT-0136 | AInchors Consulting Playbook — AI Transformation | backlog | high | |
| TKT-0138 | Business Jumpstart — 3-part client engagement | backlog | high | |
| TKT-0139 | Consulting Product Portfolio — commercial | backlog | high | |
| TKT-0169 | Typed Agent Contracts — 4 Cross-Agent Interfaces | backlog | high | |
| TKT-0170 | PII Scanner on Document Ingestion Pipeline | backlog | high | |

## LinkedIn Campaign Status
- **Status:** ACTIVE — 4-Week Foundation Arc (restarted 2026-06-16)
- **Current week:** Week 2 (Movement II: The Audit) — Theme A (What AI Agents in Production Actually Look Like)
- **Posted:** W1-P1 (Tue 16 Jun), W1-P2 (Wed 17 Jun), W1-P3 (Thu 18 Jun) — all posted
- **Upcoming slots:** Tue 23 Jun 07:30 (W2-P4), Wed 24 Jun 12:00 (W2-P5), Thu 25 Jun 07:30 (W2-P6)
- **Drafts ready:** W2-P4, P5, P6 all approved by Ken (2026-06-22) with images. Ready to publish.
- **Voice:** Ken Mun, CTO — first-person, direct, no fluff. NO AInchors/Yoda/Nexus/agent names.
- **Missed-slot rule:** Push to next slot. If occupied, skip. Never post late.
- **Pipeline:** Weekend batch draft (Sat 12:00) → review → publish at slot. Never draft at publish time.

## Ollama Usage / Burn Alert (as of 2026-06-21 20:00 AEST)
- Weekly limit: 64,038 requests
- Current: 49,053 requests (76.6% used)
- Days remaining: ~0.58 (window ended Mon 22 Jun 10:00 AEST)
- Burn rate: 322.7 req/hr
- **Alert level:** ALERT — 70% threshold crossed 2026-06-20. 85% threshold (54,432) not yet crossed. No new alert sent at last check.

## Mandatory Rules for Telegram Sessions
1. **Yoda/Aria CREST:** Plan/Replan primary = `kimi-k2.7-code:cloud`. Execute NEVER without Ken approval.
2. **No fabrication.** Say "I don't know" and find out.
3. **Evidence-only.** Done = validated + backed by artifacts.
4. **Skill-first:** Load skill before any domain script (`bash scripts/skill-load.sh <skill>`).
5. **CHG discipline:** Every structural change needs a CHG record before execution.
6. **Telegram chunking:** All messages MUST be chunked at 3,800 chars.
7. **Sanctum protocol:** External/client outputs pass Shield → Lex → Sage.
8. **Data sovereignty:** Client data = Tier 0/1 local ONLY. No exceptions.
9. **Build/scripts → Forge ONLY.** Yoda NEVER directly edits scripts/, infra/, or build/config files. Plan/Verify = Yoda; Execute = Forge via sessions_spawn(agentId="infra").
10. **Subagent-dispatch:** verifier_corpus MANDATORY for any execute/verify atom.
11. **Journal discipline:** Append after every meaningful Ken exchange.
12. **Model routing SSOT:** `state/model-policy.json`. Query via `scripts/model-policy-query.sh`.
13. **CREST v1.3:** EXECUTED and verified. Sage-as-Judge operational. Capability-based multi-model routing active.

# END BRIEF
