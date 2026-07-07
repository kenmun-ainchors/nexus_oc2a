# CHG-0830 — Retention Cleanup Architecture Brief

## Overview
Remediate session/trajectory bloat in `agents/*/sessions/`. The system accumulates `.jsonl` session files, `.trajectory.jsonl` trajectory dumps, and `.trajectory-path.json` metadata files across 14 agent directories. Current footprint: ~16 GiB, with `main/` alone at 9 GiB.

## Design

### Script: `scripts/retention-cleanup.sh`
- Three modes: dry-run (default), `--apply` (live deletion), `--report` (audit-only)
- TTL_SESSIONS=14d (JSONL session files, excludes *.trajectory.jsonl)
- TTL_TRAJECTORY=7d (*.trajectory.jsonl and *.trajectory-path.json)
- TTL_ORPHAN=7d (cancelled-orphan/historical-orphan in task-queue.json)
- Overridable via env vars or `--ttl-*` CLI flags
- Excludes files modified <24h ago (configurable via `--min-age`)
- Cross-references active session UUIDs from `openclaw status --json`, excludes those
- Never touches: memory SQLite DBs, `.usage-cost-cache.json`, config, workspace state files
- Uses `find -mtime +N` for idempotent file scanning
- Atomic temp-file handling for JSON queue pruning

### Cron: `state/chg-0830-cron-payloads.json`
- **Daily 03:00 AEST**: `retention-cleanup.sh --apply`
- **Weekly Monday 05:00 AEST**: `retention-cleanup.sh --report`
- Both disabled by default, require approval before enabling

### Safety
- Default dry-run prevents accidental deletion
- `find -mtime +N` means first run only deletes files older than TTL
- Active session cross-reference prevents deleting in-use conversation files
- 24h min-age buffer prevents deleting files recently created or modified
- Never touches memory DBs, config, or workspace state JSON files