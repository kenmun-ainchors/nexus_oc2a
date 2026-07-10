#!/usr/bin/env zsh
# foodie-enable.sh — Apply Foodie agent + Dinner Crew bot config to openclaw.json
# CHG: Pending — requires Ken approval
#
# This script:
# 1. Reads the bot token from macOS Keychain (service: dinner-crew-bot-token)
# 2. Patches openclaw.json with the new agent, telegram account, and binding
# 3. Creates a backup before modifying
#
# Prerequisites:
#   - Bot token must be stored first via:
#     bash scripts/secrets-init.sh store dinner-crew-bot-token "<token_from_BotFather>"
# 
# Usage:
#   bash scripts/foodie-enable.sh
#
# After running: restart OpenClaw gateway for the new connector to take effect.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── 1. Load bot token from Keychain ──────────────────────────────────────────
BOT_TOKEN=$(/usr/bin/security find-generic-password -s "dinner-crew-bot-token" -w 2>/dev/null || true)

if [[ -z "$BOT_TOKEN" ]]; then
  echo "❌ Bot token not found in Keychain."
  echo ""
  echo "Steps:"
  echo "  1. Open Telegram → @BotFather → /newbot"
  echo "     Name: Dinner Crew"
  echo "     Username: dinnercrew_ainchors_bot"
  echo "  2. Copy the token from BotFather's reply"
  echo "  3. Store it:"
  echo "     bash scripts/secrets-init.sh store dinner-crew-bot-token \"<token>\""
  echo "  4. Re-run this script."
  exit 1
fi

echo "✅ Bot token loaded from Keychain"

# ── 2. Backup openclaw.json ──────────────────────────────────────────────────
CONFIG_FILE="/Users/ainchorsangiefpl/.openclaw/openclaw.json"
BACKUP_FILE="${CONFIG_FILE}.bak.$(date +%Y%m%d-%H%M%S)-foodie"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "✅ Backup: $BACKUP_FILE"

# ── 3. Apply patches using Python (precise JSON manipulation) ────────────────
python3 -c "
import json, sys

with open('$CONFIG_FILE') as f:
    data = json.load(f)

# Add foodie agent to agents list
data['agents']['list'].append({
    'agentDir': '/Users/ainchorsangiefpl/.openclaw/workspace/agents/foodie',
    'id': 'foodie',
    'model': {
        'primary': 'ollama/deepseek-v4-flash:cloud',
        'fallbacks': ['ollama/gemma4:31b-cloud', 'ollama/kimi-k2.6:cloud']
    },
    'name': 'Foodie 🍽️ — Dinner Crew Dining Concierge',
    'tools': {
        'allow': [
            'read', 'write', 'edit', 'web_search', 'web_fetch',
            'sessions_list', 'sessions_send', 'session_status',
            'memory_search', 'memory_get'
        ]
    },
    'workspace': '/Users/ainchorsangiefpl/.openclaw/workspace'
})

# Add dinner-crew telegram account
data['channels']['telegram']['accounts']['dinner-crew'] = {
    'allowFrom': [8574109706],
    'botToken': '$BOT_TOKEN',
    'dmPolicy': 'allowlist',
    'groupAllowFrom': [8574109706]
}

# Add foodie binding
data['bindings'].append({
    'agentId': 'foodie',
    'comment': 'Dinner Crew bot → Foodie agent (Ken + 2 pending users)',
    'match': {'accountId': 'dinner-crew', 'channel': 'telegram'},
    'type': 'route'
})

# Update meta timestamp
data['meta']['lastTouchedAt'] = '$(date -u +%Y-%m-%dT%H:%M:%S.000Z)'
data['meta']['lastTouchedVersion'] = '$(date +%Y.%-m.%-d)'

with open('$CONFIG_FILE', 'w') as f:
    json.dump(data, f, indent=2)

print('✅ Config patched successfully')
print(f'   Agents: {len(data[\"agents\"][\"list\"])}')
print(f'   Bindings: {len(data[\"bindings\"])}')
print(f'   TG accounts: {list(data[\"channels\"][\"telegram\"][\"accounts\"].keys())}')
"

if [[ $? -eq 0 ]]; then
  echo ""
  echo "✅ All changes applied!"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  NEXT STEPS:"
  echo "  1. Open @dinnercrew_ainchors_bot in Telegram"
  echo "  2. Start a conversation with the bot"
  echo "  3. Restart OpenClaw gateway:"
  echo "     openclaw gateway restart"
  echo "     (or use gateway tool in a session)"
  echo "  4. Add 2 additional users to allowFrom when IDs known"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
  echo "❌ Patch failed. Restoring backup..."
  cp "$BACKUP_FILE" "$CONFIG_FILE"
  exit 1
fi