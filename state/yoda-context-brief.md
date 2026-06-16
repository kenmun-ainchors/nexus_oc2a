---
# Yoda Context Brief — Telegram Sessions
# Generated: 2026-06-16 20:00 AEST (Day 53 from 2026-04-25)
# Auto-refreshed: 2pm + 8pm daily by Forge cron c69615bb
---

## Platform Status

- **Day:** 53 since 2026-04-25
- **Phase:** MVP → P1 (OC2 incoming 6–13 Jul 2026)
- **Sprint:** Sprint 8 (2026-06-15 to 2026-06-21) | Status: planning | 53% complete (8/15 done)
- **OC1:** Mac Mini M4 24GB — LIVE Production
- **OC2-A/B:** Mac Mini M4 Pro 48GB ×2 — ETA 6–13 Jul, commission ~27 Jul
- **Gateway:** OpenClaw on OC1 (port 18789 prod, 28789 sandbox, 38789 shadow)
- **Models:** DeepSeek v4-pro (Yoda/Aria), Gemma4:31b (backend), minimax-m3 (T3 specialists)
- **CREST:** v1.3 + TKT-0368 risk framework — MANDATORY until LOCKED
- **Daily budget cap:** $150

## Key People

- **Ken Mun** — Co-founder, CTO. Mobile: +61403650578. Primary: web chat. Secondary: Telegram.
- **Angie Foong** — Co-founder, CEO. Mobile: +61430928371.
- **KL Team** — Malaysia, 4–5 headcount, P1 onboarding.

## Infrastructure

- **Tailscale mesh:** OC1 serve enabled. URL: https://ainchorss-mac-mini.tail5e2567.ts.net
- **MinIO:** Self-hosted on OC1 (native macOS binary)
- **Postgres:** 5-tier schema on OC1. PG→Notion sync active.
- **Docker:** Colima replaces Docker Desktop.
- **RustDesk:** Public relay primary remote access.
- **NAS:** Writable platform backup target (TKT-0326 open, OC2-gated).
- **Ollama Cloud:** Weekly cap pattern — hits Sun/Mon, recovers Tue. Single SPOF for all cloud-modelled crons. CHECK 29 shipped 2026-06-15 for cloud-cron escalation.

## Current Sprint (Sprint 8)

Dates: 2026-06-15 to 2026-06-21 | Status: planning | Completion: 53% (8/15 done)

Committed items:
1. TKT-0529 — Old-Code Audit P0 (Sprint 8): high-risk live scripts | M | yoda | open
2. TKT-0293 — Expand Regression Testing Framework | ? | open (deferred S7→S8)
3. TKT-0319 — TQP Phase 3 — Global Agent Auto-Resume Protocol | ? | open
4. TKT-0324 — TQP Integration + Rollout Test for 2-Pass Dispatch | ? | open
5. TKT-0326 — NAS Setup — Writable Platform Backup Target | ? | open (deferred S7→S8)
6. TKT-0410 — Fix SUB_CREST_TRANSITIONS: add verified → terminal | ? | forge | open
7. TKT-0525 — CHG-0525: Fix pg-to-notion-sync.sh — JSONB Path | ? | open

Done/closed: TKT-0137, TKT-0317, TKT-0318, TKT-0332, TKT-0340, TKT-0409, TKT-0503, TKT-0526
Blocked: TKT-0340 (BLOCKED, dep TKT-0368)

Sprint 7 retro: 14/15 closed (93%), 24 lessons shipped, L-139 subagent-trap rule shipped.

## Approved Decisions (Key — from MEMORY.md)

1. **CHG-0545 (2026-06-13):** Ken governance mandate — NO fabrication, evidence-only, CREST mandatory, orchestrator-only execute boundary.
2. **CHG-0594 (2026-06-15):** LinkedIn 4-Week Foundation Arc locked-in. Week 1 = Movement I "The Cracks" (Theme A).
3. **CHG-0596 (2026-06-15):** Model routing permanent — DeepSeek v4-pro (Yoda/Aria), Gemma4 (backend), minimax-m3 (T3). Minimax trial TERMINATED.
4. **CHG-0502 (2026-06-12):** Anthropic PERMANENTLY PARKED. Unblock keyword: "CLAUDE ACTIVATE".
5. **Port convention LOCKED (2026-06-08):** Prod=1xxxx, Sandbox=2xxxx, Shadow=3xxxx.
6. **Star Wars naming LOCKED:** Nexus=platform, Holocron=AKB, Bridge=cmd-centre, Citadel=client-portal, Holonet=live-data, Beacon=monitoring, Sanctum=governance, Datapad=reporting.
7. **3 Strikes Principle (TKT-0401):** Strike-1 plan before execute, Strike-2 flash by default/pro only when flagged, Strike-3 check LESSONS.md before acting.
8. **Build/scripts → Forge ONLY (L-026).** Atlas=EA assess. Thrawn=arch design.
9. **CHECK 29 shipped (2026-06-15, L-116 + L-117):** Cloud-cron escalation + orphan try/except fix in auto-heal.sh. CHECK 25 bug had silently crashed auto-heal since 2026-06-13.

## Open Tickets — Top Priority

