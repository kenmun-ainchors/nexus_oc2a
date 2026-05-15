# TKT-0184 — Option D Investigation: OpenClaw Native Telegram → Main Session Binding

**Status:** COMPLETE  
**Date:** 2026-05-15  
**Investigator:** Thrawn (Platform Architect)  
**Ticket:** TKT-0184  
**Linked:** TKT-0160 (Option C — dumb terminal workaround, currently live)

---

## Verdict: YES ✅

OpenClaw **natively supports** routing Telegram DMs to the main session. No external workaround or platform gap. Config-change only.

---

## Evidence

### 1. `session.dmScope` — Default Behaviour

From the OpenClaw config-agents docs and source code:

```
session.dmScope = "main"  ← DEFAULT
```

When `dmScope` is `"main"`, **all DMs from all channels collapse to `agent:main:main`** — the same session as WebChat. This is the factory default.

Source confirmation (`/opt/homebrew/lib/node_modules/openclaw/dist/session-key-C0K0uhmG.js`):
```js
const dmScope = params.dmScope ?? "main";
const linkedPeerId = dmScope === "main" ? null : resolveLinkedPeerId(...)
```

When `dmScope === "main"`, `linkedPeerId` is `null` → no per-peer session key → all DMs merge into the main session key.

### 2. Per-Binding `session.dmScope` Override

From the runtime schema (`runtime-schema-BEtBEbzv.js`):
```
"bindings[].session.dmScope": {
  description: "Optional DM session scope override for this route binding..."
}
```

**Individual bindings can specify their own `dmScope`** independent of the global `session.dmScope`. This means we can target only the yoda Telegram binding without affecting Aria or other channels.

### 3. Current Config State — Why It's Broken Today

Current `openclaw.json` has **two blockers** that prevent Telegram DMs from reaching the main session:

**Blocker 1:** `session.dmScope = "per-channel-peer"` (global override — set away from default "main")

**Blocker 2:** A binding that routes all yoda-account Telegram traffic to a **different agent**:
```json
{
  "agentId": "yoda-telegram",
  "match": { "accountId": "yoda", "channel": "telegram" },
  "type": "route"
}
```
→ Messages land on the `yoda-telegram` agent (with kimi model, CHG-0340), not `main`.

---

## Required Config Change

To implement Option D (Telegram DMs → main session):

### Option D-1: Full merge (shared session + main agent)

Modify the binding:
```json
{
  "agentId": "main",
  "comment": "Yoda bot → main agent (Option D — TKT-0184)",
  "match": {
    "accountId": "yoda",
    "channel": "telegram"
  },
  "session": {
    "dmScope": "main"
  },
  "type": "route"
}
```

This:
- Routes Telegram DMs to the **main agent** (claude-sonnet-4-6, not kimi)
- `session.dmScope: "main"` on the binding ensures DMs collapse to `agent:main:main`
- Global `session.dmScope: "per-channel-peer"` remains unchanged — other channels/agents unaffected

### Verification

After config change, Telegram DMs from Ken (chatId: 8574109706) will:
1. Route to agent: `main`
2. Session key: `agent:main:main`
3. Share context with WebChat session → full context continuity

---

## Trade-offs

| Factor | Current (Option C) | Option D (native binding) |
|---|---|---|
| **Model** | kimi (Telegram) vs claude (WebChat) | claude-sonnet-4-6 for both |
| **Context** | Separate sessions — no shared context | Unified session — full context |
| **Cost** | kimi is cheaper for Telegram | claude-sonnet-4-6 for all Telegram |
| **Complexity** | dumb-terminal relay (TKT-0160) running | Config-only change, no middleware |
| **Risk** | Low (separate, isolated) | Medium — shared session means Telegram messages appear in WebChat history |
| **Streaming** | Telegram streaming independent | Shared session — Telegram edits + WebChat coexist |

**Key consideration:** With Option D, Ken's Telegram DMs appear in the WebChat session transcript. This is the intended benefit (full context) but also means a potentially busy transcript from mixed channels.

---

## Recommendation

Option D is **viable and clean**. If Ken wants unified context (know what was discussed on Telegram when switching to WebChat), this is the right permanent fix.

**Gate before implementing:**
1. Ken approves retiring the `yoda-telegram` agent (CHG-0340) or repurposing it
2. Ken confirms accepting claude-sonnet-4-6 cost for Telegram (instead of kimi)
3. TKT-0160 dumb-terminal solution is retired or kept as fallback

**Implementation time:** ~5 minutes (single binding edit in openclaw.json + gateway restart)

---

## Files Reviewed

- `/Users/ainchorsangiefpl/.openclaw/openclaw.json` — current config
- `/opt/homebrew/lib/node_modules/openclaw/docs/channels/telegram.md`
- `/opt/homebrew/lib/node_modules/openclaw/docs/channels/channel-routing.md`
- `/opt/homebrew/lib/node_modules/openclaw/docs/gateway/config-agents.md`
- `/opt/homebrew/lib/node_modules/openclaw/dist/session-key-C0K0uhmG.js`
- `/opt/homebrew/lib/node_modules/openclaw/dist/resolve-route-c-_Hhz9r.js`
- `/opt/homebrew/lib/node_modules/openclaw/dist/runtime-schema-BEtBEbzv.js`
