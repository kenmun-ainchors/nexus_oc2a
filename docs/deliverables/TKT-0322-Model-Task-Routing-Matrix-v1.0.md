# Model-Task Routing Matrix v1.0

**Document ID:** TKT-0322
**Version:** 1.0
**Date:** 2026-06-02
**Author:** Platform Architecture (Thrawn)
**Status:** Draft

---

## 1. Decision Tree: Task Complexity → Model Assignment

Every incoming task passes through a 4-tier complexity classifier before dispatch.
The decision tree is evaluated top-to-bottom; first match wins.

```
START
 │
 ├─[Tier 0: ROUTINE]─────────────────────────────────────────────────────
 │  Conditions:
 │    • Heartbeat polls (inbox check, calendar peek, weather)
 │    • Simple file reads/writes (no logic)
 │    • Status queries ("what's the time?", "is X running?")
 │    • Single-step tool calls with no branching
 │    • Reaction triggers (emoji, ACK, template reply)
 │
 │  Model: gemma4:31b-cloud  (default)
 │  Fallback: systemEvent handler (no LLM)
 │  Max tokens: 500
 │  Thinking: off
 │
 ├─[Tier 1: STANDARD]────────────────────────────────────────────────────
 │  Conditions:
 │    • Multi-step but linear workflows
 │    • Information retrieval + synthesis
 │    • Code review (single file, straightforward)
 │    • Documentation generation from templates
 │    • TaskFlow job with ≤3 steps
 │    • Web search + summarise
 │
 │  Model: gemma4:31b-cloud  (default)
 │  Fallback: deepseek-flash (for non-English or longer contexts)
 │  Max tokens: 2,000
 │  Thinking: off (can toggle on if stuck)
 │
 ├─[Tier 2: COMPLEX]─────────────────────────────────────────────────────
 │  Conditions:
 │    • Multi-file refactors
 │    • Architecture / design decisions
 │    • Debugging across ≥2 service boundaries
 │    • Code generation >100 lines
 │    • Multi-agent coordination (≥2 subagents spawned)
 │    • PR review with ≥3 files changed
 │    • Security audit or threat modelling
 │    • Any task where wrong output = data loss or security risk
 │
 │  Model: deepseek-v4-pro  (default)
 │  Fallback: claude-sonnet (when deepseek is unavailable or rate-limited)
 │  Max tokens: 8,000
 │  Thinking: on by default
 │
 ├─[Tier 3: GOVERNANCE]──────────────────────────────────────────────────
 │  Conditions:
 │    • Approval gate decisions (allow/deny)
 │    • Policy compliance checks
 │    • Sensitive data handling rulings
 │    • Escalation verdicts from other agents
 │    • Any task where the model MUST NOT generate creative output
 │
 │  Model: gemma4:31b-cloud  ONLY — no fallback
 │  Max tokens: 300
 │  Thinking: off (hard-locked)
 │  Output constraint: verdict-only (YES/NO + 1-line reason)
 │  Reasoning: stripped from response, not streamed
 │
 └─[UNCLASSIFIED]────────────────────────────────────────────────────────
    → Escalate to platform-arch (Thrawn) for manual routing
    → Log to memory/triage-failures.md
```

### Decision Heuristics (Quick Reference)

| Signal | Tier | Reason |
|--------|------|--------|
| Task contains "heartbeat" or "poll" | 0 | Scheduled idle check |
| Single tool call, no conditionals | 0 | Fire-and-forget |
| ≤2 tools, linear flow | 1 | Simple multi-step |
| 3-5 tools, branching | 2 | Moderate complexity |
| >5 tools OR subagent spawn | 2 | Complex workflow |
| "audit", "security", "threat", "vulnerability" | 2 | Risk surface |
| "approve", "allow", "deny", "policy", "compliance" | 3 | Governance gate |
| Token estimate >4K input | 2 | Context-heavy |
| After 23:00 or before 08:00 local | +1 tier bump | Off-hours caution |

