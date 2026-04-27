# AInchors Change Log
_Established: 2026-04-27 | Owner: Yoda 🟢 | Append-only, reverse-chronological_

This log captures **every change** Yoda makes to AInchors infrastructure, config, scripts, agents, or operating rules. Every change vector — Ken-prompted, auto-heal, incident-recovery, scheduled — must call `scripts/changelog-append.sh`.

**Schema:**

```
## YYYY-MM-DD HH:MM AEST — [CHG-NNNN] One-line title
**Type:** config | script | cron | rule | agent | infra | data | doc
**Source:** ken-prompt | auto-heal | incident-recovery | scheduled | manual
**Trigger:** what caused this change (incident ID, US ID, Ken request, scan finding)
**What changed:** specific files/jobs/values (old → new)
**Why:** rationale
**Verification:** what was tested, what passed
**Rollback:** how to undo
**Linked:** US-NN, INC-NN, decisions.md
```

---

## 2026-04-27 06:46 AEST — [CHG-0007] Lock journal + blog format distinction
**Type:** rule + doc
**Source:** ken-prompt
**Trigger:** Ken's review of Day 2 journal redo; established Journal vs Blog as two distinct artefacts
**What changed:**
- Created `~/Documents/AInchors/Operations/JournalFormat.md` (LOCKED format spec)
- Created `~/Documents/AInchors/Operations/BlogFormat.md` (LOCKED format spec, NEW)
- Updated `RULES.md` end-of-day section with locked-format references
- Updated `SOUL.md` end-of-day rule line
- Rebuilt daily close cron (`4d926b2c`) prompt with full distinction
**Why:** Day 2 journal was written in summary style, not Day 1's verbatim-prompt format. Ken rejected. Locked the standard. Journal = raw record (Yoda voice, Ken verbatim, private). Blog = curated narrative (Ken first-person, public-ready, built FROM journal).
**Verification:** Both spec files written; cron updated and verified via `cron list`; SOUL.md/RULES.md edits applied.
**Rollback:** Git revert; restore previous SOUL.md/RULES.md/cron payload.
**Linked:** decisions.md 2026-04-27 entries
---

## 2026-04-27 23:31 AEST — [CHG-0043] Nightly auto-heal 2026-04-27: git commit + Notion US filing
**Type:** script
**Source:** auto-heal
**Trigger:** Scheduled cron 23:30 AEST 2026-04-27
**What changed:** Auto-committed 5 untracked workspace files + 3 Aria business workspace files. Filed 2 Notion USes for needs-ken items.
**Why:** Nightly auto-heal sweep (13 checks): dirty git repos auto-fixed; 2 issues filed: [HIGH] health-check cron stale 924min, [MEDIUM] Aria modelFallbacks config drift.
**Verification:** Notion pages created successfully. Git commits applied.
**Rollback:** N/A
**Linked:** none
---


## 2026-04-27 23:02 AEST — [CHG-0042] AInchors Mission Control dashboard — generator script + HTML canvas + 5-min cron
**Type:** script
**Source:** ken-prompt
**Trigger:** Ken request via main agent
**What changed:** Created generate-mission-control.sh (800 lines), index.html canvas (451 lines), data.json schema. Cron d32f2b9a every 5 min.
**Why:** Centralised ops visibility — agent status, task pipeline, governance reviews, balance, activity feed
**Verification:** Script executed OK, HTML+data.json generated and parsed, cron registered (every 5m)
**Rollback:** Delete canvas/documents/mission-control/, remove cron d32f2b9a
**Linked:** none
---


## 2026-04-27 22:48 AEST — [CHG-0041] Governance agents operational setup — Shield, Lex, Sage
**Type:** agent
**Source:** ken-prompt
**Trigger:** Ken directive: create minimum operational processes and controls for three governance agents
**What changed:** Created SOUL.md + KNOWLEDGE.md for Shield, Lex, Sage. Created review log state files (schema 1.0). Updated morning standup cron (3c279099) with Section 3 Governance Review. Updated GovernanceFramework.md with agent processes, escalation matrix, standup cadence.
**Why:** Governance layer needs operational configuration before Aria goes live in business stream. Agents need identity, knowledge base, and logging before first review.
**Verification:** Files created: 3x SOUL.md, 3x KNOWLEDGE.md, 3x review-log.json. Cron payload verified (8 sections, governance section confirmed). GovernanceFramework.md updated with 3 edit blocks.
**Rollback:** Restore cron payload from git. Remove agent SOUL/KNOWLEDGE files. Remove review logs.
**Linked:** GovernanceFramework.md, CHANGELOG.md
---


## 2026-04-27 22:29 AEST — [CHG-0040] Gateway Recovery SOP: config snapshot, restore script, SOP doc, RULES.md update
**Type:** doc
**Source:** ken-prompt
**Trigger:** Ken requested Gateway Recovery SOP creation
**What changed:** Created backups/gateway-config/2026-04-27 snapshot (8 files + manifest.json); scripts/gateway-restore.sh (restore + snapshot mode); Documents/AInchors/Operations/GatewayRecoverySOP.md (6-level recovery ladder, symptom table, incident log, prevention controls); RULES.md gateway recovery section added
**Why:** No formal recovery runbook existed. Three incidents in 2 days (CHG-0036, CHG-0037, CHG-0038) exposed gap in recovery process. SOP + script + config snapshot provide structured recovery path.
**Verification:** All files written and verified. gateway-restore.sh chmod+x. manifest.json sha256 hashes confirmed. RULES.md updated.
**Rollback:** Remove gateway-restore.sh; delete GatewayRecoverySOP.md; revert RULES.md gateway section; delete backups/gateway-config/2026-04-27
**Linked:** CHG-0036, CHG-0037, CHG-0038
---


