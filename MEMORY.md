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
- SOUL.md: hard limit 10,000 (warn 6,000). identity+traits+rules+cadences. Details in [AGENT]_RULES.md. Aria OOM cause (2026-04-30). All agents ✅ compliant 2026-05-08.
- MEMORY.md: hard limit 15,000 (warn 12,000). See `infra/sandbox/seed/skills/changelog/SKILL.md`. Archive overflow at 12K, trim to 10K.

#
## Ken's Governance Mandate — 2026-06-13 13:54 AEST (CHG-0545)
Four rules locked into SOUL.md Non-Negotiables (#13–16) and confirmed by Ken:
1. **No fabrication.** Say "I don't know" and find out.
2. **Evidence-only.** Done/verified = validated + backed by artifacts. Vibe ≠ fact.
3. **CREST mandatory.** Every plan with execution work runs Plan→Execute→Verify→Replan→Synthesize→Done. No skip phases.
4. **Orchestrator only.** Yoda's CREST activities = Plan, Verify, Replan, Synthesize, Close. Execute is NEVER mine. Per-instance Ken approval required for any exception.

Triggered by: TKT-0501 "CREST synthesize and close" prompt where Yoda correctly observed ticket was already closed but could be misread as over-claiming. Ken used it to lock the boundary. CHG-0545.

## CREST Loop — Cognitive Routing & Execution Sandwich Topology (LOCKED 2026-06-09)
- **Keyword:** CREST — Ken's reference word for the orchestration execution model
- **Phases:** Plan (strong) → Execute (cheap) → Verify (strong) → Replan (strong) → Synthesize (cheap) → Done (terminal)
- **Strong-tier:** Yoda, Atlas, Thrawn — cognitive work (plan, verify, replan). Expensive models.
- **Cheap-tier:** Forge, infra, specialist executors — mechanical work (execute, synthesize). Efficient models.
- **Replan Gate:** Critical decision hub. Gap found → iterate back to Execute (n++). Stop met → advance to Synthesize.
- **Routing:** Yoda plans typed DAG → queues atoms via TQP → cheap-tier executes → Yoda binary-judges 0–1 per atom → Replan → Synthesize → Done emits audit.
- **Cross-strong-tier:** Yoda ↔ Atlas/Thrown coordination deferred to design stage.
- **CREST Loop:** see docs/CREST-v1.2-Recursive-Model-C.md (LOCKED, dual PASS)

### CREST Enforcement Rules — NON-NEGOTIABLE (LOCKED 2026-06-11)
**Trigger:** ANY state change, ticket operation, config mutation, or platform operation — regardless of perceived size.

1. **No silent execution.** Before touching any tool for an operational task, output the Plan phase explicitly. Even single-atom tasks get a 1-line plan.
2. **Skill-gate always.** Before calling any domain script (db-ticket.sh, db-sprint.sh, changelog-append.sh, dispatch-validate.sh, telegram-alert.sh, pg-to-notion-sync.sh), run `bash scripts/skill-load.sh <name>` after reading the SKILL.md. Domain scripts now BLOCK if skill not in session registry (TKT-0396).
3. **No tribal knowledge.** Skills (pg-sprint-backlog, changelog, telegram, model-routing) were extracted from MEMORY.md/AGENTS.md into progressive-disclosure SKILL.md files on 2026-06-10. Reference the skill, not inline memory. Working memory = WHAT (rules), skills = HOW (procedures).
4. **Model tier discipline.** Plan/Verify/Replan = strong models. Execute/Synthesize = cheap models. Yoda never does specialist Execute work directly — dispatch to Forge or the appropriate specialist agent.
5. **Triage mode is not an exemption.** Processing a queue of Ken alerts does not suspend CREST. Each alert that requires operational action starts a new CREST loop.
6. **Self-check:** If Ken has to ask "did you use CREST?" or "did you load the skill?" — that's a violation. Log it immediately to LESSONS.md.

**Violations:** 3 strikes on Jun 11 (tilde fix, timeout batch-apply, ticket update) — all bypassed CREST + skill-gate. Root cause: triage-mode momentum treating operational tasks as chat replies. Fix: structural rule above.

# Governance Agents
- **Shield🛡️/Lex⚖️/Sage🧪** — Haiku. Move to Gemma4 at TRIGGER-03.
- **Warden 🔍** Model Compliance, 15-min cron:83accf7b. State: model-drift-state.json/violations.json. Escalation → warden-escalation-pending.json → Yoda.

## Key Scripts & Infrastructure
- `auto-heal.sh` (01:00 AEST, 24 checks including CHECK 24 L-085 long-ID stub detection) | `run-diagnostics.sh` (/diagnostics, 7 phases) | `changelog-append.sh` (CHG+Notion) | `gateway-config-snapshot.sh`/`gateway-restore.sh` | `cost-tracker.sh` | `audit-skill.sh` | `telegram-alert.sh` | `long-id-stub-check.sh` (L-085)
- L-085: Long-ID stub detector — flags TKT-NNNN: <text> duplicates of TKT-NNNN short IDs. Auto-heal CHECK 24, non-destructive. 7/7 tests pass.
- Ticket/sprint: see `infra/sandbox/seed/skills/pg-sprint-backlog/SKILL.md` (progressive disclosure)

## Operations Docs (locked)
- Journal: Notion+`memory/journal-YYYY-MM-DD.md` | Blog: Notion+`canvas/documents/ainchors-YYYY-MM-DD/index.html`
- Key docs: `docs/` → Governance_Framework_v1, Model3-Policy, ORCHESTRATOR, RUNBOOK

## GitHub
- gh CLI: account **kenmun-ainchors**, scopes: repo, read:org, gist (keyring).

## Nexus — Star Wars Naming (LOCKED ✅)
Nexus=platform|Holocron=AKB|Bridge=cmd-centre|Citadel=client-portal|Holonet=live-data|Beacon=monitoring|Sanctum=governance|Datapad=reporting. New: Star Wars themes, Ken approves.

## LinkedIn Posting Rule — Missed Schedule (locked 2026-05-13)
- Missed post → push to next slot (Tue 07:30→Wed 12:00→Thu 07:30→next Tue 07:30). Never post late. If slot taken, skip entirely. All Spark crons.

## Open Items
- Notion DB architecture: see TOOLS.md (CHG-0401 3-DB setup)
- LinkedIn ✅ connected. Instagram/Facebook/X not yet connected. Spark scope: IG/LI/FB/YT.
- ⚠️ TKT-0121: Ken to add HF API key to Keychain (LinkedIn FLUX image gen).

## Kimi Safety Net
Model routing: see skill at `infra/sandbox/seed/skills/model-routing/SKILL.md` and `docs/Model3-Policy.md`

## 4-Tier Model Strategy
Model routing: see skill at `infra/sandbox/seed/skills/model-routing/SKILL.md` and `docs/Model3-Policy.md`

## Security Controls (S1–S7)
- S1: OC ≥ v2026.5.12 | S2-S6: see `RULES.md` | S7: NAS encrypted (post-OC2)

## CHG Trigger Rules
Model routing: see skill at `infra/sandbox/seed/skills/model-routing/SKILL.md` and `docs/Model3-Policy.md`

## Tailscale
- OC1 serve, `allowTailscale: true`, URL: `https://ainchorss-mac-mini.tail5e2567.ts.net`. S2 compliant.

## Platform Phase Definitions (LOCKED 2026-05-12 — Ken Mun)
- **MVP** — OC1-only, two founders, core platform live (now).
- **P1** — OC2 era, HA cluster, NAS, KL team (~Jul 2026)
- **P2** — SaaS: individuals + SME, first paying clients, Citadel live (~Aug 2026)
- **P3** — SME onsite install ⚠️ PARKED
- **P4** — Enterprise: multi-tenant, BYOK, Holonet

## KL Team (confirmed 2026-05-12)
- KL, Malaysia. 4–5 headcount (Marketing/Dev/Support/Admin). Laptop+mobile, external network.
- Access: Cloudflare Access (P1). Role-scoped IAM.

## Sprint Capacity
- Pre-OC2: 5/sprint | OC2 setup: 2–3 | Post-OC2: 5. 30% headroom. P2 target: end-Aug 2026 (contingency mid-Sep). **Daily budget cap: $150** | **TEMPORARY: $450 until 2026-05-17** (heavy build phase). See changelog skill for CHG records.

## Pending Tickets
→ Run `bash scripts/db-sprint.sh status` for current sprint. See `infra/sandbox/seed/skills/pg-sprint-backlog/SKILL.md` for full interface.

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

