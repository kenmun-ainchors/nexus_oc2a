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
- **Aevlith Technologies Pty Ltd** — Technology holding entity, owns Nexus platform. AInchors = market-facing brand; invisible platform company. Domain: aevlith.ai (AYV-lith, confirmed 2026-05-09 per CHG-0248). ASIC registration to proceed. P1–P3: silent. P4: surfaces as product brand.
- Emails: kenmun@ ✅ gog | info@ | accounts@ | Gmail (Google Workspace). Tech: Ken+Yoda. Business: Angie+Aria.

## Infrastructure — HIVE Architecture (confirmed May 2026)
- **OC1** — Mac Mini M4 24GB — LIVE Production. PERMANENT. HARD LIMIT: No local LLM inference >~8B Q4.
- **OC2-A/B** — Mac Mini M4 Pro 48GB ×2 — INCOMING ETA 6–13 Jul 2026. A=HA Primary, B=Standby. Commission ~27 Jul. OC2-gated items wait for TRIGGER-03.
- Supporting: Tailscale mesh, NAS. Platform: OpenClaw (final).

## Agent Architecture

### Governance Tier Model (approved Ken 2026-05-08, TKT-0103)
- T0: Yoda (lead) | T1: Aria (dual-principal: CEO+Yoda) | T2: Warden (Yoda-Govern) | T3: Spark, Atlas, Thrawn, Lando, Forge, Mon Mothma, Krennic (Yoda-Manage-Passthrough); Luthen queued P2 | T4: Shield, Lex, Sage (reactive verdict-only)
- **Yoda 🟢** lead | **Aria 🔵** Business Lead (OC1→OC2 at T10, Sonnet, Angie pace) | **Spark ✨** Social/Marketing (kimi, crons: e7ebaf61/bef42235, review 316df676 2026-06-02)
- **Atlas 🏛️** (architect) Enterprise Arch, TOGAF, P1–P4 | **Thrawn** (platform-arch) Nexus/model strategy/S1–S7 | Atlas=enterprise-facing; Thrawn=platform-internal; Atlas sets constraints, Thrawn implements
- **⚠️ L-026:** Build/scripts → **Forge ONLY**. Atlas=EA assess. Thrawn=arch design. NEVER route build to Thrawn/Atlas.
- **Lando 🟡** (biz-process) BPM/BPMN | **Forge 🏗️** (infra) Infra/SRE/CI/backups | **Krennic 🔵** SRE/incidents, TKT-0074 | **Mon Mothma 🌟** (change-mgt) ADKAR
- **Gemma4 policy: background/non-interactive crons ONLY** — cold-load causes system-wide slowdown.

## Agent SOUL.md Compact Standard (NON-NEGOTIABLE)
- Hard limit: 10,000 chars. Warning: 6,000. SOUL.md = identity+traits+rules+cadences. Details in [AGENT]_RULES.md. Root cause (2026-04-30): Aria OOM. All agents ✅ within limits 2026-05-08.

## Governance Agents
- **Shield🛡️/Lex⚖️/Sage🧪** — Haiku (CHG-0230). Move to Gemma4 at TRIGGER-03.
- **Warden 🔍** Model Compliance, 15-min cron:83accf7b. State: model-drift-state.json/violations.json. Escalation → warden-escalation-pending.json → Yoda.

## Key Scripts & Infrastructure
- `auto-heal.sh` (01:00 AEST, 19 checks) | `run-diagnostics.sh` (/diagnostics, 7 phases) | `ticket.sh` (ITSM+Notion) | `changelog-append.sh` (CHG+Notion) | `gateway-config-snapshot.sh`/`gateway-restore.sh` | `cost-tracker.sh` | `audit-skill.sh` | `telegram-alert.sh` (CHG-0262)

## Operations Docs (locked)
- Journal: Notion + `memory/journal-YYYY-MM-DD.md` | Blog: Notion + `canvas/documents/ainchors-YYYY-MM-DD/index.html` (built FROM journal)
- Key docs in `docs/`: Agent_Governance_Framework_v1.md | Model3-Policy.md | Yoda_ORCHESTRATOR.md | Yoda_RUNBOOK.md

## GitHub
- gh CLI: account **kenmun-ainchors**, scopes: repo, read:org, gist (keyring).

