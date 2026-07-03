#!/usr/bin/env zsh
# audit-skill.sh — Security audit of a SKILL.md file before installation
# TKT-0141/0142 | Skill-Installation-Policy-v1.0.md
# v2.0 | TKT-0180 | 2026-05-15 — Added checks 9-13: SEMANTIC_DOMAIN, EXTERNAL_URL,
#                                  EXCESSIVE_CRON, SYSTEM_PATH_WRITE, RECURSIVE_SPAWN
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

# Resolve allowlist path relative to this script's directory
SCRIPT_DIR="${0:A:h}"
ALLOWLIST_PATH="${SCRIPT_DIR}/../state/skill-url-allowlist.json"

python3 - "$SKILL_PATH" "$STRICT" "$JSON_OUT" "$ALLOWLIST_PATH" << 'PYEOF'
import sys, re, json, os

path         = sys.argv[1]
strict       = sys.argv[2].lower() == "true"
json_out     = sys.argv[3].lower() == "true"
allowlist_fn = sys.argv[4]

content = open(path).read()
lines   = content.split('\n')

# ---------------------------------------------------------------------------
# Checks 1-8: original per-line pattern checks
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Checks 9-13: content-level checks (v2, TKT-0180)
# ---------------------------------------------------------------------------

# ── CHECK 9: SEMANTIC_DOMAIN ─────────────────────────────────────────────────
# Detect tool usage that conflicts with the skill's declared domain.
# Strategy: derive domain from path, then look for cross-domain tool patterns.
skill_name_from_path = os.path.basename(os.path.dirname(os.path.abspath(path))).lower()

DOMAIN_KEYWORDS = {
    'weather':  ['weather', 'forecast', 'temperature', 'rain', 'wind', 'climate'],
    'social':   ['linkedin', 'twitter', 'instagram', 'social', 'post', 'tweet'],
    'office':   ['pdf', 'docx', 'xlsx', 'pptx', 'spreadsheet', 'document', 'report'],
    'infra':    ['docker', 'kubernetes', 'colima', 'ssh', 'server', 'deploy', 'infra'],
    'security': ['security', 'audit', 'firewall', 'vpn', 'encryption', 'shield'],
    'browser':  ['browser', 'playwright', 'selenium', 'web', 'click', 'tab', 'navigate'],
}

# Determine skill domain from its path / skill name
detected_domain = None
for dom, keywords in DOMAIN_KEYWORDS.items():
    if any(kw in skill_name_from_path for kw in keywords):
        detected_domain = dom
        break

# Cross-domain red-flags: (source_domain, suspicious_pattern, description)
CROSS_DOMAIN_PATTERNS = [
    ('weather',  r'(?i)(?:write|exec)\s+.*?(?:social|linkedin|twitter|workspace-social)',
     "Weather skill using social media write paths"),
    ('weather',  r'(?i)(?:state/|memory/|\.openclaw/)',
     "Weather skill referencing internal system paths"),
    ('social',   r'(?i)exec.*?curl.*?(?:\d{1,3}\.){3}\d{1,3}',
     "Social skill using exec/curl with IP address"),
    ('office',   r'(?i)(?:exec|spawn).*?(?:memory/|state/)',
     "Office-docs skill writing to system directories"),
]

if detected_domain and 'SEMANTIC_DOMAIN' not in {f['id'] for f in deduped}:
    for src_dom, pattern, desc in CROSS_DOMAIN_PATTERNS:
        if src_dom == detected_domain:
            m = re.search(pattern, content, re.DOTALL)
            if m:
                # Find the line number
                line_no = content[:m.start()].count('\n') + 1
                deduped.append({
                    'id': 'SEMANTIC_DOMAIN',
                    'severity': 'FLAG',
                    'description': 'Tool usage outside declared domain',
                    'line': line_no,
                    'content': lines[line_no - 1].strip()[:120] if line_no <= len(lines) else '',
                    'note': desc
                })
                break

