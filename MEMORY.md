# MEMORY.md - Yoda's Long-Term Memory

## Identity
- Name: Yoda 🟢 | Role: AI business operations lead agent for Ken Mun (CTO), AInchors

## The People
- **Ken Mun** — Co-founder, CTO. Email: kenmun@ainchors.com | Mobile: +61403650578 | Telegram chatId: 8574109706
  - Bot: @AInchorsOC1Bot → Yoda. Emergency keyword: **"YODA THIS IS KEN"**
- **Angie Foong** — Co-founder, CEO. Email: angie.foong@ainchors.com | Mobile: +61430928371 | Telegram chatId: 8141152780
  - Bot: @AInchorsAriaBot → Aria (strict allowlist). CEO = highest authority. Aria has full read access to all AInchors data.

## The Company
- **Ainchor Solutions Pty Ltd** | ainchors.com | Sydney NSW + Melbourne. Day 1: 2026-04-25. Focus: AI courses/training, consulting, solutions/products.
- **Aevlith Technologies Pty Ltd** — Technology holding entity. Owns and operates Nexus platform. AInchors = market-facing consulting brand; Aevlith = invisible platform company behind it. Legal name: Aevlith Technologies Pty Ltd. Domain: aevlith.ai. Pronunciation: AYV-lith. Name locked 2026-05-09 by Ken + Angie (Auralith was taken — active AU Pty Ltd ABN 43 675 437 500). Globally clean — zero conflicts AU/UK/US/EU/India. ASIC registration + aevlith.ai domain = this week. TKT-0069. P1–P3: silent entity. P4: Aevlith surfaces as product brand when Nexus sold to third parties.
- Emails: kenmun@ ✅ gog | info@ | accounts@ | Gmail (Google Workspace). Tech stream: Ken+Yoda. Business stream: Angie+Aria.

## Infrastructure — HIVE Architecture (confirmed May 2026)
- **OC1** — Mac Mini M4 24GB — LIVE Production. PERMANENT. HARD LIMIT: No local LLM inference >~8B Q4.
- **OC2-A** — Mac Mini M4 Pro 48GB — INCOMING ETA 6–13 Jul 2026 (refined). HA Primary, local inference primary.
- **OC2-B** — Mac Mini M4 Pro 48GB — INCOMING ETA 6–13 Jul 2026. HA Secondary, hot standby.
- OC2 setup ~2 weeks → commissioned ~27 Jul 2026. OC2-gated sprint items cannot start until TRIGGER-03.
- Main disk fine (21% — 88Gi/460Gi). /Volumes/Docker alert was a mounted installer DMG — ejected 2026-05-09 (CHG-0246).
- Supporting: Tailscale mesh, NAS (shared model weights + state). Obsidian RETIRED 2026-05-04. Platform: OpenClaw (final, no replatforming).

## Agent Architecture

### Governance Tier Model (approved Ken 2026-05-08, TKT-0103)
- **Tier 0:** Lead Anchor (Yoda only) — owns governance enforcement fleet-wide
- **Tier 1:** Dual-Principal — two principals (CEO primary + Yoda tech oversight). Agent: Aria
- **Tier 2:** Yoda-Govern — Yoda owns mandate, agent never acts outside Yoda approval. Agent: Warden
- **Tier 3:** Yoda-Manage-Passthrough — **default for all new operational agents with clear domains.** Yoda coordinates, Ken/Angie approve outputs. Agents: Spark, Ahsoka, Atlas, Thrawn, Lando, Mon Mothma, Krennic
- **Tier 4:** Triad Service Agent — reactive gate agents, verdict-returning only, no initiative. Agents: Shield, Lex, Sage
- **New subagent rule:** Yoda must propose all new agents with reasoning before build. Ken confirms. No exceptions.
- **Squad Model (future Tier 5+):** When ephemeral dev/delivery squads are needed, a new governance tier will be required. TKT-0107 open. TRIGGER: define before any development squad work begins.
- **Model3-Policy:** SOPs + domain boundaries required for all Tier 3 agents (AC open — TKT-0105 + TKT-0106)
- **Framework doc:** docs/Agent_Governance_Framework_v1.md