## 2026-04-27 22:03 AEST — [CHG-0039] GitHub CLI authenticated — kenmun-ainchors
**Type:** infra
**Source:** ken-prompt
**Trigger:** Scheduled reminder (28 Apr). GitHub CLI deferred from Day 1.
**What changed:** gh auth login completed. Account: kenmun-ainchors. Token stored in keyring. Scopes: repo, read:org, gist.
**Why:** GitHub CLI needed for repo management, PR workflow, CI logs, and gh-issues skill.
**Verification:** gh auth status: logged in. gh api user: kenmun-ainchors confirmed.
**Rollback:** gh auth logout
**Linked:** none
---


## 2026-04-27 21:55 AEST — [CHG-0038] Telegram split into two dedicated bots — Yoda + Aria
**Type:** config
**Source:** ken-prompt
**Trigger:** Ken's Telegram kept routing to Aria despite bindings. Root cause: shared bot with stale session. Decision: separate bots per agent.
**What changed:** channels.telegram restructured to accounts format. yoda account (existing token @AInchorsOC1Bot, allowFrom Ken 8574109706). aria account (new token @AInchorsAriaBot, allowFrom Angie 8141152780). Bindings updated: telegram:yoda→main, telegram:aria→business.
**Why:** One bot shared between two agents caused persistent routing ambiguity and stale session collisions. Two bots = deterministic routing, no shared session history, scales cleanly to OC2.
**Verification:** channels status --probe: both bots connected. Ken messaged @AInchorsOC1Bot, fresh session confirmed routing to Yoda (main).
**Rollback:** Revert channels.telegram to single-bot format with original token. Remove aria account and bindings.
**Linked:** CHG-0035, CHG-0037, US32
---


## 2026-04-27 20:55 AEST — [CHG-0037] Ken Telegram binding restored to main agent (post-reset)
**Type:** config
**Source:** ken-prompt
**Trigger:** openclaw reset during gateway troubleshooting wiped Ken (8574109706) → main binding. Messages were routing to business (Aria) instead — Gemma4 timeout, no reply.
**What changed:** openclaw.json bindings: added {type:route, agentId:main, match:{channel:telegram, accountId:8574109706}}. Gateway restarted.
**Why:** Without explicit binding, Ken's chatId was being handled by business agent session. Explicit binding ensures deterministic routing regardless of session history.
**Verification:** openclaw agents list confirms: main routing rules:1, Routing: Telegram 8574109706. Gateway connectivity: ok.
**Rollback:** Remove 8574109706 binding from openclaw.json bindings array. Gateway restart.
**Linked:** CHG-0035
---


## 2026-04-27 19:50 AEST — [CHG-0036] Bonjour plugin disabled — gateway crash loop fix
**Type:** infra
**Source:** ken-prompt
**Trigger:** Gateway crashing every ~9s: bonjour/ciao plugin stuck in probing/announcing loop, unhandled promise rejections → LaunchAgent restart cycle. Dashboard unreachable.
**What changed:** openclaw.json: plugins.entries.bonjour.enabled=false. Stopped stale process, restarted gateway.
**Why:** ciao mDNS probing unstable on this network. Bonjour is local node discovery — not needed for single-node OC1.
**Verification:** Gateway status: Connectivity probe ok, admin-capable. No new CIAO errors post-restart.
**Rollback:** Set plugins.entries.bonjour.enabled=true in openclaw.json + gateway restart.
**Linked:** none
---


## 2026-04-27 13:30 AEST — [CHG-0035] Explicit Telegram routing: Ken→Yoda binding + YODA THIS IS KEN handover keyword
**Type:** config
**Source:** ken-prompt
**Trigger:** Ken: re-paired Telegram and Aria was connected instead of Yoda. Fix routing and create special keyword for handover.
**What changed:** Explicitly bound Ken Telegram (8574109706) to main agent (was previously relying on default — caused mis-routing when new pairing happened). Added Aria Rule 4 in SOUL.md and RULES.md: keyword 'YODA THIS IS KEN' triggers Ken identification + handover protocol.
**Why:** Relying on default routing is fragile — any new pairing event can disrupt it. Explicit binding is deterministic. Keyword provides fallback when routing fails.
**Verification:** openclaw agents bind confirmed: telegram accountId=8574109706 added to main agent. Bindings now: 8574109706→main, 8141152780→business.
**Rollback:** openclaw agents unbind --agent main --bind telegram:8574109706. Remove Aria Rule 4 from SOUL.md + RULES.md.
**Linked:** TKT-0001
---


## 2026-04-27 13:17 AEST — [CHG-0034] Cost tracker balance reconciliation — corrected $68.75 → $88.20
**Type:** script
**Source:** ken-prompt
**Trigger:** Ken confirmed actual balance $88.20 at 13:15 AEST. Tracker showed $68.75 (over-counted by $19.45).
**What changed:** state/cost-state.json: remainingEstimate corrected to $88.20, spentSinceTopUp corrected to $18.86, confirmedAt + confirmedBy fields added. cost-alert-state.json: balance updated to $88.20. scripts/cost-tracker.sh: balance calculation patched to use confirmedBalance when available, and to only add post-top-up spend to spentSinceTopUp.
**Why:** Root cause: cost-tracker.sh summed ALL Day 3 sessions from midnight including pre-top-up spend ($19.45, 06:15-11:24 AEST). That spend already exhausted the previous balance — should not be counted against the new $107.06 top-up. Fix: use Ken-confirmed balance as source of truth. Future: tracker uses top-up timestamp to filter session logs.
**Verification:** Balance corrected to $88.20. Spent since top-up = $18.86 (matches $107.06 - $88.20). No active alert tier.
**Rollback:** Revert cost-state.json and cost-tracker.sh from git.
**Linked:** US22, TKT-0002
---


