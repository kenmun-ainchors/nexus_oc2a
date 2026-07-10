# Yoda Telegram Context Brief
# Generated: 2026-07-10 20:00 AEST (UTC 10:00)
# Cron: yoda-context-brief-refresh (2pm + 8pm AEST)

---

## Platform Status
- **Platform Day:** 77 (since 2026-04-25)
- **Sprint 11** — Jul 06 to Jul 12 (committed, planning completed 2026-07-05)
- **OC1 (Mac Mini M4 24GB):** LIVE Production — stable
- **OC2-A/B (Mac Mini M4 Pro 48GB x2):** ETA 6–13 Jul 2026 — still pending arrival
- **Tailscale mesh + NAS:** operational

## Key People
- **Ken Mun** — CTO, co-founder. Telegram: 8574109706. Mobile: +61403650578
- **Angie Foong** — CEO, co-founder. Mobile: +61430928371
- **Yoda** — Lead Orchestrator (Runtime: main)
- **Aria** — Business Stream (Runtime: business)
- **Atlas** — Enterprise Architect (Runtime: architect)
- **Thrawn** — Platform Architect (Runtime: platform-arch)
- **Forge** — Infrastructure Agent (Runtime: infra)
- **Shield** — Security | **Lex** — Legal | **Sage** — QA | **Warden** — Governance | **Spark** — Social | **Lando** — BPM

## Infrastructure
- **OC1** — Mac Mini M4 24GB — LIVE. Permanent. No local LLM >~8B Q4.
- **OC2-A/B** — pending arrival (ETA 6–13 Jul). HA Primary/Standby.
- **Colima** — container runtime (Docker Desktop removed 2026-05-11)
- **Port Convention:** Prod=18789, Sandbox=28789, Shadow=38789
- **RustDesk** — primary remote access. CRD fallback.
- **Tailscale IP (OC1):** 100.91.60.36
- **MinIO** — live on OC1 (ainchors-generated-media bucket)
- **PostgreSQL** — primary SSOT for tickets, sprints, standups

## Current Sprint (Sprint 11 — Jul 06 to Jul 12)
- **Status:** committed
- **Key tickets:** TKT-0342 (EPIC: PG SSOT Gap — critical, S11), TKT-0358 (PG table health monitor — critical, S12), TKT-0352 (knowledge docs to PG — high, S11), TKT-0354 (state_standups to PG — high, S11), TKT-0359 (PG-first write policy — high, S11), TKT-0280 (cleanup — medium, S12), TKT-0171 (pgvector RAG — high, S12), TKT-0293 (regression testing — high, unassigned)

## Approved Decisions
1. **Governance Tier Model (T0-T4)** — Ken 2026-05-08
2. **Ken's Governance Mandate (CHG-0545, 2026-06-13):** No fabrication. Evidence-only. CREST mandatory. Orchestrator-only.
3. **LinkedIn Campaign (CHG-0594, 2026-06-15):** 4-week Foundation Arc. Tue 07:30, Wed 12:00, Thu 07:30 AEST. Voice rules: NO internal mentions.
4. **Subagent Update Rule (CHG-0812, 2026-07-03):** Always visible status update after dispatch.
5. **CREST v1.3:** Three-move loop. Sage-as-Judge. Multi-model routing.
6. **Nexus Naming (LOCKED):** Holocron=AKB, Bridge=cmd-centre, Citadel=client-portal, etc.
7. **Forge Execute Gate (2026-06-21):** Yoda never edits scripts/infra/config. Route to Forge.
8. **LinkedIn Campaign DEPRECATED (CHG-0860, 2026-07-10):** Per-account separation. Use per-account files.

## Open Tickets (Top 10 by Priority)
1. **TKT-0342** — EPIC: PG SSOT Gap Remediation — critical, Sprint 11
2. **TKT-0358** — PG table health monitor cron — critical, Sprint 12
3. **TKT-0125** — Roadmap Refinement QBR 2026-Q3 — P1, unassigned
4. **TKT-0130** — Agent Fleet Review QBR 2026-Q3 — P1, unassigned
5. **TKT-0114** — AInchors-Aevlith partnership — high, pending
6. **TKT-0127** — Agentic Marketing Org Design — high, backlog
7. **TKT-0128** — Aria expanded marketing orchestration — high, backlog
8. **TKT-0136** — AInchors Consulting Playbook — high, backlog
9. **TKT-0138** — Business Jumpstart client pathway — high, backlog
10. **TKT-0139** — Consulting Product Portfolio — high, unassigned
Plus PG SSOT cluster: TKT-0345/0349/0352/0353/0354/0355/0356/0359/0360, TKT-0329, TKT-0331, TKT-0293

## LinkedIn Queue Status
- **Status:** DEPRECATED (per-account separation, CHG-0860, 2026-07-10)
- **New per-account files:** linkedin-campaign-ken.json, linkedin-campaign-angie.json, linkedin-campaign-business.json
- **Last active:** 4-week Foundation Arc (reactivated 2026-06-12)
- **Cadence crons still active:** Tue 07:30 (13b0aa89), Wed 12:00 (833ee0c7), Thu 07:30 (869502c9) AEST
- **Voice rules (NON-NEGOTIABLE):** no AInchors, no Yoda, no Nexus, no agent names, no platform internals, no em-dashes, no "co-founder", no finite time references, no consulting-speak, no fake clients
- **Missed slot rule:** Push to next available slot. If taken, skip. Never post late.

## Recent Ollama Usage / Burn Status
- **Window:** 2026-07-06 to 2026-07-13 (weekly limit: 53,090)
- **Current:** 24,793 / 53,090 (46.7%)
- **Remaining:** 28,297 | **Burn rate:** 238.4 req/hr
- **Projected exhaustion:** 2026-07-15 16:42 AEST (within window, no alert)
- **Threshold:** None triggered (below 50%)
- **Model breakdown:** deepseek-v4-flash (18,662), kimi-k2.7-code (4,292), deepseek-v4-pro (1,169), gemma4:31b (549), kimi-k2.6 (110), minimax-m3 (11)
- **Alert sent:** No

## Mandatory Rules for Telegram Sessions
1. NO direct file writes — use cron-write.sh wrapper
2. CREST mandatory — load skill before planning execution
3. Forge Execute Gate — Yoda never edits scripts/infra/config directly
4. Subagent completion update — always visible status to Ken after dispatch
5. CHG discipline — every structural change needs a CHG record first
6. Telegram chunking — all messages at 3,800 chars max
7. Journal discipline — append after every meaningful exchange
8. NO fabrication — say "I don't know" and find out
9. Evidence-only — done = validated + artifact-backed
10. HITL gates — never self-approve sign-off-required outputs
