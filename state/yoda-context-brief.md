# Yoda Context Brief 🟢
Generated: 2026-06-15 20:05 AEST (8:05 PM)

## 📊 Platform Status
- **Day Count:** Day 52 (Since 2026-04-25)
- **Phase:** MVP (OC1-only) → Target P1 (OC2 era, ~Jul 2026)
- **Budget:** Daily cap $150

## 👥 Key People
- **Ken Mun (CTO):** Co-founder. Lead Authority. Email: kenmun@ainchors.com | Mobile: +61403650578
- **Angie Foong (CEO):** Co-founder. Business Lead. Email: angie.foong@ainchors.com | Mobile: +61430928371

## 🏗️ Infrastructure
- **OC1:** Mac Mini M4 24GB (Live Production). PERMANENT.
- **OC2-A/B:** Mac Mini M4 Pro 48GB ×2 (ETA 6–13 Jul 2026). A=HA Primary, B=Standby. Commission ~27 Jul.
- **Mesh:** Tailscale (`ainchorss-mac-mini.tail5e2567.ts.net`)
- **Governance:** Warden (15-min drift check), Shield/Lex/Sage (reactive verdict)
- **Daily Auto-Heal:** 24 checks incl. CHECK 24 (L-085 long-ID stub detection)

## 🏃 Current Sprint
- **Sprint:** 8 (2026-06-15 to 2026-06-21)
- **Status:** Committed / Planning
- **Completion:** 53% (8/15 done, 7 open, 0 blocked)
- **Carried:** TKT-0529 from Sprint 7

## ✅ Approved Decisions (Key)
- **CHG-0545 (Governance):** No fabrication, Evidence-only, CREST mandatory, Yoda as Orchestrator only.
- **CHG-0594 (LinkedIn):** Canonical 4-Week Foundation Arc locked. Reactivation approved 2026-06-12.
- **CHG-0596 (Models):** Model routing locked. Yoda/Aria=deepseek-v4-pro, T3=minimax-m3, Backend=gemma4. Minimax trial terminated.
- **CHG-0502 (Anthropic):** PERMANENTLY PARKED until "CLAUDE ACTIVATE".
- **Naming Convention:** Nexus=platform, Holocron=AKB, Bridge=cmd-centre, Citadel=client-portal, Holonet=live-data.

## 🎫 Open Tickets (Top Priority)
| ID | Title | Status | Effort | Agent |
|---|---|---|---|---|
| TKT-0529 | Old-Code Audit P0 (Sprint 8): high-risk live scripts | open | M | yoda |
| TKT-0293 | Expand Regression Testing Framework | open | ? | ? |
| TKT-0319 | TQP Phase 3 — Global Agent Auto-Resume Protocol | open | ? | ? |
| TKT-0324 | TQP Integration + Rollout Test for 2-Pass Dispatch | open | ? | ? |
| TKT-0326 | NAS Setup — Writable Platform Backup Target | open | ? | ? |
| TKT-0410 | Fix SUB_CREST_TRANSITIONS: add 'verified' → terminal | open | ? | forge |
| TKT-0525 | CHG-0525: Fix pg-to-notion-sync.sh — JSONB Path | open | ? | ? |

## 📱 LinkedIn Campaign (4-Week Foundation Arc)
- **Status:** ACTIVE — Reactivation Week 1 starts Tue 16 Jun
- **Movement I (The Cracks):** 3 posts queued for 16–18 Jun
  - LI-W1-P1: "The day my AI bill became the loudest thing in the room" → Tue 07:30 — **APPROVED** ✅
  - LI-W1-P2: "What happens to your AI when the model underneath you disappears" → Wed 12:00 — **APPROVED** ✅
  - LI-W1-P3: "The four things that quietly broke when everything was loud" → Thu 07:30 — **APPROVED** ✅
- **All images:** Ready, governance cleared (Shield/Lex/Sage)
- **Theme:** Week 1 = Theme A (AI agents in production). Alternates weekly.
- **Pipeline v2.0:** Draft-before-slot principle. Weekend batch draft preferred.
- **Previous:** Teaser posted Sat 13 Jun 14:24 AEST successfully.

## 🚨 Mandatory Rules for Telegram Sessions
1. **CREST Mandatory:** Every execution task = Plan → Execute → Verify → Replan → Synthesize → Done.
2. **Skill-Gate:** Run `bash scripts/skill-load.sh <name>` before any domain script.
3. **No Silent Execution:** Output explicit Plan phase before any tool use.
4. **Model Discipline:** Plan/Verify = strong (deepseek-v4-pro). Execute/Synthesize = cheap (minimax-m3/gemma4).
5. **Evidence-Only:** "Done" requires validation artifacts (logs, PG state, tool output). Vibe ≠ fact.
6. **No Fabrication:** State "I don't know" if unsure. Find out. Never invent.
7. **Telegram Chunking:** Max 3,800 characters per message.
8. **Yoda = Orchestrator Only:** Plan, Verify, Replan, Synthesize, Close. Execute NEVER mine (per-instance Ken approval required).
9. **Anthropic = PARKED:** No activation, no key rotation, no model assignment until "CLAUDE ACTIVATE".
10. **Forge = Build Only:** Atlas=EA assess. Thrawn=arch design. Never route build to Thrawn/Atlas.
11. **Journal Discipline:** Append to `memory/journal-YYYY-MM-DD.md` after every meaningful Ken exchange.
12. **LESSONS.md Check:** Search before acting. Log after any fix/incident.

## 🔗 Key References
- Model routing: `infra/sandbox/seed/skills/model-routing/SKILL.md`
- Sprint skill: `infra/sandbox/seed/skills/pg-sprint-backlog/SKILL.md`
- Telegram skill: `infra/sandbox/seed/skills/telegram/SKILL.md`
- Changelog skill: `infra/sandbox/seed/skills/changelog/SKILL.md`
- CREST doc: `docs/CREST-v1.2-Recursive-Model-C.md`
