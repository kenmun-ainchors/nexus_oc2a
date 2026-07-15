# CREST Plan: Re-enable Cross-Agent + Telegram Alerts — 2026-07-15

**Phase:** Plan  
**Owner:** Yoda (main)  
**Executor:** Forge (infra)  
**Judge:** Sage (qa)  
**CHG:** CHG-0886  
**Tickets:** TKT-0775 (Telegram alerting — existing, monitoring), TKT-XXXX (cross-agent alerting — to create)

---

## 1. Current State

### 1.1 Telegram alerting
- Scripts patched in TKT-0769/TKT-0775:
  - `scripts/telegram-alert.sh` — direct Bot API; `TELEGRAM_BOT_TOKEN` env primary, Keychain fallback.
  - `scripts/sovereign-alert.sh` — wrapper with source prefix + log.
  - `scripts/telegram-alert-test.sh` — verification wrapper (env/keychain check, no send).
- **Live send blocked** because `TELEGRAM_BOT_TOKEN` is missing from env and Keychain (`telegram-bot-token` service absent).
- Token value has never been written to workspace files or logs.
- Ken's chat ID: `8574109706`.

### 1.2 Cross-agent alerting
- **No `scripts/cross-agent-alert.sh` exists.**
- Cross-agent alerting in the platform currently relies on:
  - Direct `sessions_send` from crons/heartbeat — channel-dependent and unreliable.
  - `sovereign-alert.sh` → Telegram as a backup channel.
- HEARTBEAT.md references "platform/cron/infra/business-impacting alerts route to both Ken (8574109706) and Angie (8141152780)" under CHG-0799, but the routing is not implemented as a dedicated script.
- Requirement: a single, source-agnostic wrapper that routes critical alerts to both Ken and Angie via Telegram when business/infra/health/cron issues occur.

### 1.3 Readiness context
- OC2A PROD readiness synthesis verdict: `READY_WITH_GAPS`.
- Final gap before full readiness declaration: live alerting path.
- iMessage remains blocked by SIP (TKT-1000, physical reboot required) — out of scope for this plan.

---

## 2. Goal

Re-enable **live Telegram alerts** and implement a **cross-agent alert wrapper** so that critical PROD events reach both Ken and Angie reliably, with token sourcing that is env-primary + Keychain fallback and never logs the token.

---

## 3. Scope

### In scope
1. Provide/inject `TELEGRAM_BOT_TOKEN` into the PROD environment (Ken action; Forge documents options).
2. Create `scripts/cross-agent-alert.sh` wrapper:
   - Accepts `--source`, `--message` or `--file`, and optional `--recipients`.
   - Defaults to Ken + Angie for `HEALTH`, `WARDEN`, `TASK`, `DOD`, `RESTART`, `STALE`, `AKB`, `DRIVE`, and cron-failure categories.
   - Routes to `telegram-alert.sh --recipients '8574109706,8141152780'`.
   - Logs to `state/cross-agent-alert.log`.
   - Never logs token.
3. Update crons / heartbeat paths that should use cross-agent routing for business-impacting alerts per CHG-0799.
4. Update `state/sovereign-alert.log` truncation / cleanup after successful test.

### Out of scope
- iMessage channel enablement (TKT-1000).
- Changes to Telegram chunking rules (skill already covers 3,800-char safe chunk).
- New bot provisioning — assumes existing @AInchorsOC1Bot / @AInchorsAriaBot tokens.

---

## 4. Acceptance Criteria

| ID | Criterion | Owner |
|---|---|---|
| a | `TELEGRAM_BOT_TOKEN` present in env OR Keychain; `telegram-alert-test.sh` exits 0. | Ken + Forge |
| b | `scripts/cross-agent-alert.sh` exists, passes `zsh -n`, and routes to both Ken + Angie by default. | Forge |
| c | A test alert is successfully sent to Ken (and optionally Angie) from OC2A PROD via `telegram-alert.sh` or `cross-agent-alert.sh`. | Forge + Ken |
| d | At least one heartbeat/cron alert path is wired to use cross-agent routing where CHG-0799 specifies dual-recipient alerts. | Forge |
| e | `state/sovereign-alert.log` stale FAIL entries cleared after successful live send. | Forge |
| f | No token value appears in any workspace file or log. | Sage |

