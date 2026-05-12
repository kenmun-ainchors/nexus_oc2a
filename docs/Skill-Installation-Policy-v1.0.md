# Skill Installation Policy v1.0
**Status:** APPROVED | **Date:** 2026-05-10 | **Approved by:** Ken Mun (CTO)
**Owner:** Yoda (operational) + Shield (security review)
**TKT:** TKT-0141, TKT-0142 | **Reference:** S3 Security Control | **CHG:** CHG-0270

---

**ITIL Practice:** Service Configuration Management

## Purpose

Skills extend agent capability via SKILL.md instruction files. A poisoned SKILL.md executes with full agent credentials, bypasses all SAST/SCA scanners, and leaves no trace in SBOMs. This policy ensures every skill installed on AInchors infrastructure passes a strict gate before it can influence any agent.

**Context:** Snyk ToxicSkills audit (Feb 2026) found 13.4% of 3,984 ClawHub skills had critical security issues. ClawHavoc campaign (Jan–Apr 2026) delivered Atomic Stealer via 1,184 compromised packages. VentureBeat (May 2026) confirmed no mainstream SAST/SCA scanner has a detection category for malicious SKILL.md content. Internal audit (2026-05-10): 63 existing skills scanned — clean.

---

## Non-Negotiable Rules

1. **No ClawHub skills. Ever.** S3 control — absolute prohibition. No exceptions.
2. **Ticket-first.** No skill installation begins without a TKT reference.
3. **Ken approves every installation.** No agent, not even Yoda, installs a skill without explicit Ken approval.
4. **Every skill is audited before approval.** Shield + Sage mandatory review. No bypass.
5. **Skill registry is the source of truth.** Every approved skill logged in `state/skill-registry.json`.

---

## Skill Classification

| Class | Definition | Policy |
|-------|-----------|--------|
| **OpenClaw bundled** | Shipped with OpenClaw npm package | Pre-audited; re-audit on OC version upgrade |
| **Custom-built (AInchors)** | Written by Yoda, Ken, or a named AInchors agent | Full gate required |
| **Third-party verified** | From a verified source (not ClawHub) with known author | Full gate required + source verification |
| **ClawHub / unknown source** | From ClawHub, skills.sh, or unverifiable origin | **PROHIBITED** |

---

## Skill Installation Gate (mandatory for all Custom and Third-party skills)

### Step 1 — TKT Raised (Yoda)
- Raise a TKT before any discussion or work begins
- TKT must include: skill name, purpose, source, author, why it's needed

### Step 2 — Source Verification (Yoda + Shield)
Shield must confirm:
- [ ] Source is NOT ClawHub or skills.sh
- [ ] Author is known and identifiable
- [ ] Repository/origin has commit history and is not newly created
- [ ] No recent suspicious commits or contributors

### Step 3 — SKILL.md Audit (Shield + Sage)
Run the audit script:
```bash
bash /Users/ainchorsangiefpl/.openclaw/workspace/scripts/audit-skill.sh \
  --path /path/to/SKILL.md --strict
```

Shield checks for:
- [ ] No pipe-to-shell patterns (`curl ... | bash`, `wget ... | sh`)
- [ ] No instruction override language (ignore previous instructions, you are now, etc.)
- [ ] No credential exfiltration patterns (`echo $TOKEN`, `cat ~/.ssh/...`)
- [ ] No IP-based URLs or URL shorteners
- [ ] No eval of dynamic content
- [ ] No embedded shell commands outside of clearly documented examples
- [ ] No external network calls to unexpected domains

Sage checks for:
- [ ] Instructions are scoped to the documented purpose — no scope creep
- [ ] No directives that could override or expand agent permissions
- [ ] Language is precise and non-ambiguous — no instructions that could be misread
- [ ] Code examples are illustrative only, not operational directives

### Step 4 — Human Read (Yoda)
Yoda reads the full SKILL.md manually. Not a scan — a read. Flag anything that feels off even if the scanner missed it.

### Step 5 — Ken Approval
Yoda delivers to Ken:
```
🔐 Skill Installation Request

Skill: [name]
Source: [URL/origin]
Author: [name]
Purpose: [what it enables]
TKT: TKT-NNNN

Shield: [CLEAR / FLAG: reason]
Sage: [CLEAR / FLAG: reason]
Yoda read: [CLEAR / FLAG: reason]

Reply APPROVED: TKT-NNNN to install
```

Ken must reply explicitly. No approval = no installation. Silence = no.

### Step 6 — Installation + Registry Entry
After Ken approval:
```bash
# Install skill
# Then immediately register:
bash /Users/ainchorsangiefpl/.openclaw/workspace/scripts/skill-registry.sh \
  --add \
  --name "[skill-name]" \
  --path "[install-path]" \
  --source "[URL/origin]" \
  --author "[author]" \
  --approved-by "Ken" \
  --tkt "TKT-NNNN" \
  --chg "CHG-NNNN"
```

### Step 7 — Post-Install Validation
- Re-run audit script against installed files
- Confirm skill behaves as documented (no unexpected tool calls)
- Log CHG entry

---

## Skill Registry

All approved skills tracked in `state/skill-registry.json`. Format:
```json
{
  "skills": [
    {
      "name": "gog",
      "class": "custom-built",
      "path": "~/.openclaw/workspace/skills/gog/SKILL.md",
      "source": "AInchors custom",
      "author": "Yoda",
      "approvedBy": "Ken",
      "approvedAt": "2026-04-29",
      "tkt": "N/A",
      "lastAudited": "2026-05-10",
      "auditResult": "clean",
      "chg": "CHG-0270"
    }
  ],
  "lastFullAudit": "2026-05-10",
  "auditScript": "scripts/audit-skill.sh"
}
```

---

## Ongoing Controls

| Control | Cadence | Owner |
|---------|---------|-------|
| Weekly audit of all installed skills | Weekly (auto) | Shield cron |
| Full re-audit on OC version upgrade | Per upgrade | Yoda + Shield |
| Registry vs installed files reconciliation | Weekly | Yoda |
| Policy review | Quarterly (QBR) | Ken |

---

## Failure Modes and Response

| Scenario | Response |
|----------|---------|
| New skill found installed without TKT | Immediate removal. INC raised. Post-mortem. |
| Audit flags a skill post-install | Remove immediately. Investigate. Ken notified within 1h. |
| ClawHub skill found anywhere on OC1 | S3 violation. INC raised. Remove. Root cause analysis. |
| Skill scanner evasion (2.5% DDIPE rate) | Manual read is the last defence. Cannot be skipped. |

---

## Version History
| Version | Date | Change |
|---------|------|--------|
| v1.0 | 2026-05-10 | Initial policy — Ken approved. TKT-0141/0142. |
