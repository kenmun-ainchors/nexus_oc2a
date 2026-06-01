# Yoda Daily Brief
_For Aria + Angie | AInchors Nexus Platform | Plain language summary_

---

## Monday, 1 June 2026

### What Yoda Built Today

Today was a heavy platform operation day — Sprint 6 fired up, and Ken drove a series of decisive infrastructure moves that turned the platform from "working" to "battle-hardened."

**CrewAI Crash Recovery → Platform Shakedown:** Yesterday's experiment with CrewAI (a multi-agent framework) crashed the whole platform — it corrupted Homebrew packages and took node offline. Ken restored everything manually, then commissioned a full health check. Result: all data survived — 31 database tables, 263 tickets, all 14 agents, all integrations (Telegram, Notion, Gmail, Calendar, file storage) confirmed healthy. Three repair items found and fixed. The crash was expensive in time but zero data was lost — a real testament to our backup and resilience design.

**Cloud Cost Kill-Switch — 14 Crons Flipped to Zero-Cost:** Ken identified that 12 of 14 automated cron jobs using the "gemma4" model were just wrapping shell scripts — burning AI tokens to do things a script can do directly. Converted all 12 to run without any AI model at all. Also converted 2 more using "deepseek-pro" (the expensive model) — one of those was firing 288 times a day and burning tokens on every call. Net impact: ~70% drop in cloud AI calls per cycle, substantial cost reduction without losing any functionality.

**Postgres Becomes the Single Source of Truth:** Completed the migration from JSON files to Postgres database as the platform's one-and-only source of truth. The old dual-write system (write to both file and database) has been retired. All 263 tickets now live exclusively in Postgres, with daily compressed backups that are automatically verified. We can now prove that every backup restores perfectly.

**Sprint 6 Locked and Started:** The next 2-week sprint is locked — 13 items (down from 14 after consolidation), already 3 completed on Day 1. The sprint covers: database hardening, backup improvements, crash-recovery patterns, the big context-optimization project (making agents use less memory), work checkpointing, and platform constraints documentation.

**Platform Constraint Limits Documented:** Thrawn (our infrastructure architect agent) completed a full audit of every limit in the platform — file sizes, context windows, memory caps, everything. This means we now have concrete numbers: we know exactly when files are getting too large, when memory is at risk, and where growth could cause problems. Automated checks now enforce these limits nightly.

**Fold SOP Created:** Ken identified that when we "fold" (combine) tickets together, we were losing knowledge. Worked through it live — now there's a strict 5-gate procedure: extract scope, migrate it, update the parent, close properly, sync to Notion. No more lost work on ticket consolidation.

### Key Decisions Made

- **Cloud AI model usage reduced by ~70%** — 14 crons converted from AI-model to direct script execution. Shell-wrapping AI models for script execution is now a documented anti-pattern to avoid.
- **Postgres is now the sole source of truth** — JSON dual-write retired. All tickets, state, and backups verified. Backup+restore tested and proven.
- **Sprint 6 locked with 13 items** — focused on hardening, optimization, and crash resilience
- **CrewAI experiment parked until new hardware arrives** — the AI model needed for it (23GB) won't fit on current machine (24GB shared), so parked until the new 48GB OC2 machine arrives (est. 6-13 July)
- **All tickets must now have full descriptions, not just titles** — no more empty ticket bodies. This is now enforced.
- **Fold operations now follow a 5-gate procedure** — scope must be preserved in the parent ticket, not lost. Documented and locked into platform rules.
- **AGENTS.md slimmed from 18.4KB to 11.6KB** — stays within platform file size limits, reducing context waste
- **File size limits now enforced automatically** — nightly checks catch oversized files before they cause problems

### Training Content Ideas from Today

- **TC-185: When your experiment crashes the whole platform — how to survive and learn from a failed AI framework installation** — CrewAI crashed Homebrew, corrupted node, and took the platform down. But 31 database tables, 263 tickets, and all 14 agents survived intact because of backup discipline. The shakedown and recovery process, plus packaging the learnings into regression tests.
- **TC-186: The shell-wrapper trap — why wrapping scripts in AI models burns money for nothing** — 12 of 14 cron jobs were running a Gemini-class AI model just to execute shell commands. Converting them saved ~70% of cloud AI calls. How to audit your automation for this pattern and kill it.
- **TC-187: From files to database — the real migration story (not the tutorial version)** — Postgres migration completed: dual-write retirement, backup verification, backup tested against live database. The practical steps, the rollback drill, and why "the backup worked" is the most important sentence in any migration.
- **TC-188: Know your limits — platform constraint auditing as an operational discipline** — Thrawn mapped every hard and soft limit in the platform (file sizes, context windows, memory, timeouts). Without this, you're guessing when things will break. With it, you have a dashboard.
- **TC-189: The Fold SOP — how to combine work items without losing knowledge** — 5 gates (extract → migrate → update → close → sync) turned a knowledge-loss pattern into a documented, repeatable procedure. All 7 folded tickets audited: scope gaps found and closed.
- **TC-190: Context discipline 401 — why ticket bodies matter more than ticket titles** — Ken's "every ticket must have description" rule, reinforced minutes later when a ticket re-groom revealed none of the folded tickets had descriptions. The pattern of "title-only" tickets and why they're a knowledge debt time-bomb.

### What's Open / What's Next

- **Sprint 6 is active** — 3 items done (PG sole SSOT, PG backup, platform constraints), 10 remaining. Ceremonies (review + planning) due Sunday 14 June.
- **TKT-0317 (Context Optimization Epic)** is the big one — consolidating agent rules, reducing the 92% duplication found in the audit. 6 child tickets, multi-phase rollout.
- **TKT-0322 (Model-Task Routing Matrix)** is pre-groomed and ready — which agents should use cheaper models vs premium ones
- **OC2 hardware arrival** (est. 6-13 July) is the next major platform event — triggers Claude restore, platform separation, Postgres migration to dedicated machine, and CrewAI PoC restart
- **429 rate limit monitoring** — Ollama Cloud rate limiting means the tilde-path fix (TKT-0327) is parked until capacity frees up
- **Platform is in steady-state ops** — all crons healthy, all integrations live, no active incidents
