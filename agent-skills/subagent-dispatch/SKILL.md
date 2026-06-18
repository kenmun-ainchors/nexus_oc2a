---
name: subagent-dispatch
description: Rules and helper for spawning OpenClaw subagents safely — workspace access, timeout enforcement, tool budgets, and kill policies.
---

# Subagent Dispatch Skill — When to Load

Load this skill whenever you need to:

- Spawn a subagent via `sessions_spawn`
- Decide whether a task should be delegated or executed in the main session
- Set `timeoutSeconds`, `cwd`, and tool budgets for a subagent task

# Core Rule — Main Session Default

**Workspace-mutating work that requires parent files must run in the main session with Ken approval, not in an isolated subagent.**

Isolated subagents are for:
- Read-only research or assessment
- Tasks that do not need parent workspace files
- Tasks where the verifier corpus can be fully embedded in the prompt

# Agent Name → Agent ID Reference

Use the exact `agentId` value when calling `sessions_spawn`:

| Name | Agent ID |
|---|---|
| Yoda | `main` |
| Aria | `business` |
| Atlas | `atlas/architect` |
| Thrawn | `platform-arch` |
| Forge | `infra` |
| Ahsoka | `ahsoka` |
| Spark | `spark/social` |
| Lando | `biz-process` |
| Mon Mothma | `change-mgt` |
| Shield | `security` |
| Lex | `legal` |
| Sage | `qa` |
| Warden | `governance` |
| Krennic | `sre` |

# Subagent Dispatch Checklist

Before calling `sessions_spawn`, confirm:

1. [ ] Task is read-only or does not need parent workspace files
2. [ ] If parent files are needed, `cwd` is set to `/Users/ainchorsangiefpl/.openclaw/workspace`
3. [ ] `timeoutSeconds` is set (default: 300 for assessment, 900 for build, 60 for quick checks)
4. [ ] Subagent prompt includes max tool-call budget (e.g. "You may use at most 20 tool calls")
5. [ ] Subagent prompt includes explicit stop condition (e.g. "Stop after N iterations and report")
6. [ ] Task objective, output format, and verifier are explicit in the prompt
7. [ ] For workspace-mutating tasks: Ken has explicitly approved main-session execution OR the subagent is same-agent fork (`context:"fork"`) with attachments

# Anti-Patterns

- ❌ Spawn a subagent to edit parent workspace files without `cwd` or attachments
- ❌ Spawn a subagent without `timeoutSeconds`
- ❌ Rely on `process kill` or `.stop` / `.abort` to kill a runaway subagent
- ❌ Use cross-agent subagents for build/cleanup work

# Helper Script

Use the canonical wrapper:

```bash
bash scripts/subagent-dispatch.sh <agent-id> <task-file>
```

The wrapper validates the dispatch checklist, sets safe defaults, and emits the `sessions_spawn` call.

# Reference

- L-146: Session Boundary / Subagent Workspace Access Blocker
- L-147: Do not kill the gateway to terminate a runaway subagent
- TKT-0536: Fix subagent dispatch, workspace access, and termination reliability