---

## 5. Execution Plan

### Step 1 — Token sourcing (Ken + Forge)
- **Option A (preferred for persistence):** Ken exports `TELEGRAM_BOT_TOKEN` in a file sourced by the OpenClaw gateway process and main session shell (e.g. `~/.config/ainchors/secrets.env` or a `launchd` env var). Forge adds a non-committed env loader to the gateway launch path.
- **Option B (manual):** Ken runs `export TELEGRAM_BOT_TOKEN='...'` in the current session, then Forge executes the test.
- **Option C (Keychain):** Add token to Keychain service `telegram-bot-token` via `/usr/bin/security add-generic-password`. More durable across reboots but requires unlock.
- **Constraint:** Token must not be written to any committed file. Use `read -s` or env injection only.

### Step 2 — Create `scripts/cross-agent-alert.sh`
- Model on `sovereign-alert.sh`.
- Default recipients: `8574109706,8141152780`.
- Source-aware emoji prefixes re-use `sovereign-alert.sh` mapping.
- Add `--recipients` override for future flexibility.
- Log line: `YYYY-MM-DD HH:MM:SS AEST OK|FAIL SOURCE → telegram to RECIPIENTS`.

### Step 3 — Wire alert paths
- Identify crons / heartbeat checks currently using `sessions_send` or `sovereign-alert.sh` for business-impacting alerts.
- Replace with `cross-agent-alert.sh` where dual-recipient is required per CHG-0799.
- Keep single-recipient `sovereign-alert.sh` for non-business alerts to avoid spamming Angie.

### Step 4 — Test
- `TELEGRAM_BOT_TOKEN='...' scripts/telegram-alert-test.sh` → expect exit 0, source env, length > 0.
- `scripts/cross-agent-alert.sh --source HEALTH --message "OC2A PROD readiness: cross-agent Telegram alert test from Forge TKT-XXXX"` → expect HTTP 200 to both recipients.
- Ken confirms receipt on his device.

### Step 5 — Cleanup
- Truncate or archive `state/sovereign-alert.log` old FAIL entries after successful test.
- Update TKT-0775 status to `done` and create/close TKT-XXXX.

---

## 6. Verification Plan (Sage)

| Check | Method |
|---|---|
| Token not in files | `grep -R "TELEGRAM_BOT_TOKEN" scripts/ state/ agent-skills/ --include='*.sh' --include='*.json' --include='*.md'` — must not return token value. |
| Syntax valid | `zsh -n scripts/cross-agent-alert.sh && zsh -n scripts/telegram-alert.sh && zsh -n scripts/sovereign-alert.sh` |
| Test wrapper | `TELEGRAM_BOT_TOKEN=xxx scripts/telegram-alert-test.sh --json` returns `{"available":true,...}` with length > 0 |
| Live send | `state/cross-agent-alert.log` contains `OK HEALTH → telegram to 8574109706,8141152780` and Ken confirms receipt |
| No log leak | `grep -E '[0-9]{8,}:[a-zA-Z0-9_-]{30,}' state/*.log` returns nothing resembling a bot token |

---

## 7. Risks & Blockers

| Risk | Mitigation |
|---|---|
| Token still unavailable | Cannot complete AC c/f; escalate to Ken. Verdict remains `READY_WITH_GAPS`. |
| Token accidentally logged | Token value regex scan in verification gate; abort if found. |
| Telegram rate-limit on dual send | Sequential loop in `telegram-alert.sh` already handles this. |
| Cross-agent wrapper breaks single-recipient paths | Keep `sovereign-alert.sh` intact; only change dual-recipient call sites. |

---

## 8. CHG Record

- **CHG-0886** to be appended via `changelog-append.sh` after Execute/Verify phases.
- Closes TKT-0775 and new TKT-XXXX.

---

## 9. Decision Required from Ken

**Provide the Telegram bot token to Forge.** Options:
1. Paste it into the current main session as an env var (ephemeral, session-only).
2. Add it to a local env file path that the gateway loads (persistent across restarts).
3. Add it to Keychain service `telegram-bot-token` (persistent, unlock-dependent).

Which option do you prefer? Once the token is available, Forge can execute the remaining steps and Sage will verify.
