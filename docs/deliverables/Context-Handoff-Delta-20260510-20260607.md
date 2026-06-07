# Context Handoff — Delta Addendum
**Period:** 2026-05-10 (Day 16) → 2026-06-07 (Day 43)
**Addendum to:** Context-Handoff-Delta-20260507-20260510.md
**Author:** Yoda 🟢 | **For:** Ken Mun, any agent resuming context
**CHG range:** CHG-0271 → CHG-0465 | **TKT range:** TKT-0143 → TKT-0368

---

## 🚨 CRITICAL: Three Foundational Architecture Challenges (NEW — 2026-06-07)

Ken has identified three foundational problem areas driving a deeper architecture research initiative:

### 1. Agentic Workflow Execution Decay
- 5-layer discipline stack built (OWL Guard → RVEV → 2-Pass → TQP Gate → DoD Gate) but gaps remain
- Observable decay: CHG-0401 "Done But Not Done" (607 items claimed migrated, not actually done), L-039 OWL drift during upgrade, gemma4 RVEV skipping in long sessions
- No closed-loop execution: current model is linear Plan→Breakdown→Sequence→Execute→Verify — plan doesn't adapt based on execution feedback
- Skills.md not used for execution discipline — 92% of rules are duplicated across agents

### 2. Model & Token Economics
- Yoda loads 123.8KB injected context per session (~30,943 tokens)
- Platform burns ~79,942 tokens/day on injected context alone
- 92% rule duplication across 14 agents (215 of 234 rule instances)
- Per-task context budget enforcement, model-aware context trimming, and per-atom cost tracking all missing

### 3. Agentic Memory Management
- 5-tier memory architecture designed (Phase 4) but only 2/5 tiers operational
- T3 (Episodic audit trail) and T4 (Semantic RAG) schemas designed but not deployed
- TQP execution gate: Phase 1 (Yoda) live, Phase 2 (Aria) + Phase 3 (all 14 agents) pending
- Root cause: LLM context window is primary state holder — not PostgreSQL

### Ken's Research Direction
Researching multi-step progression execution models (VMAO, POLARIS) for closed-loop plan→execute→validate→replan. 16 specific research questions across execution architecture, quality assurance, cost economics, memory integration, and practical implementation.

**Key docs produced:**
- `docs/deliverables/Nexus-Foundational-Architecture-Challenges-Assessment-v1.0.md` (33KB — SSOT)
- GDrive: https://drive.google.com/file/d/1U9MyQJwtSHaJeWvLw-LH-Tdqe2LVfVlQ/view?usp=drivesdk
- **TKT-0368** (backlog, high): "Nexus Foundational Architecture — 3-Area Solution Design" — full context locked in PG metadata
- **CHG-0465** logged

---

## 1. Platform State — Key Metrics (Day 43)

| Metric | Day 16 (May 10) | Day 43 (Jun 7) | Δ |
|--------|-----------------|-----------------|---|
| OC1 version | 2026.5.5 | 2026.5.27 | Upgraded |
| Active agents | 10 | 14 | +4 |
| PG tables | Not yet PG SSOT | 20 state tables | New capability |
| Total tickets | ~142 | 309 | +167 |
| Open tickets | ~30 | 61 | +31 |
| CHGs logged | CHG-0270 | CHG-0465 | +195 |
| Cron jobs | ~25 | 59 | +34 |
| Model strategy | Sonnet primary, haiku fallback | deepseek-v4-pro primary (Ollama Cloud $100/mo), Claude credits depleted | Major shift |
| Monthly budget | A$500 (temporary A$450) | $150 USD cap ($100 Ollama + $50 buffer) | Recalibrated |
| Sprint | Sprint 3 committed | Sprint 7 committed | +4 sprints |
| Sprints closed | S2 only | S2, S3, S4, S5, S6 (5 sprints) | +4 sprints |

---

## 2. Agent Fleet — Major Evolution (10 → 14 agents)

