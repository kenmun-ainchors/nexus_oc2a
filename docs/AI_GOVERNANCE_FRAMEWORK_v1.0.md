# AInchors AI Governance Framework

> ⚠️ **SUPERSEDED IN PART — Model guidance updated.** This v1.0 framework remains APPROVED for governance structure, HITL tiers, and risk taxonomy. However, its model-tier assignments (Anthropic Sonnet/Haiku/Opus) are deprecated. Current canonical model assignments are in `state/model-policy.json` v3.0 and `docs/Aevlith-Technology-Strategy-Roadmap-v1.1.md` §7. Anthropic is permanently parked per CHG-0502 until Ken issues "CLAUDE ACTIVATE". Updated under CHG-0855.

> v1.0 | 2026-05-04 | Status: APPROVED — Ken Mun, CTO, 2026-05-04 17:50 AEST
> Owner: Ken Mun, CTO — Ainchor Solutions Pty Ltd
> Reference: TKT-0052

---

**ITIL Practice:** Governance

## 1. Purpose

The [AI Charter v1.0](./AI_CHARTER_v1.0.md) establishes what AInchors stands for — principles, permissions, HITL tiers, data ethics, and agent accountability. This framework is the operational layer that sits beneath it. It answers a different question: *how* is governance actually enforced, monitored, and evolved day-to-day?

Where the Charter sets boundaries, this framework describes the machinery that keeps agents inside them. Every mechanism described here is live in P1 unless explicitly noted as a P2 pre-condition. This document is practitioner-level and auditable — it references real system components by name.

---

## 2. Governance Structure

### 2.1 Hierarchy

```
Ken Mun (Owner — ultimate authority)
  └─ Yoda (Lead Enforcer — operational accountability)
       └─ Warden (Automated Monitor — continuous model compliance)
            └─ Shield / Lex / Sage (Pre-action Triad — high-risk gate)
                 └─ All other agents (Governed — operate within defined bounds)
```

Each level has defined authority. No level may escalate itself or bypass the level above it.

### 2.2 Responsibilities

| Role | Governance Responsibility |
|------|--------------------------|
| **Ken Mun** | Final approval authority. Owns the Charter, this framework, and model-policy.json. Signs off all Tier 3 actions, agent scope changes, new providers, new platform phases. |
| **Yoda** | Day-to-day governance enforcement. Receives all Warden escalations. Remediates model drift. Owns CHG log hygiene. Escalates to Ken for anything outside defined authority. |
| **Warden** | Continuous automated monitor. Runs every 15 minutes. Detects model drift, policy violations, and config anomalies. Escalates to Yoda within one heartbeat of a breach. |
| **Shield** | Security review leg of the pre-action triad. Evaluates high-risk operations for security implications before execution. |
| **Lex** | Legal/compliance review leg of the pre-action triad. Flags APP obligations, contract risk, and data handling concerns. |
| **Sage** | Ethics/QA review leg of the pre-action triad. Checks content accuracy, output quality, and policy alignment. |
| **All other agents** | Operate within SOUL.md + RULES.md constraints. Log all significant actions. Escalate anything outside defined scope to Yoda. |

### 2.3 Escalation Path

| Trigger | Escalates To | Expected Response |
|---------|-------------|-------------------|
| Agent encounters task outside its defined scope | Yoda | Yoda assesses, handles or escalates to Ken |
| Warden detects model drift or policy violation | Yoda (via Telegram alert) | Yoda remediates within 1 heartbeat (30 min) |
| Yoda encounters ambiguous authority or material risk | Ken | Ken decides before execution proceeds |
| 3+ consecutive health check failures OR failure > 1 hour | Ken + Angie (via Aria) | Immediate human review |
| Any Tier 3 action | Ken | Explicit approval before execution. Silence is not approval. |
| Incident (unexpected behaviour, data handling error, failed safety check) | Yoda logs → Ken notified | Root cause within 24 hours |

---