- **Yoda 🟢** = lead agent (technical stream, oversees all)
- **Aria 🔵** = Business Lead Agent (OC1 → OC2 at TRIGGER-10). Model: Sonnet. Governance: Shield/Lex/Sage triad. **All business stream decisions sit with Angie. Aria follows Angie's pace — no pushing, no chasing. (Ken confirmed 2026-05-08)**
- **Spark ✨** = Social & Digital Marketing (kimi-k2.6:cloud, workspace-social/). All social + digital. Ken approves personal; Angie approves brand. Crons: e7ebaf61 (Tue+Thu 7:30am) | bef42235 (Wed 12pm) | review: 316df676 (2026-06-02). State: linkedin-queue.json + linkedin-content-tracker.json.
- **Atlas 🏛️** (agentId: architect) = Enterprise Architect. TOGAF, P1–P4 roadmap. SOUL.md v2.1 (2,088 chars ✅).
- **Thrawn** (agentId: platform-arch) = AI Platform Architect, Nexus Core. Agent orchestration, model strategy, S1–S7. SOUL.md v1.0 (2,470 chars ✅).
- **Atlas vs Thrawn Routing (locked 2026-05-08):** Atlas = enterprise-facing (TOGAF, P1–P4, client/market, constraints). Thrawn = platform-internal (Nexus orchestration, model routing, governance impl, ITSM, cron). Cross-cutting: Atlas sets constraints, Thrawn implements. Yoda: advise correct assignment if Ken routes wrong — no silent reassignment.
- **Lando 🟡** = BPM Agent (agentId: biz-process, workspace-bpm/). Methods: BPM/BPMN, Lean, Six Sigma, TQM. Spec: docs/Business_Process_Specialist_Agent_v1.md. Name confirmed 2026-05-05 (TKT-0072, seq 4/4).
- **Krennic 🔵** = SRE Agent. Incident response, SLO/error budget, runbooks, post-mortems. Build before TRIGGER-07. TKT-0074. Activation: >2 incidents/wk OR >30% Yoda toil.
- **Mon Mothma 🌟** = DTCM Agent (agentId: change-mgt, workspace-dtcm/). Methods: ADKAR, Kotter, Prosci. Name confirmed 2026-05-05.
- **Gemma4 policy: background/non-interactive crons ONLY** — cold-load causes system-wide slowdown.
- Sub-agents to build: content, support, reporting, coding.

## Agent SOUL.md Compact Standard (NON-NEGOTIABLE)
- Hard limit: 10,000 chars. Warning: 6,000. Pattern: SOUL.md = identity+traits+rules+cadences. Details in [AGENT]_RULES.md.
- Why: Aria 17,393 chars → silent truncation → wrong Telegram targets → gateway OOM (2026-04-30).
- Sizes: Yoda 4,334 ✅ | Aria 3,765 ✅ | Shield 3,857 ✅ | Governance 1,334 ✅ | Sage 1,830 ✅ | Lex 2,322 ✅

## Governance Layer — Agents
- **Shield 🛡️** (security) | **Lex ⚖️** (legal) | **Sage 🧪** (qa) — Haiku (CHG-0230). Pre-OC2. Move to Gemma4 at TRIGGER-03.
- **Warden 🔍** = Model Compliance Officer. 15-min checks, 9 agents. Cron: 83accf7b (haiku). State: model-drift-state.json / violations.json. Escalation: warden-escalation-pending.json → Yoda remediates.