### New Agents Activated Since Day 16

| Agent | Role | Activated | Model | Status |
|-------|------|-----------|-------|--------|
| **Forge 🏗️** | Infra/SRE/CI/Backups | Day 17+ | gemma4:31b-cloud | 🟢 Active — primary build agent |
| **Luthen 🔍** | Marketing Intelligence | Day 32 | gemma4:31b-cloud | 🟢 First activation from spec v1.0 |
| **Ahsoka 🤍** | AI Transformation Consulting | Day 32 | gemma4:31b-cloud | 🟢 Workspace separated (workspace-ahsoka) |

### Workspace Separation (TKT-0308, Day 32)
- Forge → `workspace-infra/`, Ahsoka → `workspace-ahsoka/`, Luthen → `workspace-luthen/`
- 14 agents now have isolated workspaces with 14/14 RULES.md + 14/14 model-policy
- **Gap identified (TKT-0329):** Cross-workspace delivery undefined — Forge can't deliver scripts from workspace-infra to workspace/scripts without Yoda bridging manually. Thrawn assigned.

### Model Strategy Overhaul

**Conservative Mode (CHG-0349, Day 21 — STILL ACTIVE):**
- Trigger: Claude API credits depleted 2026-05-15
- Rule: NO RISKY STATE MANIPULATION without explicit Ken approval
- All agents on kimi/gemma4/deepseek-pro until `CLAUDE RESTORE` keyword issued by Ken

**kimi Decommissioned (Day 31, 2026-05-26):**
- deepseek-v4-pro:cloud = permanent primary for Yoda + Aria
- kimi-k2.6:cloud = fallback only
- 12 of 14 agents on gemma4:31b-cloud primary

**4-Tier Model Strategy (Target — post OC2):**
- T0: systemEvent $0 | T1: Gemma4:26b local (OC2) $0 | T2: Ollama Cloud $100/mo fixed | T3: Claude Sonnet FALLBACK ONLY
- Client data = T0/T1 local ONLY. Never cloud (DS-1 to DS-5 data sovereignty rules)

**Budget Recalibrated (CHG-0325, Day 31):**
- From A$500/month → $150 USD/month (effective Jun 1)
- Ollama Cloud Max $100/mo fixed subscription + $50 Claude buffer
- CI Cycle A/B decommissioned (CHG-0428). Warden 15-min drift monitoring replaces it

### Agent Governance
- **5-Tier Governance Model** approved (TKT-0103, Day 14)
- **ALL agents** now have SOUL.md (<10K chars), RULES.md, model-policy, and workspace isolation
- **RULES.md Foundation Repair** (TKT-0307, Day 32): 12 of 12 agents have RULES.md accessible via symlinks. Auto-heal CHECK 14 prevents regression
- **2-Pass Dispatch Contract** (TKT-0321, Day 33): "No executor receives undiscovered work" — platform-wide, not Yoda-only
- **TKT-0322 Model-Task Routing Matrix**: 4-tier complexity classifier (Routine→Standard→Complex→Governance) with per-agent model assignments

---

## 3. PostgreSQL SSOT Migration (PG Era — Days 25-33)

This is the single largest architectural shift in the delta period. PG is now the authoritative SSOT for platform state.

### What Moved to PG

| Domain | Before | After | Tickets |
|--------|--------|-------|---------|
| Tickets | tickets.json (file) | PG primary, JSON dual-write | TKT-0270 |
| Cost tracking | JSON files | PG state_cost table | TKT-0270 |
| Model policy | JSON files | PG state_model_policy | TKT-0270 |
| Agent shared state | JSON files | PG agent_shared_state | TKT-0270 |
| Task queue (TQP) | Cron/subagent ephemeral | PG state_task_queue — execution gate | TKT-0309 |
| Auto-heal logs | JSON files | PG state_autoheal_log | TKT-0295 |
| Diagnostics | JSON files | PG state_diagnostics | TKT-0295 |
| Uptime tracking | JSON files | PG state_uptime | TKT-0295 |
| KRI tracking | None | PG state_kri | TKT-0295 |
| Sprint state | JSON files | PG (dual-write) | TKT-0297 |
| Notion sync | Manual | pg-to-notion-sync.sh (idempotent, timestamp-filtered) | TKT-0297 |

