#!/bin/bash
# subagent-dispatch.sh — Safe subagent dispatch helper for OpenClaw
# Enforces the subagent-dispatch skill rules from agent-skills/subagent-dispatch/SKILL.md
#
# Usage:
#   bash scripts/subagent-dispatch.sh <agent-id> <task-file.md> [--read-only] [--timeout <seconds>] [--cwd <path>]
#
# Examples:
#   bash scripts/subagent-dispatch.sh platform-arch /tmp/assessment-task.md --read-only --timeout 300
#   bash scripts/subagent-dispatch.sh main /tmp/quick-check.md --timeout 60 --cwd /Users/ainchorsoc2a/.openclaw/workspace

set -euo pipefail

WORKSPACE_ROOT="${WORKSPACE_ROOT:-/Users/ainchorsoc2a/.openclaw/workspace}"
DEFAULT_TIMEOUT=300
DEFAULT_CWD="$WORKSPACE_ROOT"

die() { echo "ERROR: $1" >&2; exit 1; }

AGENT_ID="${1:-}"
TASK_FILE="${2:-}"
[[ -z "$AGENT_ID" ]] && die "Missing agent-id"
[[ -z "$TASK_FILE" ]] && die "Missing task-file"
[[ -f "$TASK_FILE" ]] || die "Task file not found: $TASK_FILE"

READ_ONLY=false
TIMEOUT="$DEFAULT_TIMEOUT"
CWD="$DEFAULT_CWD"

shift 2
while [[ $# -gt 0 ]]; do
  case "$1" in
    --read-only) READ_ONLY=true ;;
    --timeout) TIMEOUT="$2"; shift ;;
    --cwd) CWD="$2"; shift ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done

# ── Validate dispatch checklist ───────────────────────────────────────────
if [[ "$READ_ONLY" == "false" && "$AGENT_ID" != "main" && "$CWD" == "$WORKSPACE_ROOT" ]]; then
  die "Workspace-mutating cross-agent subagent dispatch blocked. Either use --read-only, set --cwd to a non-parent path, use agent 'main', or get Ken approval."
fi

if [[ "$TIMEOUT" -le 0 || "$TIMEOUT" -gt 3600 ]]; then
  die "timeout must be between 1 and 3600 seconds"
fi

# ── Detect parent-workspace exec commands in cross-agent dispatches ──────
# Per-agent tool allow-lists may exclude 'exec'. Even with cwd=WORKSPACE_ROOT,
# a cross-agent subagent cannot run parent scripts. Only the main session (or
# an agent whose tool list explicitly includes 'exec') may be asked to execute
# commands in the parent workspace.
AGENT_HAS_EXEC=false
if [[ "$AGENT_ID" == "main" ]]; then
  AGENT_HAS_EXEC=true
else
  # Query OpenClaw agent config for tool allow-list. Agents with no explicit
  # tools block inherit default capabilities (exec allowed). An explicit
  # allow list without exec, or a deny list containing exec, blocks execution.
  # Note: openclaw agents list --json does not include tools, so use config get.
  AGENT_TOOL_MODE=$(openclaw config get agents.list 2>/dev/null | python3 -c "
import json,sys
agents=json.load(sys.stdin)
for a in agents:
    if a.get('id')=='$AGENT_ID':
        tools=a.get('tools',{})
        allow=tools.get('allow')
        deny=tools.get('deny',[])
        if allow is None:
            print('default')
        elif 'exec' in allow:
            print('allow_exec')
        elif 'exec' in deny:
            print('deny_exec')
        else:
            print('no_exec')
        break
" 2>/dev/null || echo "no_exec")
  if [[ "$AGENT_TOOL_MODE" == "default" || "$AGENT_TOOL_MODE" == "allow_exec" ]]; then
    AGENT_HAS_EXEC=true
  fi
fi

TASK_TEXT=$(cat "$TASK_FILE")
EXEC_INDICATORS=("bash " "sh " "zsh " "exec " "run " "scripts/" "./" "git " "docker " "kubectl " "make " "npm " "yarn " "python " "python3 " "node " "openclaw ")
REQUIRES_EXEC=false
for indicator in "${EXEC_INDICATORS[@]}"; do
  if [[ "$TASK_TEXT" == *"$indicator"* ]]; then
    REQUIRES_EXEC=true
    break
  fi
done

if [[ "$REQUIRES_EXEC" == "true" && "$AGENT_HAS_EXEC" == "false" ]]; then
  die "Cross-agent subagent $AGENT_ID cannot execute commands in the parent workspace (tool allow-list lacks 'exec'). Use agent 'main' with Ken approval, or embed the command output in the prompt."
fi

# ── Emit safe subagent prompt with tool budget and stop condition ────────
SAFE_TASK=$(cat "$TASK_FILE")
SAFE_TASK="$SAFE_TASK

---
SUBAGENT CONTROL RULES (mandatory):
1. You may use at most 30 tool calls total.
2. If your task requires iteration, stop after at most 10 iterations and report status.
3. Do not enter infinite loops. If stuck, report the blocker and stop.
4. Do not modify parent workspace files unless explicitly instructed.
"

# Write safe task to a temp file
TMP_TASK=$(mktemp /tmp/subagent-task.XXXXXX)
echo "$SAFE_TASK" > "$TMP_TASK"

echo "=== Safe Subagent Dispatch ==="
echo "Agent:      $AGENT_ID"
echo "Timeout:    ${TIMEOUT}s"
echo "CWD:        $CWD"
echo "Read-only:  $READ_ONLY"
echo "Task file:  $TMP_TASK"
echo ""
echo "Run the following in your parent session:"
echo ""
echo "  sessions_spawn({"
echo "    agentId: '$AGENT_ID',"
echo "    task: '$(cat "$TMP_TASK" | sed "s/'/\\'/g")',"
echo "    runtime: 'subagent',"
echo "    mode: 'run',"
echo "    cwd: '$CWD',"
echo "    timeoutSeconds: $TIMEOUT"
echo "  })"
