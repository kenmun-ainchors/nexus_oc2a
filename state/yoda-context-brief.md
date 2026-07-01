# Yoda Telegram Context Brief
# Generated: Wed 1 Jul 2026 20:00 AEST | Day 68 (since 2026-04-25)
# Auto-refreshed: 2pm + 8pm AEST daily

## Platform Status
- **Day:** 68 since launch (2026-04-25)
- **OC1:** Mac Mini M4 24GB — LIVE Production. No local LLM >~8B Q4.
- **OC2-A/B:** Mac Mini M4 Pro 48GB ×2 — ETA 6–13 Jul 2026, commission ~27 Jul.
- **Tailscale:** Active mesh. OC1 IP: 100.91.60.36
- **Docker:** Colima runtime (Docker Desktop removed 2026-05-11)
- **MinIO:** Live on OC1 (port 9000)
- **PG:** PostgreSQL active, SSOT gap remediation in progress (TKT-0342 epic)

## Key People
- **Ken Mun** — CTO, co-founder. kenmun@ainchors.com | +61403650578
- **Angie Foong** — CEO, co-founder. angie.foong@ainchors.com | +61430928371
- **AInchor Solutions Pty Ltd** — ainchors.com | Sydney + Melbourne
- **Aevlith Technologies Pty Ltd** — Technology holding (Nexus platform). Domain: aevlith.ai

## Agent Architecture (Governance Tier Model)
- **T0:** Yoda (lead orchestrator)
- **T1:** Aria (dual-principal: CEO+Yoda)
- **T2:** Warden (model compliance, 15-min cron)
- **T3:** Spark, Atlas, Thrawn, Lando, Forge, Mon Mothma, Krennic
- **T4:** Shield (security), Lex (legal), Sage (QA) — reactive verdict-only
- **Key rule:** Build/scripts → Forge ONLY. Yoda = Plan/Verify; Forge = Execute.

## Current Sprint: Sprint 9 (2026-06-22 → 2026-06-28)
- **Status:** In progress (past end date — auto-rollover enabled)
- **Capacity:** 16 items (exception to 6-item rule, Ken approved)
- **Key items:** TKT-0530, TKT-0394 (Tribal Knowledge Audit — P1), TKT-0344, TKT-0358 (PG table health monitor — critical), TKT-0359, TKT-9991, TKT-0761, TKT-0764
- **Done items:** TKT-0725, TKT-0330, TKT-0726, TKT-0720, TKT-0357, TKT-0390, TKT-0343, TKT-0761, TKT-0764
- **Note:** Sprint 9 was a 16-item exception. Auto-rollover enabled — unfinished items roll into Sprint 10.

## Approved Decisions (from MEMORY.md)
1. **Exec Guard Revoked (CHG-0788, 2026-06-28):** Ken override — exec guard removed due to operational outage wall. FORGE EXECUTE GATE remains (scripts/infra/build → Forge only).
2. **CREST v1.3 (CHG-0680, 2026-06-20):** External loop ownership (Yoda owns CREST), Sage-as-Judge, capability-based multi-model routing. Verify primary: gemma4:31b-cloud (20/20 benchmark).
3. **Model Routing (CHG-0596, 2026-06-15):** Yoda/Aria default = kimi-k2.7-code:cloud. GLM-5.2:cloud adopted for design_backend Plan. Deepseek-v4-pro:cloud demoted to fallback.
4. **LinkedIn Campaign (CHG-0594, 2026-06-15):** 4-week Foundation Arc, 3 posts/week (Tue/Wed/Thu), alternating Theme A/B. Voice: NO AInchors, NO agent names, NO platform internals.
5. **Sprint 9 Exception (2026-06-21):** 16-item sprint to deliver TKT-0342 + TKT-0368 before OC2 arrival.
6. **CREST Groom vs Plan (2026-06-22):** Groom = analyze/refine scope. Plan = execution plan. Keep separate.

## Open Tickets — Top 10 by Priority
1. **TKT-0342** — EPIC: PG SSOT Gap Remediation (critical, Sprint 10)
2. **TKT-0358** — Create PG table health monitor cron (critical, Sprint 11)
3. **TKT-0125** — Roadmap Refinement — QBR 2026-Q3 (P1, Unassigned)
4. **TKT-0130** — Agent Fleet Review — QBR 2026-Q3 (P1, Unassigned)
5. **TKT-0394** — Tribal Knowledge Audit — QBR 2026-Q3 (P1, Sprint 9)
6. **TKT-0114** — AInchors–Aevlith partnership (high, pending, Unassigned)
7. **TKT-0127** — Agentic Marketing Org Design (high, backlog, Unassigned)
8. **TKT-0128** — Aria: expanded marketing orchestration (high, backlog, Unassigned)
9. **TKT-0136** — AInchors Consulting Playbook (high, backlog, Sprint 8)
10. **TKT-0138** — Business Jumpstart — 3-part client pathway (high, backlog, Sprint 8)

## LinkedIn Campaign Status
- **Active:** 4-Week Foundation Arc, Movement III "The Rebuild" (Week 3)
- **Current theme:** Theme B — "Building AI Operations in Public"
- **This week's posts:**
  - Tue 30 Jun 07:30 — LI-W3-P7 "The rebuild that changed how I work" ✅ posted
  - Wed 1 Jul 12:00 — LI-W3-P8 "What 'context discipline' actually means" ✅ approved, posting now
  - Thu 2 Jul 07:30 — LI-W3-P9 "The governance stack I built because I couldn't trust the model" ✅ approved
- **Next theme switch:** Mon 30 Jun (to Theme A for Week 4)
- **Stream:** Ken personal profile (since CHG-0739, 2026-06-23)
- **Voice rules:** NO AInchors, NO Yoda, NO Nexus, NO agent names, NO platform internals, NO em-dashes, NO "co-founder", NO finite time references, NO consulting-speak
- **Missed slot rule:** Push to next available slot. If slot taken, skip. Never post late.

## Ollama Usage / Burn Status
- **Last check:** 2026-07-01 19:08 AEST
- **Session:** 16 requests used (0.1% of 16,000 limit)
- **Weekly window:** 2026-06-29 → 2026-07-06 (4.62 days remaining)
- **Burn rate:** 0.3 req/hr
- **Alert level:** SILENT — all thresholds well below minimum
- **50% warn:** 15,000 | **70% alert:** 21,000 | **85% critical:** 25,500 | **95% emergency:** 28,500

## Mandatory Rules for Telegram Sessions
1. **NO fabrication** — say "I don't know" and find out.
2. **Evidence-only** — done = validated + artifact-backed. Vibe ≠ fact.
3. **CREST mandatory** — load skill before execution work.
4. **Orchestrator only** — Yoda = Plan/Verify/Replan/Synthesize/Close. Execute = Forge.
5. **FORGE EXECUTE GATE** — Yoda NEVER directly edits scripts/, infra/, or build/config files.
6. **CHG discipline** — structural changes need CHG record before execution.
7. **Security first** — S1–S7 controls always live. Warden always watching.
8. **Data sovereignty** — client data = Tier 0/1 local ONLY.
9. **Sanctum protocol** — external/client outputs pass Shield → Lex → Sage.
10. **Telegram chunking** — all messages ≤ 3,800 chars.
11. **Journal discipline** — append to memory/journal-YYYY-MM-DD.md after every meaningful exchange.
12. **Lessons registry** — check LESSONS.md before implementation. Log lessons after fixes.
13. **Skill-first** — load skill before domain scripts. `bash scripts/skill-load.sh <name>`
14. **Subagent dispatch** — load subagent-dispatch skill first. Cross-agent subagents = read-only by default.
