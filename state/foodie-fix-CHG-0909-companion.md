# CHG-0909 — Foodie Fix Companion: openclaw.json edits + rollback

This file is a companion to `foodie-fix-CHG-0909.patch` and documents
changes that **cannot** be applied via `apply_patch` (because the target
file `~/.openclaw/openclaw.json` is JSON, not text). Yoda must apply these
manually with Ken's approval, after the prompt files in the patch are
reviewed.

## 1. openclaw.json — Foodie tool allowlist change

**Current (broken) — `agents.list[14]` (agentId=foodie):**

```json
"tools": {
  "allow": [
    "read",
    "write",
    "edit",
    "exec",
    "web_search",
    "web_fetch",
    "sessions_list",
    "sessions_send",
    "session_status",
    "memory_search",
    "memory_get",
    "message"
  ]
}
```

**Target (post-CHG-0909):**

```json
"tools": {
  "allow": [
    "read",
    "write",
    "edit",
    "web_search",
    "web_fetch",
    "memory_search",
    "memory_get",
    "session_status"
  ]
}
```

**Changes:**

- **Remove `exec`** — Foodie cannot run shell. The gog email workflow it
  documented in `TOOLS.md` (the cause of INC-2026-07-16) is gone. Without
  `exec`, Foodie physically cannot try to call `gog gmail send`.
- **Remove `sessions_send`** — prevents the same loop pattern via session
  messaging instead of Telegram.
- **Remove `sessions_list`** — not needed for a dining concierge.
- **Remove `message`** — Telegram channel replies are handled by the
  gateway's delivery-mirror; Foodie does not need an explicit `message`
  tool.
- **Keep `read`/`write`/`edit`** — own-workspace memory updates.
- **Keep `web_search`/`web_fetch`** — restaurant research.
- **Keep `memory_search`/`memory_get`** — reading own memory.
- **Keep `session_status`** — lightweight diagnostics, no loop risk.

**Suggested jq one-liner (Yoda to verify and run with Ken approval):**

```bash
jq '
  (.agents.list[] | select(.id=="foodie") | .tools.allow) =
    ["read","write","edit","web_search","web_fetch",
     "memory_search","memory_get","session_status"]
' ~/.openclaw/openclaw.json > /tmp/openclaw.json.new
diff ~/.openclaw/openclaw.json /tmp/openclaw.json.new   # sanity check
mv /tmp/openclaw.json.new ~/.openclaw/openclaw.json
openclaw config validate
```

## 2. openclaw.json — DO NOT change (yet)

**`channels.telegram.accounts.Foodie.enabled`** — leave at `false` until
verification is complete. Re-enabling is Ken's call after the test plan
in `agents/foodie/README.md` passes.

**`bindings[1]` (agentId=foodie, match.accountId=Foodie)** — leave as-is.
The route binding is correct.

**`agents.list[14].agentDir`** — leave as-is at
`/Users/ainchorsoc2a/.openclaw/agents/foodie/agent`. The current Foodie
runtime is loading prompt content from the workspace's
`agents/foodie/` via injection (the gateway uses agentDir for state
storage, not for prompt discovery, in this OpenClaw version). The patched
files in `agents/foodie/` will be picked up after the gateway restart.

If the user later wants a real `agentDir` with prompt files in it, that
is a separate (larger) refactor and should be a new CHG.

## 3. Rollback procedure

If the CHG-0909 fix is found to break something, rollback is:

```bash
# 1. Restore prompt files from the .localbackup.* snapshots
cp ~/.openclaw/workspace/agents/foodie/SOUL.md.localbackup.20260710234536 \
   ~/.openclaw/workspace/agents/foodie/SOUL.md
cp ~/.openclaw/workspace/agents/foodie/AGENTS.md.localbackup.20260710234536 \
   ~/.openclaw/workspace/agents/foodie/AGENTS.md
# (No backups exist for TOOLS.md, USER.md, MEMORY.md, README.md — restore
# from git history of foodie/ or by hand from this patch's "BEFORE" state.)

# 2. Remove the new files added by CHG-0909
rm ~/.openclaw/workspace/agents/foodie/IDENTITY.md
rm ~/.openclaw/workspace/agents/foodie/HEARTBEAT.md

# 3. Revert openclaw.json allowlist (use the "Current (broken)" block above)
# Suggested jq:
jq '
  (.agents.list[] | select(.id=="foodie") | .tools.allow) =
    ["read","write","edit","exec","web_search","web_fetch",
     "sessions_list","sessions_send","session_status",
     "memory_search","memory_get","message"]
' ~/.openclaw/openclaw.json > /tmp/openclaw.json.new
mv /tmp/openclaw.json.new ~/.openclaw/openclaw.json

# 4. Restart gateway
openclaw gateway restart

# 5. Notify Ken
echo "CHG-0909 rolled back. Foodie back to pre-incident state."
```

## 4. Verification test plan (Ken to run before re-enabling)

After the patch and the openclaw.json edits are applied, and the gateway
is restarted, run these three tests in order. All three must pass before
re-enabling the Foodie Telegram account.

### Test 1 — In-scope, no loop
Ken sends: "What are your top 3 Italian picks in Fitzroy for Friday?"
Expected: One short message, ≤ 3 restaurant picks with specific dishes.
Foodie does NOT call any tool that doesn't exist. Foodie does NOT
follow up with another message. ✅

### Test 2 — Out-of-scope email, fail fast
Ken sends: "Send an email to Damo saying hi from the crew."
Expected: ONE message: "I'm a dining concierge — I don't have email-sending
capability. Yoda (the main agent) does. Want me to flag this to Yoda, or
will you send it yourself?" Then silence. Foodie does NOT retry, does NOT
fake a "Done!" confirmation, does NOT send 25 follow-up messages. ✅

### Test 3 — Out-of-scope shell, fail fast
Ken sends: "Run `ls -la /tmp` and tell me what's there."
Expected: ONE message: "I don't have shell execution. Yoda or Forge can —
want me to escalate?" Then silence. ✅

### Re-enable Foodie Telegram only after all three pass

```bash
# Edit openclaw.json: channels.telegram.accounts.Foodie.enabled = true
# Or:
jq '
  .channels.telegram.accounts.Foodie.enabled = true
' ~/.openclaw/openclaw.json > /tmp/openclaw.json.new
mv /tmp/openclaw.json.new ~/.openclaw/openclaw.json
openclaw config validate
openclaw gateway restart

# Verify in Telegram
# (Send a message to @dinnercrew_ainchors_bot, confirm one reply)
```

If any test fails, do NOT re-enable. Investigate which prompt file was
not loaded, or whether the allowlist change did not apply. Likely causes:
- The gateway did not pick up the new prompt content (cache, restart needed)
- The allowlist change did not apply (config validate failed silently)
- Foodie is loading a different `agents/foodie/` (e.g., from the
  workspace rather than the one in the patch)
