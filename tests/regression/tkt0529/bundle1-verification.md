# TKT-0529 A7 Bundle 1 Verification

## Changes Applied
1. Created shared atomic-write helper: `scripts/lib/atomic-write.sh`
2. Added `set -euo pipefail` to:
   - `scripts/auto-heal.sh`
   - `scripts/state-health-assert.sh`
   - `scripts/check-cooldown-gate.sh`
3. Replaced hardcoded `/Users/ainchorsangiefpl/.openclaw/workspace` with `${WORKSPACE_ROOT:-$HOME/.openclaw/workspace}` in shell portions of all 5 scripts.

## Syntax Checks
| Script | Result |
|---|---|
| auto-heal.sh | zsh syntax OK |
| state-health-assert.sh | bash syntax OK |
| ollama-quota-track.sh | zsh syntax OK |
| cron-migration-advisor.sh | bash syntax OK |
| check-cooldown-gate.sh | bash syntax OK |

## Hardcoded Path Counts
| Script | Remaining `/Users/ainchorsangiefpl/` | Notes |
|---|---|---|
| auto-heal.sh | 0 | fully converted |
| state-health-assert.sh | 0 | fully converted |
| ollama-quota-track.sh | 2 | inside Python HEREDOC only — Bundle 4 |
| cron-migration-advisor.sh | 3 | inside Python HEREDOC only — Bundle 4 |
| check-cooldown-gate.sh | 0 | fully converted |

## set flags
| Script | Flag |
|---|---|
| auto-heal.sh | `set -euo pipefail` |
| state-health-assert.sh | `set -euo pipefail` |
| ollama-quota-track.sh | `set -euo pipefail` |
| cron-migration-advisor.sh | `set -euo pipefail` |
| check-cooldown-gate.sh | `set -euo pipefail` |

## Atomic-Write Helper Tests
- `atomic_write`: PASS
- `atomic_write_file`: PASS
- `zsh -n scripts/lib/atomic-write.sh`: OK

## Script Run Tests (post-Bundle-1)
| Script | Invocation | Result |
|---|---|---|
| auto-heal.sh | `bash scripts/auto-heal.sh --dry-run` | exit 0, completed all 38 checks |
| state-health-assert.sh | `bash -n` syntax check | OK |
| ollama-quota-track.sh | `bash scripts/ollama-quota-track.sh` | exit 0 (cooldown skipped) |
| cron-migration-advisor.sh | `bash scripts/cron-migration-advisor.sh` | exit 0 (cooldown skipped) |
| check-cooldown-gate.sh | `bash scripts/check-cooldown-gate.sh` | exit 0, 0 findings |

## Notes
- Python HEREDOC path fixes deferred to Bundle 4 (SSOT migration / dry-run) because they require passing `${WORKSPACE}` to Python via env/sys.argv and may be replaced by PG-first reads.
- `auto-heal.sh` intentionally preserves per-check `|| true` and `|| log` patterns to keep the legacy keep-going behavior inside individual checks, while the outer script now fails fast on real errors.
- `check-cooldown-gate.sh` bash wrapper still needs explicit Python exit-code check (Bundle 2 or 3).
- One `set -euo pipefail` compatibility fix applied to `auto-heal.sh`: `ACTIVE_GW_PID=$(pgrep ... | head -1 || true)`.