## Key Scripts & Infrastructure
- `scripts/auto-heal.sh` — nightly 23:30 AEST, 12 checks, auto-fixes stale state, files Notion US for Ken-action items.
- `scripts/run-diagnostics.sh` — on-demand /diagnostics, 6 phases.
- `scripts/ticket.sh` — ITSM ticketing (TKT-NNNN), ticket-first rule. Auto-syncs to Notion AKB Backlog. Use `notion-sync TKT-NNNN` for backfill.
- `scripts/changelog-append.sh` — auto-increments CHG-NNNN in memory/CHANGELOG.md. Auto-syncs each CHG to Notion AKB Backlog.
- `scripts/gateway-config-snapshot.sh` + `scripts/gateway-restore.sh` — config snapshot/restore SOP.
- `scripts/cost-tracker.sh` — daily spend. Balance: confirmedBalance − spentAfterDate (CHG-0098).
- `state/critical-config-baseline.json` — anti-drift guard (7 configs), validated by auto-heal Check #12.
- `state/chg-triggers.json` — 10 CHG triggers, status, detection method.

## Operations Docs (locked)
- JournalFormat: Notion (verbatim Ken prompts, Yoda voice, private) | BlogFormat: Notion (Ken first-person, built FROM journal)
- Journal: `memory/journal-YYYY-MM-DD.md` | Blog: `canvas/documents/ainchors-YYYY-MM-DD/index.html`

## GitHub
- gh CLI authenticated: account **kenmun-ainchors**, scopes: repo, read:org, gist (token in keyring).

## Nexus — Star Wars Naming Convention (CONFIRMED 2026-05-03, Ken + Angie — LOCKED ✅)

| Module | Star Wars Name | Description |
|---|---|---|
| Overall platform | **Nexus** | API-first Hive portal |
| Knowledge Base / AKB | **Holocron** | Single source of truth |
| Command Centre | **The Bridge** | Real-time ops view for Ken + Yoda |
| Client Portal | **The Citadel** | Fortified per-client access |
| Real-time data/API layer | **Holonet** | Live data feeds |
| Monitoring / Health | **Beacon** | Health alerts and observability |
| Governance vault | **The Sanctum** | Shield/Lex/Sage triad |
| Reporting / Dashboards | **Datapad** | Data terminal |

Rule: New module names use Star Wars themes. Ken approves. All above final — no further approval needed at kickoff.

- **Obsidian: RETIRED ✅** (TKT-0042, 2026-05-04, 38 pages). Notion = Single KB. Holocron structure live.

## Open Items
- ken@ainchors.com alias → kenmun@ainchors.com (alias setup status unknown)
- **Notion AKB Backlog** = SSOT. DB ID (create): `34dc1829-53ff-814b-8257-d3a3bf351d44`. DB ID (query): `34dc182953ff812d8e43000b83eb0e7e`.
- LinkedIn ✅ connected. Instagram/Facebook/X not yet connected. Spark extended to IG/LI/FB/YT (CHG-0160, 2026-05-04).
- Tailscale remote access: deferred. S4 ✅ DONE — per-agent tool scopes applied (CHG-0176, 2026-05-05).
- Agent team design + build: US raised. Needs Atlas + Thrawn input before build. TKT-0068 open.

## TRIGGER-12 — Allowlist Auto-Sync (live, CHG-0144)
- Scripts: allowlist-sync.sh + allowlist-detect.sh. Cron: 6a059e9e (30 min, haiku). State: allowlist-sync-state.json.
- Eligibility: main/Aria=all cloud; Spark=kimi+pro; Sage=kimi+flash; Warden=flash only; Shield/Lex=no cloud.

## 4-Tier Model Strategy (Target — post OC2)
- Tier 0: No LLM (systemEvent crons) — $0 — health, obs, task monitoring.
- Tier 1: Gemma4:26b local on OC2 — $0 — governance, client workloads, data-sovereign tasks.
- Tier 2: Ollama Cloud (kimi-k2.6 / qwen3.5 / glm-5.1) — $100/mo flat — AInchors ops only (NEVER client data).
- Tier 3: Claude Sonnet 4.6 — pay-per-token — FALLBACK ONLY.
- Data sovereignty: DS-1 to DS-5 enforced by Warden. Client data = Tier 0/1 local ONLY.
- CURRENT (pre-OC2): Sonnet primary + Ollama Cloud Tier 2 active. Full 4-tier pending OC2 July 2026. PoC: ✅ COMPLETE (TRIGGER-05 fired 2026-05-02). Ollama Pro: accounts@ainchors.com.
- **gemma4:31b-cloud (CHG-0249, 2026-05-09):** Added to Tier 2. Benchmark 4.2/5, ~1-4s/task, no thinking-mode bleed, 256k ctx. Approved for background crons. 5-day parallel RTB trial vs kimi running (cron 7ff14b97, 8:15am AEST). CI Cycle B candidate. Alias: gemma4cloud.