## 3. Model Governance

### 3.1 Model Approval Process

New models are not added to the platform by configuration change alone. The process is:

1. **PoC** — Yoda (or delegated agent) runs a structured benchmark: quality score (1–5), average latency, cost profile, data sensitivity constraints.
2. **Benchmark report** — documented in a state file or Notion AKB entry. Minimum: quality ≥ 3.5/5 for production eligibility.
3. **Ken approval** — explicit sign-off in webchat or Telegram using keyword `POLICY CHANGE APPROVED`.
4. **Allowlist update** — `state/model-policy.json` updated. `state/critical-config-baseline.json` updated to match.
5. **CHG log** — entry written to `CHANGELOG.md` with model name, approval context, and per-agent assignments.
6. **MEMORY.md update** — Yoda records the new model and rationale for session continuity.

Any provider integration that doesn't follow this process is a governance violation, regardless of who initiated it.

### 3.2 Model Policy

The canonical model policy lives at `state/model-policy.json`. Warden enforces it. The key structural rules:

**Per-agent model assignment:**
- Each agent has a `requiredModel`, `allowedModels`, and `prohibitedModels` list.
- Interactive sessions must use `requiredModel`. No exceptions without a CHG entry.
- Cron tasks may use a broader `allowedInCrons` list — still bounded by the agent's policy.

**Data sensitivity tiers:**
- `high` — Ken-facing interactive sessions, governance reviews (Shield/Lex/Sage), anything touching PII or client data. Anthropic (Sonnet) only.
- `medium` — Bounded subtasks, orchestration sub-steps, internal reporting. Anthropic (Sonnet or Haiku) only.
- `low` — Non-sensitive background tasks: research synthesis, marketing copy, config reads, CI benchmarking. Ollama Cloud eligible.

**Ollama Cloud constraint:** `kimi-k2.6:cloud`, `deepseek-v4-flash:cloud`, and `deepseek-v4-pro:cloud` are restricted to `data_sensitivity = low` tasks only. No PII. No legal content. No client data. No financial decisions. Warden enforces this gate on every cron invocation.

**Current per-agent summary:**

| Agent | Interactive Model | Ollama Cloud in Crons? | Opus? |
|-------|------------------|------------------------|-------|
| Yoda (main) | Sonnet | Yes (low-sensitivity only) | Escalation only (Ken approval) |
| Aria (business) | Sonnet | Yes (low-sensitivity only) | Prohibited |
| Spark (social) | kimi-k2.6:cloud | Yes | Prohibited |
| Shield (security) | Sonnet | No | Prohibited |
| Lex (legal) | Sonnet | No (prohibited) | Prohibited |
| Sage (QA) | Sonnet | Yes (non-sensitive QA only) | Prohibited |
| Warden | Sonnet | deepseek-v4-flash:cloud for crons (CREST v1.3 governance role) | Prohibited |
| Forge (infra) | Sonnet | Yes (CI tasks only) | Prohibited |

Full details: `state/model-policy.json`.

### 3.3 Model Drift Detection

Warden runs every 15 minutes via cron. It performs 9 checks on every live agent:

1. Active model matches `requiredModel` in policy
2. No prohibited model in use (interactive or cron)
3. Cron model is in `allowedInCrons` list
4. Ollama Cloud models are only used for `data_sensitivity = low` tasks
5. Gemma4 usage is restricted to the cron allowlist (`gemma4AllowedCronNames`)
6. Gemma4 is not used in prohibited cron name patterns (standup, close, journal, blog, alert, telegram)
7. No deprecated models in use (`ollama/gemma4:26b`, `ollama/gemma4:e4b`)
8. `model-policy.json` hash matches `critical-config-baseline.json` (detects unauthorised edits)
9. Agent config in `openclaw.json` matches the policy for that agent

