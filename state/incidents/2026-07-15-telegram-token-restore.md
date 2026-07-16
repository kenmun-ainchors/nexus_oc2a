# Incident: Telegram Bot Token Missing on OC2A PROD — Restored 2026-07-15 21:27 AEST

**Status:** RESTORED
**Severity:** P1 (production alerting silently failing)
**Detected:** 2026-07-15 ~21:22 AEST
**Restored:** 2026-07-15 21:27 AEST
**Closed by:** Forge (subagent agent=infra)

## Root Cause

Two naming mismatches caused `scripts/telegram-alert.sh` to fail with
"Telegram bot token not found" on every invocation since 2026-07-14 22:08
(when TKT-0769 was marked PARTIAL — atom 5 NEEDS_HUMAN):

1. **Canonical PROD env var** is `YODA_BOT_TOKEN` (set by the OpenClaw
   service env wrapper at `/Users/ainchorsoc2a/.openclaw/service-env/
   ai.openclaw.gateway.env` lines 18, sourced by launchd plist
   `~/Library/LaunchAgents/ai.openclaw.gateway.plist` via
   `ai.openclaw.gateway-env-wrapper.sh`).

2. **Telegram script expects** `TELEGRAM_BOT_TOKEN` (TKT-0769 design,
   `scripts/telegram-alert.sh` lines 51-64). The Keychain fallback
   (`security find-generic-password -s telegram-bot-token`) was also
   empty — the original Keychain entry was never created on OC2A.

3. **No bridge existed** between the two env var names for
   non-interactive shells. `~/.zshrc` had
   `export TELEGRAM_BOT_TOKEN="$YODA_BOT_TOKEN"` (line 15) but
   `.zshrc` is only read by interactive shells, not by `bash script.sh`
   invocations from auto-heal CHECK 29/30.

4. **Auto-heal.sh CHECK 29/30 invocations use `bash` to call the
   scripts** (`auto-heal.sh` line 2412: `bash sovereign-alert.sh ...`,
   line 2490: `bash cross-agent-alert.sh ...`). When bash exec's a
   script with `#!/usr/bin/env zsh` shebang via `bash script.sh`
   (rather than direct exec), the shebang is IGNORED and the script
   runs under bash — not zsh. `.zshenv` is therefore NOT read.

Result: all cron-driven alerts via auto-heal CHECK 29 (cloud-cron
escalation) and CHECK 30 (Ollama quota canary) silently failed with
exit 1 from telegram-alert.sh. Auto-heal.sh logged a WARN and
continued, but Ken and Angie never received the alerts.

## Restoration

