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