**On breach:**
- Warden writes to its state file and sends a Telegram alert to Yoda within one heartbeat cycle (≤ 30 min).
- Yoda remediates: identifies the drift source, corrects the config, logs a CHG entry, and notifies Ken.
- If Yoda cannot remediate within one additional heartbeat, Ken is alerted directly.

**Note:** Formal Warden escalation thresholds (exact criteria, sensitivity levels, suppression rules) are a mandatory P2 pre-condition. See TKT-0061.

### 3.4 CI Framework

Two concurrent cycles run continuously to evaluate and improve model selection:

**Cycle A — Shadow evaluation (always on):**
- Duration: 7 days rolling.
- Any candidate model runs in shadow mode alongside the production model on real tasks.
- Output quality, latency, and cost are logged but shadow results do not influence production execution.
- Managed by Forge. Results reviewed by Yoda.

**Cycle B — Concurrent evaluation (week 2 of PoC):**
- Candidate model runs concurrently with production on a subset of eligible tasks.
- Quality differential, error rate, and cost delta are tracked.
- Yoda compiles a weekly report to Ken. Ken decides whether to promote, extend, or reject.

Neither cycle may promote a model without completing the approval process in Section 3.1.

### 3.5 Model Retirement

When a model is retired from the platform:

1. Yoda or Ken initiates via a CHG entry with rationale (provider deprecation, quality failure, security concern, cost).
2. Model added to `deprecatedModels` list in `model-policy.json`.
3. All agent entries referencing the model are updated: removed from `allowedModels`, `allowedInCrons`, added to `prohibitedModels` where appropriate.
4. `critical-config-baseline.json` updated.
5. Any active cron jobs referencing the model are updated or disabled.
6. MEMORY.md updated with retirement note and date.

Current deprecated models: `ollama/gemma4:26b`, `ollama/gemma4:e4b` (retained as emergency fallback in limited cases — see model-policy.json).

---

## 4. Agent Lifecycle Governance

### 4.1 Agent Creation

Before a new agent is deployed, the following must exist:

| Requirement | Detail |
|-------------|--------|
| `SOUL.md` | Compact identity file, ≤ 5,000 characters. Defines name, role, traits, non-negotiable rules. |
| `RULES.md` | Operational procedures. Covers: task intake, escalation, logging, model routing, any agent-specific workflows. |
| Workspace directory | Isolated workspace under `~/.openclaw/workspace/` or defined mount path. |
| `openclaw.json` registration | Agent entry added with correct `id`, `model`, `description`, and any cron definitions. |
| Notion AKB entry | Created in Holocron › Platform Operations › Agents. Includes role, owner, deployment date, scope summary. |
| CHG log entry | Documents the creation decision, agent scope, approved by Ken, date. |
| Model policy entry | Agent added to `state/model-policy.json` with complete model assignments before first run. |

Ken approval is required before any new agent is activated. No agent operates on-platform without a corresponding policy entry.

### 4.2 Agent Change

**SOUL.md or RULES.md changes:**
- Any edit requires a CHG log entry.
- Ken must be made aware. For minor clarifications (typo, formatting): Yoda informs Ken in next standup.
- For material changes (new behaviour, changed constraints, modified escalation logic): Ken must acknowledge before the change takes effect.

**Scope changes (new tools, new channels, new permissions):**
- Require explicit Ken approval before implementation.
- Model policy entry updated if change affects model routing.
- Pre-risky-op checkpoint (per RULES.md) required.

**All changes tracked in:** `CHANGELOG.md` with agent name, change description, CHG reference, and approver.

### 4.3 Agent Retirement

When an agent is decommissioned:

1. All cron jobs for that agent disabled (not deleted — retained for audit).
2. Agent workspace archived to `~/.openclaw/archive/<agent-id>/YYYY-MM-DD/`.
3. `openclaw.json` entry updated: agent set to `disabled: true`. Not deleted.
4. `state/model-policy.json` entry marked `status: retired` with retirement date.
5. CHG log entry written with rationale and Ken sign-off.
6. Notion AKB entry updated: status → Retired, retirement date recorded.
7. Any Telegram channels or integration hooks the agent used are reviewed and closed if no longer needed.