### Key PG Infrastructure
- 20 state tables total (up from 5 at Day 16)
- `db-read.sh` / `db-write.sh` wrappers for all agent access
- JSONB schema contract published — unknown columns auto-merged into metadata
- sc_persist_atom() + sc_resume_context() for TQP execution gating
- ticket.sh reads PG primary via db.sh

### JSON → PG Migration (TKT-0295, Day 31 — COMPLETE)
- 7 tickets closed in chain
- Cron payloads migrated to PG reads
- 18 state tables at migration completion (now 20)

---

## 4. Execution Discipline Stack (Days 22-33)

The platform now has a 5-layer execution discipline stack — built incrementally from incidents:

```
LAYER 5: DoD Gate (TKT-0237 A1) — Pre-close validation
LAYER 4: TQP Execution Gate (TKT-0309) — PG commit required before "done"
LAYER 3: 2-Pass Dispatch (TKT-0321) — Discovery/Execution separation
LAYER 2: RVEV Cycle (TKT-0321) — READ→VALIDATE→EXECUTE→VERIFY per atom
LAYER 1: OWL Guard (TKT-0228) — Pre-session execution contract
```

### Key Components

**TQP Execution Gate (TKT-0309, Day 30 — APPROVED, Day 33 — Phase 2 LIVE):**
- No atom is "complete" until PG commit returns success
- Auto-resume: on restart, agent resumes from last persisted atom index
- Phase 1 (Yoda inline): 🟢 Live
- Phase 2 (Aria business): 📋 TKT-0318, pending
- Phase 3 (all 14 agents): 📋 TKT-0319, pending
- Schema: 5 new columns (parent_task_id, execution_context, atom_index, state_payload, persistence_type)

**2-Pass Dispatch Contract (TKT-0321, Day 33):**
- "No executor receives undiscovered work" — platform-wide rule
- Pass 1 (Discovery): Orchestrator breaks task into concrete atoms. No execution.
- Pass 2 (Execution): Specialist executes pre-discovered atoms via RVEV. No discovery.
- dispatch-validate.sh gate designed (TKT-0323 — not yet built)
- RVEV trace format defined; per-atom READ→VALIDATE→EXECUTE→VERIFY

**Platform Rule Engine (TKT-0237, Day 22):**
- DoD validation gate in ticket.sh — blocks close if deliverable doesn't exist
- dod-validator.sh cron (every 2h) — re-checks closed tickets
- 10-rule audit engine (R01-R10) covering path discipline, SoT compliance, model routing, template adherence, state checking, ID uniqueness, config drift, content governance, cron health, memory limits

**OWL Drift Detection (TKT-0228, Day 22):**
- owl-guard.sh — pre-session OWL contract for MEDIUM+ currency work
- Currency auto-detection (LOW/MEDIUM/HIGH)
- Chain-reaction detection: 3+ atoms without verification pauses
- Daily compliance tracking: <70% = Telegram alert, <70% sustained = restricted to LOW only

---

## 5. Sprint History — S3 through S7

### Sprint 3 (≈May 10-17) — CLOSED
| TKT | Title | Status |
|-----|-------|--------|
| TKT-0124 | MinIO agent layer (4 buckets, hybrid scope) | Done |
| TKT-0135 | Sandbox environment | Done |
| TKT-0141 | CLI-Anything supply chain security assessment | Done |
| Multiple | Various infra + LinkedIn pipeline fixes | Done |

