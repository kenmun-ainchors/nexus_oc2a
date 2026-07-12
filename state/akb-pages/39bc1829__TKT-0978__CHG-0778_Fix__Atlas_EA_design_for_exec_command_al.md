# [TKT-0978] CHG-0778 Fix: Atlas EA design for exec command allowlist/denylist

- **Notion ID:** `39bc182953ff815eb55fe079ec596faa`
- **Status:** Open
- **Type:** task
- **Priority:** High
- **Category:** Technical
- **Sprint:** 
- **Created:** 2026-07-12T08:35:00.000+10:00
- **Last Edited:** 2026-07-12T08:35:00.000Z

## Notes

Complete CHG-0783: Atlas EA decides allowlist vs denylist (or hybrid) for shell exec strings across OpenClaw tool calls and subagent dispatches. Define covered script set, escape-hatch policy, and integration with dispatch-validate.sh / crest-execute-gate.sh. This is the design prerequisite before Forge builds the enforcement gate. Trigger: 2026-08-01 resume.
