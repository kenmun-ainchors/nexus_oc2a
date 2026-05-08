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
- **Auralith** — IP/technology entity. Ken intends to incorporate. Owns and operates Nexus platform. AInchors = market-facing brand; Auralith = platform company behind it. Confirmed by Ken 2026-05-07. Feeds Atlas EA, Ahsoka positioning, Holocron structure. TKT-0069.
- Emails: kenmun@ ✅ gog | info@ | accounts@ | Gmail (Google Workspace). Tech stream: Ken+Yoda. Business stream: Angie+Aria.

## Infrastructure — HIVE Architecture (confirmed May 2026)
- **OC1** — Mac Mini M4 24GB — LIVE Production. PERMANENT. HARD LIMIT: No local LLM inference >~8B Q4.
- **OC2-A** — Mac Mini M4 Pro 48GB — INCOMING ETA July 2026. HA Primary, local inference primary.
- **OC2-B** — Mac Mini M4 Pro 48GB — INCOMING ETA July 2026. HA Secondary, hot standby.
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
- **Spark ✨** = Social & Digital Marketing (model: kimi-k2.6:cloud, workspace-social/). Scope: all social (LinkedIn, Instagram, Facebook, X) + digital marketing. Ken approves personal; Angie approves brand content.
  - Crons: e7ebaf61 (Tue+Thu 7:30am AEST) | bef42235 (Wed 12pm AEST) | 30-day review: 316df676 (2026-06-02)
  - State: state/linkedin-queue.json + state/linkedin-content-tracker.json. Governance: content-governance-review.sh.
  - First run: 2026-05-05 07:30 AEST ✅ CHG-0130. TKT-0038.
- **Atlas 🏛️** (agentId: architect) = Enterprise Architect. TOGAF, P1–P4 roadmap. SOUL.md v2.1 (2,088 chars ✅).
- **Thrawn** (agentId: platform-arch) = AI Platform Architect, Nexus Core. Agent orchestration, model strategy, S1–S7. SOUL.md v1.0 (2,470 chars ✅).
- **Atlas vs Thrawn Routing Rule (locked 2026-05-08):**
  - **Atlas:** Enterprise-facing — TOGAF B/D/A/T, P1–P4 roadmap, client/market/regulatory, integration estate, deployment models, investment framing. Sets constraints Thrawn implements inside.
  - **Thrawn:** Platform-internal — Nexus agent orchestration, model routing/tiering, governance implementation (Shield/Lex/Sage/Warden), observability, ITSM hooks, session/cron architecture.
  - **Cross-cutting:** Both — Atlas sets constraints, Thrawn implements inside them.
  - **Yoda behaviour:** If Ken assigns a task to the wrong agent, Yoda must advise the correct assignment and ask Ken to confirm before proceeding. No silent reassignment.
- **Lando 🟡** = BPM Agent (agentId: biz-process, workspace-bpm/). Methods: BPM/BPMN, Lean, Six Sigma, TQM. Spec: docs/Business_Process_Specialist_Agent_v1.md. Name confirmed 2026-05-05 (TKT-0072, seq 4/4).
- **Krennic 🔵** = SRE Agent. Incident response, SLO/error budget, runbooks, post-mortems. Build before TRIGGER-07. TKT-0074. Activation: >2 incidents/wk OR >30% Yoda toil.
- **Mon Mothma 🌟** = DTCM Agent (agentId: change-mgt, workspace-dtcm/). Methods: ADKAR, Kotter, Prosci. Name confirmed 2026-05-05.
- **Gemma4 policy: background/non-interactive crons ONLY** — cold-load causes system-wide slowdown.
- Sub-agents to build: content, support, reporting, coding.

## Agent SOUL.md Compact Standard (NON-NEGOTIABLE — locked 2026-04-30)
- Every agent SOUL.md must be under 5,000 chars. Hard limit: 10,000 chars (OpenClaw truncation threshold).
- Pattern: SOUL.md = identity + traits + brief rules + cadences. [AGENT]_RULES.md = detailed procedures.
- Why: Aria at 17,393 chars → silent truncation → wrong Telegram targets → gateway OOM → WebSocket 1006 (incident 2026-04-30 18:11).
- Enforcement: obs-collector.sh monitors soul_truncated events. Action trigger at 6,000 chars.
- Current sizes: Yoda 4,334 ✅ | Aria 3,765 ✅ | Shield 3,857 ✅ | Governance 1,334 ✅ | Sage 1,830 ✅ | Lex 2,322 ✅
- RULES.md files: YODA_RULES.md, ARIA_RULES.md, SAGE_RULES.md, LEX_RULES.md live. Shield: SHIELD_RULE_1.md.

