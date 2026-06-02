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
- MEMORY.md: hard limit 15,000 (warn 12,000). TKT-0310/CHG-0454. Archive overflow at 12K, trim to 10K.

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
- gemma4:31b-cloud: REMOVED from all agent allowlists 2026-05-09 (CHG-0250). No longer experimental—deprecated. TKT-0134 deferred post-OC2 commissioning.

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
- Defaults primary=Haiku, Warden=Haiku. BYOK+Nexus-first.
- CI Cycle A/B decommissioned 2026-05-24 (CHG-0428). Replaced by Warden 15-min drift monitoring + monthly model strategy review.

## kimi Policy — DECOMMISSIONED 2026-05-26
DeepSeek = permanent primary. kimi = fallback only. Full history: `memory/MEMORY-archive-2026-05-27.md`.

- 2026-05-25: TKT-0295 (PG Audit) parked due to Tier 3 budget breach. Reports from Atlas and Thrawn are delivered but pending final review. Resume tomorrow with DeepSeek.
---

## Day 32 End-of-Day (2026-05-26)

**TKT-0295 PG Audit chain:** ALL 7 tickets closed. PG now has 18 state tables. Cron payloads migrated to PG reads. JSONB schema contract published. sc_read wrappers live.

**TKT-0307 Agent RULES.md Foundation Repair:** 10 of 12 agents now have RULES.md accessible via symlinks. Shield + Warden RULES.md created (3.7KB + 3.8KB). Agent-rules-audit.sh + auto-heal CHECK 14 for permanent prevention. RULES.md commissioning checklist (5 gates) added. L-044 logged.

**TKT-0308 Agent Workspace Separation:** Forge → workspace-infra, Ahsoka → workspace-ahsoka. Luthen 🔍 first activation from spec v1.0 (workspace-luthen). Spark ✨ registered in agents.list (was ephemeral). Krennic parked until OC2. 14 agents in openclaw.json, 14/14 RULES.md, 14/14 model-policy.

**TKT-0329 Thrawn Assessment — Workspace Sandbox vs Delivery Gap:** Raised 2026-05-30. TKT-0308 introduced workspace separation but didn't define cross-workspace delivery paths. Forge built TKT-0328 script in workspace-infra/ but couldn't deliver to workspace/scripts/ — Yoda bridged manually. Thrawn assigned: map all cross-workspace deps, evaluate symlink bridge + delivery-map.json + auto-heal CHECK 16. Sprint 6 locked.

**TKT-0297 PG→Notion Sync Redesign:** Thrawn approved architecture. Forge built pg-to-notion-sync.sh (idempotent, file-locked, timestamp-filtered). ticket.sh reads PG primary via db.sh. Closed.

**TKT-0309 Context Retention — TQP Execution Gate:** Atlas assessed 4-layer stack → "hydration void" identified. Thrawn designed Option E (TQP as gate, not hook). Ken approved. Phase 1 built: 5 new schema columns + sc_persist_atom + sc_resume_context. Phase 2 (Yoda inline adoption) parked for tomorrow.

**Platform state:** 14 agents registered. 18 PG tables. 235 tickets. TOM operational. Sprint 5 planning, not committed. LinkedIn paused until Sunday. 2 criticals open: TKT-0296 (monitoring), TKT-0309 (Phase 2 pending).

---

## Day 33 End-of-Day (2026-05-27) — Sprint 5 Cleanup + Sprint 6 Queued

**TKT-0309 Phase 2 — COMPLETE:** 5 atoms delivered (contract, tqp-yoda.sh wrapper, AGENTS.md integration, self-test, DoD gate). 5 bugs found+fixed during implementation. TQP gate now operational. TKT-0309 closed. Aria + Global phases raised as TKT-0318 + TKT-0319.

**TKT-0296 Journal Writer — COMPLETE:** EOD finalizer cron simplified. HEARTBEAT.md stale refs fixed. 2-day observation passed. Journal fully inline via journal-append.sh.

