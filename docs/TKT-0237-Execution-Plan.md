# TKT-0237 — Execution Plan (Atomic, Sequential)
**Sprint 4 | 11h | 6 stories → 26 atoms | No parallel execution**

## Execution Principle
Each atom is a single unit of work. Each atom completes AND IS VERIFIED before the next atom starts. No "fire two things at once." No "assume done." Each atom produces one observable output.

## Dependency Chain
```
A1 → A2 → C1 → A3 → B1 → B2
```
Stream C (TQP) needs A1's verify function. A3 needs A1. B2 needs B1. Everything else is sequential to eliminate race conditions.

---

## PHASE 1: DoD Verification Gate (A1 + A2)

### Atom 1.1 — Create verify_before_close() function skeleton
**Effort:** 20 min | **Owner:** Yoda
**Task:** Add function stub to `scripts/ticket.sh`. Function signature: `verify_before_close(ticket_id, ticket_type, deliverable_path)`. Returns 0 (pass) or 1 (fail) with error message to stderr. No logic yet — just the skeleton with exit codes.
**Verify:** `grep "verify_before_close" scripts/ticket.sh` returns match. Function is syntactically valid bash (`bash -n scripts/ticket.sh` exits 0).

### Atom 1.2 — Implement file existence check for task-type tickets
**Effort:** 15 min | **Owner:** Yoda
**Task:** In `verify_before_close()`, for type=task: check `test -f <deliverable_path>`. If not found, echo error and return 1.
**Verify:** Create test file. Run `verify_before_close TKT-TEST task /path/to/file` → returns 0. Run with nonexistent path → returns 1 with error message.

### Atom 1.3 — Implement git commit check for task-type tickets
**Effort:** 15 min | **Owner:** Yoda
**Task:** In `verify_before_close()`, for type=task: after file check passes, run `git log -1 --oneline -- <deliverable_path>`. If empty (file not in git), echo error and return 1.
**Verify:** Create file, git add + commit. Run verify → returns 0. Create file, DON'T commit. Run verify → returns 1.

### Atom 1.4 — Implement CHG-type verification
**Effort:** 15 min | **Owner:** Yoda
**Task:** For type=change/CHG: grep for ticket ID in `memory/CHANGELOG.md`. If not found, return 1. Also check `git diff HEAD~1 --name-only` — at least one file must have changed. 
**Verify:** Close a CHG ticket with changelog entry + code committed → returns 0. Close without changelog entry → returns 1.

### Atom 1.5 — Implement bug-type verification
**Effort:** 10 min | **Owner:** Yoda
**Task:** For type=bug: grep for ticket ID in `memory/CHANGELOG.md` (bug fix must be documented). Check git diff for code changes.
**Verify:** Bug ticket with changelog entry + committed fix → returns 0. Without → returns 1.

### Atom 1.6 — Implement config-type verification
**Effort:** 10 min | **Owner:** Yoda
**Task:** For type=config: check `git diff HEAD~1 -- <config_path>` has changes. Check `state/critical-config-baseline.json` has matching update.
**Verify:** Config ticket with file changed + baseline updated → returns 0. Missing baseline update → returns 1.

### Atom 1.7 — Wire verify_before_close() into ticket.sh close flow
**Effort:** 15 min | **Owner:** Yoda
**Task:** In the `close` subcommand, call `verify_before_close()` BEFORE atomic_write. If return 1, output error and exit without closing. Add `--skip-verify` flag for Ken override. Add `--deliverable-path <path>` flag for declaring expected deliverable.
**Verify:** Full end-to-end test: create task ticket → close without deliverable → BLOCKED. Add `--skip-verify` → closes successfully. Create task ticket → set deliverable → commit → close → PASSES.

### Atom 1.8 — Handle edge cases
**Effort:** 15 min | **Owner:** Yoda
**Task:** Tickets with no declared deliverable path → skip file check (only validate CHANGELOG for CHG/bug types). Tickets with notionPageId=null → skip Notion archive, still do local close. Tickets already closed → skip verification (re-close is no-op with warning).
**Verify:** Close a research-type task (no file deliverable) → passes (skips file check). Close a ticket with no Notion page → passes (skips Notion archive). Attempt to close already-closed ticket → "Already closed" warning.

### Atom 1.9 — Write DoD Validation Rules document
**Effort:** 30 min | **Owner:** Yoda
**Task:** Create `docs/DoD-Validation-Rules.md` with all 5 sections: type matrix, path conventions, edge cases, override protocol, SoT mapping. Reference TKT-0197 for canonical data locations.
**Verify:** Document has all 5 sections. Matrix covers task/bug/change/config/incident. Path conventions are specific (not generic). Edge cases section lists 4+ scenarios. Override protocol specifies --skip-verify + changelog audit trail.

### Atom 1.10 — Update RULES.md
**Effort:** 10 min | **Owner:** Yoda
**Task:** Add "DoD Verification Gate" section to RULES.md. Non-negotiable. Reference `docs/DoD-Validation-Rules.md` and `ticket.sh --skip-verify` override. Mark as enforced by platform, not just documented.
**Verify:** RULES.md has DoD section. References correct paths. Git committed.

