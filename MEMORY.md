# MEMORY.md - Yoda's Long-Term Memory

## Identity
- Name: Yoda 🟢 | Role: AI business operations lead agent for Ken Mun (CTO), AInchors

## The People
- **Ken Mun** — Co-founder, CTO. Email: kenmun@ainchors.com | Mobile: +61403650578
- **Angie Foong** — Co-founder, CEO. Email: angie.foong@ainchors.com | Mobile: +61430928371
- Telegram contacts: load skill `bash scripts/skill-load.sh telegram`

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
- Model routing: load skill `bash scripts/skill-load.sh model-routing` and `docs/Model3-Policy.md`

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
- Sprint/ticket ops: load skill `bash scripts/skill-load.sh pg-sprint-backlog`

**Rule:** No tribal knowledge — reference skills, not inline memory.

## Skills Loader — Canonical Path (TKT-0535, CHG-0623)
- `scripts/skill-load.sh` is the **only** supported way to load a platform skill.
- It validates against `infra/sandbox/seed/skills/.index.json` and fails closed for unknown/unapproved skills.
- Skill packages live at `infra/sandbox/seed/skills/<name>/SKILL.md` — SSOT.
- `scripts/ticket.sh` is deprecated; use `db-ticket.sh` after loading `pg-sprint-backlog`.

# Governance Agents
- **Shield🛡️/Lex⚖️/Sage🧪** — reactive verdict-only (T4).
- **Warden 🔍** Model Compliance, 15-min cron:83accf7b. Escalation → warden-escalation-pending.json → Yoda.

## Key Scripts & Infrastructure
- `auto-heal.sh` (01:00 AEST, 24 checks) | `changelog-append.sh` (CHG+Notion) | `gateway-config-snapshot.sh`/`gateway-restore.sh`
- L-085: Long-ID stub detector — auto-heal CHECK 24, non-destructive. 7/7 tests pass.
- Ticket/sprint: load skill `bash scripts/skill-load.sh pg-sprint-backlog`

## Notion + Agile Skill Packages — Canonical 2026-06-20 (CHG-0677, CHG-0678, CHG-0679)
- **Notion skill:** `agent-skills/notion/SKILL.md` — SSOT for auth, DB IDs, API patterns, rate limits. `agent-skills/notion/scripts/notion-env-check.sh` validates connectivity. Registered in `agent-skills/.index.json`.
- **Agile skill:** `agent-skills/agile/scripts/sprint-review.sh` — canonical Sprint Review report generator. Checklist at `agent-skills/agile/references/sprint-review-checklist.md`.
- **Skill-first enforcement:** 8 Notion scripts now require `notion` skill load. `db-sprint.sh` auto-generates review report on `ceremony complete review`.
- **Cleanup pattern:** after building a skill package, always sweep MEMORY.md, HEARTBEAT.md, TOOLS.md, and agent AGENTS.md for inline tribal knowledge and redirect to the skill package.

## CREST v1.3 — Approved 2026-06-20 09:28 AEST (CHG-0680)
- **Status:** Approved, not yet executed. TKT-0546 (critical epic) open.
- **Three moves:** (1) External loop ownership — Yoda owns CREST loop; agents are phase executors. (2) Sage-as-Judge — Sage renders Verify pass/fail/needs_human verdicts; specialists assemble evidence only. (3) Capability-based multi-model routing — role×data_class×phase matrix replaces binary model selection; Verify primary: gemma4:31b-cloud (20/20 benchmark).
- **Pre-Tier-A gates (G1-G5):** CHG record, baseline snapshot, down-migration DDL, judgment benchmark (glm-5.1 ≥90% on 20 atoms), dispatch-validate baseline. Must complete before any Tier A execution.
- **Docs:** `docs/CREST-v1.3-Recursive-Model-C.md`, `docs/CREST-v1.3-Model-Policy-Schema.md`, `agents/sage/SOUL.md` + `AGENTS.md`.
- **Oracle-reviewed:** kimi-k2.6:cloud 2026-06-20 09:15 AEST; 8 gaps fixed in v2.
- **No execution until Ken triggers.**