# Also catch the generic cross-domain pattern from spec (any skill):
# skill references a domain path that doesn't match its own domain
if 'SEMANTIC_DOMAIN' not in {f['id'] for f in deduped}:
    # Generic: look for "write ... social" or "exec ... memory" type patterns
    # that suggest cross-domain tool usage
    generic_cross = re.search(
        r'(?i)\b(?:write|exec)\b[^\n]{0,60}(?:workspace[-_]social|workspace[-_]infra|workspace[-_]docs)[^\n]{0,60}(?:memory|state|\.openclaw)',
        content
    )
    if generic_cross:
        line_no = content[:generic_cross.start()].count('\n') + 1
        deduped.append({
            'id': 'SEMANTIC_DOMAIN',
            'severity': 'FLAG',
            'description': 'Tool usage outside declared domain',
            'line': line_no,
            'content': lines[line_no - 1].strip()[:120] if line_no <= len(lines) else '',
            'note': 'Skill references tools/paths outside its declared domain scope'
        })

# ── CHECK 10: EXTERNAL_URL ───────────────────────────────────────────────────
# Extract all URLs from content, check hosts against allowlist.
# HTTP (non-HTTPS) → BLOCK. HTTPS not in allowlist → FLAG.

allowed_hosts = []
if os.path.isfile(allowlist_fn):
    try:
        with open(allowlist_fn) as f:
            allowlist_data = json.load(f)
        allowed_hosts = [h.lower() for h in allowlist_data.get('allowedHosts', [])]
    except Exception:
        pass  # Allowlist unreadable — treat as empty (be conservative)

url_pattern = re.compile(r'(https?://[^\s\'"<>\)\]]+)', re.IGNORECASE)
all_urls = url_pattern.findall(content)

url_findings = []
seen_hosts = set()
for url in all_urls:
    # Strip trailing punctuation that's likely not part of the URL
    url = re.sub(r'[.,;:!?\)]+$', '', url)
    try:
        # Simple host extraction — strip userinfo (user:pass@host) if present
        after_scheme = url.split('://', 1)[1]
        authority = after_scheme.split('/')[0].split('?')[0].split('#')[0].lower()
        # Strip userinfo prefix (e.g. x-access-token:$TOKEN@github.com)
        if '@' in authority:
            authority = authority.rsplit('@', 1)[1]
        host = authority.split(':')[0]  # remove port
    except IndexError:
        continue

    if host in seen_hosts:
        continue
    seen_hosts.add(host)

    scheme = url.split('://')[0].lower()

    # Is it localhost / private ranges? Skip.
    if host in ('localhost', '127.0.0.1', '0.0.0.0'):
        continue

    # HTTP (not HTTPS) → BLOCK (unless already caught by IP_URL check)
    if scheme == 'http' and not re.match(r'\d+\.\d+\.\d+\.\d+', host):
        if 'EXTERNAL_URL' not in {f['id'] for f in deduped}:
            # Find the line for this URL
            line_no = 1
            for i, line in enumerate(lines, 1):
                if url[:40] in line or host in line:
                    line_no = i
                    break
            url_findings.append({
                'id': 'EXTERNAL_URL',
                'severity': 'BLOCK',
                'description': 'Plain HTTP URL (not HTTPS)',
                'line': line_no,
                'content': url[:120],
                'note': f'HTTP URL {host} — use HTTPS or remove; plain HTTP is insecure'
            })

    # Check against allowlist
    host_allowed = any(
        host == allowed or host.endswith('.' + allowed)
        for allowed in allowed_hosts
    )
    if not host_allowed and 'EXTERNAL_URL' not in {f['id'] for f in deduped}:
        line_no = 1
        for i, line in enumerate(lines, 1):
            if host in line:
                line_no = i
                break
        url_findings.append({
            'id': 'EXTERNAL_URL',
            'severity': 'FLAG',
            'description': 'External URL not in known-safe allowlist',
            'line': line_no,
            'content': url[:120],
            'note': f'Host "{host}" not in state/skill-url-allowlist.json — verify before trusting'
        })

# Add at most one EXTERNAL_URL finding (first/most severe)
if url_findings and 'EXTERNAL_URL' not in {f['id'] for f in deduped}:
    # Sort: BLOCK before FLAG
    url_findings.sort(key=lambda x: 0 if x['severity'] == 'BLOCK' else 1)
    deduped.append(url_findings[0])

