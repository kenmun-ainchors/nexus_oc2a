#!/bin/bash
# check-pipefail-trap.sh — Static analyzer for the L-138 bug class.
# Detects `set -o pipefail` + `trap ... ERR` + ungated `$(...)` checker
# invocations, `awk | head` SIGPIPE patterns, `tr '\n' ' '` in process
# substitution, and `read -r ... < <(cmd)` with multi-line pipelines.
#
# The bug: under `set -o pipefail` + `trap ... ERR`, a non-zero exit from
# any pipeline stage (e.g., head closing early, tr exiting 1 on no trailing
# newline, a checker returning 1) fires the ERR trap, crashing the script.
#
# L-126, L-131, L-132, L-137 all hit this. Anti-regression checker.
#
# Output: state/pipefail-trap-findings.json
# Prints: PIPEFAIL_TRAP_FINDINGS: N
#         HIGH: N
#         MEDIUM: N
# Exit: 0 if 0 findings, 1 if any.
#
# Defense-in-depth: pairs with CHECK 35 in auto-heal.
# Pattern: see LESSONS.md L-138.

set -u
WORKSPACE="${WORKSPACE:-/Users/ainchorsangiefpl/.openclaw/workspace}"
SCRIPTS_DIR="$WORKSPACE/scripts"
OUTPUT="$WORKSPACE/state/pipefail-trap-findings.json"

# Scope: only .sh in scripts/, exclude backups
# Note: macOS ships bash 3.2 which lacks `mapfile`. Use a while-read loop for portability.
TARGETS=()
# L-138 v2: support SCRIPTS_TO_SCAN for synthetic test corpus
if [[ -n "${SCRIPTS_TO_SCAN:-}" ]]; then
  # Read space/newline-separated list
  for f in $SCRIPTS_TO_SCAN; do
    TARGETS+=("$f")
  done
else
  # Default: scan scripts/*.sh
  while IFS= read -r f; do
    TARGETS+=("$f")
  done < <(find "$SCRIPTS_DIR" -maxdepth 1 -name "*.sh" -type f ! -name "*.bak" ! -name "*.backup" ! -path "*_test_l138*" 2>/dev/null | sort)
fi

# Build a list of script basenames for the Python parser
SCRIPT_LIST=$(printf "%s\n" "${TARGETS[@]}" | xargs -I {} basename {} | tr '\n' ':' | sed 's/:$//')
PARENT_DIRS=$(printf "%s\n" "${TARGETS[@]}" | xargs -I {} dirname {} | sort -u | tr '\n' ':' | sed 's/:$//')

# L-138 v2: If SCRIPTS_TO_SCAN is set, combine all parent dirs for lookups
if [[ -n "${SCRIPTS_TO_SCAN:-}" ]]; then
  SCRIPTS_DIR_COMBINED="${SCRIPTS_DIR}:${PARENT_DIRS}"
else
  SCRIPTS_DIR_COMBINED="${SCRIPTS_DIR}"
fi

python3 - "$SCRIPTS_DIR_COMBINED" "$OUTPUT" "$SCRIPT_LIST" <<'PYEOF'
import json, os, re, sys, datetime

scripts_dir = sys.argv[1]
output_path = sys.argv[2]
script_list_str = sys.argv[3]
script_names = [s for s in script_list_str.split(':') if s]
script_parent_dirs = scripts_dir.split(':')  # L-138 v2: support multiple parent dirs

# L-138 v2: given a basename, find the file in our search dirs
def resolve_script_path(basename, search_dirs):
    for d in search_dirs:
        p = os.path.join(d, basename)
        if os.path.exists(p):
            return p
    # Fallback: just use first dir
    return os.path.join(search_dirs[0], basename)

