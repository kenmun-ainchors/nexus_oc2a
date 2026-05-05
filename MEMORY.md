# MEMORY.md - Yoda's Long-Term Memory

## Identity
- Name: Yoda 🟢
- Role: AI business operations lead agent for Ken Mun (CTO), AInchors

## The People
- **Ken Mun** — Co-founder, CTO. Technical lead. My direct operator.
  - Email: kenmun@ainchors.com | Mobile: +61403650578 | Telegram chatId: 8574109706
  - Telegram bot: **@AInchorsOC1Bot** → routes to Yoda (Ken only)
  - Emergency keyword: **"YODA THIS IS KEN"** — triggers immediate Yoda control regardless of routing state
- **Angie Foong** — Co-founder, CEO. Business lead. Has trainers, marketing/sales, support staff.
  - Email: angie.foong@ainchors.com | Mobile: +61430928371 | Telegram chatId: 8141152780
  - **Authority: CEO = highest authority. Full access to all AInchors information via Aria.**
  - Aria 🔵 acts on Angie's behalf with full read access to all data (Yoda workspace, Obsidian, Notion, state files)
  - Telegram bot: **@AInchorsAriaBot** → routes to Aria (Angie only, strict allowlist)

## The Company
- **Name:** Ainchor Solutions Pty Ltd | **Short:** AInchors | **Domain:** ainchors.com
- Sydney NSW + Melbourne. Day 1 of tech dept = 2026-04-25.
- Focus: (1) AI courses & training (2) AI consulting (3) AI solutions/products
- Emails: kenmun@ainchors.com ✅ gog working | info@ainchors.com | accounts@ainchors.com | Provider: Gmail (Google Workspace)
- Technical stream (Ken + Yoda): AI foundation, agent team, platform dev
- Business stream (Angie + Aria): training delivery, marketing, sales, support

## Infrastructure — HIVE Architecture (confirmed May 2026 — Ken brief)
- **OC1** — Mac Mini M4 24GB — LIVE Production. Orchestration, Tier 0/1 agents, Telegram gateway. PERMANENT — never decommissioned.
  - HARD LIMIT: Cannot run local LLM inference. 24GB = hardware ceiling. No models above ~8B at Q4. Not a config issue.
  - Post-OC2 role: lightweight relay node, ITSM/obs/cost-tracking, Tier 0/1 only.
- **OC2-A** — Mac Mini M4 Pro 48GB — INCOMING (ETA: July 2026). HA Primary. Local inference primary.
- **OC2-B** — Mac Mini M4 Pro 48GB — INCOMING (ETA: July 2026). HA Secondary, hot standby.
- Supporting: Tailscale mesh, NAS (shared model weights + state). Obsidian vault RETIRED (migration complete 2026-05-04).
- Platform: OpenClaw confirmed for P1 and P2. Final decision. No replatforming.
- Telegram: Ken's secondary channel (urgent/offline)

## Agent Architecture
- Yoda 🟢 = lead agent (technical stream primary, oversees all)
- **Aria 🔵** = Business Lead Agent (on OC1, migrates to OC2 at TRIGGER-10)
  - Governance layer: Shield 🛡️ (security), Lex ⚖️ (legal), Sage 🧪 (QA) — all Sonnet
  - Aria primary model: Sonnet
- **Spark ✨** = Social & Digital Marketing Agent. Model: kimi-k2.6:cloud. Workspace: workspace-social/. Managed by Yoda.
  - Scope: ALL social platforms + digital marketing — strategy, campaigns, content, execution across LinkedIn, Instagram, Facebook, X, and future channels (Ken personal + AInchors brand). Replaces planned "Social (full API)" agent slot.
  - Ken approves: his personal content. Angie approves: AInchors brand content.
  - Generation crons: e7ebaf61 = Tue+Thu 7:30am AEST (one cron, days 2+4) | bef42235 = Wed 12:00pm AEST
  - 30-day review cron: 2026-06-02 (ID: 316df676)
  - State: state/linkedin-queue.json + state/linkedin-content-tracker.json
  - Governance: content-governance-review.sh (Shield→Lex→Sage triad). Ken approves via Telegram before posting.
  - First run: 2026-05-05 07:30 AEST ✅ completed. CHG-0130. TKT-0038.
