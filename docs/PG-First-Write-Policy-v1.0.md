# PG-First Write Policy

**Version:** 1.0 · **Effective:** 2026-06-23 · **CHG:** CHG-0751 · **Ticket:** TKT-0359

## Purpose

Postgres is the master source of truth for the Nexus platform. This policy defines which state surfaces must be written to Postgres first, and which are explicitly excepted.

## Invariant

> **Class-1 durable knowledge state is PG-first mandatory.** All other state classes are excepted by default.

A script may only treat a file, SQLite database, or markdown document as the source of truth if that state surface is registered as class-2, class-3, or class-4 in the registry. If a surface is not registered, it is out-of-policy until classified.

## State classes

| Class | Name | Rule | Examples |
|-------|------|------|----------|
| 1 | Durable knowledge state | **PG-first mandatory**; JSON/markdown/SQLite may be derived cache only | `state_tickets`, `state_sprints`, `state_changes`, `state_lessons`, `agent_events`, `entity_links`, `verdict_log` |
| 2 | Operational telemetry | file or SQLite-primary allowed | health snapshots, outage state, auto-heal logs, diagnostics, latency, cost telemetry |
| 3 | Versioned source / DNA | file-primary | `SOUL.md`, `AGENTS.md`, `RULES.md`, skills, `openclaw.json` |
| 4 | Narrative | derived markdown | journals, daily memory, `CHANGELOG.md`, canvas documents |

### What counts as class-1?

A state surface is class-1 if it answers any of these questions across agents and sessions:

- What happened? (events, changes, verdicts)
- What is true now? (tickets, sprints, links)
- What must every agent agree on? (model policy, lessons)

If losing the file would change platform behavior or break cross-session continuity, it is almost certainly class-1.

## Writer obligations

1. **Write to Postgres first.** The PG write must complete and be acknowledged before any file cache is updated.
2. **File caches are derived.** JSON mirrors, markdown logs, and SQLite snapshots must be rebuildable from PG.
3. **Use canonical wrappers.** Class-1 writes must go through the approved writer scripts (`db-ticket.sh`, `db-sprint.sh`, `changelog-append.sh`, `pg-write-event.sh`, `pg-write-audit-event.sh`, `db-link.sh`) or a CHG-approved equivalent.
4. **Do not add new class-1 JSON files without approval.** Every new class-1 state surface must be added to `state/pg-first-write-registry.json` and approved via CHG.
5. **No silent fallbacks to file-primary.** If PG is unavailable, the operation must fail or defer; it must not silently promote a file to primary truth.

## Registry

The authoritative registry is `state/pg-first-write-registry.json`. It lists every class-1 surface, its PG table, any JSON cache file, the canonical writer scripts, its migration status, and the linked ticket.

## Enforcement

A deterministic enforcement gate will be built by Forge as a fast-follow to this policy. Until the gate is live, every new script or state file is reviewed manually by Yoda against this policy before merge.

## Exceptions

Exceptions are granted per class, not per file. To add a new class-1 surface or reclassify an existing surface, open a CHG and update the registry.

## Migration backlog

Class-1 surfaces still file-primary are tracked in existing tickets:

- `state_lessons` PG table — TKT-0362
- `verdict_log` PG table — TKT-0722

No new parallel backlog is created by this policy.
