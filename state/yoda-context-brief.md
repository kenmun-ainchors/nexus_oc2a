# Yoda Telegram Context Brief
# Generated: Sun 5 Jul 2026 20:00 AEST | Platform Day 72

## Platform Status
- Day count: 72 (from 2026-04-25)
- Sprint 11 | 2026-07-06 to 2026-07-12 | STATUS: committed (planning completed 2026-07-05)
- OC1: Mac Mini M4 24GB — LIVE Production. HARD LIMIT: No local LLM inference >~8B Q4.
- OC2-A/B: Mac Mini M4 Pro 48GB ×2 — INCOMING ETA 6–13 Jul 2026. Commission ~27 Jul. OC2-gated items wait for TRIGGER-03.
- Current model: ollama/deepseek-v4-flash:cloud (this session)
- Ports: 18789 Production, 18791 Browser, 28789 Sandbox, 38789 Shadow (LOCKED)

## Key People
- Ken Mun — Co-founder, CTO. kenmun@ainchors.com | +61403650578 | Melbourne AEST
- Angie Foong — Co-founder, CEO. angie.foong@ainchors.com | +61430928371
- Agents: Yoda (lead), Aria (business/dual-principal), Forge (infra/SRE), Thrawn (platform-arch), Atlas (enterprise arch), Spark (social), Lando (BPM), Mon Mothma (change mgmt), Warden (governance), Shield (security), Lex (legal), Sage (QA), Krennic (infra, planned)

## Infrastructure
- OC1 (Production): Mac Mini M4 24GB — Docker via Colima, PostgreSQL (SSOT), MinIO (media), Tailscale mesh
- OC2-A/B (Incoming): M4 Pro 48GB ×2 — HA Primary + Standby, ~27 Jul commission
- NAS: Writable platform backup target — pending (TKT-0326)
- Sandbox: 28789 gateway — isolated Forge/build/infra workspace
- Containers: RustDesk relay managed via infra/rustdesk/
- Remote: RustDesk (primary relay) + Google Remote Desktop (past lock screen)

## Current Sprint (Sprint 11 — 2026-07-06 to 2026-07-12)
- STATUS: committed | Planning: 2026-07-05 completed
- Critical items: TKT-0342 (EPIC: PG SSOT Gap Remediation), TKT-0358 (PG table health monitor cron — critical, Sprint 12)
- Key high-priority Sprint 11 tickets: TKT-0352 (PG wire: knowledge docs/chunks), TKT-0354 (wire state_standups PG-first), TKT-0359 (PG-first write policy enforcement)
- Key high-priority unassigned: TKT-0114 (Aevlith partnership), TKT-0127 (Agentic Marketing Org), TKT-0128 (Aria marketing mandate), TKT-0138 (Business Jumpstart), TKT-0293 (Regression Testing Framework), TKT-0331 (Skill-Based Encapsulation)

## Approved Decisions (from MEMORY.md)
1. Governance Tier Model (T0–T4) — approved 2026-05-08 (TKT-0103)
2. CREST mandatory for all execution work (CHG-0545, 2026-06-13)
3. Forge-only rule: Build/scripts → ONLY Forge. Atlas=EA assess. Thrawn=arch design. Yoda=never execute.
4. No fabrication / evidence-only mandate (Ken, 2026-06-13)
5. Skills loader at scripts/skill-load.sh — canonical path, validated against index (TKT-0535, CHG-0623)
6. Notion 3-DB architecture (CHG-0401): Backlog, Auto-Heal, Archive
7. LinkedIn Foundation Arc v3.0 (CHG-0594): 4-week arc, Tue/Wed/Thu slots, strict voice rules
8. OC2 gating: MinIO+PG 2-sprint validation before OC2 (TRIGGER-13)
9. Port convention: 1xxxx production, 2xxxx sandbox, 3xxxx shadow (LOCKED 2026-06-08)
10. Subagent completion update rule (Ken directive 2026-07-03, CHG-0812 follow-up)

