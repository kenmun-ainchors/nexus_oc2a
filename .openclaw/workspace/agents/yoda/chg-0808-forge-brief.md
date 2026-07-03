# CHG-0808 Forge Execution Brief

**CHG:** CHG-0808 — Post-CHG-0806 platform hygiene  
**Type:** config / Routine  
**Owner:** Forge (infra)  
**Status:** Approved by Ken Mun  
**Date:** 2026-07-03  

---

## Pre-execution

1. Create the CHG record via canonical skill path:
   ```
   bash scripts/run-changelog.sh \
     --title "Post-CHG-0806 platform hygiene" \
     --type config \
     --source ken-prompt \
     --description "Re-baseline config hash after CHG-0806, fix health-state staleness, trim MEMORY.md, run sandbox-boundary audit, and clean related low-priority items." \
     --change-type Routine
   ```
2. Read `state/chg-0808-draft.json` for full scope.

---

## Execution atoms (do in order)

### Atom 1 — Re-baseline critical config hash
- File: `state/critical-config-baseline.json`
- Action: Recompute hashes for the current gateway config and cron payloads (post-CHG-0806) and update the baseline.
- Evidence: Show old hash, new hash, and a diff summary of what changed (expected: standup cron payload, weekly/monthly cron payloads, generate-mission-control.sh, audit-skill.sh).

### Atom 2 — Fix health-state.json staleness
- Files: `state/health-state.json`, `scripts/health-check.sh`, related cron payload.
- Action: Determine why `health-state.json` is 190min old and why obs shows `health_failure:1`. Fix the health-check cron or script. Re-run health-check to produce a fresh `state/health-state.json`.
- Evidence: Before/after timestamps, exit codes, any cron error logs.

### Atom 3 — Trim MEMORY.md
- Files: `MEMORY.md`, `memory/MEMORY-archive-2026-07-03.md`
- Action: Reduce `MEMORY.md` to ≤12,000 chars (soft limit). Move trimmed overflow to the archive file with a clear header.
- Evidence: Before/after byte counts.

### Atom 4 — Run sandbox-boundary audit
- Action: Execute the sandbox-boundary audit script (or equivalent). Update `state/sandbox-boundary-audit.json` (or create if missing).
- Evidence: Audit report summary, any findings.

### Atom 5 — Tidy untracked root .md files
- Files: `DREAMS.md`, `yoda-daily-brief.md`
- Action: Either move to appropriate subdir (`docs/`, `agents/yoda/`, or `archive/`) and register/update `state/file-contracts.json`, or delete if stale. Do not leave unregistered root .md files.
- Evidence: New paths, contract entries, or deletion confirmation.

### Atom 6 — Review cron timeout recommendations
- Action: Read auto-heal timeout recommendations. Apply only if safe and clearly justified. Prefer NOT to change timeoutSeconds unless evidence shows under/overrun.
- Evidence: List of recommendations and which were applied/skipped with reason.

### Atom 7 — Backup stale reconciliation
- Action: Check `state/backup-state.json`. Resolve discrepancy between `lastBackup` (2026-07-02 22:05Z) and `lastSnap` (`workspace-2026-07-03-0805`).
- Evidence: Which field is correct, whether the stale detector is miscalibrated.

### Atom 8 — L-102 env-wrapper and short :cloud cron timeouts
- Action: Evaluate only; report findings. Do not change gateway wrapper without explicit follow-up approval.
- Evidence: Current env state, which 2 crons have timeoutSeconds < 120, recommended values.

---

## Verification

- After Atom 1: `state/critical-config-baseline.json` hash matches current gateway config.
- After Atom 2: `state/health-state.json` timestamp is within 10 minutes of now and no `health_failure` obs events remain.
- After Atom 3: `wc -c MEMORY.md` ≤ 12,000; archive file exists and contains removed content.
- After Atom 4: Fresh sandbox-boundary audit report exists with timestamp.
- After Atom 5: No unregistered root .md files remain.
- After Atom 6-8: Report file `.openclaw/tmp/chg-0808-execution-report.md` documents decisions and evidence.

---

## Constraints

- Do NOT run the standup cron or send emails.
- Do NOT modify CHG-0806 changes.
- Do NOT delete files without confirming stale status.
- All script/infra/config edits are authorized under this CHG.
