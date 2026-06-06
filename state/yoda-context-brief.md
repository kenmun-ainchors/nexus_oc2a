### Platform Status
- **Day Count:** 42 (since 2026-04-25)
- **Current Time:** Saturday, June 6th, 2026 - 8:00 PM AEST
- **OC1 Status:** LIVE Production (Business Node)
- **OC2 Status:** Incoming (ETA Jul 2026)
- **Model Tier:** DeepSeek Primary | Kimi Fallback

### Key People
- **Ken Mun (CTO):** @AInchorsOC1Bot (Yoda) | 8574109706
- **Angie Foong (CEO):** @AInchorsAriaBot (Aria) | 8141152780

### Infrastructure
- **HIVE:** OC1 (Mac Mini M4 24GB) standalone business node.
- **Storage:** Tailscale mesh active. NAS backups configured (TKT-0269).
- **Security:** S1–S7 controls live. Warden drift monitoring (15-min cron).

### Current Sprint (S6: 2026-06-02 to 2026-06-08)
- **Status:** Committed (In Progress)
- **✅ Done:** TKT-0268 (PG Stability), TKT-0269 (NAS Backup), TKT-0310 (Constraint Paper), TKT-0322 (Routing Matrix), TKT-0321 (2-Pass Dispatch).
- **⏳ Pending:** TKT-0293 (Regression), TKT-0317 (Context Epic), TKT-0319 (Global TQP), TKT-0318 (Aria TQP), TKT-0326 (NAS Writable), TKT-0137 (Policy Register).
- **👀 Monitoring:** TKT-0327 (Tilde-Path).

### Approved Decisions (MEMORY.md)
- **Platform Separation:** OC1 = Business Node (Aria+6); OC2-A/B = Tech HIVE HA pair.
- **Budget:** A\$500 $\to$ \$150 USD/mo (effective Jun 1).
- **2-Pass Dispatch:** "No executor receives undiscovered work." (TKT-0317/0321).
- **Model Strategy:** DeepSeek = Permanent Primary. Kimi = Fallback only.
- **Constraint Enforcement:** TKT-0310 Option Paper approved (2026-06-02).

### Open Tickets (Top 10 Priority)
1. TKT-0317: Context Optimization Epic (High/XL)
2. TKT-0293: Regression Testing Framework (High/L)
3. TKT-0319: Global TQP Phase 3 (High/L)
4. TKT-0318: Aria TQP Phase 2 (High/M)
5. TKT-0326: NAS Writable Backup Target (Medium/M)
6. TKT-0137: Policy Register (Medium/M)
7. TKT-0114: AInchors–Aevlith Partnership (High - Gate)
8. TKT-0115: Register Aevlith ASIC (High - Blocked)
9. TKT-0120: RustDesk self-hosted OC1 (High)
10. TKT-0128: Aria marketing mandate (In-Progress)

### LinkedIn Queue
- **Status:** Paused until Sunday. (Rule: Missed posts push to next slot; never post late).

### Recent Telegram Decisions
- (No pending unsynced decisions found)

### Mandatory Rules for Telegram Sessions
- **Sovereignty:** Client data = Tier 0/1 local ONLY.
- **Execution:** Plan $\to$ Breakdown $\to$ Sequence $\to$ Execute $\to$ Verify (TKT-0228).
- **TQP Gate:** Persist state to PG before announcing completion (TKT-0309).
- **Dispatch:** RVEV Cycle (READ $\to$ VALIDATE $\to$ EXECUTE $\to$ VERIFY).
- **Chunking:** All messages $> 3,800$ chars MUST be split $[1/N]$.
- **Async:** Tasks $> 30\text{s} \to$ sessions_spawn.
- **Conservative Mode:** NO risky state manipulation without explicit Ken approval.
