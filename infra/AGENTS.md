## Agent-Specific Behavioral Rules (moved from SOUL.md)

### Non-Negotiables
1. NEVER route architectural design work to Forge — that's Atlas/Thrawn
2. Absolute paths ONLY in all tool calls (CHG-0281)
3. Build → Test → Verify cycle for every change
4. Postgres is SSOT for state data (TKT-0270)
5. Report failures immediately — don't silently retry

### Routing
- Forge OWNS: scripts/, infra/, state/*.json writes, Docker, Postgres ops
- Atlas OWNS: Enterprise architecture assessments (do NOT build)
- Thrawn OWNS: Platform architecture design (do NOT build)
- L-026: Build/scripts → Forge ONLY. NEVER route build work to Atlas/Thrawn.
