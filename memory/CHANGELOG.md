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

## 2026-04-28 18:27 AEST — [CHG-0067] US35 acceptance criteria locked — AC1+AC2 PASS, AC3 watch, AC4+AC5 deferred
**Type:** rule
**Source:** ken-prompt
**Trigger:** Ken accepted AC as proposed 2026-04-28 18:26 AEST
**What changed:** state/us35-acceptance.json: AC1 PASS, AC2 PASS, AC3 24hr watch, AC4+AC5 deferred to May 28 review. US35 → Done in Notion.
**Why:** Formal acceptance criteria closure for US35 3-tier model strategy implementation.
**Verification:** Ken explicit approval.
**Rollback:** N/A — acceptance decision.
**Linked:** US35 CHG-0048 CHG-0065 CHG-0066
---


## 2026-04-28 16:56 AEST — [CHG-0065] QW batch: SLOs, uptime logging, CI Register, change types, ITIL tags, PRB-001
**Type:** script
**Source:** ken-prompt
**Trigger:** TKT-0003/0006/0007/0008/0009/0010: 6 ITSM quick wins implemented
**What changed:** Operations/SLOs.md (NEW): P1-P4 response times, 99.5% availability target, change management SLOs. state/uptime-log.json (NEW): uptime tracking, SLO compliance. health-check.sh: uptime entry logged on every run. state/ci-register.json (NEW): CI Register / CMDB foundation. RULES.md: change types STD/NRM/EMG documented. 13 Operations docs tagged with ITIL practice headers. state/problems/PRB-001.json (NEW): first Problem record — billing exhaustion root cause, permanent fix implemented.
**Why:** ITSM maturity QW batch — moves ITIL/ITSM framework from L3 toward L4 (measured/managed). SLOs define what we're held to. Uptime logging tracks whether we meet it. CI Register starts CMDB. PRB-001 closes the first problem loop.
**Verification:** health-check.sh: uptime 100% after 1 check. SLOs.md created. PRB-001 filed. 13 docs tagged. All 6 tickets resolved.
**Rollback:** Delete SLOs.md, uptime-log.json, ci-register.json, PRB-001.json. Revert health-check.sh uptime block. Remove RULES.md change types.
**Linked:** TKT-0003 TKT-0006 TKT-0007 TKT-0008 TKT-0009 TKT-0010
---


## 2026-04-28 16:44 AEST — [CHG-0064] Governance gate skip rule approved — Yoda/Ken internal work exempt
**Type:** rule
**Source:** ken-prompt
**Trigger:** Ken reviewed and approved the governance gate control clarification for Yoda-Ken tech stream
**What changed:** RULES.md: governance gate skip rule formalised and approved. Internal trigger = recipient, not producer. Yoda/Ken internal work (scripts, state files, changelogs, commits, private notes) = skip. Any asset leaving Ken+Yoda loop = gate runs. Yoda runs directly, no ask. Aria asks Angie first.
**Why:** Rule was ambiguous — Shield/Lex/Sage Rule 1 said ALL shared assets, but no explicit guidance on when tech stream skips. Ken reviewed and approved the distinction.
**Verification:** Ken explicit approval 2026-04-28 16:44 AEST.
**Rollback:** Cannot roll back an approved rule without Ken re-approval.
**Linked:** CHG-0053 CHG-0054 CHG-0055
---


## 2026-04-28 16:30 AEST — [CHG-0063] Business ROI expansion: campaign tracking, marketing funnel, sales conversion
**Type:** script
**Source:** ken-prompt
**Trigger:** TKT-0021: Ken: track by campaign/initiative lens, post-execution metrics, marketing funnel, sales conversion
**What changed:** state/campaigns.json (NEW): campaign registry with funnel metrics per campaign. state/funnel-metrics.json (NEW): 6-stage funnel definition, sales conversion framework with benchmarks, aggregate metrics. scripts/log-campaign.sh (NEW): create/update/close/list/roi commands. scripts/campaign-debrief.sh (NEW): interactive post-execution debrief — prompts Angie for all funnel metrics, computes ROI. Aria SOUL.md: campaign tracking rules added (mandatory debrief, funnel metric logging). Seed: CAMP-0001 KL Class 30 Apr.
**Why:** Business value rubric tracks activities in isolation. Campaign lens tracks the full journey from cost through funnel to revenue. Required for marketing ROI conversations with investors and clients.
**Verification:** log-campaign.sh new + list working. CAMP-0001 created. funnel-metrics.json with 6-stage definition. campaign-debrief.sh interactive flow tested.
**Rollback:** Delete campaigns.json, funnel-metrics.json, log-campaign.sh, campaign-debrief.sh. Revert Aria SOUL.md.
**Linked:** TKT-0021 TKT-0020
---


