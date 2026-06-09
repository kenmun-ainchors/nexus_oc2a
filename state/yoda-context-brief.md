 # NEXUS PLATFORM CONTEXT BRIEF
## 📊 Platform Status
- **Current Date:** Tuesday, June 9, 2026
- **Platform Day:** Day 46 (since 2026-04-25)
- **OpenClaw Version:** v2026.5.27
- **Environment:** OC1 (Production) | Shadow (38789)

## 👥 Key People
- **Ken Mun (CTO):** Primary authority. Emergency: "YODA THIS IS KEN"
- **Angie Foong (CEO):** Highest authority.

## 🏗️ Infrastructure
- **OC1:** Mac Mini M4 24GB (LIVE Production)
- **OC2-A/B:** Mac Mini M4 Pro 48GB ×2 (ETA Jul 6–13, 2026)
- **Networking:** Tailscale mesh, Cloudflare Tunnel
- **Storage:** MinIO (native macOS binary)

## 🎯 Current Sprint (S7)
- **Dates:** 2026-06-08 to 2026-06-14
- **Theme:** Sprint 6 Carries — Close Out
- **Status:** Committed
- **Next Sprint (S8):** Platform Constraint Enforcement + PG SSOT Remediation

## ✅ Approved Decisions (from MEMORY.md)
- **Platform Separation:** OC1 repurposed as standalone business node; OC2-A/B as tech HIVE HA pair.
- **Budget:** Monthly cap A$500 → $150 USD (eff. Jun 1).
- **Model Strategy:** DeepSeek = permanent primary; kimi = fallback only.
- **Governance:** 2-Pass Dispatch ("No executor receives undiscovered work") and RVEV Cycle.
- **C1 Divergence Gate:** 7-day window (Jun 8 → Jun 15) for Shadow PG validation.

## 🎫 Open Tickets (Top 10 Priority)
- **TKT-0114:** AInchors–Aevlith partnership agreement (HIGH)
- **TKT-0127:** Agentic Marketing Org Design (HIGH)
- **TKT-0136:** AInchors Consulting Playbook (HIGH)
- **TKT-0137:** AInchors Policy Register (HIGH)
- **TKT-0138:** Business Jumpstart pathway (HIGH)
- **TKT-0139:** Consulting Product Portfolio (HIGH)
- **TKT-0141:** CLI-Anything supply chain risk (HIGH)
- **TKT-0142:** SKILL.md poisoning review (HIGH)
- **TKT-0169:** Typed Agent Contracts (HIGH)
- **TKT-0170:** PII Scanner on Document Ingestion Pipeline (HIGH)

## 📱 Content Queue
- **LinkedIn Queue:** Active (SSOT: linkedin-campaign.json). Theme: "What AI Agents in Production Actually Look Like". Last posted: LI-W3-P3 (2026-05-22). Current status: Drafts cancelled by Ken; awaiting fresh restart at Sunday planning.
- **Content Queue:** active.

## 🔄 Recent Telegram Decisions
- *No entries with syncedToWebchat=false found in current state files.*

## ⚠️ Mandatory Rules for Telegram
1. **Telegram Chunking:** All messages > 3,800 chars MUST be split at paragraph boundaries, numbered [1/N], and sent sequentially (CHG-0397).
2. **Async Background:** Tasks > 30s must use sessions_spawn. Never block webchat (CHG-0405).
3. **Conservative Mode:** No risky state manipulation without explicit Ken approval (CHG-0349).
4. **Routing Discipline:** Yoda orchestrates. No specialist work executed directly by the orchestrator (CHG-0297).
5. **RVEV Cycle:** READ → VALIDATE → EXECUTE → VERIFY for every atom.
