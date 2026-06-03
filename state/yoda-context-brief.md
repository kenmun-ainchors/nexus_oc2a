### 🟢 YODA TELEGRAM CONTEXT BRIEF
**Last Refresh:** 2026-06-03 20:00 AEST
**Platform Day:** 40 (Since 2026-04-25)

#### 📊 Platform Status
- **Phase:** MVP (OC1-only, core platform live)
- **Runtime:** OC1 (Mac Mini M4 24GB) | v2026.5.27
- **Health:** 59 crons active, integrations healthy.
- **Budget:** Monthly cap A$500 $ightarrow$ $150 USD (eff. Jun 1).

#### 👥 Key People
- **Ken Mun (CTO):** Principal Authority. Telegram: 8574109706
- **Angie Foong (CEO):** Highest Authority. Telegram: 8141152780

#### 🏗️ Infrastructure
- **OC1:** Production Node (Permanent).
- **OC2-A/B:** Incoming (ETA 6-13 Jul), HA Pair.
- **Connectivity:** Tailscale Mesh.
- **Storage:** NAS (Encrypted post-OC2).

#### 🏃 Current Sprint (S6: 2026-06-02 to 2026-06-08)
- **Status:** In Progress.
- **Completed:** 
  - TKT-0268: PG Dual-Write Stability ✅
  - TKT-0269: PG pg_dump to NAS ✅
  - TKT-0310: Platform Constraint Enforcement ✅
  - TKT-0322: Model-Task Routing Matrix ✅
  - TKT-0321: 2-Pass Dispatch Discipline ✅
- **Pending/High:** TKT-0317 (Context Epic), TKT-0293 (Regression), TKT-0319 (Global TQP), TKT-0318 (Aria TQP).

#### ⚖️ Approved Decisions (Key)
- **Platform Separation:** OC1 as business node (Aria+6 agents), OC2-A/B as tech HIVE HA pair.
- **2-Pass Contract:** "No executor receives undiscovered work." (Discovery $ightarrow$ Execution).
- **TQP Gate:** TQP as a hard gate for context retention, not just a hook.
- **Model Strategy:** Client data = T0/T1 local ONLY. DeepSeek permanent primary, Kimi fallback.

#### 🎫 Top Open Tickets (Priority)
1. TKT-0317: Context Optimization Epic (XL)
2. TKT-0319: Global TQP Phase 3 (L)
3. TKT-0318: Aria TQP Phase 2 (M)
4. TKT-0293: Regression Testing Framework (L)
5. TKT-0326: NAS Writable Backup Target (M)
6. TKT-0137: Policy Register (M)
7. TKT-0114: AInchors–Aevlith Partnership (High/Gate)
8. TKT-0115: Register Aevlith ASIC (High)
9. TKT-0120: RustDesk self-hosted OC1 (High)
10. TKT-0135: AInchors Sandbox (High)

#### 📱 LinkedIn Queue
- **Status:** Paused until Sunday.

#### 🛰️ Recent Telegram Decisions
- *No pending unsynced decisions found in current state.*

#### ⚠️ Mandatory Telegram Rules
- **Chunking:** Messages $> 3,800$ chars MUST be split [1/N].
- **Async:** Tasks $> 30	ext{s}$ MUST run via `sessions_spawn`.
- **Tilde-Path:** NEVER use `~` in tool calls; use absolute `/Users/...` paths.
- **RVEV:** Every atom: READ $ightarrow$ VALIDATE $ightarrow$ EXECUTE $ightarrow$ VERIFY.
- **Kimi Rule:** Atomic tasks ONLY + HITL for risky items.
