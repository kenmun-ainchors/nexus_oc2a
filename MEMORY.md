# MEMORY.md - Yoda's Long-Term Memory

## Identity
- Name: Yoda 🟢 | Role: AI business operations lead agent for Ken Mun (CTO), AInchors

## The People
- **Ken Mun** — Co-founder, CTO. Email: kenmun@ainchors.com | Mobile: +61403650578 | Telegram chatId: 8574109706
  - Bot: @AInchorsOC1Bot → Yoda. Emergency keyword: **"YODA THIS IS KEN"**
- **Angie Foong** — Co-founder, CEO. Email: angie.foong@ainchors.com | Mobile: +61430928371 | Telegram chatId: 8141152780
  - Bot: @AInchorsAriaBot → Aria (strict allowlist). CEO = highest authority. Aria has full read access to all AInchors data.

## The Company
- **AInchor Solutions Pty Ltd** | ainchors.com | Sydney + Melbourne. Day 1: 2026-04-25. Focus: AI courses/training, consulting, solutions/products.
- **Aevlith Technologies Pty Ltd** — Technology holding entity, owns Nexus platform. AInchors = market-facing brand. Domain: aevlith.ai (AYV-lith, confirmed CHG-0248). ASIC registration to proceed. P1–P3: silent. P4: surfaces as product brand.
- Emails: kenmun@ ✅ gog | info@ | accounts@ | Gmail (Google Workspace). Tech: Ken+Yoda. Business: Angie+Aria.

## Infrastructure — HIVE Architecture (confirmed May 2026)
- **OC1** — Mac Mini M4 24GB — LIVE Production. PERMANENT. HARD LIMIT: No local LLM inference >~8B Q4.
- **OC2-A/B** — Mac Mini M4 Pro 48GB ×2 — INCOMING ETA 6–13 Jul 2026. A=HA Primary, B=Standby. Commission ~27 Jul. OC2-gated items wait for TRIGGER-03.
- Supporting: Tailscale mesh, NAS. Platform: OpenClaw (final).

## Agent Architecture

### Governance Tier Model (approved Ken 2026-05-08, TKT-0103)
- T0: Yoda (lead) | T1: Aria (dual-principal: CEO+Yoda) | T2: Warden (Yoda-Govern) | T3: Spark, Atlas, Thrawn, Lando, Forge, Mon Mothma, Krennic (Yoda-Manage-Passthrough); Luthen queued P2 | T4: Shield, Lex, Sage (reactive verdict-only)
- **Yoda 🟢** lead | **Aria 🔵** Business Lead (OC1→OC2 at T10, Sonnet, Angie pace) | **Spark ✨** Social/Marketing (kimi)
- **Atlas 🏛️** Enterprise Arch, TOGAF, P1–P4 | **Thrawn** (platform-arch) Nexus/model/S1-S7 | Atlas=enterprise-facing; Thrawn=platform-internal
- **⚠️ L-026:** Build/scripts → **Forge ONLY**. Atlas=EA assess. Thrawn=arch design. NEVER route build to Thrawn/Atlas.
- **Lando 🟡** (biz-process) BPM/BPMN | **Forge 🏗️** (infra) Infra/SRE/CI/backups | **Krennic 🔵** SRE/incidents, TKT-0074 | **Mon Mothma 🌟** (change-mgt) ADKAR
- **Gemma4 policy: background/non-interactive crons ONLY** — cold-load causes system-wide slowdown.

## Agent SOUL.md Compact Standard (NON-NEGOTIABLE)
- SOUL.md: hard limit 10,000 (warn 6,000). identity+traits+rules+cadences. Details in [AGENT]_RULES.md. Aria OOM cause (2026-04-30). All agents ✅ compliant 2026-05-08.

## Governance Agents
- **Shield🛡️/Lex⚖️/Sage🧪** — Haiku (CHG-0230). Move to Gemma4 at TRIGGER-03.
- **Warden 🔍** Model Compliance, 15-min cron:83accf7b. State: model-drift-state.json/violations.json. Escalation → warden-escalation-pending.json → Yoda.