### Sprint 4 (≈May 17-24) — CLOSED
| TKT | Title | Status |
|-----|-------|--------|
| TKT-0228 | OWL Drift Detection System | Done |
| TKT-0237 | Platform Rule Engine v1 | Done |
| TKT-0162 | Nexus Architecture Direction Option Paper | Done (Option B approved) |
| Multiple | PG migration groundwork, auto-heal hardening | Done |

### Sprint 5 (≈May 24-29) — CLOSED
| TKT | Title | Status |
|-----|-------|--------|
| 7 committed, 11 bonus delivered = 18 total | | |
| TKT-0295 | PG Audit chain (7 tickets) | Done |
| TKT-0307 | Agent RULES.md Foundation Repair | Done |
| TKT-0308 | Agent Workspace Separation | Done |
| TKT-0297 | PG→Notion Sync Redesign | Done |
| TKT-0236 | Standby mode + outage banner | Done |
| Critical+high tickets reduced from 17→8 (53%) | | |

### Sprint 6 (≈Jun 2-7) — CLOSED
| TKT | Title | Status |
|-----|-------|--------|
| TKT-0268 | Delegated Auth Health Check | Done |
| TKT-0269 | Memory Overflow Archive Pattern | Done |
| TKT-0310 | Platform Constraint Enforcement Option Paper | Done (APPROVED) |
| TKT-0321 | 2-Pass Dispatch Contract | Done |
| TKT-0322 | Model-Task Routing Matrix | Done |
| 3 bonus items | | |
| Total: 8 closed (5 committed + 3 bonus) | | |

### Sprint 7 (Jun 8-14) — COMMITTED (incoming)
Carries from Sprint 6. 7 items:

| Seq | TKT | Title | Agent | Effort |
|-----|-----|-------|-------|--------|
| 1 | TKT-0327 | Tilde-Path Normalization | Forge | S |
| 2 | TKT-0317 | Context Optimization Epic (4 children) | Atlas+Forge | XL |
| 3 | TKT-0293 | Regression Testing Framework | Forge | L |
| 4 | TKT-0319 | Global TQP Phase 3 | Atlas+Forge | L |
| 5 | TKT-0318 | Aria TQP Phase 2 | Yoda+Aria | M |
| 6 | TKT-0326 | NAS Writable Backup Target | Forge | M |
| 7 | TKT-0137 | Policy Register | Thrawn | M |

### Sprint 8 (Jun 15-21) — QUEUED
21 tickets. Theme: Platform Constraint Enforcement + PG SSOT Remediation. Includes CrewAI/Qwen3.6 PoC, MinIO hardening, Notion sync hardening, backup validation.

---

## 6. Key Architecture Milestones

### Golden Blueprints (Day 20, TKT-0172/0173)
Two definitive documents produced by Atlas, approved by Ken:
1. **Technology Strategy & Roadmap v1.0** — vision, principles, P1-P4 roadmap, model/cost strategy, OKRs, governance
2. **Nexus System Architecture v1.0** — full stack: agents, infra, data, integration, security, current + target state, gap map

These supersede ALL fragmented architecture docs. Referenced in AGENTS.md as mandatory reading.

### Platform Separation (Day 36 — APPROVED)
- OC1 repurposed as standalone business node (Aria + 6 agents)
- OC2-A/B remains tech HIVE HA pair — no cross-node
- Ken approved: C1 (second OpenClaw license), C2 (separate Ollama sub), C3 (new Google Workspace for tech)
- All 3 risks accepted. Phase 0 prep can start now
- Atlas option paper + Thrawn feasibility delivered to Drive

### Context Optimization Epic (TKT-0317, Day 33)
Atlas delivered 20KB Context Optimization Assessment via 2-pass execution (discovery JSON → assessment doc in 3m38s). Key findings:
- 92% rule duplication across 14 agents
- Yoda loads 123.8KB context per session
- 5 over-privilege findings (Spark has db-read.sh access — FLAG-01)
- 16 proposed tickets across 3 phases
- 55-64% projected Yoda context reduction
- 4 sub-tickets: TKT-0321 ✅, TKT-0322 ✅, TKT-0323 (pending), TKT-0324 (pending)

