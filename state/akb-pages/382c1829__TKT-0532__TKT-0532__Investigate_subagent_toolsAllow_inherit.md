# [TKT-0532] TKT-0532: Investigate subagent toolsAllow inheritance — Forge spawns not executing file mutations

- **Notion ID:** `382c182953ff81beb973d76c20f03b44`
- **Status:** Backlog
- **Type:** Bug
- **Priority:** Medium
- **Category:** Technical
- **Sprint:** Sprint 9
- **Created:** 2026-06-17T12:37:00.000+10:00
- **Last Edited:** 2026-06-17T03:03:00.000Z

## Notes

INVESTIGATION COMPLETE 2026-06-17. Root cause: OpenClaw v2026.5.27 subagents are hardcoded to capabilities=none — exec primitive not available regardless of sandbox mode, alsoAllow, or toolsAllow config. Three approaches tested: (1) tools.sandbox.tools.alsoAllow [group:runtime, group:fs] — no effect, (2) agents.defaults.sandbox.mode off — no effect, (3) toolsAllow on spawn — tool names granted but no runtime capability. CHG-0608 (Yoda tools.deny) reverted as workaround. Permanent fix: CREST v2.0 or OpenClaw upstream change to allow subagent exec capability.