| ID | Title | Status | Priority |
|---|---|---|---|
| TKT-0529 | Old-Code Audit P0 (Sprint 8): high-risk live scripts | open | READY |
| TKT-0293 | Expand Regression Testing Framework | open | READY |
| TKT-0319 | TQP Phase 3 — Global Agent Auto-Resume Protocol | open | READY |
| TKT-0324 | TQP Integration + Rollout Test for 2-Pass Dispatch | open | READY |
| TKT-0326 | NAS Setup — Writable Platform Backup Target | open | READY |
| TKT-0410 | Fix SUB_CREST_TRANSITIONS: add verified → terminal | open | READY |
| TKT-0525 | CHG-0525: Fix pg-to-notion-sync.sh — JSONB Path | open | READY |

Other open/pending:
- TKT-0110 — Process Documentation Framework (open, medium)
- TKT-0114 — AInchors–Aevlith partnership agreement (pending, high)
- TKT-0125 — Roadmap Refinement QBR 2026-Q3 (open, P1)
- TKT-0130 — Agent Fleet Review QBR 2026-Q3 (open, P1)
- TKT-0179 — ClawGuard security toolkit evaluation (open, medium)
- TKT-0181 — Gemma4 fine-tuning research P3 boundary (open, medium)
- TKT-0186 — LinkedIn: Fix token refresh + comment/metrics (open, medium)
- TKT-0187 — Cloudflare Tunnel — MinIO + OpenClaw webchat (pending, high)
- TKT-0189 — Nexus Client Isolation Policy v1.0 (open, medium)
- TKT-0191 — Sandbox Runbook v1 — Ken Formal Review (open, medium)
- TKT-0232 — Spark: LinkedIn metrics ownership (open, medium)
- TKT-0234 — Dynamic Escalation Pattern Phase 2 (open, medium)
- TKT-0238 — Systemic cron date calculation drift (open, medium)

## LinkedIn Campaign — 4-Week Foundation Arc

- **Status:** ACTIVE. Reactivated 2026-06-12. First post published.
- **Week 1 (16–18 Jun):** Movement I — The Cracks | Theme A (AI agents in production)
- **Published:**
  - LI-W1-P1 "The day my AI bill became the loudest thing in the room" — Tue 16 Jun 17:27 AEST ✅ (v3 repost, correct body + fresh image)
- **Queued (approved):**
  - LI-W1-P2 — "What happens to your AI when the model underneath you disappears" — Wed 17 Jun 12:00 AEST
  - LI-W1-P3 — "The four things that quietly broke when everything was loud" — Thu 18 Jun 07:30 AEST
- **Schedule:** Tue 07:30, Wed 12:00, Thu 07:30 AEST
- **Voice rules (NON-NEGOTIABLE):** No AInchors, no Yoda, no Nexus, no agent names, no platform internals, no em-dashes, no "co-founder", no finite time references, no consulting-speak, no fake clients.
- **Pipeline:** v2.0 — draft before slot, publish at slot. Weekend batch draft (Sat 12:00), day-before fallback if missed.
- **Missed slot rule:** Push to next slot. If occupied, skip entirely.

## Recent Telegram Decisions (syncedToWebchat=false)

- LI-W1-P1 reposted 17:27 AEST — draft format bug fixed (missing --- delimiters caused wrong content post). v3 with fresh image + correct body live.
- CHECK 29 approved 10:33 AEST — cloud-cron escalation + auto-heal orphan try/except fix (L-116 + L-117).
- Sprint 8 planning completed 07:27 AEST.
- Journal: memory/journal-2026-06-16.md

## Mandatory Rules for Telegram Sessions

1. **CREST MANDATORY:** Every operational task -> Plan->Execute->Verify->Replan->Synthesize->Done. No skip phases.
2. **Skill-Gate:** Load skill before domain script. `bash scripts/skill-load.sh <name>` first.
3. **No fabrication:** Say "I do not know" and find out. Never invent.
4. **Evidence-only:** Done = validated + artifact-backed. Vibe != fact.
5. **Orchestrator-only:** Yoda does Plan/Verify/Replan/Synthesize/Close. Execute = NEVER Yoda's.
6. **HITL Gates:** Ken/Angie always have final say. Yoda recommends, they decide.
7. **Data sovereignty:** Client data = Tier 0/1 local ONLY. No exceptions.
8. **Telegram chunking:** All messages MUST be chunked at 3,800 chars.
9. **Journal discipline:** After every meaningful exchange with Ken -> `bash scripts/journal-append.sh`.
10. **CHG discipline:** Every structural change has a CHG record before execution.
11. **Build -> Forge ONLY.** Atlas=EA assess. Thrawn=arch design.
12. **Lessons check:** Check LESSONS.md before acting. Log fixes immediately.
13. **Anthropic PARKED:** No Anthropic work unless Ken says "CLAUDE ACTIVATE".
14. **Minimax trial TERMINATED:** minimax-m3 approved for engineering only (T3), NOT engagement/planning.
15. **Memory limits:** SOUL.md <= 5,000 chars. MEMORY.md <= 15,000 (warn 12,000). Archive overflow.
16. **Draft format contract:** All LinkedIn drafts MUST have --- delimiters around post body. Enforce at generation time.

## Reference Paths

- Technology Strategy: docs/Aevlith-Technology-Strategy-Roadmap-v1.0-Internal.md
- System Architecture: docs/Nexus-System-Architecture-v1.0.md
- Model Routing: infra/sandbox/seed/skills/model-routing/SKILL.md
- PG Sprint Backlog: infra/sandbox/seed/skills/pg-sprint-backlog/SKILL.md
- Changelog: infra/sandbox/seed/skills/changelog/SKILL.md
- Telegram: infra/sandbox/seed/skills/telegram/SKILL.md
- Rules: RULES.md (reference only, not injected)
- State files: state/ directory