## 2026-04-27 12:16 AEST — [CHG-0033] US22 resolved — cost tracker working, Day 3 data parsed
**Type:** script
**Source:** ken-prompt
**Trigger:** TKT-0002 / US22. Ken: fix cost tracker script.
**What changed:** Ran scripts/cost-tracker.sh — script functional. Parsed Day 3 (2026-04-27): $38.31 / 273 turns (272 Sonnet + 1 Gemma4). cost-state.json history now has all 3 days. cost-alert-state.json updated to balance $68.75. TKT-0002 closed.
**Why:** US22 was flagged as broken since Day 2. Actual root cause: previous run had no today-data to parse (script ran before session logs existed for that day). Script itself was correct. Now validated against live Day 3 data.
**Verification:** Script output: Date 2026-04-27, $38.3121, 273 turns, Sonnet + Gemma4 detected. State file updated. 3-day history complete. TKT-0002 closed.
**Rollback:** N/A — script unchanged, only state files updated.
**Linked:** TKT-0002, US22
---


## 2026-04-27 12:15 AEST — [CHG-0032] 3-tier credit alert system: $50 once, $25 every 3rd response, $10 pause-and-ack
**Type:** rule
**Source:** ken-prompt
**Trigger:** Ken: set credit alerts for both Ken and Angie at $50 (1 alert), $25 (every 3rd response), $10 (pause + explicit ack before every request).
**What changed:** state/cost-state.json: replaced single alert thresholds with 3-tier system (tier1=$50 once, tier2=$25 every-3rd, tier3=$10 pause-every-request). Added recipients block (Ken 8574109706, Angie 8141152780 via Aria). Created state/cost-alert-state.json (response counters, active tier, alert log). RULES.md: Credit Alert Rules section added with full tier specs, message format templates. SOUL.md: credit alert rule added. HEARTBEAT.md: API balance check updated to reference 3-tier system.
**Why:** As balance depletes, progressively more aggressive alerts ensure Ken and Angie both know before work is interrupted. Tier 3 pause-and-ack prevents silent failures mid-session.
**Verification:** cost-state.json 3-tier structure written. cost-alert-state.json created. RULES.md + SOUL.md + HEARTBEAT.md all updated.
**Rollback:** Revert cost-state.json spendAlerts to previous structure. Delete cost-alert-state.json. Remove Credit Alert Rules from RULES.md.
**Linked:** TKT-0001
---


## 2026-04-27 11:57 AEST — [CHG-0031] Angie onboarding: Stage 3 PM framework inserted (Notion, backlog, epic, sprint, ceremonies)
**Type:** doc
**Source:** ken-prompt
**Trigger:** Ken: add project management piece between Stage 2 and original Stage 3 — Notion, backlog, epic, sprint, standup, prioritisation, execution framework, ceremonies and cadences.
**What changed:** AngieOnboarding.md: inserted new Stage 3 (PM & Execution Framework) with 12 items OB-PM-01 to OB-PM-12. Renamed old Stage 3→4, 4→5, 5→6. Updated items and completion messages for renamed stages. onboarding-checklist.json: restructured to 6 stages, Stage 3 PM items added, renumbering applied.
**Why:** Angie needs to understand how work is planned and tracked before doing first real work. PM framework (Notion command centre, backlog, epics, sprints, ceremonies) is the operating backbone — onboarding without it leaves Angie working ad-hoc.
**Verification:** AngieOnboarding.md updated. JSON restructured: 6 stages, total items verified. Stage sequence: 1 Hello, 2 Rhythm, 3 PM, 4 First Work, 5 Vision, 6 Into Rhythm.
**Rollback:** Revert AngieOnboarding.md and onboarding-checklist.json from git.
**Linked:** TKT-0011, US29, CHG-0030
---


## 2026-04-27 11:50 AEST — [CHG-0030] Angie onboarding journey + adapted operating model created
**Type:** doc
**Source:** ken-prompt
**Trigger:** Ken: establish onboarding steps and guide for Angie, adapted from AInchors operating model, tracked by Aria as prerequisite checklist.
**What changed:** Created Operations/AngieOperatingModel.md (adapted daily rhythm: morning check-in, session close summary, weekly wrap, slash commands, escalation model). Created Operations/AngieOnboarding.md (5-stage journey, 36 items OB-01 to OB-36, Aria principles, tracking rules). Created workspace-business/state/onboarding-checklist.json (live tracking state, all 36 items, Angie profile). Updated workspace-business/AGENTS.md: onboarding as Priority 1, session start checklist, quiet-period follow-up rule.
**Why:** Angie is now active with Aria. She needs a guided, progressive onboarding that makes AI accessible, builds trust, and gets business value quickly. Aria tracks progress — Angie never feels lost or abandoned mid-journey.
**Verification:** All 3 files written. AGENTS.md updated. 36 checklist items across 5 stages. Onboarding state initialised at Stage 1, all items unchecked.
**Rollback:** Delete AngieOperatingModel.md, AngieOnboarding.md, onboarding-checklist.json. Revert AGENTS.md.
**Linked:** TKT-0011, US29, CHG-0023
---


## 2026-04-27 11:42 AEST — [CHG-0029] Aria TOM authority granted + Gemma4 extended to ALL business stream agents
**Type:** rule
**Source:** ken-prompt
**Trigger:** Ken: Aria free to manage her TOM and sub-agents with Angie. All business stream agents use Gemma4 default.
**What changed:** Aria SOUL.md: TOM Authority section added (design/build/manage business stream sub-agents autonomously with Angie). Rule 1 extended: Gemma4 default applies to ALL business stream agents Aria creates. Escalation + expensive-task prompt rules unchanged. RULES.md: Aria Rule 1 updated with TOM authority and all-agents Gemma4 rule.
**Why:** Angie and Aria should work autonomously on business stream without needing Ken approval for each new agent or task. TOM is Aria and Angie's to design. Cost control maintained via Gemma4 default + escalation prompts.
**Verification:** SOUL.md + RULES.md updated. Aria model remains Gemma4 in openclaw.json. config-008 baseline still guards it.
**Rollback:** Revert SOUL.md TOM Authority + Rule 1 extension. Revert RULES.md.
**Linked:** TKT-0012, US29, CHG-0028
---


