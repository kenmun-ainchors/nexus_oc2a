#!/usr/bin/env zsh
# cron-timeout-apply.sh — One-shot apply of stable cron timeout recommendations
# TKT-0503-A6 follow-up: explicit, Ken-triggered, never implicit.
#
# Replaces the CHECK22_AUTO_APPLY=true env var path inside auto-heal.sh.
# auto-heal.sh only updates the ledger + surfaces NEEDS_KEN; this script
# is the *only* way to actually write timeoutSeconds to gateway config.
#
# Usage:
#   cron-timeout-apply.sh                  # dry-run: list eligible (7d+ stable DECREASE on agentTurn)
#   cron-timeout-apply.sh --cron <id>      # dry-run: show what would change for one cron
#   cron-timeout-apply.sh --all --yes      # apply ALL eligible (REQUIRES explicit --yes)
#   cron-timeout-apply.sh --cron <id> --yes  # apply one cron
#
# Exit codes:
#   0 = success (or dry-run completed)
#   1 = general error
#   2 = --yes required for live apply
#   3 = cron not eligible (not 7d stable, not agentTurn, not DECREASE, or already applied)
#   4 = openclaw cron edit failed
#   5 = ledger write failed
#
# Linked: TKT-0503-A6, L-099, CHG-0534

set -uo pipefail

SCRIPT_DIR_CTA="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="/Users/ainchorsangiefpl/.openclaw/workspace"
STATE_DIR="$WORKSPACE/state"
BASELINE_FILE="$STATE_DIR/cron-timeout-baseline.json"
LEDGER_FILE="$STATE_DIR/cron-timeout-applied.json"
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

CRON_FILTER=""   # if set, only act on this cronId prefix
APPLY_ALL=0
YES_FLAG=0
VERBOSE=0

usage() {
  cat <<'USAGE'
cron-timeout-apply.sh — one-shot apply of stable cron timeout DECREASEs

Usage:
  cron-timeout-apply.sh                     dry-run: list all eligible
  cron-timeout-apply.sh --cron <prefix>     dry-run: one cron (8-char prefix match)
  cron-timeout-apply.sh --all --yes         apply all eligible (requires --yes)
  cron-timeout-apply.sh --cron <p> --yes    apply one cron
  cron-timeout-apply.sh --verbose           show ledger + eligibility reasoning
  cron-timeout-apply.sh --cron <p> --yes --ken-bypass  apply one cron bypassing 7d stability
  cron-timeout-apply.sh --all --yes --ken-bypass       apply all eligible bypassing 7d stability

Without --yes, this is a dry-run. Live apply requires explicit --yes.
--ken-bypass bypasses the 7d stability check (L-099 safety net) for items
Ken has explicitly approved out-of-band (e.g. scaler vA6 backfill). Bypasses
are recorded in the ledger for audit. CHG-0578.

USAGE
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cron)  CRON_FILTER="$2"; shift 2 ;;
    --all)   APPLY_ALL=1; shift ;;
    --yes)   YES_FLAG=1; shift ;;
    --ken-bypass) KEN_BYPASS=1; shift ;;
    --verbose|-v) VERBOSE=1; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# KEN_BYPASS requires LIVE mode
if [[ "$KEN_BYPASS" -eq 1 ]] && [[ "$YES_FLAG" -ne 1 ]]; then
  echo "ERROR: --ken-bypass requires --yes (must be in live mode)" >&2
  exit 1
fi
if [[ "$KEN_BYPASS" -eq 1 ]] && [[ -z "$CRON_FILTER" ]] && [[ "$APPLY_ALL" -ne 1 ]]; then
  echo "ERROR: --ken-bypass requires --cron <prefix> or --all" >&2
  exit 2
fi

# Sanity: baseline + ledger
[[ ! -f "$BASELINE_FILE" ]] && { echo "ERROR: $BASELINE_FILE not found. Run cron-timeout-scaler.sh first." >&2; exit 1; }

