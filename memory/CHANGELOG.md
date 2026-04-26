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
