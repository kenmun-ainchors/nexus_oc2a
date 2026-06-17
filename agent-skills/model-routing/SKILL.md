---
name: model-routing
description: Model tier definitions, agent→model mapping, fallback chains, CREST phase-aware routing, OC2 trigger gates, and Gemma4 policy for the AInchors Nexus platform.
---

## Does your question involve…

1. **Which model an agent uses?**
   → **[Agent→Model Mapping](#agent-model-mapping)**

2. **Tier cost models or fallback chains?**
   → **[Tiers & Fallbacks](#tiers--fallbacks)**

3. **CREST phase routing (Plan vs Execute)?**
   → **[CREST Phase Routing](#crest-phase-routing)**

4. **Gemma4 local/OC2 migration / trigger gates?**
   → **[OC2 & Gemma4 Policy](#oc2--gemma4-policy)**

5. **Anthropic key rotation / current state?**
   → **[Key Rotation & Current State](#key-rotation--current-state)**

---

## Agent→Model Mapping

| Agent | Model | Tier |
|-------|-------|------|
| Yoda, Aria, Atlas, Thrawn | `minimax-m3` (Ollama Cloud) primary; **opt-in T3 Anthropic Sonnet** for Plan/Verify/Replan per CREST v1.3 phase map | T2 primary, T3 opt-in (CHG-0500) |
| Forge, Spark, Lando, MonMothma, Krennic | `deepseek-v4-flash` (Ollama Cloud) | T2 Primary |
| Shield, Lex, Sage, Warden | `minimax-m3` (Ollama Cloud) | T2 Primary |
| All agents | kimi fallback chain ends with `ollama/kimi-k2.6:cloud` | Safety net |

## Executor Tracking Schema

Every executor dispatch logged by the CREST execution gate records the following fields in `state/crest-execute-gate-log.json` for audit and drift detection.

### Fields

| Field | Type | Description | Source |
|-------|------|-------------|--------|
| `executor` | string | The agent that _actually_ performed the work | Gate runtime `CREST_OPERATOR` |
| `modelUsed` | string | The model that _actually_ executed | Gate runtime `CREST_MODEL` |
| `intendedRoute` | string | The agent that should have performed the work per CREST routing | Dispatch atom `target_agent` |
| `costTier` | string | T0–T3 cost classification | Derived from model-policy.json |
| `gateVerdict` | string | `allow` / `block` / `warn` | Gate decision |
| `gateReason` | string | Human-readable justification | Gate decision |

### Why They Exist (L-107, TKT-0506)

When CREST-phase dispatches bypass the intended executor (e.g., Yoda executes a mechanical file write that should have gone to Forge), the cost tier drifts from the plan. The `intendedRoute` vs `executor` comparison enables auto-heal drift checks and ensures the 2-Pass Contract (TKT-0321) is being followed.

### Log Location

`state/crest-execute-gate-log.json` — JSON array `history` with last 200 entries, plus a `lastDecision` summary. Appended via `log_decision()` in `scripts/crest-execute-gate.sh`.

## Tiers & Fallbacks

| Tier | Model | Cost | Notes |
|------|-------|------|-------|
| T0 | systemEvent | $0 | Internal events only |
| T1 | Gemma4:26b local | $0 | Post-OC2. Client-data-safe |
| T2 | Ollama Cloud (kimi/deepseek/minimax) | ~$100/mo | Current primary tier |
| T3 | Claude Sonnet/Opus | Per-token | Higher-quality option. CREST v1.3 phase model map allows strong-tier opt-in. Lifted from "fallback only" per CHG-0500. |

**Fallback chains (current):** Per-agent model-task matrix (TKT-0322). Strong-tier defaults to T2 (Ollama Cloud) with T3 (Anthropic) as opt-in for Plan/Verify/Replan when credits available. kimi as final safety net.

## CREST Phase Routing

- **Strong-tier (Plan / Verify / Replan):** Yoda, Atlas, Thrawn → `minimax-m3`
- **Cheap-tier (Execute / Synthesize):** Forge, infra executors → `deepseek-v4-flash`
- **Replan Gate:** Gap found → iterate back to Execute (n++). Stop met → Synthesize → Done.

### Dispatch Discipline Audit

A cross-check between intended route and actual execution, surfaced by two mechanisms:

1. **`scripts/crest-execute-gate.sh`** — the execution gate (Path A). At dispatch time, it checks whether the operator matches the intended phase-model assignment. Blocks Yoda→direct-execute and logs the verdict.
2. **Auto-heal CHECK 28h** — periodic audit that reads `state/crest-execute-gate-log.json`, compares `executor` vs `intendedRoute`, and flags any drift where a strong-tier agent performed cheap-tier work. Alerts via `scripts/telegram-alert.sh`.

**Drift check pattern:**
- `executor` must match `intendedRoute` OR have a valid Ken-approved override (`CREST_OVERRIDE=1`)
- `modelUsed` must match the phase's expected tier per `model-policy.json`
- Blocked dispatches are not a failure — they are a sign the gate is working correctly

> **When to dispatch to Forge (infra executor):** For mechanical atoms — file write, cron restore, plist edit, state bootstrap, or any repetitive script-level task — route to Forge, not Yoda direct. Per L-026 ("Build/scripts → Forge ONLY").

## OC2 & Gemma4 Policy

- **Gemma4:26b local (T1):** crons only — background/non-interactive. Cold-load causes system-wide slowdown.
- **OC2 trigger gates:** T01 (setup), T02 (HA+NAS), T03 (Gemma4→swap Haiku), T05 (kimi T2 ✅), T11 (monthly check), T12 (allowlist sync ✅), T13 (semantic memory).
- **Pre-OC2 current:** Strong-tier (Plan/Verify/Replan) on T2 (Ollama Cloud); opt-in T3 (Anthropic Sonnet) for higher-quality cognitive work per CREST v1.3 phase model map. CHG-0500 CLAUDE RECONFIGURE lifted Conservative Mode; CREST v1.3 + TKT-0368 provide structural risk framework.

## Key Rotation & Current State

- **Anthropic key rotation:** Ken runs `openclaw models auth`. Yoda runs `python3 scripts/propagate-anthropic-key.sh` → all agents. Execute within 1 min of event.
- **Current state (pre-OC2):** Per-agent model-task matrix. Strong-tier (Yoda, Atlas, Thrawn, Aria) on T2 (Ollama Cloud: minimax-m3 trial or kimi/gemma4:31b-cloud); opt-in T3 (Anthropic Sonnet) for cognitive work per CREST v1.3 phase model map. Cheap-tier (Forge, Spark, Lando) on `deepseek-v4-flash`. kimi final safety net. **Conservative Mode LIFTED 2026-06-12 (CHG-0500)**; risk framework is now CREST v1.3 + TKT-0368 structural guards.

## References
- `docs/Aevlith-Technology-Strategy-Roadmap-v1.0-Internal.md`
- `docs/Model3-Policy.md`
- `docs/CREST-v1.2-Recursive-Model-C.md`