- **Atlas 🏛️** = Enterprise Architect (agentId: architect). TOGAF B/D/A/T, P1–P4 roadmap, integration strategy, security zones, regulatory. SOUL.md v2.1 (2,088 chars ✅).
- **Thrawn** (name TBC) = AI Platform Architect — Nexus Core (agentId: platform-arch). Agent orchestration, model strategy, S1–S7 implementation, observability. SOUL.md v1.0 (2,470 chars ✅).
- Yoda orchestrates both: platform-internal → Thrawn | enterprise-level → Atlas | cross-cutting → Atlas first then Thrawn.
- **Gemma4 policy: background/non-interactive crons ONLY** — cold-load causes system-wide slowdown.
- **Lando 🟡** = BPM Agent — Business Process Specialist (tech + business). Name confirmed by Ken 2026-05-05 (TKT-0072, seq 4/4).
  - Spec: docs/Business_Process_Specialist_Agent_v1.md (email BPS_AGENT). Methods: BPM/BPMN, Lean, Six Sigma, TQM. agentId=biz-process. workspace-bpm/ (agentId: biz-process).
- **Krennic 🔵** = SRE Agent — Site Reliability Engineering. Incident response, SLO/error budget, runbooks, post-mortems, capacity planning. Build before TRIGGER-07 (P2). Activation triggers: incident rate >2/wk OR toil >30% Yoda turns. TKT-0074.
- **Mon Mothma 🌟** = DTCM Agent — Digital Transformation Change Management Specialist. People/adoption side of digital/AI change. Methods: ADKAR, Kotter, Prosci. agentId=change-mgt. workspace-dtcm/. Name confirmed by Ken 2026-05-05.
- Sub-agents to build: content, support, reporting, coding

## Agent SOUL.md Compact Standard (NON-NEGOTIABLE — locked 2026-04-30)
- **Rule:** Every agent SOUL.md must be under 5,000 chars. Hard limit: 10,000 chars (OpenClaw truncation threshold).
- **Pattern:** SOUL.md = identity + traits + brief rules + cadences (compact). [AGENT]_RULES.md = all detailed procedures.
- **Why it matters:** Aria's SOUL.md at 17,393 chars was being silently truncated → wrong Telegram targets → stuck session → gateway OOM crash → WebSocket 1006 (incident 2026-04-30 18:11)
- **Enforcement:** obs-collector.sh monitors soul_truncated events. Action trigger at 6,000 chars.
- **Current sizes:** Yoda 4,334 ✅ | Aria 3,765 ✅ | Shield 3,857 ✅ | Governance 1,334 ✅ | Sage 1,830 ✅ | Lex 2,322 ✅
- **RULES.md files:** YODA_RULES.md, ARIA_RULES.md, SAGE_RULES.md, LEX_RULES.md all live. Shield uses SHIELD_RULE_1.md.
- **New agents:** SOUL.md written compact from Day 1 alongside [AGENT]_RULES.md. No exceptions.

## Governance Layer — Agents
- **Shield 🛡️** (security) — model: Sonnet
- **Lex ⚖️** (legal) — model: **Sonnet** (Opus exception removed 2026-04-28, Ken confirmed Sonnet sufficient — cost saving)
- **Sage 🧪** (qa) — model: Sonnet
- **Warden 🔍** (governance) — Model Compliance Officer. Checks all 6 agents every 15 min. Reports to Yoda. Never acts directly. See `state/model-policy.json`.
  - Script: `scripts/model-drift-check.sh` — 9 checks, exit 0=clean/exit 2=violation
  - State: `state/model-drift-state.json`, `state/model-drift-violations.json`
  - Escalation: writes `state/warden-escalation-pending.json` → Yoda heartbeat picks up + remediates
  - Cron: every 15 min, isolated agentTurn (cron id: 83accf7b), model: gemma4:e2b (CHG-0096)
  - Monitors all 9 agents (main, business, security, legal, qa, governance, infra, architect, platform-arch)
  - Policy registry: `state/model-policy.json` (per-agent allowed/required/prohibited models)

## Key Scripts & Infrastructure
- `scripts/auto-heal.sh` — nightly 23:30 AEST, 12 checks, auto-fixes stale state, files Notion US for needs-Ken items
- `scripts/run-diagnostics.sh` — on-demand `/diagnostics`, 6 phases
- `scripts/ticket.sh` — ITSM ticketing (TKT-NNNN), ticket-first rule enforced before any ad-hoc work. Auto-syncs to Notion AKB Backlog on new/update/close. Use `notion-sync TKT-NNNN` for backfill.
- `scripts/changelog-append.sh` — auto-increments CHG-NNNN in `memory/CHANGELOG.md`. Auto-syncs each CHG to Notion AKB Backlog (Status=Done).
- `scripts/gateway-config-snapshot.sh` + `scripts/gateway-restore.sh` — config snapshot/restore SOP
- `scripts/cost-tracker.sh` — daily spend tracking. Balance: confirmedBalance − spentAfterDate (CHG-0098)
- `state/critical-config-baseline.json` — anti-drift guard (7 configs), validated by auto-heal Check #12
- `state/chg-triggers.json` — 10 CHG triggers, status, detection method

