# YODA TELEGRAM CONTEXT BRIEF
Generated: Tuesday, June 2nd, 2026 - 8:00 PM AEST
Platform Day: 39 (Since 2026-04-25)

## 🚀 Platform Status
- **State:** MVP (OC1-only) $ightarrow$ Transitioning to P1 (OC2 Era)
- **Current Focus:** Sprint 6 (Context Optimization & Platform Separation Phase 0)
- **Budget:** Monthly cap A$500 $ightarrow$ $150 USD (effective Jun 1)
- **OpenClaw:** v2026.5.27 | 59 crons | TQP Gate Live

## 👥 Key People
- **Ken Mun (CTO):** Lead Authority. Bot: @AInchorsOC1Bot
- **Angie Foong (CEO):** Highest Authority. Bot: @AInchorsAriaBot

## 🏗️ Infrastructure
- **OC1:** Mac Mini M4 24GB (LIVE Production)
- **OC2-A/B:** Mac Mini M4 Pro 48GB $	imes (ETA 6–13 Jul 2026)
- **Network:** Tailscale mesh | NAS
- **Data:** Postgres (18-32 tables) SSOT for state | MinIO on OC1 ✅ LIVE

## 📅 Current Sprint (S6: 2026-06-02 to 2026-06-08)
- **Status:** Committed
- **Done:** 
  - TKT-0268: PG Dual-Write Stability ✅
  - TKT-0269: PG pg_dump Backup to NAS ✅
  - TKT-0310: Platform Constraint Enforcement ✅
- **Pending/In-Progress:**
  - TKT-0317: Context Optimization Epic (XL)
  - TKT-0293: Regression Testing Framework (L)
  - TKT-0321: 2-Pass Dispatch Discipline (M)
  - TKT-0322: Model-Task Routing Matrix (S-M)
  - TKT-0326: NAS Writable Backup Target (M)
  - TKT-0327: Tilde-Path Normalization (Monitoring)
  - TKT-0318/0319: Aria/Global TQP Phase 2/3 (M/L)
  - TKT-0137: Policy Register (M)

## ✅ Approved Decisions (Key)
- **Platform Separation:** OC1 $ightarrow$ Business Node (Aria + 6); OC2-A/B $ightarrow$ Tech HIVE HA Pair.
- **TQP Gate:** TQP as execution gate (Option E) approved and live.
- **Budget:** Shift to $150 USD/mo cap with fixed $100 Ollama Cloud + $50 Claude buffer.
- **Governance:** T0-T4 Model approved (Yoda lead $ightarrow$ Warden $ightarrow$ Specialist $ightarrow$ Verdict).
- **TKT-0310:** Platform Constraint Enforcement Option Paper approved.

## 🎫 Top Open Tickets (Priority)
1. **TKT-0317:** Context Optimization Epic (XL)
2. **TKT-0319:** Global TQP Phase 3 (L)
3. **TKT-0293:** Regression Testing Framework (L)
4. **TKT-0114:** Aevlith Partnership Gate (HIGH)
5. **TKT-0120:** RustDesk self-hosted OC1 (HIGH)
6. **TKT-0127:** Agentic Marketing Org Design (HIGH)
7. **TKT-0130:** QBR Fleet Review (HIGH)
8. **TKT-0135:** AInchors Sandbox (HIGH)
9. **TKT-0141:** CLI-Anything Supply Chain Audit (HIGH)
10. **TKT-0142:** SKILL.md Poisoning Review (HIGH)

## 📱 Social Queue
- **LinkedIn:** Paused until Sunday.
- **Rule:** Missed slots push to next available (Tue 07:30 $ightarrow$ Wed 12:00 $ightarrow$ Thu 07:30 $ightarrow$ next Tue). Never post late.

## ⚠️ Mandatory Telegram Rules
- **Chunking:** All messages $>$ 3,800 chars MUST be split [1/N].
- **Async:** Tasks $>$ 30s $ightarrow$ . Never block webchat.
- **TQP:** Persist state to PG before announcing completion.
- **Kimi:** Atomic tasks only + HITL for risky items.
- **Conservative Mode:** No risky state manipulation without Ken approval.
- **Routing:** Yoda orchestrates $ightarrow$ Specialist executes. No build work for Atlas/Thrawn.
- **Paths:** Always absolute paths (/Users/...). No ~ in tool calls.
