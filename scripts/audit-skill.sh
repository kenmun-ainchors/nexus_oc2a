#!/usr/bin/env zsh
# audit-skill.sh — Security audit of a SKILL.md file before installation
# TKT-0141/0142 | Skill-Installation-Policy-v1.0.md
#
# Usage:
#   audit-skill.sh --path /path/to/SKILL.md [--strict] [--json]
#
# Exit codes: 0=CLEAR, 1=FLAG (review needed), 2=BLOCK (do not install)

set -uo pipefail

SKILL_PATH=""
STRICT=false
JSON_OUT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)   SKILL_PATH="$2"; shift 2 ;;
    --strict) STRICT=true; shift ;;
    --json)   JSON_OUT=true; shift ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$SKILL_PATH" ]] && { echo "❌ --path required" >&2; exit 1; }
[[ ! -f "$SKILL_PATH" ]] && { echo "❌ File not found: $SKILL_PATH" >&2; exit 1; }

python3 - "$SKILL_PATH" "$STRICT" "$JSON_OUT" << 'PYEOF'
import sys, re, json

path = sys.argv[1]
strict = sys.argv[2] == "True"
json_out = sys.argv[3] == "True"

content = open(path).read()
lines = content.split('\n')

CHECKS = [
    # (id, severity, description, pattern, note)
    ("PIPE_SHELL",   "BLOCK", "Pipe-to-shell execution",
     r'curl[^\n|]*\|[^\n]*(?:bash|sh)\b|wget[^\n|]*\|[^\n]*(?:bash|sh)\b',
     "curl/wget piped to shell — classic supply chain attack vector"),

    ("INSTR_OVERRIDE", "BLOCK", "Instruction override language",
     r'(?i)ignore.{0,30}(?:previous|above|prior).{0,20}instruction|disregard.{0,20}system.{0,20}prompt|you are now an?\b|forget.{0,20}(?:your\s+)?guidelines?|bypass.{0,20}(?:safety|filter|restriction)|jailbreak|DAN mode',
     "Prompt injection attempt embedded in documentation"),

    ("CRED_EXFIL",  "BLOCK", "Credential exfiltration pattern",
     r'echo\s+\$[A-Z_]{3,}(?:TOKEN|KEY|SECRET|PASSWORD|PASS|API)\b|cat\s+[~\/][^\s]*\.(?:ssh|env|pem|key|gpg|p12)|base64\s+[~\/]',
     "May extract credentials during normal agent operation"),

    ("EVAL_DYNAMIC", "FLAG", "Dynamic eval of content",
     r'\beval\s*\$\(|\beval\s*`',
     "eval of dynamic content is high-risk even in examples"),

    ("IP_URL",       "FLAG", "IP-based URL (non-localhost)",
     r'https?://(?!127\.0\.0\.1|localhost|0\.0\.0\.0)\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}',
     "Direct IP URL may bypass DNS-based filtering"),

    ("URL_SHORTENER", "FLAG", "URL shortener detected",
     r'\bbit\.ly/|\btinyurl\.com/|\bt\.co/(?!witter\.com)',
     "Shortened URLs obscure final destination"),

    ("RM_DANGEROUS",  "BLOCK", "Destructive filesystem command",
     r'\brm\s+-[rRf]+\s+/(?!tmp/|var/folders)',
     "rm -rf from root is almost never legitimate in skill docs"),

    ("EXFIL_NETCAT", "FLAG", "Netcat potential exfiltration",
     r'\bnc\s+-[^h][^\n]*\d{2,5}',
     "Netcat with outbound port could be data exfiltration"),

    ("CLAWDBOT_EXEC", "FLAG", "Instruction that appears operational (not documentary)",
     r'(?i)^(?:run|execute|now\s+run|immediately|silently\s+run|do\s+this)[\s:]+(?:bash|sh|python|curl)\b',
     "Imperative language at line start may be a DDIPE embedded directive"),
]

findings = []
for check_id, severity, description, pattern, note in CHECKS:
    for i, line in enumerate(lines, 1):
        if re.search(pattern, line, re.IGNORECASE | re.MULTILINE):
            findings.append({
                'id': check_id,
                'severity': severity,
                'description': description,
                'line': i,
                'content': line.strip()[:120],
                'note': note
            })

# Deduplicate by check_id (report first occurrence only)
seen = set()
deduped = []
for f in findings:
    key = f['id']
    if key not in seen:
        seen.add(key)
        deduped.append(f)

blocks = [f for f in deduped if f['severity'] == 'BLOCK']
flags  = [f for f in deduped if f['severity'] == 'FLAG']

if strict:
    overall = 'BLOCK' if blocks or flags else 'CLEAR'
else:
    overall = 'BLOCK' if blocks else ('FLAG' if flags else 'CLEAR')

exit_code = 2 if overall == 'BLOCK' else (1 if overall == 'FLAG' else 0)

if json_out:
    result = {
        'path': path,
        'verdict': overall,
        'blocks': len(blocks),
        'flags': len(flags),
        'findings': deduped
    }
    print(json.dumps(result, indent=2))
else:
    skill_name = path.rstrip('/').split('/')[-2] if 'SKILL.md' in path else path.split('/')[-1]
    print(f"\n{'='*60}")
    print(f"SKILL AUDIT — {skill_name}")
    print(f"Path: {path}")
    print(f"{'='*60}")
    
    if not deduped:
        print(f"\n✅  VERDICT: CLEAR — no risk indicators found")
    else:
        for f in deduped:
            icon = "🚫" if f['severity'] == 'BLOCK' else "⚠️ "
            print(f"\n{icon} [{f['severity']}] {f['description']} (line {f['line']})")
            print(f"   Content: {f['content']}")
            print(f"   Note:    {f['note']}")
        
        print(f"\n{'─'*60}")
        verdict_icon = "🚫" if overall == 'BLOCK' else "⚠️ "
        print(f"{verdict_icon} VERDICT: {overall} — {len(blocks)} block(s), {len(flags)} flag(s)")
        if overall == 'BLOCK':
            print("   DO NOT INSTALL. Escalate to Ken immediately.")
        elif overall == 'FLAG':
            print("   Manual review required before Ken approval.")

sys.exit(exit_code)
PYEOF