## Operations Docs (locked)
- JournalFormat: Notion Holocron › Platform Operations › JournalFormat (locked spec — verbatim Ken prompts, Yoda voice, private)
- BlogFormat: Notion Holocron › Platform Operations › BlogFormat (locked spec — Ken first-person, public-ready, built FROM journal)
- GatewayRecovery: Notion Holocron › Platform Operations › GatewayRecoverySOP (troubleshoot → restore from snapshot → openclaw reset)
- **Journal:** `memory/journal-YYYY-MM-DD.md` | **Blog:** `canvas/documents/ainchors-YYYY-MM-DD/index.html`

## GitHub
- GitHub CLI (`gh`) authenticated: account **kenmun-ainchors**, scopes: repo, read:org, gist (token in keyring)

## Nexus — Star Wars Naming Convention (CONFIRMED 2026-05-03, Ken)
All modules and functions within the Nexus platform use Star Wars themed names.

| Module | Star Wars Name | Description |
|---|---|---|
| Overall platform | **Nexus** | Force Nexus — convergence of power and data. API-first Hive portal. |
| Knowledge Base / AKB | **Holocron** | Jedi/Sith data repositories. Single source of truth. |
| Command Centre (AInchors) | **The Bridge** | Ship command bridge — real-time ops view for Ken + Yoda. |
| Client Portal | **The Citadel** | Fortified, isolated per-client access. |
| Real-time data/API layer | **Holonet** | Galaxy-wide comms network — live data feeds. |
| Monitoring / Health | **Beacon** | Distress beacon — health alerts and observability. |
| Governance vault | **The Sanctum** | Sacred protected space — Shield/Lex/Sage triad. |
| Reporting / Dashboards | **Datapad** | Standard Star Wars data terminal. |

**Rule:** When naming new Nexus modules or functions, use Star Wars themed names. Ken approves new ones.
**Status: LOCKED ✅** — Confirmed by Ken + Angie (2026-05-05). All names above are final. Use them. No further approval needed at kickoff.

## Architecture Decision — Knowledge Base (2026-05-03, Ken)
- **Obsidian: RETIRED** ✅ — All 5 phases complete (TKT-0042 closed 2026-05-05). 38 pages migrated. Vault decommissioned.
- **Notion: Single KB** — Holocron structure live. AKB daily cron writes Notion-only.

## Open Items
- ken@ainchors.com alias → kenmun@ainchors.com (gog working ✅ — alias setup status unknown)
- **Notion AKB Backlog** = single source of truth. DB ID (create): `34dc1829-53ff-814b-8257-d3a3bf351d44`. DB ID (query): `34dc182953ff812d8e43000b83eb0e7e`.
- LinkedIn ✅ connected. Instagram/Facebook/X not yet connected.
- Tailscale remote access: deferred
- S4 ✅ DONE — per-agent tool scopes applied (CHG-0176, 2026-05-05)
- Agent team design + build: US raised (see Notion Backlog). Needs Atlas + Thrawn architecture input before build.
- **OpenClaw update pending:** v2026.5.2 installed → v2026.5.3 available (routine, no CVE). Update when convenient.

## TRIGGER-12 — Allowlist Auto-Sync (live, 2026-05-03)
- **What:** Auto-syncs all agent `allowedInCrons` when CI Cycle B approves models OR model-policy.json tierStrategy changes.
- **Scripts:** `scripts/allowlist-sync.sh` (engine) + `scripts/allowlist_sync_core.py` (Python logic) + `scripts/allowlist-detect.sh` (detector)
- **Cron:** 6a059e9e (every 30 min, haiku) — detects trigger, runs sync, alerts Ken via Telegram if changes applied
- **Eligibility matrix:** main/Aria=all cloud; Spark=kimi+pro; Sage=kimi+flash; Warden=flash only; Shield/Lex=no cloud (sensitive)
- **State:** `state/allowlist-sync-state.json` — tracks lastSyncAt, lastChanges, approvedCloudModels
- **CHG:** CHG-0144

## Active Backlog (Notion source of truth)
- US19: HA Design (reliability, High priority)
- US39: Preventable Downtime Enforcement (future sprint)
- CAMP-0001 (Mont Kiara Apr 30 class): no debrief from Angie yet
- OC2 arrival (ETA July 2026) → fires TRIGGER-01 setup sequence
- Ollama Cloud PoC: ✅ COMPLETE. kimi/deepseek-flash/deepseek-pro Tier 2. Full report: state/ollama-cloud-poc-report.md

