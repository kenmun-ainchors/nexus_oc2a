# Decisions Log
_Key decisions made. Dated. Permanent record._

---

## 2026-04-25
- **Yoda** chosen as lead AI agent (CTO stream, oversees all)
- **Two-stream architecture** adopted: Technical + Business
- **File-based shared memory** as agent coordination backbone
- **Gmail** as primary email provider
- **Social priority:** Instagram → Facebook → LinkedIn
- **Project management tool:** TBD
- **Remote dashboard (Tailscale):** Deferred to Phase 4
- **Agent build order:** Foundation → Technical → Business → Full Ops

## 2026-04-26
- **Model strategy approved** — Sonnet 4.6 default, Opus for high-stakes, Gemma4 background-only (explicit whitelist)
- **Budget cap set** — A$500/month (Sonnet + Opus). Alert at A$400.
- **Auto-escalation rule** — Sonnet fails twice → Opus on attempt 3, Ken notified
- **Monthly model review** — end of every month, Ken explicit sign-off required
- **API outage fallback** — Gemma4 sends status alert to Ken, queues work, waits for Sonnet
- **7-day shadow period** — 2026-04-26 to 2026-05-03, log Gemma4-eligible tasks before live routing
- **FileVault + auto-login conflict** — FileVault stays enabled (security non-negotiable). Auto-login not possible. Known limitation: power trip requires physical login to unlock. Mitigation: remote KVM (PiKVM) recommended long-term. Solar battery covers >99% of outages. Outlier: 2026-04-26 planned circuit shutdown.
- **Pre-risky-op checkpoint rule** — Before any operation that risks breaking or restarting OpenClaw (updates, gateway restarts, major config changes), Yoda MUST: (1) flush all context to persistent storage, (2) clear stale plugin-runtime-deps dirs, (3) git commit, (4) confirm to Ken. After op: run PVT when available. Approved 2026-04-26. Updated 2026-04-26 after INC-003.
- **plugin-runtime-deps cleanup** — Before every gateway restart: `rm -rf ~/.openclaw/plugin-runtime-deps/openclaw-unknown-*` to prevent ENOTEMPTY crash loop. Root cause: INC-20260426-003 (116 min outage). Approved 2026-04-26.

## 2026-04-27
- **Journal format LOCKED** — Day 2 was rebuilt to Day 1 format (verbatim Ken prompts → understanding → actions → outcome, chronological). Ken approved as the standard. Full spec: `~/Documents/AInchors/Operations/JournalFormat.md`. Future deviations require explicit approval. Approved 2026-04-27 06:44 AEST.
- **Journal vs Blog distinction LOCKED** — Two distinct end-of-day artefacts. Journal = raw record of work, Yoda's voice, recording Ken verbatim, private, built from session transcripts. Blog = curated daily summary, Ken's first-person voice, public-ready, built FROM the journal. Different purposes, different audiences, different formats. `BlogFormat.md` created as companion to `JournalFormat.md`. Approved 2026-04-27 06:46 AEST.
- **Ollama apiKey hardening** — `~/.openclaw/openclaw.json` `models.providers.ollama.apiKey` changed from placeholder string `"OLLAMA_API_KEY"` to literal `"ollama-local"`. Belt-and-braces with `auth-profiles.json`. Triggered by 2026-04-26 night outage where billing failure cascaded to ollama auth-missing error.
- **Backup cron LLM-independence** — Daily backup now has dual path: primary 02:00 (Gemma4 + Sonnet fallback, 300s timeout) + resilient 02:05 (systemEvent direct shell, no LLM). Triggered by 2026-04-27 02:00 backup timeout during outage cascade. US24 in progress.
- **Telegram cron routing fix** — Three crons (Morning Standup, Monthly Model Review, Quarterly Asset Review) had silent fail-closed delivery (`channel: last` with no chatId). Fixed to `telegram → 8574109706`. No deliveries actually missed (Yoda was running them from main session anyway), but the latent bug is now closed.
- **US23 added** — Resilient outage handling (High/Platform/M). Auto-detect billing/auth failures, validate fallback chain on boot, Gemma4 standby mode with user banner, OutageRecovery.md doc.
- **US24 added** — Backup cron LLM-independence (Medium/Platform/S, In Progress, dual-path applied).
- **3-tier resiliency framework adopted** — Health Check (every 15 min, silent operational) + Auto-Heal (nightly 23:30, proactive) + Run Diagnostics (on-demand `/diagnostics`, deep assurance). Plus Change Log (`memory/CHANGELOG.md`, append-only via `scripts/changelog-append.sh`) as single audit trail across all three. Approved 2026-04-27 07:11 AEST.
- **Auto-Heal full mode from Day 3** — Ken approved auto-fixes (stale locks, plugin-deps, dirty git commits) running immediately tonight, not staged read-only first. Risk accepted because fixes are deterministic + every action logged via changelog-append.sh.
- **`/diagnostics` chat trigger** — Single phrase to invoke run-diagnostics. Unambiguous slash-prefix prevents accidental fires. Logged in RULES.md.
- **US25, US26, US27 added** — Change Log framework (Done), Auto-Heal nightly (Done, first scheduled run tonight 23:30), Run Diagnostics (In Progress, phases 7–9 deferred).
- **🚨 Critical Config Anti-Drift Rule** — Critical configurations (model strategy, fallback chain, auth keys, workspace path) MUST NOT drift. Trigger: 2026-04-27 07:32 AEST Ken caught silent drift of agent main model from Sonnet to Opus (~3x cost burn). Codified: `state/critical-config-baseline.json` declares 7 guarded items; auto-heal Check #12 validates nightly; ANY drift on critical-severity item files needs-Ken US for standup. Update process locked: Ken decision → baseline update → config change → CHG entry → decision log → verify Check #12 passes. Approved 2026-04-27 07:36 AEST.
- **Agent main model corrected to Sonnet** — Reverted from Opus (silent drift, root cause unknown) back to Sonnet per US11. Edit applied at 2026-04-27 07:35 AEST. Effective on next session/turn.

## 2026-05-22
- **TKT-0237 before TKT-0228 — Platform verification gates before AI model drift prevention.** Fix the "done but not done" pattern first, then fix execution discipline. Ken approved 2026-05-22.
- **Yoda under same quality contract as all agents.** The orchestrator is not exempt from OWL compliance tracking, DoD gates, or quality audits. Ken approved 2026-05-22.
- **Notion DB C manual setup deferred.** Filter-based view sufficient for archive; standalone database creation not worth the complexity at this stage. Ken approved 2026-05-22.
- **Ollama Cloud cap pattern confirmed:** kimi + gemma4 share a weekly usage cap; deepseek-pro has a separate one. Long-term: may need to migrate all crons to deepseek-pro.
- **Quality enforced by platform, not agent promises.** Verification must be observable and automated — structural change to stop trusting self-reported completion.

## 2026-05-11
- **Journal format updated** — `Yoda's response (verbatim)` field added to per-entry structure. Captures Yoda's final chat reply per entry (not tool output — the message Ken received). Ken approved 2026-05-11 07:50 AEST. Spec: `Operations/JournalFormat.md`. Journal cron `4d926b2c` updated.
