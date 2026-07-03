# Yoda Telegram Context Brief
# Generated: 2026-07-03 20:00 AEST | Platform Day 70 (since 2026-04-25)

---

## Platform Status
- **Platform Day:** 70 (since 25 Apr 2026)
- **Company:** AInchor Solutions Pty Ltd | ainchors.com
- **HoldCo:** Aevlith Technologies Pty Ltd — technology holding, Nexus platform owner. Domain: aevlith.ai.
- **Infrastructure:** OC1 (Mac Mini M4 24GB) — LIVE Production
- **OC2-A/B** (Mac Mini M4 Pro 48GB x2) — ETA 6-13 Jul 2026, commission ~27 Jul 2026

## Key People
- **Ken Mun** — Co-founder, CTO. kenmun@ainchors.com | +61403650578
- **Angie Foong** — Co-founder, CEO. angie.foong@ainchors.com | +61430928371

## Current Sprint — Sprint 10 (29 Jun - 5 Jul 2026)
- **Status:** Committed | **Tickets:** 17 | **Done:** 3 (17.6%)
- **Key tickets:** EPIC PG SSOT Gap Remediation (TKT-0342, critical), Agent Fleet QBR Review (TKT-0130, P1), Roadmap Refinement QBR (TKT-0125, P1), Sandbox Runbook (TKT-0191), ClawGuard (TKT-0179), Process Documentation Framework (TKT-0110).

## Top Open Tickets (by priority)
1. **TKT-0342 (critical)** — EPIC: PG SSOT Gap Remediation — Sprint 10
2. **TKT-0358 (critical)** — PG Table Health Monitor Cron — Sprint 11
3. **TKT-0125 (P1)** — Roadmap Refinement QBR 2026-Q3 — Unassigned
4. **TKT-0130 (P1)** — Agent Fleet Review QBR 2026-Q3 — Unassigned
5. **TKT-0329 (high)** — Thrawn Assessment — Workspace Sandbox — Sprint 8
6. **TKT-0331 (high)** — Skill-Based Encapsulation — Unassigned
7. **TKT-0293 (high)** — Expand Regression Testing Framework — Unassigned
8. **TKT-0345 (high)** — Wire state_linkedin to live PG writes — Unassigned
9. **TKT-0346 (high)** — Wire state_diagnostics to automated PG write — Unassigned
10. **TKT-0349 (high)** — Wire state_policies to automated PG write — Unassigned
11. **TKT-0352 (high)** — Wire knowledge_documents+chunks to PG — Sprint 10
12. **TKT-0353 (high)** — Wire state_governance to automated PG write — Unassigned
13. **TKT-0354 (high)** — Wire state_standups to PG-first — Sprint 10
14. **TKT-0355 (high)** — Verify Gateway-internal PG write paths — Unassigned
15. **TKT-0356 (high)** — Audit + resolve 8 empty PG tables — Unassigned

## Approved Decisions (from MEMORY.md)
- **Governance Tier Model** (2026-05-08, TKT-0103): T0 Yoda / T1 Aria / T2 Warden / T3 Spark, Atlas, Thrawn, Lando, Forge, Mon Mothma, Krennic / T4 Shield, Lex, Sage
- **CREST Mandatory** (CHG-0545, 2026-06-13): All execution work uses CREST. Yoda = Plan/Verify/Replan/Synthesize/Close only. Execute = Forge.
- **Forge Execute Gate** (SOUL.md #16): Yoda NEVER directly edits scripts/, infra/, or build/config files. Routes to agentId="infra".
- **LinkedIn Campaign v3.0** (CHG-0594, 2026-06-15): 4-week Foundation Arc, 12 posts. Tue/Wed/Thu slots. No AInchors/Yoda/Nexus mentions.
- **3-DB Notion Architecture** (CHG-0401): DB A (Backlog), DB B (Auto-Heal), DB C (Archive).
- **Subagent completion update rule** (Ken directive 2026-07-03, CHG-0812): Yoda must send visible status when dispatching subagents + summarise on completion.
- **Port Convention** (locked 2026-06-08): Production=1xxxx, Sandbox=2xxxx, Shadow=3xxxx.

## LinkedIn Campaign Status (4-Week Foundation Arc)
- **Schedule:** Tue 07:30, Wed 12:00, Thu 07:30 AEST
- **Week 3 (Movement III. The Rebuild):**
  - LI-W3-P7 (Tue 30 Jun) — Approved, ready
  - LI-W3-P8 (Wed 1 Jul) — Approved, ready
  - LI-W3-P9 rescheduled to LI-W4-P10 (Tue 7 Jul due to missed-slot rule)
- **Week 4:** LI-W4-P10 (Tue 7 Jul) — governance theme, approved + imaged
- **Posting stream:** Ken Mun personal profile (since CHG-0739/CHG-0745, 23 Jun)
- **Voice rules (non-negotiable):** No AInchors, Yoda, Nexus, agent names, platform internals, no em-dashes, no "co-founder", no finite time references, no consulting-speak.
- **Missed slot rule:** Push to next available slot. If slot occupied, skip. Never post late.
- **Cron IDs:** Tue=13b0aa89, Wed=833ee0c7, Thu=869502c9

## Ollama Usage / Burn Status
- **Weekly Limit:** 73,184 requests | **Used:** 5,562 (7.6%) | **Burn Rate:** 69.5 req/hr
- **Thresholds:** 50%=36,592 / 70%=51,229 / 85%=62,206 / 95%=69,525
- **Status:** SILENT — all thresholds clear. No action needed.
- **Next check:** Cron at 05:00 + 17:00 AEST daily.

## Agent Architecture
- **Governance Tier Model:** T0 Yoda / T1 Aria / T2 Warden / T3 Spark/Atlas/Thrawn/Lando/Forge/Mon Mothma/Krennic / T4 Shield/Lex/Sage
- **Yoda role:** Lead AI Ops Agent — Nexus Platform Orchestrator. Routes tasks by domain.
- **Runtime Registry IDs:** main=yoda, business=aria, architect=atlas, platform-arch=thrawn, infra=forge, social=spark, biz-process=lando, change-mgt=mon-mothma, security=shield, legal=lex, qa=sage, governance=warden

## Mandatory Rules for Telegram Sessions
1. **CHG discipline** — Every structural change has a CHG record before execution.
2. **CREST mandatory** — Every execution plan runs through CREST. Load: bash scripts/skill-load.sh crest
3. **Forge Execute Gate** — Yoda NEVER directly edits scripts/infra/build. Route to agentId="infra".
4. **Skill-first** — Before calling any domain script, load its skill: bash scripts/skill-load.sh <skill>.
5. **Telegram chunking** — Messages at 3,800 char chunks. Load: bash scripts/skill-load.sh telegram.
6. **No fabrication** — Say "I don't know" and find out.
7. **Evidence-only** — Done = validated + artifact-backed.
8. **Subagent update rule** — Send visible status on dispatch + summarise on completion.
9. **Port convention** — Prod=1xxxx, Sandbox=2xxxx, Shadow=3xxxx. Never cross.
10. **Sanctum protocol** — External/client outputs pass Shield -> Lex -> Sage.
11. **Data sovereignty** — Client data = Tier 0/1 local only. No exceptions.
12. **CREST Orchestrator-only** — Yoda = Plan/Verify/Replan/Synthesize/Close. Execute = Forge.

---

*Brief auto-generated at 2026-07-03 20:00 AEST. For full context, read MEMORY.md + state/ files + db-ticket list --open.*