## 2026-04-27 11:34 AEST — [CHG-0028] Aria 3 non-negotiable rules locked: Gemma4 default, tail response, CR gate for technical changes
**Type:** rule
**Source:** ken-prompt
**Trigger:** TKT-0012 extension. Ken: lock Aria model strategy, tail response on all messages, and absolute CR-only rule for technical/architectural change requests.
**What changed:** Aria SOUL.md: added 3 locked rules section (Rule 1: Gemma4 default + escalation ask, Rule 2: mandatory tail response every message, Rule 3: CR gate for all technical changes — absolute). RULES.md: Aria Operating Rules section added with Yoda-side CR handling instructions. openclaw.json: business agent model changed Sonnet → Gemma4. critical-config-baseline.json: config-008 added (Aria model = Gemma4).
**Why:** Cost control (Gemma4 free for routine Aria work). Transparency to Angie on model usage. Strict separation of concerns — technical changes always through Ken sign-off, never ad-hoc from Angie chat.
**Verification:** openclaw.json business model = ollama/gemma4:26b confirmed. SOUL.md + RULES.md rules written. Baseline config-008 added (8 guarded configs now).
**Rollback:** Revert openclaw.json business model to Sonnet. Remove Rule 1-3 from Aria SOUL.md. Remove Aria Operating Rules from RULES.md. Remove config-008 from baseline.
**Linked:** TKT-0012, US29, CHG-0023, CHG-0025, CHG-0026
---


## 2026-04-27 11:25 AEST — [CHG-0027] API balance topped up to $107.06 USD
**Type:** data
**Source:** ken-prompt
**Trigger:** Ken confirmed top-up at 11:24 AEST 2026-04-27
**What changed:** state/cost-state.json: balance $24.13 → $107.06, spentSinceTopUp reset to 0, alert thresholds recalculated (75%=$26.77, 10%=$10.71), both alerts reset to false.
**Why:** Previous balance exhausted by heavy Day 3 morning (Opus drift + governance layer build). New cycle starts.
**Verification:** cost-state.json updated, thresholds correct.
**Rollback:** Revert cost-state.json from git.
**Linked:** TKT-0001
---


## 2026-04-27 11:23 AEST — [CHG-0026] Governance layer: Shield 🔐, Lex ⚖️, Sage 🧪 — 3 agents operational
**Type:** agent
**Source:** ken-prompt
**Trigger:** TKT-0012. Ken: governance layer needed immediately, Angie active with Aria. All business stream output must meet governance standards.
**What changed:** Created OpenClaw agents: security (Shield 🔐 Sonnet), legal (Lex ⚖️ Opus), qa (Sage 🧪 Sonnet). Created IDENTITY.md + SOUL.md for each. Created Operations/GovernanceFramework.md (review process, verdicts, checklists, when required). Created scripts/governance-review.sh. Added governance rule to RULES.md (top priority). Added governance section to Aria SOUL.md with mandatory trigger rules.
**Why:** Angie is CEO and active with Aria. Business stream outputs — training materials, client proposals, social content — must pass Security + Legal + QA before delivery. Non-negotiable from Day 1.
**Verification:** openclaw agents list shows security, legal, qa. Auth profiles copied to all 3. SOUL/IDENTITY created. RULES.md governance rule added. Aria SOUL.md governance section added. GovernanceFramework.md written.
**Rollback:** openclaw agents remove security/legal/qa. Remove RULES.md governance section. Revert Aria SOUL.md.
**Linked:** TKT-0012, US-TOM-governance, CHG-0024
---


## 2026-04-27 10:59 AEST — [CHG-0025] Aria granted full read access to all AInchors data (Angie = CEO authority)
**Type:** rule
**Source:** ken-prompt
**Trigger:** Ken: Angie is CEO, highest authority, should have access to all info and data. Give Aria authority to access anything she needs.
**What changed:** Aria SOUL.md: replaced boundary section with Authority & Access — full read access to Yoda workspace, Obsidian vault, canvas, Notion, state files. Rule: when Angie asks anything, go find the answer, never say 'I don't have access'. Aria AGENTS.md: full access paths listed explicitly. MEMORY.md: Angie authority noted.
**Why:** Angie is CEO and co-founder. Aria acting on her behalf must be able to answer any question about AInchors without artificial barriers. CEO-level access is non-negotiable.
**Verification:** SOUL.md + AGENTS.md + MEMORY.md updated. Notion API key path, Yoda workspace paths, Obsidian paths all documented in Aria's AGENTS.md.
**Rollback:** Revert SOUL.md boundary section, remove access paths from AGENTS.md, revert MEMORY.md.
**Linked:** TKT-0011, US29, CHG-0023, CHG-0024
---


