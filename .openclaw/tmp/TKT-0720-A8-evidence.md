# TKT-0720 A8 — Commit Evidence

**Timestamp:** 2026-06-22 20:26 AEST
**Executor:** Forge (subagent)

## Pre-commit `git status --short`

```
M MEMORY.md
 M agents/ahsoka/AGENTS.md
 M memory/2026-06-22.md
 M memory/CHANGELOG.md
 M memory/journal-2026-06-22.md
 M scripts/changelog-append.sh
 M scripts/db-sprint.sh
 M scripts/db-ticket.sh
 M scripts/model-policy-query.sh
 M state/agent-identity-audit.json
 M state/agent-rules-audit.json
 M state/auto-heal-2026-06-22.json
 M state/auto-heal-cron-timeout-audit.json
 M state/auto-heal-current.json
 M state/check31-last-fire.json
 M state/check32-last-fire.json
 M state/cooldown-gate-findings.json
 M state/crest-execute-gate-log.json
 M state/crest-rejection-stalls.json
 M state/crest-script-syntax.json
 M state/crestv2-p1-tracker.json
 M state/critical-config-baseline.json
 M state/cron-list-snapshot.json
 M state/cron-migration-advisor-last-run.json
 M state/cron-migration-suggestions.json
 M state/cron-ollama-usage.json
 M state/cron-timeout-applied.json
 M state/db-ticket-shell-failures.json
 M state/delegation-log.json
 M state/fallback-chain-status.json
 M state/file-contracts.json
 M state/gateway-launch-state.json
 M state/health-state.json
 M state/latency-summary.json
 M state/latency-tracker-state.json
 M state/lessons-staleness-state.json
 M state/long-id-stubs.json
 M state/model-drift-state.json
 M state/model-policy-drift-alert.json
 M state/null-safe-json-findings.json
 M state/obs-collector-state.json
 M state/obs-trend.json
 M state/obs.db
 M state/ollama-quota-track-last-run.json
 M state/ollama-usage.json
 M state/pipefail-trap-findings.json
 M state/sandbox-boundary-audit.json
 M state/skill-load-registry.json
 M state/task-collector-state.json
 M state/task-queue-legacy-archive.json
 M state/tickets.json
 M state/tkt-0539-assessment.json
 M state/tqp-executor-state.json
 M state/tqp-orphan-writes.json
 M state/tqp-stuck-claims.json
 M state/tz-drift-report.json
 M state/uptime-log.json
 M state/yoda-context-brief.md
 M tests/regression/model-routing/test-consumer-consistency.sh
 M tests/regression/model-routing/test-policy-consistency.sh
?? MD
?? OF
?? agent-skills/crest/notes/
?? agents/atlas/
?? infra/rollback/TKT-0720-rollback.sql
?? scripts/db-link.sh
?? scripts/entity-links-backfill.sh
?? state/task-queue-legacy-archive.json.bak-20260622-173722
?? state/tkt-0539-assessment.json.bak-20260622-173722
```

**Note:** Only the 16 specified TKT-0720 files were staged. All other modified/untracked files were intentionally excluded.

## Commit SHA

```
39c735732aed87e05866ca8feb06eb44fd7b6233
```

## `git log -1 --stat`

```
commit 39c735732aed87e05866ca8feb06eb44fd7b6233
Author: Yoda (AInchors) <yoda@ainchors.com>
Date:   Mon Jun 22 20:26:02 2026 +1000

    TKT-0720: entity_links edge table + markdown backfill + live hooks
    
    - Add entity_links table, sequence, format_link_id(), indexes
    - Add db-link.sh shared helper (insert, parse, resolve)
    - Add entity-links-backfill.sh (dry-run / commit modes)
    - Wire live-write hooks into db-ticket.sh, changelog-append.sh, db-sprint.sh
    - Backfill 1,504 entity edges + 95 file edges from markdown Linked: mentions
    - Completeness audit: ≥97.99% of discoverable edges captured
    - Add TKT-0720 rollback script

 .openclaw/tmp/TKT-0720-A1-architecture-note.md  | 288 +++++++++++++++++
 .openclaw/tmp/TKT-0720-A2-evidence.md           | 146 +++++++++
 .openclaw/tmp/TKT-0720-A3-evidence.md           | 112 +++++++
 .openclaw/tmp/TKT-0720-A4-evidence.md           | 149 +++++++++
 .openclaw/tmp/TKT-0720-A5-completeness-audit.md |  89 +++++
 .openclaw/tmp/TKT-0720-A6-multihop-demo.md      |  38 +++
 .openclaw/tmp/TKT-0720-A7-verification.md       |  87 +++++
 .openclaw/tmp/TKT-0720-CREST-plan.md            | 176 ++++++++++
 .openclaw/tmp/TKT-0720-groomed-brief.md         | 119 +++++++
 infra/rollback/TKT-0720-rollback.sql            |   9 +
 scripts/changelog-append.sh                     |  17 +
 scripts/db-link.sh                              | 411 ++++++++++++++++++++++++
 scripts/db-sprint.sh                            |   5 +
 scripts/db-ticket.sh                            |  78 +++++
 scripts/entity-links-backfill.sh                | 169 ++++++++++
 state/crestv2-p1-tracker.json                   |  10 +-
 16 files changed, 1897 insertions(+), 6 deletions(-)
```

## Files in Commit (16 total)

| # | File | Type |
|---|------|------|
| 1 | `.openclaw/tmp/TKT-0720-A1-architecture-note.md` | Evidence/planning |
| 2 | `.openclaw/tmp/TKT-0720-A2-evidence.md` | Evidence/planning |
| 3 | `.openclaw/tmp/TKT-0720-A3-evidence.md` | Evidence/planning |
| 4 | `.openclaw/tmp/TKT-0720-A4-evidence.md` | Evidence/planning |
| 5 | `.openclaw/tmp/TKT-0720-A5-completeness-audit.md` | Evidence/planning |
| 6 | `.openclaw/tmp/TKT-0720-A6-multihop-demo.md` | Evidence/planning |
| 7 | `.openclaw/tmp/TKT-0720-A7-verification.md` | Evidence/planning |
| 8 | `.openclaw/tmp/TKT-0720-CREST-plan.md` | Evidence/planning |
| 9 | `.openclaw/tmp/TKT-0720-groomed-brief.md` | Evidence/planning |
| 10 | `infra/rollback/TKT-0720-rollback.sql` | Code/config |
| 11 | `scripts/changelog-append.sh` | Code/config (modified) |
| 12 | `scripts/db-link.sh` | Code/config (new) |
| 13 | `scripts/db-sprint.sh` | Code/config (modified) |
| 14 | `scripts/db-ticket.sh` | Code/config (modified) |
| 15 | `scripts/entity-links-backfill.sh` | Code/config (new) |
| 16 | `state/crestv2-p1-tracker.json` | State (modified) |

**Note:** The deliverable listed 16 file paths. The "exactly 11" count in the instructions appears to be a stale count from an earlier version of the task. All 16 listed files were committed.

## Verification

- ✅ No unrelated files staged (only the 16 TKT-0720 files)
- ✅ Commit message matches exactly
- ✅ Commit SHA captured: `39c735732aed87e05866ca8feb06eb44fd7b6233`
- ✅ Not pushed to remote
- ✅ Evidence file written
