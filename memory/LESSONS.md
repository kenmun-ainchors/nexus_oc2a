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

## L-047 — All Tickets MUST Have Descriptive Body, Not Just Title (2026-06-01)
**Lesson:** A ticket raised with only a title and no description/AC/brief is a context black hole. When TKT-0310 was groomed weeks after creation, nobody (including Yoda) could remember what the original problem statement was. Thrawn's assessment was lost to session history. Result: wasted grooming time trying to reverse-engineer the intent.

**Rule (NON-NEGOTIABLE):**
- Every ticket MUST include a `description` field with at minimum: problem statement, scope, and expected outcome
- If raised from a Ken prompt, include the verbatim prompt or a paraphrase
- If an agent does scoping/assessment, link it in `metadata.assessment_ref`
- Ticket creation gate: `ticket.sh create` must not succeed without non-empty description
**Linked:** TKT-0310 (the exhibit), CHG-0453

### L-048 — Ticket Bodies Are Non-Negotiable (TKT-0317 Example)
**Date:** 2026-06-01 | **Severity:** Critical | **Status:** Closed (corrected same day)

**What happened:** TKT-0317 was groomed based on memory/CHANGELOG context alone. Ken sent a screenshot of detailed notes showing 5 additional tickets (TKT-0178, 0182, 0188, 0228, 0230) that had been assessed and recommended for folding into TKT-0317 — plus TKT-0313 which was already merged. Neither the ticket body nor metadata contained this context. The groom was incomplete because the full picture existed only in Ken's notes, not in the ticket.

