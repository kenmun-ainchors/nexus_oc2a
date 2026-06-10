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
| Yoda, Aria, Atlas, Thrawn | `deepseek-v4-pro` (Ollama Cloud) | T2 Primary |
| Forge, Spark, Lando, MonMothma, Krennic | `deepseek-v4-flash` (Ollama Cloud) | T2 Primary |
| Shield, Lex, Sage, Warden | `deepseek-v4-pro` (Ollama Cloud) | T2 Primary |
| All agents | kimi fallback chain ends with `ollama/kimi-k2.6:cloud` | Safety net |

## Tiers & Fallbacks

| Tier | Model | Cost | Notes |
|------|-------|------|-------|
| T0 | systemEvent | $0 | Internal events only |
| T1 | Gemma4:26b local | $0 | Post-OC2. Client-data-safe |
| T2 | Ollama Cloud (kimi/deepseek) | ~$100/mo | Current primary tier |
| T3 | Claude Sonnet | FALLBACK ONLY | Credits depleted — CONSERVATIVE MODE |

**Fallback chains (current):** DeepSeek primary → kimi fallback → `ollama/kimi-k2.6:cloud` safety net.

## CREST Phase Routing

- **Strong-tier (Plan / Verify / Replan):** Yoda, Atlas, Thrawn → `deepseek-v4-pro`
- **Cheap-tier (Execute / Synthesize):** Forge, infra executors → `deepseek-v4-flash`
- **Replan Gate:** Gap found → iterate back to Execute (n++). Stop met → Synthesize → Done.

## OC2 & Gemma4 Policy

- **Gemma4:26b local (T1):** crons only — background/non-interactive. Cold-load causes system-wide slowdown.
- **OC2 trigger gates:** T01 (setup), T02 (HA+NAS), T03 (Gemma4→swap Haiku), T05 (kimi T2 ✅), T11 (monthly check), T12 (allowlist sync ✅), T13 (semantic memory).
- **Pre-OC2 current:** deepseek-v4-pro primary on Ollama Cloud T2. Claude depleted — CONSERVATIVE MODE active.

## Key Rotation & Current State

- **Anthropic key rotation:** Ken runs `openclaw models auth`. Yoda runs `python3 scripts/propagate-anthropic-key.sh` → all agents. Execute within 1 min of event.
- **Current state (pre-OC2):** `deepseek-v4-pro` primary, `deepseek-v4-flash` for cheap-tier exec, Ollama Cloud T2 flat $100/mo. CONSERVATIVE MODE (CHG-0349) active until CLAUDE RESTORE.

## References
- `docs/Aevlith-Technology-Strategy-Roadmap-v1.0-Internal.md`
- `docs/Model3-Policy.md`
- `docs/CREST-v1.2-Recursive-Model-C.md`