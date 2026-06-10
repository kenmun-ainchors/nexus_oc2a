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
## CREST Loop — Cognitive Routing & Execution Sandwich Topology (LOCKED 2026-06-09)
- **Keyword:** CREST — Ken's reference word for the orchestration execution model
- **Phases:** Plan (strong) → Execute (cheap) → Verify (strong) → Replan (strong) → Synthesize (cheap) → Done (terminal)
- **Strong-tier:** Yoda, Atlas, Thrawn — cognitive work (plan, verify, replan). Expensive models.
- **Cheap-tier:** Forge, infra, specialist executors — mechanical work (execute, synthesize). Efficient models.
- **Replan Gate:** Critical decision hub. Gap found → iterate back to Execute (n++). Stop met → advance to Synthesize.
- **Routing:** Yoda plans typed DAG → queues atoms via TQP → cheap-tier executes → Yoda binary-judges 0–1 per atom → Replan → Synthesize → Done emits audit.
- **Cross-strong-tier:** Yoda ↔ Atlas/Thrawn coordination deferred to design stage.
- **CREST Loop:** see docs/CREST-v1.2-Recursive-Model-C.md (LOCKED, dual PASS)

# Governance Agents
- **Shield🛡️/Lex⚖️/Sage🧪** — Haiku. Move to Gemma4 at TRIGGER-03.
- **Warden 🔍** Model Compliance, 15-min cron:83accf7b. State: model-drift-state.json/violations.json. Escalation → warden-escalation-pending.json → Yoda.

## Key Scripts & Infrastructure
- `auto-heal.sh` (01:00 AEST, 19 checks) | `run-diagnostics.sh` (/diagnostics, 7 phases) | `changelog-append.sh` (CHG+Notion) | `gateway-config-snapshot.sh`/`gateway-restore.sh` | `cost-tracker.sh` | `audit-skill.sh` | `telegram-alert.sh`
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

## Anthropic API Key Rotation
Model routing: see skill at `infra/sandbox/seed/skills/model-routing/SKILL.md` and `docs/Model3-Policy.md`

## Config Baseline (Day 20)
→ See `state/critical-config-baseline.json` for live drift detection.

## kimi Policy — DECOMMISSIONED 2026-05-26
DeepSeek = permanent primary. kimi = fallback only. Full history: `memory/MEMORY-archive-2026-05-27.md`.

- 2026-05-25: TKT-0295 (PG Audit) parked due to Tier 3 budget breach.
---

_Historical EOD sections archived to `memory/MEMORY-archive-2026-06-09.md`._

