# TKT-0529 — Deep-Groomed Audit Brief

## What changed since A6
I re-read all 5 scripts and verified the line numbers from the subagent reports. Some findings need correction/clarification.

## Verified Per-Script Findings

### 1. `scripts/auto-heal.sh` — HIGH (confirmed)
- **Lines:** ~2,980 (subagent undercounted; file is larger than 1,376)
- **set flags (line 8):** `set -u` only. Explicitly avoids `-e` so checks keep going.
- **Hardcoded paths (7 instances):**
  - line 10: `WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"`
  - line 580: `WORKSPACE_ROOT="/Users/ainchorsoc2a/.openclaw/workspace"`
  - line 1299: hardcoded SOUL.md/AGENTS.md/MEMORY.md/HEARTBEAT.md list
  - line 2505: `AUDIT_OUTFILE="/Users/ainchorsoc2a/.openclaw/workspace/state/..."`
  - line 2631: hardcoded `cron-write.sh` path in pipe
  - line 2668: `BOUNDARY_TESTFILE="/Users/ainchorsoc2a/.openclaw/test-boundary-write"`
  - line 2900: `SANDBOX_PLIST="/Users/ainchorsoc2a/Library/LaunchAgents/..."`
- **Destructive operations that run unattended:**
  - line 266: `rm -rf "$d"` — stale plugin runtime deps
  - line 299: `rm -f "$lock"` — stale session locks
  - line 665: `SELECT setval(...)` — auto-fixes PG sequences
  - line 714: `kill -9 "$pid"` — orphaned gateway processes
  - lines 1287, 1292, 1302, 2794: `mv` rewrites of user files (context summarization, daily brief archive)
- **Dry-run / HITL:** `--dry-run` exists (line 24) but only gates some enforcement; auto-heal still performs `rm`, `kill`, `setval`, and file rewrites when not in dry-run. No explicit `--yes` requirement.
- **Skill-gate:** None of the helper scripts it calls (`changelog-append.sh`, `check-delegated-auth.sh`, `agent-identity-audit.sh`, `agent-rules-audit.sh`, `db-raw.sh`, `safe-path.sh`, `file-size-guard.sh`, `context-budget.sh`, `context-summarize.sh`, `cron-timeout-apply.sh`, `long-id-stub-check.sh`) are invoked through skill-load wrappers or skill-gate.
- **Concurrency:** No lockfile. Cron runs auto-heal. Stale lock cleanup can race with active sessions.

**Deep-groom verdict:** `auto-heal.sh` is the only script with real destructive auto-execution. It needs the most careful remediation.

### 2. `scripts/state-health-assert.sh` — MEDIUM (confirmed)
- **Lines:** 210
- **set flags (line 5):** `set -u` only.
- **Hardcoded path (line 7):** `WORKSPACE="/Users/ainchorsoc2a/.openclaw/workspace"`
- **State writes (lines 201, 210):** `cat > "$BLOCK_FILE"` and `cat > "$ASSERT_FILE"`
- **Destructive ops:** None.
- **Risk:** Corrupted state files if writes are interrupted; brittle on other hosts.

### 3. `scripts/ollama-quota-track.sh` — MEDIUM (confirmed)
- **Lines:** 156
- **set flags:** `set -euo pipefail` present (line 9) — subagent report was correct.
- **Hardcoded paths (lines 10, 37, 136):**
  - line 10: `WORKSPACE="${WORKSPACE:-/Users/ainchorsoc2a/.openclaw/workspace}"`
  - line 37: Python `open('/Users/ainchorsoc2a/.openclaw/workspace/state/cron-list-snapshot.json')`
  - line 136: Python `open('/Users/ainchorsoc2a/.openclaw/workspace/state/cron-ollama-usage.json', 'w')`
- **State writes:** Lines 136 (usage JSON), 149 (cooldown epoch).
- **Destructive ops:** None.
- **Risk:** Non-atomic writes; JSON instead of PG; missing `--dry-run`.