## 2026-04-28 16:21 AEST — [CHG-0062] Business ROI framework — value rubric, tracker, Aria integration, weekly cron
**Type:** script
**Source:** ken-prompt
**Trigger:** TKT-0020: Ken: build business stream ROI framework equivalent to tech cost tracking. Aria implements and maintains.
**What changed:** workspace-business/state/business-value-rubric.json (NEW): 5 value categories, 14 subcategories, AUD value per unit, assumptions documented. workspace-business/state/business-roi.json (NEW): running ROI log, summary by category, weekly snapshots, monthly reports. scripts/log-business-value.sh (NEW): Aria calls this after every value-generating activity. scripts/business-roi-report.sh (NEW): full ROI report — business value vs tech cost, ROI ratio, by category, recent activities. workspace-business/SOUL.md: Business ROI tracking rule added (mandatory, non-negotiable). Weekly ROI cron (7a4d8381): Sunday 18:00 AEST, sends Angie plain-language summary, requests confirmation. Seed entries: 6 governance gate passes + 3 blogs + 1 proposal = A$4,000 estimated / 10.7x ROI.
**Why:** Technology cost is binary and tracked precisely. Business value must be tracked with equal discipline using a value rubric. This data foundation enables future investor/client ROI conversations.
**Verification:** business-roi-report.sh: 8 entries, A$4,000 estimated, 10.7x ROI ratio. log-business-value.sh working. Aria SOUL.md updated. Weekly cron live.
**Rollback:** Delete business-value-rubric.json, business-roi.json, log-business-value.sh, business-roi-report.sh. Revert SOUL.md. Delete cron 7a4d8381.
**Linked:** TKT-0020
---


## 2026-04-28 14:53 AEST — [CHG-0061] /frameworks command — operational framework maturity assessment
**Type:** rule
**Source:** ken-prompt
**Trigger:** Ken: keep framework maturity assessment as a living document, trigger with /frameworks
**What changed:** RULES.md: /frameworks command added (L1-L5 maturity scale, 7 frameworks, gaps + opportunities + priority focus). state/frameworks-maturity.json: authoritative maturity registry (all 7 frameworks, gaps, opportunities, priority focus order). scripts/frameworks-report.sh: generates the structured report on demand.
**Why:** Framework maturity is a strategic compass. Ken needs a repeatable command to assess gaps and focus without rebuilding context each time.
**Verification:** bash scripts/frameworks-report.sh → full structured report generated correctly.
**Rollback:** Remove RULES.md /frameworks entry. Delete frameworks-maturity.json and frameworks-report.sh.
**Linked:** TKT-0019
---


## 2026-04-28 14:32 AEST — [CHG-0060] US27: Run Diagnostics phases 7-9 (coverage, performance, predictive)
**Type:** script
**Source:** ken-prompt
**Trigger:** TKT-0019 US27
**What changed:** Added phase 7 (coverage analysis: 35 scripts, 11 crons, 7 state files, 6 agents), phase 8 (performance benchmarks: gateway 0.021s, ollama 0.003s, health-check 0s, model-drift 13s, 11 canvas docs), phase 9 (predictive health: disk 4% GREEN, balance 2.4d AMBER, warden 27 clean, backup 12h GREEN, logs 7 GREEN, cron errors 0 GREEN) to run-diagnostics.sh
**Why:** Complete assurance layer — US27 diagnostics coverage, performance, and predictive health phases
**Verification:** 9 phases ran: 50 PASS, 8 WARN, 0 FAIL. All phases completed without errors.
**Rollback:** Remove phases 7-9 from run-diagnostics.sh
**Linked:** US27
---


