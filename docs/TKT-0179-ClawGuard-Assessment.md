# ClawGuard Assessment — AInchors Nexus Platform
## TKT-0179 | Status: ASSESSMENT COMPLETE | Ken approval required for adoption
## Date: 2026-05-15 | Assessed by: Yoda 🟢

---

## 1. What is ClawGuard?

Third-party security toolkit for OpenClaw autonomous agents. GitHub: `NY1024/ClawGuard`

**Three modules:**
- **Auditor** — Pre-install skill audit (SAST, dependency scanning, anomaly detection)
- **Checker** — Config security audit (credential exposure, permissions, CIS benchmarks)
- **Detect** — Runtime monitoring (command/file/network monitoring, prompt injection detection)

**License:** MIT

---

## 2. What Does It Claim to Do?

| Module | Claim | Nexus Need? |
|---|---|---|
| **Auditor** | Automated SAST + supply chain scan of skills before install | **YES** — Our `audit-skill.sh` is manual regex-based. ClawGuard adds semantic analysis + dependency verification. |
| **Checker** | Config hardening benchmark (CIS, NSA, CISA) | **MAYBE** — We have S1-S7 but no automated benchmark scoring. Could be quarterly review addition. |
| **Detect** | Real-time command/file/network monitoring | **NO** — Single-host, single-user. Runtime monitoring is P2+ territory. |

---

## 3. What Does It Actually Do? (Code Review)

**Limitation:** README only reviewed. Full code audit requires:
1. Clone the repository
2. Review Auditor module source
3. Review Checker module source
4. Check for malicious code in ClawGuard itself (ironic but necessary)
5. Verify no data exfiltration or credential harvesting
6. Check dependency tree for known vulnerabilities

**What we CANNOT assess from README alone:**
- Code quality
- False positive rate
- Performance impact
- Whether the "ML-based anomaly detection" is real or marketing
- Supply chain safety of ClawGuard's own dependencies

---

## 4. Our Current `audit-skill.sh` — Gap Analysis

Our existing audit: **regex-based pattern matching** on SKILL.md text.

```
Checks: 8 patterns
- PIPE_SHELL: curl | bash (BLOCK)
- INSTR_OVERRIDE: prompt injection language (BLOCK)
- CRED_EXFIL: credential extraction (BLOCK)
- EVAL_DYNAMIC: eval $() (FLAG)
- IP_URL: non-localhost IP URLs (FLAG)
- URL_SHORTENER: bit.ly etc (FLAG)
- RM_DANGEROUS: rm -rf / (BLOCK)
- EXFIL_NETCAT: nc outbound (FLAG)
```

**What ClawGuard Auditor adds:**
- Semantic intent analysis (does claimed functionality match actual behavior)
- Supply chain security (dependency verification, CVE scanning)
- ML-based anomaly detection
- Sandbox execution testing

**What ClawGuard Checker adds:**
- CIS/NSA/CISA benchmark compliance
- Permission modeling
- Runtime integrity verification (SHA-256)
- Log forensics

---

## 5. Risk Assessment

| Risk | Level | Mitigation |
|---|---|---|
| **ClawGuard itself is malicious** | Unknown | Full code audit required before any use |
| **False positives** | Unknown | Test on our existing skills before production |
| **Performance impact** | Unknown | Benchmark on OC1 before enablement |
| **Dependency vulnerabilities** | Unknown | CVE scan of ClawGuard dependencies |
| **Data exfiltration** | Unknown | Review network calls in Detect module |
| **Integration complexity** | Low-Medium | MIT license, modular design |

---

## 6. Recommendation

| Approach | Effort | Value | Verdict |
|---|---|---|---|
| **Full ClawGuard adoption** | 2-3 days | Medium | ❌ Not yet — needs full code audit |
| **Adopt Auditor module only** | 0.5-1 day | High | ⏳ After code audit |
| **Fork + adapt Auditor** | 1-2 days | High | ⏳ After code audit |
| **Enhance our audit-skill.sh** | 0.5 day | Medium | ✅ Do now — low risk |
| **Ignore ClawGuard** | 0 | Low | ❌ Missed opportunity |

**My recommendation:**

1. **Immediate:** Enhance our `audit-skill.sh` with semantic checks (see §7). Low effort, no external dependency.
2. **This week:** Clone ClawGuard, run our `audit-skill.sh` against it (meta-audit), review Auditor module code, test on 3 existing skills.
3. **If clean:** Adopt Auditor module as skill-audit enhancement. Checker module as quarterly security review tool.
4. **Defer Detect module** to P2+ (runtime monitoring not needed on OC1).

---

## 7. Immediate Enhancement — audit-skill.sh v2

While we audit ClawGuard, enhance our existing audit:

**Add these checks:**
```
# NEW: Semantic intent check
Does the SKILL.md's stated purpose match its tool usage patterns?
- Example: A skill claiming "weather lookup" that uses exec tool extensively = FLAG

# NEW: Dependency scan
If SKILL.md references external scripts/URLs:
- Check if URL is in allowlist
- Verify URL is HTTPS
- Check if referenced script has been audited

# NEW: Tool scope check
Does the skill use tools outside its declared domain?
- Example: A "weather" skill that writes to workspace-social/ = BLOCK

# NEW: Resource exhaustion check
Does the skill create cron jobs or spawn subagents excessively?
- More than 3 cron jobs = FLAG
- Recursive self-spawn pattern = BLOCK
```

**Effort:** 0.5 day for Yoda/Forge.

---

## 8. Decision (DEFERRED)

Ken approved deferral to P2 security research. TKT-0180 (audit-skill.sh v2) addresses TKT-0142 now.

**Ken — three options:**

| Option | Action | When |
|---|---|---|
| **A. Full audit + adopt** | I clone ClawGuard, audit code, test on our skills, then propose adoption plan | This week |
| **B. Enhance our audit first** | Improve `audit-skill.sh` now. Evaluate ClawGuard adoption as P2 item | Today |
| **C. Defer entirely** | Note for P2 security review. No action now. | — |

**My vote:** B — enhance our audit now (0.5 day, immediate value). Schedule ClawGuard evaluation for Sprint 5 as a security research task (Forge, 1 day).

Reply: **A** | **B** | **C**