## Governance Layer — Agents
- **Shield 🛡️** (security) | **Lex ⚖️** (legal) | **Sage 🧪** (qa) — **Haiku** (updated 2026-05-08, CHG-0230). Pre-OC2 cost strategy. Will move to Gemma4 local on TRIGGER-03.
- **Warden 🔍** = Model Compliance Officer. Checks all 6 agents every 15 min. Reports to Yoda. Never acts directly.
  - Script: scripts/model-drift-check.sh (9 checks, exit 0=clean/exit 2=violation). Cron: 83accf7b (15 min, anthropic/claude-haiku-4-5, CHG-0096).
  - State: state/model-drift-state.json, state/model-drift-violations.json. Policy: state/model-policy.json.
  - Escalation: writes state/warden-escalation-pending.json → Yoda heartbeat remediates.
  - Monitors all 9 agents (main, business, security, legal, qa, governance, infra, architect, platform-arch).

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
- JournalFormat: Notion Holocron › Platform Operations › JournalFormat (verbatim Ken prompts, Yoda voice, private)
- BlogFormat: Notion Holocron › Platform Operations › BlogFormat (Ken first-person, public-ready, built FROM journal)
- GatewayRecovery: Notion Holocron › Platform Operations › GatewayRecoverySOP
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

## Architecture Decision — Knowledge Base (2026-05-03)
- **Obsidian: RETIRED ✅** — All 5 phases complete (TKT-0042 closed 2026-05-05). Phases 1-5 completed 2026-05-04. 38 pages migrated. Vault decommissioned.
- **Notion: Single KB** — Holocron structure live. AKB daily cron writes Notion-only.

## Open Items
- ken@ainchors.com alias → kenmun@ainchors.com (alias setup status unknown)
- **Notion AKB Backlog** = SSOT. DB ID (create): `34dc1829-53ff-814b-8257-d3a3bf351d44`. DB ID (query): `34dc182953ff812d8e43000b83eb0e7e`.
- LinkedIn ✅ connected. Instagram/Facebook/X not yet connected. Spark extended to IG/LI/FB/YT (CHG-0160, 2026-05-04).
- Tailscale remote access: deferred. S4 ✅ DONE — per-agent tool scopes applied (CHG-0176, 2026-05-05).
- Agent team design + build: US raised. Needs Atlas + Thrawn input before build. TKT-0068 open.

## TRIGGER-12 — Allowlist Auto-Sync (live, 2026-05-03)
- Auto-syncs all agent `allowedInCrons` when CI Cycle B approves models OR model-policy.json tierStrategy changes.
- Scripts: scripts/allowlist-sync.sh + scripts/allowlist_sync_core.py + scripts/allowlist-detect.sh.
- Cron: 6a059e9e (every 30 min, haiku). State: state/allowlist-sync-state.json. CHG: CHG-0144.
- Eligibility: main/Aria=all cloud; Spark=kimi+pro; Sage=kimi+flash; Warden=flash only; Shield/Lex=no cloud (sensitive).

## Active Backlog (Notion source of truth)
- OC2 arrival (ETA July 2026) → fires TRIGGER-01 setup sequence.
- Ollama Cloud PoC: ✅ COMPLETE (TRIGGER-05 fired 2026-05-02). kimi/deepseek-flash/deepseek-pro Tier 2 active. Tier 2B trial (kimi-k2.6) added for RTB tasks (CHG-0194, 2026-05-06).

## Blog Post Ideas (Ken-originated — do not write until Ken signals ready)
- None currently tracked. Historical ideas archived.

## 4-Tier Model Strategy (Target — post OC2)
- Tier 0: No LLM (systemEvent crons) — $0 — health, obs, task monitoring.
- Tier 1: Gemma4:26b local on OC2 — $0 — governance, client workloads, data-sovereign tasks.
- Tier 2: Ollama Cloud (kimi-k2.6 / qwen3.5 / glm-5.1) — $100/mo flat — AInchors ops only (NEVER client data).
- Tier 3: Claude Sonnet 4.6 — pay-per-token — FALLBACK ONLY.
- Data sovereignty: DS-1 to DS-5 enforced by Warden. Client data = Tier 0/1 local ONLY.
- CURRENT (pre-OC2): Sonnet primary + Ollama Cloud Tier 2 active. Full 4-tier pending OC2 July 2026. PoC: ✅ COMPLETE (TRIGGER-05 fired 2026-05-02). Ollama Pro: accounts@ainchors.com.

## Security Controls (S1–S7)
- S1: OpenClaw ≥ v2026.1.29 (CVE-2026-25253 patched). Daily Warden check.
- S2: Gateway bind = loopback only. Port 18789 never public. Remote via Tailscale only.
- S3: No ClawHub skills on production. All skills custom-built. Weekly audit.
- S4: Least privilege per agent. Governance agents read-only filesystem.
- S5: No hardcoded credentials. Keychain + env vars only.
- S6: All CHG entries logged. Warden model compliance. Incident log current.
- S7: Obsidian vault encrypted. NAS encrypted (post-OC2).

