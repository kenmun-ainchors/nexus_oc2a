# Post-upgrade shakedown — manual follow-up checklist

Run the automated script first:

```bash
bash agent-skills/openclaw-post-upgrade-shakedown/scripts/shakedown.sh
```

Then complete these manual items that the script cannot perform unattended.

## 1. Ollama usage scraper

The scraper requires an active browser session at `ollama.com`.

1. Sign in as `accounts@ainchors.com`.
2. Run:
   ```bash
   bash scripts/ollama-usage-scraper-run.sh
   ```
3. Confirm `state/cost-state.json` reflects live usage.

## 2. Browser automation functional test

If the sidecar is not currently running, trigger a browser action to start it:

```bash
# Example: fetch a page via the browser automation tool in a subagent or heartbeat test.
```

Verify port `127.0.0.1:18791` becomes reachable and a page fetch succeeds.

## 3. Subagent smoke test

Spawn a non-destructive subagent (e.g., `infra`) and confirm it returns:

- `openclaw agent-status` healthy.
- Subagent session created and completed without tool-policy errors.

## 4. OC1 dev/test standby spot check

If OC1 is online:

```bash
ssh -i ~/.ssh/id_oc2a_oc1 ainchorsangiefpl@ainchorss-mac-mini.tailfc3ed1.ts.net \
  "source ~/.zshrc 2>/dev/null; source ~/.zprofile 2>/dev/null; openclaw status --json"
```

Confirm `runtimeVersion` matches OC2A.

## 5. Notion / state sync

- Check that any CHG records created during the upgrade are synced to Notion Archive DB (DB C).
- Verify critical state files (`state/health-state.json`, `state/cost-state.json`) are present and fresh.

## 6. Telegram channel smoke test

Send a direct message to the production Telegram bot and confirm the routed agent replies.

## 7. Journal entry

Append the upgrade outcome, any CHG IDs, and residual issues to today's journal.
