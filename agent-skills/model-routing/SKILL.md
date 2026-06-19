---
name: model-routing
description: Reference-only skill for model tier policy. Single source of truth is state/archive/model-policy.json. Runtime queries go through scripts/model-policy-query.sh.
---

# Model Routing — Reference Skill

**Single source of truth:** `state/archive/model-policy.json`  
**Runtime query helper:** `scripts/model-policy-query.sh`

This skill is intentionally thin. Do **not** embed model-to-agent mappings here; they drift. Instead, query the policy file or use the helper.

## Quick commands

```bash
# Effective model for an agent + CREST phase
bash scripts/model-policy-query.sh --agent platform-arch --phase Execute

# Summary for an agent
bash scripts/model-policy-query.sh --agent infra

# Full effective map for all agents
bash scripts/model-policy-query.sh --all
```

## Where model routing is enforced

1. **Warden 15-min cron** — checks actual runtime model against `state/archive/model-policy.json`.
2. **`scripts/dispatch-validate.sh`** — validates that each atom's declared `model` matches the policy for the target agent + phase.
3. **`scripts/crest-execute-gate.sh`** — blocks Yoda direct Execute and logs `executor`/`intendedRoute`/`modelUsed`.
4. **Auto-heal drift checks** — compare effective policy map with consumer behavior.

## CREST phase discipline

- **Plan / Verify / Replan** → strong model (agent's tier `primary`).
- **Execute / Synthesize** → cheap model (agent's tier `cheapModel`) unless an override applies.
- **Yoda (`main`)** → no `Execute` phase without per-instance Ken approval (CHG-0545).
- **Forge (`infra`)** exception: `Plan`/`Synthesize` use cheap; `Verify`/`Replan` use strong.
- **Spark (`social`)** exception: `highStakesExecute` may override to strong with documented `model_override` + `override_reason`.

## Anthropic

Permanently parked per CHG-0502. Do not activate unless Ken says the unblock keyword "CLAUDE ACTIVATE".

## References

- `state/archive/model-policy.json` — SSOT
- `docs/Model3-Policy.md`
- `agent-skills/crest/SKILL.md` — CREST phase topology (not model assignments)