### Platform Constraints Audit (TKT-0310, Day 35 — APPROVED)
Thrawn produced option paper identifying:
- SOUL.md hard limit 10K chars with silent truncation on exceed
- MEMORY.md archive overflow pattern designed (8K warn, move to archives)
- HEARTBEAT.md loading 13.6KB in every session regardless of task
- Context window injection limits per model
- 5-mitigation sprint plan (Sprint 7 = P0-P2)

### Phase 4 Data & Memory Architecture (Day 7 — DESIGNED, not yet built)
5-tier memory architecture:
- T1 (Working): LLM context window — unmanaged
- T2 (Session): OpenClaw-managed, ephemeral
- T3 (Episodic/Audit): PG schema designed — immutable agent event log with hash-based tamper evidence — **NOT BUILT**
- T4 (Semantic/RAG): pgvector schema designed — vector store + RAG pipeline — **NOT DEPLOYED**
- T5 (Shared): agent_shared_state + agent_state_history PG tables — **PARTIALLY LIVE** (TQP + tickets + cost + sprints)
- APRA CPG 234/235 compliance checklist designed but not implemented
- PII detection pipeline (spaCy/Presidio) designed but not built

---

## 7. Infrastructure & Operations

### OpenClaw Upgrade (Day 34)
- Upgraded from v2026.5.12 → v2026.5.27
- 59 cron jobs, all integrations healthy
- Config slimmed (crons now in Gateway internal state)

### Auto-Heal & Monitoring
- 19-check nightly auto-heal (01:00 AEST) — expanded from 13 checks
- CHECK 14 added: Agent RULES.md foundation integrity (permanent prevention)
- CHECK 15 added: File size limit enforcement (TKT-0310)
- CHECK 16 designed: Cross-workspace delivery integrity (not yet built)
- Telegram fallback alert (CHG-0262): direct Bot HTTP, no Anthropic dependency
- Blog verification added to heartbeat (06:00 AEST daily) — catches silent blog failures (12-day outage caught)

### Backup & Recovery
- BASE1 restore runbook delivered
- NAS backup target configured
- Backup obs false positives fixed (regex)
- NAS writable backup target (TKT-0326, Sprint 7)

### Docker/Colima
- Docker Desktop removed (2026-05-11), replaced with Colima (brew)
- Colima auto-starts at login via brew services
- RustDesk containers managed via `infra/rustdesk/`

### Security
- Skill Installation Gate: 7-step policy (TKT → source verify → audit → manual read → Ken approval → install → registry)
- 63 skills baseline-registered, all CLEAN
- Gateway config snapshot + restore scripts live
- Delegated auth health monitoring (Gmail/Drive/sheets OAuth)

---

## 8. Key Decisions Locked Since Day 16

| Decision | Date | Detail |
|----------|------|--------|
| Option B (Phased) | May 14 | Nexus architecture direction. Work Currency Model drives all downstream decisions |
| 5-Tier Governance | May 8 | T0-T4 agent tiers approved. Aria=T1 at OC2 |
| PG as SSOT | May 20 | Postgres authoritative for state data. JSON = dual-write fallback |
| TQP Execution Gate | May 26 | Thrawn Option E approved. Phase 1 live, Phase 2-3 queued |
| 2-Pass Dispatch | May 27 | Platform-wide. "No executor receives undiscovered work" |
| Platform Separation | May 29 | OC1 = business node, OC2-A/B = tech HIVE. No cross-node |
| Budget Recalibration | May 29 | $150 USD/month. Ollama $100 fixed + $50 Claude buffer |
| Conservative Mode | May 15 | STILL ACTIVE. No risky state changes without Ken approval |
| kimi Decommissioned | May 26 | deepseek-v4-pro = permanent primary. kimi = fallback only |
| Platform Constraints | Jun 2 | TKT-0310 Option B approved. 5-ticket enforcement sprint |
| Foundational Assessment | Jun 7 | TKT-0368. 3-area challenge. Ken researching VMAO/POLARIS |

