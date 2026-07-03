# Yoda Telegram Context Brief — 2026-07-03 14:00 AEST

## Platform Status
- **Platform Day:** 69 (from 2026-04-25)
- **Date:** Friday, 3 July 2026 — 14:00 AEST (UTC+10)
- **Model Running:** DeepSeek V4 Flash (cloud)
- **Default Model:** Kimi K2.7 Code (cloud)
- **Gateway Uptime:** 10h 40m · System Uptime: 1d 15h

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
- **OC2-A/B:** Mac Mini M4 Pro 48GB ×2 — ETA 6–13 Jul 2026. Commission ~27 Jul.
- **Tailscale mesh** — OC1 IP: 100.91.60.36
- **Colima:** Docker runtime (replaces Docker Desktop)
- **Gateway Ports:** Prod 18789 | Sandbox 28789 | Shadow 38789
- **PG:** PostgreSQL active (db-ticket.sh + db-sprint.sh)
- **Notion:** 3-DB architecture (Backlog, Auto-Heal, Archive)

## Current Sprint — Sprint 10 (2026-06-29 to 2026-07-05)
- **Status:** Committed | 17 tickets | 3 done (17.6%) | 13 open | 0 in-progress
- **Key criticals:** TKT-0342 (PG SSOT Gap Remediation), TKT-0722 (verdict_log PG table)
- **Sprint 10 high-priority items:**
  - CRITICAL: TKT-0342 — PG SSOT Gap Remediation (epic)
  - CRITICAL: TKT-0722 — verdict_log PG table + replace state/sage-verdicts
  - High: TKT-0352 — Wire knowledge_documents + knowledge_chunks to PG
  - High: TKT-0354 — Wire state_standups to PG
  - High: TKT-0723 — DNA leanness: dedupe rules
  - High: TKT-0749 — db-sprint.sh commit --sprint flag ignored
  - High: TKT-0750 — Post-upgrade 7 cron jobs in error
  - P1: TKT-0394 — Tribal Knowledge Audit — QBR 2026-Q3
  - P1: TKT-0530 — Old-Code Audit P1 (Sprint 9)
  - Medium: TKT-0769 — cron context-brief-refresh timeout (monitoring)
  - Medium: TKT-0742 — Fix standup-email-send.sh messageId extraction
  - Medium: TKT-0743 — LinkedIn token health probe

## LinkedIn Campaign — 4-Week Foundation Arc (Week 3/4)
- **Cadence:** Tue 07:30 / Wed 12:00 / Thu 07:30 AEST
- **Movement III. The Rebuild** — Weeks 3-4
- **Voice:** NO AInchors/Yoda/Nexus/internals/consulting-speak. Ken personal profile.
- **Approved posts queued:**
  - W4-P10 "The governance stack I built because I couldn't trust the model" — Tue 7 Jul 07:30 AEST (rescheduled after L-141 delimiter fix by Aria)
- **Thu 2 Jul slot:** Empty — W3-P9 renumbered to W4-P10, moved Tue 7 Jul
- **Batch draft cron:** Sat 12:00 AEST (1cb0c7ff)
- **Publish crons:** Tue 13b0aa89, Wed 833ee0c7, Thu 869502c9
- **All 4 weeks drafted and approved through 7 Jul.** No immediate action needed.

## Ollama Usage / Burn Status
- **Weekly limit:** 73,184 | Used: 5,562 (7.6%) | Remaining: 67,622
- **Burn rate:** 69.5 req/hr | Alert: SILENT
- **Last check:** 2026-07-02 20:00 AEST — no thresholds threatened
- **50% warn threshold:** 36,592 — currently well under

## Mandatory Rules for Telegram Sessions
1. **CREST mandatory** — load skill: bash scripts/skill-load.sh crest
2. **Orchestrator only** — Yoda Plans/Verifies/Synthesizes/Closes. Forge Executes.
3. **No fabrication** — never invent. Say "I don't know" and find out.
4. **Evidence-only** — done = validated + artifact-backed. Vibe is not fact.
5. **No direct script edits** — all script/infra/build/config changes route to Forge (agentId="infra").
6. **CHG discipline** — structural changes need CHG record before execution.
7. **Sanctum protocol** — external outputs pass Shield to Lex to Sage.
8. **Data sovereignty** — client data stays Tier 0/1 local. No exceptions.
9. **Telegram chunking** — all messages MUST be chunked at 3,800 chars. Load skill: bash scripts/skill-load.sh telegram.
10. **Journal discipline** — append via journal-append.sh after every meaningful exchange.