## CHG Trigger Rules (TRIGGER-01 to TRIGGER-12)
- TRIGGER-01: OC2 arrival → 10-step setup (Ollama config, Gemma4 install, Tailscale, OpenClaw config, HA validation).
- TRIGGER-02: Both OC2 nodes live → HA architecture active, NAS shared state.
- TRIGGER-03: Gemma4 validated on OC2 → switch governance agents from Haiku to Gemma4:26b local.
- TRIGGER-04: OpenClaw security patch → update within 48h (critical) or 7 days (high). Raise CHG.
- TRIGGER-05: Ollama Cloud PoC PASS → 4-tier model strategy. **FIRED 2026-05-02** — kimi-k2.6:cloud Tier 2 active.
- TRIGGER-06: OpenClaw v4.0 ships → P3 gate assessment. CrewAI vs native multi-agent eval for Ken.
- TRIGGER-07: First P2 client → onboarding checklist execution.
- TRIGGER-08: Daily API cost >$60 USD → T1 alert; >$80 → T2; >$100 → T3 pause.
- **Auto-reload:** enabled at <$50 → reloads **$450** (confirmed 2026-05-08: +$450 from $50 = $500 total, not $500 reload). Credit alert thresholds recalibrated 2026-05-08 (CHG-0232): T1=$60 (alert once), T2=$55 (pre-reload heads-up), T3=$15 (reload failed, real emergency).
- TRIGGER-09: Warden model drift detected → Yoda remediates within 1 heartbeat.
- TRIGGER-10: Business stream ready → migrate Aria + agents from OC1 to OC2.
- TRIGGER-11: glm-5.1 no-think mode availability (monthly check) → benchmark if available, add to Tier 2 if latency <=20s.
- TRIGGER-12: Agent allowlist auto-sync (live 2026-05-03) → fires on CI Cycle B decisions or model-policy.json updates. Script: allowlist-sync.sh. CHG-0144.

## Recent Milestones (Days 7-14 Summary)
- Agile Framework v1.0 locked (Day 13, CHG-0222) — Agile L2→L3. Sprint 1 started 2026-05-07.
- TKT-0086 sequence complete: strategy coherence → governance gaps (20 ACs) → Atlas EA roadmap P1-P5 → backlog replan (95 items) → Agile framework.
- P2 target confirmed: end August 2026. Auralith incorporation hard gate: end May 2026.
- **P1–P4 Phase Definitions (locked 2026-05-08):** P1=internal single-tenant (current) | P2=SaaS individual agents | P3=SaaS company/multi-agents (shared context + data) | P4=Enterprise/FSI consulting. Licensed product scope DROPPED from P3.
- **P3 REDEFINED (2026-05-08 15:08 AEST):** P3 is NOT a build phase. It is a commercial tier label and feature unlock within P2. Multi-tenant foundation built in P2 from day one (tenant_id, RLS, shared state). P3 tier enabled on demand, only if ROI justified. Phase structure: P1 → P2 (multi-tenant + P3 label as add-on tier) → P4.
- **BYOK policy live. Nexus-first locked globally. 18+ CHGs logged (CHG-0208 through CHG-0226 as of May 8).**
- **P2 isolation model: RLS (row-level security) from day one** — confirmed Ken 2026-05-08.
- **P3 trigger: formal ROI checklist required** before enabling company/multi-agent tier. Ken skeptical — maintenance cost may not justify. Strategic note: P4 enterprise clients may prefer physical/in-house deployment over P3 SaaS — P3 may be skipped entirely in practice.
- **BYOK policy live. Nexus-first locked globally.**
- **P2 client model policy (locked CHG-0236):** Default = Gemma4 local only for all client-facing workloads. Client BYOK = opt-in (client brings own Anthropic key, owns data residency responsibility — AInchors not liable). Claude API not used for client data until Anthropic DPA verified.
- **Anthropic DPA confirmed 2026-05-08:** Processing can occur in AU (global routing includes Anthropic Australia Pty Ltd). BUT storage always in US regardless of inference_geo. inference_geo only supports 'global' or 'us' — no AU-only option. VERDICT: Claude API cannot be used for client data under APRA CPG 235 / Privacy Act APP 11 (US storage = cross-border transfer). Policy stands: Gemma4 local default. BYOK = client accepts residency risk.
- BYOK policy live. Nexus-first locked globally. 18+ CHGs logged (CHG-0208 through CHG-0226 as of May 8).
- canvas embed rule: sub-agents pass full path only, no embed tags — Yoda embeds directly
- agentToAgent enabled in openclaw.json — cross-agent sessions_send now live
- Ollama Cloud PoC PASS (TRIGGER-05) with kimi-k2.6, deepseek Tier 2 active (Day 8)
- Obsidian fully retired (Day 9), Notion Holocron live (5 phases complete Day 9, TKT-0042 closed Day 11)
- S4 tool scopes applied all agents (Day 11, CHG-0176)
- Spark extended to IG/LI/FB/YT (Day 9, CHG-0160), W1P1 posted, W2 approved
- Agents expanded: Atlas, Thrawn (platform-arch), Ahsoka (pilot testing Day 13)
- Strategy locked: VMS, OKRs, Guardrails (Day 13, CHG-0201-0206)
- CI Cycle A running (status: cycle-a, phase A, 17 runs to date, target A-phase end ~May 9)
- Ollama Pro: accounts@ainchors.com
