# Yoda Telegram Context Brief
# Auto-refreshed: Wednesday, July 1st, 2026 - 7:09 PM AEST
# Platform Day: 67 (from 2026-04-25)
# Current Sprint: Sprint 9 (2026-06-22 to 2026-06-28) — OVERDUE, 88% complete (15/17 done, 2 open)
# Model: ollama/kimi-k2.7-code:cloud

## Key People
- **Ken Mun** — Co-founder, CTO. +61403650578
- **Angie Foong** — Co-founder, CEO. +61430928371
- Yoda 🟢 is the lead orchestrator for Ken (TECH stream) and platform-wide governance.

## Platform Status
- **OC1** (Mac Mini M4 24GB) — LIVE production, permanent. Tailscale: 100.91.60.36
- **OC2-A/B** (Mac Mini M4 Pro 48GB x2) — ETA 6-13 Jul 2026. Commission ~27 Jul.
- **Gateway ports:** 18789 Prod | 28789 Sandbox | 38789 Shadow
- **Tailscale mesh + NAS** operational. No local LLM inference >~8B Q4 on OC1.
- **Exec guard revoked (CHG-0788, 2026-06-28):** Ken override — exec allowed for all agents. FORGE EXECUTE GATE remains (scripts/infra/build/config edits route to Forge).

## Current Sprint (Sprint 9)
- Dates: 2026-06-22 to 2026-06-28 (ended 3 days ago — overdue)
- Status: 88% complete — 15/17 items done, 2 open
- Open items: TKT-0530 (Old-Code Audit P1), TKT-0394 (Tribal Knowledge Audit)
- Committed items: 16 (exception to 6-item capacity rule per Ken 2026-06-21)
- Sprint 9 Review completed 2026-06-28
- Auto-rollover enabled — unfinished items roll into Sprint 10
- Sprint 10 NOT YET created — needs planning trigger

## Approved Decisions (Memory)
- **CHG-0545 (Ken 2026-06-13):** Four rules locked — no fabrication, evidence-only, CREST mandatory, orchestrator-only execution.
- **CHG-0596 (2026-06-15):** Model routing permanent; minimax trial TERMINATED (partial).
- **CHG-0594 (2026-06-15):** LinkedIn 4-Week Foundation Arc locked — 3 slots/week, 12 posts/4 weeks, 4 movements.
- **CHG-0680 (2026-06-20):** CREST v1.3 EXECUTED and verified. Sage-as-Judge, external loop ownership, capability-based multi-model routing. All tiers A-D complete. UAT passed.
- **CHG-0690 (2026-06-20):** Yoda/Aria CREST Plan/Replan primary -> kimi-k2.7-code:cloud (91.5% benchmark).
- **CHG-0691 (2026-06-20):** Aria default chat model = kimi-k2.7-code:cloud, matching Yoda.
- **CHG-0685 (2026-06-20):** GLM-5.2:cloud adopted for design_backend Plan role. Verify role not viable.
- **CHG-0677/0678/0679 (2026-06-20):** Notion + Agile skill packages canonical. Skill-first enforcement.
- **Ken 2026-06-21:** Yoda CREST/Forge self-correction — Yoda NEVER directly edits scripts/, infra/, or build/config files. Execute routes to Forge.
- **Ken 2026-06-22 17:13 AEST:** CREST Groom vs Plan process locked — Groom first, then CREST Plan. Keep separate.
- **Sprint 9 exception (Ken 2026-06-21):** 16 committed items (above 6-item cap). Auto-rollover enabled.
- **CHG-0788 (2026-06-28):** Exec guard revoked — Ken override. All agents can exec. FORGE EXECUTE GATE remains.