Retired agents are not deleted. They are archived. This is an audit requirement.

### 4.4 Agent Performance Standards

Performance is assessed per agent type. These are the minimum "healthy" thresholds:

| Agent Type | Metric | Healthy Threshold |
|------------|--------|-------------------|
| **Cron agents** (Warden, Forge, health checks) | Cron success rate | ≥ 95% over 7-day rolling window |
| **Interactive agents** (Yoda, Aria) | Escalation rate to Ken | < 20% of tasks in a week (high escalation = scope/rule gap) |
| **Governance triad** (Shield, Lex, Sage) | Review turnaround | Pre-action reviews complete before execution begins |
| **Content agents** (Spark) | Human approval rate | 100% (no content published without explicit approval) |
| **All agents** | Audit trail completeness | 100% of Tier 2/3 actions logged before or during execution |
| **All agents** | Incident rate | ≤ 1 unplanned incident per 30-day period per agent |

Performance data sourced from: `obs.db` (action logs), `state/agent-status.json`, auto-heal logs (`state/auto-heal-*.log`), and Warden cron reports.

---

## 5. LLM-Specific Risk Register

Current as of P1. Likelihood and impact are assessed for the P1 internal-only environment.

**Tier definitions:** 1 = Critical (immediate action required), 2 = High (mitigated but monitored), 3 = Medium (accepted with controls)

| Risk | Tier | Description | Existing Mitigation | Residual Risk | Owner |
|------|------|-------------|---------------------|---------------|-------|
| **1. Hallucination** | 2 | Agent fabricates facts, metrics, or sources. Presented as confirmed. | Charter Principle 2 (honesty). Warden quality checks. Sage pre-publish review. Min 2-source rule in SOUL.md. Human review for all external-facing content. | Low for internal tasks. Medium for published content before Sage gate is fully operational. | Sage / Yoda |
| **2. Prompt injection** | 2 | Malicious content in external inputs (web fetch, user message, email) causes unintended agent behaviour. | Tool scope restrictions per agent. Shield pre-action review for high-risk ops. No agent executes shell from untrusted input without explicit approval. S1–S7 security controls. | Medium — Shield review is manual for now; no automated injection detection. | Shield |
| **3. Data leakage** | 1 | Sensitive data sent to wrong model tier or external API. E.g. PII routed to Ollama Cloud. | `data_sensitivity` gate in model-policy.json. Warden enforces Ollama Cloud restriction. Lex prohibited from Ollama Cloud entirely. No client data in any cloud API. | Low for P1 (no external clients). Gate is config-enforced, not code-enforced — residual gap until Warden threshold formalisation (TKT-0061). | Warden / Yoda |
| **4. Model drift** | 2 | Provider-side model update changes behaviour without a config change. E.g. Anthropic silently updates Sonnet. | Warden 15-min checks. CI Framework Cycle A shadow evaluation detects quality shifts over 7 days. Baseline hash check detects local config drift. | Medium — provider-side silent updates cannot be fully prevented. Detection window is up to 7 days (CI cycle). | Warden / Forge |
| **5. Cost runaway** | 2 | Runaway cron loop or unbounded sub-agent spawn causes API cost spike beyond A$500 cap. | A$400 alert / A$500 hard cap enforced by credit alert check on every response. 3-tier alert system (Ken + Angie via Aria). Cron schedules are explicit and bounded. | Low for Anthropic (hard cap). Medium for Ollama Cloud (Ollama Pro flat-rate but no per-task metering). | Yoda |
| **6. Jailbreak** | 2 | Agent bypasses its own constraints via adversarial prompt in user input or sub-agent communication. | SOUL.md constraints are model-system-prompt level. Charter explicit prohibition on self-modification. Shield review for unusual requests. Yoda escalation for scope-edge cases. | Medium — no automated jailbreak detection. Relies on agent self-enforcement and human review. | Shield / Yoda |
| **7. Stale context** | 3 | Agent acts on outdated state (old task file, stale memory) and makes wrong decisions. | MEMORY.md + daily logs updated each session. Active task state in `state/active-work.json`. Pre-risky-op checkpoint requires state flush before execution. | Low — primarily managed by operational discipline. Risk increases as agent count grows. | Yoda |
| **8. Supply chain** | 3 | Model provider outage or compromise affects platform operations. E.g. Anthropic API down; Ollama Cloud breach. | Gemma4 local fallback for Yoda crons when Anthropic unavailable. Aria enters standby (not fallback to unknown model) if Anthropic down. Ollama Cloud scoped to low-sensitivity tasks — breach impact limited. | Medium — no formal provider SLA review process. Local fallback covers basic ops but not full capability. | Ken / Yoda |
| **9. Over-automation** | 2 | Agent acts outside intended scope due to ambiguous instructions, broad tool access, or inference of approval. | Tier 3 approval gate. Silence-is-not-approval rule (Charter Section 4). Escalation path for scope-edge cases. HITL tiers defined at task definition, not agent discretion. | Medium — tool scope (`tools: null` for most agents) is a known gap. All agents currently have broad tool access. This is **S4 gap** — unresolved before P2. | Ken (decision required) |
| **10. Audit gap** | 3 | Action taken without sufficient logging for post-hoc review. No trail in obs.db, CHANGELOG.md, or Notion. | Dual-log requirement (Charter Section 6): every significant action logged in ≥ 2 of: obs.db, CHANGELOG.md, Notion AKB. Tier 3 logs required before execution. | Low for high-risk actions. Medium for routine Tier 1/2 actions — completeness of obs.db logging not yet formally verified. | Yoda / Warden |

