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
- **Aevlith Technologies Pty Ltd** — Technology holding entity, owns Nexus platform. AInchors = market-facing brand; Aevlith = invisible platform company. Domain: aevlith.ai (AYV-lith). Name locked 2026-05-09. Globally clean. ASIC registration + domain = this week. TKT-0069. P1–P3: silent. P4: surfaces as product brand.
- Emails: kenmun@ ✅ gog | info@ | accounts@ | Gmail (Google Workspace). Tech: Ken+Yoda. Business: Angie+Aria.

## Infrastructure — HIVE Architecture (confirmed May 2026)
- **OC1** — Mac Mini M4 24GB — LIVE Production. PERMANENT. HARD LIMIT: No local LLM inference >~8B Q4.
- **OC2-A** — Mac Mini M4 Pro 48GB — INCOMING ETA 6–13 Jul 2026. HA Primary, local inference primary.
- **OC2-B** — Mac Mini M4 Pro 48GB — INCOMING ETA 6–13 Jul 2026. HA Secondary, hot standby.
- OC2 commissioned ~27 Jul 2026. OC2-gated items wait for TRIGGER-03.
- Main disk fine (21%). Supporting: Tailscale mesh, NAS. Obsidian RETIRED 2026-05-04. Platform: OpenClaw (final).

## Agent Architecture

### Governance Tier Model (approved Ken 2026-05-08, TKT-0103)
- T0: Yoda (lead) | T1: Aria (dual-principal: CEO+Yoda) | T2: Warden (Yoda-Govern) | T3: Spark, Ahsoka, Atlas, Thrawn, Lando, Mon Mothma, Krennic (Yoda-Manage-Passthrough) | T4: Shield, Lex, Sage (reactive verdict-only)
- **New subagent rule:** Yoda must propose all new agents before build. Ken confirms. No exceptions.
- Squad Model (T5+): TKT-0107. Framework: docs/Agent_Governance_Framework_v1.md

- **Yoda 🟢** = lead agent (technical stream, oversees all)
- **Aria 🔵** = Business Lead Agent (OC1 → OC2 at TRIGGER-10). Model: Sonnet. All business stream decisions sit with Angie. Aria follows Angie's pace — no pushing, no chasing.
- **Spark ✨** = Social & Digital Marketing (kimi-k2.6:cloud, workspace-social/). Ken approves personal; Angie approves brand. Crons: e7ebaf61 (Tue+Thu 7:30am) | bef42235 (Wed 12pm) | review: 316df676 (2026-06-02).
- **Atlas 🏛️** (agentId: architect) = Enterprise Architect. TOGAF, P1–P4 roadmap.
- **Thrawn** (agentId: platform-arch) = AI Platform Architect, Nexus Core. Orchestration, model strategy, S1–S7.
- **Atlas vs Thrawn Routing (locked):** Atlas = enterprise-facing (TOGAF, P1–P4, client/market). Thrawn = platform-internal (Nexus, model routing, governance, ITSM). Atlas sets constraints, Thrawn implements. Yoda: advise correct assignment if Ken routes wrong.
- **⚠️ Routing rule (L-026):** Build/implement/scripts → **Forge ONLY**. Atlas=EA assess. Thrawn=arch design. NEVER route build work to Thrawn or Atlas.
- **Lando 🟡** = BPM Agent (agentId: biz-process, workspace-bpm/). BPM/BPMN, Lean, Six Sigma.
- **Forge 🏗️** (agentId: infra) = Infra/SRE Agent. CI, model PoC, OC1/OC2 health, backups, MinIO, NAS.
- **Krennic 🔵** = SRE Agent. Incidents, SLO/error budget. Build before TRIGGER-07. TKT-0074.
- **Mon Mothma 🌟** = DTCM Agent (agentId: change-mgt, workspace-dtcm/). ADKAR, Kotter, Prosci.
- **Gemma4 policy: background/non-interactive crons ONLY** — cold-load causes system-wide slowdown.

## Agent SOUL.md Compact Standard (NON-NEGOTIABLE)
- Hard limit: 10,000 chars. Warning: 6,000. SOUL.md = identity+traits+rules+cadences. Details in [AGENT]_RULES.md.
- Why: Aria 17,393 chars → silent truncation → wrong Telegram targets → gateway OOM (2026-04-30).
- All agents ✅ within limits as of 2026-05-08.

## Governance Agents
- **Shield 🛡️** (security) | **Lex ⚖️** (legal) | **Sage 🧪** (qa) — Haiku (CHG-0230). Move to Gemma4 at TRIGGER-03.
- **Warden 🔍** = Model Compliance Officer. 15-min checks, 9 agents. Cron: 83accf7b (haiku). State: model-drift-state.json / violations.json. Escalation: warden-escalation-pending.json → Yoda remediates.