**TKT-0313 2-Pass Dispatch — MERGED into TKT-0317:** Ken corrected scope: discipline is platform-wide, NOT Yoda-only. "No executor receives undiscovered work." 4 sub-tickets raised (TKT-0321-0324).

**TKT-0317 Epic Groomed:** Atlas delivered 20KB assessment via 2-pass execution (discovery JSON → assessment doc in 3m38s). Findings: 92% rule duplication, Yoda 123.8KB context, 5 over-privileges, 16 proposed tickets. Sprint 6 first item.

**Sprint 5 Cleanup:** 9 high tickets processed. 5 folded into TKT-0317 (0178, 0182, 0188, 0228, 0230). 3 deferred to P2 (0128, 0137, 0318). TKT-0305 completed. Open critical+high: 17 → 8 (53% reduction).

**CHGs:** CHG-0430 through CHG-0442 (13 today)

---

## Day 36 End-of-Day (2026-05-29) — Sprint 5 Closed + Platform Separation Approved

**Sprint 5 Review (Fri May 29):** 7 committed closed, 11 bonus delivered, 18 items total. 4 carried to S6 (TKT-0268, TKT-0269, TKT-0137, TKT-0275). TKT-0236 confirmed closed (was incorrectly listed as not started). TKT-0241 blocked (Claude Restore). TKT-0238 folded into TKT-0327. TKT-0313 merged into TKT-0317. 15 CHGs (0430-0444). Open critical+high: 17→8 (53% reduction).

**Platform Separation — APPROVED:** OC1 repurposed as standalone business node (Aria + 6 agents). OC2-A/B remains tech HIVE HA pair. No cross-node. Ken approved C1 (second license), C2 (separate Ollama sub), C3 (new Google Workspace for tech). All 3 risks accepted. Atlas option paper + Thrawn feasibility delivered to Drive. Phase 0 prep can start now.

**Budget Recalibration:** Monthly cap A$500→$150 USD (effective Jun 1). Ollama Cloud Max $100/mo fixed + $50 Claude buffer. Model rates locked (subscription-aligned + market-equivalent). TKT-0325 closed.

**Infra fixes:** BASE1 restore runbook + NAS backup delivered. 3 cron prompts patched (tilde-path bug, safe-path.sh guard). Auto-heal confirmed running (PG write gap folded into TKT-0327). Backup obs false positives fixed (regex).

**Sprint 6 (2026-06-02 to 2026-06-08) — IN PROGRESS:** 3/14 done (TKT-0268, TKT-0269, TKT-0310). Remaining: TKT-0317 (Context Epic), TKT-0293 (Regression), TKT-0321 (Yoda Dispatch), TKT-0322 (Routing Matrix), TKT-0326 (NAS Writable), TKT-0327 (Tilde-Path), TKT-0318 (Aria TQP), TKT-0319 (Global TQP), TKT-0137 (Policy Register), + Platform Separation Phase 0 prep.

**TKT-0310:** APPROVED Ken 2026-06-02 18:44. Thrawn option paper → docs/deliverables/TKT-0310-Platform-Constraint-Enforcement-Option-Paper-v1.0.md. GDrive: https://drive.google.com/file/d/1FaodSS0GeV8iaYEL-PFhXmO96gUVy0Nm

**Sprint 7 (2026-06-02 to 2026-06-08) — COMMITTED — Platform Constraint Enforcement:** 5 tickets, all Forge. Parent: TKT-0310. Seq: P0 (safe-path.sh, XS), P1-A (context budget guards, M), P1-B (file size enforcement, M), P1-C (cron timeout auto-scaling, M), P2 (hardening + dashboard, M). P3 (prompt truncation) = backlog, trigger-gated. Sprint file: state/sprint-7.json.

**Platform state:** 14 agents. 32 PG tables. 251+ tickets. TQP gate live. Journal inline writes stable. Sprint 5 closed. Sprint 6 queued. Platform Separation go.

**OpenClaw:** v2026.5.27 (upgraded from 5.12, 2026-05-29). 59 crons, all integrations healthy. Config slimmed (crons in Gateway internal state). CHG-0445.