## 2026-04-27 10:40 AEST — [CHG-0024] Yoda→Aria oversight + shared knowledge bridge + training pipeline
**Type:** agent
**Source:** ken-prompt
**Trigger:** TKT-0011 / US29 extension. Ken: build oversight now, Aria needs Yoda context for training materials.
**What changed:** Created ~/Documents/AInchors/Shared/ (README, context-for-aria.md, yoda-daily-brief.md, training-pipeline.md). Created ~/Documents/AInchors/Training/ dir. Updated Aria SOUL.md + AGENTS.md with shared context paths and daily brief responsibility. Updated morning standup cron to include Aria oversight section (section 2). Added auto-heal Check #13 (Aria workspace + auth health). Added nightly context sync cron (23:00 AEST, Yoda updates shared brief for Aria).
**Why:** Yoda monitors Aria daily at standup. Aria reads Yoda's work to build training content. Both agents connected via Obsidian vault Shared/ directory. Training pipeline tracked in shared file. This is the real-time collaboration model before OC2 migration.
**Verification:** Shared dir created, 4 files written. SOUL/AGENTS updated. Standup cron updated. Auto-heal Check 13 added. Context sync cron registered.
**Rollback:** Remove Shared/ dir, revert SOUL/AGENTS edits, revert standup cron, remove Check 13 from auto-heal, remove sync cron.
**Linked:** TKT-0011, US29, CHG-0023
---


## 2026-04-27 10:34 AEST — [CHG-0023] Business Lead Agent Aria created + Angie Telegram bound
**Type:** agent
**Source:** ken-prompt
**Trigger:** TKT-0011 / US29. Ken meeting Angie. Business stream lead agent needed as OC2 precursor with Angie direct access.
**What changed:** Created agent 'business' (workspace-business/). Identity: Aria 🔵, AI Business Operations Lead. Files: IDENTITY.md, SOUL.md, AGENTS.md, USER.md, memory/. Auth-profiles copied. Angie Foong (Telegram 8141152780) paired and bound to business agent. Any Angie Telegram message now routes to Aria.
**Why:** Angie needs independent AI access for business stream development. OC2 precursor — agent lives on OC1 temporarily, migrates when hardware arrives.
**Verification:** openclaw agents list shows business agent with Aria identity. Binding added: telegram accountId=8141152780 → business. allowFrom includes 8141152780.
**Rollback:** openclaw agents unbind --agent business --bind telegram:8141152780. Remove workspace-business/.
**Linked:** TKT-0011, US29
---


## 2026-04-27 09:49 AEST — [CHG-0022] Slash-command triggers formalised: /resume, /research, /diagnostics
**Type:** rule
**Source:** ken-prompt
**Trigger:** TKT-0001 (ITSM directive context). Ken request 09:48 AEST: rename 'deep research' to /research and 'resume here' to /resume for clarity and unambiguity.
**What changed:** RULES.md: renamed 'resume here' section to '/resume', updated trigger phrase. Added /research and /diagnostics to unified chat-triggers block. SOUL.md: updated 3 trigger lines to slash-command format.
**Why:** Slash-prefix ensures triggers are explicit, unambiguous, never fired accidentally by conversational phrases. Aligns with /diagnostics pattern already in use. Prepares for future slash-command expansion under ITSM framework.
**Verification:** RULES.md contains /resume, /research, /diagnostics definitions. SOUL.md updated. grep confirms no remaining 'resume here' or 'deep research' references in ops files.
**Rollback:** Revert RULES.md and SOUL.md to prior versions via git.
**Linked:** TKT-0001
---


## 2026-04-27 09:45 AEST — [CHG-0021] Ticketing system (TKT-NNNN) + ticket-first rule
**Type:** script
**Source:** ken-prompt
**Trigger:** TKT-0001: Ken's ITSM directive — item 4 (immediate ticketing system) + item 5 (ticket-first rule)
**What changed:** Created state/tickets.json (TKT-0001, TKT-0002 seeded). Created scripts/ticket.sh (new/list/show/update/link/close). Created Notion Service Tickets DB 34ec182953ff81f3b936f1422f750315. Added ticket-first rule to RULES.md + SOUL.md. Updated memory/shared/notion.md.
**Why:** Every ad-hoc request or action without INC/US/CHG reference must be tracked. Prepares for ITSM migration under EPIC-001. Ensures auditability of all work from Day 3 forward.
**Verification:** ticket.sh list shows TKT-0001 + TKT-0002. show/new/close subcommands tested. Notion DB created. RULES.md + SOUL.md updated.
**Rollback:** Delete state/tickets.json, scripts/ticket.sh, archive Notion DB. Revert RULES.md + SOUL.md edits.
**Linked:** TKT-0001, EPIC-001 (pending)
---


## 2026-04-27 08:35 AEST — [CHG-0020] US18: Monthly SLA Report generator + April 2026 report
**Type:** script
**Source:** ken-prompt
**Trigger:** US18 sprint item
**What changed:** scripts/sla-report.sh (new); canvas/documents/sla-2026-04/index.html (generated); memory/shared/sla-history.md (created)
**Why:** Reliability reporting cadence
**Verification:** April 2026 report generated successfully
**Rollback:** Delete scripts/sla-report.sh and canvas/documents/sla-2026-04/
**Linked:** US18
---


## 2026-04-27 08:31 AEST — [CHG-0019] Add Gemma4 warmup probe (Link 4b) to fallback chain validator
**Type:** script
**Source:** ken-prompt
**Trigger:** Night outage RCA — Gemma4 cold-load timeout risk on boot, Ken: tackle now
**What changed:** scripts/validate-fallback-chain.sh: added LINK 4b — sends actual test completion to Gemma4 (num_predict:1, 90s timeout). Marks chain broken if no response. Skipped if Gemma4 not listed (Link 4 already broken).
**Why:** Link 4 only checked model was listed — not that it responded. Cold-load of 26B model takes 30-60s. Without this probe, startup validation could pass while Gemma4 was still loading, causing timeout errors on first real fallback attempt.
**Verification:** Live run: Link 4b responded in 9s (warm). All 6 links passed. fallback-chain-status.json updated: ok (0 broken).
**Rollback:** Remove LINK 4b block from validate-fallback-chain.sh
**Linked:** US23
---