## Key Scripts & Infrastructure
- `auto-heal.sh` — nightly 01:00 AEST, 19 checks, auto-fixes, files Notion US for needs-Ken items.
- `run-diagnostics.sh` — on-demand /diagnostics, 7 phases. `ticket.sh` — ITSM (TKT-NNNN), Notion sync.
- `changelog-append.sh` — CHG-NNNN log + Notion sync. `gateway-config-snapshot.sh` / `gateway-restore.sh` — config SOP.
- `cost-tracker.sh` | `audit-skill.sh` | `telegram-alert.sh` (API-independent Bot HTTP, CHG-0262).

## Operations Docs (locked)
- Journal: Notion + `memory/journal-YYYY-MM-DD.md` (verbatim Ken prompts, Yoda voice, private)
- Blog: Notion + `canvas/documents/ainchors-YYYY-MM-DD/index.html` (Ken first-person, built FROM journal)
- Key docs (docs/): Agent_Governance_Framework_v1.md | Model3-Policy.md | Strategy_to_Backlog_Pipeline_v0.1.md | Skill-Installation-Policy-v1.0.md | Yoda_ORCHESTRATOR.md | Yoda_RUNBOOK.md

## GitHub
- gh CLI authenticated: account **kenmun-ainchors**, scopes: repo, read:org, gist (token in keyring).

## Nexus — Star Wars Naming (LOCKED ✅ 2026-05-03)
Nexus=platform | Holocron=AKB/KB | The Bridge=command centre | The Citadel=client portal | Holonet=live data | Beacon=monitoring | The Sanctum=governance vault | Datapad=reporting
Rule: New modules use Star Wars themes. Ken approves. All above final.

## Open Items
- **Notion AKB Backlog** = SSOT. DB ID (create): `34dc1829-53ff-814b-8257-d3a3bf351d44`. DB ID (query): `34dc182953ff812d8e43000b83eb0e7e`.
- LinkedIn ✅ connected. Instagram/Facebook/X not yet connected. Spark scope: IG/LI/FB/YT (CHG-0160).
- ⚠️ **TKT-0121 action pending:** Ken to add HF API key to Keychain (LinkedIn FLUX image gen).
- Agent team design + build: Needs Atlas + Thrawn input. TKT-0068 open.

## 4-Tier Model Strategy (Target — post OC2)
- T0: No LLM (systemEvent) — $0. T1: Gemma4:26b local (OC2) — $0 client workloads. T2: Ollama Cloud (kimi/deepseek) — $100/mo flat. T3: Claude Sonnet — FALLBACK ONLY.
- Data sovereignty: DS-1 to DS-5. Client data = T0/T1 local ONLY. NEVER cloud.
- CURRENT (pre-OC2): Sonnet primary + Ollama Cloud T2 active. Ollama Pro: accounts@ainchors.com. PoC: ✅ COMPLETE.
- gemma4:31b-cloud: experimental/archived. >=75% pass rate gate before prod. TKT-0134 review ~2026-05-18.

## Security Controls (S1–S7)
- S1: OC ≥ v2026.5.5 (current; v2026.5.7 available — routine, no CVE). S2: Gateway loopback only, port 18789 never public. S3: No ClawHub skills on prod. S4: Least privilege per agent. S5: No hardcoded creds, Keychain+env only. S6: All CHG logged, Warden compliance. S7: NAS encrypted (post-OC2).

## CHG Trigger Rules
- T01: OC2 arrival→setup | T02: Both OC2→HA+NAS | T03: Gemma4 validated→swap Haiku | T04: OC patch→48h/7d
- T05: ✅ kimi T2 active | T06: OC v4.0→P3+CrewAI | T07: First P2 client→onboarding | T08: ✅ Auto-reload <$50→$500 (T1=$60/T2=$55/T3=$15, CHG-0232)
- T09: Warden drift→Yoda remediates 1 heartbeat | T10: Aria→OC2 | T11: monthly model check | T12: ✅ Allowlist auto-sync live (CHG-0144)
- T13: OC2+MinIO 2-sprint validated→TKT-0153 semantic memory. Deprecates MEMORY_TICKETS.md + MEMORY_DECISIONS.md.

## Tailscale Config (CHG-0227/228)
- Serve on OC1. `allowTailscale: true`. URL: `https://ainchorss-mac-mini.tail5e2567.ts.net`. S2 compliant. Windows 1006 fix: `tailscale serve --https=443 --bg http://localhost:18789`.

## Sprint Capacity Model (CHG-0241)
- Pre-OC2: 5 items/sprint | OC2 setup: 2–3 | Post-OC2: 5. 30% headroom buffer. P2 target: end-Aug 2026. Contingency: mid-Sep.
- `/sprint` = on-demand burndown. **Main agent daily budget cap:** $150 (CHG-0268).

## Pending Tickets
→ See **MEMORY_TICKETS.md** (auto-managed, ≤8k). tickets.json seq 153. Notion AKB Backlog = SSOT.
- ⚠️ **TKT-0121 action pending:** Ken to add HF API key to Keychain (LinkedIn FLUX image gen).

## Key Decisions & Architecture
→ See **MEMORY_DECISIONS.md** (append-only, ≤6k).
- **BYOK + Nexus-first locked globally.** agentToAgent enabled. canvas embed: sub-agents pass full path only.
- CI Cycle A running. Cycle 2A started.