---

## 2. Matrix Table: 14 Agents × Task Types × Model Assignments

| # | Agent (Persona) | Heartbeat / Poll | Info Retrieval | Code / Refactor | Multi-Agent Coord | Security / Audit | Approval Gate | Default Model | Fallback |
|---|-----------------|-------------------|----------------|-----------------|-------------------|------------------|---------------|---------------|----------|
| 1 | **main** (Yoda) | Tier 0 · gemma4:31b | Tier 1 · gemma4:31b | Tier 2 · deepseek-v4-pro | Tier 2 · deepseek-v4-pro | Tier 2 · deepseek-v4-pro | Tier 3 · gemma4:31b | gemma4:31b-cloud | deepseek-flash |
| 2 | **business** (Aria) | Tier 0 · gemma4:31b | Tier 1 · gemma4:31b | N/A (delegates) | N/A (delegates) | N/A (delegates) | Tier 3 · gemma4:31b | gemma4:31b-cloud | deepseek-flash |
| 3 | **social** (Spark) | Tier 0 · gemma4:31b | Tier 1 · gemma4:31b | N/A | N/A | N/A | Tier 3 · gemma4:31b | gemma4:31b-cloud | deepseek-flash |
| 4 | **architect** (Atlas) | Tier 0 · gemma4:31b | Tier 1 · gemma4:31b | Tier 2 · deepseek-v4-pro | Tier 2 · deepseek-v4-pro | Tier 2 · deepseek-v4-pro | Tier 3 · gemma4:31b | deepseek-v4-pro | claude-sonnet |
| 5 | **platform-arch** (Thrawn) | Tier 0 · gemma4:31b | Tier 1 · gemma4:31b | Tier 2 · deepseek-v4-pro | Tier 2 · deepseek-v4-pro | Tier 2 · deepseek-v4-pro | Tier 3 · gemma4:31b | deepseek-v4-pro | claude-sonnet |
| 6 | **biz-process** (Lando) | Tier 0 · gemma4:31b | Tier 1 · gemma4:31b | N/A | N/A | N/A | Tier 3 · gemma4:31b | gemma4:31b-cloud | deepseek-flash |
| 7 | **infra** (Forge) | Tier 0 · gemma4:31b | Tier 1 · gemma4:31b | Tier 2 · deepseek-v4-pro | Tier 2 · deepseek-v4-pro | Tier 2 · deepseek-v4-pro | Tier 3 · gemma4:31b | deepseek-v4-pro | claude-sonnet |
| 8 | **change-mgt** (Mon Mothma) | Tier 0 · gemma4:31b | Tier 1 · gemma4:31b | N/A | N/A | N/A | Tier 3 · gemma4:31b | gemma4:31b-cloud | deepseek-flash |
| 9 | **ahsoka** | Tier 0 · gemma4:31b | Tier 1 · gemma4:31b | Tier 2 · deepseek-v4-pro | Tier 2 · deepseek-v4-pro | Tier 2 · deepseek-v4-pro | Tier 3 · gemma4:31b | deepseek-v4-pro | claude-sonnet |
| 10 | **luthen** | Tier 0 · gemma4:31b | Tier 1 · gemma4:31b | Tier 2 · deepseek-v4-pro | Tier 2 · deepseek-v4-pro | Tier 2 · deepseek-v4-pro | Tier 3 · gemma4:31b | deepseek-v4-pro | claude-sonnet |
| 11 | **security** (Shield) | Tier 0 · gemma4:31b | Tier 1 · gemma4:31b | Tier 2 · deepseek-v4-pro | Tier 2 · deepseek-v4-pro | Tier 2 · deepseek-v4-pro | Tier 3 · gemma4:31b | deepseek-v4-pro | claude-sonnet |
| 12 | **legal** (Lex) | Tier 0 · gemma4:31b | Tier 1 · gemma4:31b | N/A | N/A | Tier 2 · deepseek-v4-pro | Tier 3 · gemma4:31b | gemma4:31b-cloud | deepseek-flash |
| 13 | **qa** (Sage) | Tier 0 · gemma4:31b | Tier 1 · gemma4:31b | Tier 2 · deepseek-v4-pro | N/A | Tier 2 · deepseek-v4-pro | Tier 3 · gemma4:31b | deepseek-v4-pro | claude-sonnet |
| 14 | **governance** (Warden) | Tier 0 · gemma4:31b | Tier 1 · gemma4:31b | N/A | N/A | Tier 2 · deepseek-v4-pro | Tier 3 · gemma4:31b | gemma4:31b-cloud | N/A (locked) |