## 2026-04-28 14:26 AEST — [CHG-0059] ITSM batch: QW-2 severity flag, QW-3 Standards.md, ITSM-US-007 auto-heal INC, ITSM-US-006 PIR trigger
**Type:** script
**Source:** ken-prompt
**Trigger:** TKT-0019: sprint priority 2 — ITSM quick wins batch
**What changed:** incident-log.sh: --severity P1-P4 flag (non-interactive mode) + severity field in interactive mode. auto-heal.sh: files P4 INC record for every auto-fixed item. pir-trigger.sh (NEW): auto-schedules PIR for P1/P2 incidents, creates state/pir/PIR-*.json, sets system banner. incident-log.sh wired to pir-trigger on P1/P2. Operations/Standards.md: Service Desk roles section added — Yoda = Service Desk Lead, Aria = Business IL, severity tiers P1-P4, first-response script.
**Why:** ITSM discipline — every incident needs severity, every auto-fix needs a record, every P1/P2 needs a PIR, Service Desk ownership must be explicit.
**Verification:** QW-2: incident-log.sh --severity P1 creates INC with severity field. PIR: P1 test auto-created PIR-*.json. Standards.md: Service Desk section added.
**Rollback:** Revert incident-log.sh. Remove pir-trigger.sh. Revert auto-heal.sh INC block. Remove Standards.md Service Desk section.
**Linked:** TKT-0019 QW-2 QW-3
---


## 2026-04-28 14:18 AEST — [CHG-0058] US23 execution: outage handler, updated fallback chain, standby banner
**Type:** script
**Source:** ken-prompt
**Trigger:** TKT-0018 / US23: resilient outage handling sprint
**What changed:** scripts/outage-handler.sh (NEW): validates chain, activates standby-mode.json, writes system-banner.json, logs INC, alerts Ken — fires once on first Anthropic failure, deduplicates. validate-fallback-chain.sh: added Haiku T2 check (LINK 2b) + gemma4:e2b check (LINK 3b), reverted expected chain to 26b (correct — emergency fallback). health-check.sh: wired to call outage-handler.sh on Anthropic fail (non-blocking background). standby recovery: health-check clears standby-mode.json + outage-alert-state.json + system-banner.json when Anthropic recovers. Fallback chain validation cron: hourly (35c8cd08). HEARTBEAT.md: standby banner check added. Validation run: 5/5 PASS.
**Why:** Prevent repeat of Day 2/3 overnight outage. Auto-detect, auto-fallback, auto-alert.
**Verification:** TBD
**Rollback:** Remove outage-handler.sh. Revert validate-fallback-chain.sh.
**Linked:** TKT-0018 US23
---


## 2026-04-28 12:44 AEST — [CHG-0056] AKB daily update cron — 3AM AEST, reads both stream journals
**Type:** cron
**Source:** ken-prompt
**Trigger:** Ken: AKB not updated, not evergreen. Run full pass + create daily cron.
**What changed:** Cron dce1ada4: AKB Daily Update, 3AM AEST, isolated, Sonnet, 10min timeout. Reads technical journal + aria-daily-brief + CHANGELOG. Updates Architecture.md, ModelStrategy.md, GovernanceFramework.md, Company/Overview.md, Decisions.md, context-for-aria.md, yoda-daily-brief.md, HOME.md. Updates Notion Agent Status + Decisions DBs. Git commits both Obsidian and workspace. Logs to state/akb-update-log.json.
**Why:** AKB was last updated 2026-04-25 (3 days stale). ModelStrategy.md, Architecture.md, GovernanceFramework.md all out of date. Daily cron ensures evergreen going forward.
**Verification:** Cron created. Sub-agent running full pass on current stale files.
**Rollback:** Delete cron dce1ada4.
**Linked:** TKT-0015
---


