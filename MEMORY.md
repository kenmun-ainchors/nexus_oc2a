# MEMORY.md - Yoda's Long-Term Memory

## Identity
- Name: Yoda 🟢 | Role: AI business operations lead agent for Ken Mun (CTO), AInchors

## The People
- **Ken Mun** — Co-founder, CTO. Email: kenmun@ainchors.com | Mobile: +61403650578
- **Angie Foong** — Co-founder, CEO. Email: angie.foong@ainchors.com | Mobile: +61430928371
- **Subagent completion update rule (Ken directive 2026-07-03, CHG-0812 follow-up):** When Yoda dispatches a subagent (e.g. Forge via `sessions_spawn`), the turn must end with a visible status message to Ken, not silence. When the subagent completion event arrives, Yoda must immediately synthesise it and send a concise result/summary + verdict. Ken never has to ask "stalled?" or "any progress?".
- Telegram contacts: load skill `bash scripts/skill-load.sh telegram`

## The Company
- **AInchor Solutions Pty Ltd** | ainchors.com | Sydney + Melbourne. Day 1: 2026-04-25. Focus: AI courses/training, consulting, solutions/products.
- **Aevlith Technologies Pty Ltd** — Technology holding entity, owns Nexus platform. AInchors = market-facing brand. Domain: aevlith.ai (AYV-lith, confirmed). ASIC registration to proceed. P1–P3: silent. P4: surfaces as product brand.
- Emails: kenmun@ ✅ gog | info@ | accounts@ | Gmail (Google Workspace). Tech: Ken+Yoda. Business: Angie+Aria.

## Infrastructure — HIVE Architecture (cutover completed 2026-07-14)
- **OC2A** — Mac Mini M4 Pro 48GB — **LIVE Production**. HIVE lead node. All gateway, agents, PostgreSQL, MinIO, and operational services run here.
- **OC1** — Mac Mini M4 24GB — **Dev/test environment**. Standalone, passive standby. Repurposed from production 2026-07-14. Not active in PROD routing.
- **OC2-A/B** — Mac Mini M4 Pro 48GB ×2 — INCOMING ETA 6–13 Jul 2026. A=HA Primary, B=Standby. Commission ~27 Jul. OC2-gated items wait for TRIGGER-03. Once commissioned, OC2A role will migrate to HA primary pair.
- Supporting: Tailscale mesh, NAS. Platform: OpenClaw (final).

## Agent Architecture

### Governance Tier Model (approved Ken 2026-05-08, TKT-0103)
- T0: Yoda (lead) | T1: Aria (dual-principal: CEO+Yoda) | T2: Warden (Yoda-Govern) | T3: Spark, Atlas, Thrawn, Lando, Forge, Mon Mothma, Krennic (Yoda-Manage-Passthrough); Luthen queued P2 | T4: Shield, Lex, Sage (reactive verdict-only)
- **⚠️ L-026:** Build/scripts → **Forge ONLY**. Atlas=EA assess. Thrawn=arch design. NEVER route build to Thrawn/Atlas.
- Model routing: load skill `bash scripts/skill-load.sh model-routing` and `docs/Model3-Policy.md`

