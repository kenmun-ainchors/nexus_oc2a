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
- Supporting: Tailscale mesh, NAS (shared model weights + state), Obsidian vault (shared KB across all nodes)
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
  - Crons: Tue 7:30am / Wed 12:00pm / Thu 7:30am AEST (IDs: e7ebaf61, bef42235)
  - 30-day review cron: 2026-06-02 (ID: 316df676)
  - State: state/linkedin-queue.json + state/linkedin-content-tracker.json
  - Governance: content-governance-review.sh (Shield→Lex→Sage triad). Ken approves via Telegram before posting.
  - First run: 2026-05-06 07:30 AEST. CHG-0130. TKT-0038.
- **Gemma4 policy: background/non-interactive crons ONLY** — cold-load causes system-wide slowdown.
- Sub-agents to build: content, support, marketing, reporting, coding

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

**Rule:** When naming new Nexus modules or functions, propose a Star Wars themed name first. Ken approves.
**Proposal status:** Names above are locked proposals. Each is reviewed and confirmed by Ken when the corresponding work kicks off — not before. Do not use as final names until confirmed at kickoff.

## Architecture Decision — Knowledge Base (2026-05-03, Ken)
- **Obsidian: RETIRE** — migrate all content to Notion. Obsidian out entirely.
- **Notion: Single KB** — restructure + cleanup required. Only AKB Backlog currently has live data. All other Notion pages stale/orphaned/unused.
- **Sequence (TKT-0042):** (1) Audit + archive stale Notion pages → (2) Design clean Notion structure → (3) Migrate Obsidian content → (4) Redirect AKB cron from Obsidian to Notion → (5) Remove Obsidian from all agent workflows
- AKB daily update cron must be rewritten to write to Notion only (not Obsidian) after migration

## Open Items
- ken@ainchors.com alias → kenmun@ainchors.com (gog working ✅ — alias setup status unknown)
- Project management tool: **Notion AKB Backlog = single source of truth for US/TKT/CHG (enforced 2026-05-03)**. ticket.sh and changelog-append.sh auto-sync to Notion on every write. DB ID (create): `34dc1829-53ff-814b-8257-d3a3bf351d44`. DB ID (query): `34dc182953ff812d8e43000b83eb0e7e` (via `/v1/data_sources/` endpoint).
- Social media accounts not yet connected (Instagram → Facebook → LinkedIn)
- Tailscale remote access: deferred
- S4 (agent tool scopes): all agents have tools=null — define explicit scopes before TRIGGER-07 (first P2 client)
- Agent team to be designed and built

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
- gog for Angie: ✅ RESOLVED — angie.foong@ainchors.com OAuth working (verified 2026-05-01)
- CAMP-0001 (Mont Kiara Apr 30 class): no debrief from Angie yet
- OC2 arrival (ETA July 2026) → fires TRIGGER-01 setup sequence
- Ollama Cloud PoC: **COMPLETE + EXTENDED** ✅ (2026-05-02). kimi-k2.6:cloud PASSED (Q=4.6/5, L=6.8s). deepseek-v4-flash:cloud PASSED (Q=4.2/5, L=12.6s). deepseek-v4-pro:cloud PASSED (Q=4.6/5, L=18.4s). All 3 added as Tier 2 models (CHG-0120, CHG-0123). Estimated monthly saving: $690–1,755/mo. glm-5.1:cloud FAILED. qwen3.5:cloud FAILED. Only non-sensitive (low data_sensitivity) tasks eligible. Routing guidance: kimi=fastest/creative, deepseek-flash=fast subtasks, deepseek-pro=complex code/reasoning.

## Blog Post Ideas (Ken-originated, do not write until Ken signals ready)
- **"Building observability for an Agentic AI platform"** (Apr 30, medium priority) — Status: idea only

## 4-Tier Model Strategy (Target — post OC2, pending PoC)
- Tier 0: No LLM (systemEvent crons) — $0 — health, obs, task monitoring
- Tier 1: Gemma4:26b local on OC2 — $0 — governance agents, client workloads, data-sovereign tasks
- Tier 2: Ollama Cloud (kimi-k2.6 / qwen3.5 / glm-5.1) — $100/mo flat — AInchors own ops only (NEVER client data)
- Tier 3: Claude Sonnet 4.6 — pay-per-token — FALLBACK ONLY
- Data sovereignty: DS-1 to DS-5 enforced by Warden. Client data = Tier 0/1 local ONLY.
- CURRENT state (pre-OC2, pre-PoC): all agents on Sonnet. Existing routing unchanged until PoC results.
- PoC: Ollama Cloud free-tier PoC to run after AKB + S1-S7 audit. Ken decision gate before any model changes.

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

## Day 7 Context (2026-05-01)
- CHG-0095: obs-collector session_stuck dedup fixed (183→0 events/24h); standup Telegram 3,500-char guard
- CHG-0096: US42 complete — Ollama routing confirmed, Warden on gemma4:e2b
- CHG-0097: Balance corrected to $115 (pre-top-up actual was $18; tracker showed ~$103)
- CHG-0098: cost-tracker.sh bug fixed — remainingEstimate now auto-decrements daily from confirmedBalance
- CHG-0099: 8 AKB entries created (AKB-PLATFORM-001–008). S1-S7 audit: 6 PASS / 1 WARN (S4) / 0 FAIL
- CHG-0100/101/102: TRIGGER-08 in cost-tracker, TRIGGER-04/06 release cron, HEARTBEAT trigger monitoring
- CHG-0107: bootstrapMaxChars 10k→20k (fix MEMORY.md truncation)
- Balance: $115.00 USD (top-up 19:04 AEST). All-time: $828.27 USD over 7 days.

