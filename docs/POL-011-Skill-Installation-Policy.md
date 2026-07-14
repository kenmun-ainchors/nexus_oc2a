# POL-011 — Skill Installation and Security Review

**Status:** APPROVED | **Effective:** 2026-05-15 | **Version:** 1.0
**Owner:** Yoda 🟢 (operational) + Shield 🛡️ (security review)
**Approver:** Ken Mun (CTO)
**CHG:** CHG-0331
**TKT:** TKT-0137 (AC2 batch) | **Source Policy:** Skill-Installation-Policy-v1.0.md (APPROVED 2026-05-10)
**Derived from:** AI Charter v1.0 §6 (Security by Default, Agent Accountability) · AI Governance Framework v1.0 §4 (Agent Lifecycle Governance) · Skill-Installation-Policy-v1.0.md
**Review cadence:** Annually or on material change
**Next review:** 2027-05-15

---

## 1. Policy Statement

All skills installed on AInchors infrastructure — including on any Nexus node, agent runtime, or OpenClaw instance — **must** pass a mandatory security gate before they are permitted to influence any agent. No skill shall be installed, activated, or referenced by any agent without explicit written approval from Ken Mun (CTO). ClawHub and skills.sh are absolutely prohibited as skill sources.

This policy is binding on all agents, all infrastructure, and all operators of AInchors systems.

---

## 2. Scope

This policy applies to:

- All SKILL.md instruction files and skill packages installed on OC1 (Mac Mini M4 24GB) or any future Nexus node
- All OpenClaw bundled, custom-built, and third-party skills
- All agents operating on AInchors infrastructure (Yoda, Atlas, Thrawn, Lex, Shield, Sage, Warden, Forge, Lando, Mon Mothma, Spark, Ahsoka, Aria, and all future agents)
- All operators, contractors, or third parties with access to AInchors infrastructure

This policy does **not** apply to:
- Reading or referencing existing approved SKILL.md files within their documented scope
- OpenClaw bundled skills already registered in state/skill-registry.json as of the effective date (re-audited on OpenClaw version upgrades)

---

## 3. Skill Classification

All skills must be classified before any gate step is initiated:

| Class | Definition | Gate Required |
|-------|-----------|---------------|
| **OpenClaw bundled** | Shipped with the OpenClaw npm package | Pre-audited; re-audit on OC version upgrade |
| **Custom-built (AInchors)** | Written by Yoda, Ken, or a named AInchors agent | Full gate (Steps 1–7 below) |
| **Third-party verified** | From a verified source (not ClawHub/skills.sh) with known author | Full gate + Step 2 source verification |
| **ClawHub / unknown source** | From ClawHub, skills.sh, or unverifiable origin | **PROHIBITED — shall not be installed under any circumstances** |

---

## 4. Responsibilities

| Role | Responsibility |
|------|---------------|
| **Yoda (Operational Owner)** | Raises TKT; performs human read of SKILL.md (Step 4); delivers approval request to Ken; executes installation; maintains skill registry |
| **Shield (Security Owner)** | Performs source verification (Step 2); performs technical SKILL.md security audit (Step 3a); runs weekly audit cron; escalates INC on audit failure |
| **Sage** | Performs scope and accuracy review of SKILL.md (Step 3b); flags scope creep or ambiguous directives |
| **Ken Mun (CTO)** | Sole approver for all skill installations; must provide explicit written approval — silence is not approval |
| **Forge** | Infrastructure support for registry tooling and audit script maintenance |

---

## 5. Controls

### 5.1 Absolute Prohibitions

5.1.1. **No agent shall install, activate, or reference any skill sourced from ClawHub or skills.sh.** This is a hard S3 security control — no exceptions, no overrides.

5.1.2. **No skill shall be installed without a valid TKT reference** raised before any discussion or installation work begins.

5.1.3. **No agent, including Yoda, shall self-approve a skill installation.** Ken Mun must provide explicit written approval.

5.1.4. **No skill shall bypass the mandatory Shield + Sage audit.** The audit shall not be skipped, abbreviated, or marked as complete without Shield and Sage both delivering a verdict.

5.1.5. **No skill shall be installed without a registry entry** in `state/skill-registry.json` immediately following installation.

### 5.2 Mandatory Installation Gate

All custom-built and third-party verified skills **must** complete the following seven steps in order:

#### Step 1 — TKT Raised (Yoda)
- A TKT **must** be raised before any installation discussion or work begins
- TKT **must** include: skill name, purpose, source, author, and justification

#### Step 2 — Source Verification (Yoda + Shield)
Shield **must** confirm all of the following before proceeding:
- Source is NOT ClawHub or skills.sh
- Author is known and identifiable
- Repository/origin has verifiable commit history and is not newly created
- No recent suspicious commits or contributors

