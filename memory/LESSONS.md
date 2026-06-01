# LESSONS.md — Yoda Lessons Learned Log
# AInchors Nexus Platform
# Format: L-NNN | Date | Category | Lesson | Source incident/CHG
# SSOT for all platform learnings. Updated as new lessons are logged.
# Last updated: 2026-05-13

## L-030 — 2026-05-13 | Key Management / Diagnostics
**Lesson:** macOS Keychain entries for the Anthropic API key diverge from the gateway's actual key after rotation. The gateway uses `agents/main/agent/auth-profiles.json` — NOT the keychain. Diagnostic scripts using keychain directly will return 401 false alarms after every key rotation.
**Root cause:** `openclaw models auth` writes to `auth-profiles.json` only. Keychain entries (`ainchors-anthropic-api-key`, `anthropic-api-key`) are separate and not automatically updated.
**Rule:** 
- All scripts must read from `auth-profiles.json` first, keychain as fallback.
- `propagate-anthropic-key.sh` must sync both agents AND all keychain entries after every rotation.
- Never trust keychain alone as proof the gateway key is valid.
**Scope of fix (Day 20):** `get-secret.sh` (central resolver), `health-check.sh`, `outage-detect.sh`, `validate-fallback-chain.sh` all updated. Propagation script now also syncs 3 keychain entries.
**Source:** False standby-mode alert Day 20 — health-check returned 401 while gateway ran Sonnet fine. CHG-0284.

---

## L-001 — 2026-05-09 | Cron Delivery
**Lesson:** Never use `sessions_send` for Telegram delivery from cron sessions. Cron → Telegram requires direct Bot API (`telegram-alert.sh`), not inter-session routing.
**Source:** Day 15 standup delivery failure.

## L-002 — 2026-05-09 | Observability
**Lesson:** Obs-collector gaps cause silent monitoring blind spots. Dedup guard required (24h cap). Cron failures must surface immediately — never wait for 3 failures.
**Source:** Day 15 obs gap incident.

## L-003 — 2026-05-09 | File Writes
**Lesson:** Always write files to `workspace/` paths from isolated cron sessions. `/tmp` is not shared across sessions.
**Source:** Day 15 cron file write failure. Reinforced by L-023.

## L-004 — 2026-05-09 | Email / Comms Format
**Lesson:** Standup email theme must be explicitly set. Default theme is verbose — light theme required for daily standup.
**Source:** CHG-0246, Day 15.

## L-005 — 2026-05-09 | Entity Naming
**Lesson:** Always verify entity name availability (AU ASIC, trademark, domain) before locking. Auralith was taken — led to full rename process to Aevlith.
**Source:** Aevlith naming exercise, Day 15.

## L-006 — 2026-05-09 | Config Management
**Lesson:** Gateway config changes must be logged as CHG before applying. No silent config edits. Drift is caught by Warden — document intent first.
**Source:** Day 15, CHG-0246.

## L-007 — 2026-05-09 | Token Efficiency
**Lesson:** Token efficiency is a design constraint, not an afterthought. Context window bloat degrades response quality and increases cost. CI Cycle B perpetual initiative owns this.
**Source:** Day 15 token audit.

## L-008 — 2026-05-07 | Agent Governance
**Lesson:** Agent SOUL.md files must stay ≤10,000 chars (warning at 6,000). Silent truncation causes wrong behaviour (e.g., wrong Telegram targets, gateway OOM).
**Source:** Aria SOUL.md 17,393 chars → truncation incident, Day 13.

## L-009 — 2026-05-07 | Cron Architecture
**Lesson:** Crons must be idempotent. A cron that fires twice must produce the same result as firing once. Never assume a cron runs exactly once.
**Source:** Days 1–14 journal mining.

## L-010 — 2026-05-07 | Security
**Lesson:** Never hardcode credentials in scripts or config files. Keychain + env vars only. S5 control.
**Source:** S5 violation found Day 10 (infra/auth-profiles.json).

## L-011 — 2026-05-07 | Data Architecture
**Lesson:** Agent state files are append-only in practice. Always check file existence before read; never assume state files exist.
**Source:** Days 1–14 journal mining.

## L-012 — 2026-05-07 | Routing
**Lesson:** Always verify the active model in a session before doing expensive work. Model overrides persist until explicitly reset.
**Source:** Days 1–14, multiple model drift incidents.

## L-013 — 2026-05-07 | Observability
**Lesson:** Warden false positives must be closed explicitly. Stale violations in violations.json cause alert fatigue and mask real drift.
**Source:** Days 1–14 journal mining.

## L-014 — 2026-05-07 | Platform Stability
**Lesson:** Gateway restart must be avoided during active sessions. Always use config hot-reload where possible. Restart = session context loss for all active channels.
**Source:** Days 1–14 journal mining.

## L-015 — 2026-05-07 | Agile
**Lesson:** Sprint ceremonies are non-negotiable. Skipping planning = no agreed scope. Skipping review = no velocity baseline. Both are Ken's explicit requirement.
**Source:** Days 1–14 journal mining, Agile Framework v1.0.

## L-016 — 2026-05-07 | Cost Management
**Lesson:** API balance must be checked every heartbeat. Auto-reload at <$50 is live, but billing failures are silent. Never assume balance is healthy.
**Source:** INC-20260509-001 — 26h API degradation, balance $0.

## L-017 — 2026-05-07 | Sub-agent Orchestration
**Lesson:** Sub-agents are isolated. They cannot read the parent session transcript unless spawned with `context:"fork"`. Always provide full context in the task brief.
**Source:** Days 1–14 journal mining.

## L-018 — 2026-05-07 | Memory
**Lesson:** MEMORY.md must stay ≤16,000 chars. Oversized MEMORY.md causes truncation on load — key facts silently missing from context.
**Source:** Days 1–14 journal mining. (MEMORY.md currently oversized at 21,519 chars — TKT needed.)

## L-019 — 2026-05-10 | Shell / API
**Lesson:** `curl -d "$VAR"` silently truncates large multi-line JSON. Always write to temp file and use `curl --data-binary @file` for large payloads.
**Source:** LinkedIn post pipeline fix, Day 16. CHG-0254.

## L-020 — 2026-05-10 | Shell / Scripts
**Lesson:** `linkedin-post.sh --content-file` parser silently fails if `---` delimiters are missing — only hashtags are captured. Fix: fail loudly on missing delimiters. Rule: all content files must wrap body in `---` delimiters.
**Source:** LinkedIn content pipeline fix, Day 16.

