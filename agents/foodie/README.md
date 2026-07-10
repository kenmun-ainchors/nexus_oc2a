# Foodie 🍽️ — Dinner Crew Agent

## Overview

Foodie is a lightweight personal dining concierge for the "Dinner Crew" project — a
private 3-user Telegram channel for coordinating Melbourne restaurant outings.

## Architecture

```
Telegram (@dinnercrew_ainchors_bot)
  │
  └── OpenClaw Gateway (port 18789)
        │
        ├── Connector: telegram-dinner-crew
        │     match: channel=telegram, accountId=dinner-crew
        │
        └── Binding: agentId=foodie (route)
              │
              └── Agent: foodie
                    │
                    └── Workspace: agents/foodie/ (SOUL.md, AGENTS.md)
                    └── Memory: memory/foodie/ (melbourne-restaurants-seed.md)
```

## Files

| Path | Purpose |
|------|---------|
| `agents/foodie/SOUL.md` | Agent identity, personality, scope |
| `agents/foodie/AGENTS.md` | Behavioral rules, authorized senders, routing |
| `agents/foodie/README.md` | This file |
| `memory/foodie/melbourne-restaurants-seed.md` | Seed restaurant data + schema |
| `scripts/foodie-enable.sh` | Apply config changes to openclaw.json |

## Setup Steps (pending Ken approval)

1. **Create Telegram bot** via @BotFather:
   - Open Telegram → @BotFather → `/newbot`
   - Name: `Dinner Crew`
   - Username: `dinnercrew_ainchors_bot`
   - Copy the bot token

2. **Store bot token** in macOS Keychain:
   ```
   bash scripts/secrets-init.sh store dinner-crew-bot-token "<token>"
   ```

3. **Apply config**:
   ```
   bash scripts/foodie-enable.sh
   ```

4. **Restart OpenClaw gateway**:
   ```
   openclaw gateway restart
   ```

5. **Verify**: Send a message to @dinnercrew_ainchors_bot in Telegram

## Adding Users

When Ken provides the 2 additional Telegram user IDs, update in two places:

1. **Config**: `openclaw.json` → `channels.telegram.accounts.dinner-crew.allowFrom`
   and `groupAllowFrom` — add the new numeric IDs
2. **Agent rules**: `agents/foodie/AGENTS.md` → replace `PLACEHOLDER_USER_2` and
   `PLACEHOLDER_USER_3` with actual IDs

## Authorized Senders

| User | Telegram ID | Status |
|------|-------------|--------|
| Ken Mun (owner) | `8574109706` | ✅ Active |
| Pending User 2 | `PLACEHOLDER_USER_2` | ⏳ Pending |
| Pending User 3 | `PLACEHOLDER_USER_3` | ⏳ Pending |

## Routing Rule

The binding in `openclaw.json` routes all messages from the `dinner-crew` Telegram
account (connector) to the `foodie` agent:

```json
{
  "agentId": "foodie",
  "match": {
    "accountId": "dinner-crew",
    "channel": "telegram"
  },
  "type": "route"
}
```

This is a direct route binding — no Yoda orchestration needed for inbound messages.
The sender checks are handled by the `dmPolicy: "allowlist"` config and the
authorized sender list in `AGENTS.md`.

## Preserved Assets

- Existing `yoda` Telegram account → `main` agent remains unchanged
- Existing `aria` Telegram account → `business` agent remains unchanged
- Ken's existing personal channel continues to work as before