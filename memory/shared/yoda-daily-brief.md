# Yoda Daily Brief — 2026-06-18

## What Yoda Built Today

**Clean-up day — 4 tickets closed (TKT-0529, TKT-0525, TKT-0538, TKT-0410), 6 lessons logged, and the old-code audit remediation policy locked into CREST + Agile skills.**

The day split into two phases: morning old-code audit remediation (TKT-0529 A7 Bundles 1-4) and afternoon close-out of 3 more tickets with PG fixes.

### Morning: TKT-0529 A7 — Old-Code Audit Remediation (05:13-16:41 AEST)

Yoda completed the final A7 bundles of the old-code audit project:

1. **Bundle 1 — auto-heal.sh hardening (CHG-0623):** Added `set -euo pipefail` to `scripts/auto-heal.sh`. Discovered that `pgrep` returning no matches fires the ERR trap even when the pipeline ends with `|| true`. Fixed with `|| true` on no-match-expected commands. Lesson L-150 logged.

2. **Bundle 2 — Subagent verification trap (L-151):** B2.3-B2.5 were reported as done by subagents but `git diff` showed no changes. Only B2.2 had actually run. Yoda re-dispatched with stricter task specs requiring `git diff` in the response. Lesson L-151: completion events are not evidence.

3. **Bundle 3 — Subagent completion event empty (L-152):** B3.7 completion event arrived with 0 tokens out. Yoda verified independently with `git status`, `git diff`, `zsh -n`, and `--dry-run`. Changes were present. Lesson L-152: treat completion events as notifications, not proof.

4. **Bundle 4 — Hardcoded paths removed (CHG-0639):** Removed all remaining `/Users/ainchorsangiefpl/.openclaw/workspace` hardcoded paths from Python HEREDOCs in `ollama-quota-track.sh` and `cron-migration-advisor.sh`. Paths now passed via `sys.argv`. Final verification: 0 hardcoded paths remain, 4 regression suites pass (15/15, 7/7, 9/9, 6/6). TKT-0529 closed.

5. **Old-code audit policy locked (CHG-0631):** Ken approved A7 policy decisions at 08:11 AEST. Yoda updated `agent-skills/crest/SKILL.md` and `agent-skills/agile/SKILL.md` with the Old-Code Audit Rule and Remediation Policy sections. Deep-groomed audit report written to `tests/regression/tkt0529/audit-report-deep.md`.

### Afternoon: TKT-0525, TKT-0538, TKT-0410 Close-Out (16:49-17:10 AEST)

1. **TKT-0525 A4 — db-ticket.sh sync fix (L-153):** During TKT-0529 close-out, discovered `db-ticket.sh sync <TKT-ID>` ignored the ticket ID and called `pg-to-notion-sync.sh` without arguments, causing full batch sync. Ken approved folding fix into TKT-0525. Fixed: `cmd_sync()` now calls `pg-to-notion-sync.sh --single "$tkt_id"`. Committed `d7367efd`.

2. **TKT-0538 — db-write.sh UPSERT fix (L-155):** `db-ticket.sh update` wasn't writing top-level status to PG. Root cause: `db-write.sh` used `INSERT ... ON CONFLICT DO UPDATE` for existing rows; PG evaluated `chk_title_not_empty` on the attempted insert row (title NULL), causing silent file-only fallback. Fixed: detects existing rows and emits plain `UPDATE`; `INSERT` only for new rows. Updated `agent-skills/pg-sprint-backlog/SKILL.md`. Committed `3918eb27`.

3. **TKT-0410 — SUB_CREST_TRANSITIONS verified→terminal edge (L-156):** Added `'verified': {'complete', 'sub_crest_done', 'done'}` to `SUB_CREST_TRANSITIONS` in `scripts/lib/pg_task_queue.py`. Added `TestVerifiedToTerminalTransitions` (4 tests). Unit tests 11/11 OK. Committed `8a0a26c5`.

4. **Sprint 8 status corrected:** `db-sprint.sh status` showed TKT-0529 as `open` despite earlier close-out. PG read confirmed `status=open`, `metadata.resolution=completed`. Re-closed via the now-fixed `db-ticket.sh update`. Sprint 8 now: 12 closed/done, 4 open, 75% completion.

