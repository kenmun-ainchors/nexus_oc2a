---
name: openclaw-post-upgrade-shakedown
description: "Run the standard OC2A post-OpenClaw-upgrade regression shakedown."
---

# OpenClaw post-upgrade shakedown

Use after every OpenClaw upgrade on OC2A (production lead node) to confirm the gateway, agents, crons, auth, budget, network, and subagent stack are healthy.

## When to run

- Immediately after `npm install -g openclaw@...` or equivalent upgrade on OC2A.
- After any gateway restart that follows a config change or auto-heal.
- As a sanity check before a demo, sprint review, or client session.

## How to run

```bash
bash agent-skills/openclaw-post-upgrade-shakedown/scripts/shakedown.sh
```

The script returns `0` when all automated checks pass and writes a JSON report to `state/post-upgrade-shakedown-latest.json`.

## What it checks

1. `openclaw status` and `gateway status` — runtime version, pid, config validity.
2. `openclaw doctor --lint` — no new warnings/errors.
3. Health state (`state/health-state.json`) — no degraded agents.
4. Cron health (`scripts/cron-health-check.sh`).
5. Delegated auth health (`scripts/check-delegated-auth.sh`).
6. Ollama request budget (`scripts/request-budget-check.sh`).
7. Session model drift (`scripts/check-session-model.sh`).
8. Main-session context watchdog (`scripts/main-session-context-watchdog.sh`).
9. Subagent smoke test (spawn `infra` agent and run a no-op check).
10. Browser automation readiness (verify browser sidecar responds).
11. Tailscale mesh reachability (ping OC2A Tailscale IP and MagicDNS host).

## What it does NOT do

- It does **not** log in to `ollama.com`. The Ollama usage scraper still needs a live browser session; run `scripts/ollama-usage-scraper-run.sh` separately after signing in.
- It does **not** upgrade OpenClaw itself.

## Failure handling

If any check fails:
1. Inspect `state/post-upgrade-shakedown-latest.json` for the failing check.
2. Resolve the underlying issue.
3. Re-run the script.
4. Record the outcome in the daily journal and, if structural, create a CHG record via `scripts/changelog-append.sh`.

## References

- `references/post-upgrade-shakedown-checklist.md` — manual follow-up items (browser login, OC1 spot checks, Notion sync verification).
