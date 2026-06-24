# Yoda Telegram Context Brief
# Auto-refreshed: Wednesday, June 24th, 2026 - 8:00 PM AEST
# Platform Day: 60 (from 2026-04-25)
# Current Sprint: Sprint 9 (2026-06-22 to 2026-06-28) — COMMITTED
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
- **CHG-0680 (2026-06-20):** CREST v1.3 EXECUTED and verified. Sage-as-Judge, external loop ownership, capability-based multi-model routing. All tiers A-D complete. UAT passed.
- **CHG-0690 (2026-06-20):** Yoda/Aria CREST Plan/Replan primary -> kimi-k2.7-code:cloud (91.5% benchmark).
- **CHG-0691 (2026-06-20):** Aria default chat model = kimi-k2.7-code:cloud, matching Yoda.
- **CHG-0685 (2026-06-20):** GLM-5.2:cloud adopted for design_backend Plan role. Verify role not viable.
- **CHG-0677/0678/0679 (2026-06-20):** Notion + Agile skill packages canonical. Skill-first enforcement for all Notion scripts.
- **Ken 2026-06-21:** Yoda CREST/Forge self-correction — Yoda NEVER directly edits scripts/, infra/, or build/config files. Execute routes to Forge.
- **Ken 2026-06-22 17:13 AEST:** CREST Groom vs Plan process locked — Groom first (analyze/refine/surface clarifications), then CREST Plan (execution plan). Keep separate.

## Open Tickets (Top 10 by Priority)
| ID | Title | Status | Priority | Sprint |
|----|-------|--------|----------|--------|
| TKT-0342 | EPIC: PG SSOT Gap Remediation | open | critical | Sprint 9 |
| TKT-0344 | Wire state_model_policy to live PG write | open | critical | Sprint 9 |
| TKT-0358 | Create PG table health monitor cron | open | critical | Sprint 11 |
| TKT-0125 | Roadmap Refinement — QBR 2026-Q3 instance | open | P1 | |
| TKT-0130 | Agent Fleet Review — QBR 2026-Q3 instance | open | P1 | |
| TKT-0114 | AInchors-Aevlith Technologies partnership structure | pending | high | |
| TKT-0187 | Cloudflare Tunnel — MinIO + OpenClaw | pending | high | |
| TKT-0293 | Expand Regression Testing Framework | open | high | |
| TKT-0328 | (in progress, title lost during migration) | monitoring | high | |
| TKT-0329 | Thrawn Assessment — Workspace Sandbox | open | high | Sprint 8 |

## LinkedIn Campaign Status
- **Status:** ACTIVE — 4-Week Foundation Arc (restarted 2026-06-16)
- **Current week:** Week 2 (Movement II: The Audit) — Theme B (Building AI Operations in Public)
- **Posted this week:** W2-P4 (Tue 23 Jun 07:30 — re-targeted to Ken personal profile per CHG-0739), W2-P5 (Wed 24 Jun 12:00 — "The 92% rule" — posted by Spark cron 833ee0c7)
- **Upcoming:** Thu 25 Jun 07:30 (W2-P6 — "The quality gate I thought I had (and didn't)" — approved, image ready)
- **Stream:** Ken personal profile (effective from 2026-06-23 per CHG-0739). Company page posts discontinued.
- **Voice:** Ken Mun, CTO — first-person, direct, no fluff. NO AInchors/Yoda/Nexus/agent names.
- **Missed-slot rule:** Push to next slot. If occupied, skip. Never post late.
- **Pipeline:** Weekend batch draft (Sat 12:00) -> review -> publish at slot. Never draft at publish time.

## Ollama Usage / Burn Alert (as of 2026-06-22 20:00 AEST)
- Weekly limit: 94,185 requests (new window started 2026-06-22)
- Current: 2,543 requests (2.7% used)
- Days remaining: 6.58 (window ends Mon 29 Jun 10:00 AEST)
- Burn rate: 317.7 req/hr
- **Alert level:** SILENT — all thresholds well below minimum. No action needed.

## Mandatory Rules for Telegram Sessions
1. **Yoda/Aria CREST:** Plan/Replan primary = kimi-k2.7-code:cloud. Execute NEVER without Ken approval.
2. **No fabrication.** Say "I don't know" and find out.
3. **Evidence-only.** Done = validated + backed by artifacts.
4. **Skill-first:** Load skill before any domain script (bash scripts/skill-load.sh <skill>).
5. **CHG discipline:** Every structural change needs a CHG record before execution.
6. **Telegram chunking:** All messages MUST be chunked at 3,800 chars.
7. **Sanctum protocol:** External/client outputs pass Shield -> Lex -> Sage.
8. **Data sovereignty:** Client data = Tier 0/1 local ONLY. No exceptions.
9. **Build/scripts -> Forge ONLY.** Yoda NEVER directly edits scripts/, infra/, or build/config files. Plan/Verify = Yoda; Execute = Forge via sessions_spawn(agentId="infra").
10. **Subagent-dispatch:** verifier_corpus MANDATORY for any execute/verify atom.
11. **Journal discipline:** Append after every meaningful Ken exchange.
12. **Model routing SSOT:** state/model-policy.json. Query via scripts/model-policy-query.sh.
13. **CREST v1.3:** EXECUTED and verified. Sage-as-Judge operational. Capability-based multi-model routing active.
14. **CREST Groom vs Plan:** Groom first (analyze/refine/surface clarifications). Then CREST Plan (execution plan). Keep separate.

# END BRIEF
