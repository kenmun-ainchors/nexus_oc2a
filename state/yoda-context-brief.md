# Yoda Telegram Context Brief
Generated: 2026-05-24 10:00 UTC | Platform Day 29 | Sprint 4 (May 19–25)

---

## Platform Status
- **Day:** 29 (since 2026-04-25)
- **Phase:** MVP → P1 transition
- **OC1:** Mac Mini M4 24GB — LIVE Production. PERMANENT.
- **OC2-A/B:** Mac Mini M4 Pro 48GB ×2 — ETA 6–13 Jul 2026, commission ~27 Jul
- **Daily Budget:** $150 (CHG-0268).
- **Key Alert:** CONSERVATIVE MODE active (CHG-0349). Claude credits depleted. All agents on kimi/gemma4/deepseek-pro until CLAUDE RESTORE keyword issued.

---

## Key People
- **Ken Mun** (CTO) — Platform, tech, P1–P4, all approvals
  - Telegram: @AInchorsOC1Bot → Yoda | chatId: 8574109706
  - Emergency keyword: **"YODA THIS IS KEN"**
- **Angie Foong** (CEO) — Business stream, Aria
  - Telegram: @AInchorsAriaBot (strict allowlist) | chatId: 8141152780

---

## Infrastructure
- **OpenClaw** on OC1, Tailscale mesh
- **MinIO** LIVE on OC1 (TKT-0124 ✅, CHG-0265)
- **Model:** kimi/gemma4/deepseek-pro (interim, CHG-0349). Sonnet FALLBACK ONLY.
- **kimi policy:** standup + email cron ONLY. NEVER for orchestration/routing/CHG/state.
- **Tailscale URL:** `https://ainchorss-mac-mini.tail5e2567.ts.net`
- **RustDesk:** public relay (primary). Self-hosted CLOSED (TKT-0120, DEC-20260516-1256).
- **Colima:** auto-starts, replaces Docker Desktop
- **Docker socket:** `unix:///Users/ainchorsangiefpl/.colima/default/docker.sock`

---

## Current Sprint (S4: May 19–25)
*Note: sprint-current.json not found; using last known S4 commit.*

| Ticket | Title | Owner | Status |
|--------|-------|-------|--------|
| TKT-0127 | Agentic Marketing Org Design | Yoda | planned |
| TKT-0196 | Three Work Types Rule | Forge | planned |
| TKT-0197 | Sources of Truth Register | Atlas | planned |
| TKT-0198 | JSON to Postgres Migration | Forge | planned |
| TKT-0182 | Explicit state checking pattern | Thrawn | planned |
| TKT-0228 | OWL Drift Detection System | Yoda | planned |

---

## Approved Decisions (from MEMORY.md)
- **Model Strategy:** T0 (Local) → T1 (Gemma4 OC2) → T2 (Cloud kimi/DS) → T3 (Sonnet fallback).
- **Aevlith:** Technology holding entity, owns Nexus. Domain: aevlith.ai.
- **L-026:** Build/scripts → Forge ONLY. Atlas=EA assess. Thrawn=arch design.
- **LinkedIn Rule:** Missed post → push to next slot. Never post late.
- **Kimi Policy:** Standup/email only. NO complex orchestration/routing/CHG/state.
- **S-SOP:** All external/client outputs pass Shield → Lex → Sage.
- **Nexus Naming:** Nexus=platform | Holocron=AKB | Bridge=cmd-centre | Citadel=client-portal.

---

## Open Tickets (Top 10 by Priority)
1. **TKT-0114** — AInchors–Aevlith partnership (HIGH, gates 0115–0117)
2. **TKT-0115** — Register Aevlith ASIC (HIGH, blocked on 0114)
3. **TKT-0116** — aevlith.ai domain (HIGH, blocked on 0115)
4. **TKT-0141** — CLI-Anything supply chain audit (HIGH)
5. **TKT-0142** — SKILL.md poisoning review (HIGH, 63 skills clean)
6. **TKT-0137** — Policy Register (HIGH, Lex, S4 assigned)
7. **TKT-0135** — AInchors Sandbox (HIGH, Forge)
8. **TKT-0136** — Consulting Playbook (HIGH)
9. **TKT-0138** — Business Jumpstart pathway (HIGH, Ahsoka)
10. **TKT-0127** — Agentic Marketing Org Design (S4, Yoda)

Full backlog: Notion AKB Backlog (SSOT). tickets.json seq 199.

---

## LinkedIn Queue Status
- **Status:** linkedin-queue.json not found. Defer to Spark for current state.
- **API:** Connected, token valid to 2026-07-12

---

## Recent Telegram Decisions (syncedToWebchat=false)
| Decision | Summary | Ticket | Action |
|----------|---------|--------|--------|
| DEC-20260517-0918 | CHG-0362 APPROVED: Warden drift docs + Conservative Mode runbook | — | approved |
| DEC-20260516-1244 | TKT-0178 Routing Enforcement approved, sprint-assigned | TKT-0178 | approved |
| DEC-20260516-1252 | LI-C1-W2-P1 v3 APPROVED + TKT-0179 Option B confirmed | LI-C1-W2-P1, TKT-0179 | approved |
| DEC-20260516-1256 | TKT-0120 RustDesk self-hosted CLOSED — sufficient | TKT-0120 | closed |
| DEC-20260516-1304 | TKT-0137 + subs tagged to Sprint 4 | TKT-0137 | sprint-assigned |

_Last synced to webchat: 2026-05-15 13:47 AEST_

---

## Mandatory Rules for Telegram Sessions
1. **Read this brief BEFORE every response.**
2. **Accept & execute immediately** — NEVER say "go to WebChat"
3. **Write EVERY decision** to `state/channel-state.json` with `syncedToWebchat: false`
4. **No relay loop** — state file is the ONLY bridge
5. **kimi = standup + email cron ONLY.** Webchat+Telegram = Sonnet. NEVER use kimi for orchestration/routing/CHG
6. **Credit alerts:** T3 ($15) → alert Ken + Angie immediately via both bots
7. **Private data stays private.** Ask before external action.
8. **Emergency keyword:** "YODA THIS IS KEN" → immediate escalation
9. **Do NOT use `[embed ...]` tags** — full local path only
10. **All architecture/strategy docs = DRAFT FOR REVIEW** until Ken says approved
11. **CHG discipline:** Every structural change has a CHG record before execution
12. **Strategy-gate:** If task depends on DRAFT FOR REVIEW doc → STOP, surface to Ken
13. **CONSERVATIVE MODE (CHG-0349):** No risky state manipulation without explicit Ken approval. Read-only ops safe.
14. **Interim Session Handling (kimi):** Control UI sessions bypass normal routing — always defer to webchat for execution