# Mode: dry-run unless --yes
LIVE=0
if [[ "$YES_FLAG" -eq 1 ]]; then
  LIVE=1
fi

# Safety: --yes requires explicit scope (--cron or --all) to prevent accidental
# blanket applies. If --yes is given without either, exit 2.
if [[ "$LIVE" -eq 1 ]] && [[ -z "$CRON_FILTER" ]] && [[ "$APPLY_ALL" -ne 1 ]]; then
  echo "ERROR: --yes requires --cron <prefix> or --all (no implicit blanket apply)" >&2
  echo "  Use: cron-timeout-apply.sh --cron 2c855a3e --yes" >&2
  echo "  Or:  cron-timeout-apply.sh --all --yes" >&2
  exit 2
fi

# Compute eligibility in a single Python pass (no shell escaping pain)
APPLY_TMP=$(mktemp -t cta-apply)
python3 - "$BASELINE_FILE" "$LEDGER_FILE" "$NOW" "$CRON_FILTER" "$APPLY_ALL" "$LIVE" "$KEN_BYPASS" > "$APPLY_TMP" 2>&1 <<'PYEOF'
import json, sys, os, datetime, subprocess

baseline_file = sys.argv[1]
ledger_file = sys.argv[2]
now = sys.argv[3]
cron_filter = sys.argv[4]
apply_all = sys.argv[5] == '1'
live = sys.argv[6] == '1'
ken_bypass = sys.argv[7] == '1'

with open(baseline_file) as f:
    b = json.load(f)

ledger = {}
if os.path.exists(ledger_file):
    try:
        with open(ledger_file) as f:
            ledger = json.load(f)
    except Exception:
        ledger = {}

today = now[:10]
results = {
    'mode': 'LIVE' if live else 'DRY-RUN',
    'eligible': [],
    'notEligible': [],
    'alreadyApplied': [],
    'applied': [],
    'failed': [],
    'errors': [],
}

def is_eligible(r, ledger, today, ken_bypass=False):
    """Check DECREASE on agentTurn, not yet applied at computed value.

    7d stability check is the default (L-099 safety net).
    ken_bypass=True bypasses the 7d check (Ken explicit approval required).
    """
    cid = r.get('cronId', '')
    if r.get('payloadKind') != 'agentTurn':
        return False, 'not-agentTurn'
    if r.get('recommendation') != 'DECREASE':
        return False, 'not-DECREASE'
    cur = r.get('currentTimeoutSec')
    new = r.get('computedTimeoutSec')
    if cur is None or new is None or new >= cur:
        return False, 'no-positive-DECREASE'
    entry = ledger.get(cid, {})
    days = entry.get('daysCount', 0)
    if days < 7 and not ken_bypass:
        return False, f'stability-{days}d'
    applied_to = entry.get('appliedTo')
    if applied_to == new and entry.get('appliedAt'):
        return False, 'already-applied'
    bypass_note = '' if days >= 7 else f' [ken-bypass:{days}d]'
    return True, f'OK-{days}d-stable{bypass_note}'

# First pass: update ledger (same logic as auto-heal)
for r in b.get('crons', []):
    cid = r.get('cronId', '')
    if r.get('payloadKind') != 'agentTurn':
        continue
    if r.get('recommendation') != 'DECREASE':
        continue
    cur = r.get('currentTimeoutSec')
    new = r.get('computedTimeoutSec')
    if cur is None or new is None or new >= cur:
        continue
    entry = ledger.get(cid, {'firstSeen': today, 'lastSeen': None, 'daysCount': 0, 'recommendation': 'DECREASE', 'currentTo': cur, 'computedTo': new, 'appliedAt': None, 'appliedTo': None})
    is_first_today = (entry.get('lastSeen') != today)
    if is_first_today:
        last_date = entry.get('lastSeen', '')
        if last_date:
            try:
                last_dt = datetime.datetime.strptime(last_date, '%Y-%m-%d').date()
                today_dt = datetime.datetime.strptime(today, '%Y-%m-%d').date()
                if (today_dt - last_dt).days == 1:
                    entry['daysCount'] = entry.get('daysCount', 0) + 1
                else:
                    entry['firstSeen'] = today
                    entry['daysCount'] = 1
            except Exception:
                entry['firstSeen'] = today
                entry['daysCount'] = 1
        else:
            entry['daysCount'] = entry.get('daysCount', 0) + 1
        entry['lastSeen'] = today
    entry['recommendation'] = 'DECREASE'
    entry['currentTo'] = cur
    entry['computedTo'] = new
    ledger[cid] = entry