## Nexus — Star Wars Naming (LOCKED ✅)
Nexus=platform|Holocron=AKB|Bridge=cmd-centre|Citadel=client-portal|Holonet=live-data|Beacon=monitoring|Sanctum=governance|Datapad=reporting. New: Star Wars themes, Ken approves.

## LinkedIn Posting Rule — Missed Schedule (locked 2026-05-13)
- **Rule:** If a scheduled LinkedIn post is missed, do NOT post late. Push it to the next available slot in the schedule.
- Ladder: Tue 07:30 → Wed 12:00 → Thu 07:30 → following week Tue 07:30
- If slot is already taken by the next post in sequence, skip the missed post entirely.
- Applies to all Spark content crons. No exceptions.

## Open Items
- **Notion AKB Backlog** = SSOT. DB ID (create): `34dc1829-53ff-814b-8257-d3a3bf351d44`. DB ID (query): `34dc182953ff812d8e43000b83eb0e7e`.
- LinkedIn ✅ connected. Instagram/Facebook/X not yet connected. Spark scope: IG/LI/FB/YT (CHG-0160).
- ⚠️ TKT-0121: Ken to add HF API key to Keychain (LinkedIn FLUX image gen, CHG-0254).

## Kimi Safety Net — NON-NEGOTIABLE (CHG-0270, locked 2026-05-13)
- **Rule:** Every agent MUST have 3-level fallback: Primary → Secondary → `ollama/kimi-k2.6:cloud`. No exceptions. (Cause: 2026-05-13 key expiry, platform went dark.)
- **Chains:** Yoda+Aria: `sonnet→haiku→kimi` | All others: `haiku→kimi→kimi`. Review at TRIGGER-03+OC2.
- **New agents:** kimi as final fallback. Verify chains after key rotation.

## 4-Tier Model Strategy (Target — post OC2)
- T0: systemEvent $0 | T1: Gemma4:26b local (OC2) $0 | T2: Ollama Cloud (kimi/deepseek) $100/mo | T3: Claude Sonnet FALLBACK ONLY
- Client data = T0/T1 local ONLY. NEVER cloud. DS-1 to DS-5.
- CURRENT (pre-OC2): Sonnet primary + Ollama Cloud T2. Ollama Pro: accounts@ainchors.com. PoC ✅ COMPLETE.
- gemma4:31b-cloud: experimental/archived. >=75% gate before prod. TKT-0134 review ~2026-05-18.

## Security Controls (S1–S7)
- S1: OC ≥ v2026.5.5 | S2: loopback only, 18789 never public | S3: No ClawHub on prod | S4: least-priv | S5: no hardcoded creds | S6: CHG logged/Warden | S7: NAS encrypted (post-OC2)

## CHG Trigger Rules
- T01: OC2 arrival→setup | T02: Both OC2→HA+NAS | T03: Gemma4 validated→swap Haiku | T04: OC patch→48h/7d
- T05: ✅ kimi T2 | T06: OC v4.0→P3+CrewAI | T07: First P2 client→onboarding | T08: ✅ Auto-reload <$50→$500 (CHG-0232)
- T09: Warden drift→Yoda remediates | T10: Aria→OC2 | T11: monthly model check | T12: ✅ Allowlist auto-sync (CHG-0144)
- T13: OC2+MinIO 2-sprint validated→TKT-0153 semantic memory. Deprecates MEMORY_TICKETS.md + MEMORY_DECISIONS.md.

## Tailscale (CHG-0227/228)
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

## Sprint Capacity (CHG-0241)
- Pre-OC2: 5/sprint | OC2 setup: 2–3 | Post-OC2: 5. 30% headroom. P2 target: end-Aug 2026 (contingency mid-Sep). **Daily budget cap: $150** (CHG-0268).

## Pending Tickets
→ See **MEMORY_TICKETS.md** (auto-managed, ≤8k). tickets.json seq 155. Notion AKB Backlog = SSOT.

## Anthropic API Key Rotation — SOP (locked 2026-05-13)
- Trigger: key expires/revoked (no warning). Ken: `openclaw models auth` (main only). Yoda: `python3 scripts/propagate-anthropic-key.sh` → all 12 agents. Run immediately on key rotation. History: CHG-0142 (Day 8) + Day 19 (2026-05-13).

## Key Decisions & Architecture
→ See **MEMORY_DECISIONS.md** (append-only, ≤6k).
- **BYOK + Nexus-first locked globally.** agentToAgent enabled. canvas embed: sub-agents pass full path only.
- CI Cycle A running. Cycle 2A started.
