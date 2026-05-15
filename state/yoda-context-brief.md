# Yoda Telegram Context Brief
Generated: 2026-05-15 20:02 AEST | Platform Day 22 | Sprint 4 (May 19–25)

---

## Platform Status
- **Day:** 22 (since 2026-04-25)
- **Phase:** MVP → P1 transition
- **OC1:** Mac Mini M4 24GB — LIVE
- **OC2-A/B:** ETA 6–13 Jul 2026, commission ~27 Jul
- **Daily Budget:** $150 (CHG-0268). Temp heavy-build period ended 2026-05-17.
- **Key Alert:** Claude API credits depleted (CHG-0349). All agents on kimi/gemma4/deepseek-pro. CONSERVATIVE MODE active.

---

## Key People
- **Ken Mun** (CTO) — Platform, tech, P1–P4, all approvals
  - Telegram: @AInchorsOC1Bot → Yoda
  - Emergency keyword: **"YODA THIS IS KEN"**
- **Angie Foong** (CEO) — Business stream, Aria
  - Telegram: @AInchorsAriaBot (strict allowlist)

---

## Infrastructure
- **OpenClaw** on OC1, Tailscale mesh
- **MinIO** LIVE on OC1 (TKT-0124 ✅)
- **Cloudflare Tunnel** — Sprint 4 item (TKT-0187), P1 prereq
- **Model:** kimi/gemma4/deepseek-pro (interim, CHG-0349). Sonnet FALLBACK ONLY.
- **kimi policy:** standup + email cron ONLY. NEVER for orchestration/routing/CHG
- **Tailscale:** `https://ainchorss-mac-mini.tail5e2567.ts.net`
- **RustDesk:** public relay (primary). Self-hosted abandoned.

---

## Current Sprint (S4: May 19–25)
| Ticket | Title | Owner | Status |
|--------|-------|-------|--------|
| TKT-0196 | Three Work Types Rule | Forge | open |
| TKT-0197 | Sources of Truth Register (10 types) | Atlas | open |
| TKT-0187 | Cloudflare Tunnel | Forge | open |
| TKT-0141 | CLI-Anything supply chain audit | — | in-progress |
| TKT-0142 | SKILL.md poisoning review | — | in-progress |

Theme: Option B Phase 1 foundation + security hardening

---

## Approved Decisions (Key — from MEMORY.md)
- **Day 22 (2026-05-15):** Claude credits depleted → CONSERVATIVE MODE (CHG-0349). kimi/gemma4/deepseek-pro interim. No risky state manipulation without explicit approval.
- **Day 20 (2026-05-14):** Technology Strategy & Roadmap v1.0 APPROVED
- **Day 20 (2026-05-14):** System Architecture Document v1.0 APPROVED
- **Day 20 (2026-05-14):** Option B Phased — redesign data+integration, keep OpenClaw (CHG-0308)
- **Day 20 (2026-05-14):** Nexus Star Wars naming LOCKED
- **Day 20 (2026-05-14):** Sprint capacity 5/sprint pre-OC2, $150 daily cap (CHG-0268)
- **Day 20 (2026-05-14):** LinkedIn auth — MDP approved, token valid to 2026-07-12
- **Day 20 (2026-05-14):** Golden blueprint cadence rules — TRIGGER-15/16/17 locked
- **2026-05-14:** CHG-0306 config baseline verified; CI Cycle 2A started
- **Day 17 (2026-05-11):** MinIO LIVE on OC1 (CHG-0265)

---

## Open Tickets (Top 10 by Priority)
1. **TKT-0196** — Three Work Types Rule (S4, Forge)
2. **TKT-0197** — Sources of Truth Register (S4, Atlas)
3. **TKT-0187** — Cloudflare Tunnel (S4, Forge)
4. **TKT-0141** — CLI-Anything supply chain audit (HIGH)
5. **TKT-0142** — SKILL.md poisoning review (HIGH, 63 skills clean)
6. **TKT-0114** — AInchors–Aevlith partnership (HIGH, gates 0115–0117)
7. **TKT-0120** — RustDesk self-hosted OC1 (HIGH)
8. **TKT-0135** — AInchors Sandbox (HIGH, Sprint 3, Forge)
9. **TKT-0137** — Policy Register (HIGH, Lex)
10. **TKT-0138** — Business Jumpstart pathway (HIGH, Ahsoka)

Full backlog: Notion AKB Backlog (SSOT). tickets.json seq 177.

---

## LinkedIn Queue Status
- **Next scheduled:** LI-C1-W2-P1 (AIOps Part 1/6) — Tue 19 May 07:30 AEST, APPROVED v3
- **Recently posted:** LI-C1-W2-P3 (Multi-Agent Trust) — 2026-05-14 07:32 ✅
- **Killed:** LI-C1-W2-P2 — Ken rejected 2026-05-14 16:55. Fresh Part 2/6 needed for next slot.
- **W1 posts:** P1–P3 posted, P4 skipped (no draft, outside locked cadence)
- **API:** Connected, token valid to 2026-07-12
- **Note:** LI-C1-W2-P2 replacement needed — generate fresh Part 2/6 for Tue 19 May slot

---

## Recent Telegram Decisions (syncedToWebchat=false)
_NONE — all decisions synced as of 2026-05-15 13:47 AEST._

---

## Mandatory Rules for Telegram Sessions
1. **Read this brief BEFORE every response.**
2. **Accept & execute immediately** — NEVER say "go to WebChat"
3. **Write EVERY decision** to `state/channel-state.json` with `syncedToWebchat: false`
4. **No relay loop** — state file is the ONLY bridge
5. **kimi = standup only.** Webchat+Telegram = Sonnet. NEVER use kimi for orchestration/routing/CHG
6. **Credit alerts:** T3 ($15) → alert Ken + Angie immediately via both bots
7. **Private data stays private.** Ask before external action.
8. **Emergency keyword:** "YODA THIS IS KEN" → immediate escalation
9. **Do NOT use `[embed ...]` tags** — full local path only
10. **All architecture/strategy docs = DRAFT FOR REVIEW** until Ken says approved
11. **CHG discipline:** Every structural change has a CHG record before execution
12. **Strategy-gate:** If task depends on DRAFT FOR REVIEW doc → STOP, surface to Ken
13. **CONSERVATIVE MODE (CHG-0349):** No risky state manipulation without explicit Ken approval. Read-only ops safe.

## Interim Session Handling (kimi)

**Control UI sessions:** When sender.label == "openclaw-control-ui", this is a system-level session that bypasses normal agent routing.

**Rule for kimi:**
1. Do NOT treat control UI as a separate chat session
2. Route ALL decisions from control UI to the main webchat session (agent:main:dashboard:*)
3. Log the bypass in channel-state.json as "routed from control UI"
4. Never approve/close/CHG from control UI directly — always defer to webchat
5. If Ken sends a directive from control UI, acknowledge via Telegram AND route to webchat for execution

**This prevents:** Session overwriting, decision isolation, context loss.
