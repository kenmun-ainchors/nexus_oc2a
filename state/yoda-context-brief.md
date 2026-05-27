# Yoda Telegram Context Brief
Generated: 2026-05-27 20:00 AEST | Platform Day 33 | Sprint 6 Queued

---

## Platform Status
- **Day:** 33 (since 2026-04-25)
- **Phase:** MVP → P1 transition
- **OC1:** Mac Mini M4 24GB — LIVE Production. PERMANENT.
- **OC2-A/B:** Mac Mini M4 Pro 48GB ×2 — ETA 6–13 Jul 2026, commission ~27 Jul
- **Daily Budget:** $150 (CHG-0268).
- **Key Alert:** CONSERVATIVE MODE active (CHG-0349). No risky state manipulation without explicit Ken approval.

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
- **Model:** DeepSeek is permanent primary. kimi = fallback only.
- **Tailscale URL:** `https://ainchorss-mac-mini.tail5e2567.ts.net`
- **RustDesk:** public relay (primary).
- **Colima:** auto-starts, replaces Docker Desktop.
- **TQP Execution Gate:** LIVE for Yoda (TKT-0309 ✅).

---

## Current Sprint
- **Status:** Sprint 5 Clean / Sprint 6 Queued.
- **Sprint 6 Queue:**
  - TKT-0310 (Platform Constraints)
  - TKT-0317 (Context Epic + 4 sub)
  - TKT-0268 (PG Stability)
  - TKT-0269 (PG Backup)
  - TKT-0293 (Regression)
  - TKT-0321-0322 (Dispatch)

---

## Approved Decisions (from MEMORY.md)
- **Model Strategy:** T0 (Local) → T1 (Gemma4 OC2) → T2 (Cloud kimi/DS) → T3 (Sonnet fallback).
- **Aevlith:** Technology holding entity, owns Nexus. Domain: aevlith.ai.
- **L-026:** Build/scripts → Forge ONLY. Atlas=EA assess. Thrawn=arch design.
- **LinkedIn Rule:** Missed post → push to next slot. Never post late.
- **S-SOP:** All external/client outputs pass Shield → Lex → Sage.
- **Nexus Naming:** Nexus=platform | Holocron=AKB | Bridge=cmd-centre | Citadel=client-portal.

---

## Open Tickets (Top 10 by Priority)
1. **TKT-0317** — Context Epic (S6 High)
2. **TKT-0114** — AInchors–Aevlith partnership (HIGH, gates 0115–0117)
3. **TKT-0115** — Register Aevlith ASIC (HIGH, blocked on 0114)
4. **TKT-0116** — aevlith.ai domain (HIGH, blocked on 0115)
5. **TKT-0141** — CLI-Anything supply chain audit (HIGH)
6. **TKT-0142** — SKILL.md poisoning review (HIGH, 63 skills clean)
7. **TKT-0137** — Policy Register (HIGH, Lex)
8. **TKT-0135** — AInchors Sandbox (HIGH, Forge)
9. **TKT-0136** — Consulting Playbook (HIGH)
10. **TKT-0138** — Business Jumpstart pathway (HIGH, Ahsoka)

Full backlog: Notion AKB Backlog (SSOT). tickets.json seq 251.

---

## LinkedIn Queue Status
- **Status:** `state/linkedin-queue.json` missing. Defer to Spark.
- **API:** Connected, token valid to 2026-07-12.

---

## Recent Telegram Decisions (syncedToWebchat=false)
*No data available in state/channel-state.json (file missing).*

---

## Mandatory Rules for Telegram Sessions
1. **Read this brief BEFORE every response.**
2. **Accept & execute immediately** — NEVER say "go to WebChat"
3. **Write EVERY decision** to `state/channel-state.json` with `syncedToWebchat: false`
4. **No relay loop** — state file is the ONLY bridge
5. **kimi = standup + email cron ONLY.** Webchat+Telegram = Sonnet/DeepSeek.
6. **Credit alerts:** T3 ($15) → alert Ken + Angie immediately via both bots
7. **Private data stays private.** Ask before external action.
8. **Emergency keyword:** "YODA THIS IS KEN" → immediate escalation
9. **Do NOT use `[embed ...]` tags** — full local path only
10. **All architecture/strategy docs = DRAFT FOR REVIEW** until Ken says approved
11. **CHG discipline:** Every structural change has a CHG record before execution
12. **Strategy-gate:** If task depends on DRAFT FOR REVIEW doc → STOP, surface to Ken
13. **CONSERVATIVE MODE (CHG-0349):** No risky state manipulation without explicit Ken approval.
14. **Interim Session Handling (kimi):** Control UI sessions bypass normal routing — defer to webchat for execution
