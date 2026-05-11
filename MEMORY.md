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
- **T0:** Lead Anchor (Yoda) — owns governance fleet-wide
- **T1:** Dual-Principal — CEO primary + Yoda tech oversight. Agent: Aria
- **T2:** Yoda-Govern — agent never acts outside Yoda approval. Agent: Warden
- **T3:** Yoda-Manage-Passthrough — default for new operational agents. Agents: Spark, Ahsoka, Atlas, Thrawn, Lando, Mon Mothma, Krennic
- **T4:** Triad Service Agent — reactive verdict-only. Agents: Shield, Lex, Sage
- **New subagent rule:** Yoda must propose all new agents before build. Ken confirms. No exceptions.
- **Squad Model (future T5+):** Define before any dev squad work. TKT-0107. Framework: docs/Agent_Governance_Framework_v1.md

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
- Sizes: Yoda 3,527 ✅ | Aria 4,659 ✅ | Shield 3,857 ✅ | Spark 4,332 ✅ | Atlas 2,850 ✅ | Thrawn 3,152 ✅ | Lando 2,737 ✅ | Mon Mothma 2,936 ✅ | Sage 1,830 ✅ | Lex 2,322 ✅ | Governance 1,334 ✅

## Governance Agents
- **Shield 🛡️** (security) | **Lex ⚖️** (legal) | **Sage 🧪** (qa) — Haiku (CHG-0230). Move to Gemma4 at TRIGGER-03.
- **Warden 🔍** = Model Compliance Officer. 15-min checks, 9 agents. Cron: 83accf7b (haiku). State: model-drift-state.json / violations.json. Escalation: warden-escalation-pending.json → Yoda remediates.

## Key Scripts & Infrastructure
- `scripts/auto-heal.sh` — nightly 01:00 AEST, 18 checks, auto-fixes, files Notion US for Ken action items.
- `scripts/run-diagnostics.sh` — on-demand /diagnostics, 7 phases.
- `scripts/ticket.sh` — ITSM (TKT-NNNN), auto-syncs to Notion AKB Backlog.
- `scripts/changelog-append.sh` — CHG-NNNN in memory/CHANGELOG.md, syncs to Notion.
- `scripts/gateway-config-snapshot.sh` + `scripts/gateway-restore.sh` — config snapshot/restore SOP.
- `scripts/cost-tracker.sh` | `scripts/audit-skill.sh` | `scripts/telegram-alert.sh` (API-independent Bot HTTP, CHG-0262).
- `state/critical-config-baseline.json` — anti-drift guard (7 configs). `state/chg-triggers.json` — 12 triggers. `state/skill-registry.json` — 63 SKILL.md files.

## Operations Docs (locked)
- Journal: Notion + `memory/journal-YYYY-MM-DD.md` (verbatim Ken prompts, Yoda voice, private)
- Blog: Notion + `canvas/documents/ainchors-YYYY-MM-DD/index.html` (Ken first-person, built FROM journal)
- Key docs (all in docs/): Agent_Governance_Framework_v1.md | Model3-Policy.md | Strategy_to_Backlog_Pipeline_v0.1.md | Skill-Installation-Policy-v1.0.md | Yoda_ORCHESTRATOR.md | Yoda_RUNBOOK.md

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

## TRIGGER-12 — Allowlist Auto-Sync (live, CHG-0144)
- Scripts: allowlist-sync.sh + allowlist-detect.sh. Cron: 6a059e9e (30 min, haiku). State: allowlist-sync-state.json.
- Eligibility: main/Aria=all cloud; Spark=kimi+pro; Sage=kimi+flash; Warden=flash only; Shield/Lex=no cloud.

## 4-Tier Model Strategy (Target — post OC2)
- T0: No LLM (systemEvent) — $0. T1: Gemma4:26b local (OC2) — $0 client workloads. T2: Ollama Cloud (kimi/deepseek) — $100/mo flat. T3: Claude Sonnet — FALLBACK ONLY.
- Data sovereignty: DS-1 to DS-5. Client data = T0/T1 local ONLY. NEVER cloud.
- CURRENT (pre-OC2): Sonnet primary + Ollama Cloud T2 active. Ollama Pro: accounts@ainchors.com. PoC: ✅ COMPLETE (TRIGGER-05).
- gemma4:31b-cloud: experimental/archived (CHG-0249-0251). >=75% pass rate gate required before production routing. TKT-0134 review ~2026-05-18.

## Security Controls (S1–S7)
- S1: OC ≥ v2026.5.5 (current; v2026.5.7 available — routine, no CVE). S2: Gateway loopback only, port 18789 never public. S3: No ClawHub skills on prod. S4: Least privilege per agent. S5: No hardcoded creds, Keychain+env only. S6: All CHG logged, Warden compliance. S7: NAS encrypted (post-OC2).

## CHG Trigger Rules
- TRIGGER-01: OC2 arrival → 10-step setup. TRIGGER-02: Both OC2 live → HA + NAS.
- TRIGGER-03: Gemma4 validated → governance Haiku → Gemma4:26b. TRIGGER-04: OC security patch → 48h/7d.
- TRIGGER-05: ✅ FIRED — kimi T2 active. TRIGGER-06: OC v4.0 → P3 gate + CrewAI eval.
- TRIGGER-07: First P2 client → onboarding. TRIGGER-08: ✅ FIRED — Auto-reload: <$50 → $500. Thresholds: T1=$60, T2=$55, T3=$15 (CHG-0232).
- TRIGGER-09: Warden drift → Yoda remediates within 1 heartbeat. TRIGGER-10: Business ready → Aria to OC2.
- TRIGGER-11: glm-5.1 no-think → monthly check. TRIGGER-12: ✅ Allowlist auto-sync live (CHG-0144).

