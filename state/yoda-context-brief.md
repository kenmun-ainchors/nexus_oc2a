 # YODA TELEGRAM CONTEXT BRIEF
# Last Updated: 2026-05-31 14:00 AEST

## 📊 PLATFORM STATUS
- Day Count: 37 (since 2026-04-25)
- State: MVP / Pre-OC2
- Health: Healthy (OC v2026.5.27)
- Budget: $150/mo cap active (Jun 1), Ollama Cloud $100/mo fixed, Claude buffer $50.

## 👥 KEY PEOPLE
- Ken Mun (CTO): @AInchorsOC1Bot
- Angie Foong (CEO): @AInchorsAriaBot

## 🏗️ INFRASTRUCTURE
- OC1: Mac Mini M4 24GB (Production)
- OC2-A/B: Mac Mini M4 Pro 48GB x2 (ETA 6-13 Jul, Commission ~27 Jul)
- Storage: MinIO live on OC1; NAS backups pending automation.
- Connectivity: Tailscale mesh active.

## 🚀 CURRENT SPRINT (S6)
- Period: 2026-06-02 $ightarrow$ 2026-06-08
- Committed (5/5):
  - TKT-0268: PG Dual-Write Stability (S5 carry)
  - TKT-0269: First Scheduled pg_dump to NAS (Critical/S5 carry)
  - TKT-0327: Tilde-Path Normalization (In-Progress)
  - TKT-0317: Agent Context Optimization - Atlas assessment
  - TKT-0321: 2-Pass Dispatch Contract + Rules
- Gated: TKT-0241 (blocked on CLAUDE RESTORE)

## ✅ APPROVED DECISIONS
- PG SSOT: Postgres is authoritative for state data.
- TQP Gate: mandatory persistence discipline for atomic execution.
- Platform Separation: OC1 as business node, OC2-A/B as tech HIVE HA pair.
- Model Strategy: DeepSeek permanent primary, kimi fallback only.
- 2-Pass Dispatch: No executor receives undiscovered work.

## 🎫 TOP OPEN TICKETS (Priority)
- TKT-0269: NAS pg_dump automation (Critical)
- TKT-0268: PG Stability reconciliation (High)
- TKT-0317: Context Optimization Epic (High)
- TKT-0321: 2-Pass Dispatch Rules (High)
- TKT-0327: Tilde-Path Normalization (High)
- TKT-0114: Aevlith Partnership (High)
- TKT-0136: Consulting Playbook (High)
- TKT-0137: Policy Register (High)
- TKT-0138: Business Jumpstart pathway (High)
- TKT-0139: Consulting Product Portfolio (High)

## 📱 LINKEDIN QUEUE
- Status: 5 items registered.
- Recent: CONTENT-0005 (triad-cleared 2026-05-31).
- Blocked: TKT-0121 (Ken HF API key needed in Keychain).

## ⚡ RECENT TELEGRAM DECISIONS
- (No unsynced decisions found in state)

## ⚠️ MANDATORY TELEGRAM RULES
- CHG-0397: Chunk messages > 3,800 chars [1/N].
- CHG-0405: Tasks > 30s $ightarrow$ sessions_spawn (No blocking webchat).
- TKT-0309: Execute $ightarrow$ persist $ightarrow$ announce.
- CHG-0281: Absolute paths ONLY (No  or ).
- CHG-0297: PG primary reads via db.sh.
- CONSERVATIVE MODE: No risky state manipulation without explicit Ken approval.
