# TKT-0237 — Platform Rule Engine v1 (Groomed — Final)
**Sprint 4 | Owner: Yoda + Warden + Forge | Effort: 11h | Status: Open**

## Why This Exists
CHG-0401 was "done" — 607 items migrated, 3 databases created, CHANGELOG claimed verification.
Reality 4 days later: 15 Done + 5 Auto-Heal still in DB A. DB C had no schema. The archive code never shipped.
Every closed ticket this sprint was vulnerable to the same pattern: agent executes → reports done → no one checks.

TKT-0237 fixes this at TWO levels:
1. **Ticket level (Stream A):** Pre-close gate — blocks close if deliverable doesn't exist
2. **Platform level (Stream C):** Task Queue Processor — changes how agents execute work so verification is mandatory, not optional

The gate catches bad closes. The processor prevents them from happening at all.

---

## STREAM A: DoD Verification Gate (Yoda, 2.5h)

### Story A1: Pre-close validation hook in ticket.sh
**Owner:** Yoda | **Effort:** 1.5h

On `ticket.sh close`, a new `verify_before_close()` function runs BEFORE status is set to closed. It checks type-specific proof that the work was actually done:

| Ticket type | Must exist | Check method |
|-------------|-----------|--------------|
| `task` | Deliverable file at declared path, git committed in last commit | `test -f <path>` + `git log -1 --oneline -- <path>` |
| `bug` | Fix script or code change committed + ticket linked to CHG in changelog | `grep <TKT_ID> memory/CHANGELOG.md` |
| `change` (CHG) | CHANGELOG.md entry with matching CHG-ID + code change in same git commit | `grep "CHG-XXXX" memory/CHANGELOG.md` + `git diff HEAD~1 --name-only` |
| `config` | Config file modified on disk + baseline updated in critical-config-baseline.json | `git diff HEAD~1 -- <config_path>` + `jq . state/critical-config-baseline.json` |

If ANY check fails: BLOCK close. Output exactly what's missing. Do not update status. Exit non-zero.

**Deliverable:** Updated `ticket.sh` with `verify_and_close()` function

**Acceptance Criteria:**
- [ ] AC1: Create test ticket TKT-TEST-1 (task type). Close without creating deliverable file → BLOCKED with "ERROR: Deliverable file [path] does not exist"
- [ ] AC2: Create test ticket TKT-TEST-2 (task type). Create file but don't git commit → BLOCKED with "ERROR: Deliverable file [path] not in git HEAD"
- [ ] AC3: Create test ticket TKT-TEST-3 (task type). Create file + git commit → PASSES verification, status set to closed
- [ ] AC4: Close a CHG-type ticket without CHANGELOG entry → BLOCKED with "ERROR: No CHANGELOG.md entry found for [CHG-ID]"
- [ ] AC5: Close a CHG-type ticket with CHANGELOG entry + code committed → PASSES
- [ ] AC6: Verify close still works for tickets WITHOUT a notionPageId (no Notion sync, local close only)
- [ ] AC7: All blocked closes leave ticket status UNCHANGED (still open/in-progress)
- [ ] AC8: Existing tickets without declared deliverable paths → skip file check, only validate CHANGELOG/git where applicable

### Story A2: DoD validation rules registry
**Owner:** Yoda | **Effort:** 1h

Create `docs/DoD-Validation-Rules.md` — the single source of truth for what "done" means per ticket type.

Must contain:
- **Section 1: Ticket Type Matrix** — table mapping each type (task/bug/change/config/incident) to required checks (file exists, git committed, changelog entry, config baseline updated, ticket linked, Notion archived)
- **Section 2: Deliverable Path Convention** — where deliverables live per type (`docs/` for documents, `scripts/` for scripts, `state/` for state files, `canvas/` for HTML output)
- **Section 3: Edge Cases** — what happens when: ticket has no file deliverable (e.g. research), ticket was hand-closed by Ken, deliverable is a DB migration (check Postgres not filesystem), deliverable is a Notion page (check Notion API, not local file)
- **Section 4: Override Protocol** — Ken can force-close with `--skip-verify` flag. Override is logged to CHANGELOG. Who can override: Ken only.
- **Section 5: SoT Mapping** — cross-reference to TKT-0197 SoT Register. Which SSOT confirms each check type.

**Deliverable:** `docs/DoD-Validation-Rules.md`