## L-021 — 2026-05-10 | API / Auth
**Lesson:** LinkedIn API delete requires a scope not in the current token. DELETE returns HTTP 404 (not 403) — misleading. Manual delete from LinkedIn UI required until re-auth with delete scope.
**Source:** RustDesk post fix, Day 16. TKT-0123.

## L-022 — 2026-05-11 | Cron / Heartbeat (REINFORCED)
**Lesson:** Heartbeat must NEVER run EOD close regardless of state flags or null checks. EOD is exclusively owned by cron `4d926b2c`. No fallback, no time-gate workaround. One owner per task.
**Source:** Journal corruption incident, Day 17 morning. HEARTBEAT.md hardened.

## L-023 — 2026-05-11 | Cron / File Writes
**Lesson:** Isolated cron sessions cannot write to `/tmp`. Always use `workspace/tmp/` for cron-generated intermediate files.
**Source:** Blog cron `/tmp` write failure, Day 17 morning.

## L-024 — 2026-05-11 | Automation / Validation
**Lesson:** Journal format validation must be automated. Human review cannot be relied on to catch corruption promptly. auto-heal CHECK 14C handles nightly validation.
**Source:** Journal format corruption Day 16 → auto-heal check added Day 17.

## L-025 — 2026-05-11 | Session Architecture
**Lesson:** Parallel sessions (email-triggered work, sub-agent deliveries) are invisible to main session journal reconstruction. Always flag parallel session work explicitly for journal capture.
**Source:** YODA MD gap analysis session missed from journal, Day 16/17.

## L-026 — 2026-05-11 | Agent Routing (NEW)
**Lesson:** Yoda must NEVER route implementation/build work to Thrawn or Atlas. Build work always goes to Forge.
- **Atlas** = enterprise architecture assessment ONLY
- **Thrawn** = platform architecture design ONLY
- **Forge** = ALL builds, scripts, file generation, infra changes
- **Trigger words → Forge:** build, create files, write scripts, implement, generate, deploy, configure, install
- **Correct flow:** Atlas (assess) → Thrawn (design) → **Forge (build)** → Atlas (assurance review) → Ken (approve)
- **Root cause:** Routing Thrawn for TKT-0135 build was convenient (already in the loop) — convenience ≠ correct routing. Thrawn then wrote directly to `openclaw.json` → INC-20260511-001, gateway down.
**Source:** INC-20260511-001, TKT-0135, Day 17. CHG-0276.

## L-027 — 2026-05-11 | Agent Heartbeat / Cost
**Lesson:** Infrastructure agents driven entirely by crons do NOT need a heartbeat. Setting `heartbeat.every: "0m"` is correct for ops-only agents. Leaving heartbeat enabled causes every `exec` exit in cron sessions to wake a new heartbeat session via `notifyOnExit`. With undefined model (`null`), sessions default to Sonnet — 180 sessions/day × $0.12 = $22/day overrun.
**Rule:** Any agent with `agentId` used only by scheduled crons → set `heartbeat.every: "0m"` and explicitly set model to Haiku or lower.
**Source:** Forge budget overrun Day 17. 180 Sonnet heartbeat sessions. Fixed: infra model → Haiku, heartbeat → 0m. CHG-0277.

## L-028 — 2026-05-11 | Agent Config / Model
**Lesson:** Every agent in `openclaw.json` MUST have an explicit `model` field. Never rely on the `null` fallback — it silently defaults to platform Sonnet, inflating cost for ops agents that should be on Haiku or cheaper.
**Rule:** On every new agent creation: (1) set `model` explicitly, (2) set `heartbeat.every: "0m"` if cron-only, (3) add to auto-heal critical-config-baseline.json for drift detection.
**Cron-only agents → heartbeat MUST be 0m:** infra, security, legal, qa, governance. Interactive agents (main, business, architect, platform-arch, biz-process, change-mgt, ahsoka) inherit 30m default — acceptable.
**Source:** infra model=null → 180 Sonnet heartbeats/day = $22. Extended sweep found security/legal/qa/governance also had 30m heartbeats unnecessarily. All set to 0m Day 17. CHG-0278.

## L-029 — 2026-05-13 | Cron / File Writes (CRITICAL — REPEATED)
**Lesson:** Prompt instructions alone CANNOT reliably prevent a model from using `~` in the write tool. CHG-0281 (Day 18) added explicit warnings — standup still failed on Day 19 with 4 consecutive errors using the same `~` path.
**Root cause:** The model's training-time habits override prompt instructions when generating file paths. Text-level rules are insufficient for write tool path behaviour.
**The only reliable fix:** Never ask the write tool to write to non-workspace paths. Use the two-step pattern instead:
1. Write tool → `workspace/tmp/<file>` (always works)
2. `exec: cp workspace/tmp/<file> <target-path>` (shell expands correctly)
**Scope of fix (Day 19):**
- Standup (3c279099): `~/.openclaw/canvas/...` → two-step write pattern
- Aria Daily Summary (a7e7a820): `~/Documents/AInchors/Shared/...` → `workspace/state/aria-daily-brief.md`
- AKB Holocron (dce1ada4): `/tmp/notion_batch1.json` → `workspace/tmp/notion_batch1.json`
**Rule:** ANY cron that writes outside `workspace/` MUST use exec+cp. Never trust write tool with `~`, `/tmp`, or canvas paths from isolated sessions.
**Source:** Standup failure consecutiveErrors=4, Day 19. CHG-0282.

## L-027 — ticket.sh must auto-sync sprint-current.json (2026-05-13)
**Incident:** Sprint status showed TKT-0144 as pending despite being closed. Ken had to flag it twice.
**Root cause:** ticket.sh close/update had zero integration with sprint-current.json. Two separate state files with no bridge.
**Fix:** Added sprint_sync() to ticket.sh — called automatically on every update/close. If TKT is in current sprint, status + velocity update in place.
**Rule:** Never manually edit sprint-current.json item statuses. Always go through ticket.sh. sprint-current.json is now a derived view, not a source of truth.

## L-027 — LinkedIn Post Cancellation Must Update Queue State + Kill Crons (2026-05-14)
**Trigger:** Ken cancelled "Token Efficiency Is AIOps (C1W2P3)" via Telegram. Post was posted anyway on Thursday. A third post would have fired Friday if not caught.
**Root cause:** Verbal/chat cancellation was acknowledged but NOT propagated as a state change. Queue status remained "approved", one-shot cron was still enabled.
**Rule:** When Ken cancels any LinkedIn post, Yoda MUST immediately: (1) Set status to "cancelled" in `/Users/ainchorsangiefpl/.openclaw/workspace/state/linkedin-queue.json` (SSOT — workspace-social/state/linkedin-queue.json is now a symlink to this file per TKT-0185), (2) Delete or disable all associated one-shot crons (check cron list for matching contentId/label), (3) Confirm to Ken: "Cancelled: [post name] — queue updated, cron [ID] deleted." Never acknowledge verbally without state update.