---

## 6. Audit and Compliance

### 6.1 What Is Audited

| Layer | System | What's Captured |
|-------|--------|-----------------|
| Agent actions | `obs.db` | Every significant agent action: timestamp, agent, action type, outcome, context |
| Config changes | `CHANGELOG.md` | Every CHG entry: what changed, who approved, when, why |
| Model behaviour | Warden state files (`state/warden-*.json`) | Per-agent model compliance status, drift detections, last-check timestamp |
| Content pre-publish | Shield/Lex/Sage triad logs | Review decisions, flags raised, approval chain before any external content action |
| Cost | `state/api-cost-actuals.json` | Per-day API spend against thresholds |
| Health | `state/auto-heal-*.log` + `state/agent-status.json` | Cron success/failure history, recovery actions |
| Incidents | `scripts/incident-log.sh` output + Notion Incidents | Every logged incident with root cause and corrective action |

### 6.2 Audit Frequency

| Scope | Frequency | Who |
|-------|-----------|-----|
| Warden compliance checks | Every 15 minutes | Automated (Warden) |
| Auto-heal validation | Daily | `scripts/auto-heal.sh` |
| Cost snapshot | Daily 12:00 PM | Yoda (cron) |
| Weekly model CI report | Weekly (Forge → Yoda → Ken) | Forge compiles, Ken reviews |
| Monthly SLA report | Monthly 28th | Yoda generates, Ken reviews |
| Asset registry review | Weekly Sunday 5PM | `scripts/asset-review.sh` |
| Model strategy + Gemma4 review | Monthly 28th | Ken sign-off required |
| Full asset audit | Quarterly | Ken sign-off required |
| Incident-triggered audit | Ad-hoc (within 24h of incident) | Yoda investigates, Ken notified |

### 6.3 Who Reviews

**P1:** Ken Mun directly. No delegation. All audit outputs (weekly CI report, monthly SLA, incident reviews) go to Ken via Telegram or webchat.

**P1:** Ken Mun only. No delegation.

**P2 Audit Committee (structure to be confirmed before P2 live — Ken acting in all roles):**