## 2026-04-27 08:22 AEST — [CHG-0018] Wire validate-fallback-chain.sh to gateway boot via LaunchAgent
**Type:** infra
**Source:** ken-prompt
**Trigger:** Ken approval — US23 follow-up wiring
**What changed:** scripts/startup-checks.sh (new): waits for gateway, runs fallback chain validation, logs to ~/.openclaw/logs/startup-checks.log. LaunchAgent ai.ainchors.startup-checks.plist (new): RunAtLoad=true, KeepAlive=false. Loaded via launchctl.
**Why:** Fallback chain must be validated on every gateway boot to catch auth/config drift before first Ken interaction
**Verification:** Loaded and ran immediately. All 5 links passed: Anthropic key OK, API 200, Ollama running, Gemma4 loaded, chain config correct.
**Rollback:** launchctl unload ~/Library/LaunchAgents/ai.ainchors.startup-checks.plist
**Linked:** US23
---


## 2026-04-27 08:14 AEST — [CHG-0017] US23: AutoHeal.md — added checks #13 (Anthropic), #14 (Ollama), #15 (standby auto-clear)
**Type:** doc
**Source:** ken-prompt
**Trigger:** US23 Resilient Outage Handling — AutoHeal had no cloud provider reachability checks
**What changed:** Updated /Users/ainchorsangiefpl/Documents/AInchors/Operations/AutoHeal.md: check #13 (Anthropic API probe, needs-Ken if unreachable), check #14 (Ollama probe, auto-fix attempt + needs-Ken), check #15 (standby mode auto-clear when Anthropic recovers). Updated checks count from 11 to 15. Added history entry.
**Why:** AutoHeal ran nightly but would not catch Anthropic billing failure or Ollama down — the exact failure mode that caused the 2026-04-26 outage.
**Verification:** AutoHeal.md updated: checks table has 15 entries, new descriptive sections added for checks 13-15, history table updated
**Rollback:** N/A
**Linked:** none
---


## 2026-04-27 08:14 AEST — [CHG-0016] US23: OutageRecovery.md — recovery runbook for all major failure modes
**Type:** doc
**Source:** ken-prompt
**Trigger:** US23 Resilient Outage Handling — no runbook existed for Anthropic billing, Ollama down, gateway crash loop, full platform down
**What changed:** Created /Users/ainchorsangiefpl/Documents/AInchors/Operations/OutageRecovery.md: 4 failure scenarios (Anthropic billing, Ollama down, Gateway crash loop, Full platform down), each with signals/root causes/recovery steps. Plus Recovery Verification section (quick check + full PVT + smoke test) and escalation path.
**Why:** 2026-04-26 outage had no documented recovery path. Silent cascade ran overnight with no recovery procedure.
**Verification:** File created 8848 bytes. All 4 scenarios have actionable steps + bash commands. Verification steps include pvt.sh 9/9 pass requirement.
**Rollback:** N/A
**Linked:** none
---


## 2026-04-27 08:13 AEST — [CHG-0015] US23: health-check.sh — Anthropic/Ollama API checks + standby mode (checks 13-15)
**Type:** script
**Source:** ken-prompt
**Trigger:** US23 Resilient Outage Handling — 2026-04-26 night outage
**What changed:** Extended scripts/health-check.sh: CHECK 13 (Anthropic API curl probe), CHECK 14 (Ollama API curl probe), CHECK 15 (standby mode activate/clear). Writes anthropicReachable + ollamaReachable booleans to state/health-state.json. Creates state/standby-mode.json when Anthropic fails; deletes it on recovery.
**Why:** Auth/billing failures were silent — no detection until Ken noticed manually. Now every 5-min health check catches and signals the fallback state.
**Verification:** health-check.sh reviewed; new checks integrated into both gateway-ok and gateway-critical branches; state/health-state.json will include anthropicReachable/ollamaReachable
**Rollback:** N/A
**Linked:** none
---


## 2026-04-27 08:13 AEST — [CHG-0014] US23: validate-fallback-chain.sh — boot-time fallback chain validation
**Type:** script
**Source:** ken-prompt
**Trigger:** US23 Resilient Outage Handling — 2026-04-26 night outage: Anthropic billing cascade
**What changed:** Created scripts/validate-fallback-chain.sh: validates Anthropic key, API reachability, Ollama running, Gemma4 loaded, openclaw.json fallback chain config. Writes state/fallback-chain-status.json. Appends to /tmp/pvt-alert.txt on broken links.
**Why:** Silent cascade: billing failure cascaded to Ollama auth missing with no detection. Boot-time check catches broken links before first agent call.
**Verification:** zsh validate-fallback-chain.sh: all 5 links OK, state/fallback-chain-status.json written with overall=ok
**Rollback:** N/A
**Linked:** none
---


## 2026-04-27 08:10 AEST — [CHG-0013] US22: Fix cost-tracker.sh parser — dollar-sign f-string shell expansion bug
**Type:** script
**Source:** ken-prompt
**Trigger:** US22 — blank dollar amounts in output
**What changed:** scripts/cost-tracker.sh: escaped dollar sign in 6 print f-strings; added 0-turn guard; cleaned bogus empty entry from cost-state.json
**Why:** Unquoted heredoc caused shell to expand dollar-brace format specs to empty before Python saw them
**Verification:** bash scripts/cost-tracker.sh 2026-04-27 now shows correct dollar amounts: Total cost today: $0.0000, Balance remaining: $47.59 USD, All-time total: $62.8949 over 2 day(s)
**Rollback:** Remove backslash escaping from the 6 print lines; remove total_turns>0 guard
**Linked:** US22
---