### Agent Classification Legend

**Light Agents** (primarily Tier 0-1, delegate Tier 2):
- business (Aria), social (Spark), biz-process (Lando), change-mgt (Mon Mothma)

**Heavy Agents** (frequent Tier 2, own complex workflows):
- main (Yoda), architect (Atlas), platform-arch (Thrawn), infra (Forge), ahsoka, luthen, security (Shield), qa (Sage)

**Gate-Only Agents** (Tier 3 is their primary function):
- legal (Lex), governance (Warden)

### Fallback Chain Priority

```
gemma4:31b-cloud  →  deepseek-flash  →  (none, retry or queue)
deepseek-v4-pro   →  claude-sonnet    →  gemma4:31b-cloud (degraded mode)
```

---

## 3. Routing Rules: Escalation & Downgrade

### 3.1 Escalation Triggers (Tier Up)

| Trigger | From → To | Action |
|---------|-----------|--------|
| Task takes >3 turns without completion | Any → Tier+1 | Re-dispatch with upgraded model |
| Error rate >20% on current tier | Any → Tier+1 | Bump model, log incident |
| Task involves PII, credentials, or secrets | Any → Tier 2 minimum | Security-sensitive data = complex tier |
| Subagent spawn requested by a Light Agent | Tier 1 → Tier 2 | Only Heavy Agents coordinate subagents |
| "URGENT" or "CRITICAL" in task metadata | Any → Tier 2 | Urgency = no room for cheap-model mistakes |
| Token context exceeds 6K input | Tier 1 → Tier 2 | gemma4 context window safety margin |
| Night-time (23:00-08:00) + Tier 2 task | Tier 2 → Tier 3 | Off-hours: approve/deny only, no generation |

### 3.2 Downgrade Rules

| Condition | Action |
|-----------|--------|
| Heartbeat response is `HEARTBEAT_OK` (no action needed) | Tier 0 · gemma4:31b, <200 tokens |
| Task completes in 1 turn on Tier 2 | Future similar tasks → Tier 1 unless pattern changes |
| 5 consecutive Tier 1 tasks succeed without escalation | Eligible for Tier 0 classification on next poll cycle |
| Governance verdict is "DENY" | No further tiers — stop processing, return verdict |

### 3.3 Anti-Patterns (Never Do)

- ❌ Never route a governance decision (Tier 3) through deepseek-v4-pro or claude-sonnet
- ❌ Never downgrade a security audit below Tier 2
- ❌ Never spawn subagents from gemma4:31b for non-trivial tasks (use deepseek-v4-pro)
- ❌ Never use thinking mode on Tier 3 — it leaks reasoning on approve/deny decisions

---

## 4. Integration with dispatch-validate.sh (TKT-0323)

The routing matrix is consumed by `dispatch-validate.sh` at task intake.
Integration points:

### 4.1 Pre-Dispatch Validation Hook

```bash
# dispatch-validate.sh reads this matrix (TKT-0322) before any dispatch
# Expected JSON interface:
{
  "agent": "main",
  "taskType": "code_review",
  "estimatedTokens": 3500,
  "containsPII": false,
  "isNighttime": false,
  "urgency": "normal"
}

# Returns routing decision:
{
  "tier": 2,
  "model": "deepseek-v4-pro",
  "fallback": "claude-sonnet",
  "maxTokens": 8000,
  "thinking": true,
  "escalationPath": "claude-sonnet → gemma4:31b-cloud (degraded)"
}
```