# ── CHECK 11: EXCESSIVE_CRON ─────────────────────────────────────────────────
# Count cron/schedule/every/time-pattern mentions across the full content.
# >3 → FLAG, >5 → BLOCK.

# Count actual cron scheduling patterns — NOT CLI flag names like --cron
# Patterns that indicate real schedule creation:
#   - crontab references, actual cron expressions (*/N * * * *)
#   - "schedule: every X minutes/hours", "runs every X", "at HH:MM daily"
# Explicitly excluded: "--cron" (CLI flag name), "cron mode", "cron-safe"
cron_matches = re.findall(
    r'(?i)(?:'
    r'\bcrontab\b|'
    r'\bcron\s+(?:job|expression|syntax|entry|task)\b|'
    r'\*/\d+\s+[*\d]|'
    r'\bschedule[d]?\s+(?:to\s+run|every|at)\b|'
    r'\bevery\s+\d+\s*(?:minutes?|hours?|seconds?|days?|weeks?)\b|'
    r'\bat\s+\d{1,2}:\d{2}\s+(?:daily|weekly|every)\b'
    r')',
    content
)
cron_count = len(cron_matches)
if cron_count > 0 and 'EXCESSIVE_CRON' not in {f['id'] for f in deduped}:
    if cron_count > 5:
        # Find first line with a cron mention
        line_no = 1
        for i, line in enumerate(lines, 1):
            if re.search(r'(?i)\b(?:cron|schedule[d]?|every\s+\d+|at\s+\d{1,2}:\d{2})\b', line):
                line_no = i
                break
        deduped.append({
            'id': 'EXCESSIVE_CRON',
            'severity': 'BLOCK',
            'description': 'Excessive cron/schedule references (>5)',
            'line': line_no,
            'content': lines[line_no - 1].strip()[:120],
            'note': f'{cron_count} cron/schedule references — possible resource exhaustion risk'
        })
    elif cron_count > 3:
        line_no = 1
        for i, line in enumerate(lines, 1):
            if re.search(r'(?i)\b(?:cron|schedule[d]?|every\s+\d+|at\s+\d{1,2}:\d{2})\b', line):
                line_no = i
                break
        deduped.append({
            'id': 'EXCESSIVE_CRON',
            'severity': 'FLAG',
            'description': 'Multiple cron/schedule references (>3)',
            'line': line_no,
            'content': lines[line_no - 1].strip()[:120],
            'note': f'{cron_count} cron/schedule references — review for resource exhaustion risk'
        })

# ── CHECK 12: SYSTEM_PATH_WRITE ──────────────────────────────────────────────
# Detect write/exec operations targeting system or personal data directories.
# BLOCK: state/, memory/, .openclaw/, /etc/, /var/

# SYSTEM_PATH_WRITE: detect writes to system/personal directories
# Uses line-by-line matching to avoid false positives from markdown blockquotes (>)
# Triggers on: write/exec/echo/append/save/dump/output followed by a system path
# Does NOT trigger on: standalone markdown "> text" blockquotes
SYSTEM_PATH_PATTERN = re.compile(
    r'(?i)(?:(?:write|exec|append|save|dump|output)\s|echo\s+[^>\n]*|>>\s*)'
    r'[^\n]*(?:state/|memory/|\.openclaw/|/etc/|/var/)',
)
# Also catch direct path references in write tool calls or file paths
SYSTEM_PATH_DIRECT = re.compile(
    r'(?i)(?:"path"\s*:\s*"|path=|write\s+to\s+|>>\s*)(?:[^\s"\']*(?:state/|memory/|\.openclaw/|/etc/|/var/))',
)

if 'SYSTEM_PATH_WRITE' not in {f['id'] for f in deduped}:
    for i, line in enumerate(lines, 1):
        if SYSTEM_PATH_PATTERN.search(line) or SYSTEM_PATH_DIRECT.search(line):
            deduped.append({
                'id': 'SYSTEM_PATH_WRITE',
                'severity': 'BLOCK',
                'description': 'Write to system/personal directory',
                'line': i,
                'content': line.strip()[:120],
                'note': 'Skills must not write to state/, memory/, .openclaw/, /etc/, /var/ — these are system-reserved paths'
            })
            break

