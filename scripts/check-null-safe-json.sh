#!/bin/bash
# check-null-safe-json.sh — Static checker for L-126 bug class.
# Detects `.get(KEY, DEFAULT)` patterns in shell scripts that flow
# into bash arithmetic.
#
# Output: state/null-safe-json-findings.json
# Exit: 0 if no findings, 1 if findings exist

set -u
WORKSPACE="${WORKSPACE:-/Users/ainchorsangiefpl/.openclaw/workspace}"
SCRIPTS_DIR="$WORKSPACE/scripts"
OUTPUT="$WORKSPACE/state/null-safe-json-findings.json"
SCRIPT_LIST="auto-heal.sh"

python3 <<'PYEOF'
import json, re, os, sys

scripts_dir = os.environ.get('SCRIPTS_DIR', '/Users/ainchorsangiefpl/.openclaw/workspace/scripts')
output_path = os.environ.get('OUTPUT', '/Users/ainchorsangiefpl/.openclaw/workspace/state/null-safe-json-findings.json')
script_list = os.environ.get('SCRIPT_LIST', 'auto-heal.sh')
targets = [s.strip() for s in script_list.split(':') if s.strip()]

findings = []

# Match .get('KEY', DEFAULT) where DEFAULT is a number, '', None, False, True
GET_RE = re.compile(r"""\.get\((['\"])(\w+)\1,\s*(\d+|''|None|False|True)\)""")

for script in targets:
    path = os.path.join(scripts_dir, script)
    if not os.path.exists(path):
        continue
    with open(path) as f:
        content = f.read()
    lines = content.split('\n')

    for i, line in enumerate(lines, 1):
        stripped = line.lstrip()
        if stripped.startswith('#'):
            continue

        # Find variable being assigned
        am = re.match(r'^\s*(\w[\w_]*)=', line)
        if not am:
            continue
        var_name = am.group(1)

        for m in GET_RE.finditer(line):
            key = m.group(2)
            default = m.group(3)

            # Build a window of lines after this one (up to 15)
            window = []
            for j in range(i, min(i + 15, len(lines) + 1)):
                window.append(lines[j-1])
            window_text = '\n'.join(window)

            # Check if var_name appears in a bash arithmetic context in window
            in_arith = False
            for wl in window:
                # Skip python code lines
                if wl.strip().startswith(('python3', 'import ', 'json.')):
                    continue
                if wl.strip().startswith(('print(', 'json.d', 'sys.')):
                    continue
                # Check for [[ "$var" -lt ]] or (( var )) or $(( var ))
                if re.search(r'\[\[\s*["\']?\$?' + re.escape(var_name) + r'["\']?\s*-[glte]e?\s', wl):
                    in_arith = True
                    break
                if re.search(r'\(\(\s*' + re.escape(var_name) + r'\s', wl):
                    in_arith = True
                    break
                if re.search(r'\$\(\(\s*' + re.escape(var_name), wl):
                    in_arith = True
                    break

            if not in_arith:
                continue

            findings.append({
                'script': script,
                'line': i,
                'key': key,
                'default': default,
                'var_name': var_name,
                'snippet': line.strip()[:200],
                'severity': 'high' if re.match(r'^\d+$', default) else 'medium',
                'fix': ".get('{}', {}) -> .get('{}') or {}".format(key, default, key, default)
            })

output = {
    'generatedAt': __import__('datetime').datetime.now().strftime('%Y-%m-%dT%H:%M:%S'),
    'schemaVersion': 1,
    'scope': 'scripts/*.sh',
    'pattern': '.get(KEY, NUM) flowing into bash arithmetic',
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
print("NULL_SAFE_FINDINGS: {}".format(len(findings)))
print("HIGH: {}".format(output['summary']['high_severity']))
print("MEDIUM: {}".format(output['summary']['medium_severity']))
for ff in findings[:10]:
    print("  {}:{} var={} key={} default={} severity={}".format(
        ff['script'], ff['line'], ff.get('var_name','?'), ff['key'], ff['default'], ff['severity']))
if len(findings) > 10:
    print("  ... and {} more".format(len(findings) - 10))
sys.exit(1 if findings else 0)
PYEOF