## 2026-04-28 12:01 AEST — [CHG-0055] Governance gate refinement: ask-first, Aria/Angie only
**Type:** rule
**Source:** ken-prompt
**Trigger:** Ken: don't auto-run gate, ask user first. Apply only to Aria and Angie, not Yoda/Ken.
**What changed:** workspace-business/SOUL.md: governance gate changed from auto-run to ask-first. Aria stops and asks Angie to confirm before running gate. Tail options updated (PASS/FAIL/skipped/not-applicable). RULES.md: /governance section updated with refinement note.
**Why:** Auto-running governance on every response is disruptive. User should be in control of when the gate fires. Also scoped correctly to Aria/Angie only.
**Verification:** SOUL.md updated. Behaviour: generate content, assess if governance needed, stop and ask, proceed based on Angie response.
**Rollback:** Revert SOUL.md governance section to auto-run behaviour.
**Linked:** TKT-0017 CHG-0053 CHG-0054
---


## 2026-04-28 11:52 AEST — [CHG-0054] Governance gate wired into Aria + /governance ad-hoc command
**Type:** agent
**Source:** ken-prompt
**Trigger:** TKT-0017: Ken requested Aria governance tail on responses and /governance keyword for Ken + Angie
**What changed:** scripts/governance-report.sh — full gate runner (Shield+Lex+Sage) + executive summary + tail string. workspace-business/SOUL.md — governance gate decision matrix, how to invoke, tail format replacing vague governance section. RULES.md — /governance slash command documented for Ken + Angie.
**Why:** Aria needed executable governance process not vague tagging instructions. Ken and Angie need ad-hoc governance visibility on demand.
**Verification:** governance-report.sh tested on budget proposal: PASS (all 3 gates). report-only mode outputs executive summary. Tail line generated correctly.
**Rollback:** Revert workspace-business/SOUL.md governance section. Delete governance-report.sh.
**Linked:** TKT-0017 CHG-0053
---


## 2026-04-28 11:31 AEST — [CHG-0053] Shield Rule 1 + Lex Rule 1: security and legal assurance gates on all shared assets
**Type:** rule
**Source:** ken-prompt
**Trigger:** TKT-0017: Ken mandated Shield and Lex rules to match Sage Rule 1. Non-negotiable, all agents, both streams.
**What changed:** workspace-security/SHIELD_RULE_1.md locked (5 security checks: credentials, internal exposure, PII, classification, send risk). workspace-legal/LEX_RULE_1.md locked (5 legal checks: contractual, regulatory, liability, IP, disclosures). scripts/shield-check.sh + lex-check.sh (automated pattern scans, LLM-deferred for nuanced checks). sage-qa.sh updated to invoke Shield + Lex as sub-gates. Shield + Lex daily crons ENABLED at 22:00/22:05 AEST. RULES.md updated with both rules. All 3 governance rules documented: Shield->Lex->Sage->Deliver.
**Why:** Sage Rule 1 established QA gate but security and legal checks were missing. Ken mandated all three as non-negotiable. Full governance gate now: Shield->Lex->Sage->Deliver.
**Verification:** shield-check.sh + lex-check.sh tested on budget proposal: both PASS. Crons enabled. Logs initialised.
**Rollback:** Remove shield-check.sh, lex-check.sh. Revert sage-qa.sh. Disable Shield+Lex crons. Remove RULES.md entries.
**Linked:** TKT-0017 CHG-0051
---


## 2026-04-28 11:22 AEST — [CHG-0052] Fix health-check.sh: declare -A, Python bool, lock glob bugs
**Type:** script
**Source:** ken-prompt
**Trigger:** Ken: health alert failed and stale. Script was crashing silently since Day 2.
**What changed:** scripts/health-check.sh: (1) declare -A removed — replaced with plain vars for bash 3.2 compat (cron calls bash not zsh, ignoring shebang). (2) ANTHROPIC_REACHABLE/OLLAMA_API_REACHABLE changed true/false → 1/0 to avoid Python NameError on bool substitution. (3) Python heredoc bool fixed to True. (4) Lock file glob fixed to *.lock(N) to suppress zsh no-match error. Result: state file now writes correctly on every run.
**Why:** health-state.json was last updated 2026-04-26T22:05:43Z — over 27hrs stale. Three compounding bugs caused the Python state writer to fail silently on every run. Haiku cron was correctly silent (consecutiveFailures=0) but status was perpetually degraded.
**Verification:** zsh scripts/health-check.sh → State written: ok. All 9 checks PASS. health-state.json lastCheck updated to current time.
**Rollback:** Revert health-check.sh from git.
**Linked:** TKT-0015
---


