# Yoda Telegram Context Brief
Generated: 2026-06-13 14:00 AEST

## 🌍 Platform Status
- **Current Day:** Day 49 (from 2026-04-25)
- **Phase:** MVP (OC1-only)
- **Infrastructure:** OC1 (Mac Mini M4 24GB) - LIVE Production.
- **Incoming:** OC2-A/B ETA 6–13 Jul 2026.

## 👥 Key People
- **Ken Mun (CTO):** Co-founder. Primary lead.
- **Angie Foong (CEO):** Co-founder. Business lead.

## 🛠 Infrastructure & Routing
- **Network:** Tailscale Mesh | OC1 URL: https://ainchorss-mac-mini.tail5e2567.ts.net
- **Governance:** Yoda (Lead) → Aria (CEO+Yoda) → Warden (Yoda-Govern)
- **Specialists:** Forge (Build/Infra), Atlas (Enterprise Arch), Thrawn (Arch Design), Lando (BPM/Workflows), Mon Mothma (Change Mgmt), Spark (Content).
- **Guardians:** Shield (Security), Lex (Legal), Sage (QA).

## 🏃 Current Sprint (Sprint 7)
- **Dates:** 2026-06-08 to 2026-06-14
- **Status:** Committed | 87% Completion (14/16)
- **Top Open Tickets:**
  - TKT-0410: Fix SUB_CREST_TRANSITIONS: add 'verified' → terminal (S, Forge)
  - TKT-0525: CHG-0525: Fix pg-to-notion-sync.sh — JSONB Path (?, ?)

## ✅ Approved Decisions (Recent)
- **CHG-0545 (2026-06-13):** Locked 4 rules into SOUL.md (No fabrication, Evidence-only, CREST mandatory, Orchestrator-only).
- **CREST Loop (2026-06-09):** Locked Plan→Execute→Verify→Replan→Synthesize→Done.
- **Anthropic (2026-06-12):** PERMANENTLY PARKED per Ken directive.

## 📢 Content & Social
- **LinkedIn Queue:** No current state found in workspace.
- **Posting Rule:** Missed post → push to next slot. Never post late.

## ⚠️ Telegram Session Mandates
- **CREST Mandatory:** Every operational task must follow Plan→Execute→Verify→Replan→Synthesize→Done.
- **Skill-Gate:** `bash scripts/skill-load.sh <name>` must be run before any domain script call.
- **No Silent Execution:** Output Plan phase explicitly before tool use.
- **Model Discipline:** Plan/Verify/Replan (Strong) | Execute/Synthesize (Cheap).
- **Chunking:** All messages MUST be chunked at 3,800 chars.
- **Async:** Tasks > 30s MUST run via `sessions_spawn`.
- **Fabrication:** ZERO tolerance. Say "I don't know" if unsure.
