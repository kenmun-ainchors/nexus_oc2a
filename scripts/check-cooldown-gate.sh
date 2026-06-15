#!/bin/bash
# check-cooldown-gate.sh — Static analyzer for the L-136 bug class.
# Detects `SHOULD_FIRE[_NN]=false` patterns where a side-effect call
# (sovereign-alert.sh, telegram-alert.sh, openclaw cron edit/rm/add,
# write to state/*-last-fire.json) appears in the next 30 lines WITHOUT
# being gated by an if-block that tests the same SHOULD_FIRE variable.
#
# The bug: a script sets SHOULD_FIRE=false to indicate "skip", but
# the actual side-effect call is not inside an if-block that checks
# the variable. Result: the side effect fires unconditionally.
#
# Output: state/cooldown-gate-findings.json
# Prints: COOLDOWN_GATE_FINDINGS: N
# Exit: 0 if 0 findings, 1 if any.
#
# Defense-in-depth: pairs with CHECK 34 (L-137) in auto-heal.
# Pattern: see LESSONS.md L-136, L-137.
# Sibling of: scripts/check-null-safe-json.sh (L-132).

set -u
WORKSPACE="${WORKSPACE:-/Users/ainchorsangiefpl/.openclaw/workspace}"
SCRIPTS_DIR="$WORKSPACE/scripts"
OUTPUT="$WORKSPACE/state/cooldown-gate-findings.json"

# Scope: only .sh in scripts/, exclude backups
# Note: macOS ships bash 3.2 which lacks `mapfile`. Use a while-read loop for portability.
TARGETS=()
while IFS= read -r f; do
  TARGETS+=("$f")
done < <(find "$SCRIPTS_DIR" -maxdepth 1 -name "*.sh" -type f ! -name "*.bak" ! -name "*.backup" 2>/dev/null | sort)

# Build a list of script basenames for the Python parser
SCRIPT_LIST=$(printf "%s\n" "${TARGETS[@]}" | xargs -I {} basename {} | tr '\n' ':' | sed 's/:$//')

python3 - "$SCRIPTS_DIR" "$OUTPUT" "$SCRIPT_LIST" <<'PYEOF'
import json, os, re, sys, datetime

scripts_dir = sys.argv[1]
output_path = sys.argv[2]
script_list_str = sys.argv[3]
script_names = [s for s in script_list_str.split(':') if s]

# Patterns
# A gating variable: SHOULD_FIRE, SHOULD_FIRE_31, should_fire, etc.
GATE_VAR_RE = re.compile(r'\b(SHOULD_FIRE(?:[_A-Z0-9]*)?)\s*=\s*(true|false)\b')
# Side-effect calls (the things we don't want fired when gate is false)
SIDE_EFFECT_PATTERNS = [
    re.compile(r'\bsovereign-alert\.sh\b'),
    re.compile(r'\btelegram-alert\.sh\b'),
    re.compile(r'\bopenclaw\s+cron\s+(edit|rm|add)\b'),
    re.compile(r'open\(\s*[\'"](\$?[A-Z_]+|\$\{?[A-Z_]+\}?)[\'"]'),  # Python file opens
    re.compile(r'>\s*\$?\{?[A-Z_]*LAST_FIRE\}?[\'"]?\b'),  # writing to *-last-fire.json
    re.compile(r'\bsubprocess\.run\('),  # Any subprocess.run in python
]
# Gating if-block: if [[ "$VAR" == "true" ]] or if [[ $VAR -eq 1 ]] or if [[ "$VAR" != "true" ]]
GATE_IF_RE = re.compile(r'\bif\s+\[\[\s+["\$]?\$?\{?(\w+)\}?["\$]?\s+(==|!=|-eq)\s+["]?(true|1)["]?\s+\]\]')

findings = []

