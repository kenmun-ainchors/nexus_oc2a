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
- gemma4:31b-cloud: experimental/archived. >=75% gate before prod. TKT-0134 review ~2026-05-18.

## Security Controls (S1–S7)
- S1: OC ≥ v2026.5.5 | S2: loopback only, 18789 never public | S3: No ClawHub on prod | S4: least-priv | S5: no hardcoded creds | S6: CHG logged/Warden | S7: NAS encrypted (post-OC2)

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
- Pre-OC2: 5/sprint | OC2 setup: 2–3 | Post-OC2: 5. 30% headroom. P2 target: end-Aug 2026 (contingency mid-Sep). **Daily budget cap: $150** (CHG-0268).

## Pending Tickets
→ See **MEMORY_TICKETS.md** (auto-managed, ≤8k). tickets.json seq 162. Notion AKB Backlog = SSOT.

## Anthropic API Key Rotation — SOP
- Trigger: key expires/revoked. Ken: `openclaw models auth`. Yoda: `python3 scripts/propagate-anthropic-key.sh` → all 12 agents. Run immediately. (CHG-0142 + 2026-05-13)

## Key Decisions & Architecture
→ See **MEMORY_DECISIONS.md** (append-only, ≤6k).

## Golden Blueprint Documents — APPROVED (Day 20, 2026-05-14)
- **Technology Strategy & Roadmap v1.0** (internal): `docs/Aevlith-Technology-Strategy-Roadmap-v1.0-Internal.md` — APPROVED Ken 2026-05-14. Drive: https://drive.google.com/file/d/10oGRVyYlEPLshPNQG-sF_1-NZu3LbI5I/view
- **System Architecture Document v1.0**: `docs/Nexus-System-Architecture-v1.0.md` — APPROVED Ken 2026-05-14. Drive: https://drive.google.com/file/d/1FxEoTDzRlIMbbJHiD5XuR4Z5MNnpUAp-/view
- Superseded docs archived; decision records in MEMORY_DECISIONS.md. AGENTS.md updated.

## Nexus Platform Architecture Direction — APPROVED (Day 20, 2026-05-14)
- **Decision: Option B Phased** — Redesign data + integration layers, keep OpenClaw. Approved Ken 2026-05-14 10:28 AEST. CHG-0308.
- **Work Currency:** High→Sonnet/Haiku/Opus | Medium→kimi | Low→Gemma4/systemEvent | None→Script.
- **Phase 1 (S4-S8, ~8 Jun):** Postgres+5-tier schema, Three Work Types Rule, SoT Register, JSON→Postgres (5 files), Event Bus, Typed Contracts, PII Scanner, RAG. P2 blockers: WP1-5 by S8.
- **Phase 2 (post-P2 +2wks):** Redis, multi-tenant RLS, Holonet v0, Citadel v0.
- **Phase 3 (TRIGGER-14):** Event sourcing, WORM audit, APRA. Fires post-P2 stable.
- **KRI Dashboard:** https://www.notion.so/Nexus-Architecture-KRI-Dashboard-Option-B-Implementation-360c182953ff816a9d1dd5c104ca6cd1
- **architecture-kri-state.json** — Yoda owns live KRI updates at each sprint review.
- **Structural fix 2.3+2.4:** Risk ↓ Sprint 4 end (25 May). Fixed Sprint 6 end (~8 Jun).

## Sprint Plan (locked Day 20)
- **Sprint 4 (May 19-25):** TKT-0141, TKT-0142 (S3 carries), TKT-0165 (Three Work Types Rule), TKT-0166 (SoT Register), Cloudflare Tunnel.
- **Sprint 5:** TKT-0164 Postgres (critical path), TKT-0108 doc gen, TKT-0157, TKT-0156, TKT-0130 QBR.
- **Sprint 6:** TKT-0167 JSON migration, TKT-0168 Event Bus, TKT-0170 PII Scanner, TKT-0150 DR Playbook.
- **Sprint 7:** TKT-0169 Typed Contracts, TKT-0171 RAG Pipeline.
- Bucket C (8 tickets) parked until QBR Sprint 5. Bucket D (TKT-0114-0119) Ken action.

## LinkedIn Auth (Day 20)
- MDP approved, Advertising API. Token valid 2026-07-12. PKCE removed. Scopes: basicprofile, org_social, org_admin, ads.
- AInchors company page onboarding deferred. Trigger 05f9d2ef set.
- L-027: Post cancellation must update queue state + delete cron. Never verbal-only acknowledgement.

## Config Baseline (Day 20 — CHG-0306)
- CHG-0270 object format; jq_queries→.model.primary. Defaults primary=Haiku. Warden=Haiku. BYOK+Nexus-first global. agentToAgent enabled. Canvas: sub-agents full path.
- CI Cycle A running; Cycle 2A started.