### 4. `scripts/cron-migration-advisor.sh` — MEDIUM (confirmed)
- **Lines:** 157
- **set flags:** `set -euo pipefail` present (line 9) — subagent report was correct.
- **Hardcoded paths (lines 11, 42, 43, 139):** same pattern as quota tracker.
- **State writes:** Lines 139 (suggestions JSON), 154 (cooldown epoch).
- **Destructive ops:** None (advisory only).
- **Risk:** Non-atomic writes; no lockfile; JSON instead of PG.

### 5. `scripts/check-cooldown-gate.sh` — LOW-MEDIUM (confirmed)
- **Lines:** 185
- **set flags (line 19):** `set -u` only.
- **Hardcoded path (line 20):** `WORKSPACE="${WORKSPACE:-/Users/ainchorsoc2a/.openclaw/workspace}"`
- **State write (lines 175-176):** Python `with open(output_path, 'w')` — single JSON dump.
- **Destructive ops:** None.
- **Risk:** Low. Mainly path portability and wrapper error handling.

## Corrected Risk Matrix

| Finding | Scripts | Risk | Effort | Priority | Verified Lines |
|---|---|---|---|---|---|
| Auto-destructive ops without HITL | auto-heal.sh | **CRITICAL** | medium | 1 | 266, 299, 665, 714, 1287-1302 |
| Non-atomic state writes | auto-heal, state-health, quota, migration-advisor | **HIGH** | low | 2 | 52, 97, 201, 210, 136, 139, 175 |
| Hardcoded paths | all 5 | **HIGH** | low | 3 | 10, 20, 580, 1299, 2505, 2631, 2668, 2900 |
| Missing `set -euo pipefail` | auto-heal, state-health, cooldown-gate | **HIGH** | low | 4 | 8, 5, 19 |
| No lockfile / concurrency gap | auto-heal, migration-advisor | **MEDIUM** | low | 5 | 293-299 |
| No `--dry-run` | quota, migration-advisor | **MEDIUM** | low | 6 | N/A |
| JSON as de-facto SSOT | quota, migration-advisor | **MEDIUM** | medium | 7 | 37, 42-43 |
| Helper scripts bypass skill-gate | auto-heal.sh | **MEDIUM** | medium | 8 | 18, 152, 535, 569, 659, 758, 901, 1110, 1233, 1417 |
| Python exit code unchecked | cooldown-gate | **LOW** | low | 9 | end of script |

## A7 Execution Options

### Option A — Full sequential remediation (recommended)
Fix all findings across all 5 scripts in 4 bundles:
1. **Hygiene bundle:** `set -euo pipefail` + hardcoded-path removal (all 5)
2. **Atomic-write bundle:** atomic-write helper + conversion (4 scripts)
3. **auto-heal safety bundle:** HITL gate, lockfile, skill-gate wiring, dry-run hardening
4. **SSOT / dry-run bundle:** PG-first reads, `--dry-run` flags, lockfile for migration-advisor

### Option B — Blocker-only remediation
Fix only critical/high findings:
1. HITL gate + dry-run hardening on auto-heal.sh
2. Atomic writes on auto-heal + state-health
3. Hardcoded paths on all 5

Leave lockfiles, skill-gate wiring, and PG SSOT migration for follow-up tickets.

### Option C — Per-script tickets
Create sub-tickets for each script. Slower, more overhead, but isolates risk.

## Trade-offs
| Option | Time | Risk | P2 Readiness | Scope Creep |
|---|---|---|---|---|
| A | ~2-3 sessions | medium (touches 5 live scripts) | high | moderate |
| B | ~1 session | low | partial | low |
| C | ~1 week | low | delayed | high overhead |

## My Recommendation
**Option A** but execute in small bundles with per-bundle HITL. Start with hygiene (lowest risk, highest leverage). Do **not** run auto-heal safety bundle until we have a dry-run regression test that passes.

## What I need from you
1. Approve Option A or choose B/C.
2. Confirm whether `auto-heal.sh` should continue to auto-kill orphan gateways and auto-fix PG sequences, or whether those should become `--yes`-gated / NEEDS_KEN only.
3. Should the atomic-write helper live in `scripts/lib/atomic-write.sh` (new shared lib) or be inlined per script?
