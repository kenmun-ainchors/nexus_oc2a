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