## Blog Post Ideas (Ken-originated, do not write until Ken signals ready)
- **"Building observability for an Agentic AI platform"** (Apr 30, medium priority) — Status: idea only

## 4-Tier Model Strategy (Target — post OC2, pending PoC)
- Tier 0: No LLM (systemEvent crons) — $0 — health, obs, task monitoring
- Tier 1: Gemma4:26b local on OC2 — $0 — governance agents, client workloads, data-sovereign tasks
- Tier 2: Ollama Cloud (kimi-k2.6 / qwen3.5 / glm-5.1) — $100/mo flat — AInchors own ops only (NEVER client data)
- Tier 3: Claude Sonnet 4.6 — pay-per-token — FALLBACK ONLY
- Data sovereignty: DS-1 to DS-5 enforced by Warden. Client data = Tier 0/1 local ONLY.
- CURRENT state (pre-OC2, post-PoC): Sonnet primary + Ollama Cloud Tier 2 active (kimi-k2.6, deepseek-flash, deepseek-pro). Full 4-tier pending OC2 arrival (July 2026).
- PoC: ✅ COMPLETE (TRIGGER-05 fired 2026-05-02). Ken decision gate passed. Full rollout at OC2.

## Security Controls (S1–S7) — from Ken brief May 2026
- S1: OpenClaw version ≥ v2026.1.29 (CVE-2026-25253 patched). Daily Warden check.
- S2: Gateway bind = loopback only. Port 18789 never public. Remote via Tailscale only.
- S3: No ClawHub skills on production. All skills custom-built. Weekly audit.
- S4: Least privilege per agent. Governance agents read-only filesystem.
- S5: No hardcoded credentials. Keychain + env vars only.
- S6: All CHG entries logged. Warden model compliance. Incident log current.
- S7: Obsidian vault encrypted. NAS encrypted (post-OC2).

## CHG Trigger Rules (TRIGGER-01 to TRIGGER-10)
- TRIGGER-01: OC2 arrival → 10-step setup (Ollama config, Gemma4 install, Tailscale, OpenClaw config update, HA validation)
- TRIGGER-02: Both OC2 nodes live → HA architecture active, NAS shared state
- TRIGGER-03: Gemma4 validated on OC2 → switch governance agents from Haiku to Gemma4:26b local
- TRIGGER-04: OpenClaw security patch → update within 48h (critical) or 7 days (high). Raise CHG.
- TRIGGER-05: Ollama Cloud PoC PASS → implement 4-tier model strategy. Ken decision gate. **FIRED 2026-05-02** — kimi-k2.6:cloud Tier 2 active. Full 4-tier pending OC2 arrival (July 2026).
- TRIGGER-06: OpenClaw v4.0 ships → P3 gate assessment. Present Ken with CrewAI vs native multi-agent eval.
- TRIGGER-07: First P2 client → onboarding checklist execution
- TRIGGER-08: Daily API cost exceeds $60 USD → T1 alert; $80 → T2; $100 → T3 pause
- TRIGGER-09: Warden model drift detected → Yoda remediates within 1 heartbeat
- TRIGGER-10: Business stream ready → migrate Aria + agents from OC1 to OC2

## Session History — Key Facts (Days 7-11)
- Day 7 (May 1): Ollama routing live, Warden on gemma4:e2b, S1-S7 audit 6 PASS/1 WARN(S4). bootstrapMaxChars 20k.
- Day 8 (May 2): Ollama Cloud PoC complete. Spark live. CI Framework A+B live. Content governance triad live. Ollama Pro: accounts@ainchors.com.
- Day 9 (May 3): Anthropic key rotated → AInchors account ($495 balance). TRIGGER-12 live. Obsidian retired. Notion Holocron structure live. Forge 🏗️ activated (agentId=infra).
- Day 10 (May 4): Atlas 🏛️ instantiated. W1 LinkedIn posts approved. AIOps theme roadmap locked (6 cycles). AI Charter + Governance Framework approved. Obsidian migration Phases 1-3 done.
- Day 11 (May 5): W1P1 posted (urn:li:activity:7457186904363421696). RTB done. W2 crons live (3 posts May 12-14). Obsidian migration all 5 phases done (TKT-0042 closed). S4 tool scopes applied (CHG-0176). Atlas v2.1 EA + Thrawn (platform-arch) registered. Architecture orchestration routing in YODA_RULES.md.
- CI Cycle A first report: ~2026-05-09 11:00 AEST. State: ci-agent-state.json.
- Ollama Pro account: accounts@ainchors.com. Run `ollama signout && ollama signin` to switch.
