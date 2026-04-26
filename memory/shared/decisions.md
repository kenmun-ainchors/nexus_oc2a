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
- **Pre-risky-op checkpoint rule** — Before any operation that risks breaking or restarting OpenClaw (updates, gateway restarts, major config changes), Yoda MUST first flush all session context, decisions, and in-progress work to persistent storage (MEMORY.md, daily memory, decisions log, Notion). No exceptions. Approved 2026-04-26.
