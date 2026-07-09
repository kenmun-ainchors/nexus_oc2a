# Yoda 🟢 — Telegram Context Brief
# Generated: Thu 9 Jul 2026 20:00 AEST | Cron: yoda-context-brief-refresh (2pm/8pm)

## Platform Status
- Day 75 (since 2026-04-25)
- OC1 (Mac Mini M4 24GB) — LIVE Production
- OC2-A/B (Mac Mini M4 Pro 48GB x2) — ETA 6-13 Jul 2026, commission ~27 Jul
- Tailscale mesh, NAS pending setup
- OpenClaw gateway: production 18789, sandbox 28789, shadow 38789

## Key People
- Ken Mun — CTO, co-founder (kenmun@ainchors.com, +61403650578)
- Angie Foong — CEO, co-founder (angie.foong@ainchors.com, +61430928371)
- Company: AInchor Solutions Pty Ltd / Aevlith Technologies Pty Ltd

## Infrastructure
- Docker via Colima (standalone brew CLI, Docker Desktop removed)
- RustDesk remote access (primary) + Google Remote Desktop secondary
- MinIO on OC1 — LIVE
- PostgreSQL — primary data store (PG-first write policy in progress)
- PG tables: state_sprints, state_tickets, state_linkedin, state_standups, state_governance, state_incidents, state_model_policy, state_kri, state_diagnostics, etc.
- PG SSOT Gap Remediation EPIC (TKT-0342) — critical, Sprint 11
- Ollama: gemma4:31b, kimi-k2.7-code, kimi-k2.6, deepseek-v4-pro, deepseek-v4-flash, minimax-m3

## Current Sprint
- Sprint 11 — 2026-07-06 to 2026-07-12 (Week 2 of 2)
- Status: committed
- Planning completed: 2026-07-05
- Key focus: PG SSOT Gap Remediation EPIC (TKT-0342)

## Key Approved Decisions (from MEMORY.md)
1. Governance Tier Model (TKT-0103): T0 Yoda -> T4 Reactive agents
2. CREST v1.3: Yoda owns CREST loop; Sage-as-Judge for Verify; multi-model routing
3. Skills loader canon: scripts/skill-load.sh is the ONLY supported way to load skills
4. LinkedIn: 4-Week Foundation Arc v3.0 (CHG-0594) — Tue/Wed/Thu slots
5. LinkedIn voice rules (NON-NEGOTIABLE): no AInchors, no Yoda, no Nexus, no agent names, no platform internals, no em-dashes, no co-founder, no finite time refs, no consulting-speak, no fake clients
6. LinkedIn missed slot rule: push to next slot, never post late
7. CREST mandatory: every execution plan runs through CREST
8. Forge Execute Gate: Yoda never directly edits scripts/infra/build/config files — Forge dispatches only
9. Subagent completion update rule: Yoda must send visible status when dispatching subagents

## Open Tickets — Top 10 by Priority
1. TKT-0342 (critical) — EPIC: PG SSOT Gap Remediation — Sprint 11
2. TKT-0358 (critical) — Create PG table health monitor cron — Sprint 12
3. TKT-0125 (P1) — Roadmap Refinement — QBR 2026-Q3 instance
4. TKT-0130 (P1) — Agent Fleet Review — QBR 2026-Q3 instance
5. TKT-0114 (high) — AInchors-Aevlith Technologies partnership
6. TKT-0127 (high) — Agentic Marketing Org Design
7. TKT-0128 (high) — Aria: expanded marketing orchestration
8. TKT-0136 (high) — AInchors Consulting Playbook
9. TKT-0138 (high) — Business Jumpstart — 3-part client engagement
10. TKT-0139 (high) — Consulting Product Portfolio
And 50+ more open tickets across backlog/monitoring statuses.

## LinkedIn Campaign — 4-Week Foundation Arc
- Week 4 — Movement IV: The Shift (final week)
- Tue 7 Jul: LI-W4-P10 "What I do differently now" — POSTED ✅
- Wed 8 Jul: LI-W4-P11 "Discipline beats motivation" — POSTED ✅
- Thu 10 Jul: LI-W4-P12 "What I learned rebuilding the foundation" — POSTED ✅ (early 8 Jul)
- All 12 posts of the 4-week arc are now published. Campaign complete.
- Next: decide post-arc strategy (new theme, break, or continue)
- Cadence: 3 slots/week (Tue 07:30, Wed 12:00, Thu 07:30 AEST)
- Pipeline: batch draft Sat 12:00, fallback day-before drafts
- Publish crons: 13b0aa89 (Tue), 833ee0c7 (Wed), 869502c9 (Thu)
- Stream: Ken Mun personal profile (since CHG-0739, 2026-06-23)
- Company page stream active for business-relevant content (Angie-driven)

## Ollama Usage / Burn Status
- Check time: 2026-07-09 20:00 AEST
- Current requests: 18,942 / 62,515 weekly limit (30.3%)
- Threshold: none triggered — below 50%
- Burn rate: 236.8 req/hr -> projected exhaustion: 2026-07-17 10:00 AEST
- Requests remaining: 43,573
- Model breakdown:
  - deepseek-v4-flash: 15,493 (82%) — primary driver
  - deepseek-v4-pro: 1,155
  - kimi-k2.7-code: 1,643
  - gemma4:31b: 543
  - kimi-k2.6: 99
  - minimax-m3: 9
- No burn alert sent. All clear.

## Mandatory Rules for Telegram Sessions
1. HUMAN AUTHORITY: Ken and Angie have final say.
2. HITL GATES: never self-approve sign-off-required outputs.
3. SKILL-FIRST: load skill before calling domain scripts.
4. NO FABRICATION: say "I don't know" and find out.
5. EVIDENCE-ONLY: done = validated + artifact-backed.
6. CREST mandatory: every execution plan runs through CREST.
7. ORCHESTRATOR ONLY: Plan, Verify, Replan, Synthesize, Close. Execute -> Forge.
8. CHG discipline: structural changes need CHG record first.
9. ASYNC: tasks >30s spawn subagent. Never block webchat.
10. SUBAGENT UPDATE: visible status after dispatch, always.
11. SANCTUM PROTOCOL: external outputs pass Shield -> Lex -> Sage.
12. DATA SOVEREIGNTY: client data Tier 0/1 local only.
13. TELEGRAM CHUNKING: all messages chunked at 3,800 chars.
14. FORGE GATE: Yoda never edits scripts/infra/build/config files directly.
15. JOURNAL DISCIPLINE: append to today journal after every meaningful exchange.
16. SILENT REPLY: if nothing user-facing to say, reply with bare NO_REPLY only.
