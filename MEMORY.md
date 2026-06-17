# MEMORY.md - Yoda's Long-Term Memory

## Identity
- Name: Yoda 🟢 | Role: AI business operations lead agent for Ken Mun (CTO), AInchors

## The People
- **Ken Mun** — Co-founder, CTO. Email: kenmun@ainchors.com | Mobile: +61403650578
- **Angie Foong** — Co-founder, CEO. Email: angie.foong@ainchors.com | Mobile: +61430928371
- Telegram contacts: see `infra/sandbox/seed/skills/telegram/SKILL.md`

## The Company
- **AInchor Solutions Pty Ltd** | ainchors.com | Sydney + Melbourne. Day 1: 2026-04-25. Focus: AI courses/training, consulting, solutions/products.
- **Aevlith Technologies Pty Ltd** — Technology holding entity, owns Nexus platform. AInchors = market-facing brand. Domain: aevlith.ai (AYV-lith, confirmed). ASIC registration to proceed. P1–P3: silent. P4: surfaces as product brand.
- Emails: kenmun@ ✅ gog | info@ | accounts@ | Gmail (Google Workspace). Tech: Ken+Yoda. Business: Angie+Aria.

## Infrastructure — HIVE Architecture (confirmed May 2026)
- **OC1** — Mac Mini M4 24GB — LIVE Production. PERMANENT. HARD LIMIT: No local LLM inference >~8B Q4.
- **OC2-A/B** — Mac Mini M4 Pro 48GB ×2 — INCOMING ETA 6–13 Jul 2026. A=HA Primary, B=Standby. Commission ~27 Jul. OC2-gated items wait for TRIGGER-03.
- Supporting: Tailscale mesh, NAS. Platform: OpenClaw (final).

## Agent Architecture

### Governance Tier Model (approved Ken 2026-05-08, TKT-0103)
- T0: Yoda (lead) | T1: Aria (dual-principal: CEO+Yoda) | T2: Warden (Yoda-Govern) | T3: Spark, Atlas, Thrawn, Lando, Forge, Mon Mothma, Krennic (Yoda-Manage-Passthrough); Luthen queued P2 | T4: Shield, Lex, Sage (reactive verdict-only)
- **⚠️ L-026:** Build/scripts → **Forge ONLY**. Atlas=EA assess. Thrawn=arch design. NEVER route build to Thrawn/Atlas.
- Model routing: see skill at `infra/sandbox/seed/skills/model-routing/SKILL.md` and `docs/Model3-Policy.md`

## Agent SOUL.md Compact Standard (NON-NEGOTIABLE)
- SOUL.md: hard limit 10,000 (warn 6,000). MEMORY.md: hard limit 15,000 (warn 12,000). Archive overflow at 12K, trim to 10K.

