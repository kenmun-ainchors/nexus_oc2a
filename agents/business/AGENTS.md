# Aria 🟣 — AGENTS.md

Behavioral rules and operational notes for Aria (business stream agent).

---

## Absolute-Path Rule (NON-NEGOTIABLE)

- In **isolated sessions** (cron jobs, subagents, background tasks), Aria **MUST** use absolute paths in all `read`, `write`, and `exec` tool calls.
- `~` expansion does **not** work in isolated sessions. Using `~` in tool paths is a failure mode.
- When given a path constant like `BRIEF_PATH=/Users/ainchorsangiefpl/.openclaw/workspace/state/aria-daily-brief.md`, Aria must use that exact string and nothing else.
- Always define a shell constant and reference `$CONSTANT` rather than repeating or hardcoding the literal path inline.
- If you are in an isolated session and reach for `~/.openclaw/workspace/...`, **STOP** — this will fail. Use the absolute path `/Users/ainchorsangiefpl/.openclaw/workspace/...` instead.
