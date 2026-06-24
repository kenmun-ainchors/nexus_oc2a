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

## Keyword Triggers
- `/init` — run initialization: load all registered skills, verify readiness, return green-light summary. (Registered by Ken 2026-06-24.)

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

## CREST v1.3 — Executed 2026-06-20 09:28 AEST (CHG-0680)
- **Status:** Approved and fully executed. TKT-0546 closed; TKT-0547 (UAT) closed.
- **Three moves:** (1) External loop ownership — Yoda owns CREST loop; agents are phase executors. (2) Sage-as-Judge — Sage renders Verify pass/fail/needs_human verdicts; specialists assemble evidence only. (3) Capability-based multi-model routing — **role × phase** matrix replaces binary model selection; `data_class` dimension is schema-ready but intentionally unpopulated in v1.3, deferred to CREST v2.0 / TKT-0710. Verify primary: gemma4:31b-cloud (20/20 benchmark).
- **Pre-Tier-A gates (G1-G5):** all completed before execution: CHG record, baseline snapshot, down-migration DDL, judgment benchmark (gemma4:31b-cloud 20/20; glm-5.1:cloud deferred for thinking-output issue), dispatch-validate baseline.
- **Execution tiers:** Tiers A–D completed 2026-06-20. Verification sweep WS1/WS2/WS3 passed; synthetic sub-CREST UAT passed (Plan/Execute/Verify/Replan/Synthesize/Done).
- **Docs:** `docs/CREST-v1.3-Recursive-Model-C.md`, `docs/CREST-v1.3-Model-Policy-Schema.md`, `agents/sage/SOUL.md` + `AGENTS.md`.
- **Oracle-reviewed:** kimi-k2.6:cloud 2026-06-20 09:15 AEST; 8 gaps fixed in v2.

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

## Sprint 9 Planning Exception — Locked 2026-06-21 09:39 AEST (Ken Mun)
- **Sprint 9 (2026-06-22 → 2026-06-28) committed with 16 items** — explicit exception to the 6-item capacity rule.
- **Reason:** Must deliver TKT-0342 (PG SSOT Gap Remediation) and TKT-0368 (CREST v2.0 / Nexus Foundational Architecture) before OC2 arrives (ETA 6–13 Jul 2026, commission ~27 Jul).
- **Rule exception:** Velocity/capacity metrics will be skewed until both epics are complete. **Auto-rollover enabled** — unfinished Sprint 9 items roll into Sprint 10 automatically.
- **Priority stack:** TKT-0342 and TKT-0368 work takes precedence over all other Sprint 9 items.
- **Tooling note:** `db-sprint.sh current` incorrectly returned Sprint 11; actual next sprint was Sprint 9. Manually targeted Sprint 9 for all commits.

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


## Yoda CREST/Forge Self-Correction — 2026-06-21 09:56 AEST (Ken Mun)
- **Violation:** Yoda directly edited `scripts/db-write.sh`, `scripts/db-raw.sh`, and `scripts/test-db-write.sh` for TKT-0698 instead of dispatching Execute to Forge.
- **Rule locked in:** Yoda NEVER directly edits scripts/, infra/, or build/config files. Plan/Verify = Yoda; Execute = Forge via `sessions_spawn(agentId="infra")`.
- **No exceptions for:** small fixes, urgency, or "already in context". Per-instance exception requires explicit Ken/Angie approval.
- **Self-check:** before any `edit`/`write` on executable/config files, ask *"Is this Execute? Is this Forge's domain?"*

## Master Platform Context (DNA) — 2026-06-21
Long-term context handoffs for agent resumption and human reference. Stored in `docs/context-handoffs/` and mirrored to Google Drive `Master Platform Context/`.

| Period | Local Path | Drive Link |
|--------|------------|------------|
| 2026-05-10 → 2026-06-07 | `docs/context-handoffs/Context-Handoff-Delta-20260510-20260607---580465c6-6c77-41b8-b521-e89edbe3c396.md` | https://drive.google.com/file/d/1HektFfW2M5Xj9XfJqOhLLfeOgJ69aeXc/view?usp=drivesdk |
| 2026-06-07 → 2026-06-21 | `docs/context-handoffs/Context-Handoff-Delta-20260607-20260621.md` | https://drive.google.com/file/d/1cDJrRubNVkkS2qGEFEBKNHvVmY-oXP1r/view?usp=drivesdk |

**Drive folder:** https://drive.google.com/drive/folders/1nQ5hUDeCfRTmGXFZkJmJ5DDLdgHemyp8
**Consolidation rule:** Combine into a single master handoff when delta chain reaches 3+ or at next major milestone per Ken instruction.

## Archived Sections
Older/less-frequently-used sections moved to `memory/MEMORY-archive-2026-06-20.md` on 2026-06-20 to keep MEMORY.md within the 10–12K soft limit. Searchable on demand.


## CREST Groom vs Plan Process — Locked 2026-06-22 17:13 AEST (Ken directive)
- **Groom** = analyze ticket, refine scope, surface clarifications, assumptions, risks, open questions, and confirm decisions. Output is a **groomed brief**, not an execution plan.
- **CREST Step 1 — Plan** = takes the groomed brief and produces the execution plan: atoms, owner, schedule, rollback, evidence standards.
- Yoda must keep these separate. Groom first. Then CREST Plan. Then dispatch.
- Reference:  and .

## Promoted From Short-Term Memory (2026-06-25)

<!-- openclaw-memory-promotion:memory:memory/2026-05-10.md:1:19 -->
- ## 00:13 AEST — Obs Spike Investigation - delegation_fail: 3761 in 24h (+2450% vs prev) — ALL empty fields (task='', agent='', error=''). Regular hourly cron pattern 02–11Z. **Logging bug, not real failures.** Flag for Ken in morning. - health_failure: 212 — from INC-20260509-001 API outage (resolved). Historical. - Mission Control dashboard regenerated OK. Gateway: ok, Balance: $479.35. ## Mission Control Refresh — 08:38 AEST - Dashboard regenerated OK. Balance $479.35. Gateway OK. Agents idle. - **OBS spike investigated:** 3,761 "delegation_fail" entries in obs.db = PHANTOM DUPLICATES. - Root cause: obs-collector re-logging 34 April 28 delegation-log.json fail entries (with status=fail but no real task/agent data — likely latency tracking entries, not true delegation failures). - All have empty task/agent/error detail → bogus records. - Likely cause: lastRunEpoch was 0 or reset during 02:06–11:41 UTC on May 9 (9.5h window, ~114 cron runs × 34 = ~3876 entries). Now lastRunEpoch = May 9 22:35 → should stop repeating. - **Related to TKT-0112** (obs-collector cron run failures not captured). - No real operational crisis — no real delegation failures occurred. - Action: TKT-0112 needs priority bump. delegation-log.json entries that are latency records (not true delegation outcomes) should be excluded from delegation_fail check. ## 00:13 AEST — Obs Spike Investigation - delegation_fail: 3761 in 24h (+2450% vs prev) — ALL empty fields (task='', agent='', error=''). Regular hourly cron pattern 02–11Z. **Logging bug, not real failures.** Flag for Ken in morning. [score=0.811 recalls=7 avg=0.482 source=memory/2026-05-10.md:1-19]