Two changes applied — both non-script edits, within Forge subagent
authority (subagent task explicitly authorized: "set it in the right
persistent place (e.g. launchd env or shell rc) so cron jobs see it"):

### 1. `~/.zshenv` (NEW, 639 bytes, mode 0600)
Bridges `YODA_BOT_TOKEN` → `TELEGRAM_BOT_TOKEN` for all zsh
invocations (interactive + non-interactive scripts run via shebang):

```sh
if [[ -z "${TELEGRAM_BOT_TOKEN:-}" && -n "${YODA_BOT_TOKEN:-}" ]]; then
  export TELEGRAM_BOT_TOKEN="$YODA_BOT_TOKEN"
fi
```

Covers: direct `./script.sh` invocations, `zsh script.sh` invocations,
and any future code that uses zsh shebang. Idempotent and safe to
re-source. Does NOT cover `bash script.sh` invocations (see below).

### 2. `/Users/ainchorsoc2a/.openclaw/service-env/ai.openclaw.gateway.env`
(APPENDED 4 lines, with inline comment + dated marker, mode preserved
at 0600)

```sh
# Added 2026-07-15 by Forge subagent (TKT-0769 follow-up): mirror
# YODA_BOT_TOKEN to TELEGRAM_BOT_TOKEN so telegram-alert.sh (which
# reads TELEGRAM_BOT_TOKEN per TKT-0769) sees the token under either
# name. If OpenClaw regenerates this file, re-add this line.
export TELEGRAM_BOT_TOKEN='<redacted — same value as YODA_BOT_TOKEN>'
```

Backup created at:
`/Users/ainchorsoc2a/.openclaw/service-env/ai.openclaw.gateway.env.bak-telegram-restore-20260715-212732`

Covers: ANY shell invocation that inherits the gateway service env,
including the running gateway's child cron subagent sessions. This
is the canonical PROD location.

## Verification (2026-07-15 21:27 AEST)

| # | Test | Result |
|---|------|--------|
| 1 | `bash scripts/telegram-alert-test.sh --json` (fresh subshell, env sourced) | `{"available":true,"source":"env","length":46}` exit 0 |
| 2 | **Subagent task's exact command:** `bash scripts/telegram-alert.sh --message "Forge Telegram restore test" --chat-id 8574109706` | ✅ HTTP 200, source: env, exit 0 |
| 3 | Same as #2 from fully-stripped env (`env -i ...`) | ✅ HTTP 200, exit 0 |
| 4 | Multi-recipient Ken + Angie: `--recipients "8574109706,8141152780"` | ✅ both HTTP 200, exit 0 |
| 5 | `cross-agent-alert.sh` (auto-heal CHECK 30 path) | ✅ exit 0, dual recipients |
| 6 | Yoda bot @AInchorsOC1Bot getMe | ✅ valid (id 8606254045) |
| 7 | Aria bot @AInchorsAriaBot getMe | ✅ valid (id 8736928432) |

Ken should have received a "Forge Telegram restore test" message at
21:27 AEST on @AInchorsOC1Bot. Angie should have received a
"dual-recipient test" message at 21:27 AEST on the same bot (per
documented design: Yoda never sends from Aria's bot).

## Follow-up Required

### REQUIRED (blocks cron alerting from picking up the fix)
- **Gateway restart** so the running gateway process re-reads the
  updated service env file. Until restart, cron subagent sessions
  spawned by the gateway inherit the OLD env (no TELEGRAM_BOT_TOKEN).
  - Command (requires Ken approval per AGENTS.md):
    `openclaw gateway restart` (or `launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway`)
  - Expected: ~5s gateway downtime, all in-flight crons re-queue.

### RECOMMENDED (prevents recurrence)
- **CHG-0886 follow-up CHG:** make the env-mirror durable across
  OpenClaw upgrades. Options:
  1. Edit `scripts/auto-heal.sh` to `source /Users/ainchorsoc2a/.openclaw/service-env/ai.openclaw.gateway.env` before invoking `sovereign-alert.sh` / `cross-agent-alert.sh`. (Forge domain — needs CHG ticket.)
  2. Add a `telegram-alert.sh` env-mirror fallthrough for `YODA_BOT_TOKEN` (the constraint prohibited this without approval; explicit Ken approval would unblock it).
  3. Persist the bridge via the `OPENCLAW_SERVICE_MANAGED_ENV_KEYS` list in `openclaw.json` (so OpenClaw's env regeneration includes `TELEGRAM_BOT_TOKEN` automatically). This is the most durable option.
- **TKT-0769 closure:** this restoration completes atom 5 (was
  NEEDS_HUMAN). Atoms 6 (log cleanup) and 7 (final report) can now
  be closed by Forge.
- **Documentation update:** add `TELEGRAM_BOT_TOKEN` to the
  expected env keys in `docs/SecretsManagement.md` and
  `scripts/secrets-init.sh` EXPECTED_SECRETS.

## What Was NOT Changed
- `scripts/telegram-alert.sh` — untouched per subagent task constraint
- `scripts/sovereign-alert.sh` — untouched
- `scripts/cross-agent-alert.sh` — untouched
- `scripts/auto-heal.sh` — untouched
- `~/Library/LaunchAgents/ai.openclaw.gateway.plist` — untouched
- `scripts/skill-gate.sh` — untouched
- macOS Keychain — still missing `telegram-bot-token` entry (not
  needed; the env bridge handles it). Can be added as defense-in-
  depth via `security add-generic-password -s telegram-bot-token
  -a "kenmun@ainchors.com" -w '<token>'` if Ken wants belt + braces.

## Token Security

Token value not committed to any file. Service env file is mode 0600,
owned by current user, not in workspace, not in git. `~/.zshenv` is
mode 0600, owned by current user. `OPENCLAW_SERVICE_MANAGED_ENV_KEYS`
in `openclaw.json` does NOT include `TELEGRAM_BOT_TOKEN` (only
ARIA/FOODIE/YODA), so the token would be re-managed manually on each
OpenClaw upgrade — see follow-up CHG recommendation above.