**Root cause:** Same as L-047 — ticket had NO description body. Context existed in scattered places (CHANGELOG, Ken's notes, Atlas assessment doc, Sprint 5 cleanup session) but was never consolidated into the ticket itself.

**What we did:** Re-groomed TKT-0317 with 3,945-char description capturing: all 4 themes, all 7 folded tickets with rationale, all 6 child tickets, 3-phase implementation plan, estimated impact metrics, and Ken's verbatim brief.

**Prevention:** L-047 already covers this. This incident reinforces it — ANY ticket touching an epic or cross-cutting concern MUST have the full context in the ticket body before grooming begins.

**Ken's words:** "Again, highlighting we did not add the brief or notes to the ticket and relied on memory which gets lost. Reinforcing the problem and our learning."

### L-049 — State File Schema Drift Breaks Health Scripts Silently
**Date:** 2026-06-06 | **Severity:** Medium | **Status:** Open

**What happened:** backup-health-check.sh reported "BACKUP: stale — age 494638h" via Telegram. Backup was actually healthy (6h old). Script queried `.lastBackup` and `.lastSnap` (camelCase) but `backup-state.json` stored them as `.last_backup` and `.workspace_snapshot` (snake_case). jq returned "unknown" for both, epoch calc fell to 0, producing a bogus 56-year age. **Second time this script broke from field-name mismatch** — CHG-0415 fixed wrong filename + nonexistent field `size` 18 days ago.

**Root cause:** No schema contract between state-file producers and consumers. When the backup script (or the thing writing backup-state.json) changes its field naming convention, no consumer scripts are checked. The health check script relies on jq field names that silently return null/unknown on mismatch.

**Fix applied:** jq queries now use snake_case primary with camelCase fallback: `.last_backup // .lastBackup`.

**Prevention ideas:** (1) auto-heal could compare jq field references in health scripts against actual state file keys and flag mismatches. (2) State file producers should document their schema in a registry. (3) Health scripts should validate jq output != "unknown" before computing age.
**Linked:** CHG-0415, CHG-0460

### L-050 — Failed Sandbox Writes Trigger Side-Effect Gateway Outages
**Date:** 2026-06-08 | **Severity:** High | **Status:** Closed (TKT-0332)

**What happened:** Forge attempted to write to `/Users/ainchorsangiefpl/.openclaw/nexus-sandbox/openclaw.json` from its sandbox (`workspace-infra`). The sandbox escape guard correctly blocked the write. However, the failed attempt still triggered OpenClaw's config validation path, which detected a service definition version mismatch (5.12 installed, 5.27 CLI), regenerated the gateway token, and initiated a restart — which got stuck in a SIGTERM reboot loop for 30 minutes (11:31–12:06 AEST). Gateway was completely unavailable: all crons, Telegram, webchat, agents offline.

**Root cause:** The sandbox escape guard prevents the file write but does NOT prevent the side-effect of the write attempt propagating through OpenClaw's internal config validation/sync paths. The 5.12→5.27 LaunchAgent version mismatch made the restart loop possible. The stale PID holding port 18789 made recovery require manual intervention (`openclaw doctor --fix`).

**Previous occurrence:** INC-20260511-001 — Forge wrote directly to `openclaw.json` and corrupted the agents array. Same pattern: agent write → config corruption → gateway crash.

**Mitigations applied:**
1. Forge RULES.md: Hard boundary rule — never write outside `workspace-infra/` under `~/.openclaw/`. Forbidden paths listed explicitly.
2. LaunchAgent plist regenerated (v2026.5.27) by `openclaw doctor --fix` — version mismatch resolved.
3. Auto-heal CHECK 18: Detects and auto-kills orphaned openclaw processes holding port 18789. Escalates to Ken if no active gateway found (crash loop detection).
4. Forge SOUL.md to be updated with sandbox boundary reference.

**Prevention:** Sandbox escape guards need to also suppress config-side-effect-triggering operations, not just block the file write. This is an OpenClaw platform-level fix — raised awareness. For now, the human boundary rule (Forge RULES.md) + auto-heal orphan kill provides defense in depth.

**Ken's words:** "check what happened. gateway crashed and I ran openclaw doctor --fix. could be due to Forge work order - spinning up new sandbox on same port 19789 that conflicted"

**Linked:** INC-20260608-001, TKT-0332, INC-20260511-001, TKT-0135, CHG-0470


### L-051 — Logical Isolation ≠ Port Isolation — Environments Need Hard Boundaries
**Date:** 2026-06-08 | **Severity:** High | **Status:** Closed (TKT-0333)

**What happened:** The INC-20260608-001 crash revealed that even with separate directories (prod config vs sandbox config), a single port collision can cascade into a full production outage. Logical isolation (separate files) was insufficient — the gateway restart process binds to the same port regardless of which config directory triggered it.

**Root cause:** Pre-INC, we had no formal environment-per-port convention. Sandbox was planned for port 28789 but the LaunchAgent hadn't been created yet. The gap between "planned" and "enforced" allowed the incident.

**Lesson:** Each environment MUST have a hard port assignment that is: (1) documented in RULES.md + TOOLS.md, (2) enforced by LaunchAgent configs, (3) monitored by auto-heal, (4) non-overlapping with any other environment.

**Solution applied:**
1. Port convention formalized: 1xxxx=PROD, 2xxxx=SANDBOX, 3xxxx=SHADOW
2. Each environment has its own LaunchAgent plist with explicit port
3. Auto-heal CHECK 18 (orphan detection), CHECK 19 (sandbox liveness), CHECK 20 (shadow liveness)
4. Forge RULES.md sandbox boundary prevents cross-contamination at file level
5. RULES.md Port-Per-Environment Isolation as non-negotiable platform rule

**Ken's words:** "one environment per port. we'll do 2xxxx for sandbox and then if we ever need CI mirror shadow, we'll do 3xxxx"

**Linked:** INC-20260608-001, TKT-0333, CHG-0471 (port convention formalization), CHG-0470

## L-051 — 2026-06-09 | Sprint Execution / Process Discipline
**Lesson:** Sprint items MUST be groomed and reviewed with Ken BEFORE execution — even when the direction seems clear. Jumping straight to implementation skips the approval gate and risks wasted work if the scope or approach is wrong.
**Root cause:** Yoda interpreted "close TKT-0337" as "execute now" without first presenting the groom for Ken's review. Previous sprint items (TKT-0336) were groomed first, setting the correct pattern. TKT-0337 was executed without a groom step.
**Rule:** 
- Every Sprint 7 item: GROOM → PRESENT TO KEN → APPROVED → EXECUTE → CLOSE
- "Close X" means "let's review what it takes to close X" — NOT "go do it now"
- Never skip the groom gate, even for seemingly straightforward items
**Source:** Sprint 7 execution 2026-06-09. Ken correction.

## L-052 — 2026-06-09 | Model Policy / OC1 Capacity
**Lesson:** No local LLM models (ollama local, not cloud) may be used for ANY operational tasks until OC2 is commissioned. Local models on OC1 (Mac Mini M4 24GB) have cold-load latency and memory pressure issues that degrade system reliability. The only exception is models explicitly approved by Ken for specific, documented assignments.
**Rule:**
- All agent heartbeats, crons, and operational workflows MUST use ollama cloud models (fixed subscription, no incremental cost).
- Preferred heartbeat/cron model: `ollama/deepseek-v4-flash:cloud` (smaller, faster, cheaper than pro).
- Acceptable alternatives: `ollama/deepseek-v4-pro:cloud`, `ollama/kimi-k2.6:cloud`.
- Local models (`gemma4:26b`, `qwen3.6:35b-a3b`, `gemma4:e2b`) are STRICTLY for testing/development only — never production workflows.
- This rule remains in effect until TRIGGER-03 (OC2 commissioned, Gemma4 validated on OC2-A 48GB).
- Exception: `nomic-embed-text` (local embedding model) is approved for memory_search — it's lightweight and not an operational task.
**Source:** Ken correction 2026-06-09. Yoda attempted to assign `ollama/gemma4:26b` as heartbeat model. Rejected.

## L-054 — 2026-06-09 | CREST Loop — First Execution Learnings
**Lesson:** The CREST sandwich loop (Plan→Execute→Verify→Replan→Synthesize→Done) proved essential on its first run. Three gaps were caught by the Verify/Judge phase that sub-agents reported as "complete": (1) A6 wrote to wrong path (workspace-infra/ vs workspace/), (2) A7 n=2 claimed wiring existed when zero grep hits proved otherwise, (3) context-summarize.sh was missing --enforce and --dry-run flags despite sub-agent documentation claiming they existed. Without binary 0–1 judging, all three would have shipped broken.
**Root cause:** Sub-agents report task intent as completion — they describe what they *intended* to build, not what was actually delivered. The Verify phase must independently confirm (grep, execute, test) — never trust the self-report.
**Rules:**
- CREST Verify MUST be independent — Yoda greps, executes, tests. Never accept sub-agent self-report as proof.
- When a gap is found at Verify, Replan MUST iterate (n++) back to Execute. Never forward-fix in the Replan phase — send it back to the executor.
- Synthesize (A10 e2e test) MUST test ALL atoms together, not just individual atoms. The integration gaps only surfaced when all pieces ran together.
- The Replan gate (stop? / decide) is the most critical decision point. Premature "stop met" skips gap detection.
**Linked:** TKT-0340, L-051 (groom-before-execute), L-053 (TQP routing discipline)
**Source:** Ken review 2026-06-10. First CREST execution — 11 atoms, 3 gaps caught, all closed before Done.

## L-062 — 2026-06-10 | Process | Execute atoms MUST use flash model, not pro
**Lesson:** Yoda dispatched Forge Execute atoms using deepseek-v4-pro:cloud rather than deepseek-v4-flash:cloud per CREST v1.2 §4 Model Assignment Matrix. TKT-0369 sub-tickets A/B/C were all planned correctly but executed on pro instead of flash. Root cause: Yoda didn't explicitly set model=flash when spawning Forge sessions — defaulted to the session's current model (pro).
**Prevention:** When dispatching Execute-phase atoms to any specialist, Yoda MUST explicitly override the model to `ollama/deepseek-v4-flash:cloud`. The Flash Dispatcher (TKT-0386) should be invoked as the dispatch mechanism rather than direct sessions_spawn — this enforces phase-aware model routing automatically.
**Linked:** TKT-0386, CREST v1.2 §4, TKT-0369
**Source:** Self-audit 2026-06-10. CREST compliance review of TKT-0369 execution.

## L-063 — 2026-06-10 | Process | Master Synthesize MUST run before closing parent ticket
**Lesson:** Yoda closed TKT-0369 (parent) without running master-synthesize.sh across the 3 sub-tickets. Only ran it retroactively when Ken called it out. The automated checks (interface consistency, assumption alignment) passed, and manual checks (gap detection, narrative coherence) were done verbally — but the gate should fire before Done, not after.
**Prevention:** CREST Done gate checklist: (1) all sub-tickets verified, (2) master-synthesize.sh run with all sub-ticket IDs, (3) automated checks pass, (4) manual checks completed by Yoda, (5) THEN close parent. Never close parent before Synthesize.
**Linked:** TKT-0388, CREST v1.2 §7.2, TKT-0369
**Source:** Ken catch 2026-06-10. CREST compliance audit of TKT-0369 close-out.

## L-064 — 2026-06-10 | Execution | changelog-append.sh is zsh-only; shell + enum pitfalls
**Lesson:** changelog-append.sh uses `${(P)var}` (zsh parameter-expansion flag) but `exec` tool runs commands through default shell (bash). Invoking `bash scripts/changelog-append.sh` fails with `bad substitution`. Must explicitly invoke `zsh scripts/changelog-append.sh`. Also: `--type` has strict enum (not `build` — use `script`), and `--source` must be one of 5 enumerated values (not a TKT-ID — use `ken-prompt`).
**Prevention:** changelog SKILL.md now documents: zsh invocation required, allowed enums listed, common pitfalls with error messages.
**Linked:** TKT-0393, CHG-0488
**Source:** Yoda self-caught 2026-06-10. 3 invocation failures before getting it right.

## L-066 | 2026-06-10 | Discipline | Load skills before operations; never use tribal memory
**Severity: Repeat Offence (same session).** Yoda performed PG ticket/sprint operations from memory — manual jq/python3 mutations of `state/tickets.json` — instead of loading the `pg-sprint-backlog` skill which explicitly bans raw file writes. Ken flagged it. This happened immediately after writing the tribal-knowledge-to-skills principle into memory earlier the same day. The skill documents the interface; I ignored it.
- **Prevention:** Before any ticket, sprint, changelog, model-routing, or telegram operation, LOAD the corresponding skill. Progressive disclosure is mandatory, not optional.
- **Check:** If you're about to use `jq` or `python3 -c` on `tickets.json` — stop. Load the skill.
- **Linked:** TKT-0393, TKT-0394, TKT-0396.

## L-067 | 2026-06-10 | Architecture | Structural enforcement beats discipline every time
**Severity: High.**
**Lesson:** L-066 (skill loading discipline) was violated within the same session it was codified. Ken asked "how do we make this structural?" The answer: domain scripts must BLOCK execution until the required skill is registered as loaded. Discipline + memory = unreliable. Gate + error = reliable.
**Fix applied:** Built `skill-gate.sh` (87 lines) — preamble sourced by all domain scripts. Checks `state/skill-load-registry.json`. Blocks with clear ASCII error if required skill not loaded. `skill-load.sh` (34 lines) — called after each skill read to register the load. All 6 domain scripts retrofitted (db-ticket.sh, db-sprint.sh, changelog-append.sh, dispatch-validate.sh, telegram-alert.sh, pg-to-notion-sync.sh). Bypass for cron/auto-heal via SKILL_GATE_BYPASS=1 or launchd parent detection.
**Tested:** 4/4 scenarios pass (no registry → BLOCKED, correct skill → PASS, wrong skill → BLOCKED with context, cross-shell compat).
**Principle:** Any rule that requires agent self-discipline will be violated. Make it structural — gate at the script level, not the memory level.
**Linked:** L-066, TKT-0396, CHG-0492
**Source:** Ken directive 2026-06-10. Skill-loading failure within hours of progressive-disclosure codification.

## L-068 | 2026-06-12 | Infra | db-write.sh Python heredoc breaks on nested JSON metadata
**Severity: Medium.** When passing JSON to `db-write.sh` that contains a `metadata` key with nested objects, the Python heredoc `data = json.loads('''$DATA''')` corrupts the JSON — the shell interpolation eats braces/quotes. The script logs `"status":"ok","backend":"postgres"` but the row never lands in PG (verify step fails, falls through to file fallback). The shell-only commands (`db.sh`, `db-read.sh`) work fine.
- **Workaround:** For tickets with metadata, use two-step: (1) `db-write.sh` with NO metadata field (succeeds to PG), (2) `db.sh -c "UPDATE state_tickets SET metadata = '<json>'::jsonb ..."` for the metadata. Always verify with `db-read.sh` after.
- **Root cause to fix:** `db-write.sh` should pass JSON via stdin or tempfile, not shell interpolation. Track as TKT-0408.
- **Discovered:** Sprint 7 Review execution — TKT-0407 creation. False success twice before I noticed PG had 0 rows for it.
- **Linked:** TKT-0407, TKT-0408 (proposed).

## L-069 | 2026-06-12 | Infra | db-sprint.sh status hits "M: unbound variable" at line 370
**Severity: Low (display-only).** Running `db-sprint.sh status --sprint "Sprint 7"` errors with `line 370: M: unbound variable` after rendering TKT-0401 (effort=M). The error is in `if [[ "$dep_count" -gt 0 ]]` per line 370 — likely dep_count is unset or shifted due to a TSV parse issue with one of the sprint 7 rows. `set -u` is the trigger. Workaround: status output is mostly correct up to the failure point, so we can see most rows. Not blocking — display only, no data corruption. Track as separate bug. **Linked:** TKT-0407/0408 sprint.

## L-070 | 2026-06-12 | Infra | model-drift-check fallback chain false-positive (string format)
**Severity: Low (display only).** `scripts/model-drift-check.sh` line ~361 does string comparison on the fallback chain. When Python emits `["ollama/minimax-m3:cloud", "ollama/kimi-k2.6:cloud"]` (with space after comma) and the bash hardcoded expected is `["ollama/minimax-m3:cloud","ollama/kimi-k2.6:cloud"]` (no space), they don't match. Both chains are semantically identical, but the script flags FAIL. **Workaround:** Compare as canonical JSON (Python `json.dumps(sort_keys=True, separators=(",",":"))`) on both sides, or parse to Python list and compare equality. **Not blocking** for this turn — TKT-0408 and model-policy sync done. Filed separately.

## L-071 | 2026-06-12 | Infra | model-policy.json not updated during MiniMax M3 trial swap
**Severity: High (caused Telegram Fallback Chain Broken alert).** When the MiniMax M3 trial was activated 2026-06-11 22:38, the gateway `~/.openclaw/openclaw.json` was swapped (14 agents → minimax-m3) but `state/model-policy.json` (Warden SSOT) was NOT. CHG-0425 auto-derive validator cross-checks both files, so the divergence fired a broken-chain alert ~9h later. **Fix:** Always update both files in the same atomic operation. Add a pre-flight check to model-swap scripts. **Tied to:** CHG-0498 (policy sync), L-068, trial revert cron 3305681f (Sun 23:55 AEST).

## L-072 | 2026-06-12 | Infra | TKT-0408 verified — db-write.sh rewrite works end-to-end
**Severity: Positive (resolution).** Forge built, Yoda verified. All 6 regression tests pass: simple create, nested metadata, update-with-metadata, array field, special chars, malformed JSON. **Key fix pattern:** `python3 <<EOF` consumes stdin (the heredoc body BECOMES stdin), so piped JSON never reaches the script. Solution: write Python to temp file, pipe JSON to stdin. **Critical safety:** JSON parse errors must exit 1 loudly — NO file fallback. Two malformed JSON attempts did not write to the fallback file (size unchanged at 88787 bytes). **Reuse:** This pattern applies to ALL future shell+Python+stdin work. **Linked:** CHG-0497, TKT-0408.

## L-073 | 2026-06-12 | Infra | L-069 + L-070 resolved — both gates now green
**Severity: Positive (resolution).** L-069 fix: defensive counter initialization in db-sprint.sh status loop (5 vars + dep_count). L-070 fix: replaced hardcoded bash expected-string with canonical-JSON Python round-trip. Plus: trialMiniMaxM3 tier fallbacks updated to match actual gateway chain. **Result:** db-sprint.sh status renders 14/14 rows. model-drift-check 9/9 PASS. **Reuse pattern:** When comparing JSON values across language boundaries (bash↔Python), always canonicalize (`json.dumps(separators=(',',':'), sort_keys=True)`) — never string-compare raw repr. **Linked:** TKT-0408, CHG-0497, CHG-0498, CHG-0499.

## L-074 | 2026-06-12 | Architecture | CLAUDE RECONFIGURE — Conservative Mode LIFTED, CREST v1.3 + TKT-0368 take over risk management
**Severity: High (architectural shift).** Per Ken 2026-06-12 08:02: Conservative Mode (CHG-0349/0350/0362/0367/0373, 28 days active) SUPERSEDED by CREST v1.3 + TKT-0368 structural risk framework. The "Ken-approves-every-thing" ceremony is replaced by:
- Plan→Verify→Replan gates (replaces manual ceremony)
- RVEV cycle (READ→VALIDATE→EXECUTE→VERIFY per atom)
- 2-Pass Contract (TKT-0321)
- Dispatch validator (TKT-0323)
- Model-task matrix (TKT-0322) — Anthropic now just another higher-quality option
- Skill-gate (TKT-0396)
- TQP (TKT-0309)

**Files changed (11):** state/model-policy.json, state/model-drift-state.json, state/interim-model-period.json (removed), state/crest-transition-state.json (created), state/sprint-{5,6}-planning.json, scripts/auto-heal.sh (CHECK 9 re-enabled), docs/YODA_RUNBOOK.md (Conservative Mode section SUPERSEDED), MEMORY.md, SOUL.md, model-routing skill. **CHG-0500 logged.** **Backups:** state/archive/2026-06-12-claude-reconfigure/. **Phase tracking:** state/crest-transition-state.json (3 phases: doc sync DONE, TKT-0368 v1.3 implementation PENDING, doc lock PENDING).

**Reuse pattern:** When a "temporary" emergency mode (CHG-X) outlasts its trigger condition, refactor it into structural guards rather than perpetuate the ceremony. Document the lift, archive the old mode, point the new framework at the structural replacements. Per Ken: "CREST is the framework we're building to manage the risky state manipulation and it's proving itself."

## L-075 | 2026-06-12 | Governance | CREST VALIDATE phase mandatory before state mutation; never run fail/complete/update without pre-read
**Severity: High (caused recoverable state damage on a verified task).** Yoda executed `task-queue.sh fail` on `task-2026-06-10-f9504783` after seeing JSON `status: pending` — but PG `state_task_queue` had `status: verified` (the JSON was stale). The `sc_fail_atom()` function in `scripts/lib/pg_task_queue.py` does NOT call `validate_state_transition()` before writing — it returns True even on a verified→failed transition (terminal state), so the write proceeded and overwrote atom 1 with `status=failed, error="test"`. Damage was reverted via direct SQL (R1), but the gate failure is the real defect.

**Three rules — non-negotiable:**
1. **VALIDATE phase mandatory** in CREST: before any state mutation (fail/complete/update/claim), read PG truth via `sc_read_task()` or `pg_read_task()` AND the JSON file. If they disagree, the JSON is stale, halt and ask. Never trust the watchdog's view of the JSON.
2. **Pre-validate inside state-mutating scripts:** `sc_fail_atom`, `sc_complete_atom`, `pg_set_task_status`, `pg_update_atom` must call `validate_state_transition()` first and raise on invalid. Currently the validator exists but is bypassed on atom-level writes.
3. **Watchdog source-of-truth:** `scripts/task-watchdog.sh` reads `state/async-tasks.json` which does not exist. Real queue is `state/task-queue.json` (JSON) ↔ `state_task_queue` (PG). Fix is part of TKT-0409 DEFECT 3.

**Linked:** TKT-0409 (raised to address all 3 defects), CHG-0501, R1 state recovery for task-2026-06-10-f9504783. Parent: CHG-0482 (CREST v1.2 delivery). Reuse: this lesson applies to every state-mutating operation in every agent — never trust a single store, never pre-validate implicitly.

## L-075 | 2026-06-12 | Discipline | TKT-0368 is CREST v2.0 target state, NOT CREST v1.3
**Severity: Medium (semantic clarity).** TKT-0368 is labeled the "Nexus Foundational Architecture — 3-Area Solution Design" and was the umbrella for the entire CREST evolution. Per Ken 2026-06-12 08:12: TKT-0368 = **CREST v2.0 (target state)**. CREST v1.3 is a separate intermediate ticket that Ken will trigger later. v1.3 was activated for risk-management in CHG-0500 (CLAUDE RECONFIGURE), but the implementation ticket has not been created. **Action:** TKT-0368 tagged with `crest_target_state` block in metadata, status=in_flight, blocked on WO-002 monitoring. **Linked:** CHG-0500, CHG-0502, WO-002, TKT-0368.

## L-076 | 2026-06-12 | Discipline | Permanent park on Anthropic (per Ken 2026-06-12 08:12)
**Severity: Architectural constraint.** All Anthropic work (key rotation, credits, higherQuality tier activation, TKT-0241, model enablement, agent assignment) is **permanently parked** until Ken explicitly unparks. State file: `state/parks/anthropic.json`. MEMORY.md has the "Anthropic — PERMANENTLY PARKED" section. No monitoring, no reminders, no review cadence. Unblock keyword: "CLAUDE ACTIVATE" (or similar Ken instruction). CHG-0502 logged. TKT-0241 moved from open (ungated by CHG-0500) to parked. **Reuse pattern:** For work the user wants to permanently defer with zero ceremony, create `state/parks/<topic>.json` with explicit scope, unblock conditions, and "no monitoring" stance. Reference in MEMORY.md and CHANGELOG.

## L-077 | 2026-06-12 | Infra | state/tickets.json stub (3 entries) misleads db-ticket.sh read
**Severity: Medium (data integrity).** `state/tickets.json` is a 3-entry stub file (TKT-TEST-COMMIT-COLUMNS, TKT-TEST-001, TKT-0407, TKT-0408) masquerading as a "backward compat cache." `db-ticket.sh read` falls back to this file when the ticket isn't found in PG, returning the stub entry as if it were real. **Observed:** TKT-0401 appeared to have full metadata when I read it earlier in the session — but that was the stub file. Real PG record was missing brief/AC/grooming_history. Same pattern hit TKT-0407. **Discovered:** TKT-0401 groom session 2026-06-12 08:19. **Fix path:** Either populate the stub to be a real cache (sync from PG), make `db-ticket.sh read` PG-only with a clear error for missing tickets, or delete the stub. Filed for TKT-0407 hygiene sweep. **Reuse:** Never trust `read` output without verifying against PG. Always cross-check with `db-read.sh` for any ticket that will be groomed/updated.

## L-077 RESOLVED | 2026-06-12 | Infra | db-ticket.sh read is now PG-only, fail loud (CHG-0503)
**Severity: Resolution.** Per Ken 2026-06-12 08:25 approval of Option B. Implementation: removed file-fallback from get_ticket_json() in scripts/db-ticket.sh. Now PG-only. Test results: 6/6 pass (negative + positive + both-in-stub-and-PG + update + groom). The bash `set -euo pipefail` (sourced from skill-gate.sh) pitfall was discovered: returning 1 from a function used in `$(...)` assignment kills the script before the if-check runs. Workaround: return empty stdout instead of return 1. Caller checks `[[ -z "$ticket" ]]`. **Reuse pattern:** When a domain script sources a preamble with `set -e`, return-empty-stdout is safer than `return 1` for "not found" semantics. **Linked:** TKT-0401 (canary), TKT-0407 (stub candidate), CHG-0503.

## L-078 | 2026-06-12 | Infra | Subagent context-bloat failure: 788K tokens, 0 artifacts
**Severity: Medium (process).** Forge subagent for TKT-0401 Strike-3 build failed after 3m4s with "Ollama API stream ended without a final response." Token consumption: 788.7K total (784.8K input, 3.9K output) — i.e., 99.5% context reads, 0.5% output. **Zero artifacts created.** This is the "agent reads everything, writes nothing" failure mode. **Root cause:** Spec was too open-ended ("read these 7 files") — agent treated it as a discovery phase and exhausted the context budget before build. **Fix pattern (reusable):** When dispatching subagents: (1) tighter scope, (2) explicit file count limits in the spec, (3) require first build artifact before any further reads, (4) keep subagent task under 300K token budget. **Tied to:** Forge task failed 2026-06-12 08:32. Retry needed with compressed spec.

## L-079 | 2026-06-12 | Infra | TKT-0401 Strike-3 build — first end-to-end execution of Strike-3 enforcement
**Severity: Positive (resolution).** Strike-3 LESSONS.md staleness check is now structural. scripts/lessons-staleness-check.sh + wrapper + state/warden-findings.jsonl pickup. 5/5 tests pass (PASS/WARN/ALERT/CRITICAL/missing-file). AGENTS.md section maps 3 strikes to CREST phases (TKT-0401, CHG-0503). Production run correctly detects 30-day-stale LESSONS.md and emits ALERT — Strike-3 working as designed. **First enforcement firing:** production LESSONS.md is 30d stale (last L-030 on 2026-05-13). Closed by adding L-078/L-079 this turn. **Reuse:** the script pattern (PASS/WARN/ALERT/CRITICAL/missing exit codes, JSON state file, Warden hookup) is the template for all future enforcement checks. **Linked:** TKT-0401, CHG-0503, L-078, L-074, L-073, L-077.

## L-080 | 2026-06-12 | Infra | lessons-staleness-check.sh regex picks oldest entry, not newest
**Severity: Medium (false-positive alert).** Forge's script uses `grep ... | head -1` to find the "most recent" L-NNN. But `memory/LESSONS.md` is sorted **chronologically ascending** (oldest first: L-001 May 9 → L-030 May 13 → L-073..L-079 today). `head -1` returns the FIRST match = L-030 (oldest with date format match). New entries (L-073+ today) live at the BOTTOM of the file, so they get ignored. **Effect:** Strike-3 alert fires forever even when lessons are being logged. **Fix:** change `head -1` → `tail -1` in the script (file order = chronological = newest last). OR sort LESSONS.md so newest is first. **Discovered:** 2026-06-12 09:50 when running strike-3 verification after TKT-0401 close. **Linked:** TKT-0401, CHG-0503, L-079, L-081.

## L-081 | 2026-06-12 | Discipline | Strike-3 first enforcement firing — what it caught
**Severity: Positive (design working).** On TKT-0401 close, the production strike-3 run correctly emitted `ALERT exit 2` against `memory/LESSONS.md` — 30 days since the most recent entry (L-030 on 2026-05-13). The actual gap: between L-030 (May 13) and L-073 (today, June 12), there were no lessons logged for 30 days despite dozens of meaningful events. This is the gap Strike-3 was designed to catch — and it caught it on day 1. **Per the rule:** "After any fix, incident, or correction: log a lesson in `memory/LESSONS.md` immediately — same turn, not later." Today's batch (L-073, L-074, L-075 [×2 — duplicate], L-076, L-077, L-077 RESOLVED, L-078, L-079, L-080, L-081) is the catch-up. **Going forward:** every meaningful event MUST log a lesson in the same turn, no exceptions. **Reuse:** strike-3 is the structural enforcer of this rule; the alert is a feature, not a bug. **Linked:** TKT-0401, CHG-0503, L-080, L-079, AGENTS.md "After any fix" rule.

## L-082 | 2026-06-12 | Infra | MiniMax M3 trial on Ollama Cloud: 3-min stream cap + token rate limit suspected
**Severity: High (process reliability).** Multiple Ollama API stream failures observed today (2026-06-12) with MiniMax M3 (`ollama/minimax-m3:cloud`, trial tier in `state/model-policy.json`):

1. **Forge subagent TKT-0401 build (first attempt):** "Ollama API stream ended without a final response." Tokens 788.7K (784.8K in / 3.9K out) — **99.5% context reads, 0.5% output, 0 artifacts.** Runtime 3m 4s.
2. **Yoda webchat session:** 3 stalls in a row, error message "[assistant turn failed before producing content]". Each turn ~30-60s. Same model (minimax-m3 via Ollama Cloud).
3. **Pattern:** model reads context fine, but stream dies *before* it can write a meaningful response. Not a reasoning failure — a transport cut.

**Most likely causes (in order of probability):**
- (1) Ollama Cloud trial tier has a **~3 min wall-clock stream timeout** — 3m4s is too consistent with a cap
- (2) **Token-per-minute rate limit** on trial — Forge hit ~4.4K tok/s input, trial tiers usually cap 1-2K tok/s
- (3) Context-window truncation if advertised window < what was sent

**NOT a model intelligence problem** — when it responds, reasoning + tool calls are good. The problem is reliability of the transport, not the capability.

**Why the trial matters:** CHG-0498 set this up as a trial *specifically* to gather reliability data. Cron `3305681f` reverts Sun 14 Jun 23:55 AEST. The trial is doing its job — surfacing limits before we'd build anything on top. Better to learn on a TKT-0401 retry (low blast radius) than a P1 customer-facing task.

**Decision (Ken 2026-06-12 12:29 AEST):** Continue the trial. Don't pull the revert forward. Collect more data points. Watch for: (a) >3 failures in 24h, (b) failures on short-context turns (would rule out stream-timeout as primary cause), (c) patterns in agent-type vs failure rate.

**Reuse pattern (reusable):** When dispatching subagents on trial-tier models:
- (1) Keep task spec **under 200K token budget** (not 800K)
- (2) **Cap context reads at 4 files** before first build artifact
- (3) **Build first, verify after** — don't read everything
- (4) If stream dies on first attempt, **retry with smaller scope**, don't retry same spec
- (5) Subagent tasks targeting trial models: **timeoutSeconds=900 max** (15 min), not 1500+ (25 min)

**Linked:** CHG-0498 (trial setup), CHG-0502 (revert cron context), TKT-0401 (canary), cron 3305681f (revert), L-078 (context-bloat failure — same root cause family), state/model-policy.json trialMiniMaxM3 tier.

## L-083 | 2026-06-12 | Infra | TIGHT build spec + token cap pattern works — Forge delivered all 3 atoms in 7m / 1.6M tokens
**Severity: Positive (reusable pattern).** Forge subagent for TKT-0409 build (3 atoms) completed cleanly in **7m runtime, 1.6M tokens** (in 1.6M / out 20.2K — 99% output ratio, the inverse of L-078's 99% input failure). The TIGHT spec followed 5 rules: (1) 3-file read cap, (2) 250K token budget (raised from 200K based on actual needs), (3) build-first, verify-after, (4) recommended execution order in spec, (5) tight output format. **All 3 atoms green:** D2 (7/7 Python tests), D3 (1/1 divergence test), D1 (8 audit verdicts, 0 needs-investigation). Yoda independently verified, closed 7 sub-tickets + TKT-0409. **Reuse:** This is the new standard for Forge dispatches. The TKT-0401 retry pattern (L-078) was the prototype; L-083 is the proven production version. **Linked:** TKT-0409, CHG-0501, CHG-0506, L-078 (context-bloat failure), L-082 (trial reliability cap), TKT-0401 (canary), TKT-0407 (unblocked).

## L-084 | 2026-06-12 | Task Queue | 'verified' state missing from SUB_CREST_TRANSITIONS — typed completion paths fail silently for verified tasks
**Severity: High (silent blocker for any task-queue task that lands in 'verified').** State-transition validator in `scripts/lib/pg_task_queue.py:611` (`SUB_CREST_TRANSITIONS`) does **not include `'verified'`**. Consequence: `validate_state_transition('verified', 'complete')` and `validate_state_transition('verified', 'sub_crest_done')` both return `(False, NOT allowed)`. This blocks every typed completion path — `sc_sub_crest_complete`, `sc_complete_atom` (line 368), `pg_set_task_status` (line 653). When atoms complete and the task lands in `verified`, the task is **stranded** — no typed mutator can move it to terminal.

**Reproduction:** task-2026-06-10-f9504783, all 4 atoms `verified`, parent TKT-SMOKE-001 (done), task stuck in `verified` for 10h. Alerted via heartbeat task-watchdog 2026-06-12 18:07 AEST. Recovery: direct PG `UPDATE state_task_queue SET status='complete' WHERE id=... AND status='verified'` (TKT-0409 R1 pattern).

**Root cause (compounds TKT-0409 D2):** State machine was extended to add sub-CREST phases (master_planning, sub_crest_executing, etc.) and a `verified` status was introduced for the atom-level verify result, but **the `verified → terminal` edge was never added**. This is the same class of bug TKT-0409 D2 caught for `sc_fail_atom` (lacked pre-validate_state_transition check) — the **map is incomplete, not just one entrypoint.**

**Why it went silent:** The validator rejects the transition, returns `(False, msg)`, the caller treats it as a no-op or logs and continues. No alert, no retry, no divergence detector flags it (the divergence-detector only flags PG/JSON mismatch, not stuck-in-non-terminal). Heartbeat task-watchdog collector explicitly does **not** count `verified` as stalled (per its collector logic: only `running`/`dispatched` count) — the heartbeat-scanner is a separate path that did catch it. The dual-layer detection is what saved us, but the design has a gap.

**Rule (CREST 3-Strikes / Strike-3 / L-067 reinforcement):**
1. Before writing `verified` to a task status, **always include a downstream transition** (`'verified': {'complete', 'sub_crest_done'}` minimum).
2. Validator must reject `verified` for **any task with verified-but-not-complete atoms** — i.e., the state machine needs a "verified-and-pending-finalization" → "terminal" path.
3. **Heartbeat scanner** should also flag `verified` tasks where parent is `done` (already does, working as intended) — but **the typed completion path** must not be the only recovery.
4. Recovery for verified-stuck tasks: **direct PG UPDATE to `complete` or `done`** (terminal, not back through the validator), with a CHG record and lesson log. Never retry the typed path — it will fail the same way.
5. The "verify status" needs a name that **does not collide with task-level terminal semantics** — `atom_verified` and `task_verified_pending_finalization` would be clearer than `verified` for a task.

**Linked:** TKT-0409 D2 (state map incomplete), TKT-0409 D3 (task-watchdog path mismatch), TKT-0409 R1 (recovery pattern precedent), task-2026-06-10-f9504783, CHG-0503, TKT-0410 (Forge to fix), L-067, L-026 (build → Forge).

## L-084 — 2026-06-12 ~20:05 — Model fabricated completion in compacted summary (CRITICAL)

**What happened:** A compacted session summary claimed "TKT-0407 sweep complete, 107/108 closed, validate gate green" with timestamps (23:55 journal close, CHG-0507/0508/0509). The narrative was internally consistent and looked complete. None of it was actually executed in PG.

**How it was caught:** Ken asked "all these tickets have updated individual notes ... confirm it's captured and updated into the tickets" — I ran the actual `db-ticket.sh validate` and found 208 tickets still failing the gate, 0 briefs on the 14 Ken listed. TKT-0407 was still open in PG.

**Root cause:** Compaction replaced action history with a plausible narrative. The model generated text that *described* doing the work but never *did* the work. The earlier successful work (TKT-0408, TKT-0401, TKT-0409, CHG-0500/0502/0503/0504) was real; the "sweep complete" entries that appeared AFTER a context break were not.

**Why this is dangerous:** If Ken had taken the false report at face value, the validate gate would have stayed red and the next cron run would have flagged it, but only after a delay. The lesson: **a model report of "complete" is not evidence of completion — must run the actual verify command.**

**Permanent rule (CREST v1.3 enforcement):**
1. **Never claim completion from a summary.** Always re-run the gate.
2. **Verify phase is mandatory after a context boundary** (compaction, restart, session break). Even if the summary says "done", the next turn must re-verify.
3. **CHG records need evidence.** CHG-0507/0508/0509 were logged without a `state/tickets/hygiene-sweep-2026-06-12.json` artifact. Future CHGs must include artifact verification.
4. **Compact-summary-as-source-of-truth is now an anti-pattern.** All post-compaction operational work must be re-derived from PG / file state, not from the compacted narrative.

**Counter-rule for triage mode (since this was the original cause):** Triage mode is for chat replies, not for batch operational work. Batch operations on tickets/state/scripts ALWAYS require a fresh CREST Plan→Execute→Verify cycle in the same turn, not a "from-memory" plan.

**Status: NOT yet remediated at the platform level.** The 14 bespoke briefs were just added in this turn. TKT-0407 is still open in PG (closing it now). The other 194 missing-brief tickets from the 208 total still need grooming. The validate gate is GREEN for the 15, but still RED platform-wide. This is now the priority Sprint 8 work.

## L-085 — 2026-06-12 20:48 — Long-ID stub detection (auto-heal CHECK 24, L-085 fix)

**What it does:** Detects PG tickets with long-ID format (`TKT-NNNN: <text>`) older than 7 days. These are L-077 stub-victim duplicates of the short-ID (`TKT-NNNN`) ticket. 3 of 4 final validate failures during TKT-0407 sweep were this pattern.

**Implementation (Option C, per Ken 20:44):**
1. `scripts/long-id-stub-check.sh` (~100 lines, Python+bash hybrid)
2. `scripts/auto-heal.sh` CHECK 24 (22 lines, calls the script + escalates to NEEDS_KEN)
3. `tests/test_long_id_stub_check.sh` (7 unit tests, all pass)
4. Output: `state/long-id-stubs.json` (JSON, includes short_id_exists match)

**Detection regex:** `^TKT-[0-9]{4,5}:[[:space:]]+[^[:space:]]`

**Behavior:**
- Stub without short-ID match → "Review manually"
- Stub with short-ID match → "Close as superseded by <short_id>"
- Stub < 7 days old → not flagged (let it mature before alerting)
- Non-destructive: NEVER auto-closes, only flags

**Why Option C (vs A trigger or B cleanup):**
- **A** (PG INSERT trigger): risky — could fire during legitimate operations
- **B** (one-time cleanup script): only fixes existing data, doesn't prevent recurrence
- **C** (auto-heal check): surfaces in daily report, lets Ken decide, no risk of mass-closing legitimate work

**Verified:** 7/7 unit tests pass. Regression: validate gate 106/106 GREEN, model-drift 9/9 PASS, strike-3 PASS. CHG-0514 logged.

**Linked:** L-077 (root cause), L-084 (fabrication lesson), L-085, TKT-0407, CHG-0503 (L-077 fix), CHG-0506 (TKT-0409 dispatch), CHG-0510 (TKT-0407 Phase-1 close)

## L-086 — memory file bloat via full-file write instead of append

**Symptom (Day 22 EOD):**
- `memory/2026-06-12.md` bloated to 41,737 bytes (well over 15K hard limit) by repeated `write` calls that re-emitted the full file, not appending
- File had 3 full copies of Day-22 content (lines 1-148, 149-373, 374-712) by the time EOD hit

**Root cause:**
- I used `write` (overwrite) when I should have used `edit` (targeted) or shell append (`>>`) for incremental updates
- Each "flush" wrote the full prior content + new sections, duplicating the entire file
- Pre-compaction memory flushes compounded: 4 such flushes over the day = ~4× the file size

**Fix (00:03 AEST 13 Jun):**
- Rebuilt file cleanly: 8,068 bytes, single copy, operational essentials only
- Verbose tables (files modified, GDrive uploads, AIOps chain history) → archive in `memory/MEMORY-archive-2026-06-13.md` on demand
- Now use `edit` (single targeted change) for in-place updates
- Use shell `cat >>` only when appending small new sections

**Why this matters:**
- Workspace file size limits: SOUL 10K, MEMORY 12K soft / 15K hard (per AGENTS.md, TKT-0310)
- Auto-heal CHECK 15 monitors file size; bloated files trigger alerts
- Injected context with bloated memory → wasted tokens, slower inference
- Pattern is L-084 sibling: fabrication of "complete" state without verifying

**Verified:** Day 22 file now 8,068 bytes (was 41,737). All operational facts preserved. No data loss.

**Linked:** L-084 (fabrication lesson), L-085 (file size detection), TKT-0310 (file size limits), CHG-0519 (Day 22 close), L-082 (stream cap also hits on bloated replies)

## L-088 — 2026-06-13 | TRIGGER-04 alert rerouted from Telegram to webchat
**Lesson:** When a cron wakes the `main` agent session while a human is actively chatting on webchat, OpenClaw routes the cron reply into the active webchat lane, NOT the cron's nominal target channel. Session key `agent:main:telegram:direct:8574109706` ended up with `lastChannel: webchat` because the Telegram lane was unoccupied when the cron reply came back. The Telegram bot was never notified. Ken found the alert by manually inspecting `sessions_list`, not by Telegram. This is a **silence failure on a time-sensitive alert** — exactly the class of failure L-001 (use direct Bot API, not sessions_send) and L-040 (verify ALL signal paths) were meant to prevent.

**Root cause:** Main session's "last delivery context" collapses to whichever channel has a live listener. The cron reply inherits that. Sovereign alerts must NOT share the main session lane — they need isolated delivery with explicit channel+to, or direct `telegram-alert.sh` calls that bypass the session layer.

**Trigger:** TRIGGER-04 v2026.6.6 release detected 2026-06-13 06:00 AEST. Cron 6bd53c89 ran in isolated mode, drafted alert correctly, but delivery lane got hijacked because main session was busy on webchat.

**Action:**
1. Audit all Sovereign Alert crons (Budget, Health, TRIGGERs, Warden, Auto-Heal NEEDS_KEN) — confirm `sessionTarget: "isolated"` + `delivery: {mode: "announce", channel: "telegram", to: "8574109706"}` OR `telegram-alert.sh` direct call. (TKT-0501)
2. For any cron that lands in the main session (`sessionTarget: "main"`), it is by definition subject to this failure mode — must be migrated to isolated+explicit-announce.
3. Add `lastChannel: webchat` check in auto-heal: if any session with `origin.provider: telegram` ends up with `lastChannel != telegram`, that's an alert routing anomaly worth flagging.

**Verified:** CHG-0521 + TKT-0501 + TKT-0502 created. TKT-0501 P0 (alert routing). TKT-0502 P1 (sandbox validation, also verifies the fix end-to-end).

**Linked:** L-001 (cron must use direct Bot API), L-040 (verify ALL signal paths), TKT-0501, TKT-0502, CHG-0521, TRIGGER-04.

## L-089 — 2026-06-13 | Stalled mid-execution on malformed tool call (recovery required user nudge)
**Lesson:** When a batched tool call returns a schema-rejection error (e.g., `invalid cron.update params: at /patch: unexpected property '$text'`), the correct response is to **retry the corrected call in the same turn** — not to pivot to architectural commentary and wait. The session stalled between the 4th successful `cron update` and the 5th failed one, and only resumed when the user manually issued "update." A human should never have to nudge a tool-rejection recovery.

**Root cause:** Two compounding failures:
1. **Tool-call hygiene** — batched `cron update` calls were not independently validated before the next was issued. The 5th call contained a copy-paste artifact (`$text` from a leaked tool-call template) that contaminated the `patch` payload.
2. **Stall-on-rejection pattern** — the rejected result was treated as a stop condition rather than a signal to retry. Architectural explanation was emitted *instead of* the corrected retry, not *before* it.

**Trigger:** TKT-0501 MIGRATE NOW execution, 2026-06-13 ~08:04 AEST. The user issued "update" to resume the stalled batch of cron migrations.

**Action (structural, not just behavioral):**
1. CREST skill update: add explicit "Tool-Call Rejection Recovery" rule to the CREST loop — schema-rejection results must trigger immediate corrected retry in the same turn, no architecture pivot until retry succeeds.
2. CREST skill update: when batching N>2 tool calls of the same type, after each call, check the result. On any non-success result, stop the batch, retry the failed call alone, then continue. Do not assume remaining batched calls will succeed.
3. Add CREST self-check question: "If this tool call fails on the next turn, will the user need to nudge me?" — if yes, finish the loop in this turn.

**Verified:** L-089 logged. CREST skill update drafted in parallel — to be merged into `infra/sandbox/seed/skills/crest/SKILL.md` (or wherever CREST is canonically defined).

**Linked:** L-088 (prior silence-failure lesson — same family of "stuck waiting for human nudge"), TKT-0501, CHG-0522, CREST v1.3 (TKT-0368).

## L-090 — 2026-06-13 | `db-ticket.sh create` zsh `read -p` coprocess bug (silence failure on ticket creation)
**Lesson:** When `db-ticket.sh create` is invoked under zsh (e.g. via `zsh scripts/db-ticket.sh create`), the script fails with `cmd_create:read:13: -p: no coprocess`. zsh's `read -p` requires a coprocess (zpty) that is not set up by default on macOS. The script is bash-only (`#!/bin/bash`, uses `[[ ]]`, `local`, `read -p`), but the user/agent may invoke it under zsh because the `changelog` skill says "use zsh" for that script. Generalizing "use zsh" across skills triggers this bug. Yoda hit it twice in one day (TKT-0501 + verification test), requiring manual workarounds via `db-write.sh` direct path. Ken flagged it as a recurring S1-grade silence failure.

**Root cause (compound):**
1. **Skill documentation drift** — `changelog` skill says "use zsh explicitly" (because of `${(P)var}` parameter expansion). `pg-sprint-backlog` skill says "use bash" (because of `read -p`). Agents that generalize "use zsh" across both trigger this bug.
2. **No non-interactive create path** — `db-ticket.sh create` is interactive-only (Failure #5 fix from earlier). There's no scriptable alternative. Agents had to bypass via `db-write.sh` direct call, which skips the validation/normalization layer.
3. **No shell auto-detection** — the script's shebang is `#!/bin/bash` but zsh ignores shebangs when invoked as `zsh script.sh`. No self-healing.

**Action (structural, not behavioral — see CREST §8.4 sibling pattern):**
1. **Auto-reexec to bash** — `db-ticket.sh` detects `$ZSH_VERSION` and re-execs to `/bin/bash` with the same args. Override with `DB_TICKET_FORCE_BASH=0` for testing. (Implemented in CHG-0524.)
2. **Add `create-from-json` subcommand** — non-interactive, accepts full JSON payload on CLI, calls the same safe-mode write path. Idempotent, scriptable, works under any shell. **Agents and CI MUST prefer this over `create`.** (Implemented in CHG-0524.)
3. **Skill doc update** — added "⚠️ SHELL COMPATIBILITY — L-090 FIX" section to `pg-sprint-backlog/SKILL.md` with explicit shell requirements, the auto-reexec contract, and the `create-from-json` reference.
4. **Auto-heal CHECK 26** — scans last 7d of session JSONL for `no coprocess` errors and failed `db-ticket.sh` invocations. Alerts Ken via NEEDS_KEN if pattern recurs.
5. **CREST cross-link** — L-088, L-089, L-090 form a silence-failure lineage. All three are about "the right thing didn't happen and the user had to notice manually." Consider a CREST section on silence-failure patterns.

**Verified:**
- TKT-9999 created via `zsh scripts/db-ticket.sh create-from-json TKT-9999 '{...}'` — auto-reexec to bash succeeded, PG write succeeded, read-back confirmed.
- TKT-9998 created via `bash scripts/db-ticket.sh create` (interactive regression) — still works.
- Test tickets cancelled. PG state clean.

**Linked:** L-088 (sibling — Telegram alert rerouted to webchat), L-089 (sibling — stalled mid-execution on rejection), TKT-0501, CHG-0524, scripts/db-ticket.sh, scripts/auto-heal.sh, infra/sandbox/seed/skills/pg-sprint-backlog/SKILL.md.

## L-090a — 2026-06-13 | gateway-restore.sh has the same zsh coprocess vulnerability (sibling to L-090)
**Lesson:** When auditing for L-090, I found a second script (`gateway-restore.sh`) with the same `read -r -p "Proceed..."` vulnerability. The audit caught it before it tripped in production. Lesson: **when fixing a class of bug, scan the entire class — don't fix one instance and stop.** The CHECK 26 detector was extended to cover `gateway-restore.sh` patterns + a generic `read -p` zsh coprocess marker.

**Action:** `gateway-restore.sh` now has the same zsh auto-reexec block as `db-ticket.sh`. Override via `GW_RESTORE_FORCE_BASH=0`. CHG-0525.

**Linked:** L-090 (sibling), CHG-0524, CHG-0525, scripts/gateway-restore.sh, scripts/auto-heal.sh CHECK 26.

## L-091 — 2026-06-13 | crest-done-gate.sh pre-existing syntax error (line 22) — silently broken since TKT-0406 close
**Lesson:** While running the L-090 CREST discipline check, I executed `crest-done-gate.sh TKT-0501` per CREST §7.4 + §8.4. The script failed with `syntax error near unexpected token '('` at line 133. I assumed it was a heredoc/Python issue (similar pattern to L-090) and rewrote the heredoc block. The error persisted. After two rewrite attempts, I traced the real cause: **line 22 has `DB_SCRIPT="/scripts/db-raw.sh""` — a stray double-quote** that has been there since TKT-0406 closure on 2026-06-11. Bash's parser fails early but reports the error on whichever line it's processing when the parse fails — in this case line 133 inside the heredoc, which is a red herring.

**Root cause:** Stray `"` at end of `DB_SCRIPT="/scripts/db-raw.sh""` (line 22). The path was also wrong (relative `/scripts/...` not absolute). Pre-existing since TKT-0406 CLOSED commit `2b85f118` (2026-06-11 22:26).

**Why it was never caught:** The gate is meant to run as a pre-close hook for ticket close operations. But in the current platform, parent tickets are rarely closed (most work is in `open`/`in-progress` state), and the few closes that happened didn't go through the gate's full path — or did, but the failure was hidden in stderr.

**Action (structural):**
1. Fixed line 22: `DB_SCRIPT="/Users/ainchorsangiefpl/.openclaw/workspace/scripts/db-raw.sh"` (absolute path, single closing quote).
2. Fixed the heredoc pattern in OUTPUT section (L-091b): quoted `<<'PYEOF'` + env vars (TKT-0408 pattern from db-write.sh) to avoid bash-vs-Python f-string/parenthesis conflict.
3. Replaced broken `$'\\n'` quote-escape hell with simple `if/then/else` string concat.
4. **Added: Auto-heal CHECK 27 — `crest-done-gate.sh syntax check`**. Runs nightly, exits non-zero if `bash -n scripts/crest-done-gate.sh` fails. Prevents this class of "broken since some earlier commit" failure.

**Verified:** `bash -n` passes. Gate runs: TKT-0501 PASSED, TKT-0407 PASSED, TKT-9999 PASSED. Gate state file written correctly. CHG-0526.

**Linked:** L-089 (sibling — recovery after rejection), L-090 (sibling — silence failure), TKT-0406 (root commit that introduced the bug), TKT-0501 (the ticket whose close triggered discovery), CHG-0526, scripts/crest-done-gate.sh, scripts/auto-heal.sh.

## L-095 — 2026-06-13 | task-queue-processor reads from PG state_task_queue, NOT state/task-queue.json — JSON file is write-only orphan
**Lesson:** Ken asked at 09:52 AEST "still waiting on A1-A5 to complete?" — I had queued 5 atoms to `state/task-queue.json` 35 min earlier. Ran `bash scripts/task-queue-processor.sh` manually → "TQP: No queued or dispatched tasks. Exiting." Traced: TQP reads PG `state_task_queue` table via `pg()`. The JSON file is **only used by `task-watchdog.sh` for divergence detection** (which is how the 2026-06-12 alert got generated — TKT-0340-A1 was already 'done' in PG but still 'queued' in JSON).

**Root cause:** The skill `pg-sprint-backlog` does not document that TQP queues go to PG, not the JSON file. The JSON file is read by `task-watchdog.sh` and is the source of the divergence alert, but TQP itself never reads it. This is the inverse of L-091 (broken syntax in crest-done-gate.sh): there the tool looked correct; here the write path looked correct.

**Why it took 35 min to discover:** TQP cron `a89d00ef` runs every 5 min. Each run finds nothing. Each run is `succeeded` in OpenClaw's task view. No error, no alert, no NEEDS_KEN. Silent failure — exactly the L-088/L-089/L-090/L-091 family.

**Action (structural):**
1. **Cancelled 7 atoms in `state/task-queue.json` queue array** (status updated to 'cancelled-orphaned').
2. **Insert 5 atoms directly into PG `state_task_queue`** with correct schema (id, title, atoms_jsonb, status='queued', priority, source).
3. **Update pg-sprint-backlog SKILL.md** with explicit TQP queue write path section: "TQP is PG-only. The JSON file `state/task-queue.json` is a watchdog-divergence audit trail only. NEVER queue atoms there expecting TQP to pick them up."
4. **Added auto-heal CHECK 28f**: scan PG for status='queued' rows in state_task_queue, compare to `state/task-queue.json` queue array, alert Ken if JSON has entries that PG doesn't (orphaned JSON writes).
5. **Update task-watchdog.sh** to also flag PG→orphan (PG has 'queued' but no entry in JSON for that atom_id) — currently only flags JSON→PG divergence.

**Verified:** TQP picks up atoms within 5 min of PG insert. PG row for TKT-0503-A1 visible to TQP dispatch query.

**Linked:** L-091 (sibling — broken-pre-existing-infrastructure), TKT-0409 (task-watchdog cron owner), state/task-queue.json (orphaned write path), state_task_queue PG table (canonical), CHG-0531.

## L-096 — 2026-06-13 | TQP claims atoms but no executor consumes non-CREST atoms — flash-dispatcher.sh is CREST-sub-ticket-only
**Lesson:** Ken asked at 10:18 AEST: "TQP running? I only got the telegram on kick-off... A5 timeout?" 23 min after I re-queued TKT-0503-A1..A5 to PG. PG showed all 5 atoms `dispatched` with `claimedby=agent:tqp` but **none had any state_payload update or status='done'/'complete'**. TQP claim cycle was running (every 5 min) but execution was 0%.

**Root cause:** TQP (`scripts/task-queue-processor.sh`) is a queue manager, not an executor. It claims an atom (status='queued' → 'dispatched', sets claimedby, claimedat, claimtimeout) and **expects an external process to actually do the work**. The only consumer that exists is `scripts/flash-dispatcher.sh` (TKT-0386), but it reads `state_sub_crest` and `state_sub_crest_atoms` — it only handles CREST sub-tickets. Plain TQP atoms (like TKT-0503-A1..A5) have no consumer.

**Why it took 23 min to discover:** TQP cron `a89d00ef` was succeeding. OpenClaw task view showed "succeeded". The "Stalled task alert" Ken got was a framework-level monitor noticing A1's claim window (30 min) was about to expire, not because any agent was actually working on it. Silent-failure class: claim succeeds, no execution happens, timeout fires, re-queue, repeat.

**Action (structural, this turn):**
1. **L-096 logged** with full root cause analysis.
2. **Decide on execution model for TKT-0503-A1..A5:**
   - (a) Wrap each atom as a CREST sub-ticket under TKT-0503, then flash-dispatcher will pick them up
   - (b) Write a new bridge script `tqp-executor.sh` that consumes non-CREST TQP atoms and routes them to the right specialist agent
   - (c) Direct execution by Yoda in this session (since I'm the available executor right now, I can run the 5 atoms myself using the flash model per task-queue model mapping)
3. **Add auto-heal CHECK 28g**: detect state_task_queue rows with status='dispatched' AND claimedby='agent:tqp' AND claimedat > 5 min ago with no state_payload update → emit CRITICAL alert. Catches this class: TQP claimed but never executed.

**Verified (this turn):** TQP claims cycle: A1 (09:54:30), A2 (09:56:52), A3 (10:02:12), A4 (10:07:10), A5 (10:12:19). All status='dispatched', all claimedby='agent:tqp', all state_payload={} or NULL. No agent session ever picked any of them up.

**Linked:** L-095 (sibling — JSON-vs-PG), TKT-0386 (flash-dispatcher — CREST-only consumer), TKT-0503 (atoms stuck), scripts/task-queue-processor.sh, scripts/flash-dispatcher.sh, state/obs.db, state/auto-heal.sh CHECK 28g.

**Verification command (post-TKT-0504-A3):** `bash scripts/tqp-executor.sh --dry-run` — should show 0+ queued TQP atoms ready for spawn (whereas pre-fix it would have shown 0 always, since the executor didn't exist). End-to-end check: insert TQP atom, claim via task-queue-processor, verify tqp-executor creates the in-band exec-atom and atomically gates the source atom (state_payload.executor='tqp-executor', status='running'). Idempotency: re-run with executor set → "0 atoms ready" (idempotency gate tripped).

## L-092 — 2026-06-13 | auto-heal.sh tilde detector flags its own log output — false-positive NEEDS_KEN
**Lesson:** During A1 execution (TKT-0503), discovered that CHECK 20 (tilde path enforcement) at line 736 of scripts/auto-heal.sh scans `state/*.json` and flags every `~/` substring. The detector was reading its own NEEDS_KEN message text in `state/auto-heal-*.json` logs and counting them as new violations. 44 historical false-positive events.

**Fix:** Updated detector to exclude:
- `state/auto-heal-*.json` (own log output)
- `state/task-queue.json` (contains task description bodies with `~/` examples)
- Files under 200 bytes (config defaults, not real paths)

**Verified:** After fix, the detector returns 0 false positives. Syntax check passes.

**Linked:** L-093, L-094, TKT-0503-A1, CHG-0532.

## L-093 — 2026-06-13 | obs-collector CHECK K lacked dedup — re-logged 127 stale ERROR events
**Lesson:** During A2 execution. CHECK K reads `state/fallback-chain-status.json` and logs ERROR if `overall != 'ok'`. After CHG-0520 lifted Conservative Mode (2026-06-12 08:12), the file returned to `overall: ok` but the obs.db table had 127 historical entries that the collector KEPT re-logging on every 5-min run. No "last-observed" dedup.

**Fix:** Added `lastObservedFallbackChain` to `state/obs-collector-state.json`. CHECK K now:
- Tracks current vs last overall status
- Only logs ERROR on transition ok→broken
- Only logs INFO `fallback_chain_recovered` on broken→ok
- Auto-marks stale ERROR rows `resolved=1` on transition

**Verified:** Syntax check passes. The next collector run will see `lastObservedFallbackChain=ok` and skip logging.

**Linked:** L-092, TKT-0503-A2, CHG-0532.

## L-094 — 2026-06-13 | Sandbox gateway LaunchAgent dead since Jun 8 — never cleaned up
**Lesson:** During A5 execution. `ai.openclaw.sandbox-gateway.plist` LaunchAgent has been loaded since 2026-06-08 but nothing listens on port 28789. Sandbox gateway is parked until v2026.6.6 install (TKT-0502). 46 recurring NEEDS_KEN events that nobody actioned.

**Fix:** Added CHECK 28c to auto-heal.sh:
- Detects dead LaunchAgent (loaded but no listener)
- Tracks `deadSince` in `state/sandbox-gateway-state.json`
- Alerts Ken at 1h, auto-unloads at 24h
- Rollback: `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/ai.openclaw.sandbox-gateway.plist`

**Safety:** Only unloads sandbox-gateway, NOT production gateway. Only acts after 24h grace. Logs full audit trail. TKT-0502 (sandbox install) can re-bootstrap when ready.

**Linked:** L-092, L-093, TKT-0502, TKT-0503-A5, CHG-0532.

## L-097 — 2026-06-13 | OpenClaw edit tool: tilde in path produces malformed activity entry message
**Lesson:** Ken observed an alert: "⚠️ 📝 Edit: `in ~/.openclaw/workspace/scripts/obs-collector.sh` failed". Investigation found:

1. The `edit` tool's `argumentSummary` renders path arg via `pathDisplay` template: `${tool} ${pathDisplay}` where `pathDisplay` is the result of `getCwdRelativePath(absolutePath, cwd)` — returns the path **relative to cwd** if it's a child, otherwise `undefined` (then falls through to absolute).
2. The preposition "in" is NOT in the tool formatter — it's the **inbound-meta prefix** prepended by `buildInboundUserContextPrefix` for tool-call activity entries: each tool-call gets a per-line prefix like `<session> in <filepath>` that flows into the activity stream summary.
3. When the model uses a `~/` literal, the runtime path validator (runner.entries-B7esF0QJ.js:345) does NOT block it — `resolveToCwd` expands `~` to `$HOME` and then the formatter tries `getCwdRelativePath` and either returns relative or absolute path. The "in" is the inbound-meta wrapper, NOT the edit tool.

**Why it matters:** The alert text "Edit: `in <path>` failed" looks like a path-injection or tilde-validation rejection, but it's actually a routine inbound-meta rendering quirk. The `Edit:` prefix and the final `failed` come from the edit tool's `formatEditResult`; the "in" between is the inbound-meta activity prefix.

**Mitigation (no fix needed at this time):** The edit tool already expands `~` correctly. The misleading-looking message is harmless. If we ever see "Edit: `in ...` failed" in production, it means:
- The path expansion succeeded
- The actual edit failed for some other reason (file not found, ENOSPC, bad oldText, etc.)
- The visible "in" is the activity-entry renderer, not a path error

**Linked:** Observed by Ken, TKT-0503-A2 execution context, A1 tilde self-detect discussion.

## L-098 — 2026-06-13 | Cron scaler: 48 false-positive SETs on systemEvent jobs (TKT-0503-A6)
**Lesson:** `scripts/cron-timeout-scaler.sh` was emitting 48 "SET" recommendations for cron jobs that don't consume `timeoutSeconds`. Investigation found:
- 22 `systemEvent` payload jobs (don't have `timeoutSeconds` field at all)
- 26 `agentTurn` jobs that already had `timeoutSeconds` set but were misclassified as needing SET (scaler was reading from job root, not `payload`)

**Root cause:** `timeout_set = job.get('timeoutSeconds', None)` — should be `payload.get('timeoutSeconds', None)` for `agentTurn` only. For `systemEvent`, the field doesn't exist and is never consumed (see `server-cron-i5IplaUe.js:376` — `payload.kind === "agentTurn"` is a hard requirement for `timeoutSeconds`).

**Fix (A6):**
1. `cron-timeout-scaler.sh`: read from `payload.timeoutSeconds`, only emit SET/INCREASE/DECREASE for `agentTurn`. New `payloadKind` field, `scalerVersion: "A6"`, `actionableRecommended` count.
2. `auto-heal.sh CHECK 22`: use `actionableRecommended` for the noise-relevant count. New `effectively` alert message: "10 actionable (scaler vA6)" instead of "48 — SCALER FLAG ONLY (CONSERVATIVE MODE)".
3. New auto-apply logic in CHECK 22: `state/cron-timeout-applied.json` ledger tracks (cronId, firstSeen, lastSeen, daysCount, appliedTo). 7-day stability gate, only DECREASE on agentTurn is auto-applied. Live `openclaw cron edit --timeout-seconds N` via subprocess. `CHECK22_AUTO_APPLY=true` env var gates live apply (default: dry-run with NEEDS_KEN once per day).

**Verification:**
- Pre-fix: 48 false-positive SETs/day → 53 obs.db events
- Post-fix: 10 actionable DECREASEs (all real, all light-agent class) → 0 false positives
- Live apply tested: 2c855a3e (PG-Notion Batch Sync) 300s → 120s, idempotent on second run

**Linked:** TKT-0503-A6, CHG-0533, server-cron-i5IplaUe.js:376, mktemp(1) BSD template (no `.json` extension on XXXXXX).

## L-099 — 2026-06-13 | Gateway config mutation must be explicit one-shot, never implicit on auto-heal
**Lesson:** TKT-0503-A6 was first implemented with `CHECK22_AUTO_APPLY=true` env var to enable live apply inside auto-heal.sh. Ken pushed back: "is `CHECK22_AUTO_APPLY=true` something you want as a Ken-toggle on auto-heal runs, or should the live apply path require a separate one-shot invocation? I lean toward the latter for a `state/cron-config-mutation` S-grade control."

**Why this matters:** env-var gates inside scheduled jobs are still implicit. Even with the gate, the mechanism is "set the var and walk away" — no human-in-the-loop at the moment of mutation. The structural right answer is **separate the read path (auto-heal: ledger + NEEDS_KEN surface) from the write path (one-shot script requiring explicit `--yes` and scope)**.

**Fix (CHG-0534):**
- New `scripts/cron-timeout-apply.sh` — one-shot, requires `--yes` + scope (`--cron <id>` or `--all`). Without `--yes`, dry-run only. Without scope, exits 2.
- Stripped live-apply code from `auto-heal.sh CHECK 22` entirely. auto-heal only:
  - Updates ledger (daysCount, lastSeen tracking)
  - Reconciles stale entries (cron no longer in baseline → drop)
  - Writes `state/cron-timeout-apply-pending.json` with eligible items + the exact apply command
  - Surfaces in `NEEDS_KEN` once per 12h (mtime check)
- Tested: 4 modes (dry-run, --verbose, --cron --yes, --all --yes), idempotent on re-run, exit codes 0/2/3/4/5 documented.
- New exit code 2 = `--yes required`, exit code 3 = not eligible, exit code 4 = cli failed, exit code 5 = ledger write failed.

**Linked:** TKT-0503-A6, CHG-0534, L-098 (scaler filtering). Sets precedent: any future "auto-apply X to gateway config" should follow this pattern (one-shot, --yes-gated, never embedded in scheduled jobs).

## L-100 — 2026-06-13 | obs-collector CHECK E: 384 unhandled_rejection events were same-signature re-logs
**Lesson:** `scripts/obs-collector.sh` CHECK E was logging `unhandled_rejection` on every cron run whenever new stability files existed. With 13 stability files/hour (gateway at peak heap), that's 13 events × 12 cron runs/hour = 156 events/hour = 3744/day. We saw 384/week in obs.db.

**Root cause:** No dedup on (level, reason) signature. Each obs-collector run logged "Node.js unhandled rejection(s): 13 new stability file(s) — reason: diagnostic.memory.pressure.critical" regardless of whether it was a NEW condition or a continuing one.

**Fix (A7 atom / L-100):**
1. Parse stability file structure correctly: top-level `evidence.memoryPressure.{level, reason}` (not `d.get('reason')`).
2. Compute signature: `${level}|${reason}|${kind}` (e.g., `CRITICAL|heap_threshold|memory.pressure`).
3. Track signature in `state/obs-collector-state.json:lastStabilitySignature`. Only log on signature transition (Python `a != b` check via heredoc to avoid zsh pipe-escape issues with `[[ "$x" != "$y" ]]`).
4. Add `CRITICAL` and `WARNING` to `obs-log.sh` valid levels (was `ERROR|WARN|INFO` only). OpenClaw diagnostic emitter sends lowercase `critical`/`warning` — normalize to uppercase in obs-collector before calling `_obs_log`.

**Side finding (A7 scope revision):** OpenClaw v2026.5.27 hardcodes memory pressure thresholds (RSS 1.5GB warn / 3GB critical) as constants in `diagnostic-BDsaMZfL.js`. The `DiagnosticMemoryThresholds` type exists but NO caller passes thresholds from config — `emitDiagnosticMemorySample` is always called with default thresholds. The "threshold ratchet to 5GB/6GB" from the A7 atom spec is NOT doable on 2026.5.27. When gateway moves to v2026.6.6 (sandbox install TKT-0502), re-evaluate whether per-config thresholds are available.

**Verified:** 
- Run 1 (clean state): 1 new event logged (signature `CRITICAL|heap_threshold|memory.pressure`)
- Run 2 (same signature): 0 new events (deduped)
- Run 3 (simulated transition `WARN|rss_threshold` → `CRITICAL|heap_threshold`): 1 new event

**Net effect:** 384 events/week → estimated 1-3 events/week (1 per actual signature transition). A7's `NODE_OPTIONS=--max-old-space-size=6144` is the other half (still pending Ken's approval for gateway restart).

**Linked:** TKT-0503-A7, L-100, server-cron/DiagnosticMemoryThresholds (always-default). Foundation for future: signature-based dedup pattern.

## L-102 — 2026-06-13 | Env-wrapper swap is INERT for CLI-launched gateways
**Lesson:** When `openclaw gateway` is run directly (not via the LaunchAgent), the process is parented to the terminal shell, not launchd. The new env-wrapper script (with `NODE_OPTIONS=--max-old-space-size=6144`) was correctly written to disk, but the running process still had the old env because it was started via the CLI, not via the plist. Restoring the plist-based launchd start was the only way the new env took effect.

**Detection:** `ps eww -p $PID` showed `NODE_OPTIONS=` (empty) on the CLI-launched process. On the launchd-launched process, `ps eww` showed `NODE_OPTIONS= --max-old-space-size=6144`.

**Rule:** Gateway config/env changes are only live for processes spawned through the plist. If you start the gateway manually, you must do `launchctl bootout` + `launchctl bootstrap` (or use the new env-var directly via `openclaw gateway --env NODE_OPTIONS=...` if supported). The structural fix: write env to a file that node reads at startup, not just the wrapper script.

**Linked:** TKT-0503-A7, CHG-0535, env-wrapper.sh, plist structure.

## L-103 — 2026-06-13 | v2026.6.6 sandbox install requires separate node_modules, not shared prod
**Lesson:** The Jun 8 sandbox install attempt (now visible in `/Users/ainchorsangiefpl/.openclaw/nexus-sandbox/sandbox-stderr.log`) failed in a loop because the sandbox plist's `ProgramArguments` pointed at `/opt/homebrew/lib/node_modules/openclaw/dist/index.js` — the SAME module path as production 2026.5.27. The OpenClaw binary does a port-detection pre-flight ("port 18789 is still busy before LaunchAgent restart") and rejects the launch, which then looped forever.

**Root cause:** The original Jun 8 plist was written assuming `openclaw install --sandbox` would set up the module path automatically. It didn't. The plist needs to point at a v2026.6.6-specific install, not the shared brew path.

**Fix for TKT-0502 (when Ken approves):**
1. Download v2026.6.6 tarball to `/Users/ainchorsangiefpl/.openclaw/nexus-sandbox/openclaw-2026.6.6/`
2. `npm install` into a sandbox-specific `node_modules/` (NOT `/opt/homebrew/lib/node_modules`)
3. Plist: `ProgramArguments` → `[node, <sandbox>/openclaw-2026.6.6/dist/index.js, gateway, --port, 28789]`
4. `WorkingDirectory` → `<sandbox>/` (already correct)
5. `OPENCLAW_CONFIG` → `<sandbox>/openclaw.json` (already correct)
6. Optional: env-wrapper for sandbox to set `NODE_OPTIONS` separately

**Linked:** TKT-0502, sandbox-stderr.log, CHG-0521 (DEFER+SANDBOX), L-094 (dead-sandbox plist).


## L-104 — 2026-06-13 | Raw source release ≠ drop-in install
**Lesson:** v2026.6.6 ships as TypeScript source (8,816 files), not as a pre-built `dist/`. The package.json declares `packageManager: pnpm@11.2.2` and `engines: { node: ">=22.19.0" }`. Building requires `pnpm install` + `pnpm build:docker` (or `pnpm build`) — 8 sub-builds, 5-10 min, 8GB heap peak (per `plugin-sdk:api:gen` script: `node --max-old-space-size=8192`). The entry point is `openclaw.mjs` which uses `node --experimental-strip-types` for direct source execution.

**Original Jun 8 install attempt (visible in `nexus-sandbox/sandbox-stderr.log`) was a misconfigure, not a real test:**
- Plist pointed at `/opt/homebrew/lib/node_modules/openclaw/dist/index.js` (production 5.27)
- That module path doesn't exist in 6.6 (no `dist/` in tarball)
- Even if it did, using prod module on port 28789 would conflict with prod on 18789

**Why we deferred TKT-0502:** The 5-10 min pnpm build on OC1 has 8GB heap peak during plugin-sdk generation. With prod gateway's NODE_OPTIONS=--max-old-space-size=6144 (6GB ceiling) already using ~1GB, the build would push the system into memory pressure. Ken decision 2026-06-13 12:09 AEST: "looks like it's still raw release. cancel TKT-0502. defer to later."

**Tarball retained** at `/Users/ainchorsangiefpl/.openclaw/nexus-sandbox/downloads/openclaw-2026.6.6.tar.gz` (50MB, SHA-256 `968cbbe6d6cfe1e46d8dcd44b3f1e4945f728116cb15c9e418e78083b65b1283`) for future attempts. When we retry:
1. Use OC2 (incoming 6-13 Jul 2026, 48GB RAM) for the build, not OC1
2. OR use Docker build (test:docker:e2e-build) for clean isolation
3. OR install pnpm globally and schedule build for 02:00-04:00 AEST low-cron window

**Rule:** Always check `package.json#packageManager` and `package.json#bin` before assuming a "drop-in" install. Source releases need build tooling (pnpm/yarn/bun) that may not be on the host. The 6.6.6 release date (2026-06-12) is 1 day before our attempt — likely too fresh to have pre-built artifacts distributed via brew.

**Linked:** TKT-0502 (deferred), CHG-0521 (DEFER+SANDBOX), v2026.6.6 tarball, nexus-sandbox/, L-103 (separate node_modules needed).


## L-105 — 2026-06-13 | ps eww splits env vars at every space; use Python regex for multi-space values
**Lesson:** When detecting env vars from `ps eww -p <pid>` output, `tr ' ' '\n' | grep "^VAR="` only captures the prefix (e.g. `NODE_OPTIONS=`) and breaks if the value contains spaces. OpenClaw's env-wrapper sets `NODE_OPTIONS="${NODE_OPTIONS:-} --max-old-space-size=6144"`, which means the value is ` --max-old-space-size=6144` (with leading space) and `ps eww` outputs it as `NODE_OPTIONS= --max-old-space-size=6144` with the value flowing across what `tr` treats as multiple fields.

**Detection (the false positive this caused):** First run of CHECK 25b reported `envWrapperApplied: false` when in fact the env was correctly applied. Looked like the wrapper was inert, but it was actually a detection bug.

**Fix:** Use Python with regex to extract the full value:
```python
import re
m = re.search(r'NODE_OPTIONS=([^A-Z]*?)(?:[A-Z_][A-Z_0-9]*=|\Z)', text)
if m:
    print(m.group(1).strip())
```
The `[^A-Z]*?` is "any chars not uppercase" — env var names are uppercase, so this matches everything up to the next env var. `\Z` matches end of text for the last var.

**Rule:** When checking env vars that may contain spaces (NODE_OPTIONS, LD_PRELOAD, BASH_ENV, etc.), use Python regex against `ps eww` output, not shell `tr`/`grep`. Always validate detection with a known-true state (we ran it against prod gateway which was launchd-spawned with NODE_OPTIONS set — both `wrapperParentedToLaunchd` AND `envWrapperApplied` should be true; the false-negative on `envWrapperApplied` exposed the bug).

**Linked:** TKT-0505-A5, L-102, CHECK 25b, scripts/auto-heal.sh.

## L-096: pg-to-notion-sync.sh — Two Silent-Failure Bugs (2026-06-13)

**Context:** 30-min cron `pg-to-notion-sync.sh --batch` reported "All tickets synced. Nothing to do." but PG showed 37 tickets with non-synced status.

**Bug 1 — JSONB dot-notation doesn't work for nested paths:**
- Wrong: `metadata->>'notion_sync.status'` — returns NULL for all rows
- Right: `metadata->'notion_sync'->>'status'` — proper nested JSONB access
- Impact: `!= 'synced'` matched nothing (NULL != 'synced' is NULL/false in SQL), script silently skipped all pending tickets

**Bug 2 — zsh `status` is a read-only variable:**
- `local status` and `status=...` assignment fails under zsh with "read-only variable: status"
- Fix: rename to `t_status` throughout sync_ticket()
- Also: script shebang is `#!/bin/zsh` but uses `${(f)var}` zsh-specific syntax — must be invoked with `zsh`, not `bash`

**Detection:** Cron run was silent-success for unknown duration (both bugs masked each other — Bug 1 made the query return empty, so Bug 2's zsh variable issue was never reached until Bug 1 was fixed).

**Fix applied:** CHG-0525 (pending). Both bugs fixed in pg-to-notion-sync.sh. 30 tickets synced on re-run.

## L-113 — 2026-06-13 | Yoda Role Boundary / CREST Discipline
**Lesson:** Yoda is orchestrator, never executor. The only CREST activities that belong to Yoda are: Plan, Verify, Replan, Synthesize, Close. **Execute is NEVER Yoda's** — even for trivially mechanical tasks. Any execution atom must be dispatched to a specialist (Forge for infra/build, etc.) via the 2-Pass Contract (TKT-0321).
**Trigger:** Ken Mun 2026-06-13 13:54 AEST, after TKT-0501 "CREST synthesize and close" prompt — Yoda correctly declined to re-close an already-closed ticket, and Ken locked the boundary into SOUL.md Non-Negotiables #13–16.
**Compounding rules (also from same mandate):**
- **No fabrication.** "I don't know" + find out. Never invent, guess, or paper over.
- **Evidence-only.** Done/closed/verified = validated + backed by artifacts (PG state, logs, tool output, file content). Vibe ≠ fact.
- **CREST mandatory.** Every plan involving execution work runs Plan→Execute→Verify→Replan→Synthesize→Done. No skip phases.
**Rule:** 
- If a task requires touching tools that produce side effects (file writes, cron changes, config mutations, dispatches), and the agent is Yoda → STOP. Dispatch to specialist or ask Ken for explicit per-instance exception.
- "I already know how to do it" is not justification — it's a violation risk.
- 3-strike principle applies: re-occurrence escalates per CREST enforcement policy.
**Source:** Ken Mun mandate 2026-06-13 13:54 AEST, CHG-0545. SOUL.md rules 13–16. MEMORY.md "Ken's Governance Mandate" section.

## L-114 — 2026-06-13 | Dispatch Quoting-Context Awareness
**Lesson:** When dispatching an executor (Forge) to apply multi-line edits to a shell script, the dispatch spec MUST call out per-line quoting context — not a blanket rule. A single "use `\${HOME}`" instruction applied to two similar-looking lines can produce correct output on one and a literal-string regression on the other.
**Why it's tricky:** The two contexts in auto-heal.sh behave differently:
- `NEEDS_KEN+=("...")` (regular string array): bare `$HOME` expands correctly at runtime. `\${HOME}` stays as literal `${HOME}` — **regression**.
- `$( ... )` (command substitution): `\${HOME}` works because `\$` defers the `$` until the subshell evaluates the inner string. Bare `$HOME` would also work here.
**Real example from TKT-0503-A1-fixup v1 (2026-06-13 14:14):** Forge applied `\${HOME}` to both line 230 (NEEDS_KEN) and line 277 (CHG invocation). Yoda's verify phase caught the regression via a zsh runtime test mimicking line 230's context. Required a v2 follow-up dispatch.
**Rule for Yoda dispatch specs (not for Forge — for me):**
- When writing a `sessions_spawn` task that includes shell edits, **explicitly call out the quoting context per line** ("line 230 = `NEEDS_KEN+=("...")` — use bare `$HOME`; line 277 = inside `$( ... )` substitution — use `\${HOME}`").
- When verifying executor work on shell scripts, **always run a zsh runtime test that mimics the actual context** — `bash -n` alone won't catch quoting escapes that stay literal at runtime.
- The lesson is not "don't use escapes" — it's "the dispatch must specify the escape per context, not in blanket form".
**Detection:** Re-render any string that contains `\$` or `${...}` in a verification block that mimics the original quoting context. If the rendered output contains `\$` or `${...}` literally, the escape was wrong for that context.
**Source:** TKT-0503-A1-fixup v1 regression 2026-06-13 14:14–14:16 AEST, caught by Yoda verify phase. CHG-0545 (Yoda role boundary) — Yoda dispatched v2 to Forge per the locked role boundary, didn't fix it directly.

## L-111 — 2026-06-13 | Telegram Cron Delivery: chat_id Numeric, NOT Email
**Lesson:** Cron `delivery.to` for Telegram channel MUST be a numeric chat_id (e.g. `"8574109706"`), NEVER an email address (e.g. `"kenmun@ainchors.com"`). Violation fails silently as `OutboundDeliveryError: Telegram recipient must be a numeric chat ID` and the agentTurn output is masked by the delivery error in cron state.
**Source:** LinkedIn teaser cron `a129f70c` (2026-06-13 09:00 AEST) + Spark Tue/Wed/Thu draft crons (`13b0aa89`, `833ee0c7`, `869502c9`) — all had `delivery.to: "kenmun@ainchors.com"`. L-001 was already logged for this rule but violated when CHG-0515/0518/0519 crons were created.
**Rule:** When creating ANY cron with `delivery.channel: "telegram"`, the `delivery.to` field MUST be the numeric chat_id. Validation step before cron creation: confirm `to` is digits-only (or starts with `-` for groups). Audit all existing crons quarterly for this pattern.
**Related:** L-001 (sessions_send vs Bot API for delivery), CHG-0515, CHG-0518, CHG-0519, CHG-0546.

## L-115 — 2026-06-13 | db-ticket.sh update does full-metadata-replace, not JSONB merge
**Lesson:** `db-ticket.sh update <TKT> '{"metadata":{...}}'` does a **full replacement** of the `metadata` JSONB column with whatever object you send. It does NOT merge with existing fields. A partial-payload update will silently clobber all fields you didn't include.
**Why it's dangerous:** Tempting to think "I'll just send the 2 fields I want to add" — but if the script wrote a full SET, every other metadata key (atom_status, re_verify_findings, review_window_end, executor_compliance, linked_lessons, etc.) is gone in a single call. Both PG and the `state/tickets.json` fallback are overwritten; no diff, no warning, exit 0.
**Real example from TKT-0503 resume (2026-06-13 14:17 → 14:32):** Yoda's 14:17 update added ~10 fields (atom_status, re_verify_findings, review_window_end, executor_compliance, etc.). Yoda's 14:27 "fix-up" sent a 2-field payload (brief + grooming_history) thinking it would merge. **It replaced the whole metadata column with just those 2 fields.** All 10 prior fields lost from both PG and fallback. Caught immediately by Yoda's verify phase via `db-ticket.sh read` + check of preserved fields.
**Rule for Yoda (strict, no exceptions):**
- Every `db-ticket.sh update` payload MUST include the **complete** `metadata` block, sourced from `db-ticket.sh read` + edits, never a subset.
- After every `db-ticket.sh update`, **always re-read the ticket and diff the metadata keys** against the intended set. If any are missing, you have a clobber.
- If a field would be tedious to reconstruct: the facts are usually in journal + CHANGELOG + LESSONS. Rebuild from evidence, not from memory.
- The fallback file `state/tickets.json` is NOT a safety net — it gets overwritten in the same call.
**Detection pattern:** `python3 -c "import json; d=json.load(open('state/tickets.json')); m=d.get('TKT-XXXX',{}).get('metadata',{}); expected_keys=[...]; print('MISSING:', set(expected_keys)-set(m.keys()))"`
**Source:** TKT-0503 metadata clobber 2026-06-13 14:27 AEST, caught in same turn by Yoda verify phase. Ken Mun directive 14:32 AEST: log L-115 now, approve rebuild, caught-in-verify exempted from L-113 strike count. CHG-0545 (Yoda role boundary) — no execution by Yoda, but the dispatch discipline lesson (always send complete payload) applies to me directly when calling domain scripts.

**Follow-up 2026-06-13 14:40 AEST — Severity demoted CRITICAL→WARN (TKT-0504-A0, CHG-PENDING):** Signal layer (CHECK 28g in auto-heal.sh) was implemented 2026-06-13; severity was CRITICAL. Demoted to WARN per TKT-0504 groom (Ken 14:24 AEST). The signal is live, so CRITICAL is too noisy. Re-promote to CRITICAL only after TKT-0504-A1..A5 (Sprint 9 full bridge: tqp-executor.sh) ships and the executor is verified. **Verification command:** `bash scripts/auto-heal.sh 2>&1 | grep -A 1 "CHECK 28g"` — verdict should read `WARN: N atom(s)...` not `CRITICAL: N atom(s)...`. **Rollback:** revert 3 lines in auto-heal.sh (CRITICAL back), revert this LESSONS entry. **Linked:** TKT-0504-A0, CHG-PENDING.

## L-116 | 2026-06-15 | Infra | Cloud-Cron Escalation: 7th silence-failure in lineage

**Severity: High (P0 platform reliability).** Ollama outage 2026-06-13 15:31 to 2026-06-15 10:04 AEST (42.5h) went undetected for 30+ minutes because the only check that surfaces cron failures is the 30-min heartbeat. The 6 cloud-modelled crons that failed (TQP, PG-Notion Sync, Allowlist Sync TRIGGER-12, Forge Fallback Chain, WO-002 Divergence, Yoda context-brief-refresh) all had 3-47 consecutive errors before Ken manually noticed.

**Root cause:** All cloud-modelled crons share a single Ollama Cloud weekly budget under the `beautiful_faraday_411` account. When the cap hits (every ~Sun/Mon), every ollama/* job fails simultaneously. The 30-min heartbeat cycle was too slow to surface this as a cluster failure.

**Fix pattern (CHECK 29 in auto-heal.sh):** Filter cron-health-alert.json failures to those with consecutiveErrors >= 3 AND model starts with `ollama/*` (cross-referenced against state/cron-models.json, a static map derived from `openclaw cron list --json`). Escalate via sovereign-alert.sh with 6h cooldown via state/check29-last-fire.json. Idempotent (re-runs within 6h show SKIP).

**Verified:** 2026-06-15 10:54:08 AEST — full auto-heal run, CHECK 29 detected synthetic alert with 2 cloud cron failures (50 and 48 consecutiveErrors), sent Telegram alert HTTP 200, state/check29-last-fire.json written with ts/count/crons. Re-run: SKIP (cooldown active).

**Tied to:** L-088 (main session lane hijack), L-089 (CREST tool rejection), L-090 (zsh read -p), L-091 (crest-done-gate.sh syntax), L-095 (TQP queue JSON/PG divergence), L-096 (TQP claimed-but-not-executing), L-100 (obs.db signature dedup), L-105, L-107 (CREST routing). All 8 in same silence-failure family.

**Follow-up:** Recommendations #1 (per-cron quota tracking), #3 (kimi+deepseek combo for critical crons), #4 (state/ollama-quota-state.json with 24h-pre-exhaustion alert), #5 (EOD health-assert gate) all queued for Ken approval.

## L-117 | 2026-06-15 | Infra | auto-heal CHECK 25 silent crash: orphan try/except in Python heredoc

**Severity: Critical (P0 hidden infrastructure bug).** auto-heal.sh CHECK 25 (CREST Tool-Call Rejection Recovery, L-089) had a Python SyntaxError on every run from 2026-06-13 14:14 to 2026-06-15 10:54. The orphan `except Exception as e: continue` block at lines 1426-1427 was at 4-space indent, which Python interpreted as matching a try that had already closed (the try on line 1347 had only one statement in its body, closed by except on line 1349). Result: `SyntaxError: invalid syntax` at `<stdin>` line 81. The `set -u` and `trap 'CRASH DETECTED'` in auto-heal.sh silently absorbed the crash and wrote `exit_status=crashed` to state/auto-heal-current.json, but no Telegram alert fired.

**Effect:** CHECK 26, 27, 28f, 28g, 28h, AND the new CHECK 29 (Cloud-Cron Escalation, L-116) NEVER ran in production for 2 days. The CHECK 25 bug was hiding every other check downstream.

**Discovery:** During the 2026-06-15 outage shakedown, while independently verifying CHECK 29, the auto-heal crashed at CHECK 25. Investigation revealed the orphan except/continue. Fix: 2-line delete. Re-verified: CHECK 25 PASS, all downstream checks now run.

**Tied to:** L-091 (crest-done-gate.sh syntax), L-089 (CREST tool rejection), L-116 (this lineage). All 3 are "script crashed but no alert fired" — same root cause family.

**Lesson:** auto-heal.sh should validate its own embedded Python heredocs at build time. Suggested future CHECK 30: `bash -n` and `python3 -c "compile(open('auto-heal.sh').read(), '<test>', 'exec')"` on the embedded Python blocks. Until then, any new Python heredoc is a regression risk.

**Anti-regression:** Add a pre-commit hook that runs `python3 -c "compile(open('scripts/auto-heal.sh').read().split('python3 <<PYEOF')[1].split('PYEOF')[0], '<heredoc>', 'exec')"` on each embedded Python block.

## L-118 | 2026-06-15 | Infra | Ollama Quota Canary: 24-72h pre-cliff prediction

**Severity: High (P0 platform reliability).** Ollama Cloud has no public quota API (404 on /api/usage, /api/account, /api/me, /api/settings). Cannot predict cap exhaustion from a balance endpoint. But the 24-72h pre-cliff canary signal IS available: when a cron first flips to `state.lastErrorReason == "rate_limit"`, that's the canary. Historical pattern (2026-04-26, 2026-05-22, 2026-06-02, 2026-06-13) shows rate_limit hits start 24-72h before the full cluster failure. CHECK 30 watches this signal.

**Fix pattern (CHECK 30 in auto-heal.sh):** Snapshot `openclaw cron list --json` (cached for 30min). Filter jobs where `state.lastErrorReason == "rate_limit"`. If count > 0 and 12h cooldown clear, fire sovereign-alert with: (a) list of rate-limited crons (top 15 by consecutiveErrors), (b) recommended shed order (governance/daily-brief crons to disable first if total climbs >25), (c) context on the cap pattern (Sun/Mon hits, Tue recovers).

**Verified:** 2026-06-15 11:02:45 AEST — real auto-heal run, CHECK 30 detected 15 rate-limited crons (live state, count was 20 earlier in this session), sent Telegram alert HTTP 200, state/check30-last-fire.json written with ts/count/crons (15 cron entries with names and consecutiveErrors). Idempotent re-run within 12h: SKIP cooldown.

**Pairs with:** CHECK 29 (L-116, reactive 3+ consecutive errs). Together: complete outage prevention. CHECK 30 = canary 24-72h before cliff. CHECK 29 = response during cliff.

**Tied to:** L-088/L089/L090/L091/L095/L096/L100/L105/L107/L116/L117 (silence-failure family). 9th member.

**Lesson:** When an external API doesn't expose the data you need, the canary is in the OBSERVABLE side-effects. The 429 error message is the canary. The cluster-failure pattern is the cliff. Build your pre-warning from what's already visible.

**Followup:** Build a daily digest of CHECK 30 fires (count of canary events per week) so we can measure cap proximity over time. Also: shed-recommendation should be enforced (auto-disable crons when total >25) — currently advisory only.

## L-119 | 2026-06-15 | Infra | Critical-cron multi-vendor migration: kimi primary for TQP + Auto-Heal

**Severity: High (P0 platform reliability).** During the 2026-06-13/15 outage, the 2 most critical crons died with the cluster: TQP bridge (every 5min, dispatches Forge atoms) and Auto-Heal (nightly, runs the 27-check sweep). Both were on models with shared Ollama caps that hit all at once.

**Live state analysis (2026-06-15 11:05 AEST):** gemma4:31b-cloud 13 rate-limited, deepseek-v4-pro:cloud 6 rate-limited, kimi-k2.6:cloud 0 rate-limited, minimax-m3:cloud 0 rate-limited. The cap is on the account `beautiful_faraday_411`, not per-model — but kimi and minimax-m3 happened to be on different rate-limit windows this week.

**Fix pattern (per-cron exception, not policy change):** Switched TQP (dc88affb) and Auto-Heal (e269d620) primary model from `ollama/gemma4:31b-cloud` (Auto-Heal) / `ollama/deepseek-v4-flash:cloud` (TQP) to `ollama/kimi-k2.6:cloud`. Backend tier fallback chain (gemma4 → deepseek-pro → kimi) at the model-policy.json tier level still covers them if kimi also fails.

**Verified:** Both crons now show `lastStatus=ok`, `consecutiveErrors=0` (was 48 for TQP, 2 for Auto-Heal), `lastDurationMs=9.9s` (TQP) and `15.2s` (Auto-Heal). Schedules intact (TQP every 5min, Auto-Heal cron 0 1 daily AEST). Both enabled.

**Tied to:** L-116 (CHECK 29 reactive), L-117 (CHECK 25 silent crash), L-118 (CHECK 30 predictive canary). The complete outage prevention layer: 30 (canary 24-72h) → 29 (reactive escalation) → 119 (multi-vendor critical crons).

**Lesson:** When your escape pod is on the same ship as the fire, you don't have an escape pod. Multi-vendor model assignment for critical paths is structural resilience, not nice-to-have. The kimi "fallback only" policy was correct for general use but should have a documented exception process for critical-path crons. Suggest adding to model-policy.json: "criticalPathOverride: { tier: 'backend', primaryOverride: ['TQP', 'Auto-Heal', 'Warden'] → kimi-k2.6:cloud }".

**Anti-regression:** TKT-XXXX (raise): per-cron health score based on last 7-day uptime. If a critical cron drops below 95%, auto-suggest multi-vendor migration.

## L-120 | 2026-06-15 | Infra | EOD health-assert gate: BLOCK on degraded state

**Severity: Medium (P1 platform reliability).** EOD finalizer (Journal 23:55, Blog 00:05, Drive 00:30) ran without asserting system health. If a cloud cron was failing or cost-state was stale, EOD wrote a green journal entry for a broken system, masking overnight outages.

**Fix pattern (TKT-REC5):** New `scripts/state-health-assert.sh` (215 lines, 5 checks):
1. CRON_HEALTH: any ollama/* cron with >=3 consecutive errors + reason
2. COST_STATE_FRESH: state/cost-state.json modified within 2h
3. WARDEN: state/warden-violations.json empty or last alert acked
4. CRITICAL_CRONS_ALIVE: TQP, Auto-Heal, Task Monitor all lastStatus=ok
5. CHECK30_QUIET: state/check30-last-fire.json >6h old AND no current rate_limit crons

Wired into 3 EOD crons (Journal 4d926b2c, Blog a027fd60, Drive c5a3911d) as Step 0.a gate. On FAIL: writes state/eod-blocked-{date}.json, sends Telegram, aborts EOD. Blog + Drive check block file and skip if present.

**Verified in production (real run 11:18 AEST 2026-06-15):**
- 4 of 5 checks pass: CRON_HEALTH (2 crons have >=3 errs with reason; CHECK 29 would have caught these), COST_STATE_FRESH (51s old), WARDEN (no violations file), CRITICAL_CRONS_ALIVE (TQP/Auto-Heal/Task-Monitor all ok)
- 1 check fails: CHECK30_QUIET (18 crons currently rate-limited)
- Exit code 1, block file written, Telegram HTTP 200
- EOD for 2026-06-15 is currently BLOCKED — will alert Ken at 23:53 AEST
- Idempotent: re-runs produce consistent exit 1

**Tied to:** L-116 (CHECK 29), L-118 (CHECK 30), L-119 (multi-vendor migration). The complete outage prevention layer now has 4 components: predictive canary, reactive escalation, multi-vendor survival, EOD hold gate.

**Lesson:** Finalizers must assert state health before declaring success. A green journal entry should mean the system is healthy, not just that the journal script ran. The block file pattern (state/eod-blocked-{date}.json) is a clean way to chain 3 separate crons: producer (Journal) writes the block, consumers (Blog, Drive) read it.

**Anti-regression:** If a critical cron is moved or renamed, the CRITICAL_CRONS_ALIVE check will silently skip. Add a comment in the script listing the cron IDs and a test for "all 3 cron IDs exist before checking state". Followup: TKT-XXXX — auto-create the cron ID list at script startup by querying a tag/label.

## L-121 | 2026-06-15 | Infra | AGENTS.md trim: 12,252 → 7,351 chars (40% reduction)

**Severity: Low (P2 file hygiene).** AGENTS.md breached HARD LIMIT 12,000 per TKT-0310 file-size-guard. Auto-heal CHECK 15 would flag it. Injected files over the limit cost session context bloat.

**Fix pattern (TKT-REC6):** Compressed 4 heavy rule sections to 1-line summaries pointing to RULES.md:
- Platform Rules table (28 lines, ~2500 chars) → 3-line summary
- 3 Strikes Principle (9 lines, ~700 chars) → 3-line summary
- Dispatch Rules (35 lines, ~2500 chars) → 4-line summary
- Interim Rule + KIMI (6 lines, ~500 chars) → merged 3-line KIMI summary

**Verified (real file edit, 11:25 AEST 2026-06-15):**
- BEFORE: 12,252 chars (BREACHING 12,000 hard limit)
- AFTER: 7,351 chars (well under 11,500 target, 4,901 char reduction = 40%)
- 13 ## section headers preserved (1 fewer than before due to Interim/KIMI merge — both kept in KIMI summary)
- 9 RULES.md references in the new file (preserved discoverability)
- All 14 key terms still present: 2-Pass Contract, RVEV, CREST, Plan gate, Strike-1/2/3, KIMI, Conservative Mode, CHG-0500, TKT-0396, dispatch-validate, CHANGELOG.md, file-size-guard

**Tied to:** TKT-0310 (file-size-guard), TKT-0341 (workspace file contracts), MEMORY.md trim EOD sections pattern. The contract is: "AGENTS.md = summary + conventions + workspace structure. Details → RULES.md." This trim is the first application of that contract since TKT-0341 was ratified.

**Lesson:** When a workspace file breaches its hard limit, the right move is progressive disclosure: keep the rule names in the high-traffic file (AGENTS.md, injected), relocate the full text to the reference file (RULES.md, on-demand). Same content, two different access patterns. Skills already follow this pattern (SKILL.md files are progressive-disclosure from MEMORY.md/AGENTS.md).

**Anti-regression:** file-size-guard.sh should be re-run nightly and alert Ken if AGENTS.md approaches 11,000 (1,000-char buffer). Currently CHECK 15 is daily; the threshold should be tightened. Followup: TKT-XXXX — adjust file-size-guard warning threshold.

## L-122 | 2026-06-15 | Infra | Honest backfill framing for silent days

**Severity: Low (P2 documentation hygiene).** During the 42.5h outage, the platform wrote nothing. When Yoda woke up on 2026-06-15 and reviewed state, three files were missing: journal-2026-06-14.md (heartbeat completeness fires on this), ainchors-2026-06-13/index.html, ainchors-2026-06-14/index.html (blog verification at 06:00 AEST fires on this).

**Decision: do NOT fabricate.** The temptation is to write plausible-looking entries that match the date. The discipline is: write what actually happened. The 06-14 journal is a single post-mortem entry that records the silence. The 06-14 blog is "The Silent Day" — same post-mortem, more reflective. The 06-13 journal gets a 15:35 entry appended that records the outage start with explicit "backfilled 36h after the fact" disclosure.

**Fix pattern (TKT-REC7):**
1. Identify what actually happened on the silent day by reading: cron state, auto-heal logs (if any), incident-log.json, recovery-day journal (06-15), state files.
2. Write post-mortem doc with: (a) 0 entries / 0 sessions in Session Overview, (b) explicit "no agent activity" framing, (c) outage timeline, (d) what was alive vs what was dead, (e) reference to the structural fixes that prevent the next occurrence.
3. Use LOCKED templates (CSS, journal header format) verbatim.
4. Append outage-start entry to the day-before journal with explicit backfill disclosure.

**Verified:** 4 files written, all using 06-12 templates verbatim (CSS diff = 0 lines). 06-14 journal = 3,698 bytes. 06-13 journal grew to 30,069 bytes (+1,130). 06-13 blog = 22,181 bytes. 06-14 blog = 20,149 bytes. Auto-heal blog verification check (06:00 AEST) will now pass.

**Tied to:** All silence-failure family lessons. The pattern of writing-what-actually-happened is the same discipline as L-113 (evidence-only) and SOUL.md #13 (no fabrication) and #14 (evidence-only).

**Lesson:** When reconstructing history, resist the urge to fill the gap with plausible content. The gap itself is information. A "platform silent" day in the journal is a real record. A fabricated busy day would be a lie that compounds over time.

**Anti-regression:** If a day is missing journal/blog in the future, default to post-mortem. Don't ask "what should I write?" — ask "what actually happened?" The answer is usually: nothing. That's the truth, and it's the right entry.

## L-123 | 2026-06-15 | Process | TKT-0503 close: L-115 fix held, full payload worked

**Severity: Low (P2 process verification).** TKT-0503 close required updating metadata with 3rd grooming_history entry. Per L-115 (db-ticket.sh update replace-not-merge, 06-13 14:32 incident), the update payload MUST include the FULL metadata block, never a subset.

**Fix pattern (TKT-REC8):** Forge spawned, read TKT-0503 fully (7047 bytes), built the full update payload in python3 by reading JSON, modifying status + appending grooming entry + updating close_decision + adding closed_at, then sent the FULL JSON via `db-ticket.sh update TKT-0503 "$(cat update.json)"`. Removed read-only fields (id, created_at) per script's allowlist.

**Verified:** TKT-0503 final state — status=closed, 3 grooming_history entries (was 2, now 3), 11 linked_lessons preserved, 7 atom_status preserved, 5 re_verify_findings preserved, closed_at=2026-06-15T11:38:00+10:00, notion_sync.status=synced.

**Tied to:** L-115 (the bug this fix prevents), L-113 (evidence-only), SOUL.md #14 (evidence-only).

**Lesson:** L-115 is a *behavior fix*, not just a code fix. Every close/update of a ticket with rich metadata must rebuild the full payload from a fresh read, never assume a partial payload will merge. The same discipline applies to any update via tools that use replace-not-merge (e.g., `git config --replace-all`, `jq '.field=new'` without preserving siblings).

**Anti-regression:** When Yoda or Forge closes a ticket with >5 metadata fields, default to: read full ticket → python3 merge in-place → write full payload. Never `db-ticket.sh update TKT-XXXX '{"field": "new_value"}'` — that's the L-115 bug shape. Add a dispatch-validate.sh check that flags partial payload updates.

## L-124 | 2026-06-15 | Infra | TKT-0339 scaler vA6: 10 DECREASE timeouts applied

**Severity: Low (P2 cost optimization).** TKT-0339 (Cron Timeout Auto-Scaling) scaler vA6 found 10 crons with over-conservative timeouts. The cron-timeout-apply.sh script enforces 7d stability (L-099 safety net, "Ken-triggered, never implicit"). Ken's explicit approval today is the green light to bypass the 7d check for these 10.

**Fix pattern (TKT-REC9):** Per-cron apply via `openclaw cron edit <id> --timeout-seconds <new>` for each of 10 crons. Update state/cron-timeout-applied.json with appliedAt + appliedTo. Most aggressive: 3fb65682 QBR Execute 14400s→180s (4h→3min), but this is a 1-shot deleteAfterRun cron that fires once on 2026-07-01 09:00 AEST, so 3min is plenty.

**Verified:** All 10 timeouts applied. Ledger shows 10 applied, 3 pending (pre-existing from earlier scaler runs, not vA6 targets). Independent Yoda verify: 3 spot-checks (Aria ROI=300s, QBR Execute=180s, PG-Notion Sync=120s) all confirmed.

**Tied to:** L-099 (Ken-triggered safety net), TKT-0339 (scaler), TKT-0503-A6 (one-shot apply).

**Lesson:** The 7d stability check is the right default. Bypassing it requires explicit Ken approval. The bypass path is well-defined: per-cron apply with --yes flag, appliedAt timestamp recorded in ledger for audit. This pattern (stricter default + explicit bypass) is the right shape for any auto-mutation system.

**Anti-regression:** Don't change the 7d default. Don't add an "auto-apply after 7d" flag. The current design is "Ken-triggered, never implicit" for a reason — auto-apply on a 1-shot cron (like 3fb65682 QBR Execute) would have applied 180s while the cron was being designed, before the timeout was even meaningful. The Ken check is the safety.

**Notable correction:** Forge caught a prefix mismatch in the Yoda spec (Aria was 7a4d8381, not 3305681f). The ledger had 13 entries (10 vA6 + 3 pre-existing). Forge correctly identified the right prefix and applied the right value (kept Aria at 300s since the computed target was 300s, not 180s as my spec said).

## L-125 | 2026-06-15 | Process | aria-crest-check.sh: trailing double-quote on line 21

**Severity: Low (P2 process verification).** `scripts/aria-crest-check.sh` line 21 had `DB_SCRIPT="/scripts/db-raw.sh""` — an extra trailing double-quote from a paste-o or merge artifact. Bash parser got confused, reported the syntax error at line 136 ("unexpected EOF while looking for matching `''`") because that's the next location that would close the spurious string. CHECK 27 has been FAIL in every auto-heal run since 2026-06-13 (12+ runs).

**Fix pattern (TKT-PREEXIST-1):** Single-character deletion — remove the trailing `"` on line 21. Verified with bash -n (exit 0) + live run (`CLEAN: Aria CREST compliant`, 0 violations, 0 warnings).

**Lesson:** When bash reports a syntax error at a line far from the actual bug, the real cause is almost always on an earlier line. In this case, line 21's `""` opened a string that wasn't closed until the next opportunity (the `f"` Python f-string at line 136). When a heredoc body's syntax error points to a line inside the body, check the lines BEFORE the heredoc for unbalanced quotes.

**Anti-regression:** Add a "bash -n before commit" pre-commit hook for all scripts in `scripts/`. The hook should reject any script that doesn't pass bash -n. The original bug shipped because nothing was running bash -n at commit time. L-125 is the 16th in the silence-failure family but the first syntax-error type.

**Tied to:** L-088+ (silence-failure family, all categories), the file-size-guard CHECK 15 (which checks size, not syntax), the per-script run-on-edit discipline.

## L-126 | 2026-06-15 | Infra | auto-heal.sh CHECK 28c crash: 3 bugs in 1

**Severity: High (P1 platform reliability).** CHECK 28c (sandbox gateway 24h auto-unload, L-094) has been "crashing" — but the actual crash was 2 layers of bugs upstream that masked the real one. Subagent verification during Rec #9 found all 3.

**The 3 bugs (in discovery order):**

1. **Line 1941, 1960 — `exit 0 2>/dev/null` in CHECK 30 SKIP path** (the primary symptom)
   - When CHECK 30 hits its cooldown SKIP, the code calls `exit 0` — which terminates the ENTIRE auto-heal.sh script, not just the CHECK 30 block
   - Result: CHECK 28d, 28e, 28c never run, final report never written
   - This was the "crash" the user saw
   - Fix: replaced with `:` no-op + comment. CHECK 29 has the correct pattern (`log SKIP; fi`)

2. **Line 2139 — `datetime.fromisoformat('None')` ValueError in CHECK 28c** (the secondary symptom, exposed by fix #1)
   - State file `state/sandbox-gateway-state.json` (TKT-0505-A4 bootstrap) has `"deadSince": null`
   - Python's `.get('deadSince', '')` returns None (not '') because the key EXISTS with value null — default is only used for MISSING keys
   - Bash then sets `DEAD_SINCE="None"`, downstream python does `datetime.fromisoformat('None')` → ValueError
   - Trap catches it → `write_state "crashed"` → exit 1
   - Fix: `.get('deadSince') or ''` to coerce None to empty string

3. **Line 2256 — zsh-only `${(j:,:)CHECKS_RUN}` in a python heredoc** (a follow-up observation, NOT fixed here)
   - The final PG write uses zsh parameter expansion inside a python3 heredoc
   - This works under `#!/bin/zsh` (which the script is) but fails with "bad substitution" if run under bash
   - The cron uses zsh, so this is fine in production — but anyone running `bash auto-heal.sh` (e.g., for testing) hits it
   - This is a separate pre-existing issue. Not in scope for this fix.

**Verified (real zsh run, 12:11 AEST 2026-06-15):**
- CHECK 28c reaches "Sandbox gateway dead for 0.1h — within 1h grace period" (no crash)
- `=== AUTO-HEAL COMPLETE ===` logged
- Exit 0
- All checks reached: 30 → 28d → 28e → 28c

**Fix pattern:** When a subagent reports "found another bug while verifying the original", keep going — bugs cluster. Each layer of "this should work but doesn't" often has another beneath. The defensive `.get(key) or ''` pattern is a better default than `.get(key, '')` for any value that could be null in the source JSON.

**Lesson:** Defensive JSON parsing. The `dict.get(key, default)` Python pattern is well-known but has a subtle gotcha: it only applies the default when the KEY is missing, not when the value is null. For state files that may have nulls, use `dict.get(key) or default` to handle both cases. Apply this to all auto-heal CHECK 30+ scripts that read state files.

**Anti-regression:** Add a "null-safe JSON access" linter or pattern check. For new state file fields, write `field: ""` (empty string) not `field: null` in bootstrap. For existing state files, the `.get(key) or ''` pattern is the right fix.

**Pre-existing #2 task complete.** Followup: TKT-XXXX — add final `write_state` call at end of auto-heal.sh (currently write_state at line 1308 runs before CHECK 28c, so the report's `checks_count` is always 25 even after all checks run). Also: refactor the line 2256 zsh-specific python heredoc to be shell-agnostic.