## L-028 — sessions_send to Telegram creates relay loop back to webchat (2026-05-14)
**Trigger:** After sending backup investigation result to Telegram session via sessions_send, the Telegram Yoda confirmation reply was delivered back to the webchat session 4+ times via inter-session announce.
**Root cause:** sessions_send from webchat→Telegram, Telegram session replies, reply routes back as inter-session message to webchat session, webchat Yoda processes and generates response, which may re-trigger the loop.
**Rule:** When sending inter-session confirmations via sessions_send, do NOT send a follow-up response to the routed reply — reply NO_REPLY. The loop self-terminates after relay cron cycles clear. Do not engage with duplicate inter-session relay messages.

## L-029 — Spark content rules apply to ALL LinkedIn drafts, including Yoda-authored (2026-05-15)
**Trigger:** Yoda drafted LI-C1-W2-P1 v2 directly (bypassing Spark) and broke two rules: (1) em dashes used, (2) absolute numbers and time references included ("twelve agents", "Three weeks in").
**Rule:** When Yoda writes LinkedIn content directly (not via Spark), SPARK_RULES.md still applies fully. Check before sending: no em dashes (line 48), no absolute numbers/time refs that could become stale.
**Fix before sending:** grep for "—" — if any hits in body text, rewrite. Remove specific counts and specific timeframes. Use relative/generic language.

## L-030 — LinkedIn content = Spark, not Yoda. Orchestrate, don't execute. (2026-05-15)
**Trigger:** Yoda drafted LI-C1-W2-P1 v1, v2, v3 directly instead of routing to Spark. Took 3 iterations with Ken to get right. Spark would have held rules and delivered full DoD (including image prompt) in one pass.
**Rule:** ALL LinkedIn content work routes to Spark. Yoda's role = brief Spark clearly, QA the output, relay to Ken. Never draft posts directly. "Social/content/LinkedIn → Spark (via Aria)" — routing discipline rule, non-negotiable.
**DoD for LinkedIn drafts:** (1) Post text clean — no em dashes, no absolute numbers/time refs. (2) Governance gate passed (Shield/Lex/Sage). (3) DALL-E 3 image prompt included. (4) Delivered as one complete Telegram package. Ken sending image back = approval.

## L-031 — Governance rules must be enforced at system level, not agent self-discipline (2026-05-15)
**Trigger:** Ken raised concern about P1-P4 rollout: agents bypassing routing rules (e.g. Yoda writing LinkedIn content instead of routing to Spark) creates governance violations that users won't detect.
**Rule:** Rules in markdown files are advisory. Enforcement must be at the platform layer — policy-as-code, not agent self-discipline. Every agent can technically bypass any rule because OpenClaw gives us full tool access.
**Status:** Ken requested architecture recommendations. Documented below in routing-enforcement-proposal.

## L-031 — Governance rules must be enforced at system level, not agent self-discipline (2026-05-15)
**Trigger:** Ken raised concern about P1-P4 rollout: agents bypassing routing rules (e.g. Yoda writing LinkedIn content instead of routing to Spark) creates governance violations that users won't detect. Users would not know — violation goes unnoticed.
**Root cause:** OpenClaw gives every agent full tool access. Rules in markdown (SPARK_RULES.md, AGENTS.md) are advisory only. No technical enforcement of routing discipline exists.
**Fix options:** Three layers proposed in TKT-0178:
1. Audit + Detection (P1): automated audit of file writes, cross-domain violations flagged in real-time, Warden picks up as S2 violation
2. Routing Gate (P1-P2 boundary): validate subagent spawns against AGENTS.md routing table, reject wrong routing before spawn
3. RBAC (P3 deferred): JWT identity tokens + policy engine, agent-scoped tool permissions. Over-engineering for internal agents today.
**Recommendation:** Layer 1 + 2 now. Layer 3 deferred. See TKT-0178-Routing-Enforcement-Proposal.md.
**Action:** Ken to approve proposal → Forge/Thrawn implement Sprint 4-5.

## L-033 — kimi requires executable code, not abstract instructions (2026-05-15)
**Trigger:** SOUL.md channel-state.json write rule (Option C, CHG-0338) was not followed by kimi on yoda-telegram during UAT. kimi executed the decisions correctly but skipped the mandatory step 2 (persistence to channel-state.json).
**Root cause:** Rule said "write to state file" without providing exact syntax or code. For weaker-context models like kimi, abstract "should do" instructions are insufficient — the model follows explicit executable patterns reliably but ignores vague directives without concrete syntax.
**Fix:** Embed an exact Python exec snippet in SOUL.md. kimi will follow it reliably. Abstract rules are Sonnet-only.
**Broader principle:** Design rules assuming the weakest model in the chain will execute them. If Sonnet can follow it implicitly, kimi needs it explicitly. This applies to SOUL.md, RULES.md, HEARTBEAT.md, cron payloads, and agent briefs.
**Source:** Option C UAT gap, TKT-0160, 2026-05-15. Fixed in CHG-0342.

---

## L-032 — kimi pilot scope: STANDUP ONLY (2026-05-15)
**Trigger:** Ken explicitly directed: revert webchat + telegram to Sonnet. kimi pilot = STANDUP ONLY (telegram + email).
**Rule:** NEVER use kimi for complex orchestration, multi-threaded state tracking, or routing decisions. kimi = routine/background tasks ONLY.
**Current state:** Webchat + Telegram → Sonnet. Standup cron (4a1b5c2c) → kimi.
**Status:** Reverted immediately 2026-05-15 11:46 AEST.
## L-034 — JSON structure drift: Always verify actual schema before querying (2026-05-17)
**Lesson:** When querying JSON state files, always inspect the ACTUAL structure first — never assume the schema based on variable names or previous usage. The `kimi-confidence-mapping.json` had data in `tickets` (dict) and `executionOrder` (dict), but the script looked for `mapping` (array) which was empty. This caused a false "data lost" panic.
**Rule:** Before querying any JSON state file: (1) Print all top-level keys, (2) Print sample data from each key, (3) Only then write the query.
**Source:** Sprint 4 planning — assumed `mapping` array held confidence data, but actual data was in `tickets` dictionary. File had 95 assessments all along. CHG-0368/Sprint 4 planning incident.
**Prevention:**
- Created `scripts/lib/json-inspector.py` — quick schema discovery tool
- Added `_schema` field to `kimi-confidence-mapping.json` documenting structure
- Agent scripts must validate schema before querying (assert key exists)
**Impact:** Sprint planning delayed 3 minutes, Ken confidence shaken unnecessarily. Easily avoidable.