## Ken's Governance Mandate — 2026-06-13 13:54 AEST (CHG-0545)
Four rules locked into SOUL.md Non-Negotiables (#13–16) and confirmed by Ken:
1. **No fabrication.** Say "I don't know" and find out.
2. **Evidence-only.** Done/verified = validated + backed by artifacts. Vibe ≠ fact.
3. **CREST mandatory.** Load the skill: `bash scripts/skill-load.sh crest`.
4. **Orchestrator only.** Yoda's CREST activities = Plan, Verify, Replan, Synthesize, Close. Execute is NEVER mine. Per-instance Ken approval required for any exception.

## CREST + Agile Skills
- CREST execution topology: `bash scripts/skill-load.sh crest`
- Agile delivery framework: `bash scripts/skill-load.sh agile`
- Sprint/ticket ops: load skill `bash scripts/skill-load.sh pg-sprint-backlog`
- **Rule:** No tribal knowledge — reference skills, not inline memory.

## Keyword Triggers
- `/init` — run initialization: load all registered skills, verify readiness, return green-light summary.

## Skills Loader — Canonical Path (TKT-0535, CHG-0623)
- `scripts/skill-load.sh` is the **only** supported way to load a platform skill. Validates against `infra/sandbox/seed/skills/.index.json` and fails closed. SSOT: `infra/sandbox/seed/skills/<name>/SKILL.md`.
- `scripts/ticket.sh` is deprecated; use `db-ticket.sh` after loading `pg-sprint-backlog`.

## Governance Agents
- **Shield🛡️/Lex⚖️/Sage🧪** — reactive verdict-only (T4).
- **Warden 🔍** Model Compliance, 15-min cron:83accf7b. Escalation → warden-escalation-pending.json → Yoda.

## Key Scripts & Infrastructure
- `auto-heal.sh` (01:00 AEST, 24 checks) | `changelog-append.sh` (CHG+Notion) | `gateway-config-snapshot.sh`/`gateway-restore.sh`
- L-085: Long-ID stub detector — auto-heal CHECK 24, non-destructive.
- Ticket/sprint: load skill `bash scripts/skill-load.sh pg-sprint-backlog`

## Notion + Agile Skill Packages — Canonical 2026-06-20 (CHG-0677, CHG-0678, CHG-0679)
- **Notion skill:** `agent-skills/notion/SKILL.md` — SSOT for auth, DB IDs, API patterns, rate limits.
- **Agile skill:** `agent-skills/agile/scripts/sprint-review.sh` — canonical Sprint Review report generator.
- **Cleanup pattern:** after building a skill package, sweep MEMORY.md, HEARTBEAT.md, TOOLS.md, and agent AGENTS.md for inline tribal knowledge.

## Operations Docs (locked)
- Journal: Notion+`memory/journal-YYYY-MM-DD.md` | Blog: Notion+`canvas/documents/ainchors-YYYY-MM-DD/index.html`
- Key docs: `docs/` → Governance_Framework_v1, Model3-Policy, ORCHESTRATOR, RUNBOOK

## GitHub
- gh CLI: account **kenmun-ainchors**, scopes: repo, read:org, gist (keyring).

## Nexus — Star Wars Naming (LOCKED ✅)
Nexus=platform|Holocron=AKB|Bridge=cmd-centre|Citadel=client-portal|Holonet=live-data|Beacon=monitoring|Sanctum=governance|Datapad=reporting.

## LinkedIn Campaign — Canonical 4-Week Foundation Arc (LOCKED-IN v3.0, CHG-0594, 2026-06-15)
- **Schedule:** Tue 07:30, Wed 12:00, Thu 07:30 AEST — 12 posts / 4 weeks / 4 movements
- **Voice rules (NON-NEGOTIABLE):** no AInchors, no Yoda, no Nexus, no agent names, no platform internals, no em-dashes, no "co-founder", no finite time references, no consulting-speak, no fake clients.
- **Crons:** Tue 13b0aa89, Wed 833ee0c7, Thu 869502c9 (`ollama/minimax-m3:cloud`)
- Full angle brief + movement details: `.openclaw/tmp/spark-reactivation-4week-arc.md`

## LinkedIn Posting Rule — Missed Schedule (locked 2026-05-13)
- Missed post → push to next slot (Tue 07:30→Wed 12:00→Thu 07:30→next Tue 07:30). Never post late. If slot taken, skip entirely. All Spark crons.

## Open Items
- **Notion DB architecture:** see `agent-skills/notion/SKILL.md` and `TOOLS.md` (CHG-0401 3-DB setup)
- **Notion skills + patterns:** canonical reference is `agent-skills/notion/SKILL.md`
- **EOD Blog publishing policy:** intentionally local-only until Citadel client portal is live. Files generated nightly at `~/.openclaw/canvas/documents/ainchors-YYYY-MM-DD/index.html`; no website/social distribution. (Ken directive 2026-07-10.)
- LinkedIn ✅ connected. Instagram/Facebook/X not yet connected.

## Master Platform Context (DNA) — 2026-06-21
Context handoffs in `docs/context-handoffs/`. Latest: 2026-06-07 → 2026-06-21. Drive folder: https://drive.google.com/drive/folders/1nQ5hUDeCfRTmGXFZkJmJ5DDLdgHemyp8

## Model Routing Reference (compact)
- SSOT: `state/model-policy.json`. Load skill: `bash scripts/skill-load.sh model-routing`.
- Verify primary: gemma4:31b-cloud. Yoda/Aria primary: kimi-k2.7-code:cloud.
- **NO-FABRICATION directive** (Ken 17:57 AEST).

## Ollama Credit / Usage Tracking (Ken correction 2026-07-13 10:01 AEST)
- **Actual credit is scraped from the Ollama Cloud usage page (`ollama.com/settings`).**
- Each model has its own usage currency; request count is an internal soft indicator only.
- **SSOT:** `scripts/ollama-usage-scraper.py` / `scripts/ollama-usage-scraper-run.sh` → updates `state/cost-state.json`.
- `scripts/request-budget-check.sh` reads `cost-state.json` and reports status against the live scraped limit.
- **Stale knowledge removed:** the 30,000 requests/week flat formula is no longer authoritative. Use dashboard-derived numbers.

## CREST v1.3 Reference (compact)
- Three moves: (1) Yoda owns CREST loop; agents are phase executors. (2) Sage-as-Judge for Verify. (3) Capability-based multi-model routing (role×phase matrix). Verify primary: gemma4:31b-cloud (20/20 benchmark).
- Docs: `docs/CREST-v1.3-Recursive-Model-C.md`, `docs/CREST-v1.3-Model-Policy-Schema.md`.

## Promoted From Short-Term Memory (2026-07-02)

<!-- openclaw-memory-promotion:memory:memory/2026-06-27.md:18:18 -->
- CRESTv2-P1 Gate Review — CRESTv2-P1-WS12-REVIEW-001: Tracker updated at state/crestv2-p1-tracker.json [score=0.806 recalls=0 avg=0.620 source=memory/2026-06-27.md:18-18]
<!-- openclaw-memory-promotion:memory:memory/2026-06-27.md:22:22 -->
- WS-3 Groom — delivered to Ken in webchat session: Full brief delivered. Three open tickets + one re-opened: [score=0.806 recalls=0 avg=0.620 source=memory/2026-06-27.md:22-22]
<!-- openclaw-memory-promotion:memory:memory/2026-06-27.md:24:27 -->
- WS-3 Groom — delivered to Ken in webchat session: **TKT-0344** — Wire state_model_policy to PG live write + F2 case normalization absorption + F3 denominator recheck; **TKT-0348** — Wire state_sprints auto-commit + sprint FK audit; **TKT-0354** — Wire state_standups to PG-first (new table, straightforward); **TKT-0359** — PG-First Write Policy enforcement gate (NOTA — closure evidence = Notion status + gate test) [score=0.806 recalls=0 avg=0.620 source=memory/2026-06-27.md:24-27]
<!-- openclaw-memory-promotion:memory:memory/2026-06-27.md:29:29 -->
- WS-3 Groom — delivered to Ken in webchat session: **Three decisions Ken deferred (too tired):** [score=0.806 recalls=0 avg=0.620 source=memory/2026-06-27.md:29-29]
<!-- openclaw-memory-promotion:memory:memory/2026-06-27.md:30:32 -->
- WS-3 Groom — delivered to Ken in webchat session: F2 absorption: fold into TKT-0344 scope or separate ticket?; F8 coupling: brief Atlas now on state_model_policy read contract, or proceed with JSON-cache stopgap?; TKT-0359 enforcement gate shape: RULES.md rule, Warden script, or OpenClaw config validation? [score=0.806 recalls=0 avg=0.620 source=memory/2026-06-27.md:30-32]
<!-- openclaw-memory-promotion:memory:memory/2026-06-27.md:34:34 -->
- WS-3 Groom — delivered to Ken in webchat session: **Resume keyword:** `CREST WS-3 resume` [score=0.806 recalls=0 avg=0.620 source=memory/2026-06-27.md:34-34]
<!-- openclaw-memory-promotion:memory:memory/2026-06-27.md:4:4 -->
- PG-Notion Batch Sync (02:57 AEST): Batch reconciliation ran — all tickets synced. Nothing to process. [score=0.806 recalls=0 avg=0.620 source=memory/2026-06-27.md:4-4]