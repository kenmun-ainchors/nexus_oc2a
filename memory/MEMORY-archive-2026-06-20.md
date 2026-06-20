# MEMORY Archive — 2026-06-20

Archived from `MEMORY.md` on 2026-06-20T06:10:44+0000.

These sections remain searchable via memory_search but are no longer loaded into the default session context.

## Session Model Drift — 3 Structural Locks (LOCKED 2026-06-20, CHG-0684, TKT-0547)
- **Problem:** Live session model overrides are invisible to model-drift-check.sh (only checks openclaw.json static config). Ken caught Yoda on deepseek-v4-pro instead of kimi-k2.7-code 10:26 AEST.
- **Lock 1 (Heartbeat):** `scripts/check-session-model.sh` runs every heartbeat — queries live session via openclaw CLI, validates against policy. Drift → alert + auto-reset.
- **Lock 2 (Auto-Reset):** `scripts/switch-model-temporary.sh` — wrapper for temporary pro switches. Writes pending-model-reset.json; Yoda schedules one-shot reset cron. NEVER use raw `session_status model=...` for temporary switches.
- **Lock 3 (Warden):** `model-drift-check.sh` now includes [Live Session Model Check] section. Warden cron (15 min) catches any agent session drift.
- **Yoda primary:** kimi-k2.7-code. **Pro only for:** CREST Plan/Replan phases. Switch via `switch-model-temporary.sh deepseek-v4-pro 30m`.

## Security & Network
- S1–S7: see `RULES.md`. Tailscale: OC1 serve, S2 compliant. CHG triggers: load skill `bash scripts/skill-load.sh changelog`.

## Platform Phase Definitions (LOCKED 2026-05-12 — Ken Mun)
- **MVP** — OC1-only, two founders, core platform live (now).
- **P1** — OC2 era, HA cluster, NAS, KL team (~Jul 2026)
- **P2** — SaaS: individuals + SME, first paying clients, Citadel live (~Aug 2026)
- **P3** — SME onsite install ⚠️ PARKED
- **P4** — Enterprise: multi-tenant, BYOK, Holonet

## KL Team & Sprint Capacity
- KL, Malaysia. 4–5 headcount. P1: Cloudflare Access, role-scoped IAM.
- Sprint capacity + pending tickets: load skill `bash scripts/skill-load.sh pg-sprint-backlog`.

## Anthropic — PERMANENTLY PARKED (2026-06-12 08:12)
- **Directive (Ken verbatim):** "Anthropic credits and model enablement - Permanently park until I provide future instruction and update"
- **What this means:** NO Anthropic API key rotation, NO higherQuality tier activation, NO agent assignment to Anthropic models, NO TKT-0241 work, NO `globalAllowedModels` additions of new Anthropic variants. Anthropic stays as a documented option in policy but is **not active**.
- **Unblock keyword:** Ken must explicitly say "CLAUDE ACTIVATE" (or similar) to unblock. Until then, all Anthropic work is parked.
- **Monitoring:** NONE. No alerts, no reminders, no review cadence. This is a permanent park by design.
- **Reference:** `state/parks/anthropic.json` (full scope, unblock conditions, related artifacts). CHG-0502.
- **Linked:** TKT-0241 (now status=parked, was ungated by CHG-0500, re-parked by CHG-0502 per this directive), CHG-0500 (CLAUDE RECONFIGURE — risk framework is CREST v1.3, not Anthropic), CHG-0502 (this park), state/parks/anthropic.json.
- **Anti-regression:** TKT-0241 status changed from "open (ungated)" to "parked". The `higherQuality` tier in model-policy.json has `agentIds: []` and `active: false` — must stay that way. If any future work proposes Anthropic enablement, check this section + state/parks/anthropic.json first.

## Config Baseline (Day 20)
→ See `state/critical-config-baseline.json` for live drift detection.

## Old-Code Audit Policy — TKT-0529 (Ken decisions 2026-06-18 08:11 AEST)
When remediating high-risk legacy scripts:
1. **Auto-destructive hygiene ops in `auto-heal.sh` are retained** (rm stale plugin dirs, rm stale locks, kill orphan gateways, PG sequence fix) — these are health/housekeeping and have proven safety history.
2. **Exception:** auto-summarize oversized context files (rewrites SOUL.md/AGENTS.md/MEMORY.md/HEARTBEAT.md) must be gated → `NEEDS_KEN`, not auto-executed.
3. **Atomic state writes** use a new shared lib at `scripts/lib/atomic-write.sh` (not inlined per script).
4. Every production script gets `set -euo pipefail` and replaces hardcoded `/Users/ainchorsangiefpl/` paths with `${WORKSPACE_ROOT}`.

## kimi Policy — DECOMMISSIONED 2026-05-26
DeepSeek = permanent primary. kimi = fallback only. Full history: `memory/MEMORY-archive-2026-05-27.md`.

- 2026-05-25: TKT-0295 (PG Audit) parked due to Tier 3 budget breach.
---

_Historical EOD sections archived to `memory/MEMORY-archive-2026-06-09.md`._