---

## 9. Lessons Learned (Selected — Days 16-43)

| ID | Date | Lesson |
|----|------|--------|
| L-026 | May 13 | Build/scripts → Forge ONLY. Atlas=EA assess. Thrawn=arch design. Never route build to architects |
| L-027 | May 13 | LinkedIn posting rule: missed post → next slot. Never post late. Skip if slot taken |
| L-034 | May 17 | JSON structure drift: always verify actual schema before querying |
| L-035 | May 17 | Notion SSOT sync: 55 duplicates, 14 status mismatches. Now daily auto-sync |
| L-039 | May 17 | OWL drift: chain-reaction execution flagged by Ken. Model-agnostic enforcement needed |
| L-041 | May 19 | Social media state in ONE file. Splitting guarantees drift |
| L-042 | May 19 | Force reload webchat when UI hangs after rate limit |
| L-043 | May 21 | Auto-heal items → DB B (Auto-Heal), NOT DB A (Backlog). 3-DB architecture |
| L-044 | May 26 | Agent RULES.md creation requires commissioning checklist. 5 gates |
| L-045 | May 27 | Agent workspace separation requires cross-workspace delivery paths defined |
| L-046 | May 28 | TQP gate prevents "Done But Not Done" — PG commit required before close |
| L-047 | May 28 | Every ticket MUST have description, not just title. Ticket Body Mandate |

---

## 10. Upcoming Milestones

| Milestone | ETA | Trigger |
|-----------|-----|---------|
| OC2-A/B arrival | Jul 6-13 | TRIGGER-01, TRIGGER-02 |
| OC2 commissioning | ~Jul 27 | Gemma4:26b local, HA cluster, NAS encrypted |
| Claude research (VMAO/POLARIS) | Ken-driven | Ken returns with solution paper → TKT-0368 review |
| P2 launch (first SME client) | Target end-Aug 2026 | TRIGGER-07 |
| Platform Separation Phase 0 | Post-OC2 | OC1 = business node, OC2 = tech HIVE |
| Sprint 7 execution | Jun 8-14 | 7 items committed |
| Sprint 8 execution | Jun 15-21 | 21 items queued |

---

## 11. Key Reference Docs (Current)

| # | Document | Status |
|---|----------|--------|
| 1 | Nexus System Architecture v1.0 | ✅ APPROVED (May 14) |
| 2 | Technology Strategy & Roadmap v1.0 | ✅ APPROVED (May 14) |
| 3 | TKT-0317 Context Optimization Assessment | 📋 DRAFT FOR REVIEW |
| 4 | TKT-0321 2-Pass Dispatch Contract v1.0 | 🟢 ACTIVE |
| 5 | TKT-0309 TQP Execution Gate Design | ✅ APPROVED |
| 6 | TKT-0322 Model-Task Routing Matrix v1.0 | 📋 Draft |
| 7 | Phase 4 Data & Memory Architecture | 📋 Designed, not built |
| 8 | Platform Constraints Audit v1.0 | 📋 Draft |
| 9 | Platform Separation Option Paper | ✅ APPROVED (May 29) |
| 10 | NFA Challenges Assessment v1.0 | 📋 DRAFT FOR REVIEW (Jun 7) |
| 11 | TKT-0310 Platform Constraint Enforcement | ✅ APPROVED (Jun 2) |
| 12 | DoD Validation Rules | 🟢 Live |
| 13 | Skill Installation Policy v1.0 | 🟢 Active |
| 14 | Model3-Policy v1.0 | 🟢 Active |

---

*Delta context complete. Full context: Context-Handoff-Delta-20260507-20260510.md + this document.*
*Next consolidation: when delta chain reaches 3+ or at next major milestone per Ken instruction.*
