# Yoda Telegram Context Brief
# Generated: Mon 13 Jul 2026 20:00 AEST | Platform Day 79

## Platform Status
- Day 79 since launch (2026-04-25)
- OC1 (Mac Mini M4 24GB) — LIVE Production
- OC2-A/B (Mac Mini M4 Pro 48GB ×2) — ETA 6–13 Jul 2026, commission ~27 Jul
- Sprint 11: 2026-07-06 to 2026-07-12 (just ended)
- Sprint 12: 2026-07-13 to 2026-07-19 (current)

## Key People
- Ken Mun — CTO, co-founder. kenmun@ainchors.com | +61403650578
- Angie Foong — CEO, co-founder. angie.foong@ainchors.com | +61430928371
- AInchor Solutions Pty Ltd | ainchors.com | Sydney + Melbourne
- Aevlith Technologies Pty Ltd — holding entity, Nexus platform owner

## Infrastructure
- OC1: Mac Mini M4 24GB — permanent production node
- OC2-A/B: Mac Mini M4 Pro 48GB ×2 — incoming, HA primary/standby
- Tailscale mesh, NAS (writable backup target pending)
- Docker via Colima (Docker Desktop removed 2026-05-11)
- RustDesk (primary remote access) + Google Remote Desktop (full session)
- Port convention: 1xxxx=prod, 2xxxx=sandbox, 3xxxx=shadow
- Gateway: 18789 (prod), 28789 (sandbox), 38789 (shadow)

## Current Sprint — Sprint 12 (2026-07-13 to 2026-07-19)
- Sprint 11 ended 2026-07-12
- Key open tickets: TKT-0342 (EPIC: PG SSOT Gap Remediation — critical), TKT-0358 (PG table health monitor — critical), TKT-0171 (pgvector RAG Pipeline — high), TKT-0352 (wire knowledge docs to PG — high), TKT-0280 (post-TKT-0270 cleanup — medium)

## Approved Decisions (from MEMORY.md)
- Governance Tier Model (TKT-0103): T0=Yoda, T1=Aria, T2=Warden, T3=Spark/Atlas/Thrawn/Lando/Forge/Mon Mothma/Krennic, T4=Shield/Lex/Sage
- L-026: Build/scripts → Forge ONLY. Atlas=EA assess. Thrawn=arch design.
- CREST mandatory: Yoda owns Plan/Verify/Replan/Synthesize/Close. Execute is NEVER Yoda's.
- LinkedIn 4-Week Foundation Arc (CHG-0594): Tue 07:30, Wed 12:00, Thu 07:30 AEST. Voice rules: NO AInchors, NO Yoda, NO agent names, NO platform internals.
- EOD Blog: local-only until Citadel client portal live (Ken directive 2026-07-10)
- Ollama credit: scraped from ollama.com/settings dashboard. SSOT = cost-state.json.
- Subagent completion update rule (Ken 2026-07-03): Yoda must immediately synthesise subagent results, never leave Ken wondering.

## Open Tickets — Top 10 by Priority
1. TKT-0342 — EPIC: PG SSOT Gap Remediation (critical, Sprint 11)
2. TKT-0358 — Create PG table health monitor cron (critical, Sprint 12)
3. TKT-0114 — AInchors–Aevlith partnership (high, unassigned)
4. TKT-0125 — Roadmap Refinement QBR 2026-Q3 (P1, unassigned)
5. TKT-0130 — Agent Fleet Review QBR 2026-Q3 (P1, unassigned)
6. TKT-0171 — pgvector + nomic-embed-text RAG Pipeline (high, Sprint 12)
7. TKT-0187 — Cloudflare Tunnel — MinIO + OpenClaw (high, pending)
8. TKT-0190 — P2 Gate — 6 Missing Governance Policies (high, backlog)
9. TKT-0201 — Design routing-gate.sh (high, backlog)
10. TKT-0202 — Implement routing-gate.sh (high, backlog)

## LinkedIn Campaign Status
- Status: DEPRECATED (CHG-0860, 2026-07-10). Per-account separation in effect.
- Use per-account files: linkedin-campaign-ken.json, linkedin-campaign-angie.json, linkedin-campaign-business.json
- Old campaign: 4-Week Foundation Arc, 3 posts/week (Tue/Wed/Thu), alternating themes
- Voice rules still apply: NO AInchors, NO Yoda, NO agent names, NO platform internals
- Pipeline: weekend batch draft (Sat 12:00) + day-before fallback + publish crons

## Ollama Usage / Burn Status
- Check: 2026-07-12 20:00 AEST
- Current: 35,602 requests (65.9% of 54,024 weekly limit)
- Remaining: 18,422 requests
- Burn rate: 234.2 req/hr
- Projected exhaustion: 2026-07-16 00:40 AEST
- Status: WARN (50%+ threshold). Below 70% ALERT.
- Model breakdown: deepseek-v4-flash 27,178 | kimi-k2.7-code 6,128 | deepseek-v4-pro 1,387 | gemma4:31b 569 | kimi-k2.6 324 | minimax-m3 16

## Mandatory Rules for Telegram Sessions
1. HUMAN AUTHORITY: Ken and Angie always have final say.
2. HITL GATES: Never self-approve sign-off-required outputs.
3. SKILL-FIRST: Load skill before calling any domain script.
4. NO FABRICATION: Say "I don't know" and find out.
5. EVIDENCE-ONLY: Done = validated + artifact-backed.
6. CREST MANDATORY: Every execution plan runs through CREST.
7. ORCHESTRATOR ONLY: Yoda plans/verifies; Forge executes.
8. CHG DISCIPLINE: Every structural change needs a CHG record.
9. SUBAGENT COMPLETION: Always synthesise results immediately.
10. TELEGRAM CHUNKING: All messages chunked at 3,800 chars.
11. JOURNAL DISCIPLINE: Append to today's journal after every meaningful exchange.
12. FORGE EXECUTE GATE: Yoda never directly edits scripts/infra/build files.