# Regex patterns
# 1. set -o pipefail (actual command, not comment)
# FIX: support combined flags (e.g., 'set -uo pipefail', 'set -eo pipefail')
PIPEFAIL_RE = re.compile(r'^\s*set\s+[-+][a-z]*o\s+pipefail\b')
# 2. trap ... ERR (actual command, not comment)
TRAP_ERR_RE = re.compile(r'^\s*trap\s+.*\bERR\b')
# 3. set +o pipefail (to disable)
# FIX: support combined flags (e.g., 'set +uo pipefail')
PIPEFAIL_OFF_RE = re.compile(r'^\s*set\s+[+][a-z]*o\s+pipefail\b')
# 4. $(...) checker invocation — matches $(bash "$WORKSPACE/scripts/check-*.sh" ...)
CHECKER_INVOKE_RE = re.compile(r'\$\(bash\s+"\$WORKSPACE/scripts/check-[^"]+\.sh"')
# 5. awk | head pattern
AWK_HEAD_RE = re.compile(r'\bawk\b.*\|.*\bhead\s+-[0-9]')
# 6. tr '\n' 'X' in process substitution
TR_NEWLINE_RE = re.compile(r"tr\s+['\"]?\\n['\"]?\s+['\"]?.")
# 7. read -r ... < <(cmd) with multi-line pipeline
READ_PROCSUB_RE = re.compile(r'read\s+-r\s+\S+.*<\s*<\([^)]*\|')
# 8. $(cmd) without || fallback (general)
DOLLAR_PAREN_RE = re.compile(r'\$\(([^)]+)\)')
# 9. || true / || echo / || die / || exit (fallback patterns)
FALLBACK_RE = re.compile(r'\|\|\s*(true|echo|die|exit|return)')
# 10. if cmd; then / if ! cmd; then
IF_CMD_RE = re.compile(r'\bif\s+(!\s+)?[^;]+\s*;\s*then\b')
# 11. if [[ -x "$X" ]] guard followed by $(X 2>&1 || true)
IF_X_GUARD_RE = re.compile(r'\bif\s+\[\[\s*-x\s+\$')
# 12. set +o pipefail / set -o pipefail toggle (local disable)
# FIX: support combined flags (e.g., 'set -uo pipefail')
LOCAL_TOGGLE_RE = re.compile(r'^\s*set\s+[+-][a-z]*o\s+pipefail\b')

findings = []

