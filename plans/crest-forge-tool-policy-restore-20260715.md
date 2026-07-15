# CREST Plan — Forge: Restore Missing Tools to `main` and `foodie`

**CHG:** CHG-0892  
**Ticket:** TKT-1002 (LinkedIn auth residual; this config fix is unrelated but discovered in same post-upgrade shakedown)  
**Date:** 2026-07-15  
**Specialist:** Forge (`agentId: infra`)  
**Model tier:** Plan/Synthesize `deepseek-v4-flash`, Verify/Replan `gemma4:31b-cloud` / `deepseek-v4-pro:cloud` per CREST v1.3  
**Yoda gate:** Plan only; Yoda does not edit `openclaw.json`. Execution is delegated to Forge.

---

## 1. Problem Statement

After the OpenClaw upgrade to `2026.7.1`, `openclaw doctor --lint` warned that agents `main` and `foodie` lack the `message` tool. The gateway log revealed two layers of removal:

1. `tools.profile: "coding"` removed messaging/channel/agent tools: `agents_list`, `gateway`, `message`, `nodes`, `tts`.
2. `agents.main.tools.allow` removed 9 tools because they were not listed: `create_goal`, `get_goal`, `memory_get`, `memory_search`, `session_status`, `skill_workshop`, `subagents`, `update_goal`, `update_plan`.

`main` (Yoda) is Telegram-routed and also requires memory/goal/session/subagent/skill tools for heartbeat and orchestration.  
`foodie` is Telegram-routed and only needs `message` restored to reply.

The abandoned `imsg` skill remains enabled even though the iMessage channel was removed.

---

## 2. Scope

In-scope:
- Edit `~/.openclaw/openclaw.json` (config file only).
- Restore tools to `main` and `foodie`.
- Disable `skills.entries.imsg.enabled`.
- Validate config and restart gateway if approved.

Out-of-scope:
- Changing global `tools.profile` from `coding` (kept for other agents).
- Re-adding iMessage channel or skill logic.
- Modifying `/etc/hosts`, SSH keys, or OC1 config.

---

## 3. Root Cause

- Global `tools.profile: "coding"` excludes `message` and other messaging tools.
- Per-agent `tools.allow` lists were too narrow after the upgrade's tool-policy reconciliation; tools not explicitly allowed were dropped.
- `alsoAllow` was not used, so profile-excluded tools could not be recovered.

---

## 4. Proposed Change

File: `~/.openclaw/openclaw.json`

### 4.1 `main` agent (`agents.list[]` where `id == "main"`)

Under `main.tools`:

```json
"tools": {
  "allow": [
    "read",
    "write",
    "edit",
    "apply_patch",
    "exec",
    "process",
    "web_search",
    "web_fetch",
    "cron",
    "message",
    "sessions_list",
    "sessions_history",
    "sessions_send",
    "sessions_spawn",
    "sessions_yield",
    "session_status",
    "subagents",
    "memory_get",
    "memory_search",
    "create_goal",
    "get_goal",
    "update_goal",
    "update_plan",
    "skill_workshop"
  ],
  "alsoAllow": ["message"]
}
```

Rationale:
- `message` is required for Telegram replies.
- `session_status`, `memory_get`, `memory_search`, `create_goal`, `get_goal`, `update_goal`, `update_plan`, `skill_workshop`, `subagents` are needed for Yoda's heartbeat, context, skill, and goal/plan workflows.
- `alsoAllow: ["message"]` bypasses the `coding` profile exclusion for `message`.

### 4.2 `foodie` agent (`agents.list[]` where `id == "foodie"`)

Under `foodie.tools`, append `message` to `allow` and add `alsoAllow`:

```json
"tools": {
  "allow": [
    "read",
    "write",
    "edit",
    "web_search",
    "web_fetch",
    "sessions_list",
    "sessions_send",
    "session_status",
    "memory_search",
    "memory_get",
    "message"
  ],
  "alsoAllow": ["message"]
}
```

### 4.3 Disable abandoned `imsg` skill

Under `skills.entries.imsg`:

```json
"imsg": {
  "enabled": false
}
```

---

## 5. DAG / Atoms

| # | Atom | Verb | Target | Pre-conditions | Post-conditions | Side-effect scope | Owner |
|---|------|------|--------|----------------|-----------------|-------------------|-------|
| 1 | Backup existing config | read/write | `~/.openclaw/openclaw.json` | File exists; JSON valid | Backup file `openclaw.json.bak.<timestamp>` exists | file-write | Forge |
| 2 | Patch `main.tools.allow` and add `main.tools.alsoAllow` | edit | `~/.openclaw/openclaw.json` | Atom 1 done; JSON valid | `main.tools.allow` contains restored tools; `main.tools.alsoAllow == ["message"]` | file-write | Forge |
| 3 | Patch `foodie.tools.allow` and add `foodie.tools.alsoAllow` | edit | `~/.openclaw/openclaw.json` | Atom 2 done | `foodie.tools.allow` contains `message`; `foodie.tools.alsoAllow == ["message"]` | file-write | Forge |
| 4 | Disable `skills.entries.imsg.enabled` | edit | `~/.openclaw/openclaw.json` | Atom 3 done | `skills.entries.imsg.enabled == false` | file-write | Forge |
| 5 | Validate JSON and run `openclaw doctor --lint` | read/validate | `~/.openclaw/openclaw.json` | Atom 4 done | JSON parses; doctor emits no `main`/`foodie` tool warnings | read-only | Forge |
| 6 | Restart gateway (HITL gate) | exec | `openclaw` CLI | Atom 5 passes; Ken approves restart | Gateway pid changes; `openclaw status` healthy | infra-change | Forge (with approval) |
| 7 | Post-restart verification | read/test | Gateway + Telegram | Atom 6 done | `openclaw doctor --lint` clean; test messages from `main` and `foodie` succeed | read-only + external-test | Forge |

---

## 6. Verification Criteria

1. `openclaw doctor --lint` shows **no** findings for agents `main` or `foodie` related to missing tools.
2. `openclaw doctor --lint --json | jq '.findings | map(select(.agentIds[]? == "main" or .agentIds[]? == "foodie"))'` is empty for tool-policy checks.
3. Gateway restart succeeds: `openclaw status` reports `running`, `configValid: true`.
4. Telegram smoke test: a direct message routed to `foodie` receives a reply.
5. Yoda can invoke `message` and `sessions_spawn` tools without tool-policy errors.

---

## 7. Rollback

1. Restore `~/.openclaw/openclaw.json.bak.20260715T103634Z` (pre-iMessage-cleanup baseline) or the new backup Forge creates.
2. Run `openclaw doctor --lint` to confirm no new warnings.
3. Restart gateway.

---

## 8. Trade-offs / Risks

| Risk | Mitigation |
|------|------------|
| `alsoAllow: ["message"]` widens `coding` profile for two agents only | Scope is per-agent; other agents keep narrow `coding` profile |
| Adding `exec`/`process` already present in `main` keeps elevated surface | No change; those tools were already allowed |
| Disabling `imsg` skill may leave stale state | Skill has no active channel; disabling is cleanup only |
| Gateway restart interrupts active sessions | Schedule restart during low-traffic window; HITL approval required |

---

## 9. DoD Gate

- [ ] CHG-0892 linked in plan and journal.
- [ ] Config backup created.
- [ ] `openclaw.json` edits applied and JSON-valid.
- [ ] `openclaw doctor --lint` clean for `main`/`foodie`.
- [ ] Gateway restarted and `openclaw status` healthy.
- [ ] Telegram smoke test passes.
- [ ] Journal entry appended by Yoda.

---

## 10. Notes for Forge

- Use `jq` or Python to edit `~/.openclaw/openclaw.json`; preserve formatting and existing ordering where possible.
- Do **not** change `tools.profile` globally.
- Do **not** restart the gateway unless Ken explicitly approves in this session (HITL gate in Atom 6).
- After restart, run `openclaw status`, `openclaw doctor --lint`, and report findings.