# Reconciliation: prune ledger entries whose cron is no longer in the
# baseline (scaler re-ran, recompute cleared the recommendation).
cid_set = {r.get('cronId', '') for r in b.get('crons', [])}
stale_cids = [cid for cid in list(ledger.keys()) if cid not in cid_set]
for cid in stale_cids:
    del ledger[cid]

# Second pass: apply or surface
for r in b.get('crons', []):
    cid = r.get('cronId', '')
    if cron_filter and not cid.startswith(cron_filter):
        continue
    eligible, reason = is_eligible(r, ledger, today, ken_bypass=ken_bypass)
    base = {
        'cronId': cid,
        'name': r.get('name', '')[:50],
        'currentTimeoutSec': r.get('currentTimeoutSec'),
        'computedTimeoutSec': r.get('computedTimeoutSec'),
        'payloadKind': r.get('payloadKind'),
        'recommendation': r.get('recommendation'),
        'daysCount': ledger.get(cid, {}).get('daysCount', 0),
    }
    if not eligible:
        if reason == 'already-applied':
            results['alreadyApplied'].append({**base, 'appliedAt': ledger.get(cid, {}).get('appliedAt')})
        else:
            results['notEligible'].append({**base, 'reason': reason})
        continue
    results['eligible'].append(base)
    if live:
        # Apply via openclaw cron edit
        full_id = r.get('fullCronId', '')
        new = r.get('computedTimeoutSec')
        try:
            proc = subprocess.run(
                ['/opt/homebrew/bin/openclaw', 'cron', 'edit', full_id, '--timeout-seconds', str(new)],
                capture_output=True, text=True, timeout=10
            )
            if proc.returncode == 0:
                ledger[cid]['appliedAt'] = now
                ledger[cid]['appliedTo'] = new
                ledger[cid]['applyMethod'] = 'cron-timeout-apply.sh'
                ledger[cid]['applyResult'] = (proc.stdout or '')[:200]
                if ken_bypass:
                    ledger[cid]['kenBypass'] = True
                    ledger[cid]['kenBypassAt'] = now
                    ledger[cid]['kenBypassReason'] = 'Ken explicit approval for scaler vA6 backfill (CHG-0578)'
                results['applied'].append({**base, 'appliedAt': now})
            else:
                results['failed'].append({**base, 'reason': f'rc={proc.returncode}', 'stderr': (proc.stderr or '')[:200]})
        except subprocess.TimeoutExpired:
            results['failed'].append({**base, 'reason': 'cli-timeout'})
        except Exception as e:
            results['failed'].append({**base, 'reason': f'{type(e).__name__}: {e}'})

# Write ledger
try:
    with open(ledger_file, 'w') as f:
        json.dump(ledger, f, indent=2, ensure_ascii=False)
except Exception as e:
    results['errors'].append(f'ledger-write-failed: {e}')

print(json.dumps(results, indent=2, ensure_ascii=False))
PYEOF
APPLY_RC=$?
RESULTS=$(cat "$APPLY_TMP")
rm -f "$APPLY_TMP"

if [[ $APPLY_RC -ne 0 ]]; then
  echo "ERROR: Python evaluation failed" >&2
  echo "$RESULTS" >&2
  exit 1
fi

