# MEMORY.md - Yoda's Long-Term Memory

## Identity
- Name: Yoda 🟢
- Role: AI business operations lead agent
- Lead agent for Ken Mun (CTO)

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
- **Name:** AI Anchor Solutions Pty Ltd
- **Short name:** AInchors
- **Domain:** ainchors.com
- **Registration:** Sydney, NSW. Bases: Sydney + Melbourne.
- **Stage:** Brand new. Day 1 of technical department = 2026-04-25.
- **Focus:** 
  1. AI courses & training for businesses
  2. AI consulting services
  3. Building AI solutions (products/custom builds)
- **Technical team size:** 1 (Ken) + me as lead agent. Growing.

## Email Accounts
- ken@ainchors.com → kenmun@ainchors.com (being set up)
- info@ainchors.com
- accounts@ainchors.com
- Provider: Gmail (Google Workspace)

## Two Streams of Work
### Technical Stream (Ken / CTO)
- Build AI agentic foundation
- Build and manage AI agent team
- Platform development
- I (Yoda) am the lead agent for this stream

### Business Stream (Angie / CEO)
- Training delivery
- Marketing & sales
- Support operations
- AI agents to handle and expand these functions

## Tools to Integrate (full scope)
- Email
- Calendar
- Project management
- Comms (team messaging)
- Coding / dev tools
- Video creation & editing
- Slides & presentations
- Documents & Excel
- Image creation & editing
- Web content management (CMS)
- Social media — posting, listening, responding, management
  - Priority order: Instagram → Facebook → LinkedIn
- Proposal creation
- Reporting

## Infrastructure
- **OC1 (this Mac mini):** Permanent base. Yoda runs here. Technical stream lead + oversight of all.
- **OC2 (future Mac mini):** Angie's machine. Business stream agents. Managed by Angie, overseen by Yoda.
- Current Mac mini → becomes OC2 when Yoda migrates to new, more powerful Mac mini.
- Tailscale: critical for OC1↔OC2 cross-instance communication (Phase 3, not Phase 4)
- Telegram: Ken's secondary channel (urgent/offline)

## Dual-Instance Architecture
- Yoda (OC1) = Lead agent. Oversees OC2. Manages holistic knowledge, decisions, context.
- OC2 = Business stream. Angie's instance. Sub-agents managed locally there.
- Cross-instance: Yoda assigns work to OC2, reviews outputs, maintains alignment.
- Shared knowledge: synced via Obsidian vault (iCloud or Git) + structured handoffs.
- Yoda must be PORTABLE — full migration guide required before new Mac mini arrives.

## Agent Architecture Plan
- Two streams: Technical + Business
- Yoda 🟢 = lead agent (technical stream primary, oversees all)
- **Aria 🔵** = Business Lead Agent (Angie's agent, lives on OC1 temporarily, migrates to OC2)
  - Governance layer (on OC1, planned): Shield 🛡️ (security), Lex ⚖️ (legal), Sage 🔬 (QA)
  - Aria primary model: Sonnet (confirmed Day 3 — Gemma4 removed from interactive path)
- **Gemma4 policy: background/non-interactive crons ONLY** — cold-load causes system-wide slowdown. Never for interactive sessions.
- Sub-agents to be built: content, social, support, marketing, reporting, coding
- Angie's team to eventually have their own AI agent layer

## Governance Layer — Agents
- **Shield 🛡️** (security) — model: Sonnet
- **Lex ⚖️** (legal) — model: **Opus** (documented exception — legal accuracy justifies cost)
- **Sage 🧪** (qa) — model: Sonnet
- **Warden 🔍** (governance) — Model Compliance Officer. Checks all 6 agents every 15 min. Reports to Yoda. Never acts directly. See `state/model-policy.json`.
  - Script: `scripts/model-drift-check.sh` — 9 checks, exit 0=clean/exit 2=violation
  - State: `state/model-drift-state.json`, `state/model-drift-violations.json`
  - Escalation: writes `state/warden-escalation-pending.json` → Yoda heartbeat picks up + remediates
  - Cron: every 15 min, isolated agentTurn (cron id: 83accf7b)
  - Policy registry: `state/model-policy.json` (per-agent allowed/required/prohibited models)

## Key Scripts & Infrastructure (Day 3)
- `scripts/auto-heal.sh` — nightly 23:30 AEST, 12 checks, auto-fixes stale state, files Notion US for needs-Ken items
- `scripts/run-diagnostics.sh` — on-demand `/diagnostics`, 6 phases, last result: 16 PASS / 6 WARN / 0 FAIL (Day 3 22:10)
- `scripts/ticket.sh` — ITSM ticketing (TKT-NNNN), ticket-first rule enforced before any ad-hoc work
- `scripts/changelog-append.sh` — auto-increments CHG-NNNN in `memory/CHANGELOG.md`
- `scripts/gateway-config-snapshot.sh` + `scripts/gateway-restore.sh` — config snapshot/restore SOP
- `state/critical-config-baseline.json` — anti-drift guard (7 configs), validated by auto-heal Check #12

## Operations Docs (locked)
- `~/Documents/AInchors/Operations/JournalFormat.md` — locked journal spec (verbatim Ken prompts, Yoda voice, private)
- `~/Documents/AInchors/Operations/BlogFormat.md` — locked blog spec (Ken first-person, public-ready, built FROM journal)
- `~/Documents/AInchors/Operations/ResiliencyFramework.md` — 5-level resiliency stack doc
- `~/Documents/AInchors/Operations/GatewayRecovery.md` — troubleshoot → restore from snapshot → openclaw reset

## Daily Output Locations
- **Journal:** `memory/journal-YYYY-MM-DD.md`
- **Blog:** `canvas/documents/ainchors-YYYY-MM-DD/index.html`

## GitHub
- GitHub CLI (`gh`) authenticated: account **kenmun-ainchors**, scopes: repo, read:org, gist (token in keyring)

## Known Incidents & Fixes (Day 3)
- **Bonjour/ciao plugin** disabled (CHG-0036) — was crash-looping every ~9s, caused gateway crash at 19:30 AEST
- **Model drift** x2 — Opus snuck in after reset. Anti-drift baseline + auto-heal Check #12 now guards this.
- **Dual Telegram bot** (CHG-0038) — eliminates routing ambiguity permanently. One bot per agent.

## Open Items
- Company name not yet captured — ask Ken
- Email: kenmun@ainchors.com being set up — integrate once live
- Project management tool: not yet decided
- Social media accounts not yet connected (Instagram, Facebook, LinkedIn — in priority order)
- Remote access (Tailscale) deferred
- Agent team to be designed and built

## Active Backlog (User Stories — Notion source of truth)
- US18: Monthly SLA Report (reliability)
- US19: HA Design (reliability)
- US20: Research Framework formalised
- US22: Fix cost tracker script (parser broken — High)
- **US23: Resilient outage handling (High, Platform, M)** — NEW Day 3. Triggered by 2026-04-26 night outage. Auto-detect billing/auth failures, validate fallback chain on boot + first failure, Gemma4 standby mode with user-facing banner, full recovery doc.
- PiKVM remote access (deferred, hardware dependency)