## Key Scripts & Infrastructure
- `auto-heal.sh` (01:00 AEST, 19 checks) | `run-diagnostics.sh` (/diagnostics, 7 phases) | `ticket.sh` (ITSM+Notion) | `changelog-append.sh` (CHG+Notion) | `gateway-config-snapshot.sh`/`gateway-restore.sh` | `cost-tracker.sh` | `audit-skill.sh` | `telegram-alert.sh` (CHG-0262)

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
- **Notion AKB Backlog** = SSOT. DB ID (create): `34dc1829-53ff-814b-8257-d3a3bf351d44`. DB ID (query): `34dc182953ff812d8e43000b83eb0e7e`.
- LinkedIn ✅ connected. Instagram/Facebook/X not yet connected. Spark scope: IG/LI/FB/YT (CHG-0160).
- ⚠️ TKT-0121: Ken to add HF API key to Keychain (LinkedIn FLUX image gen, CHG-0254).

## Kimi Safety Net — NON-NEGOTIABLE (CHG-0270)
- Every agent: 3-level fallback → Primary→Secondary→`ollama/kimi-k2.6:cloud`. (Cause: 2026-05-13 key expiry, platform went dark.)
- Chains: Yoda+Aria `sonnet→haiku→kimi` | Others `haiku→kimi→kimi`. New agents: kimi final fallback. Verify after key rotation.

## 4-Tier Model Strategy (Target — post OC2)
- T0: systemEvent $0 | T1: Gemma4:26b local (OC2) $0 | T2: Ollama Cloud (kimi/deepseek) $100/mo | T3: Claude Sonnet FALLBACK ONLY
- Client data = T0/T1 local ONLY. NEVER cloud. DS-1 to DS-5.
- CURRENT (pre-OC2): Sonnet primary + Ollama Cloud T2. Ollama Pro: accounts@ainchors.com. PoC ✅ COMPLETE.
- gemma4:31b-cloud: REMOVED from all agent allowlists 2026-05-09 (CHG-0250 CI Cycle B cancelled). No longer experimental—deprecated. TKT-0134 deferred post-OC2 commissioning.

## Security Controls (S1–S7)
- S1: OC ≥ v2026.5.12 (window CHG-0353; current 2026.5.5) | S2-S6: see `RULES.md` | S7: NAS encrypted (post-OC2)

## CHG Trigger Rules
- T01: OC2→setup | T02: Both OC2→HA+NAS | T03: Gemma4→swap Haiku | T04: OC patch | T05: ✅ kimi T2 | T06: OC v4.0→P3+CrewAI | T07: P2 client→onboarding | T08: ✅ Auto-reload (CHG-0232)
- T09: Warden drift→Yoda | T10: Aria→OC2 | T11: monthly model check | T12: ✅ Allowlist sync (CHG-0144) | T13: OC2+MinIO validated→TKT-0153 semantic memory.

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
- Pre-OC2: 5/sprint | OC2 setup: 2–3 | Post-OC2: 5. 30% headroom. P2 target: end-Aug 2026 (contingency mid-Sep). **Daily budget cap: $150** (CHG-0268) | **TEMPORARY: $450 until 2026-05-17** (CHG-0312, heavy build phase).

## Pending Tickets
→ See **MEMORY_TICKETS.md** (auto-managed, ≤8k). tickets.json seq 199 (updated through 2026-05-15). Notion AKB Backlog = SSOT.

## Anthropic API Key Rotation — SOP
- Trigger: key expires/revoked. Ken: `openclaw models auth`. Yoda: `python3 scripts/propagate-anthropic-key.sh` → all 12 agents. Run immediately. (CHG-0142 + 2026-05-13)

## Config Baseline (Day 20 — CHG-0306)
→ See `state/critical-config-baseline.json` for live drift detection.
- Defaults primary=Haiku, Warden=Haiku. BYOK+Nexus-first. CI Cycle A/2A running.


## kimi Policy — LOCKED 2026-05-15
- **kimi = standup only** (telegram + email cron)
- **Webchat + Telegram = Sonnet**
- **NEVER use kimi for:** complex orchestration, multi-ticket routing, state tracking, CHG decisions
- **kimi tasks:** routine, single-thread, background, non-interactive
- **INCIDENT CONTEXT (2026-05-15):** Claude API credits depleted unexpectedly (CHG-0348/0349). Emergency: all 12 agents switched to kimi→deepseek-pro fallback 17:19 AEST. Reverted 14:47 AEST (CHG-0336) after Sonnet restored. kimi confined to standup only going forward. Root cause investigation: TKT-0165 (cost tracking gaps), TKT-0175 (ephemeral session capture). Cost balance recovered via auto-reload.