#
## Ken's Governance Mandate — 2026-06-13 13:54 AEST (CHG-0545)
Four rules locked into SOUL.md Non-Negotiables (#13–16) and confirmed by Ken:
1. **No fabrication.** Say "I don't know" and find out.
2. **Evidence-only.** Done/verified = validated + backed by artifacts. Vibe ≠ fact.
3. **CREST mandatory.** Load the skill: `bash scripts/skill-load.sh crest`.
4. **Orchestrator only.** Yoda's CREST activities = Plan, Verify, Replan, Synthesize, Close. Execute is NEVER mine. Per-instance Ken approval required for any exception.

Triggered by: TKT-0501 "CREST synthesize and close" prompt where Yoda correctly observed ticket was already closed but could be misread as over-claiming. CHG-0545.

## CREST + Agile Skills
- CREST execution topology: `bash scripts/skill-load.sh crest`
- Agile delivery framework: `bash scripts/skill-load.sh agile`
- Sprint/ticket ops: `infra/sandbox/seed/skills/pg-sprint-backlog/SKILL.md`

**Rule:** No tribal knowledge — reference skills, not inline memory.

# Governance Agents
- **Shield🛡️/Lex⚖️/Sage🧪** — reactive verdict-only (T4).
- **Warden 🔍** Model Compliance, 15-min cron:83accf7b. Escalation → warden-escalation-pending.json → Yoda.

## Key Scripts & Infrastructure
- `auto-heal.sh` (01:00 AEST, 24 checks) | `changelog-append.sh` (CHG+Notion) | `gateway-config-snapshot.sh`/`gateway-restore.sh`
- L-085: Long-ID stub detector — auto-heal CHECK 24, non-destructive. 7/7 tests pass.
- Ticket/sprint: see `infra/sandbox/seed/skills/pg-sprint-backlog/SKILL.md`

## Operations Docs (locked)
- Journal: Notion+`memory/journal-YYYY-MM-DD.md` | Blog: Notion+`canvas/documents/ainchors-YYYY-MM-DD/index.html`
- Key docs: `docs/` → Governance_Framework_v1, Model3-Policy, ORCHESTRATOR, RUNBOOK

## GitHub
- gh CLI: account **kenmun-ainchors**, scopes: repo, read:org, gist (keyring).

## Nexus — Star Wars Naming (LOCKED ✅)
Nexus=platform|Holocron=AKB|Bridge=cmd-centre|Citadel=client-portal|Holonet=live-data|Beacon=monitoring|Sanctum=governance|Datapad=reporting. New: Star Wars themes, Ken approves.

## LinkedIn Campaign — Canonical 4-Week Foundation Arc (LOCKED-IN v3.0, CHG-0594, 2026-06-15)
- **Schedule:** Tue 07:30, Wed 12:00, Thu 07:30 AEST — 12 posts / 4 weeks / 4 movements
- **Voice rules (NON-NEGOTIABLE):** no AInchors, no Yoda, no Nexus, no agent names, no platform internals, no em-dashes, no "co-founder", no finite time references, no consulting-speak, no fake clients.
- **Crons:** Tue 13b0aa89, Wed 833ee0c7, Thu 869502c9 (`ollama/minimax-m3:cloud`)
- **Deprecated drafts:** archived `archive/linkedin-stale/2026-06-15/` — DO NOT use.
- Full angle brief + movement details: `.openclaw/tmp/spark-reactivation-4week-arc.md` (LOCKED-IN, do not edit without Ken approval)

## LinkedIn Posting Rule — Missed Schedule (locked 2026-05-13)
- Missed post → push to next slot (Tue 07:30→Wed 12:00→Thu 07:30→next Tue 07:30). Never post late. If slot taken, skip entirely. All Spark crons.

## Open Items
- Notion DB architecture: see TOOLS.md (CHG-0401 3-DB setup)
- LinkedIn ✅ connected. Instagram/Facebook/X not yet connected.

## Model Routing — Permanent Structure (LOCKED 2026-06-15, CHG-0596)
- **Yoda (main) + Aria (business):** `ollama/deepseek-v4-pro:cloud` (tier-1 cognitive, NO fabrication)
- **T3 Specialists (Sage/Forge/Ahsoka/Luthen/Spark):** `ollama/minimax-m3:cloud` (tier-2 engineering)
- **Backend (Shield/Lex/Warden/Atlas/Thrawn/Lando/Mon Mothma):** `ollama/gemma4:31b-cloud`
- **Yoda-on-deepseek verifies all T3-on-minimax outputs** as structural guardrail per CREST v1.3
- **Minimax trial TERMINATED** 2026-06-15 17:57 AEST (CHG-0596). Verdict: PARTIAL — good for engineering, NOT for engagement/planning.
- **NO-FABRICATION directive** (Ken 17:57 AEST): Yoda absolute NO fabrication of data. New additional directive.
- Model routing skill: `infra/sandbox/seed/skills/model-routing/SKILL.md`
- Model policy SSOT: `state/model-policy.json`

## Security & Network
- S1–S7: see `RULES.md`. Tailscale: OC1 serve, S2 compliant. CHG triggers: see changelog skill.

## Platform Phase Definitions (LOCKED 2026-05-12 — Ken Mun)
- **MVP** — OC1-only, two founders, core platform live (now).
- **P1** — OC2 era, HA cluster, NAS, KL team (~Jul 2026)
- **P2** — SaaS: individuals + SME, first paying clients, Citadel live (~Aug 2026)
- **P3** — SME onsite install ⚠️ PARKED
- **P4** — Enterprise: multi-tenant, BYOK, Holonet

## KL Team & Sprint Capacity
- KL, Malaysia. 4–5 headcount. P1: Cloudflare Access, role-scoped IAM.
- Sprint capacity + pending tickets: see `infra/sandbox/seed/skills/pg-sprint-backlog/SKILL.md`.

## Anthropic — PERMANENTLY PARKED (2026-06-12 08:12)
- **Directive (Ken verbatim):** "Anthropic credits and model enablement - Permanently park until I provide future instruction and update"
- **What this means:** NO Anthropic API key rotation, NO higherQuality tier activation, NO agent assignment to Anthropic models, NO TKT-0241 work, NO `globalAllowedModels` additions of new Anthropic variants. Anthropic stays as a documented option in policy but is **not active**.
- **Unblock keyword:** Ken must explicitly say "CLAUDE ACTIVATE" (or similar) to unblock. Until then, all Anthropic work is parked.
- **Monitoring:** NONE. No alerts, no reminders, no review cadence. This is a permanent park by design.
- **Reference:** `state/parks/anthropic.json` (full scope, unblock conditions, related artifacts). CHG-0502.
- **Linked:** TKT-0241 (now status=parked, was ungated by CHG-0500, re-parked by CHG-0502 per this directive), CHG-0500 (CLAUDE RECONFIGURE — risk framework is CREST v1.3, not Anthropic), CHG-0502 (this park), state/parks/anthropic.json.
- **Anti-regression:** TKT-0241 status changed from "open (ungated)" to "parked". The `higherQuality` tier in model-policy.json has `agentIds: []` and `active: false` — must stay that way. If any future work proposes Anthropic enablement, check this section + state/parks/anthropic.json first.

## Config Baseline (Day 20)
→ See `state/critical-config-baseline.json` for live drift detection.

## kimi Policy — DECOMMISSIONED 2026-05-26
DeepSeek = permanent primary. kimi = fallback only. Full history: `memory/MEMORY-archive-2026-05-27.md`.

- 2026-05-25: TKT-0295 (PG Audit) parked due to Tier 3 budget breach.
---

_Historical EOD sections archived to `memory/MEMORY-archive-2026-06-09.md`._