## Day 10 Context — next session
- Phase 3 gate: present full Obsidian→Notion mapping table to Ken for approval before any migration
- Forge name: still proposed ("Forge 🏗️") — Ken to confirm
- TKT-0043 to TKT-0048: all in Backlog, untouched — not actioned
- CI Cycle A first report due ~2026-05-09
- Balance: $445.77 USD (confirmed Ken 22:53 AEST)

## Day 9 Context (2026-05-03) — Key Events
- CHG-0139: Anthropic API key rotated. Moved to AInchors Anthropic account. Balance $98 USD confirmed.
- T1 balance alert fired 13:20 AEST ($45.24 < $80 threshold) — then reset after CHG-0139 key rotation + top-up to $98.
- Standby mode 14:11–14:30 AEST: HTTP 401 on outage-detect.sh — stale keychain key post-rotation. Self-cleared after key update.
- Warden escalation warden-20260503-0003 resolved CHG-0133 (obs-collector self-recovered, model-drift-check.sh quoting bug fixed, 15/15 PASS).
- TKT-0039 EOD reminder fired 17:00 AEST — Ken decision pending: LinkedIn Authority Campaign Week 1 start date.
- Partnership Discussion meeting notes arrived 10:47AM AEST (gemini-notes) — key actions: company setup (immediate), training due tomorrow, IP strategy. Flagged to Ken.
- Calendar: Meeting with Ken and Colbert — 2026-05-04 14:00–15:00 AEST.

## Day 9 Context (2026-05-03) — Key Events (continued)
- CHG-0140: Allowlist audit — Ollama Cloud Tier 2b propagated to all eligible agents. Spark added to model-policy.json. Lex opus contradiction fixed.
- CHG-0143/0144: TRIGGER-12 implemented — allowlist-sync.sh auto-fires on CI Cycle B decision or strategy change.
- CHG-0145: Notion Model Strategy page fully rewritten — 4-tier, per-agent routing, PoC results, TRIGGER-12.
- CHG-0146: Holocron daily cron fixed — Notion-only (Obsidian removed), timeout resolved, Telegram delivery fixed. Runs 134s.
- CHG-0147/0148: Forge 🏗️ activated — owns all ITIL/ITSM/AIOps + CI. 12 crons assigned to agentId=infra. INFRA_RULES.md created.
- TKT-0042 Phase 1+2 complete (sub-agent) — Notion audit done, 63 stale pages archived, clean Holocron structure established. Phase 3 pending Ken approval.
- openclaw.json: Ollama Cloud models added to agents.defaults.models (were missing — caused CI cron failures).

## Day 8 Context (2026-05-02) — Webchat Session
- CHG-0120–0130 logged (11 entries). PoC complete, Spark live, CI framework live, content governance live.
- Ollama Pro: accounts@ainchors.com (NOT kenmun). Run `ollama signout && ollama signin` to switch.
- /standup, /update, /eod, /blog slash commands locked in RULES.md
- CI Framework: Cycle A (7d batch shadow, always-on) + Cycle B (concurrent wk 2). First report: 2026-05-09 ~11:00 AEST. Model: deepseek-v4-pro:cloud. State: ci-agent-state.json.
- Content governance triad (TKT-0033 ✅): Shield→Lex→Sage. PVT 10/10. Warden Check #15 guards published-without-clearance.
- Spark ✨ live (CHG-0130). First LinkedIn run: Tue 2026-05-06 7:30am AEST.
- Balance top-up: $140 at ~11:33 AEST. All-time: $828.27 (Day 1–7) + Day 8 spend TBD.
- New tickets: TKT-0033 (resolved), TKT-0034 (social auto-post), TKT-0035 (content agent), TKT-0037 (Warden per-agent gating), TKT-0038 (LinkedIn — in progress).

## Ollama Cloud PoC — COMPLETE (2026-05-02)

**Status: ✅ COMPLETE — Phase 6 Implemented**
**Authorised by:** Ken (Ollama Pro signup accounts@ainchors.com)
**CHG:** CHG-0120
**Full report:** /Users/ainchorsangiefpl/.openclaw/workspace/state/ollama-cloud-poc-report.md

### Benchmark Results — All Models

| Model | Avg Quality | Avg Latency | Result |
|-------|-------------|-------------|--------|
| kimi-k2.6:cloud | 4.6/5 | 6.8s | **✅ PASS** |
| deepseek-v4-flash:cloud | 4.2/5 | 12.6s | **✅ PASS** |
| deepseek-v4-pro:cloud | 4.6/5 | 18.4s | **✅ PASS** |
| glm-5.1:cloud | N/A | 221s+ | **❌ FAIL** |
| qwen3.5:cloud (/no_think) | 4.6/5 | 42.3s | **❌ FAIL (latency)** |

### Tier 2 Implementation (Phase 6 + Phase 5D)
- **kimi-k2.6:cloud** — fastest (6.8s), best for creative/content tasks. CHG-0120.
- **deepseek-v4-flash:cloud** — fast subtasks (12.6s avg). CHG-0123.
- **deepseek-v4-pro:cloud** — complex code/reasoning (18.4s avg, async preferred). CHG-0123.
- Constraint: ALL three = non-sensitive tasks ONLY (`data_sensitivity == "low"`)
- Warden must enforce: no PII, no medical, no legal data via any Ollama Cloud model
- Estimated saving: **$690–1,755/mo** vs current Claude spend of ~$3,550/mo
- glm-5.1 and qwen3.5: NOT added. Revisit qwen3.5 for async batch jobs in OC2.

### Key caveats
- kimi-k2.6 quality excellent but output includes thinking tokens (visible in stream) — acceptable for background tasks
- Full 4-tier model strategy still pending OC2 arrival (July 2026)
- Routing implementation (Warden enforcement, agent-level gating) is next step
