# audit-skill.sh v2 Enhancement Spec
## TKT-0180 | Status: COMMITTED TO S4 | Priority: P2
## Date: 2026-05-15 | Approved by: Ken Mun
## Agent: Forge | Est: 0.5 day

---

## 1. Objective

Enhance our existing `audit-skill.sh` to catch semantic/safety issues that regex patterns miss. Prepares us for ClawGuard evaluation at P2 without external dependency today.

---

## 2. Current State

**audit-skill.sh v1:**
- 8 regex patterns (pipe-to-shell, prompt injection, credential exfil, eval, IP URLs, shorteners, rm -rf, netcat)
- BLOCK or FLAG severity
- No semantic understanding
- No dependency awareness
- No tool-scope validation

**Gaps:**
- A skill claiming "weather lookup" that writes to workspace-social/ = not caught
- A skill with excessive cron creation = not caught
- A skill referencing unvetted external URLs = not caught
- A skill using tools outside its declared domain = not caught

---

## 3. New Checks to Add

### Check 9: SEMANTIC_DOMAIN_MISMATCH
```
Read SKILL.md "What Goes Here" section
Extract claimed domain (e.g. "weather", "office docs", "social media")
Check if referenced tools match domain:
- weather skill using write tool extensively → FLAG
- social skill using exec tool for curl → FLAG
- office-docs skill using web_search → OK (research)
```

### Check 10: EXTERNAL_URL_UNVETTED
```
Find all URLs in SKILL.md
Check if URL is in known-safe list (github.com/openclaw, clawhub.ai, etc.)
If HTTPS but not in allowlist → FLAG
If HTTP (not HTTPS) → BLOCK
If URL shortener → BLOCK (already covered, keep)
```

### Check 11: EXCESSIVE_CRON_CREATION
```
Count cron references in SKILL.md
- > 3 cron jobs mentioned → FLAG
- > 5 cron jobs → BLOCK
- Recursive self-spawn pattern (skill spawns itself) → BLOCK
```

### Check 12: TOOL_SCOPE_VIOLATION
```
Check if skill references paths outside its declared domain:
- weather skill writing to workspace-social/ → BLOCK
- social skill reading from docs/ → FLAG (may be legitimate research)
- Any skill writing to state/ → BLOCK (system directory)
- Any skill writing to memory/ → BLOCK (personal data)
```

### Check 13: SUPPLY_CHAIN_RISK
```
If SKILL.md references external scripts/executables:
- Check if referenced script is in workspace/scripts/ (vetted)
- If references curl | bash pattern → BLOCK (already covered, keep)
- If references npm/pip install of unvetted packages → FLAG
```

---

## 4. Implementation Plan

### File: scripts/audit-skill.sh

```python
# NEW CHECKS to add to CHECKS list:

("SEMANTIC_DOMAIN", "FLAG", "Tool usage outside declared domain",
 r'(?i)(?:weather|social|office|docs|infra|security).*?(?:write|exec).*?(?:social|infra|docs|memory|state)',
 "Skill claims one domain but uses tools/paths from another domain"),

("EXTERNAL_URL", "FLAG", "External URL not in allowlist",
 r'https?://(?!github\.com|docs\.openclaw\.ai|clawhub\.ai|pypi\.org|npmjs\.com|...)',
 "External URL not in known-safe list — verify before trusting"),

("EXCESSIVE_CRON", "FLAG", "Excessive cron job creation",
 r'(?i)(?:cron|schedule|every|at\s+\d{1,2}:).*?(?:cron|schedule|every|at\s+\d{1,2}:)',
 "Multiple cron references may indicate resource exhaustion risk"),

("SYSTEM_PATH_WRITE", "BLOCK", "Write to system directory",
 r'(?i)(?:write|exec).*?(?:state/|memory/|\.openclaw/|/etc/|/var/)',
 "Skills should not write to system or personal data directories"),

("RECURSIVE_SPAWN", "BLOCK", "Recursive self-spawn pattern",
 r'(?i)(?:spawn|subagent).*?(?:itself|self|recursive)',
 "Recursive self-spawning can cause resource exhaustion"),
```

### Allowlist: state/skill-url-allowlist.json
```json
{
  "allowedHosts": [
    "github.com",
    "docs.openclaw.ai",
    "clawhub.ai",
    "pypi.org",
    "npmjs.com",
    "registry.npmjs.org",
    "raw.githubusercontent.com",
    "huggingface.co",
    "anthropic.com",
    "openai.com"
  ],
  "updatedAt": "2026-05-15",
  "note": "Add hosts only after vetting. Review quarterly."
}
```

---

## 5. Test Plan

Test on existing skills:
| Skill | Expected | Why |
|---|---|---|
| weather | CLEAR | No system writes, no external URLs, single domain |
| office-docs | CLEAR | Uses allowed tools for declared domain |
| linkedin-post | FLAG or CLEAR | Uses exec for curl — already flagged by PIPE_SHELL |
| browser-automation | FLAG | Uses web_fetch extensively — verify domain |
| gh-issues | CLEAR | Uses gh CLI for declared domain |

---

## 6. Acceptance Criteria

- [ ] All 5 new checks implemented in audit-skill.sh
- [ ] allowlist.json created and populated
- [ ] Tested on 5+ existing skills
- [ ] No false positives on legitimate skills
- [ ] CHG entry logged
- [ ] Ken sign-off: APPROVED

---

## 7. Approval

**Ken — approved for Sprint 4? 0.5 day, Forge owner.**

Reply: **APPROVED** | **EDIT** [feedback] | **REJECT** [reason]
