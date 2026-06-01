# YODA TELEGRAM CONTEXT BRIEF
**Generated:** 2026-06-01 14:00 AEST
**Platform Day:** 38 (from 2026-04-25)

## 🌍 Platform Status
- **State:** MVP Phase (OC1 Production)
- **Health:** Stable. OpenClaw v2026.5.27.
- **Budget:** Monthly cap A$500 → $150 USD active from Jun 1.
- **Models:** DeepSeek primary, Claude buffer $50, Ollama Cloud $100/mo fixed.

## 👥 Key People
- **Ken Mun (CTO):** Lead Authority.
- **Angie Foong (CEO):** Highest Authority.

## 🏗️ Infrastructure
- **OC1:** Mac Mini M4 24GB (LIVE Production).
- **OC2-A/B:** Incoming ETA 6–13 Jul 2026 (HA Pair).
- **Storage:** MinIO self-hosted on OC1.
- **Connectivity:** Tailscale mesh.

## 🎯 Current Sprint (S6)
- **Period:** 2026-06-02 to 2026-06-08
- **Committed Items:**
  - TKT-0268: PG Dual-Write Stability (S5 carry)
  - TKT-0269: pg_dump Backup to NAS (S5 carry / Critical)
  - TKT-0327: Tilde-Path Normalization (In Progress)
  - TKT-0317: Agent Context Optimization (Atlas Assessment)
  - TKT-0321: 2-Pass Dispatch Contract + Rules
- **Gated:** TKT-0241 (Blocked on CLAUDE RESTORE)

## ✅ Approved Decisions (MEMORY.md)
- **Platform Separation:** OC1 as business node, OC2-A/B as tech HIVE HA pair.
- **TQP Execution Gate:** Phase 2 complete. Mandatory persistence for all atoms.
- **Kimi Policy:** DeepSeek = Permanent Primary. Kimi = Fallback only.
- **S6 Budget:** $150/month cap active.

## 🎫 Top Open Tickets (Priority)
- TKT-0269: First Scheduled pg_dump Backup to NAS (Critical)
- TKT-0317: Epic: Agent Context Optimization (High)
- TKT-0268: PG Dual-Write Stability (High)
- TKT-0321: 2-Pass Dispatch Contract + Rules (High)
- TKT-0327: Tilde-Path Normalization (High)
- TKT-0114: AInchors–Aevlith partnership (High)
- TKT-0127: Agentic Marketing Org Design (High)
- TKT-0136: AInchors Consulting Playbook (High)
- TKT-0137: AInchors Policy Register (High)
- TKT-0138: Business Jumpstart pathway (High)

## ✍️ LinkedIn Queue Status
- **Last State:** 5 items in queue.
- **Recent Cleared:** CONTENT-0002 (May 28), CONTENT-0004 (May 30), CONTENT-0005 (May 31).
- **Pending Triad:** CONTENT-0001, CONTENT-0003.

## 📲 Recent Telegram Decisions (Sync Pending)
- *None found (all recent state synced to webchat/PG).*

## ⚠️ Mandatory Rules for Telegram Sessions
- **TQP Discipline:** Execute → Persist (TQP) → Announce. No 'Done' without persist.
- **Atomic Tasks:** Kimi model = ATOMIC ONLY. Verify each step.
- **Chunking:** Messages > 3,800 chars MUST be split [1/N].
- **Routing:** Yoda orchestrates; specialist work goes to named agents.
- **Tilde-Paths:** Use absolute paths. No $\sim$ or .