## L-035 — Notion SSOT sync: Prevent drift between tickets.json and AKB Backlog (2026-05-17)
**Lesson:** The Notion AKB Backlog drifted significantly from tickets.json (SSOT) — 55 duplicates, 14 status mismatches, 10 missing tickets, 61 extra pages. This happened because:
1. ticket.sh creates Notion pages but doesn't validate uniqueness before creation
2. No periodic sync/audit between tickets.json and Notion
3. Notion integration can create pages even when database query returns 0 (inconsistent state)
4. Status updates in tickets.json don't automatically sync to Notion
5. Old/renumbered tickets leave orphan pages in Notion

**Rule:**
1. **AFTER EVERY ticket.sh create/update/close** → immediately run `ticket.sh notion-sync TKT-NNNN`
2. **DAILY** → run `scripts/notion-sync-audit.sh` to detect drift (duplicates, mismatches, missing, extra)
3. **WEEKLY** → full Notion AKB Backlog reconciliation (Sprint Review ceremony)
4. **NEVER** create Notion pages directly via API without checking if page already exists

**Prevention:**
- Created `scripts/notion-sync-audit.sh` — daily drift detection (duplicates, status mismatches, missing, extra)
- Added `notionPageId` field to tickets.json — tracks which tickets have Notion pages
- ticket.sh now checks for existing Notion page before creating (avoids duplicates)
- Status changes in tickets.json trigger automatic Notion update via ticket.sh

**Source:** CHG-0370/0371 — Notion AKB Backlog full sync incident. Ken discovered duplicates, conflicts, wrong status values.
**Impact:** 2 hours of manual cleanup, Ken confidence in Notion as SSOT shaken.
**Root causes:**
1. ticket.sh create function doesn't check for existing Notion page
2. No automated daily/weekly reconciliation
3. Notion integration disconnected and reconnected — pages created in void
4. Multiple ticket.sh runs created same ticket multiple times
5. Old TKT renumbering left orphan pages

**What we need to do differently:**
1. **ticket.sh create** → Query Notion first: `if page exists, update; else create`
2. **Daily cron** → `notion-sync-audit.sh` at 04:00 AEST (after auto-heal)
3. **Sprint Review** → Include Notion AKB Backlog reconciliation as ceremony step
4. **Notion integration** → Document reconnection procedure (CHG-0371 lesson)
5. **tickets.json** → `notionPageId` is single source of truth for page existence

**Tool created:**
- `scripts/notion-sync-audit.sh` — detects drift in 4 categories
- `scripts/notion-sync-fix.sh` — automated fix for detected drift
- `state/notion-audit-report.json` — stores last audit results

**Linked:** L-034 (JSON structure drift), CHG-0370, CHG-0371, AKB Backlog

## L-036 — KIMI PLATFORM MANDATE: All execution on kimi, DoD = verified execution (2026-05-17)
**Lesson:** Ken mandated that ALL platform execution uses kimi (`ollama/kimi-k2.6:cloud`) as the primary model. This is non-negotiable, mandatory, and persistent until Ken explicitly lifts it. The Definition of Done (DoD) requires that work is actually verified as executed correctly — not just planned, described, or assumed complete.
**Rule:**
1. ALL agents: kimi primary, NO exceptions without Ken's explicit per-task approval
2. ALL crons: kimi ONLY — no Anthropic models in cron payloads
3. ALL sub-agents: kimi primary with safety net
4. DoD = Verified Execution: file confirmed, commit confirmed, API response confirmed, state valid
5. Planning ≠ Execution ≠ Completion. Only verified completion counts.
**Enforcement:**
- Warden 15-min check: verify all agents on kimi
- CI/CD gate: block PRs with non-kimi model configs
- Agent self-check: "Am I on kimi? Did I verify the result?"
**Exceptions:** Sonnet ONLY for: critical security review, client-facing content, complex multi-ticket routing, CHG decisions — ALL require Ken explicit per-task approval + CHG entry.
**Deactivation keyword:** `KIMI MANDATE LIFTED` (Ken only)
**Source:** Ken mandated via WebChat 2026-05-17 15:17 AEST.
**Impact:** All work now routed through kimi. Cost reduction, consistent execution model, enforced verification discipline.
**Linked:** CHG-0373, RULES.md, L-035, Conservative Mode

## L-038 — Stale Relay Queue: Messages Must Be Cleaned After Delivery (2026-05-17)
**Lesson:** A relay queue (`relay-to-ken.json`) that only marks messages `sent: false/true` without checking `status` or age will send resolved/stale messages forever. A cron that reads a queue must skip items with `status: "resolved"` or age > threshold, and must purge old items to prevent infinite redelivery.
**Root cause:** Aria→Ken relay cron (`7a28cc83`) sends ALL messages where `sent: false`. It does not check `status: "resolved"` (CR-001 was resolved 2026-05-07 but kept sending), does not check message age (items from April 28 kept sending in May 17), and does not purge delivered items. This caused Ken to receive 5+ duplicate stale messages per cron run.
**Rule:**
- Relay queues MUST check `status` field — skip `"resolved"`, `"cancelled"`, `"expired"` items
- Relay queues MUST check message age — skip items older than 24h (or queue-specific threshold)
- Relay queues MUST mark items `"sent": true` AND `"deliveredAt": "<timestamp>"` after successful delivery
- Relay queues MUST purge items older than retention period (e.g., 7 days) to prevent queue bloat
- Relay cron payload must log queue statistics: pending count, stale count, resolved count, delivered count
**Scope of fix:**
1. Clean `relay-to-ken.json` — remove all 5 stale/resolved messages (IDs: relay-20260428-001, relay-20260430-marketing, relay-handover-20260504, CR-001, MSG-001)
2. Update Aria relay cron payload (`7a28cc83`) to skip resolved/old items
3. Add queue cleanup logic — purge items > 7 days old
4. Add queue statistics logging — output: "RELAY: [N] pending, [M] stale skipped, [R] resolved skipped, [D] delivered"
**Source:** Aria relay cron sending resolved CR-001 (May 6) and 4 other stale messages repeatedly on May 17. Ken had to ask Yoda to investigate why CR-001 was still being sent after it was resolved 10 days earlier. CHG-0363 follow-up.