---

## PHASE 2: Task Queue Processor (C1)

### Atom 2.1 — Create task-queue.json schema
**Effort:** 15 min | **Owner:** Forge
**Task:** Create `state/task-queue.json` with schema: `{queue: [], metrics: {totalProcessed, totalFailed, avgCompletionMs}}`. Each queue entry: taskId, ticketId, story, type, promptFile, expectedDeliverable, status, retries, maxRetries, assignedModel, queuedAt, startedAt, completedAt, verificationResult.
**Verify:** File is valid JSON. `jq . state/task-queue.json` exits 0. Schema contains all required fields.

### Atom 2.2 — Build TQP dispatch function
**Effort:** 30 min | **Owner:** Forge
**Task:** `scripts/task-queue-processor.sh` — reads queue, picks first item with status=queued, calls `sessions_spawn` with prompt from `promptFile`, waits for completion, returns sub-agent session result.
**Verify:** Manually add task to queue. Run processor → sub-agent spawns. Sub-agent completes → processor receives output.

### Atom 2.3 — Build verification integration
**Effort:** 20 min | **Owner:** Forge
**Task:** After sub-agent completes, call `verify_before_close()` from A1's function (source it from ticket.sh). PASS → update queue entry to status=done. FAIL → increment retries. If retries < 3: re-queue (status=queued). If retries >= 3: status=failed, create `state/task-queue-failed.json` alert.
**Verify:** Task with valid output → verified → status=done. Task with broken output → re-queued with retries=1. After 3 failures → status=failed, alert JSON created.

### Atom 2.4 — Build queue metrics
**Effort:** 15 min | **Owner:** Forge
**Task:** After each task completes, update `state/task-queue-metrics.json`: totalProcessed++, totalFailed++ (if failed), avgCompletionMs (rolling), queueDepth (current queue length).
**Verify:** Process 2 tasks. metrics.json shows totalProcessed=2, queueDepth updated.

### Atom 2.5 — Add --auto-execute flag to ticket.sh
**Effort:** 15 min | **Owner:** Forge
**Task:** `ticket.sh new --auto-execute` → creates ticket AND adds entry to `state/task-queue.json` with expectedDeliverable from ticket description. `--deliverable-path <path>` flag sets expected path.
**Verify:** `ticket.sh new --auto-execute --title "Test" --deliverable-path scripts/test.sh` → ticket created + queue entry added. Queue entry has correct ticketId + expectedDeliverable.

### Atom 2.6 — Create TQP cron
**Effort:** 10 min | **Owner:** Forge
**Task:** Cron job: every 5 min, runs `scripts/task-queue-processor.sh`. Light context. Model: deepseek-v4-pro. Timeout: 300s. Delivery: none (silent). Failure alert: after 3 consecutive errors, notify Ken.
**Verify:** Cron created and listed. Wait 5 min → check if processor ran (check queue metrics updated).

---

## PHASE 3: Post-Deliverable Validator (A3)

### Atom 3.1 — Build dod-validator.sh
**Effort:** 25 min | **Owner:** Warden
**Task:** Script reads `state/tickets.json`, finds tickets with status=closed AND updated within last 24h. For each: re-run `verify_before_close()`. If check fails → create `state/dod-validation-alert.json`. If check passes → do nothing. If alert exists and deliverable now present → clear alert.
**Verify:** Close ticket with valid deliverable → validator runs → no alert. Delete deliverable file → validator runs → alert created. Restore file → validator runs → alert cleared.

### Atom 3.2 — Wire to heartbeat
**Effort:** 15 min | **Owner:** Warden
**Task:** Add check to HEARTBEAT.md: read `state/dod-validation-alert.json`. If alerts exist with acknowledged=false → surface to Ken via Telegram with ticket ID, failed check, expected path, closed time.
**Verify:** Create manual alert entry. Run heartbeat check → Telegram message sent with correct ticket details.

### Atom 3.3 — Create validator cron
**Effort:** 10 min | **Owner:** Warden
**Task:** Cron: every 2 hours (xx:15), runs `scripts/dod-validator.sh`. Model: gemma4:31b-cloud. Timeout: 30s. Light context.
**Verify:** Cron created. Wait 2h → check if validator ran (check state/dod-validation-alert.json timestamps).

---

## PHASE 4: 10-Rule Audit Engine (B1)

### Atom 4.1 — Build rule-audit.sh framework
**Effort:** 20 min | **Owner:** Warden
**Task:** Create script skeleton that iterates 10 rules, calls each rule's check function, collects results, outputs JSON. Output schema: `{runAt, rules: {R01-R10: {status, violations, detail, remediation}}, summary: {totalRules, passed, failed, warned, blockers}}`.
**Verify:** Script runs, outputs valid JSON with all 10 rules present. All rules return "NOT_IMPLEMENTED" initially.