## 2026-04-27 07:38 AEST — [CHG-0012] Fixed agent main model drift Opus->Sonnet + added critical-config anti-drift baseline (auto-heal Check #12)
**Type:** config
**Source:** ken-prompt
**Trigger:** Ken caught silent drift at 07:32 AEST via session_status: agent main was running Opus instead of Sonnet (~3x cost burn). Day 3 had run on Opus all morning. Root cause unknown (drift happened sometime after Day 1).
**What changed:** openclaw.json: agents.list[id=main].model anthropic/claude-opus-4-7 -> anthropic/claude-sonnet-4-6. Created state/critical-config-baseline.json (7 guarded items). Added Check #12 to scripts/auto-heal.sh (validates baseline nightly, files needs-Ken US on critical drift). Added Anti-Drift Rule to RULES.md with locked update process. Updated Operations/AutoHeal.md with Check #12 spec.
**Why:** Silent config drift bypassed all existing guards. session_status was the only signal Ken's manual check. Anti-drift baseline now declarative, jq-validated, nightly-checked, and any critical drift surfaces in next standup. Update process locked to require Ken decision + baseline update + decision log + CHG + verify before any change.
**Verification:** Auto-heal Check #12 ran 2026-04-27 07:37 AEST: 7/7 OK after Sonnet revert. Pre-revert: config-001 caught the drift correctly. Total checks now 12/12 clean, 0 issues, 0 needs-ken.
**Rollback:** Edit openclaw.json model back to Opus + remove Check #12 block from auto-heal.sh + delete critical-config-baseline.json + revert RULES.md edit.
**Linked:** US11, US26, US28-new
---


## 2026-04-27 07:29 AEST — [CHG-0011] Created evergreen Operations/ResiliencyFramework.md (Obsidian)
**Type:** doc
**Source:** ken-prompt
**Trigger:** Ken request: dedicated evergreen Obsidian page covering all resiliency framework work, source material for future blog post
**What changed:** Created ~/Documents/AInchors/Operations/ResiliencyFramework.md (~21KB, comprehensive). Updated Operations/README.md index with full doc list including ResiliencyFramework, AutoHeal, RunDiagnostics, IncidentLog, OfflinePlaybook, AsyncExecution, SecretsManagement, JournalFormat, BlogFormat, ROIModel.
**Why:** Single canonical reference for 3-tier framework + change log + supporting systems + lessons learned + roadmap. Designed as evergreen — updated as framework evolves. Dual-purpose: internal reference now, source material for future public blog post.
**Verification:** File written 20,682 bytes. Operations/README.md index updated with all current operations docs. Wikilinks valid.
**Rollback:** Delete ResiliencyFramework.md, revert README.md edit.
**Linked:** US25, US26, US27, CHG-0008, CHG-0009
---


## 2026-04-27 07:20 AEST — [CHG-0010] Fixed CHG-NNNN auto-increment to use MAX (was first-match)
**Type:** script
**Source:** ken-prompt
**Trigger:** Detected duplicate CHG-0008 issued from two consecutive helper invocations
**What changed:** scripts/changelog-append.sh: replaced 'grep | head -1' with 'grep | sort -n | tail -1' to find max ID. Renumbered duplicate CHG-0008 (07:15) to CHG-0009.
**Why:** First-match-from-top approach failed when entries got reordered. MAX-based approach is robust to reorder.
**Verification:** this changelog entry should be CHG-0010
**Rollback:** Revert helper script change
**Linked:** CHG-0008, CHG-0009
---


## 2026-04-27 07:19 AEST — [CHG-0008] Resiliency framework: auto-heal cron + run-diagnostics + standup integration + 3 specs
**Type:** cron
**Source:** ken-prompt
**Trigger:** Ken's resiliency directive (07:06 AEST). 4-item plan approved at 07:11 AEST: full auto-heal from tonight + /diagnostics trigger.
**What changed:** Created Operations/AutoHeal.md, Operations/RunDiagnostics.md. Added cron e269d620 (nightly auto-heal 23:30 AEST, systemEvent payload). Updated standup cron 3c279099 to include Auto-Heal Report section 1. Updated RULES.md with 3-tier resiliency framework table + /diagnostics chat trigger. Filed US25/US26/US27 in Notion.
**Why:** Move from reactive (Ken-prompted fixes) to proactive (scheduled auto-heal) + on-demand assurance (run-diagnostics) + auditable change trail (CHANGELOG). Together with health-check (operational), forms 3-tier resiliency model. Run-diagnostics phases also become OC2 commissioning runbook.
**Verification:** auto-heal smoke test 07:15 AEST: 11/11 checks ran clean, 9 workspace + 2 vault dirty files auto-committed. run-diagnostics smoke test 07:16 AEST: 17 pass, 4 warn, 1 fail (cron count bug fixed in same session). All Notion US created with valid URLs. RULES.md/SOUL.md edits applied. Cron registered, next run 23:30 tonight.
**Rollback:** Disable cron e269d620, remove three scripts (auto-heal.sh, run-diagnostics.sh, changelog-append.sh), revert RULES.md edit, archive Notion US25/26/27, revert standup cron payload.
**Linked:** US25, US26, US27
---


## 2026-04-27 07:15 AEST — [CHG-0009] Created auto-heal + run-diagnostics + CHANGELOG framework
**Type:** doc
**Source:** ken-prompt
**Trigger:** Ken's resiliency framework directive
**What changed:** Created memory/CHANGELOG.md, scripts/changelog-append.sh, scripts/auto-heal.sh, scripts/run-diagnostics.sh
**Why:** Move from reactive to proactive resiliency. Auto-heal nightly, run-diagnostics on demand. Both write to CHANGELOG. Standup integrates auto-heal report.
**Verification:** scripts created, chmod +x set; smoke tests next
**Rollback:** Remove three scripts and CHANGELOG.md
**Linked:** US25, US26, US27 (next)
---