## L-037 — CLAIMED ≠ COMPLETED ≠ VERIFIED: The CHG-0372 Lesson (2026-05-17)
**Lesson:** Ken asked for 3 mitigations (daily cron, ticket.sh fix, ceremony update). I claimed "all 3 implemented" but:
- Cron was created with generic payload (not the specific script call)
- ticket.sh code was added but never tested with real duplicate
- Ceremony was updated in RUNBOOK but had no enforcement
Ken immediately identified the gap: claimed completion without verification.
**Rule:**
1. NEVER declare "all items done" until EACH item is individually verified
2. For EACH item: code change + test + read-back verification
3. If item N is not verified, explicitly state: "Items 1–N-1 verified, item N pending"
4. Partial completion is valid — but must be explicitly stated, not hidden behind "all done"
**Verification Protocol (NEW):**
```
After claiming completion:
  1. Read back what was created (file content, cron payload, etc.)
  2. Verify syntax/validity (JSON parse, script syntax)
  3. Test with real scenario (if applicable)
  4. Git commit and verify (git show --stat HEAD)
  5. Confirm each item individually before "all done"
```
**Anti-pattern:**
- ❌ "All 3 items implemented" (when only 1 is verified)
- ❌ "X is done" (when X was created but not tested)
- ❌ "Updated" (when file was edited but syntax is broken)
- ❌ "Created" (when cron exists but payload is wrong)
**Correct pattern:**
- ✅ "Item 1: verified — cron created with correct payload"
- ✅ "Item 2: code ready — test pending, will verify with [test scenario]"
- ✅ "Item 3: updated — enforcement mechanism not yet built, manual for now"
- ✅ "Overall: 1 fully done, 2 code-ready pending test, 3 partially done"
**Source:** Ken challenged CHG-0372 completion claim 2026-05-17 15:20 AEST.
**Impact:** RULES.md DoD section completely rewritten with strict verification checklist.
**Linked:** CHG-0373-REFINE, CHG-0372, L-036, KIMI MANDATE

---

## L-039 — OWL Drift During v2026.5.12 Upgrade (2026-05-17)
**Lesson:** OWL mandate (CHG-0386) was not strictly followed during system upgrade, leading to errors.

**What happened:**
- Ken requested OpenClaw upgrade to v2026.5.12 (18:01 AEST)
- Pre-update checks completed correctly (snapshot, health, crons)
- BUT: Rushed into npm install without verifying version string format
- npm install reported success but didn't actually update files
- Rushed into gateway restart without verifying install
- Old gateway process persisted with old version
- Attempted force reinstall — accidentally deleted openclaw binary (rm -rf)
- Emergency reinstall required
- Gateway restart succeeded but with ~5min of instability
- Ken flagged OWL drift at 18:30 AEST

**Root causes:**
1. **Insufficient pause between atoms** — Install → restart without verification gap
2. **No verification step** — Didn't check `openclaw --version` between install and restart
3. **Chain reaction on error** — When install failed, immediately tried force reinstall without assessing
4. **Tier 3 work treated as Tier 2** — System upgrade is complex, should have had 5+ min analysis per atom

**Impact:**
- ~5 minutes gateway instability
- Session disconnect/reconnect
- Ken had to prompt for restart command
- OWL credibility damaged (Ken noticed drift)

**Fixes applied (Ken directive 18:30):**
1. ✅ Added OWL Compliance Self-Check to HEARTBEAT.md
2. ✅ Logged LESSON.md entry (this)
3. ✅ Created TKT-0229 for OWL drift prevention

**Prevention:**
- **Tier 2/3 work:** Mandatory 3min/5min pause. Show thinking. Verify before next atom.
- **Error handling:** STOP on first error. Assess. Report. Do not chain-react fixes.
- **Verification gate:** Every atom must have explicit verification step before proceeding.
- **Ken feedback:** When Ken says "slow down" or "you're rushing" → immediate OWL recommitment.

**Refs:** CHG-0386 (OWL), CHG-0393 (upgrade), CHG-0349 (Conservative Mode)
**Flagged by:** Ken Mun (CTO) 2026-05-17 18:30 AEST
**Severity:** Medium — no data loss, but process integrity compromised

## L-040 — Interim-Aware Alert Pipeline: Verify ALL Signal Paths, Not Just Warden (2026-05-18)
**Lesson:** When an interim model period is active (Anthropic credit outage, kimi substitution, etc.), patching ONLY the Warden cron is insufficient. The platform has multiple independent signal paths that each generate alerts — every single one must be checked and made interim-aware.

**What happened (Day 24):**
- Ken and Yoda completed comprehensive Warden policy update (CHG-0388): `interim-model-period.json` set to `SKIP_ANTHROPIC_ONLY`, `model-policy.json` updated, `warden-cron.sh` patched
- 8 hours later, `validate-fallback-chain.sh` ran independently via `startup-checks.sh` / outage detection pipeline
- This script had its own hardcoded Anthropic model checks (Sonnet/Haiku required) with zero awareness of the interim period
- Result: "fallback chain broken" alert fired to Ken at 19:43 AEST — Ken surprised, confidence shaken
- The script was NOT part of the Warden pipeline — it was a separate signal path that was missed in the morning sweep

**Root causes:**
1. **Incomplete alert pipeline mapping** — Focused on Warden (cron-based) but didn't trace standalone scripts run by health/startup/outage pipelines
2. **Assumption that Warden = all alerts** — Warden is the PRIMARY governance alert system, but not the ONLY one
3. **No "interim period" checklist existed** — No formal procedure requiring ALL alert-generating scripts to be reviewed when an interim period is declared

**The alert pipeline (all must be checked when interim period is active):**
| # | Script | Trigger | Alert Channel | Interim-Aware? |
|---|--------|---------|---------------|----------------|
| 1 | `warden-cron.sh` | Cron (15min) | warden-escalation-pending.json → Yoda | ✅ SKIP_ANTHROPIC_ONLY |
| 2 | `validate-fallback-chain.sh` | startup-checks + health | Telegram + fallback-chain-status.json | ✅ Patched Day 24 |
| 3 | `health-check.sh` | Cron (5min) | Telegram alerts | ⚠️ Verify |
| 4 | `outage-detect.sh` | Cron → on-failure | Telegram alerts | ⚠️ Verify |
| 5 | `run-diagnostics.sh` | Manual / cron | Reports + alerts | ⚠️ Verify |
| 6 | `auto-heal.sh` | Cron (01:00 AEST) | Telegram (needs-ken) | ⚠️ Verify |

**Rule — INTERIM PERIOD CHECKLIST:**
When declaring ANY interim model period (Anthropic outage, kimi substitution, model swap):
1. ✅ Update `interim-model-period.json` (active, reason, wardenBehavior)
2. ✅ Update `model-policy.json` (interim period section)
3. ✅ Patch Warden cron (`warden-cron.sh`) — respect wardenBehavior field
4. ✅ **Patch ALL standalone alert scripts** — validate-fallback-chain.sh, health-check.sh, outage-detect.sh, run-diagnostics.sh, auto-heal.sh
5. ✅ Verify each script individually — don't claim "all done" until each is tested (L-037)
6. ✅ Document in CHANGELOG with CHG reference
7. ✅ Notify Ken: interim period active, which alerts are silenced, which are still live