# ── CHECK 12b: CANVAS_DIRECT_WRITE ───────────────────────────────────────────
# Detect direct write tool call to Canvas/external paths.
# These MUST go through cron-write.sh, not the native write tool.
# Patterns: path to ~/.openclaw/canvas/, .openclaw/canvas/, "write tool to ~/.openclaw/canvas/", etc.

CANVAS_WRITE_PATTERN = re.compile(
    r'(?i)'
    r'(?:'
    r'"path"\s*:\s*"~/\.openclaw/canvas/|'          # JSON "path": "~/.openclaw/canvas/...
    r'"path"\s*:\s*\.openclaw/canvas/|'              # JSON "path": ".openclaw/canvas/...
    r'\bwrite\s+tool\s+to\s+~/\.openclaw/canvas/|'    # "write tool to ~/.openclaw/canvas/"
    r'\bwrite\s+tool\s+to\s+\.openclaw/canvas/|'      # "write tool to .openclaw/canvas/"
    r'\bwrite\s+tool\b[^\n]*~/\.openclaw/canvas/|'       # "write tool ... ~/.openclaw/canvas/"
    r'\bwrite\s+tool\b[^\n]*\.openclaw/canvas/'           # "write tool ... .openclaw/canvas/"
    r')'
)

if 'CANVAS_DIRECT_WRITE' not in {f['id'] for f in deduped}:
    for i, line in enumerate(lines, 1):
        if CANVAS_WRITE_PATTERN.search(line):
            deduped.append({
                'id': 'CANVAS_DIRECT_WRITE',
                'severity': 'BLOCK',
                'description': 'Direct write tool call to Canvas/external path',
                'line': i,
                'content': line.strip()[:120],
                'note': 'Canvas/external paths must be written via cron-write.sh, not the native write tool.'
            })
            break

# ── CHECK 13: RECURSIVE_SPAWN ────────────────────────────────────────────────
# Detect recursive self-spawning patterns.
# Pattern: "spawn"/"subagent" near "itself"/"self"/"recursive"

# RECURSIVE_SPAWN: detect recursive self-spawning patterns
# Match within a SINGLE LINE (no DOTALL) to avoid false positives from
# documentation that mentions 'loop' and 'spawn' in separate contexts
RECURSIVE_PATTERN = re.compile(
    r'(?i)(?:spawn|subagent|sessions_spawn)[^\n]{0,100}(?:itself|self[-_]spawn|recursive(?:ly)?)',
)
RECURSIVE_PATTERN2 = re.compile(
    r'(?i)(?:recursive(?:ly)?\s+spawn|self[-_]spawn(?:ing)?|spawn\s+itself)',
)

if 'RECURSIVE_SPAWN' not in {f['id'] for f in deduped}:
    for pattern in [RECURSIVE_PATTERN, RECURSIVE_PATTERN2]:
        m = pattern.search(content)
        if m:
            line_no = content[:m.start()].count('\n') + 1
            deduped.append({
                'id': 'RECURSIVE_SPAWN',
                'severity': 'BLOCK',
                'description': 'Recursive self-spawn pattern detected',
                'line': line_no,
                'content': lines[line_no - 1].strip()[:120] if line_no <= len(lines) else '',
                'note': 'Recursive or looping self-spawn can cause resource exhaustion and runaway agent cost'
            })
            break

# ---------------------------------------------------------------------------
# Compute verdict
# ---------------------------------------------------------------------------
blocks = [f for f in deduped if f['severity'] == 'BLOCK']
flags  = [f for f in deduped if f['severity'] == 'FLAG']

if strict:
    overall = 'BLOCK' if blocks or flags else 'CLEAR'
else:
    overall = 'BLOCK' if blocks else ('FLAG' if flags else 'CLEAR')

exit_code = 2 if overall == 'BLOCK' else (1 if overall == 'FLAG' else 0)

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
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
    print(f"SKILL AUDIT v2 — {skill_name}")
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