### Atom 4.2 — Implement R01 (Path Discipline)
**Effort:** 15 min | **Owner:** Warden
**Task:** Scan recent session transcript files in `/agents/*/sessions/` for tilde paths (`~/.openclaw`) in tool call arguments. Count violations. If >0: FAIL (BLOCKER). Detail: list of files + line numbers where tilde paths found.
**Verify:** Today had 4+ tilde-path violations. Script should catch them. Output shows file names + counts.

### Atom 4.3 — Implement R03 (Model Routing)
**Effort:** 15 min | **Owner:** Warden
**Task:** Compare active agent models (from `state/agent-status.json` or gateway config) against `Model3-Policy.md`. Any mismatch → FAIL (BLOCKER). Detail: which agent, expected model, actual model.
**Verify:** Standup cron was kimi while policy says deepseek → should flag. After today's patch → should pass.

### Atom 4.4 — Implement R09 (Cron Health)
**Effort:** 15 min | **Owner:** Warden
**Task:** Scan cron job list for any job with `consecutiveErrors >= 3`. If found → FAIL (BLOCKER). Detail: cron ID, name, error count, last error message.
**Verify:** Journal incremental cron (1b853131) had 4 consecutive errors → should flag. After fix → should pass.

### Atom 4.5 — Implement R06 (ID Uniqueness)
**Effort:** 10 min | **Owner:** Warden
**Task:** Scan `state/tickets.json` for duplicate IDs. Scan `memory/CHANGELOG.md` for duplicate CHG/INC IDs. Any duplicates → FAIL (BLOCKER).
**Verify:** No duplicates expected. If manually create duplicate → should flag.

### Atom 4.6 — Implement R07 (Config Drift)
**Effort:** 10 min | **Owner:** Warden
**Task:** Compare `openclaw.json` model assignments against `state/critical-config-baseline.json`. Unapproved differences → FAIL (BLOCKER). Detail: which field, expected value, actual value.
**Verify:** Baseline is up to date. If manually change a model assignment, run → should flag.

### Atom 4.7 — Implement R10 (MEMORY Limits)
**Effort:** 5 min | **Owner:** Warden
**Task:** `wc -c MEMORY.md`. If >16000 chars → WARN. Detail: current size, limit, delta.
**Verify:** Run → should output current size. If MEMORY.md >16000 → WARN.

### Atom 4.8 — Implement R02, R04, R05, R08 (remaining rules)
**Effort:** 20 min | **Owner:** Warden
**Task:** R02: sample 10 recent reads against SoT Register. R04: diff-check output structure vs locked template. R05: check recent ticket closes for state-checking pattern. R08: check content-queue.json for triad-gated publishing. All WARNING severity.
**Verify:** Each rule outputs meaningful detail, not just "PASS." At least one rule should find a real (non-zero) result.

---

## PHASE 5: Weekly Report (B2)

### Atom 5.1 — Build report generator
**Effort:** 30 min | **Owner:** Warden
**Task:** `scripts/rule-audit-report.sh` — reads audit report history, calculates compliance score (weighted: BLOCKER=-10%, WARNING=-3%), generates HTML canvas report. Same CSS as standup template. Sections: hero, trend, rule table, top violations, blockers, improved/degraded.
**Verify:** Run against 1 day of audit data → HTML renders, all sections present, no empty sections.

### Atom 5.2 — Build Telegram delivery
**Effort:** 10 min | **Owner:** Warden
**Task:** After report generation, send Telegram flash to Ken: score, PASS/FAIL/WARN counts, top blocker, top improvement.
**Verify:** Flash message ≤600 chars, contains all required fields.

### Atom 5.3 — Create weekly cron
**Effort:** 5 min | **Owner:** Warden
**Task:** Cron: Monday 09:00 AEST. Runs `scripts/rule-audit-report.sh`. Model: deepseek-v4-pro. Timeout: 120s. Delivery: announce to Telegram 8574109706.
**Verify:** Cron created. First report scheduled.

---

## Summary

| Phase | Atoms | Effort | Owner | Depends On |
|-------|-------|--------|-------|------------|
| 1: DoD Gate | 1.1–1.10 (10 atoms) | 3h | Yoda | — |
| 2: TQP | 2.1–2.6 (6 atoms) | 2h | Forge | Phase 1 complete |
| 3: Validator | 3.1–3.3 (3 atoms) | 1h | Warden | Phase 1 complete |
| 4: Audit Engine | 4.1–4.8 (8 atoms) | 2h | Warden | — (independent) |
| 5: Report | 5.1–5.3 (3 atoms) | 1h | Warden | Phase 4 complete |

**Total: 26 atoms, 9h (reduced from 11h — sequential eliminates parallel overhead)**

**Note:** Phases 1→2→3 must be sequential. Phase 4 can run anytime (independent of Phases 1-3). Phase 5 needs Phase 4.

**Execution order:**
1. Phase 1 (Atoms 1.1–1.10) — Yoda
2. Phase 4 (Atoms 4.1–4.8) — Warden (can run during Phase 1 since independent)
3. Phase 2 (Atoms 2.1–2.6) — Forge (needs Phase 1)
4. Phase 3 (Atoms 3.1–3.3) — Warden
5. Phase 5 (Atoms 5.1–5.3) — Warden (needs Phase 4)