for script in script_names:
    path = os.path.join(scripts_dir, script)
    if not os.path.exists(path):
        continue
    with open(path) as f:
        content = f.read()
    lines = content.split('\n')

    # Track the set of gate variables that have been set to false and not yet consumed
    # For each: list of (line_no, scope_end) where scope_end = line where an if-block
    # referencing the variable ends (or +30 from set line if no if-block found)
    active_gates = []  # list of {var, set_line, gated_through_line}

    for i, line in enumerate(lines, 1):
        stripped = line.lstrip()
        # Skip pure comments
        if stripped.startswith('#'):
            continue

        # Detect a SHOULD_FIRE=... assignment
        m = GATE_VAR_RE.search(line)
        if m and not line.lstrip().startswith('if '):  # assignment, not comparison
            var = m.group(1)
            val = m.group(2)
            # We care about assignments to false (or true — we'll verify gating exists)
            active_gates.append({'var': var, 'value': val, 'set_line': i, 'gated_through': i})
            continue

        # Detect gating if-block: if [[ "$VAR" == "true" ]] etc.
        gm = GATE_IF_RE.search(line)
        if gm:
            gated_var = gm.group(1)
            # Update the gate's coverage to extend through this if-block
            # Find the matching `fi` using bracket-balanced scan:
            # - Strip comments first
            # - Track if/elif/else/fi/while/for/case/esac tokens
            # - Use word-boundary matching to avoid 'find', 'fish', 'config', etc.
            import re as _re
            IF_TOKEN = _re.compile(r'\bif\b')
            ELIF_TOKEN = _re.compile(r'\belif\b')
            ELSE_TOKEN = _re.compile(r'\belse\b')
            FI_TOKEN = _re.compile(r'\bfi\b')
            WHILE_TOKEN = _re.compile(r'\bwhile\b')
            FOR_TOKEN = _re.compile(r'\bfor\b')
            CASE_TOKEN = _re.compile(r'\bcase\b')
            ESAC_TOKEN = _re.compile(r'\besac\b')
            depth = 0
            fi_line = i + 50  # default: extend coverage by 50 lines
            for j in range(i - 1, len(lines)):
                raw = lines[j]
                # Strip comments — everything after # (but not inside quotes; best-effort)
                hash_pos = raw.find('#')
                if hash_pos >= 0 and not (raw[:hash_pos].count('"') % 2 or raw[:hash_pos].count("'") % 2):
                    raw_no_comment = raw[:hash_pos]
                else:
                    raw_no_comment = raw
                if IF_TOKEN.search(raw_no_comment) or WHILE_TOKEN.search(raw_no_comment) or FOR_TOKEN.search(raw_no_comment) or CASE_TOKEN.search(raw_no_comment):
                    depth += 1
                if FI_TOKEN.search(raw_no_comment) or ESAC_TOKEN.search(raw_no_comment):
                    depth -= 1
                    if depth <= 0:
                        fi_line = j + 1
                        break
            # Extend the coverage of any active gate matching this var
            for g in active_gates:
                if g['var'] == gated_var and g['gated_through'] < fi_line:
                    g['gated_through'] = fi_line
            continue

        # Detect side-effect call
        is_side_effect = any(p.search(line) for p in SIDE_EFFECT_PATTERNS)
        if not is_side_effect:
            continue

        # Side effect found — check if it's inside a gate
        side_effect_line = i
        # Find any active gate whose set_line is within 30 lines above AND that
        # covers this line
        violating_gates = []
        for g in active_gates:
            # Gate was set within 30 lines above
            if g['set_line'] <= side_effect_line <= g['set_line'] + 30:
                # And the gate doesn't cover this line (i.e., we're outside the if-block)
                if side_effect_line > g['gated_through']:
                    violating_gates.append(g)

        if violating_gates:
            # Only flag the closest gate (don't double-count)
            g = violating_gates[0]
            findings.append({
                'script': script,
                'gateLine': g['set_line'],
                'gateVar': g['var'],
                'gateValue': g['value'],
                'sideEffectLine': side_effect_line,
                'sideEffectSnippet': line.strip()[:200],
                'gatedThrough': g['gated_through'],
                'gap': side_effect_line - g['gated_through'],
                'severity': 'high' if g['value'] == 'false' else 'medium',
                'fix': f'Wrap side-effect call in: if [[ "${g["var"]}" == "true" ]]; then ... fi'
            })

output = {
    'generatedAt': datetime.datetime.now().strftime('%Y-%m-%dT%H:%M:%S'),
    'schemaVersion': 1,
    'scope': 'scripts/*.sh (excluding .bak/.backup)',
    'pattern': 'SHOULD_FIRE[_NN]=false followed by ungated side-effect call within 30 lines',
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
print(f"COOLDOWN_GATE_FINDINGS: {len(findings)}")
print(f"HIGH: {output['summary']['high_severity']}")
print(f"MEDIUM: {output['summary']['medium_severity']}")
for ff in findings[:5]:
    print(f"  {ff['script']}:{ff['sideEffectLine']} gate={ff['gateVar']}={ff['gateValue']} (set L{ff['gateLine']}) gap={ff['gap']} severity={ff['severity']}")
if len(findings) > 5:
    print(f"  ... and {len(findings) - 5} more (see {os.path.basename(output_path)})")
sys.exit(1 if findings else 0)
PYEOF