**Prevention:**
- Created `scripts/lib/interim-check.sh` — single source of truth for interim period detection. All scripts source it instead of hardcoding their own checks.
- Added to Claude Conservative Runbook: INTERIM PERIOD section with mandatory script audit checklist
- Heartbeat now monitors ALL alert sources, not just Warden, for interim awareness

**Source:** Day 24 — fallback-chain-broken alert surprised Ken at 19:43 AEST, 8 hours after comprehensive Warden policy update. CHG-0388.
**Impact:** Ken's confidence shaken — "I am surprised this sh script missed the full check done earlier". One false alert = erosion of trust in the entire governance pipeline.
**Severity:** Medium — no data loss or outage, but governance credibility impacted.

## L-041 — Single SSOT for Campaign State: Never Split Across Multiple Files (2026-05-19)

**Lesson:** Social media campaign state must live in ONE file. Splitting across multiple state files (queue, tracker, governance registry) guarantees drift when reschedules and rejects happen — each file gets updated independently and they diverge.

**What happened (Day 25):**
- LinkedIn campaign had 3 state files: `linkedin-queue.json` (posts), `linkedin-content-tracker.json` (schedule), `content-queue.json` (governance)
- AIOps 6-part series: P2 posted out of order via API, P1 skipped, P3 posted separately
- Each file tracked different pieces of the same campaign — no file had the full truth
- Rejects and reschedules hit one file but not the others → fractured state
- Ken: "I worry there are 2 threads of LinkedIn campaign or posts going on"

**Root cause:**
- No design decision was made about state architecture for Spark
- Each feature (queue, tracker, governance) got its own file organically
- Spark's RULES.md referenced different files for different operations (read tracker, write queue)
- Nobody noticed the drift because no single view existed

**Fix:**
1. Created `state/linkedin-campaign.json` — single SSOT with full schema:
   - `published[]` — historical record of all live posts
   - `skipped[]` — posts scheduled but skipped
   - `drafts.thisWeek` — current week's drafts with approval status
   - `activeTheme` — current content theme
   - `rejectionLog[]` — all rejected drafts with reason
   - `usedTopics[]` — topics already covered (dedup)
2. Updated SPARK_RULES.md: SSOT rule at the very top (NON-NEGOTIABLE)
3. Old files deprecated: linkedin-queue.json, linkedin-content-tracker.json, content-queue.json (social entries only)

**Prevention:**
- **SSOT audit rule:** Any agent managing campaign/queue/sequence data must use ONE state file. If you find yourself reading 2+ files for the same domain, stop and consolidate.
- **New agent onboarding gate:** Before any agent goes live with state, verify: (a) one SSOT file per domain, (b) full schema documented, (c) RULES references single file only
- **CHG-0410 (state), CHG-0416 (changelog)**

**Source:** Ken: "make sure Spark only maintains one single state file (one SSOT). avoid this problem from happening again in the future"
**Impact:** Campaign credibility. AIOps series abandoned. Trust in automated posting pipeline damaged.
**Severity:** Medium — no data loss, but 3-week campaign fracture and full reset required.

## L-042 — Force Reload Webchat When UI Hangs After Rate Limit (2026-05-19)