## 2026-04-28 11:13 AEST — [CHG-0051] Sage Rule 1: QA gate on all shared/communicated assets
**Type:** rule
**Source:** ken-prompt
**Trigger:** TKT-0016: Ken mandated non-negotiable QA assurance across all agents and both streams after broken PDF formatting
**What changed:** workspace-qa/SAGE_RULE_1.md — full rule spec (5 checks, verdict format, remediation loop). scripts/sage-qa.sh — executable QA gate (checks 4+5 automated, 1-3 LLM-deferred). state/sage-qa-log.json — QA audit trail. RULES.md — Sage Rule 1 added as non-negotiable. budget-proposal HTML — print CSS added for browser-to-PDF. Sage daily review cron enabled.
**Why:** PDF formatting was broken when sent to Ken. This exposed a gap: assets were being generated and delivered without QA. Sage Rule 1 closes this gap permanently. All assets for sharing must pass before delivery.
**Verification:** sage-qa.sh ran against broken PDF: passed checks 4+5. Print CSS added to HTML for clean browser-PDF. Rule locked in RULES.md and SAGE_RULE_1.md.
**Rollback:** Cannot roll back a non-negotiable rule.
**Linked:** TKT-0016
---


## 2026-04-28 10:53 AEST — [CHG-0050] Day 4 sprint: delegation logging, config-009, burn alert, gemma4 shadow fix
**Type:** script
**Source:** ken-prompt
**Trigger:** TKT-0015: 9AM model review report flagged shadow logging broken, config-009, burn rate critical
**What changed:** scripts/log-delegation.sh — 3-tier delegation outcome logger (T1/T2/T3, pass/fail/timeout, savings estimate). state/delegation-log.json — initialised with 3 seed entries. config-009 re-enabled: Aria modelFallbacks=[Haiku, gemma4:e2b] — prevents Opus escalation. Burn alert cron daily 20:00 AEST on Haiku — fires if today > $40 USD. Health check cron wires in delegation logging. Warden cron wires in delegation logging. US22 confirmed already Done.
**Why:** Shadow logging had 0 entries since Day 1 — hook was never wired in. Config-009 drift real: Aria inherited global fallback including Opus. Burn rate $50.99/day vs $500/month cap — need early warning.
**Verification:** Warden 9/9 PASS. delegation-log.json 3 entries. Burn alert cron live 20:00 AEST.
**Rollback:** Remove delegation-log.json, log-delegation.sh. Revert Aria modelFallbacks to None. Delete burn alert cron ca5d5e50.
**Linked:** TKT-0015 US22 US23
---


## 2026-04-28 10:47 AEST — [CHG-0049] 3-tier routing live: route-model.sh, governance cron scaffolding, Haiku extended
**Type:** config
**Source:** ken-prompt
**Trigger:** TKT-0014 actions A+B+C: governance Haiku crons, qwen3 /no_think benchmark, routing framework
**What changed:** scripts/route-model.sh — routing decision engine (T1=Sonnet/T2=Haiku/T3=gemma4:e2b/EM=gemma4:26b). RULES.md — model routing rules section added. Backup cron → Haiku. Shield/Lex/Sage daily review crons created (disabled, Haiku, ready to enable). qwen3:4b /no_think benchmark: consistent timeouts — not viable for Tier 2. Verdict: Haiku 4.5 is sole Tier 2 model.
**Why:** Complete 3-tier routing implementation. Governance agents ready to activate on Haiku. qwen3 ruled out — latency too high even without thinking output.
**Verification:** route-model.sh self-test: 10 routing decisions all correct. Governance crons created disabled. Haiku benchmark remains 8/8 PASS 893ms.
**Rollback:** Remove route-model.sh. Revert backup cron to Sonnet. Delete governance crons.
**Linked:** TKT-0014 CHG-0048 US35
---


