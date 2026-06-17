# TKT-0529 Verifier Corpus — Old-Code Audit of 5 High-Risk Live Scripts

## Scope
Audit these five production scripts against the static profile checklist below:

1. `scripts/auto-heal.sh`
2. `scripts/state-health-assert.sh`
3. `scripts/ollama-quota-track.sh`
4. `scripts/cron-migration-advisor.sh`
5. `scripts/check-cooldown-gate.sh`

## Static Profile Checklist

For each script, report PASS/FAIL/NA for every item. A FAIL must include:
- Line number(s) or function name
- Concrete defect description
- Risk rating: critical / high / medium / low
- Suggested remediation

### 1. Skill-Gate Compliance
- [ ] Script does not directly invoke another domain script without first loading its skill.
- [ ] If the script is a domain script itself, it calls `skill-gate.sh` at entry (where applicable).
- [ ] No hardcoded references to deprecated scripts (e.g. `scripts/ticket.sh`).

### 2. Atomic Writes & Rollback
- [ ] Any state-modifying write uses an atomic pattern (temp file + mv, or PG transaction).
- [ ] A rollback path is documented or implementable for each destructive change.
- [ ] No in-place overwrite of critical state files without backup.

### 3. Hardcoded Paths / Secrets
- [ ] No absolute user paths that break on other hosts (e.g. `/Users/ainchorsangiefpl/...` without `$HOME` fallback).
- [ ] No embedded secrets, tokens, or credentials.
- [ ] `$WORKSPACE_ROOT` and other env vars are used consistently.

### 4. HITL Gates for Destructive Operations
- [ ] Any operation that deletes, modifies config, restarts services, or changes PG state requires explicit human approval or is wrapped in a dry-run gate.
- [ ] Auto-executed destructive operations are flagged as critical findings.

### 5. Idempotency & Dry-Run Mode
- [ ] Script can be run repeatedly without harm (idempotent).
- [ ] A `--dry-run` or equivalent exists, or destructive sections are clearly isolated.

### 6. Error Handling & Fail-Safe Defaults
- [ ] `set -euo pipefail` or equivalent error handling is present.
- [ ] Failures do not silently continue.
- [ ] Variables are initialized with safe defaults.

### 7. Logging / Audit Trail
- [ ] Operations are logged with timestamps.
- [ ] Logs include sufficient context for post-incident tracing.
- [ ] No debug output that leaks sensitive data.

### 8. Cron / Auto-Heal Safety
- [ ] If run by cron or auto-heal, it respects quiet-hours or active-hours policy.
- [ ] It has timeout/loop guards to prevent runaway execution.
- [ ] Lockfile or singleton behavior prevents concurrent runs.

### 9. PG SSOT vs Stale JSON Fallback
- [ ] State reads prefer PG over local JSON when PG is canonical.
- [ ] JSON fallbacks (if any) are documented and do not override PG truth.

### 10. CREST v1.2+ / TQP Alignment
- [ ] Script does not perform multi-step reasoning without verification.
- [ ] Script does not modify workspace without a ticket/CHG record.
- [ ] Script respects the 2-Pass Contract where applicable.

## Reporting Template

For each script, return exactly this structure:

```
## Script: <filename>

### Summary
- Lines of code: <N>
- Risk rating: critical/high/medium/low
- Top 3 findings: <bullets>

### Checklist Results
| Check | Status | Evidence | Risk | Remediation |
|-------|--------|----------|------|-------------|
| 1.1 | PASS/FAIL/NA | ... | ... | ... |
...

### Blockers
<list anything that must be fixed before P2>

### Recommended Remediation Order
<ranked list>
```

## Subagent Control Rules
- Read-only assessment. Do not modify any file.
- Maximum 25 tool calls total.
- Cite line numbers and function names for every FAIL.
- Stop if a script exceeds your analysis budget; report partial findings and move on.
