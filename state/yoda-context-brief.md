# Yoda Telegram Context Brief
# Generated: Sun 5 Jul 2026 14:00 AEST | Platform Day 71

## Platform Status
- Day count: 71 (from 2026-04-25)
- Sprint: Sprint 10 (2026-06-29 to 2026-07-05) — ends today
- Sprint 10: 17 tickets, 3 done (17.6%), 13 open, 0 in-progress
- OC2-A/B ETA: 6–13 Jul 2026 (this week!)
- This is the last day of Sprint 10. Sprint Review / Retro due.

## Key People
- Ken Mun (CTO) — kenmun@ainchors.com | +61403650578
- Angie Foong (CEO) — angie.foong@ainchors.com | +61430928371
- Primary channel: Web chat | Secondary: Telegram

## Infrastructure
- OC1: Mac Mini M4 24GB — LIVE Production. HARD LIMIT: no local LLM >~8B Q4.
- OC2-A/B: Mac Mini M4 Pro 48GB ×2 — incoming Jul 2026. Commission ~27 Jul.
- Tailscale IP: 100.91.60.36
- Port convention: 1xxxx=Production, 2xxxx=Sandbox, 3xxxx=Shadow
- Docker: Colima runtime (active). Docker Desktop removed.
- PostgreSQL: active (PG SSOT gap remediation = Sprint 10 epic)
- RustDesk: primary remote access

## Current Sprint (Sprint 10 — ends today)
- 17 tickets, 3 done, 13 open, 0 in-progress, 17.6% completion
- Critical: TKT-0342 EPIC: PG SSOT Gap Remediation
- Critical: TKT-0358 Create PG table health monitor cron
- High: TKT-0352 Wire knowledge_documents + knowledge_chunks to PG
- High: TKT-0354 Wire state_standups to PG
- High: TKT-0345 Wire state_linkedin to PG
- High: TKT-0346 Wire state_diagnostics to PG
- High: TKT-0349 Wire state_policies to PG
- High: TKT-0353 Wire state_governance to PG
- High: TKT-0355 Gateway-internal PG write paths
- High: TKT-0356 Audit 8 empty PG tables
- High: TKT-0360 Create state_incidents PG table
- High: TKT-0361 Create state_rule_violations PG table
- Next sprint: Sprint 11 — TKT-0171 pgvector RAG Pipeline committed

## Approved Decisions (from MEMORY.md)
1. Governance Tier Model — T0–T4 (TKT-0103, CHG-0545)
2. CREST Orchestrator-only — Yoda: Plan/Verify/Replan/Synthesize/Close. Execute→Forge (CHG-0545)
3. Forge Execute Gate — Yoda never scripts/infra/build edits. Route to agentId="infra" (CHG-0545)
4. CREST v1.3 — Three-move: Yoda owns loop, Sage-as-Judge, capability-based routing
5. LinkedIn 4-Week Foundation Arc — 12 posts, 3/week (Tue/Wed/Thu), NO AInchors/agent names/internal refs
6. LinkedIn missed-slot rule — Push to next slot, never late, skip if occupied
7. PG SSOT — All state files must wire to PG live writes (Sprint 10 epic)
8. Subagent completion update rule — Yoda must always send visible status after spawning subagents
9. No fabrication — always say "I don't know" and find out
10. Evidence-only — done/verified = validated + artifact-backed

## Open Tickets — Top 10 by Priority
1. TKT-0342 — EPIC: PG SSOT Gap Remediation (critical, Sprint 10)
2. TKT-0358 — Create PG table health monitor cron (critical, Sprint 11)
3. TKT-0125 — Roadmap Refinement QBR 2026-Q3 (P1, Unassigned)
4. TKT-0130 — Agent Fleet Review QBR 2026-Q3 (P1, Unassigned)
5. TKT-0114 — AInchors–Aevlith partnership (high, pending, Unassigned)
6. TKT-0169 — Typed Agent Contracts (high, backlog, Unassigned)
7. TKT-0170 — PII Scanner on Document Ingestion (high, backlog, Unassigned)
8. TKT-0171 — pgvector + nomic-embed-text RAG Pipeline (high, Sprint 11)
9. TKT-0187 — Cloudflare Tunnel MinIO + OpenClaw (high, pending, Unassigned)
10. TKT-0190 — P2 Gate — 6 Missing Governance Policies (high, backlog, Unassigned)

## LinkedIn Campaign Status
- Active: 4-Week Foundation Arc (v3.0, locked CHG-0594)
- Week 4 of 4 (Movement IV: The Shift) — final week
- Schedule: Tue 07:30 / Wed 12:00 / Thu 07:30 AEST
- Posts remaining: 3 (W4-P10 Tue 7 Jul, W4-P11 Wed 8 Jul, W4-P12 Thu 9 Jul)
- Latest: W4-P10 approved (drafted), W4-P11 drafted, W4-P12 drafted
- All batch-drafted 2026-07-04 (Sat 12:00). W4-P10 ready for Tue publish.
- Voice rules active: NO AInchors, NO Yoda, NO agent names, NO platform internals, NO em-dashes, NO "co-founder", NO finite time, NO consulting-speak, NO fake clients.
- Business account: one post published (Visa+OpenAI, 2026-06-24, Angie-approved)

## Ollama Usage / Burn Status
- Weekly limit: 56,571 requests (Mon 10:00 AEST window)
- Used: 16,236 (28.7%) — well below 50% threshold
- Remaining: 40,335 requests
- Burn rate: 126.8 req/hr
- Alert level: SILENT — no action needed
- Window: 2026-06-29 to 2026-07-06 (ends Mon 10:00)
- 2 days remaining in window

## Mandatory Rules for Telegram Sessions
1. All Telegram messages MUST be chunked at 3,800 chars. Load skill: bash scripts/skill-load.sh telegram
2. CREST mandatory: load bash scripts/skill-load.sh crest before any execution work
3. Forge Execute Gate: NEVER edit scripts/infra/build files directly. Route to agentId="infra"
4. CHG discipline: every structural change needs a CHG record before execution
5. Security first: S1–S7 controls always live. Warden always watching.
6. Data sovereignty: client data = Tier 0/1 local ONLY. No exceptions.
7. Sanctum protocol: external/client outputs pass Shield -> Lex -> Sage
8. Subagent completion update: always send visible status after spawning subagents
9. No fabrication — say "I don't know" and find out
10. Evidence-only — done/verified = validated + artifact-backed