### 4.2 Validation Gates (checked in order)

1. **Agent exists?** → Agent name must be in the 14-agent registry
2. **Task classified?** → Task type must resolve to a tier
3. **Model allowed for agent?** → Cross-reference matrix table
4. **Tier 3 lock?** → If governance, reject any non-gemma4 model assignment
5. **Fallback available?** → Confirm fallback model is reachable before dispatch
6. **Token budget check** → `maxTokens` must not exceed tier limit

### 4.3 Runtime Override Protocol

`dispatch-validate.sh` accepts an `--override-tier=N` flag for manual intervention.
All overrides are logged to `memory/routing-overrides.md` with:
- Timestamp
- Overriding agent/session
- Original tier → Overridden tier
- Reason (mandatory, cannot be blank)

### 4.4 TKT-0323 Dependency

TKT-0323 (`dispatch-validate.sh`) is the **runtime enforcer** of this matrix.
- TKT-0322 defines the rules (this document)
- TKT-0323 executes them (the script)
- TKT-0323 MUST NOT deviate from this matrix without a TKT-0322 revision

---

## 5. Cost Impact Analysis

### 5.1 Current Baseline (Estimated)

| Metric | Value |
|--------|-------|
| Daily token consumption | ~79,000 tokens |
| gemma4:31b share | ~35% (27,650 tokens) |
| deepseek-v4-pro share | ~55% (43,450 tokens) |
| claude-sonnet share | ~10% (7,900 tokens) |
| Avg tokens/task | ~1,800 |
| Tasks/day | ~44 |

### 5.2 Target After Routing Matrix

| Metric | Value | Delta |
|--------|-------|-------|
| Daily token consumption | ~40,000 tokens | **-49%** |
| gemma4:31b share | ~65% (26,000 tokens) | +30pp |
| deepseek-v4-pro share | ~30% (12,000 tokens) | -25pp |
| claude-sonnet share | ~5% (2,000 tokens) | -5pp |
| Avg tokens/task | ~900 | -50% |
| Tasks/day | ~44 | unchanged |

### 5.3 How the Savings Happen

1. **Tier 0 absorbs heartbeats and polls** — these were ~30% of tasks running on deepseek-v4-pro. Moving them to gemma4:31b (500 tokens vs 2,000) cuts ~18,000 tokens/day.

2. **Tier 3 strips reasoning tokens** — governance verdicts drop from ~1,500 tokens (with reasoning) to ~200 tokens (verdict-only). At ~5 governance calls/day: saves ~6,500 tokens.

3. **Tier limits cap waste** — max 500/2,000/8,000/300 per tier prevents runaway token burn on simple tasks.

4. **Light Agents stay light** — business, social, biz-process, change-mgt never touch Tier 2 models. They were occasionally burning deepseek tokens on simple summarisation.

5. **Fallback reduction** — explicit fallback chains reduce retry-token waste when a model is unavailable.

### 5.4 Monitoring Metrics

Track these weekly after rollout:

| Metric | Alert Threshold |
|--------|-----------------|
| % tasks on correct tier | <90% → investigate misclassification |
| Tier 2 token avg | >8,000 → limit enforcement failing |
| Tier 3 reasoning leak | >0 → blocker, fix immediately |
| Fallback rate | >5% → model availability issue |
| Override rate | >3% → matrix needs tuning |

---

## 6. Implementation Notes

### 6.1 Agent Configs to Update

Each agent's config file needs a `routing` block added:

| Agent | Config File (estimated path) | Change |
|-------|------------------------------|--------|
| main (Yoda) | `agents/main/config.yaml` | Add routing block, default: gemma4, fallback: deepseek-flash |
| business (Aria) | `agents/business/config.yaml` | Add routing block, lock to gemma4:31b only |
| social (Spark) | `agents/social/config.yaml` | Add routing block, lock to gemma4:31b only |
| architect (Atlas) | `agents/architect/config.yaml` | Add routing block, default: deepseek-v4-pro |
| platform-arch (Thrawn) | `agents/platform-arch/config.yaml` | Add routing block, default: deepseek-v4-pro |
| biz-process (Lando) | `agents/biz-process/config.yaml` | Add routing block, lock to gemma4:31b only |
| infra (Forge) | `agents/infra/config.yaml` | Add routing block, default: deepseek-v4-pro |
| change-mgt (Mon Mothma) | `agents/change-mgt/config.yaml` | Add routing block, lock to gemma4:31b only |
| ahsoka | `agents/ahsoka/config.yaml` | Add routing block, default: deepseek-v4-pro |
| luthen | `agents/luthen/config.yaml` | Add routing block, default: deepseek-v4-pro |
| security (Shield) | `agents/security/config.yaml` | Add routing block, default: deepseek-v4-pro |
| legal (Lex) | `agents/legal/config.yaml` | Add routing block, Tier 3 locked |
| qa (Sage) | `agents/qa/config.yaml` | Add routing block, default: deepseek-v4-pro |
| governance (Warden) | `agents/governance/config.yaml` | Add routing block, Tier 3 locked, no fallback |

### 6.2 Config Schema (to add to each agent config)

```yaml
routing:
  matrix_version: "1.0"
  matrix_doc: "TKT-0322"
  default_model: "gemma4:31b-cloud"      # or "deepseek-v4-pro" for Heavy Agents
  default_tier: 1                         # or 2 for Heavy Agents
  allowed_tiers: [0, 1, 3]               # Light Agents: [0, 1, 3]; Heavy: [0, 1, 2, 3]
  fallback_chain:
    - model: "deepseek-flash"
      condition: "context_length_exceeded OR non_english"
    - model: "claude-sonnet"
      condition: "rate_limited OR unavailable"
  tier_3_lock:
    model: "gemma4:31b-cloud"
    max_tokens: 300
    thinking: false
    output_mode: "verdict_only"
  token_budgets:
    tier_0: 500
    tier_1: 2000
    tier_2: 8000
    tier_3: 300
```

### 6.3 Rollout Phases

| Phase | Duration | Scope | Success Criteria |
|-------|----------|-------|------------------|
| **Phase 1: Config Audit** | 1 day | Read all 14 agent configs, confirm paths | All configs located |
| **Phase 2: Light Agents** | 2 days | Update business, social, biz-process, change-mgt | 0 Tier 2 calls from these agents |
| **Phase 3: Heavy Agents** | 3 days | Update main, architect, platform-arch, infra, ahsoka, luthen, security, qa | Tier routing matches matrix |
| **Phase 4: Gate Agents** | 1 day | Update legal, governance with Tier 3 lock | 0 reasoning leaks, verdict-only output |
| **Phase 5: dispatch-validate.sh** | 2 days | Implement TKT-0323 validation script | All dispatches validated against matrix |
| **Phase 6: Monitor** | 1 week | Track token usage, tier distribution, fallback rate | 40K tokens/day target hit |

### 6.4 Rollback Plan

If token usage increases or task quality degrades:
1. Revert agent config `routing` blocks to `default_model` only (no tiers)
2. Disable `dispatch-validate.sh` validation hooks
3. Restore pre-matrix configs from git (`git revert` on config branch)
4. Document root cause in `memory/routing-rollback-YYYY-MM-DD.md`

### 6.5 Related Tickets

| Ticket | Dependency | Relationship |
|--------|------------|--------------|
| TKT-0322 | — | This document (definition) |
| TKT-0323 | TKT-0322 | Runtime enforcement script |
| TKT-0324 | TKT-0322, TKT-0323 | Monitoring dashboard for tier distribution |
| TKT-0325 | TKT-0322 | Agent config migration scripts |

---

*End of Model-Task Routing Matrix v1.0*