#### Step 3 — SKILL.md Audit (Shield + Sage)

**Shield** shall run the audit script and manually verify:
```bash
bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/audit-skill.sh \
  --path /path/to/SKILL.md --strict
```
Shield **must** check for and flag: pipe-to-shell patterns, instruction override language, credential exfiltration patterns, IP-based URLs or URL shorteners, eval of dynamic content, embedded operational shell commands, and unexpected external network call patterns.

**Sage** shall verify: instructions are scoped to the documented purpose, no permission-expanding directives, language is precise and non-ambiguous, all code examples are illustrative only.

#### Step 4 — Human Read (Yoda)
Yoda **must** read the full SKILL.md manually. This is not a scanner — it is a judgment read. Yoda **shall** flag anything that feels off even if automated checks passed.

#### Step 5 — Ken Approval
Yoda **must** deliver the following structured request to Ken and await explicit written reply:

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

Ken **must** reply explicitly. No approval = no installation. Silence = no.

#### Step 6 — Installation and Registry Entry
Immediately following Ken approval:
```bash
bash /Users/ainchorsoc2a/.openclaw/workspace/scripts/skill-registry.sh \
  --add \
  --name "[skill-name]" \
  --path "[install-path]" \
  --source "[URL/origin]" \
  --author "[author]" \
  --approved-by "Ken" \
  --tkt "TKT-NNNN" \
  --chg "CHG-NNNN"
```

A registry entry **shall** be created in the same session as installation — never deferred.

#### Step 7 — Post-Install Validation
- Re-run audit script against installed files
- Confirm skill behaves as documented (no unexpected tool calls)
- Log CHG entry

### 5.3 OpenClaw Version Upgrades
On every OpenClaw npm version upgrade, Yoda + Shield **shall** re-audit all OpenClaw bundled skills and update `lastAudited` in `state/skill-registry.json`.

### 5.4 Ongoing Audit Controls

| Control | Cadence | Owner |
|---------|---------|-------|
| Automated audit of all installed skills | Weekly | Shield (cron) |
| Full re-audit on OC version upgrade | Per upgrade | Yoda + Shield |
| Registry vs installed files reconciliation | Weekly | Yoda |
| Policy review | Annually or on material change | Ken |

### 5.5 Failure Response

| Scenario | Required Response |
|----------|------------------|
| Skill found installed without TKT | Immediate removal. INC raised. Post-mortem required. |
| Audit flags a skill post-install | Remove immediately. INC raised. Ken notified within 1 hour. |
| ClawHub skill found anywhere on AInchors infrastructure | S3 violation. INC raised immediately. Remove within 15 minutes. Full root cause analysis. |
| Skill scanner evasion detected | Manual read is the final defence — cannot be skipped. Escalate to Shield + Ken. |
| Registry entry missing for installed skill | INC raised. Treat as unauthorised installation until provenance confirmed. |

---

## 6. Compliance

### 6.1 How Compliance Is Verified

| Method | Frequency | Owner |
|--------|-----------|-------|
| Weekly automated audit (audit-skill.sh) | Weekly | Shield |
| Registry reconciliation report | Weekly | Yoda |
| Sanctum governance review | Quarterly (QBR) | Shield + Lex + Sage |
| Annual policy review | Annually | Ken |

### 6.2 Non-Compliance Consequences

Any breach of this policy **shall** result in:
1. Immediate remediation (removal of non-compliant skill)
2. INC raised and logged in `state/incident-log.json`
3. Post-mortem within 5 business days
4. Policy or control update if systemic cause identified

### 6.3 Policy Authority

This policy derives authority from:
- AI Charter v1.0 §6 (Security by Default) — "Security controls S1–S7 are the floor, not the ceiling. When a new capability is added, the access model is reviewed before deployment."
- AI Charter v1.0 §6 (Agent Accountability) — agents are bound by least-privilege principles
- AI Governance Framework v1.0 §4 (Agent Lifecycle Governance) — new capabilities require formal review and approval
- Skill-Installation-Policy-v1.0.md (APPROVED by Ken Mun, 2026-05-10, TKT-0141/0142, CHG-0270)
- S3 Security Control (ClawHub prohibition — absolute)
- RULES.md §SKILL GATE (operational enforcement)

Conflicts between this policy and any other document shall be escalated to Ken Mun for resolution. This policy supersedes any informal practice or previous undocumented convention regarding skill installation.

---

## 7. Version History

| Version | Date | Change | Approver |
|---------|------|--------|----------|
| 1.0 | 2026-05-15 | Initial formal policy — derived from Skill-Installation-Policy-v1.0.md. TKT-0137 AC2 batch. | Ken Mun |
