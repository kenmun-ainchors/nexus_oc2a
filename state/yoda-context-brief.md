# Yoda Telegram Context Brief
# Auto-refreshed: Saturday, June 20th, 2026 - 8:00 PM AEST
# Platform Day: 57 (from 2026-04-25)
# Current Sprint: Sprint 8 (2026-06-15 to 2026-06-21) — IN PROGRESS
# Model: ollama/kimi-k2.6:cloud

## Key People
- **Ken Mun** — Co-founder, CTO. +61403650578
- **Angie Foong** — Co-founder, CEO. +61430928371
- Yoda 🟢 is the lead orchestrator for Ken (TECH stream) and platform-wide governance.

## Platform Status
- **OC1** (Mac Mini M4 24GB) — LIVE production, permanent. Tailscale: 100.91.60.36
- **OC2-A/B** (Mac Mini M4 Pro 48GB ×2) — ETA 6–13 Jul 2026. Commission ~27 Jul.
- **Gateway ports:** 18789 Prod | 28789 Sandbox | 38789 Shadow
- **Tailscale mesh + NAS** operational. No local LLM inference >~8B Q4 on OC1.

## Current Sprint (Sprint 8)
- Dates: 2026-06-15 to 2026-06-21
- Status: in_progress
- Ceremonies locked: 2026-06-15 17:57 AEST by Ken
- Effective working items: 7 (1 pre-closed: TKT-0317)
- Capacity: 8 items (5/sprint cap overridden for S8 per L-140)

## Approved Decisions (Memory)
- **CHG-0545 (Ken 2026-06-13):** Four rules locked — no fabrication, evidence-only, CREST mandatory, orchestrator-only execution.
- **CHG-0596 (2026-06-15):** Model routing permanent; minimax trial TERMINATED (partial).
- **CHG-0594 (2026-06-15):** LinkedIn 4-Week Foundation Arc locked — 3 slots/week, 12 posts/4 weeks, 4 movements.
- **CHG-0680 (2026-06-20):** CREST v1.3 approved (not yet executed). Pre-Tier-A gates G1-G5 required before execution.
- **CHG-0690 (2026-06-20):** Yoda/Aria CREST Plan/Replan primary → `kimi-k2.7-code:cloud` (91.5% benchmark).
- **CHG-0691 (2026-06-20):** Aria default chat model = `kimi-k2.7-code:cloud`, matching Yoda.
- **CHG-0685 (2026-06-20):** GLM-5.2:cloud adopted for design_backend Plan role. Verify role not viable.

## Open Tickets (Top 10 by Priority)
| ID | Title | Status | Priority | Sprint |
|----|-------|--------|----------|--------|
| TKT-0546 | CREST v1.3 Implementation — external loop ownership | open | critical | |
| TKT-0130 | Agent Fleet Review — QBR 2026-Q3 instance | open | P1 | |
| TKT-0394 | Tribal Knowledge Audit — QBR 2026-Q3 instance | open | P1 | Sprint 9 |
| TKT-0187 | Cloudflare Tunnel — MinIO + OpenClaw | pending | high | |
| TKT-0329 | Thrawn Assessment — Workspace Sandbox Isolation | open | high | |
| TKT-0331 | Skill-Based Encapsulation — Ticket, Sprint, Changelog | open | high | |
| TKT-0365 | Create cron manifest — machine-readable crons | open | high | Sprint 11 |
| TKT-0368 | Nexus Foundational Architecture — 3-Area Solution | open | high | |
| TKT-0280 | Post-TKT-0270 Cleanup — Archive 5 repo files | open | medium | Sprint 9 |
| TKT-0234 | Dynamic Escalation Pattern — Phase 2 (local-first) | open | medium | |

## LinkedIn Campaign Status
- **Status:** ACTIVE — 4-Week Foundation Arc (restarted 2026-06-16)
- **Current week:** Week 2 (Movement II: The Audit) — Theme A (What AI Agents in Production Actually Look Like)
- **Posted this week:** W2-P1 (Tue), W2-P2 (Wed), W2-P3 (Thu) — all posted
- **Upcoming slots:** Tue 23 Jun 07:30 (W2-P4), Wed 24 Jun 12:00 (W2-P5), Thu 25 Jun 07:30 (W2-P6)
- **Drafts ready:** W2-P4, P5, P6 drafted Sat 20 Jun by batch cron (1cb0c7ff). Images pending Ken approval.
- **Voice:** Ken Mun, CTO — first-person, direct, no fluff. NO AInchors/Yoda/Nexus/agent names.
- **Missed-slot rule:** Push to next slot. If occupied, skip. Never post late.
- **Pipeline:** Weekend batch draft (Sat 12:00) → review → publish at slot. Never draft at publish time.

## Ollama Usage / Burn Alert
- Weekly limit: 66,597 requests
- Current: 16,064 requests (47.2% used)
- Days remaining: ~2.6 (window ends Mon 22 Jun 10:00 AEST)
- Burn rate: 302 req/hr
- **Alert level:** NONE — below 50% threshold. No action needed.

## Mandatory Rules for Telegram Sessions
1. **Yoda/Aria CREST:** Plan/Replan primary = `kimi-k2.7-code:cloud`. Execute NEVER without Ken approval.
2. **No fabrication.** Say "I don&#39;t know" and find out.
3. **Evidence-only.** Done = validated + backed by artifacts.
4. **Skill-first:** Load skill before any domain script (`bash scripts/skill-load.sh <skill>`).
5. **CHG discipline:** Every structural change needs a CHG record before execution.
6. **Telegram chunking:** All messages MUST be chunked at 3,800 chars.
7. **Sanctum protocol:** External/client outputs pass Shield → Lex → Sage.
8. **Data sovereignty:** Client data = Tier 0/1 local ONLY. No exceptions.
9. **Build/scripts → Forge ONLY.** Atlas=EA assess. Thrawn=arch design.
10. **Subagent-dispatch:** verifier_corpus MANDATORY for any execute/verify atom.
11. **Journal discipline:** Append after every meaningful Ken exchange.
12. **Model routing SSOT:** `state/model-policy.json`. Query via `scripts/model-policy-query.sh`.
13. **CREST v1.3:** Approved, NOT executed. Ken trigger required. Pre-Tier-A gates G1-G5 first.

# END BRIEF