### Cross-Cutting: Lessons Learned

- **L-149:** OpenClaw's runtime agent init hook = workspace bootstrap files, not a separate config. Don't use `systemPromptOverride` unless replacing the entire prompt. Add agent-level rules to `SOUL.md`.
- **L-148:** Don't yield the session while waiting for a short subagent timeout. For a 30s timeout that completed in 3s, yielding caused unnecessary delay.
- **L-147:** Don't kill the gateway to terminate a runaway subagent. Ken directive.
- **L-146:** Session boundary / subagent workspace access blocker documented.
- **L-154:** Use append, not overwrite, for memory files. (Yoda accidentally overwrote `memory/2026-06-18.md` with a `write` tool call. Recovered from earlier turn content.)

## Key Decisions Made Today

- **Old-code audit remediation policy locked into CREST + Agile skills** — Ken approved at 08:11 AEST. The Old-Code Audit Rule and Remediation Policy are now SSOT in the skill packages, not in agent files.
- **TKT-0525 A4 fix approved as side-finding** — Ken approved folding the `db-ticket.sh sync` bug fix into TKT-0525 since it was discovered during TKT-0529 close-out.
- **`db-write.sh` UPSERT pattern fixed** — For existing rows, use plain `UPDATE`; `INSERT ... ON CONFLICT` only for new rows. After any write, verify with a PG read, not the writer's exit code.
- **State maps must include intermediate success states as sources for terminal transitions** — `verified` was a pre-terminal success state but wasn't listed as a source for `complete`/`done`/`sub_crest_done`. Fixed and regression-tested.
- **Subagent completion events are notifications, not proof** — Always verify with independent tool-backed evidence (`git diff`, `grep`, test output, logs) before marking complete.

## Training Content Angles from Today

From today's work, these are ready for the training pipeline:

- **"Your subagent said it's done. The git log says otherwise."** — The day Yoda's subagents reported 3 bundles complete but only 1 had actually run. Why completion events are not evidence, and how independent `git diff` verification caught the false progression. Real lesson in trusting AI self-reports.
- **"The UPSERT that wasn't: when Postgres check constraints silently swallow your update"** — `INSERT ... ON CONFLICT DO UPDATE` still evaluates check constraints on the insert row before the conflict is resolved. A NULL title on an existing row caused silent file-only fallback. How detecting row existence first and using plain `UPDATE` fixed it.
- **"The missing edge: why verified tasks stalled at 99% complete"** — A state machine that marks `verified` as a pre-terminal success state but forgets to list it as a source for terminal transitions. Tasks stalled indefinitely. One line fix, 4 regression tests.
- **"Don't yield the session: why waiting for a 3-second subagent cost 30 seconds"** — `sessions_yield` is for when the parent has no further work. For short subagent timeouts, yielding caused unnecessary delay. When to wait vs when to keep working.
- **"The old-code audit that found 0 hardcoded paths"** — TKT-0529 A7 Bundle 4: removing all `/Users/ainchorsangiefpl/.openclaw/workspace` hardcoded paths from Python HEREDOCs. 4 regression suites, 37 tests, 0 remaining violations. How systematic path removal works at scale.

## What's Open / What's Next

- **Sprint 8: 75% complete (12/16).** 4 open tickets: TKT-0293 (regression testing), TKT-0319 (TQP Phase 3), TKT-0324 (TQP rollout test), TKT-0326 (NAS setup).
- **Model swap trial (deepseek-v4-pro → kimi-k2.7-code):** Running since 2026-06-17. Trial ends Sun 22 Jun 10:00 AEST. Monitor Ollama dashboard for usage drop. If quality is unacceptable, 5-minute rollback.
- **TKT-0533 (Ollama tracker):** Live in production. Next step: monitor burn alert at 70% weekly threshold.
- **CREST v2.0 design for structural executor dispatch** remains pending.
- **Business agent (Aria)** has no active session — will pick up new kimi-k2.7-code model on next activation.

## ✅ Auth Status
- All delegated auth tokens valid (Ken Mun ✅, Angie Foong ✅). No alerts.