## Open Bug — openclaw CLI wrapper PATH collision (TKT-0542)
- `bash openclaw cron get <id>` fails because `openclaw` wrapper resolves ImageMagick `import` binary instead of its intended helper. Workaround: use native `cron` tool. Not yet fixed.

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
- **Notion DB architecture:** see `agent-skills/notion/SKILL.md` and `TOOLS.md` (CHG-0401 3-DB setup)
- **Notion skills + patterns:** canonical reference is `agent-skills/notion/SKILL.md`
- LinkedIn ✅ connected. Instagram/Facebook/X not yet connected.

## Model Routing — Permanent Structure (LOCKED 2026-06-15, CHG-0596)
- Load skill: `bash scripts/skill-load.sh model-routing`
- Model policy SSOT: `state/model-policy.json`
- **NO-FABRICATION directive** (Ken 17:57 AEST): Yoda absolute NO fabrication of data.
- **Minimax trial TERMINATED** 2026-06-15 17:57 AEST (CHG-0596). Verdict: PARTIAL.

## Aria Default Chat Model Alignment — 2026-06-20 16:04 AEST (CHG-0691)
- **Decision:** Aria default chat/user-interaction model = `ollama/kimi-k2.7-code:cloud`, matching Yoda.
- **Scope:** `business`, `ahsoka`, `luthen` agent static models in `openclaw.json`; `business|Synthesize` PG rule moved to `kimi-k2.7-code:cloud`; `crest_v13.phase_rules` re-exported from PG.
- **Governance fix:** `scripts/model-policy-query.sh` JSON fallback now reads `crest_v13.phase_rules` (role+phase) before legacy `agentTiers`. `scripts/model-drift-check.sh` Agent Models check now uses CREST v1.3 phase rules.
- **Verification:** Warden 55/55 PASS, 0 FAIL.
- **SSOT:** `state/model-policy.json`, `state/critical-config-baseline.json`, PG `crest_phase_rules`, `~/.openclaw/openclaw.json`.

## Yoda/Aria CREST Plan/Replan — kimi-k2.7-code:cloud Primary — 2026-06-20 13:40 AEST (CHG-0690)
- **Benchmark:** 12-atom Yoda+Aria CREST Plan test vs `glm-5.2:cloud`, `kimi-k2.7-code:cloud`, `deepseek-v4-pro:cloud`.
- **Verdict:** `kimi-k2.7-code:cloud` adjusted 91.5% > deepseek 87.2% > glm 84.6%.
- **Action:** PG `crest_phase_rules` updated — `yoda_master` Plan/Replan primary → `kimi-k2.7-code:cloud` (fallback `deepseek-v4-pro:cloud`); `business` Plan/Replan primary → `kimi-k2.7-code:cloud` (fallback `kimi-k2.6:cloud`).
- **SSOT:** `state/model-policy.json`, `agent-skills/crest/SKILL.md`, PG `state_model_policy.crest_phase_rules`.

## GLM-5.2:cloud Adoption — 2026-06-20 11:58 AEST (CHG-0685)
- **Verify role:** NOT viable. No filesystem access via `ollama run` and emits visible chain-of-thought; same block as glm-5.1:cloud.
- **Plan/Analysis role:** Adopted as primary for `design_backend` agents (Atlas, Thrawn, Lando, Mon Mothma). Corrected rubric-only benchmark: glm-5.2:cloud 91.7% (77/84), deepseek-v4-pro:cloud 90.5%, kimi-k2.7-code:cloud 89.3%.
- **Replan role:** `kimi-k2.7-code:cloud` primary for `design_backend`; it led on Replan in the benchmark.
- **Yoda/Aria primary:** Unchanged at `kimi-k2.7-code:cloud`.
- **Deepseek-v4-pro:cloud:** Demoted to fallback-only for `design_backend` Plan/Replan. No longer justified as primary: most expensive and no longer leading.
- **Policy files updated:** `state/model-policy.json`, `state/critical-config-baseline.json`. `ollama/glm-5.2:cloud` added to `globalAllowedModels` and CREST v1.3 model registry.
- **Verification note:** Sage verification failed due to sandbox workspace isolation. Forge re-scored and orchestrator audited corrected math. Full transparency logged in CHG-0685.


## Archived Sections
Older/less-frequently-used sections moved to `memory/MEMORY-archive-2026-06-20.md` on 2026-06-20 to keep MEMORY.md within the 10–12K soft limit. Searchable on demand.

