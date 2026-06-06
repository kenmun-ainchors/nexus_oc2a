#!/usr/bin/env zsh
# framework-audit.sh — AInchors Framework Alignment Audit
# Checks today's CHG entries for frameworkDocs fields and verifies the listed
# framework documents were actually updated. Flags any gaps.
#
# Usage: zsh scripts/framework-audit.sh [--date YYYY-MM-DD] [--verbose]
# Output: state/framework-audit-state.json
# Exit: 0=clean, 1=gaps found (but non-fatal)

set -uo pipefail

WORKSPACE="${0:A:h:h}"
CHANGELOG="$WORKSPACE/memory/CHANGELOG.md"
REGISTRY="$WORKSPACE/state/framework-registry.json"
AUDIT_STATE="$WORKSPACE/state/framework-audit-state.json"
LOG="$HOME/Backups/ainchors/logs/framework-audit.log"

mkdir -p "$(dirname $LOG)"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [FRAMEWORK-AUDIT] $1" | tee -a "$LOG"; }

TARGET_DATE="${1:-}"
VERBOSE=false
while (( $# > 0 )); do
  case "$1" in
    --date)    TARGET_DATE="$2"; shift 2 ;;
    --verbose) VERBOSE=true; shift ;;
    *) shift ;;
  esac
done

TODAY=$(date '+%Y-%m-%d')
CHECK_DATE="${TARGET_DATE:-$TODAY}"

log "=== Framework Alignment Audit — $CHECK_DATE ==="

python3 - "$CHECK_DATE" "$CHANGELOG" "$REGISTRY" "$AUDIT_STATE" "$VERBOSE" << 'PYEOF'
import sys, json, re, os
from datetime import datetime, timezone
from pathlib import Path

check_date = sys.argv[1]
changelog_path = sys.argv[2]
registry_path = sys.argv[3]
audit_state_path = sys.argv[4]
verbose = sys.argv[5].lower() == "true"

home = Path.home()

def expand(p):
    return Path(str(p).replace("~", str(home)))

# Load registry
registry = json.load(open(registry_path)) if Path(registry_path).exists() else {"registry": {}}

# Parse CHANGELOG.md for today's CHG entries with frameworkDocs
changelog = open(changelog_path).read() if Path(changelog_path).exists() else ""

# Find all CHG blocks for today
# Pattern: ## YYYY-MM-DD ... [CHG-NNNN] ... up to next ---
chg_blocks = re.findall(
    r'## (' + re.escape(check_date) + r'[^\n]*?)\[([A-Z]+-\d+)\](.*?)(?=^---$|\Z)',
    changelog, re.MULTILINE | re.DOTALL
)

gaps = []
checked = []
all_framework_docs = set()

# Also scan for **Framework docs:** lines in any CHG block from today
framework_doc_refs = re.findall(
    r'\*\*Framework docs:\*\*\s*([^\n]+)',
    changelog
)

# Collect all referenced framework docs from today's CHGs
referenced_docs = []
for ref_line in framework_doc_refs:
    docs = [d.strip() for d in ref_line.split(",") if d.strip()]
    referenced_docs.extend(docs)

# Also check registry categories for CHG types mentioned today
# Scan for **Category:** lines near today's date blocks
category_refs = re.findall(
    r'\*\*Category:\*\*\s*([^\n]+)',
    changelog
)

# Resolve docs from registry
registry_docs = set()
for cat in category_refs:
    cat_key = cat.strip().lower().replace(" ", "-")
    if cat_key in registry.get("registry", {}):
        for doc in registry["registry"][cat_key].get("frameworks", []):
            registry_docs.add(str(expand(doc)))

# Combine: explicit frameworkDocs refs + registry-derived docs
all_docs_to_check = set()
for doc in referenced_docs:
    all_docs_to_check.add(str(expand(doc.strip())))
all_docs_to_check.update(registry_docs)

# Check each doc: was it modified today?
today_epoch_start = datetime.strptime(check_date, "%Y-%m-%d").replace(tzinfo=timezone.utc).timestamp()
today_epoch_end = today_epoch_start + 86400

for doc_path_str in sorted(all_docs_to_check):
    doc_path = Path(doc_path_str)
    if not doc_path.exists():
        if verbose:
            print(f"  SKIP (not found): {doc_path_str}")
        continue

    mtime = doc_path.stat().st_mtime
    updated_today = today_epoch_start <= mtime < today_epoch_end

    entry = {
        "path": doc_path_str,
        "exists": True,
        "updatedToday": updated_today,
        "lastModified": datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M AEST")
    }
    checked.append(entry)

    if not updated_today:
        gaps.append(entry)
        print(f"  GAP: {doc_path.name} — last modified {entry['lastModified']} (not updated today)")
    elif verbose:
        print(f"  OK:  {doc_path.name} — updated today")

# Write audit state
state = {
    "schema": "framework-audit-v1",
    "lastRun": datetime.now(timezone.utc).isoformat(),
    "checkDate": check_date,
    "docsChecked": len(checked),
    "gapsFound": len(gaps),
    "gaps": gaps,
    "checked": checked,
    "status": "gaps" if gaps else "clean"
}
json.dump(state, open(audit_state_path, "w"), indent=2)

# ── PG WRITE: state_frameworks — update last_audited for each checked doc ──
import subprocess as _sp
db_sh = os.path.join(os.environ.get("WORKSPACE", str(Path.home() / ".openclaw/workspace")), "scripts", "db.sh")
for entry in checked:
    rel_path = str(Path(entry["path"]).relative_to(Path.home() / ".openclaw/workspace")) if str(Path.home() / ".openclaw/workspace") in entry["path"] else entry["path"]
    result = "current" if entry["updatedToday"] else "stale"
    _sp.run(["bash", db_sh, "-c",
        f"UPDATE state_frameworks SET last_audited = NOW(), audit_result = '{result}' WHERE file_path = '{rel_path}'"],
        capture_output=True)

if gaps:
    print(f"\nFRAMEWORK AUDIT: {len(gaps)} gap(s) found — framework docs referenced in CHGs but not updated today.")
    print("Run: cat state/framework-audit-state.json for details.")
    sys.exit(1)
else:
    print(f"FRAMEWORK AUDIT: Clean — {len(checked)} doc(s) checked, all up to date.")
    sys.exit(0)
PYEOF

EXIT=$?
log "Audit complete. Exit: $EXIT"
exit $EXIT