## 2026-04-28 10:39 AEST — [CHG-0048] 3-tier model strategy: Haiku 4.5 as Tier 2, qwen3 benchmarked
**Type:** agent
**Source:** ken-prompt
**Trigger:** TKT-0014: Ken approved Haiku 4.5 as Tier 2 after benchmark showed 8/8 PASS at 893ms vs gemma4:e2b 3/8 at 7,224ms
**What changed:** model-policy.json: 3-tier strategy written (Sonnet/Haiku/gemma4:e2b). Haiku added to openclaw.json. Warden cron model Sonnet→Haiku. Health check cron Sonnet→Haiku. qwen3:4b (2.5GB) and qwen3:8b (5.2GB) pulled and benchmarked — inconclusive (thinking mode, needs /no_think re-test). Model strategy hub updated with Benchmark 2, April review, new roadmap. US35 created in Notion. Baseline check-014 added.
**Why:** Haiku 4.5 is 3x cheaper than Sonnet with perfect structured output. Estimated $450-600/month saving on governance/health sub-tasks. Step-up transition before OC2 (3 months away).
**Verification:** Haiku benchmark 8/8 PASS 893ms. Warden cron updated. Health cron updated. Model strategy hub live.
**Rollback:** Revert Warden + Health crons to Sonnet. Remove Haiku from model-policy.json and openclaw.json.
**Linked:** TKT-0014 US35
---


## 2026-04-28 08:37 AEST — [CHG-0047] Gemma4 delegation model: gemma4:26b → gemma4:e2b
**Type:** config
**Source:** ken-prompt
**Trigger:** Benchmark 2026-04-28: e2b 67% pass / 6s avg / ~8GB RAM. Ken approved e2b as standard delegation model.
**What changed:** model-policy.json: e2b = standard delegation model, 26b deprecated for cron use. Cron jobs updated: Midday Cost Tracker + Weekly Asset Review → gemma4:e2b. Both cron prompts prefixed with no-reasoning instruction. gemma4:e4b deleted from Ollama (no benefit over e2b). openclaw.json: e2b registered, e4b removed. SHARED_CONTEXT.md updated. Fallback chain KEEPS 26b (emergency offline path — capability > speed in outage). Warden drift check: 9/9 PASS.
**Why:** e2b = 34% faster, ~2GB less RAM, same quality on delegation tasks. e4b offered no advantage. 26b retained in fallback chain only — most capable local model for outage resilience.
**Verification:** Warden model-drift-check.sh → 9/9 PASS. ollama list confirms e4b deleted, e2b present.
**Rollback:** Restore 26b in cron payloads. ollama pull gemma4:e4b if needed. Update model-policy.json.
**Linked:** TKT-0013 CHG-0045 CHG-0046
---


## 2026-04-28 07:58 AEST — [CHG-0046] Lex (legal agent) model Opus → Sonnet
**Type:** config
**Source:** ken-prompt
**Trigger:** Ken confirmed Sonnet sufficient for legal reviews. Opus exception removed.
**What changed:** openclaw.json agents.list[id=legal].model = anthropic/claude-sonnet-4-6. model-policy.json Lex exception removed. critical-config-baseline config-011 updated. model-drift-check.sh Lex expected value updated.
**Why:** Cost reduction. Sonnet uniform across all 6 agents. No justified need for Opus in legal reviews.
**Verification:** Warden model-drift-check.sh → 9/9 PASS
**Rollback:** Set agents.list[id=legal].model back to anthropic/claude-opus-4-7. Restore exception in model-policy.json and baseline.
**Linked:** TKT-0013 CHG-0045
---