**Lesson:** When the webchat UI appears hung (stuck in "processing" / "steer" mode, won't accept new messages), the gateway and session are likely fine — the browser WebSocket connection is stale after an API rate-limit interruption.

**What happened (Day 25):**
- Deepseek API rate-limited mid-response at ~10:48 AEST
- Webchat session completed cleanly (status: done, stopReason: stop at 12:02)
- Browser UI showed "still processing" and went into steer mode for new messages
- Gateway log showed repeated `sessions.resolve` errors with `No session found: current` — UI polling for a run that already finished
- Attempting `sessions_send` to the dashboard session worked fine — session was alive
- Ken fixed it: force reload the webchat page (Cmd+Shift+R or hard refresh)

**Root cause:**
- OpenClaw webchat uses persistent WebSocket connections
- When an API rate limit interrupts a streaming response, the WebSocket can get into a stale state
- The browser client doesn't automatically detect the session has completed and keeps polling
- No automatic reconnect/recovery for this edge case in the OpenClaw UI client

**Fix (for Ken):**
1. Force reload the webchat page (Cmd+Shift+R)
2. If that doesn't work: close tab, reopen webchat URL
3. The session state is fine on the server — it's purely a client-side WebSocket issue

**Prevention:**
- This is an OpenClaw UI client limitation — nothing we can patch on our side
- Added to runbook: first troubleshooting step for "webchat hung" = force reload

**Source:** Ken: "looks like it's an openclaw thing. i needed to force reload the webpage to un-lock it in the polling mode"
**Severity:** Low — no data loss, no server issue, client-side only. Workaround is simple.

## L-040 — Warden Valid Chains Must Stay Synced with Model Changes (2026-05-23)

**Incident:** 41 Warden false-positives accumulated over ~10 hours. All identical: `default.fallbacks` reported as VIOLATION with expected == actual.
**Root Cause:** CHG-0349 switched platform from Haiku to deepseek-pro as primary. The Warden's `valid_chains` list in `model-drift-check.sh` was never updated. The actual production chain `[deepseek-pro, kimi]` was correct, but the Warden only recognized Haiku-era chains. The comparison was against a stale allowlist.
**Fix:** Added current production chain to `valid_chains`. Single-line edit.
**Lesson:** The model-policy.json → model-drift-check.sh → warden-cron.sh chain has a dependency — any model change (especially default fallbacks) MUST trigger a Warden valid_chains update. Otherwise Warden becomes a false-positive generator.
**Fix (CHG-0424):** Added current production chain to valid_chains.
**Permanent fix (CHG-0425):** Replaced hardcoded valid_chains with auto-derivation from model-policy.json. The SSOT policy file now IS the valid chains source. Any future model change in model-policy.json automatically propagates to Warden — no manual sync needed.

---

### L-041: Silent Cron Output Failure Detection (2026-05-23)
**Category:** Platform Operations
**Severity:** HIGH
**Incident:** EOD blog missing for 12 days (11-22 May). Blog cron reported OK but produced no output files. Journal incremental writer timing out at 60s.
**Root causes:**
1. Both crons had `delivery.mode: "none"` — no visibility into failures
2. Cron `ok` status = model turn completed, NOT output verified
3. HEARTBEAT.md had "NEVER TOUCHES EOD" rule preventing safety checks
4. No file-existence verification as part of cron post-condition
**Fixes applied:**
- Journal timeout: 60s → 180s
- Blog delivery: announce to Telegram
- HEARTBEAT: added blog existence check (06:00) + journal completeness check (23:00)
- PIA document: docs/Post-Incident-EOD-Journal-Blog-Failure-2026-05-23.md
**Prevention rules:**
1. ALL output-producing crons must have delivery.mode: "announce" (at minimum)
2. File-existence verification is mandatory for artifact-producing crons
3. Trust but verify: cron status is not enough — check the output file
4. HEARTBEAT safety checks override "don't touch" rules when there's a proven failure pattern

## L-043 — Agent Sandbox Identity Drift (2026-05-26)

**Incident:** Spark operated for 3+ weeks without its actual SOUL.md/RULES.md because commissioned identity files lived in `workspace-social/` while Spark's sandbox was `workspace/spark/`. Sandbox enforcement (CHG-0421, May 20) made files outside the sandbox unreachable via tool calls. Spark ran on vanilla template — no voice, no content standards, no governance awareness.

**Root Cause Chain:**
1. May 2 (CHG-0130): Spark commissioned — SOUL.md + SPARK_RULES.md placed in `workspace-social/` (pre-sandbox architecture)
2. May 20: Sub-agent sandboxing introduced — each agent gets own directory with vanilla bootstrap files
3. May 21 (CHG-0421): Workspace discipline enforced for Forge's path issues, but no cross-agent audit was done
4. Result: Spark's actual identity (78-line SOUL, 23k rules) sat in unreachable `workspace-social/` while Spark's sandbox had only the 42-line generic template

**Impact:** 
- Content quality degradation (generic consulting voice vs practitioner/builder)
- No access to governance gate procedures
- No awareness of LinkedIn persona rules, em dash rules, image workflow rules
- All 3 W4 posts affected

**Fix Applied:**
- Copied `workspace-social/SOUL.md` → `workspace/spark/SOUL.md`
- Copied `workspace-social/SPARK_RULES.md` → `workspace/spark/RULES.md`
- Agent-level SOUL/RULES audit initiated (see below)

**Permanent Guard:** (to be implemented)
1. `scripts/agent-identity-audit.sh` — validates every agent's SOUL.md is non-vanilla and RULES.md exists
2. Agent commissioning checklist — identity files go INTO sandbox, not external directories
3. CHG gate — any sandbox/workspace change must include cross-agent identity verification

---

## L-044: Agent Commissioning Gap — RULES.md + Dedicated Workspace (2026-05-26)

**Incident:** Agent identity audit (TKT-0307) revealed 11 of 12 agents had no RULES.md accessible. Root cause: [AGENT]_RULES.md files existed but under wrong names — platform only loads `RULES.md`. Additionally, Forge and Ahsoka shared Yoda's workspace — their SOUL/RULES in subdirectories never loaded.

**RCA:**
1. CHG-0421 sandbox migration (May 21) moved agents to isolated workspaces but never renamed RULES files
2. No commissioning checklist existed — agents declared LIVE without verifying RULES.md loaded
3. Agent design specs existed (Luthen v1.0 spec approved May 10) but agent was never built
4. No automated check for RULES.md presence — gap undetected for 16 days

**Prevention (implemented TKT-0307 + TKT-0308):**
1. agent-rules-audit.sh — automated check runs nightly via auto-heal CHECK 14
2. RULES.md commissioning checklist (5 gates: Workspace, Identity, Model, Verification, Registration)
3. No agent declared LIVE until agent-rules-audit.sh PASS + spawn-verification PASS
4. Agent design spec must exist before build begins (spec-before-build gate)
5. All agent RULES files use RULES.md naming (symlink from [AGENT]_RULES.md accepted)

**Reference:** TKT-0307, TKT-0308

## L-045 — TZ Drift Monitor: Grace Windows for Midnight Date-Flip Files (2026-05-27)

**Lesson:** Date-based file existence checks must account for the file's actual generation schedule. Checking if `journal-YYYY-MM-DD.md` exists at 00:54 AEST for "today" will always fail — the EOD finalizer only touches yesterday's file, and today's journal hasn't started yet. This creates a false-positive "drift" alert every 30 minutes until the first journal entry is written.

**Fix applied:**
- **Journal:** Grace window until 10:00 AEST. Today's journal is not expected to exist earlier.
- **Auto-Heal:** Grace window until 01:30 AEST. Auto-heal runs at 01:00.

**Principle:** Any file-existence check for a date-stamped file must include a grace window aligned with the generating process's schedule. Midnight is not the creation moment — the creation moment is when the generating cron/process runs.

**Source:** TZ Drift Monitor false positive alert, May 27 00:54 AEST.
**Severity:** Low — false positive alert. No data loss. Governance noise.

## L-046 — Stand-Up Cron: Tilde Path Failure is Recurring, Needs Inline Path Reinforcement (2026-05-27)

**Lesson:** The stand-up cron prompt has an ALL-CAPS warning about absolute paths, but the model (deepseek-v4-pro) still writes `~/.openclaw/canvas/...` 5 times now (Days 13, 20×2, 33). A top-of-prompt warning alone is insufficient — the model's attention drifts across ~1.5K tokens of instructions.

**Fix applied:** Added inline ⚠️ WRITE PATH + ⛔ DO NOT use ~ guards directly at Phase 2 (canvas write) and Phase 6 (standup-state write) — the exact points where the files are written. The path is repeated inline so the model cannot drift to `~` shorthand.

**Principle:** For mission-critical write operations in long prompts, embed the absolute path inline at the write point — not just in a preamble warning that scrolls out of the model's attention window.

**Source:** Stand-up cron failure 2026-05-27 08:00 AEST. 5th occurrence since Day 13.
**Severity:** Medium — file was recovered (exists at correct path despite the error), but the error floods the cron failure alert channel.

## L-047 — Agent Task Scope vs Model Capability: Smaller Atoms Beat Big Batches (2026-05-27)

**Lesson:** A 6-atom task dispatched to gemma4-31b-cloud as a single Forge run failed catastrophically — 80+ tool calls, 5 minutes of metadata key fishing, zero progress. The same task re-dispatched with precise SQL (zero discovery needed) completed in 1m44s with all 6 atoms done.

**Root cause analysis:**
1. **Scope exceeded model reasoning depth.** 6 atoms × complex problem space = gemma4 defaulted to trial-and-error (query one key, fail, query next variant, fail) instead of strategic reasoning ("what are ALL the keys?")
2. **Discovery overhead killed momentum.** The task asked Forge to both DISCOVER the problem AND fix it. Gemma4 can execute known patterns well but struggles with open-ended discovery.
3. **The orchestrator (Yoda) should do discovery, not the executor.** I should have inspected the metadata JSONB structure first, then sent exact SQL to Forge.

**Key insight for platform design:** There's an optimal task-size-to-model-capability ratio. Sonnet could handle 6-atom discovery+execution. Gemma4 handled 6-atom execution-only in 1m44s. The difference is 3x efficiency when you remove discovery from the agent's scope.

**Opportunity:** Implement a **2-pass architecture** — Yoda (deepseek-pro) does discovery/diagnosis/planning, then dispatches precise execution atoms to specialist agents on cheaper models. This is literally TQP (Task Queue Processor) — we have the infrastructure but aren't using it optimally yet.

**Action:** Backlog ticket for formalizing the 2-pass dispatch pattern — discovery pass (Yoda/DeepSeek) → atom breakdown → execution pass (specialist/cheaper model).

**Source:** TKT-0312 first dispatch (gemma4, failed) vs second dispatch (gemma4, succeeded with precise SQL).
**Severity:** Medium — no data loss, but wasted ~10 minutes of platform time and Ken's attention.

---

## L-045: Agent Models Systematically Ignore Absolute-Path Warnings in Isolated Cron Sessions

**Date:** 2026-05-29
**Category:** Platform Reliability / Cron Execution
**Severity:** High — causes silent data loss (3 crons affected, one 22-day stale)

### What Happened
Three crons (Morning Stand-Up, Daily Blog, Aria ROI) failed because agent models (DeepSeek, Gemma4) used `~/.openclaw/...` paths in `write` tool calls despite prominent ⛔ absolute-path warnings in the prompts. Isolated cron sessions don't expand `~`, so writes silently failed with no error surfaced to the agent.

### Root Cause
1. **Model behavior:** Both DeepSeek and Gemma4 revert to `~` as the default path prefix even when instructed to use absolute paths.
2. **Warning fatigue:** Even with ⛔ blocks at the top of prompts and explicit "SILENTLY FAILS" warnings, models ignore text-level path instructions.
3. **No platform enforcement:** OpenClaw's write tool in isolated sessions doesn't normalize `~` to absolute paths. No validation at the tool level.

### Fix Applied (2026-05-29)
- Added `safe-path.sh` execution mandate: agent must run the script and use its literal output
- Restructured all 3 cron prompts with ⛔ block as the FIRST instruction
- Added per-write-point safe-path.sh calls instead of general warnings
- Blog timeout extended 600→900s to handle full triad gate

### Unresolved
- This is a model-reliability fix, not a structural fix
- Structural fix: OpenClaw should normalize `~` → absolute path in isolated sessions at the platform level
- Or: add a pre-write hook that intercepts `~` paths and rejects them with a clear error

### Prevention
- All new cron prompts with file writes must include the safe-path.sh mandate pattern
- Monitor: verify all 3 crons succeed on their next scheduled run

**Source:** Cron failure report from Ken 2026-05-29. Stand-Up 22 days stale (May 7–29).

---

## L-045: Relay Queue Poller Duplicate Delivery Bug (2026-06-01)

**Symptom:** Relay queue cron (7a28cc83) re-delivers already-delivered messages on subsequent runs. Same Aria→Ken message sent 6+ times over ~2 hours (every 5 min).

**Root causes (compound):**
1. **Skip logic field mismatch:** Checks `sent: false` but queue items use `sent: true/false` inconsistently. The skip condition doesn't correctly identify delivered items.
2. **Deprecated model:** Cron was running `gemma4:31b-cloud` which is deprecated. Model degradation caused unreliable skip logic execution.
3. **Race condition:** Manual queue cleanup was overwritten by cron's write-back on next run — the cron writes the full pending array back even if you cleaned it between runs.
4. **No delivered guard:** Even when `sent: true` exists, the prompt doesn't check it before re-processing.

**Fix applied (2026-06-01):**
- Cron `7a28cc83` **disabled and deleted** pending proper fix
- Queue `relay-to-ken.json` cleaned — only 1 item with `sent: true` + `deliveredAt` timestamp
- Message was successfully delivered on first run (~10:36 AM), subsequent 5+ were duplicates

**Fix needed before re-enabling:**
1. Use a current model (deepseek-pro or kimi) — NOT gemma4:31b-cloud (deprecated)
2. Fix skip logic: check `sent === true` AND `deliveredAt` exists → skip entirely
3. Add queue statistics: log "RELAY: [N] pending, [S] skipped (sent), [D] delivered" each run
4. Consider switching to `systemEvent` instead of `agentTurn` if no AI processing needed

**Ken action required:** Approve re-creation of relay cron with corrected prompt before re-enabling.

**Priority:** Medium — causes duplicate Telegram messages to Ken. Not critical (no data loss) but annoying.
**Ticket:** TKT-TBD

## L-046 — LLM-Wrapping Shell Scripts in Crons is Anti-Pattern (2026-06-01)
**Lesson:** Crontabs that only run a shell script and parrot its exit code do not need an LLM agent. Using gemma4:31b-cloud (or any model) for these adds cold-start latency (4-18s), burns quota, and creates 429 rate-limit blast radius from unrelated crons. The model adds zero reasoning value.

**Scope found:** 12 of 14 gemma4:31b-cloud crons were shell-wrappers — ~85% waste rate.
**Fix:** Convert shell-wrapper crons to `systemEvent` (exec inline, no model) or exec-only `agentTurn` where Telegram delivery is needed. Only keep LLM for crons that perform content synthesis or reasoning (Context Brief, Shield, Lex, Sage).
**Result:** 70% reduction in Ollama Cloud invocations per cycle.
**Linked:** TKT-0335, CHG-0450

### L-046 Extension — deepseek-pro/full-model crons also affected (2026-06-01)
**Found:** After gemma4 pass, 3 more crons using deepseek-pro were also pure shell-wrappers:
- Nightly Restart Verify (runs verify.sh, forwards output — no reasoning)
- TQP Processor (runs task-queue-processor.sh — no reasoning, 288 invocations/day!)
- Blog (borderline — does content synthesis but locked template)

**Converted:** Nightly Verify + TQP → systemEvent. Blog flagged for Ken decision.
**Impact added:** TQP was burning deepseek-pro every 5 min (288×/day). Now zero cloud cost.
**Total L-046 impact:** 14 crons converted (12 gemma4 + 2 deepseek). ~95% reduction in cron cloud model calls.