**Acceptance Criteria:**
- [ ] AC1: Document has all 5 sections listed above
- [ ] AC2: Matrix covers all 5 ticket types (task/bug/change/config/incident)
- [ ] AC3: Path convention section is specific — not "files go somewhere", but "docs/ for .md deliverables, scripts/ for .sh, etc."
- [ ] AC4: Edge cases section covers at minimum: research tickets, Ken hand-closes, DB migrations, Notion-only deliverables
- [ ] AC5: Override protocol section specifies: who (Ken), how (`--skip-verify`), audit trail (CHANGELOG)
- [ ] AC6: SoT Mapping section references specific data types from TKT-0197
- [ ] AC7: Document is git committed to `docs/DoD-Validation-Rules.md`
- [ ] AC8: RULES.md updated with reference to this document as non-negotiable DoD gate

### Story A3: Post-deliverable validation scheduler
**Owner:** Warden | **Effort:** 1h

A cron that re-checks closed tickets because the pre-close hook only runs once. Deliverables can be deleted, moved, or corrupted after close. This catches that.

**Script:** `scripts/dod-validator.sh`
- Reads `state/tickets.json` → finds all tickets with status=closed AND updated in last 24h
- For each closed ticket, re-runs the same checks from Story A1's `verify_before_close()`
- If a previously-passed check now fails → creates `state/dod-validation-alert.json`:
  ```json
  {
    "alerts": [{
      "ticketId": "TKT-XXXX",
      "failedCheck": "deliverable_file_missing",
      "expectedPath": "/Users/.../docs/whatever.md",
      "closedAt": "2026-05-22T10:00:00+10:00",
      "detectedAt": "2026-05-22T14:00:00+10:00",
      "acknowledged": false
    }]
  }
- Heartbeat reads this file → surfaces to Ken via Telegram with ticket ID, what's missing, when it was closed
- When deliverable is restored: alert auto-clears on next validator run
- When Ken acknowledges: mark `acknowledged: true` (alert stays for record, stops pinging)

**Cron:** Every 2 hours, aligned with heartbeat (e.g. xx:15). 30s timeout. Light context. Model: gemma4:31b-cloud (background, non-interactive).

**Deliverable:** `scripts/dod-validator.sh` + cron job + heartbeat integration

**Acceptance Criteria:**
- [ ] AC1: Close a ticket with valid deliverable → validator passes (no alert)
- [ ] AC2: Close a ticket, then `rm` the deliverable file → validator detects within 2h, alert JSON created
- [ ] AC3: Alert JSON contains all required fields: ticketId, failedCheck, expectedPath, closedAt, detectedAt, acknowledged
- [ ] AC4: Heartbeat picks up alert and sends Telegram message: "⚠️ DoD Validation failed: TKT-XXXX deliverable [path] missing. Closed [time]."
- [ ] AC5: Restore the deleted file → next validator run clears the alert
- [ ] AC6: Two tickets fail simultaneously → alert JSON has 2 entries, heartbeat reports both
- [ ] AC7: No stale alerts — items older than 7 days auto-purged regardless of acknowledged state
- [ ] AC8: Script handles missing tickets.json gracefully (file not found → output "ERROR: tickets.json not found", exit 1)

---

## STREAM B: 10-Rule Audit Engine (Warden, 4.5h)

### Story B1: Rule audit engine
**Owner:** Warden | **Effort:** 2h

`scripts/rule-audit.sh` — runs on Warden's existing 15-min cron cycle. Sweeps the platform for rule violations and outputs a structured JSON report.

Each rule has: a check function, a violation threshold, a severity (BLOCKER/WARNING/INFO), and a remediation hint.

| Rule | Check | How | Severity | Threshold |
|------|-------|-----|----------|-----------|
| **R01** Path Discipline | Any write or exec uses `~` instead of absolute path | Scan recent session transcripts for `~/.openclaw` in tool calls | BLOCKER | >0 |
| **R02** SoT Compliance | Agent reads/writes to canonical SSOT per SoT Register | Sample 10 recent reads against docs/Sources-of-Truth-Register.md | WARNING | >2 mismatches |
| **R03** Model Routing | Agent model matches assigned primary per Model3-Policy.md | Compare active agent models vs policy | BLOCKER | Any non-approved model |
| **R04** Template Adherence | Output format matches locked template (standup, journal, blog) | Diff check: does output structure match template structure? | WARNING | >1 drift |
| **R05** State Checking | Agent follows READ→VALIDATE→EXECUTE→VERIFY cycle | Check recent ticket closes: was state READ before action? Was output VERIFIED? | BLOCKER | >0 violations |
| **R06** ID Uniqueness | No duplicate TKT/CHG/INC IDs exist | Scan tickets.json + CHANGELOG.md for duplicate IDs | BLOCKER | >0 duplicates |
| **R07** Config Drift | openclaw.json matches critical-config-baseline.json | Diff known config fields against baseline | BLOCKER | Any unapproved drift |
| **R08** Content Governance | Triad gate (Shield/Lex/Sage) was run on external content | Check content-queue.json for CLEARED verdict on published items | BLOCKER | Any un-gated publish |
| **R09** Cron Health | No cron has >3 consecutive errors without alert | Scan cron state for consecutiveErrors >3 | BLOCKER | >3 consecutive |
| **R10** MEMORY Limits | MEMORY.md ≤ 16000 chars | `wc -c MEMORY.md` | WARNING | >16000 |

**Output per run:** `state/rule-audit-report.json`
```json
{
  "runAt": "ISO timestamp",
  "rules": {
    "R01": {"status": "PASS|FAIL|WARN", "violations": 0, "detail": "..."},
    ...
  },
  "summary": {
    "totalRules": 10,
    "passed": 8,
    "failed": 1,
    "warned": 1,
    "blockers": ["R01"]
  }
}
```

**Deliverable:** `scripts/rule-audit.sh`

**Acceptance Criteria:**
- [ ] AC1: Script runs end-to-end, outputs valid JSON with all 10 rules
- [ ] AC2: R01 catches at least 1 known tilde-path violation (today had 4)
- [ ] AC3: R03 catches the standup cron's kimi model assignment (pre-patch) as BLOCKER
- [ ] AC4: R06 catches if two tickets accidentally get same ID
- [ ] AC5: R09 catches the journal incremental cron (1b853131) with 4 consecutive errors
- [ ] AC6: R10 flags MEMORY.md if >16000 chars with WARNING severity
- [ ] AC7: Each rule has a `detail` field explaining what was checked and what was found
- [ ] AC8: Each rule has a `remediation` field hinting how to fix the violation
- [ ] AC9: Script runs in <30 seconds (lightweight, no heavy API calls)
- [ ] AC10: All BLOCKER violations create entries in state/rule-violations.json (separate from audit report, used for escalation)

### Story B2: Weekly audit HTML report
**Owner:** Warden | **Effort:** 1.5h

Generates a human-readable HTML canvas report from `rule-audit-report.json` history.

**Content:**
- **Hero section:** "Platform Compliance Score: 87%" (average of all rules across 7 days)
- **Compliance trend:** mini sparkline or bar chart showing weekly trend (Day 1→7)
- **Rule-by-rule breakdown table:**
  - Rule ID | Name | Status (PASS/FAIL/WARN) | Violations (7d) | Trend (↑↓→) | Remediation
- **Top 3 violations:** most frequent rule breaks with count and example
- **Blocker section:** any BLOCKER violations that need immediate Ken action
- **What improved:** rules that went from FAIL→PASS this week
- **What degraded:** rules that went from PASS→FAIL this week

**Style:** Follow locked standup canvas template (same CSS, .page wrapper, .section blocks, pill badges)

**Cron:** Monday 09:00 AEST. Model: deepseek-v4-pro (needs HTML generation capability).

**Delivery:** Telegram flash to Ken:
```
📊 Weekly Compliance — Week ending [date]
Score: 87% | 8 PASS · 1 FAIL · 1 WARN
🔴 [Blocker]: R01 Path Discipline — 4 tilde-path violations
🟢 Improved: R09 Cron Health (was 3, now 0)
📌 Full report → webchat embed
```

**Deliverable:** `scripts/rule-audit-report.sh` + `canvas/documents/rule-audit-weekly/index.html` + Monday 09:00 cron

**Acceptance Criteria:**
- [ ] AC1: Report HTML renders correctly — same CSS as standup template, mobile responsive
- [ ] AC2: All 10 rules present in table with status/pass/violations/trend
- [ ] AC3: Compliance score is a weighted average (BLOCKER violations = -10%, WARNING = -3%)
- [ ] AC4: Trend calculation uses 7-day history (compare current week to prior week where available)
- [ ] AC5: Top violations list shows actual examples from audit data (not generic text)
- [ ] AC6: Report auto-publishes to canvas/documents/rule-audit-weekly/index.html
- [ ] AC7: Telegram flash sent to Ken within 5 minutes of report generation
- [ ] AC8: First report can generate with only 1 day of data (graceful degradation — "insufficient data" for trends)
- [ ] AC9: Report is git committed
- [ ] AC10: If no audit data exists (state/rule-audit-report.json missing), output: "No audit data available for this period" — do not crash

---

## STREAM C: Task Queue Processor (Forge, 4h)

The DoD Gate (Stream A) catches lies at close time. The Task Queue Processor prevents the lies from being told in the first place.

The root cause of today's incidents is structural: agents (especially kimi/gemma4) execute work in linear sessions with memory context. They execute → write output → report "done" based on tool exit codes — never circling back to verify. The processor changes the execution model so verification is not optional.

### How It Works

```
TKT created → TQP picks up → Agent picks up atomic task → Agent executes (stateless)
→ Agent MUST verify output → TQP verifies → PASS (mark done) | FAIL (re-queue, max 3)
```

### Story C1: Task Queue Processor — async, stateless atomic execution
**Owner:** Forge | **Effort:** 4h

**Core principles:**
- **Atomic:** Each task is a single unit. One story = one task. No batch runs.
- **Stateless:** No session memory. Fresh start every time. Context from files only.
- **Verify-before-close:** The processor (not the agent) runs final verification via A1's function.
- **Re-queue on failure:** Max 3 retries, then escalate to Ken.

**Input:** `state/task-queue.json` — each entry: taskId, ticketId, story, type, promptFile, expectedDeliverable, status, retries, maxRetries, assignedModel, timestamps

**Dispatch:** `sessions_spawn` with prompt + "This is an ATOMIC task. Produce the deliverable. The platform will verify."

**Verification:** After sub-agent completes, run `verify_before_close()` from A1.
- PASS → status=done, verificationResult=passed
- FAIL → retries++. If < maxRetries: re-queue. If >= maxRetries: status=failed, alert Ken

**Cron:** 5-min interval via `scripts/task-queue-processor.sh`. Max 1 concurrent task.

**Deliverable:** `scripts/task-queue-processor.sh` + `state/task-queue.json` schema + cron

**Acceptance Criteria:**
- [ ] AC1: Add task to queue → processor picks up within 5 min → spawns → verifies → marks done
- [ ] AC2: Agent produces broken output → verification fails → re-queued with retries++
- [ ] AC3: 3 failures → status=failed, Telegram alert: "⚠️ TKT-XXXX failed 3 times. Manual intervention required."
- [ ] AC4: Two tasks queued → processor runs one at a time (no race conditions)
- [ ] AC5: Sub-agent timeout → mark as failed (counts as retry)
- [ ] AC6: `state/task-queue.json` uses atomic writes, valid JSON always
- [ ] AC7: `ticket.sh new --auto-execute` → auto-queues to task-queue.json
- [ ] AC8: Processor uses deepseek-v4-pro (no rate limits), fallback gemma4 for non-critical
- [ ] AC9: Queue metrics: depth, avg time, failure rate → `state/task-queue-metrics.json`
- [ ] AC10: Manual tasks (Ken→Yoda directly) bypass TQP — TQP only for explicitly queued tasks

---

## Dependencies
```
A1 (Pre-close hook) ──→ C1 (TQP uses A1's verify function)
                      ──→ A3 (Post-close validator uses A1's checks)
A2 (Rules registry) ──┘

B1 (Audit engine) ────→ B2 (Report needs B1's JSON output)

Stream A ∥ Stream B (parallel)
Stream C depends on A1 (needs verification function)
```

## Execution Order
1. **A1** (Yoda) + **B1** (Warden) — parallel, Day 1
2. **A2** (Yoda) + **C1** (Forge) — parallel, Day 2 (C1 needs A1 complete)
3. **A3** (Warden) + **B2** (Warden) — parallel, Day 3

## Risk: What Could Go Wrong
| Risk | Impact | Mitigation |
|------|--------|------------|
| A1 blocks legitimate closes | Sprint stall | `--skip-verify` flag for Ken override |
| B1 false positives flood alerts | Alert fatigue | BLOCKER alerts, WARNING logs only |
| A3 cron hits Ollama 429 | Silent failure | Use deepseek-v4-pro |
| A1 can't determine deliverable path | Close blocked | Skip if no declared path (A1.AC8) |
| Warden capacity clash | Race condition | B1 runs inside existing 15-min cron |
| TQP spawns too many sub-agents | Cost spike | Max 1 concurrent, 5-min interval |
| TQP infinite re-queue loop | Resource drain | Hard cap 3 retries, then escalate |
| Queue grows faster than processing | Backlog | Alert at >10 items → Telegram to Ken |

## DoD (Exit criteria for entire ticket)
- [ ] All 6 stories pass their individual ACs (A1, A2, A3, B1, B2, C1)
- [ ] `ticket.sh close` blocks when deliverable missing → verified with real test tickets
- [ ] `dod-validator.sh` fires Telegram alert within 2h of missing deliverable → verified end-to-end
- [ ] `task-queue-processor.sh` executes → verifies → marks done for at least 1 real task end-to-end
- [ ] `rule-audit.sh` catches at least 3 real violations on first run
- [ ] First weekly report generated and reviewed by Ken
- [ ] TKT-0240 runs TKT-0196/0197/0198/0182 through DoD gate + TQP → all 4 PASS
- [ ] Zero CHG-0401/0402-class incidents for 14 consecutive days