for script in script_names:
    path = resolve_script_path(script, script_parent_dirs)  # L-138 v2: support multi-dir lookup
    if not os.path.exists(path):
        continue
    with open(path) as f:
        content = f.read()
    lines = content.split('\n')

    # Phase 1: Determine if this script has set -o pipefail AND trap ... ERR
    # L-138 v2 FIX: track pipefail toggle state (set -uo pipefail / set +uo pipefail)
    has_pipefail = False
    has_trap_err = False
    pipefail_active = False  # current effective state

    for i, line in enumerate(lines, 1):
        stripped = line.lstrip()
        if stripped.startswith('#'):
            continue
        if PIPEFAIL_OFF_RE.search(line):
            has_pipefail = True  # script has pipefail config (any toggle)
            pipefail_active = False
            continue
        if PIPEFAIL_RE.search(line):
            has_pipefail = True
            pipefail_active = True
        if TRAP_ERR_RE.search(line):
            has_trap_err = True

    # If the script doesn't have both, skip it (different bug shape)
    if not (has_pipefail and has_trap_err):
        continue

    # Phase 2: Scan for violations — only flag while pipefail is currently active
    pipefail_active_line = 0  # track which line set it active, for reset on toggle
    # L-138 v2: join lines for multi-line pattern detection (e.g., procsub with embedded \n)
    # This handles `echo "1\n2" | python3 ...` patterns split across physical lines.
    # We process both the original line AND a "joined" view, but only flag once per finding.
    joined_lines = []
    if lines:
        current = ""
        in_string = False
        string_char = None
        for ln in lines:
            # Naive string tracking — good enough for our use case
            for ch in ln:
                if not in_string and ch in ('"', "'"):
                    in_string = True
                    string_char = ch
                elif in_string and ch == string_char:
                    in_string = False
            if in_string:
                current += ln + "\n"
            else:
                if current:
                    joined_lines.append(current)
                    current = ""
                joined_lines.append(ln)
        if current:
            joined_lines.append(current)
    else:
        joined_lines = lines

    for i, line in enumerate(joined_lines, 1):
        stripped = line.lstrip()
        if stripped.startswith('#'):
            continue

        # L-138 v2: update toggle state BEFORE scanning this line
        if PIPEFAIL_OFF_RE.search(line):
            pipefail_active = False
            continue
        if PIPEFAIL_RE.search(line):
            pipefail_active = True
            pipefail_active_line = i
            continue

        # Skip if pipefail is not currently active (toggled off)
        if not pipefail_active:
            continue

        # --- Rule 1: HIGH — $(bash "$WORKSPACE/scripts/check-*.sh" ...) without || true ---
        if CHECKER_INVOKE_RE.search(line):
            # Check for fallback
            if not FALLBACK_RE.search(line):
                # Check for if-guard pattern
                if not IF_CMD_RE.search(line):
                    findings.append({
                        'script': script,
                        'line': i,
                        'severity': 'high',
                        'rule': 1,
                        'pattern': 'checker_invoke_no_fallback',
                        'snippet': line.strip()[:200],
                        'fix': 'Add || true after the $(...) invocation'
                    })
                    continue  # don't double-flag

        # --- Rule 2: HIGH — awk | head -N (SIGPIPE) ---
        if AWK_HEAD_RE.search(line):
            # Check for fallback
            if not FALLBACK_RE.search(line):
                findings.append({
                    'script': script,
                    'line': i,
                    'severity': 'high',
                    'rule': 2,
                    'pattern': 'awk_head_sigpipe',
                    'snippet': line.strip()[:200],
                    'fix': 'Replace awk | head with python or add || true'
                })
                continue

        # --- Rule 3: HIGH — tr '\n' 'X' in process substitution ---
        if TR_NEWLINE_RE.search(line) and '< <(' in line:
            if not FALLBACK_RE.search(line):
                findings.append({
                    'script': script,
                    'line': i,
                    'severity': 'high',
                    'rule': 3,
                    'pattern': 'tr_newline_procsub',
                    'snippet': line.strip()[:200],
                    'fix': 'Replace tr with python print(a, b, c) + IFS=" " read -r pattern'
                })
                continue

        # --- Rule 4: HIGH — read -r ... < <(cmd) with multi-line pipeline ---
        if READ_PROCSUB_RE.search(line):
            if not FALLBACK_RE.search(line):
                findings.append({
                    'script': script,
                    'line': i,
                    'severity': 'high',
                    'rule': 4,
                    'pattern': 'read_procsub_pipeline',
                    'snippet': line.strip()[:200],
                    'fix': 'Add || true to the pipeline or use python print + IFS=" " read -r pattern'
                })
                continue

        # --- Rule 5: MEDIUM — any other $(cmd) without || fallback ---
        # Only flag if it's a multi-word command (not a simple variable expansion)
        for m in DOLLAR_PAREN_RE.finditer(line):
            inner = m.group(1).strip()
            # Skip simple variable expansions: $(VAR) or $(VAR:-default)
            if re.match(r'^[A-Z_][A-Z_0-9]*(:?[-+?=].*)?$', inner):
                continue
            # Skip if it's inside an if condition
            if IF_CMD_RE.search(line):
                continue
            # Skip if it has a fallback
            if FALLBACK_RE.search(line):
                continue
            # Skip if it's a simple echo or assignment
            if inner.startswith('echo ') or inner.startswith('printf '):
                continue
            # Skip if it's inside a string (quoted)
            # Check if the $(...) is inside double quotes — that's fine
            line_before = line[:m.start()]
            if line_before.count('"') % 2 == 1:
                continue

            findings.append({
                'script': script,
                'line': i,
                'severity': 'medium',
                'rule': 5,
                'pattern': 'dollar_paren_no_fallback',
                'snippet': line.strip()[:200],
                'fix': 'Add || true after $(...) or wrap in if/then'
            })

output = {
    'generatedAt': datetime.datetime.now().strftime('%Y-%m-%dT%H:%M:%S'),
    'schemaVersion': 1,
    'scope': 'scripts/*.sh (excluding .bak/.backup)',
    'pattern': 'set -o pipefail + trap ERR + ungated $(...) / awk|head / tr|procsub / read|procsub',
    'findings': findings,
    'summary': {
        'total_findings': len(findings),
        'high_severity': sum(1 for f in findings if f['severity'] == 'high'),
        'medium_severity': sum(1 for f in findings if f['severity'] == 'medium'),
        'scripts_affected': sorted(set(f['script'] for f in findings))
    }
}
with open(output_path, 'w') as f:
    json.dump(output, f, indent=2)
print("PIPEFAIL_TRAP_FINDINGS: {}".format(len(findings)))
print("HIGH: {}".format(output['summary']['high_severity']))
print("MEDIUM: {}".format(output['summary']['medium_severity']))
for ff in findings[:10]:
    print("  {}:{} rule={} severity={} pattern={}".format(
        ff['script'], ff['line'], ff['rule'], ff['severity'], ff['pattern']))
if len(findings) > 10:
    print("  ... and {} more (see {})".format(len(findings) - 10, os.path.basename(output_path)))
sys.exit(1 if findings else 0)
PYEOF