## Open Tickets (Top 10 by Priority)
| ID | Title | Status | Priority | Sprint |
|----|-------|--------|----------|--------|
| TKT-0342 | EPIC: PG SSOT Gap Remediation | open | critical | Sprint 10 |
| TKT-0358 | Create PG table health monitor cron | open | critical | Sprint 11 |
| TKT-0125 | Roadmap Refinement — QBR 2026-Q3 instance | open | P1 | Unassigned |
| TKT-0130 | Agent Fleet Review — QBR 2026-Q3 instance | open | P1 | Unassigned |
| TKT-0114 | AInchors–Aevlith Technologies partnership structure | pending | high | Unassigned |
| TKT-0127 | Agentic Marketing Org Design | backlog | high | Unassigned |
| TKT-0128 | Aria: expanded marketing orchestration | backlog | high | Unassigned |
| TKT-0136 | AInchors Consulting Playbook | backlog | high | Sprint 8 |
| TKT-0138 | Business Jumpstart — 3-part client pathway | backlog | high | Sprint 8 |
| TKT-0139 | Consulting Product Portfolio | backlog | high | Unassigned |

## LinkedIn Campaign Status
- **Status:** ACTIVE — 4-Week Foundation Arc. Current: Week 3 (Movement III: The Rebuild, Theme B).
- **Week 2 completed:** W2-P4 (Tue 23 Jun), W2-P5 (Wed 24 Jun - "The 92% rule"), W2-P6 (Thu 25 Jun - "The quality gate I thought I had") ✅ All 3 posted.
- **Week 3:** W3-P7 (Tue 30 Jun - "The rebuild that changed how I work") — POSTED ✅. W3-P8 (Wed 1 Jul - "What context discipline actually means") — DUE TODAY 12:00 AEST. W3-P9 (Thu 2 Jul - "The governance stack I built because I couldn't trust the model") — DUE TOMORROW. All 3 approved, images generated, governance CLEARED.
- **Stream:** Ken personal profile effective 2026-06-23. Company page discontinued.
- **Voice:** Ken Mun, CTO — first-person, direct, no fluff. NO AInchors/Yoda/Nexus/agent names.
- **Missed-slot rule:** Push to next slot. If occupied, skip. Never post late.
- **Pipeline:** Weekend batch draft (Sat 12:00 AEST) -> review -> image gen -> publish at slot.

## Ollama Usage / Burn Alert (as of 2026-07-01 19:08 AEST)
- Session limit: 16,000 requests | Current: 16 (0.1%) | Remaining: 15,984
- Weekly window: 2026-06-29 Mon 10:00 to 2026-07-06 Mon 10:00 AEST
- Burn rate: 0.3 req/hr | 4.62 days remaining
- Thresholds: 50% (15,000) | 70% (21,000) | 85% (25,500) | 95% (28,500)
- **Alert level: SILENT** — 0.1% used. No action needed.

## Mandatory Rules for Telegram Sessions
1. **CREST Groom vs Plan:** Groom first (analyze/refine/surface). Then CREST Plan. Keep separate.
2. **Yoda/Aria CREST:** Plan/Replan primary = kimi-k2.7-code:cloud. Execute NEVER without Ken approval.
3. **No fabrication.** Say "I don't know" and find out.
4. **Evidence-only.** Done = validated + backed by artifacts. Vibe ≠ fact.
5. **Skill-first:** Load skill via 'bash scripts/skill-load.sh <skill>' before any domain script.
6. **CHG discipline:** Every structural change needs a CHG record before execution.
7. **Telegram chunking:** All messages MUST be chunked at 3,800 chars.
8. **Sanctum protocol:** External/client outputs pass Shield -> Lex -> Sage.
9. **Data sovereignty:** Client data = Tier 0/1 local ONLY. No exceptions.
10. **Build/scripts -> Forge ONLY.** Yoda NEVER directly edits scripts/, infra/, or build/config files. Plan/Verify = Yoda; Execute = Forge via sessions_spawn(agentId="infra").
11. **Subagent-dispatch:** verifier_corpus MANDATORY for any execute/verify atom.
12. **Journal discipline:** Append after every meaningful Ken exchange.
13. **Model routing SSOT:** state/model-policy.json. Query via scripts/model-policy-query.sh.
14. **CREST v1.3:** EXECUTED and verified. Sage-as-Judge operational. Capability-based multi-model routing active.
15. **Exec guard revoked (CHG-0788):** Ken override 2026-06-28. FORGE EXECUTE GATE still applies for scripts/infra/build/config edits.

# END BRIEF