# Render results as human-readable + extract counts
MODE=$(echo "$RESULTS" | python3 -c "import json, sys; print(json.loads(sys.stdin.read())['mode'])")
ELIG_N=$(echo "$RESULTS" | python3 -c "import json, sys; print(len(json.loads(sys.stdin.read())['eligible']))")
APPLIED_N=$(echo "$RESULTS" | python3 -c "import json, sys; print(len(json.loads(sys.stdin.read())['applied']))")
FAILED_N=$(echo "$RESULTS" | python3 -c "import json, sys; print(len(json.loads(sys.stdin.read())['failed']))")
ALREADY_N=$(echo "$RESULTS" | python3 -c "import json, sys; print(len(json.loads(sys.stdin.read())['alreadyApplied']))")
NOT_N=$(echo "$RESULTS" | python3 -c "import json, sys; print(len(json.loads(sys.stdin.read())['notEligible']))")

echo "=== cron-timeout-apply.sh — $MODE ==="
echo ""
if [[ "$ELIG_N" -gt 0 ]]; then
  echo "Eligible for apply (7d+ stable DECREASE on agentTurn):"
  echo "$RESULTS" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
for e in d['eligible']:
    print(f\"  {e['cronId']} {e['name']:50s} {e['currentTimeoutSec']}s -> {e['computedTimeoutSec']}s ({e['daysCount']}d stable)\")"
  echo ""
fi
if [[ "$ALREADY_N" -gt 0 ]]; then
  echo "Already applied (skipped):"
  echo "$RESULTS" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
for e in d['alreadyApplied']:
    print(f\"  {e['cronId']} {e['name']:50s} -> {e['computedTimeoutSec']}s (applied {e.get('appliedAt','?')[:10]})\")"
  echo ""
fi
if [[ "$NOT_N" -gt 0 ]] && [[ $VERBOSE -eq 1 ]]; then
  echo "Not eligible (verbose):"
  echo "$RESULTS" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
for e in d['notEligible']:
    print(f\"  {e['cronId']} {e['name']:50s} rec={e['recommendation']} days={e['daysCount']} -> {e['reason']}\")"
  echo ""
fi
if [[ "$APPLIED_N" -gt 0 ]]; then
  echo "✅ APPLIED ($APPLIED_N):"
  echo "$RESULTS" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
for e in d['applied']:
    print(f\"  {e['cronId']} {e['name']:50s} {e['currentTimeoutSec']}s -> {e['computedTimeoutSec']}s\")"
  echo ""
fi
if [[ "$FAILED_N" -gt 0 ]]; then
  echo "❌ FAILED ($FAILED_N):"
  echo "$RESULTS" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
for e in d['failed']:
    print(f\"  {e['cronId']} {e['name']:50s} reason={e.get('reason','?')} stderr={e.get('stderr','')[:80]}\")"
  echo ""
fi

# Exit code logic
if [[ $LIVE -eq 1 ]]; then
  if [[ $APPLIED_N -gt 0 ]] && [[ $FAILED_N -eq 0 ]]; then
    exit 0
  elif [[ $APPLIED_N -gt 0 ]] && [[ $FAILED_N -gt 0 ]]; then
    exit 4  # partial
  elif [[ $APPLIED_N -eq 0 ]] && [[ $FAILED_N -gt 0 ]]; then
    exit 4
  elif [[ $ELIG_N -eq 0 ]] && [[ $ALREADY_N -gt 0 ]]; then
    echo "(All eligible already applied.)"
    exit 0
  else
    echo "ERROR: --yes given but no eligible items (filter='$CRON_FILTER', all=$APPLY_ALL)" >&2
    exit 3
  fi
else
  # Dry-run summary
  if [[ $ELIG_N -gt 0 ]]; then
    echo "Dry-run complete. To apply:"
    if [[ -n "$CRON_FILTER" ]]; then
      echo "  cron-timeout-apply.sh --cron $CRON_FILTER --yes"
    else
      echo "  cron-timeout-apply.sh --all --yes"
    fi
    exit 0
  else
    echo "No eligible items. (Either nothing's been stable 7d+, or everything is already applied.)"
    exit 0
  fi
fi