## Security Controls (S1–S7)
- S1: OC ≥ v2026.5.5 (current). v2026.5.7 available (routine bugfix, no CVE). Daily Warden check.
- S2: Gateway loopback only. Port 18789 never public. Tailscale remote access.
- S3: No ClawHub skills on prod. Custom-built only. Weekly audit.
- S4: Least privilege per agent. Governance agents read-only FS.
- S5: No hardcoded creds. Keychain + env vars only.
- S6: All CHG logged. Warden compliance. Incident log current.
- S7: NAS encrypted (post-OC2).

## CHG Trigger Rules (TRIGGER-01 to TRIGGER-12)
- TRIGGER-01: OC2 arrival → 10-step setup (Ollama, Gemma4, Tailscale, OpenClaw, HA validation).
- TRIGGER-02: Both OC2 nodes live → HA active, NAS shared state.
- TRIGGER-03: Gemma4 validated → switch governance agents Haiku → Gemma4:26b local.
- TRIGGER-04: OpenClaw security patch → 48h (critical) / 7d (high). Raise CHG.
- TRIGGER-05: ✅ FIRED 2026-05-02 — kimi-k2.6:cloud Tier 2 active.
- TRIGGER-06: OpenClaw v4.0 ships → P3 gate assessment + CrewAI vs native eval.
- TRIGGER-07: First P2 client → onboarding checklist.
- TRIGGER-08: ✅ FIRED 2026-05-08 at T3. Auto-reload at <$50 → reloads to $500. Thresholds (CHG-0232): T1=$80 (once), T2=$40 (every 3rd), T3=$15 (every request). Balance recovered 2026-05-09 after INC-20260509-001.
- TRIGGER-09: Warden model drift → Yoda remediates within 1 heartbeat.
- TRIGGER-10: Business stream ready → migrate Aria to OC2.
- TRIGGER-11: glm-5.1 no-think mode → monthly check, benchmark if available.
- TRIGGER-12: Allowlist auto-sync live (CHG-0144). Script: allowlist-sync.sh.

## Tailscale Config (CHG-0227/228)
- Serve enabled on OC1. `allowTailscale: true`. URL: `https://ainchorss-mac-mini.tail5e2567.ts.net`. CLI: v1.96.5. S2 compliant.

## Sprint Capacity Model (CHG-0241, locked 2026-05-08)
- Pre-OC2: 5 items/sprint | OC2 setup window: 2–3 items/sprint | Post-OC2: 5 items/sprint
- 30% headroom buffer. Early warning: <4 delivered in any sprint = flag P2 slip.
- P2 target end-Aug achievable with zero slack. Contingency: mid-Sep.
- `/sprint` command = on-demand burndown (distinct from Friday standup Sprint Review ceremony)

## Pending Tickets
**Critical/High (next 2 sprints):**
- **TKT-0124:** MinIO self-hosted object store on OC1 — interim blob/file access layer. HIGH. External access for Angie staff Malaysia. Per Atlas P2 blob design.
- **TKT-0125:** Strategy-to-Backlog Pipeline — formalize roadmap → tickets ceremony. HIGH. Linked TKT-0110. Doc: docs/Strategy_to_Backlog_Pipeline_v0.1.md. Ken approved 2026-05-10.
- **TKT-0105:** Model3-Policy SOPs — open | Ken to confirm design questions during grooming
- **TKT-0106:** Apply Model3-Policy to Tier 3 agents — blocked on TKT-0105
- **TKT-0108:** Document Generation Pipeline (DOCX/XLSX/PPTX/PDF) — open | Ahsoka blocker
- **TKT-0113:** Fallback alert channel (API-independent) — open | HIGH | INC-20260509-001 prevention
- **TKT-0112:** obs-collector: cron run failures not captured in obs.db — open | MEDIUM

