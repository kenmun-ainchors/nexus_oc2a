### 🟢 Yoda Telegram Context Brief
**Last Updated:** 2026-06-07 20:00 AEST
**Platform Day:** 43 (since 2026-04-25)

#### 🚀 Platform Status
- **Phase:** MVP (OC1-only, core platform live)
- **Hardware:** OC1 (Mac Mini M4 24GB) LIVE. OC2-A/B (M4 Pro 48GB) ETA 6-13 Jul.
- **OpenClaw Version:** v2026.5.27
- **Current Model Strategy:** Sonnet primary + Ollama Cloud (DeepSeek permanent primary, kimi fallback).
- **Budget Cap:** A$150 USD/day.

#### 👥 Key People
- **Ken Mun (CTO):** @AInchorsOC1Bot | Emergency: "YODA THIS IS KEN"
- **Angie Foong (CEO):** @AInchorsAriaBot (Aria) | Highest Authority.

#### 🏗️ Infrastructure
- **HIVE:** OC1 Production. OC2-A/B for HA/NAS (Incoming).
- **Networking:** Tailscale mesh active.
- **State Store:** Postgres SSOT (18+ tables). TQP Execution Gate live.
- **Security:** S1-S7 controls live. Warden drift monitoring (15-min).

#### 📅 Current Sprint (Sprint 7)
- **Dates:** 2026-06-08 to 2026-06-14
- **Status:** Committed
- **Theme:** Sprint 6 Carries — Close Out
- **Next (S8):** Platform Constraint Enforcement + PG SSOT Remediation.

#### ✅ Approved Decisions
- **Platform Separation:** OC1 -> Business Node; OC2-A/B -> Tech HIVE HA pair (Approved).
- **Model Policy:** DeepSeek as permanent primary; kimi as fallback only (CHG-0526).
- **TQP Gate:** Execution gate operational for context retention (TKT-0309).
- **2-Pass Dispatch:** "No executor receives undiscovered work" mandate (TKT-0321).

#### 🎫 Open Tickets (Priority)
1. **TKT-0317:** Context Epic (Sprint 6 carry)
2. **TKT-0321:** Yoda Dispatch Discipline
3. **TKT-0322:** Routing Matrix
4. **TKT-0293:** Regression Testing
5. **TKT-0326:** NAS Writable
6. **TKT-0327:** Tilde-Path Bug Fix
7. **TKT-0318:** Aria TQP implementation
8. **TKT-0319:** Global TQP implementation
9. **TKT-0137:** Policy Register (POL-001+)
10. **TKT-0114:** Aevlith Partnership Gate

#### 📱 Social & Queue
- **LinkedIn:** Queue status: No active file found (linkedin-queue.json missing).
- **Rule:** Missed posts push to next slot; never post late.

#### ⚠️ Telegram Mandatory Rules
- **Chunking:** Messages > 3,800 chars MUST be split [1/N].
- **Async:** Tasks > 30s -> sessions_spawn. Never block webchat.
- **RVEV Cycle:** READ -> VALIDATE -> EXECUTE -> VERIFY.
- **Conservative Mode:** NO RISKY STATE MANIPULATION without explicit Ken approval (Active).
- **2-Pass Contract:** Complete Discovery (Pass 1) before dispatching to Specialists (Pass 2).

---
*Sourced from MEMORY.md, MEMORY_TICKETS.md, and sprint-current.json*