## Open Tickets (Top 10 by Priority)
1. TKT-0342 — EPIC: PG SSOT Gap Remediation — CRITICAL | Sprint 11
2. TKT-0358 — Create PG table health monitor cron — CRITICAL | Sprint 12
3. TKT-0125 — Roadmap Refinement — QBR 2026-Q3 instance — P1 | Unassigned
4. TKT-0130 — Agent Fleet Review — QBR 2026-Q3 instance — P1 | Unassigned
5. TKT-0114 — AInchors–Aevlith partnership — HIGH | pending
6. TKT-0127 — Agentic Marketing Org Design — HIGH | backlog
7. TKT-0128 — Aria expanded marketing orchestration — HIGH | backlog
8. TKT-0138 — Business Jumpstart — 3-part client pathway — HIGH | Sprint 8
9. TKT-0293 — Expand Regression Testing Framework — HIGH | Unassigned
10. TKT-0331 — Skill-Based Encapsulation — Ticket/Sprint/Standup/CHG — HIGH | Unassigned

## LinkedIn Campaign Status (4-Week Foundation Arc — Week 4 "The Shift")
- Next posts: LI-W4-P10 (Tue 8 Jul), LI-W4-P11 (Wed 9 Jul), LI-W4-P12 (Thu 10 Jul) — all APPROVED + image-ready
- Movement IV "The Shift" — closing week of the 4-week arc
- All 3 posts queued and approved by Ken (2026-07-05 batch)
- Published so far: W1(3), W2(3), W3(2) — Week 3 posts LI-W3-P7/P8 posted; LI-W3-P9 slotted but not yet in published list
- Voice rule NON-NEGOTIABLE: No AInchors, Yoda, Nexus, agent names, platform internals, em-dashes, "co-founder", finite time refs, consulting-speak, fake clients
- Accounts: Ken personal profile (effective from 2026-06-23 CHG-0739)

## Ollama Usage / Burn Status (as at 2026-07-04 20:00 AEST)
- Weekly limit: 56,571 requests (Mon 29 Jun — Mon 6 Jul)
- Used: 16,236 (28.7%) | Remaining: 40,335
- Burn rate: 126.8 req/hr | 2 days remaining in window
- Alert level: SILENT (below 50% threshold of 28,286)
- All thresholds green: 50% warn(28,286), 70% alert(39,600), 85% critical(48,085), 95% emergency(53,742)
- No action needed

## Mandatory Rules for Telegram Sessions
1. HUMAN AUTHORITY: Ken and Angie always have final say. Yoda recommends; they decide.
2. HITL GATES: Never self-approve outputs requiring human sign-off.
3. SKILL-FIRST RULE: Load skill via bash scripts/skill-load.sh <skill> before calling any domain script.
4. NO FABRICATION: Say "I don't know" and find out. Never invent, guess, or paper over gaps.
5. EVIDENCE-ONLY: Done/closed/verified = validated + backed by artifacts.
6. CREST MANDATORY: Load skill first; Plan+Verify+Replan+Synthesize+Close only. Execute is NEVER Yoda.
7. CHG DISCIPLINE: Every structural change has a CHG record before execution.
8. SUBAGENT DISPATCH: Load bash scripts/skill-load.sh subagent-dispatch. Always end turn with visible status.
9. FORGE EXECUTE GATE: Yoda NEVER directly edits scripts/infra/build files. Route to agentId="infra".
10. TELEGRAM CHUNKING: All messages chunked at 3,800 chars. Load skill: bash scripts/skill-load.sh telegram.
11. NO FABRICATION / SILENT REPLY: When nothing user-facing to say, respond with single NO_REPLAY token.

## Nexus Naming Reference
- Nexus=platform | Holocron=AKB | Bridge=cmd-centre | Citadel=client-portal | Holonet=live-data | Beacon=monitoring | Sanctum=governance | Datapad=reporting
- AInchor Solutions Pty Ltd (market-facing) | Aevlith Technologies Pty Ltd (tech holding)
- Domain: aevlith.ai (AYV-lith) | ASIC registration pending