## Tailscale Config (CHG-0227/228)
- Serve enabled on OC1. `allowTailscale: true`. URL: `https://ainchorss-mac-mini.tail5e2567.ts.net`. S2 compliant.
- Windows webchat 1006 fix (2026-05-11): `tailscale serve --https=443 --bg http://localhost:18789`.

## Sprint Capacity Model (CHG-0241)
- Pre-OC2: 5 items/sprint | OC2 setup: 2–3 | Post-OC2: 5. 30% headroom buffer. P2 target: end-Aug 2026. Contingency: mid-Sep.
- `/sprint` = on-demand burndown. **Main agent daily budget cap:** $150 (CHG-0268).

## Pending Tickets

**Critical/High (active):**
- **TKT-0124:** MinIO on OC1 — ✅ LIVE 2026-05-11. Sprint 3 committed. CHG-0265.
- ✅ Day 15–17 completions: TKT-0125 (Strategy Pipeline), TKT-0105/106 (Model3-Policy), TKT-0108 (Doc Gen), TKT-0113 (Telegram fallback), TKT-0112/140 (obs dedup), TKT-0121 (HF image), TKT-0123/126 (LinkedIn fix), TKT-0144 (CI token audit) — CHG refs in CHANGELOG.md

**Infrastructure (Aevlith/OC2):**
- TKT-0114: AInchors–Aevlith partnership — HIGH | GATE for 0115-0117
- TKT-0115: Register Aevlith ASIC — HIGH | blocked on 0114
- TKT-0116: aevlith.ai domain — HIGH | blocked on 0115
- TKT-0117: aevlith.com.au — MEDIUM | blocked on 0115
- TKT-0118: aevlith.com — MEDIUM | parallel
- TKT-0119: IP Australia trademark — MEDIUM | blocked on 0114
- TKT-0120: RustDesk self-hosted OC1 — HIGH

**Business Stream (P2):**
- TKT-0127: Agentic Marketing Org Design — HIGH | dep: TKT-0124
- TKT-0128: Aria marketing mandate + Brand Code (P1) — in-progress | MinIO-dependent. CHG-0263.
- TKT-0129: Luthen Marketing Agent (P2) — MEDIUM | blocked on 0124+0128

**Process & Docs:**
- TKT-0107: Squad Model (T5+) — MEDIUM | GATE before squad work
- TKT-0109: Cassian Andor (Agile PM) — MEDIUM | Jul QBR
- TKT-0110: Process Documentation Framework — in-progress | Lando owns
- TKT-0111: Angie Agile + Nexus Working Guide — in-progress

**EA & Product Strategy:**
- TKT-0130: QBR Fleet Review — HIGH | Jan/Apr/Jul/Oct. First: Jul 2026.
- TKT-0131: Review task log — MEDIUM. TKT-0132: Review cost + ROI log — MEDIUM.
- TKT-0133: Observability Strategy (OTel vs Dynatrace) — MEDIUM | Atlas owns
- TKT-0134: Model strategy review — MEDIUM | auto-fire ~2026-05-18
- TKT-0135: AInchors Sandbox — HIGH | Sprint 3 committed. Forge builds. CHG-0265.
- TKT-0136: Consulting Playbook — HIGH. TKT-0137: Policy Register (POL-001+) — HIGH | Lex.
- TKT-0138: Business Jumpstart pathway — HIGH | Ahsoka owns
- TKT-0139: Consulting Product Portfolio — HIGH

**Security & Governance:**
- TKT-0141: CLI-Anything supply chain audit — in-progress | HIGH
- TKT-0142: SKILL.md poisoning review — in-progress | HIGH | 63 skills audited clean
- TKT-0143: CLI-Anything EA assessment — MEDIUM | CONDITIONAL ADOPT (P2)

tickets.json seq 152. Notion AKB Backlog = SSOT.

## Key Decisions & Architecture (locked)
- **P1–P4:** P1=internal | P2=SaaS individual agents | P3=commercial tier label | P4=Enterprise/FSI. Licensed product DROPPED from P3.
- **P2:** RLS from day one. Multi-tenant (tenant_id, RLS, shared state). Client model: Gemma4 local only. BYOK = opt-in (CHG-0236).
- **Anthropic DPA:** Claude API blocked for client data (APRA CPG 235 / Privacy Act APP 11). Gemma4 local default.
- **BYOK + Nexus-first locked globally.** agentToAgent enabled. canvas embed: sub-agents pass full path only.
- Agile Framework v1.0 (CHG-0222). Sprint 1 started 2026-05-07. P2 target: end-Aug 2026. Aevlith inc. hard gate: end-May 2026.
- CI Cycle A running. Cycle 2A started.
- **INC-20260511-001 (22:03 AEST Day 17):** Thrawn wrote directly to openclaw.json → array schema break → ~2 min gateway crash. Fix: `openclaw doctor --fix`. Rule locked: Thrawn/Atlas NEVER write files. Config via gateway tool only.
- **INC-20260509-001:** 26h API degradation (balance $0). Auto-reload live post-recovery.

## File Access
- **MinIO live (TKT-0124 ✅ 2026-05-11):** Agent object store on OC1. Tailscale URL: `https://ainchorss-mac-mini.tail5e2567.ts.net`. Presigned URLs via `scripts/minio-upload.sh`. Buckets: agent-memory, generated-media, workspace-assets, brand-code.
- **Google Drive (human layer):** "AInchors — Yoda Working Files" | Root: `1EyLi8JCvxwixhpBdRwP0PwdZokrg78Jl` | State: `state/gdrive-folders.json`
- **File access rule:** Agent blobs → MinIO. Human docs → Drive. P1 permanent until P2 S3 migration.
