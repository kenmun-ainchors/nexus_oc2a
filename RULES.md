# KIMI PLATFORM MANDATE — NON-NEGOTIABLE RULE
# Effective: 2026-05-17 15:17 AEST
# Authority: Ken Mun (CTO) — mandatory and persistent
# CHG-0373

## Rule Statement

**ALL agent execution across the AInchors Nexus platform SHALL use `ollama/kimi-k2.6:cloud` as the primary model until explicitly overridden by Ken.**

This rule is:
- **MANDATORY** — No exceptions without Ken's explicit written approval
- **NON-NEGOTIABLE** — Agents may not self-override or fallback without approval
- **PERSISTENT** — Remains active indefinitely until Ken issues `KIMI MANDATE LIFTED` keyword
- **PLATFORM-WIDE** — Applies to all agents, all sessions, all crons, all channels

## Scope

| Component | Requirement |
|-----------|-------------|
| **Main session (webchat)** | kimi primary, Sonnet ONLY with explicit Ken approval per task |
| **Telegram sessions** | kimi primary, Sonnet ONLY with explicit Ken approval per task |
| **Cron jobs** | kimi ONLY — no Anthropic models in any cron payload |
| **Sub-agents** | kimi primary, with kimi safety net (3-level fallback) |
| **Background tasks** | kimi ONLY |
| **Outage handling** | kimi ONLY — no Sonnet fallback during outages |

## Definition of Done (DoD)

**Work is NOT considered complete until:**

1. **Executed correctly** — The actual task was performed, not just planned or described
2. **Verified by tool** — File writes confirmed via `read`, commits confirmed via `git log`, API calls confirmed via response
3. **State validated** — JSON state files parse correctly, no syntax errors
4. **Observable output** — Human-verifiable result exists (file, commit, Notion page, etc.)
5. **Ken confirmation** — For critical work, Ken explicitly confirms completion

**Anti-patterns that FAIL DoD:**
- ❌ "I will create X" — Planning is not execution
- ❌ "X has been created" without file hash, commit ID, or URL
- ❌ Partial execution (e.g., wrote file but didn't commit)
- ❌ Tool error ignored (e.g., `jq` parse error, `curl` failure)
- ❌ Assumption-based completion ("should work" without testing)

## Enforcement

### Warden Check (every 15 min)
- Verify all agents are on kimi or approved model
- Flag any agent on non-kimi model without CHG approval
- Escalate to Yoda → Ken immediately

### CI/CD Gate
- Any PR/commit modifying `.openclaw.json` model configs → blocked until Ken approval
- Any cron with non-kimi model → auto-flagged in audit

### Agent Self-Check
- Before executing: "Am I on kimi? If not, why?"
- After executing: "Did I verify the result? Can Ken see it?"
- If unsure: ASK Ken, don't assume

## Exceptions

| Scenario | Approval Required | Documented In |
|----------|-----------------|---------------|
| Sonnet for critical security review | Ken explicit per-task | CHG entry |
| Sonnet for client-facing content | Ken explicit per-task | CHG entry |
| Sonnet for complex multi-ticket routing | Ken explicit per-task | CHG entry |
| Sonnet for CHG decisions | Ken explicit per-task | CHG entry |

**Default: NO exceptions. All work on kimi.**

## Verification Commands

```bash
# Check current model
openclaw status | grep model

# Check agent model configs
grep -r "anthropic" ~/.openclaw/workspace/state/ || echo "No Anthropic refs"

# Check cron models
openclaw cron list | grep "anthropic" || echo "No Anthropic crons"
```

## Compliance Log

| Date | Check | Result | Verifier |
|------|-------|--------|----------|
| 2026-05-17 | Initial mandate | ✅ All agents on kimi | Ken |

## Activation

**Activated:** 2026-05-17 15:17 AEST by Ken Mun via WebChat
**Deactivation keyword:** `KIMI MANDATE LIFTED` (only Ken can issue)
**CHG reference:** CHG-0373

---

**This rule supersedes all prior model routing policies until lifted.**