## 2026-04-28 07:54 AEST — [CHG-0045] Warden 🔍 — model compliance and drift monitoring agent
**Type:** agent
**Source:** ken-prompt
**Trigger:** TKT-0013: Ken requested dedicated model governance after 2x drift incidents Day 3
**What changed:** New agent governance (Warden) in openclaw.json. workspace-governance/ + SOUL.md + IDENTITY.md. scripts/model-drift-check.sh (9-check compliance). state/model-policy.json (per-agent model registry, Lex Opus exception documented). state/model-drift-state.json + model-drift-violations.json. Warden cron every 15min isolated. critical-config-baseline config-010 to 013. HEARTBEAT.md Warden escalation check.
**Why:** Two Opus drift incidents Day 3 (Yoda + Aria). No systematic check. Warden provides continuous monitoring, audit, escalation to Yoda.
**Verification:** bash scripts/model-drift-check.sh → 9/9 PASS. Lex Opus documented as intentional exception.
**Rollback:** Remove governance agent from openclaw.json. Delete workspace-governance/, model-drift-check.sh, model-policy.json. Remove cron 83accf7b.
**Linked:** TKT-0013
---


## 2026-04-27 23:48 AEST — [CHG-0044] /close command defined + Day 3 sprint closed
**Type:** rule
**Source:** ken-prompt
**Trigger:** Ken: finalise, update, save and close everything. /close keyword for future sessions. Sprint completion.
**What changed:** RULES.md + SOUL.md: /close slash command added (git commit, memory flush, CHG, Notion update, PVT 9/9, gateway snapshot, summary). US24 closed. US29 closed. Governance agents US closed. 1Password US closed (superseded by macOS Keychain). Gateway snapshot taken.
**Why:** Standardise session close procedure. /close replaces ad-hoc end-of-day cleanup. Ensures consistent state before handoff to nightly crons.
**Verification:** PVT 9/9 passed. Gateway snapshot written. Git committed. All target Notion US marked Done.
**Rollback:** Remove /close section from RULES.md + SOUL.md.
**Linked:** US24, US29, CHG-0039
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

## 2026-04-28 13:47 AEST — [CHG-0057] Aria relay path fix
**What:** Added Rule 5 to `workspace-business/SOUL.md` — correct Aria→Ken urgent message relay mechanism.
**Why:** Aria's credit balance alert at 02:34 AEST never reached Ken. Root cause: `cron wake` is unreliable for sleeping sessions. Alert told Angie "Ken will get this shortly" — but the event was never processed.
**Fix:** Rule 5 mandates using `cron add` with `sessionTarget: "main"` and `payload.kind: "systemEvent"` — fires into Yoda's main session, which is bound to Ken's Telegram. `deleteAfterRun: true`. Wake events prohibited for relays.
**Approved by:** Ken (Telegram, 13:46 AEST)

## 2026-04-28 15:13 AEST — [CHG-0058] Fix Aria→Ken relay path (take 2)
**What:** Replaced broken Rule 5 (cron sessionTarget=main blocked for business agent) with relay queue architecture.
**Why:** CHG-0057 fix was wrong — cron sessionTarget="main" throws error for non-default agents. Aria silently fell back to aria-daily-brief.md and falsely told Angie "Message sent to Ken! ✅"
**Fix:**
- Created relay queue: ~/Documents/AInchors/Shared/relay-to-ken.json
- Created Yoda-side poller cron (id: de5de5f4) — every 5 min, sessionTarget=main, checks queue, delivers unsent items to Ken's Telegram
- Updated Aria Rule 5: correct mechanism = write to relay queue, not cron
**Approved by:** Ken (Telegram, 15:10 AEST)

## 2026-04-28 18:13 AEST — [CHG-0066] US35: Relay poller → Haiku + fix health-check + fallback-chain bugs
**Type:** config + bugfix
**Source:** ken-prompt (sprint grooming US35)
**What changed:**
- Relay Queue Poller cron (7a28cc83): added model=anthropic/claude-haiku-4-5. Was defaulting to Sonnet.
- health-check.sh line 213: zsh glob (N) qualifier → bash-safe glob with -e guard (CHG-0052 class repeat, missed instance)
- validate-fallback-chain.sh: zsh array join ${(j:,:)RESULTS} + ${(j:\n:)BROKEN} → bash IFS join. State file now writes correctly. Fixed unbound variable on empty BROKEN array.
**Verification:** health-check.sh → all 9 checks OK. validate-fallback-chain.sh → ok (0 broken). State file updated.
**Linked:** US35, CHG-0052
