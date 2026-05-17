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