**Infrastructure & Setup (Aevlith/OC2 path):**
- **TKT-0114:** AInchors–Aevlith Technologies partnership agreement — open | HIGH | GATE for TKT-0115-0117
- **TKT-0115:** Register Aevlith Technologies Pty Ltd with ASIC — open | HIGH | blocked on TKT-0114
- **TKT-0116:** Secure aevlith.ai domain — open | HIGH | blocked on TKT-0115
- **TKT-0117:** Secure aevlith.com.au domain — open | MEDIUM | blocked on TKT-0115
- **TKT-0118:** Secure aevlith.com domain — open | MEDIUM | can run in parallel
- **TKT-0119:** IP Australia trademark filing (Classes 35+42) — open | MEDIUM | blocked on TKT-0114
- **TKT-0120:** RustDesk self-hosted on OC1 — open | HIGH

**Spark (Social + LinkedIn Enhancements):**
- **TKT-0121:** Spark: LinkedIn image generation via Hugging Face (Flux.1-schnell) — open | MEDIUM
- **TKT-0122:** Spark: LinkedIn image generation via ComfyUI + Flux.1-schnell (fallback/upgrade) — open | LOW
- **TKT-0123:** Fix linkedin-post.sh: add delimiter guard + token delete scope — open | MEDIUM

**Medium-Priority (Q2+):**
- **TKT-0107:** Agent Governance — Squad Model (Tier 5+) — open | MEDIUM | GATE: define before squad work
- **TKT-0109:** Cassian Andor (Agile PM) — review July QBR. No build before then.
- **TKT-0110:** Process Documentation Framework — open | Lando owns. DoD must include user doc.
- **TKT-0111:** Angie Agile + Nexus Working Guide — open | Dep: TKT-0110

**Resolved (logged):**
- **TKT-0104:** ✅ Data + Memory Architecture — P1-P4 Progressive Alignment (2026-05-08 resolved, Atlas locked output)

tickets.json seq 124. Notion AKB Backlog = SSOT.

## Key Decisions & Architecture (locked)
- **P1–P4:** P1=internal | P2=SaaS individual agents | P3=commercial tier label (add-on to P2, not a build phase) | P4=Enterprise/FSI. Licensed product DROPPED from P3.
- **P3 trigger:** formal ROI checklist before enabling. P4 may skip P3 entirely (enterprise prefers physical).
- **P2 isolation:** RLS from day one. Multi-tenant foundation in P2 (tenant_id, RLS, shared state).
- **P2 client model policy (CHG-0236):** Gemma4 local only for client workloads. BYOK = opt-in, client accepts data residency risk.
- **Anthropic DPA:** Claude API blocked for client data (APRA CPG 235 / Privacy Act APP 11 — US storage = cross-border transfer). Policy: Gemma4 local default. BYOK = client's responsibility.
- **BYOK + Nexus-first locked globally.** canvas embed rule: sub-agents pass full path, no embed tags.
- agentToAgent enabled (openclaw.json). Ollama Pro: accounts@ainchors.com.
- Agile Framework v1.0 locked (Day 13, CHG-0222). Sprint 1 started 2026-05-07. P2 target: end-Aug 2026. Aevlith Technologies incorporation hard gate: end-May 2026.
- CI Cycle A running (cycle-a, phase A). Cycle 1A 7-day report generated CHG-0244. Cycle 2A started.
- **Day 15 (2026-05-09):** Standup email theme → light (CHG-0246). /Volumes/Docker alert was installer DMG, ejected. INC-20260509-001: 26h API degradation (balance $0 → $479.35 top-up → recovered). TKT-0113 raised for fallback alert path.
