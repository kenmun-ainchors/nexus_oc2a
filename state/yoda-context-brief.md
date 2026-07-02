# Yoda Telegram Context Brief — 2026-07-02 20:00 AEST

## Platform Status
- **Platform Day:** 68 (from 2026-04-25)
- **Date:** Thursday, 2 July 2026 — 20:00 AEST (UTC+10)
- **Model Running:** DeepSeek V4 Flash (cloud)
- **Default Model:** Kimi K2.7 Code (cloud)

## Key People
- **Ken Mun** — CTO, main human. Telegram + webchat.
- **Angie Foong** — CEO. Business stream lead.
- **Aria** (business) — Dual-principal (CEO+Yoda T1)
- **Atlas** (architect) — EA/strategy
- **Thrawn** (platform-arch) — Platform/infra design
- **Forge** (infra) — Build/scripts execution
- **Spark** (social) — LinkedIn campaign
- **Lando** (biz-process) — BPM
- **Mon Mothma** (change-mgt) — Change records
- **Shield/Lex/Sage** — T4 reactive governance (security/legal/QA)
- **Warden** — Model compliance (15-min cron)
- **Ahsoka** — Client discovery/delivery

## Infrastructure
- **OC1:** Mac Mini M4 24GB — LIVE Production. No local LLM >~8B Q4.
- **OC2-A/B:** Mac Mini M4 Pro 48GB x2 — ETA 6-13 Jul 2026. Commission ~27 Jul.
- **Tailscale mesh** — OC1 IP: 100.91.60.36
- **Colima:** Docker runtime (replaces Docker Desktop)
- **Gateway Ports:** Prod 18789 | Sandbox 28789 | Shadow 38789
- **PG:** PostgreSQL active (db-ticket.sh + db-sprint.sh)
- **Notion:** 3-DB architecture (Backlog, Auto-Heal, Archive)

## Current Sprint — Sprint 10 (2026-06-29 to 2026-07-05)
- **Status:** Committed | 17 tickets | 3 done (17.6%) | 13 open
- **Key epic:** TKT-0342 — PG SSOT Gap Remediation (critical)
- **Sprint 10 high-priority items:**
  - TKT-0722 — verdict_log PG table + replace state/sage-verdicts (critical)
  - TKT-0352 — Wire knowledge_documents + knowledge_chunks to PG (high)
  - TKT-0354 — Wire state_standups to PG (high)
  - TKT-0394 — Tribal Knowledge Audit — QBR 2026-Q3 (P1)
  - TKT-0530 — Old-Code Audit P1 (Sprint 9) (P1)
  - TKT-0723 — DNA leanness: dedupe rules (high)
  - TKT-0749 — db-sprint.sh commit --sprint flag ignored (high)
  - TKT-0750 — Post-upgrade 7 cron jobs in error (high)
  - TKT-0742 — Fix standup-email-send.sh messageId extraction (medium)
  - TKT-0743 — LinkedIn token health probe (medium)
  - TKT-0769 — yoda-context-brief-refresh cron timeout (medium/monitoring)
- **Sprint 9 auto-rollover active** (oversized by Ken exception)

## Approved Decisions (Recent)
1. **CREST v1.3** — Executed 2026-06-20. Yoda=orchestrator. Sage=Judge.
2. **Model routing locked** — kimi-k2.7-code:cloud primary Yoda+Aria Plan/Replan. glm-5.2:cloud adopted for design_backend Plan. deepseek-v4-pro demoted to fallback.
3. **Exec Guard revoked** (CHG-0788, 2026-06-28) — Ken override. Forge Execute Gate still active.
4. **Yoda/Forge separation** — No direct script edits. Forge executes.
5. **Minimax trial terminated** (2026-06-15) — PARTIAL verdict.
6. **CREST Groom vs Plan** — separate steps. Groom first.
7. **Sprint 9 exception** — 16 items committed. Auto-rollover.
8. **Aria default model** — kimi-k2.7-code:cloud (CHG-0691).
9. **LinkedIn stream** — Ken personal profile from 2026-06-23 (CHG-0739).

## Open Tickets — Top 10 by Priority
| ID | Title | Priority | Sprint |
|----|-------|----------|--------|
| TKT-0342 | PG SSOT Gap Remediation | CRITICAL | Sprint 10 |
| TKT-0722 | verdict_log PG table + replace state/sage-verdicts | CRITICAL | Sprint 10 |
| TKT-0352 | Wire knowledge_documents + knowledge_chunks to PG | HIGH | Sprint 10 |
| TKT-0354 | Wire state_standups to PG | HIGH | Sprint 10 |
| TKT-0723 | DNA leanness: dedupe rules to single canonical source | HIGH | Sprint 10 |
| TKT-0749 | db-sprint.sh commit --sprint flag ignored | HIGH | Sprint 10 |
| TKT-0750 | Post-upgrade 7 cron jobs in error | HIGH | Sprint 10 |
| TKT-0394 | Tribal Knowledge Audit — QBR 2026-Q3 | P1 | Sprint 10 |
| TKT-0530 | Old-Code Audit P1 (Sprint 9) | P1 | Sprint 10 |
| TKT-0114 | AInchors-Aevlith Technologies partnership | HIGH | Unassigned |

Full backlog: 60+ open tickets. Notable: TKT-0125 (Roadmap Refinement QBR), TKT-0130 (Agent Fleet Review QBR), TKT-0187 (Cloudflare Tunnel), TKT-0190 (P2 Gate governance policies).

## LinkedIn Campaign — 4-Week Foundation Arc (Week 3-4)
- **Cadence:** Tue 07:30 / Wed 12:00 / Thu 07:30 AEST
- **Movement III. The Rebuild** — Weeks 3-4
- **Voice:** NO AInchors/Yoda/Nexus/internals/consulting-speak. Ken personal profile.
- **Approved posts queued:**
  - W4-P10 "The governance stack I built because I couldn't trust the model" — Tue 7 Jul 07:30 AEST (rescheduled from Thu 2 Jul after L-141 delimiter fix by Aria)
- **Thu 2 Jul slot:** Empty — W3-P9 renumbered to W4-P10, moved to Tue 7 Jul
- **Batch draft cron:** Sat 12:00 AEST (1cb0c7ff)
- **Publish crons:** Tue 13b0aa89, Wed 833ee0c7, Thu 869502c9
- **All 4 weeks drafted and approved through 7 Jul.** No immediate action needed.

## Ollama Usage / Burn Status
- **Weekly limit:** 80,750 | Used: 323 (0.4%) | Remaining: 80,427
- **Burn rate:** 5.6 req/hr | Alert: SILENT
- **Last check:** 2026-07-01 20:00 AEST — no thresholds threatened

## Mandatory Rules for Telegram Sessions
1. **CREST mandatory** — load skill: bash scripts/skill-load.sh crest
2. **Orchestrator only** — Yoda Plans/Verifies/Synthesizes/Closes. Forge Executes. No exceptions.
3. **No fabrication** — never invent. Say "I don't know" and find out.
4. **Evidence-only** — done = validated + artifact-backed. Vibe is not fact.
5. **No direct script edits** — all script/infra/build/config changes route to Forge (agentId="infra").
6. **CHG discipline** — structural changes need CHG record before execution.
7. **Sanctum protocol** — external outputs pass Shield to Lex to Sage.
8. **Data sovereignty** — client data stays Tier 0/1 local. No exceptions.
9. **Telegram chunking** — all messages MUST be chunked at 3,800 chars. Load skill: bash scripts/skill-load.sh telegram.
10. **Journal discipline** — append via journal-append.sh after every meaningful exchange.