| Role | Responsibility | P1 Acting | P2 Placeholder |
|------|---------------|-----------|----------------|
| Governance Chair | Final authority on all Tier 3 actions, major incidents, policy changes | Ken Mun | Ken Mun (permanent) |
| Technical Review | Weekly CI report review, model drift, cron health | Ken Mun | TBC — confirm before P2 |
| Legal/Compliance Review | APP compliance, DPA review, Lex output sign-off | Ken Mun | TBC — confirm before P2 |
| Business Review | Client-facing governance, Aria operational audit | Ken Mun | Angie Foong (Aria owner) |
| External Audit | Independent P2 evidence pack review (optional P1, mandatory if regulated client) | N/A | TBC — confirm at P2 kickoff |

**Rule:** All placeholder roles must be confirmed by Ken before P2 live. No role may be filled by an AI agent alone — human owners required for all committee seats.

### 6.4 P2 Compliance Checkpoints

These are hard gates. No external client is onboarded until all are resolved:

| Checkpoint | Owner | Reference |
|------------|-------|-----------|
| APP gap analysis completed by Lex | Lex | Charter Section 5 |
| Client DPA template drafted and Ken-approved | Lex | TKT-0060 |
| Warden escalation thresholds formally documented and approved | Warden / Ken | TKT-0061 |
| Tier 3 delegation model defined (who can approve what on Ken's behalf) | Ken | Charter Section 4 |
| S4 tool scope defined per agent (currently `tools: null` for all — see Yoda Notes) | Ken / Shield | Known gap |
| P2 audit committee structure defined | Ken | Section 6.3 above |

### 6.5 P2 Governance Evidence Pack

The following documents constitute the minimum evidence package required for P2 external auditability:

1. `docs/AI_CHARTER_v1.0.md` (approved)
2. `docs/AI_GOVERNANCE_FRAMEWORK_v1.0.md` (this document)
3. `state/model-policy.json` (current approved version)
4. Warden compliance reports (last 90 days)
5. Monthly SLA history (last 3 months)
6. Incident register (all incidents from P1 onwards)
7. Client DPA (TKT-0060)
8. APP gap analysis (Lex output)
9. CHG log extract (CHANGELOG.md entries relevant to governance decisions)

---

## 7. Third-Party AI Governance

### 7.1 Active Providers

**Anthropic (Claude — Sonnet, Haiku, Opus)**
- Primary provider. Handles all high/medium sensitivity tasks.
- Pay-per-token. **Dedicated cost metering required — metered against A$500/month hard cap, alerted at A$400.** (Ken confirmed: all non-Ollama providers must have defined cost metering. 2026-05-04.)
- Risk: API pricing changes, provider-side model updates (silent drift — see Risk 4), model deprecation.
- Mitigation: cost alerts at A$400, hard cap at A$500. CI framework detects quality drift. Retirement process handles deprecations.
- Data residency: requests processed by Anthropic (US). AInchors does not pass client PII to Anthropic without explicit client consent + DPA.

**Ollama Cloud (kimi-k2.6:cloud, deepseek-v4-flash:cloud, deepseek-v4-pro:cloud)**
- Tier 2. Low-sensitivity tasks only.
- Flat-rate Ollama Pro account (`accounts@ainchors.com`), $20/month.
- **Cost metering: flat monthly rate accepted — no per-task metering required for Ollama Cloud.** (Ken confirmed 2026-05-04.)
- Risk: data residency unclear (providers are Chinese-origin models; Ollama routes to their cloud infrastructure). Quality variance. Potential availability issues.
- Mitigation: `data_sensitivity` gate enforced by Warden. No PII, no legal, no client data. If Ollama Cloud is unavailable, affected agents fall back to Haiku or Sonnet.
- **P2 pre-condition (TKT-0063):** Before P2 live, one of the following must be resolved: (A) formal DPA with Ollama Cloud, (B) explicit exclusion/acceptance of offering for client workloads, or (C) BYOK model where clients supply their own Ollama API keys. Lex to assess and present recommendation.

**Gemma4 (local — gemma4:e2b, gemma4:26b)**
- Tier 3/Emergency. Local model, zero data egress.
- Not yet live in production (post-OC2, ETA July 2026).
- Risk: Quality limitations for complex tasks. No provider risk (fully local).
- Governance: `gemma4AllowedCronNames` whitelist enforces where it can run. Prohibited from interactive, standup, journal, blog, and alert crons.

### 7.2 Provider Change Process

Adding a new AI provider is not a configuration change. It is a platform governance event:

1. Yoda (or delegated agent) conducts PoC: quality benchmark, latency, cost model, data residency assessment.
2. Shield reviews security and data residency implications.
3. Lex reviews for APP obligations and any DPA requirements.
4. Ken approves explicitly (`POLICY CHANGE APPROVED`).
5. `state/model-policy.json` updated with provider and per-agent assignments.
6. Warden policy updated to enforce any new sensitivity gates.
7. CHG log entry written.
8. If provider requires a DPA: DPA drafted and signed before production use.

No provider is used in production — even for low-sensitivity tasks — without completing this process.

---

## 8. Governance Evolution

### 8.1 How This Framework Gets Updated

1. Any agent or Ken proposes a change with rationale.
2. Lex reviews for legal/compliance implications.
3. Sage reviews for ethics and policy alignment.
4. Ken approves.
5. Version bumped (minor: x.Y patch; major: restructure or new section).
6. CHG log entry written with change description and approval reference.
7. Canonical location (Notion Holocron › Platform Operations) updated.
8. All documents that reference this framework checked for consistency.

Minor clarifications (typo, formatting, clarifying wording without changing intent) do not require Lex/Sage review. Material changes to process, risk tiers, or governance structure always do.

### 8.2 Mandatory Review Triggers

This framework must be reviewed — not just updated if someone notices — when:

- A new agent class is deployed
- A new AI provider is added to the platform
- Platform phase changes (P1 → P2, P2 → P4). Note: P3 is a commercial tier label within P2, not a separate build phase (CHG-0234). Enabling the P3 commercial tier (company/multi-agent) within P2 is also a mandatory governance framework review trigger.
- A material incident occurs that reveals a governance gap
- Annual review (alongside the Charter)
- Australian privacy law or regulatory guidance changes materially

### 8.3 Version History

| Version | Date | Status | Summary |
|---------|------|--------|---------|
| v1.0 | 2026-05-04 | APPROVED — Ken Mun 17:50 AEST | Initial framework. Covers model governance, agent lifecycle, risk register, audit, third-party providers. Reference: TKT-0052. |

---

## YODA NOTES — DECISIONS RESOLVED

*All 5 confirmed by Ken Mun, 2026-05-04 17:46 AEST. Framework updated accordingly.*

| # | Decision | Resolution | Action |
|---|----------|------------|--------|
| 1 | S4 tool scope | Shield to draft per-agent tool scope for Ken review. Confirmed and implemented within 30 days (deadline: 2026-06-03). | TKT-0062 raised |
| 2 | Ollama Cloud DPA | Mandatory before P2: finalise DPA OR explicit exclusion/acceptance of offering OR BYOK (clients bring own model keys). Lex to assess and present options. | TKT-0063 raised |
| 3 | P2 audit committee | Confirm by approval roles, levels, layers, and placeholders. Ken acting for all roles now. Mandatory to review, update, and confirm before P2 live. See updated Section 6.3. | Framework Section 6.3 updated |
| 4 | Warden threshold deadline | 90 days from today: deadline 2026-08-02. | TKT-0061 updated |
| 5 | Ollama Cloud cost metering | Accepted — Ollama Cloud flat monthly rate, no per-task metering required. All other model providers must have dedicated defined cost metering. | Framework Section 7.1 updated |

*— Yoda, 2026-05-04*