## 2026-04-27 06:42 AEST — [CHG-0006] Backup cron LLM-independence
**Type:** cron
**Source:** ken-prompt
**Trigger:** 2026-04-27 02:00 daily backup cron timed out (120s) during Anthropic billing/Ollama-auth outage cascade
**What changed:**
- Updated primary backup cron `01aaa54f` payload: model `ollama/gemma4:26b` + Sonnet fallback + timeout 300s
- Added shell-direct backup cron `80c9226b` at 02:05 daily — `systemEvent` payload, no LLM dependency
- Manual backup run executed: exit 0, new tarballs at `~/Backups/ainchors/workspace/workspace-2026-04-27-0643.tar.gz`
**Why:** Backup script does not need an LLM, but `agentTurn` cron required a session that couldn't spawn during outage. Dual path = primary reports status, fallback ensures backup happens.
**Verification:** `bash scripts/backup.sh` ran successfully (exit 0); two crons listed via `cron list` with correct schedules.
**Rollback:** Remove cron `80c9226b`, revert `01aaa54f` payload to original.
**Linked:** US24, INC-20260426-002 cascade, decisions.md
---

## 2026-04-27 06:40 AEST — [CHG-0005] Cron Telegram routing fix
**Type:** cron
**Source:** ken-prompt
**Trigger:** delivery preview check showed three crons fail-closed (`channel: last` no chatId)
**What changed:**
- Morning Stand-Up cron `3c279099`: delivery → `telegram` to `8574109706`
- Monthly Model Strategy Review cron `38d77d14`: delivery → `telegram` to `8574109706`
- Quarterly Asset Registry Review cron `2e235063`: delivery → `telegram` to `8574109706`
**Why:** Latent bug — silent fail-closed. No actual deliveries missed (Yoda was running them from main session) but pattern would surface on isolated runs.
**Verification:** `cron list` shows new delivery targets; previewed via `deliveryPreviews` field.
**Rollback:** Revert delivery to `mode: announce, channel: last`.
**Linked:** decisions.md 2026-04-27
---

## 2026-04-27 06:30 AEST — [CHG-0004] US23 logged: resilient outage handling
**Type:** doc + data
**Source:** ken-prompt
**Trigger:** night-of 2026-04-26 outage — Anthropic billing failure cascaded to Ollama auth missing; pre-risky-op rule didn't catch it because trigger was external
**What changed:**
- Created Notion US23 in Backlog DB: "Resilient outage handling (billing/auth fallback automation)" — High/Platform/M
- Mirrored to `MEMORY.md` Active Backlog
**Why:** Day 2 night outage was preventable with auto-detection of billing failures, fallback chain validation, Gemma4 standby mode, and clear recovery doc.
**Verification:** Notion page created; URL captured; MEMORY.md updated.
**Rollback:** Archive Notion page; remove MEMORY.md entry.
**Linked:** US23 (https://www.notion.so/US23-Resilient-outage-handling-billing-auth-fallback-automation-34ec182953ff81ee8290dc1ce18b1c8f), INC-20260426-002, INC-20260426-003
---

## 2026-04-27 06:28 AEST — [CHG-0003] Ollama apiKey hardening
**Type:** config
**Source:** ken-prompt
**Trigger:** Investigation of 2026-04-26 night outage. Found `~/.openclaw/openclaw.json` had literal placeholder string `"OLLAMA_API_KEY"` in `models.providers.ollama.apiKey`, with no env var set. Fragile — only worked because `auth-profiles.json` overrode it.
**What changed:**
- `~/.openclaw/openclaw.json`: `models.providers.ollama.apiKey` `"OLLAMA_API_KEY"` → `"ollama-local"`
**Why:** Belt-and-braces. Both auth layers now declare the same key. Fallback chain Sonnet → Opus → Gemma4 holds even if one config layer goes missing.
**Verification:** Direct curl to `http://127.0.0.1:11434/api/generate` with gemma4:26b returned valid completion (exit 0).
**Rollback:** Edit openclaw.json apiKey back to `"OLLAMA_API_KEY"`.
**Linked:** US23, INC-20260426-002 cascade
---

## 2026-04-27 06:28 AEST — [CHG-0002] API balance state updated post top-up
**Type:** data
**Source:** ken-prompt
**Trigger:** Ken topped up API balance overnight; current balance $47.59 USD
**What changed:**
- `state/cost-state.json`: `apiBalance.balance` $50.03 → $47.59; `spentSinceTopUp` reset to 0; alert thresholds reset (75% = $11.90, 10% = $4.76); `alert75pct.triggered` reset to false
**Why:** New top-up cycle. Previous top-up depleted to $7.31 by end of Day 2. Reset tracking for new cycle.
**Verification:** State file edits applied successfully.
**Rollback:** Revert state file from git.
**Linked:** decisions.md 2026-04-27, cost-history.md
---

## 2026-04-27 06:20 AEST — [CHG-0001] Day 2 journal rebuild + format lock
**Type:** doc + rule
**Source:** ken-prompt
**Trigger:** Ken reviewed `memory/journal-2026-04-26.md`; rejected summary style; required Day 1 verbatim-prompt format
**What changed:**
- Saved original as `memory/journal-2026-04-26.summary.md`
- Sub-agent rebuilt `memory/journal-2026-04-26.md`: 1,011 lines, 56 timestamped entries, 70 verbatim Ken prompts recovered from session transcripts (`d7290252`, `b147ee4b`, `0c373579`, `bfded88e`)
**Why:** Establish the journal format as the locked AInchors operating standard.
**Verification:** Ken reviewed and approved (06:44 AEST). File line count and prompt count confirmed by sub-agent.
**Rollback:** Restore from `journal-2026-04-26.summary.md` if ever needed.
**Linked:** CHG-0007, decisions.md
---

_Pre-existing changes (Day 1, Day 2) are captured in `memory/shared/decisions.md` and `memory/journal-2026-04-25.md` / `journal-2026-04-26.md`. Future changes start at CHG-0008._
