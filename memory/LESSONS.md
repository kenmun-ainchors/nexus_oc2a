# LESSONS.md — Yoda Lessons Learned Log
# AInchors Nexus Platform
# Format: L-NNN | Date | Category | Lesson | Source incident/CHG
# SSOT for all platform learnings. Updated as new lessons are logged.
# Last updated: 2026-05-11

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
