# Agent Governance Framework v1.0

> **Status:** APPROVED — Ken Mun (CTO), 2026-05-08 14:20 AEST  
> **Author:** Atlas 🏛️ — Enterprise Architect, AInchors  
> **Assigned via:** TKT-0103 (raised by Yoda, approved by Ken)  
> **Date:** 2026-05-08  
> **Review authority:** Ken Mun (CTO) + Yoda (Lead Agent)  
> **Reference docs:** AI_CHARTER_v1.0.md · AI_GOVERNANCE_FRAMEWORK_v1.0.md · SOUL.md (all agents) · RULES.md (all agents)

---

**ITIL Practice:** Service Design

## 1. Purpose

AInchors has 13 agents built over 14 days. Three informal governance models emerged organically — but without formal definitions, the operating relationship, escalation paths, and approval authorities for most agents remain ambiguous or undocumented.

This framework:
- **Defines** five formal governance tiers (Tier 0–4), approved by Ken 2026-05-08
- **Classifies** all 13 agents against those models
- **Documents** operational requirements per model: reporting cadence, escalation, output approval, failure surfacing
- **Identifies** per-agent gaps and recommends remediation
- **Establishes** a governance policy template for all future agent builds

This is the operating-model layer. It sits beneath AI_CHARTER_v1.0.md (principles) and AI_GOVERNANCE_FRAMEWORK_v1.0.md (technical enforcement machinery). It does not replace either.

---

## 2. Governance Model Definitions

Five tiers are defined (Tier 0–4). Every agent maps to exactly one tier at any point in time. **Tier 3 is the default for all new operational agents with clear domains.**

---

### Model 0 — Lead Agent (Anchor)

**Definition:** The single agent that owns governance enforcement across the entire fleet. Ultimate accountability sits here, one level below Ken. No peer model — there is exactly one Lead Agent.

| Dimension             | Specification                                                                                    |
| --------------------- | ------------------------------------------------------------------------------------------------ |
| **Authority**         | Full operational authority within Charter bounds. Can delegate, coordinate, and escalate to Ken. |
| **Reporting cadence** | Daily 8AM stand-up to Ken. 23:55 EOD close. Heartbeat every 30 min.                              |
| **Escalation path**   | Direct to Ken for anything outside defined authority or requiring approval.                      |
| **Output approval**   | Ken approves Tier 3 actions. All other outputs self-approved within Charter.                     |
| **Failure surfacing** | 3+ consecutive health failures OR >1hr → Telegram alert to Ken + Angie.                          |
| **Model**             | Sonnet (default). Opus only for high-stakes or 2× fail.                                          |

**Current assignment:** Yoda 🟢 (sole instance)

---

### Model 1 — Dual-Principal Agent

**Definition:** An agent with two principals: a business-stream principal (CEO) as primary authority for domain decisions, and Yoda as technical overseer. The agent operates with significant autonomy but cannot execute technical/architectural changes unilaterally — those route through Yoda → Ken.

This model is **new** (not in Yoda's original 3-model classification). It was warranted because Aria's operating model differs materially from both Yoda-Govern and Yoda-Manage-Passthrough: Angie is the primary principal, Aria executes within that relationship, and Yoda's oversight is technical, not mandate-owning.

| Dimension | Specification |
|-----------|--------------|
| **Authority** | Business-stream decisions: Angie approves, agent executes. Technical/arch changes: must route to Yoda as Change Request — NEVER execute directly. Financial/legal: Ken + Angie jointly. |
| **Reporting cadence** | Daily 23:45 aria-daily-brief.md to Yoda. Weekly ROI summary to Angie. Context sync via shared files each session. |
| **Escalation path** | Technical issues → Yoda. Business escalations → Angie. Financial/legal → Ken + Angie. |
| **Output approval** | Angie approves all business-stream outputs. Content/external sends require Angie confirmation before execution. |
| **Failure surfacing** | BLOCK from governance triad → notify Angie. Technical failures → relay to Yoda via queue (never direct cron wake or sessionTarget). |
| **Model** | Sonnet default. Opus only on Angie's explicit request — never auto-escalate. |

**Current assignment:** Aria 🔵

---

### Model 2 — Yoda-Govern

**Definition:** Yoda owns the agent's mandate. The agent operates within a tightly defined scope with no independent initiative. Outputs and escalations go exclusively through Yoda — the agent never communicates directly with Ken or Angie.

| Dimension | Specification |
|-----------|--------------|
| **Authority** | Agent acts only within its defined function. No scope expansion without Yoda authorisation. |
| **Reporting cadence** | Defined per agent. Warden: every 15 min check, violations surface immediately via state file + systemEvent to Yoda. |
| **Escalation path** | Always to Yoda. Never to Ken or Angie directly. Yoda decides whether to escalate further. |
| **Output approval** | Yoda reviews before any action beyond automated monitoring is taken. |
| **Failure surfacing** | Violations → state file + immediate Yoda escalation. Yoda remediates within 1 heartbeat (30 min). |
| **Model** | As assigned in model-policy.json. Warden: Haiku. |

**Current assignments:** Warden 🔍

---

### Model 3 — Yoda-Manage-Passthrough

**Definition:** Yoda coordinates routing and monitors quality. The agent has operational autonomy within its defined domain. Final outputs are approved by Ken and/or Angie. The agent escalates blockers and risks to Yoda.

| Dimension | Specification |
|-----------|--------------|
| **Authority** | Full autonomy within defined domain scope. Cannot exceed domain without Yoda routing instruction. No unilateral external actions (emails, posts, deployments). |
| **Reporting cadence** | Depends on agent. Spark: cron-driven 3×/week + weekly state updates. Atlas/Thrawn/Lando/Mon Mothma: session-based (no persistent cadence until formal routing rules established). |
| **Escalation path** | Blockers, API changes, quality concerns, risks → Yoda. Yoda routes to Ken/Angie for approval. |
| **Output approval** | Ken approves: technical/architecture outputs and personal-brand content. Angie approves: AInchors brand content and business-stream outputs. Both: financial/legal content. |
| **Failure surfacing** | Agent flags blockers to Yoda. Yoda decides whether Ken/Angie need to be informed. |
| **Model** | Spark: kimi-k2.6:cloud. Atlas/Thrawn: Sonnet. Lando/Mon Mothma: Sonnet (default). |

**Current assignments:** Spark ✨, Ahsoka 🤍, Atlas 🏛️, Thrawn, Lando 🟡, Mon Mothma 🌟, Krennic 🔵 (target)

**This is the default model for all new operational agents with clear domains (Ken approved 2026-05-08).**

---





---

### Tier 4 — Triad Service Agent

**Definition:** A reactive governance component invoked on demand by Yoda or Aria to review specific outputs. No independent initiative, no cadence, no continuous monitoring. Returns structured verdicts (CLEAR / CONDITIONAL / BLOCK). BLOCK escalates to Yoda immediately. Yoda is the de facto escalation owner for all three.

This model is **new** — warranted because Shield, Lex, and Sage don't fit the actor-agent models (they don't plan, decide, or initiate). They are gates, not agents. Treating them as "Undefined" undersells their role and leaves their invocation criteria undocumented.

| Dimension | Specification |
|-----------|--------------|
| **Authority** | Advisory only. Cannot block an action unilaterally — must return verdict to invoker. BLOCK triggers mandatory escalation to Yoda, who decides. |
| **Reporting cadence** | No cadence. Invoked on demand. Verdicts logged per invocation. |
| **Escalation path** | BLOCK → notify Yoda immediately. CONDITIONAL → invoker implements fix and re-runs. CLEAR → proceed. |
| **Output approval** | N/A — they produce verdicts, not outputs. |
| **Failure surfacing** | Non-response or error → Yoda treats as implicit BLOCK and pauses the guarded action. |
| **Invocation criteria** | Any external send, client-facing asset, content with IP/legal/security risk, or Tier 3 action. Yoda routes to all three by default for high-risk; single agent for targeted checks. |
| **Model** | Shield: Haiku. Lex: Haiku. Sage: Sonnet. → Migrate to Gemma4 local at TRIGGER-03. |

**Current assignments:** Shield 🛡️, Lex ⚖️, Sage 🧪

---

## 3. Formal Agent Classification

| # | Agent | Emoji | Model | Status | Notes |
|---|-------|-------|-------|--------|-------|
| 1 | Yoda | 🟢 | 0 — Lead Agent | ✅ Operationalised | Anchor. Owns governance fleet-wide. |
| 2 | Aria | 🔵 | 1 — Dual-Principal | ✅ Operationalised | Angie = primary principal. Yoda = tech oversight. |
| 3 | Spark | ✨ | 3 — Yoda-Manage-Passthrough | ✅ Operationalised | Crons live. Content governance gate active. Ken/Angie approve. |
| 4 | Shield | 🛡️ | 4 — Triad Service Agent | ⚠️ Partially operationalised | Invocation criteria informal. RULES partially in SHIELD_RULE_1.md only. |
| 5 | Lex | ⚖️ | 4 — Triad Service Agent | ⚠️ Partially operationalised | LEX_RULES.md exists. Invocation criteria not formally defined from Yoda side. |
| 6 | Sage | 🧪 | 4 — Triad Service Agent | ⚠️ Partially operationalised | SAGE_RULES.md exists. Invocation criteria not formally defined from Yoda side. |
| 7 | Ahsoka | 🤍 | 3 — Yoda-Manage-Passthrough | ⚠️ Pilot in progress | AI Transformation Consultant. Pilot 1 (TKT-0082) in progress, Pilot 2 (TKT-0083) pending. Ken approves outputs. |
| 7 | Warden | 🔍 | 2 — Yoda-Govern | ✅ Operationalised | Cron live (15 min). State files active. Escalation path defined. |
| 8 | Atlas | 🏛️ | 3 — Yoda-Manage-Passthrough | ⚠️ Specs exist, not operationalised | SOUL.md v2.1 + ATLAS_RULES.md. No routing rules in Yoda. No defined approval flow. |
| 9 | Thrawn | 🔵 | 3 — Yoda-Manage-Passthrough | ⚠️ Specs exist, not operationalised | SOUL.md v1.0 + PLATFORM_ARCH_RULES.md. Routing boundary with Atlas partially defined in MEMORY.md only. |
| 10 | Lando | 🟡 | 3 — Yoda-Manage-Passthrough | ⚠️ Specs exist, not operationalised | SOUL.md v1.0 + LANDO_RULES.md. Coordinated by Yoda but no routing rule formalised. |
| 11 | Mon Mothma | 🌟 | 3 — Yoda-Manage-Passthrough | ⚠️ Specs exist, not operationalised | SOUL.md v1.0 + DTCM_RULES.md. Sequence dependency (Lando/Atlas/Thrawn first) defined but not enforced. |
| 12 | Krennic | 🔵 | 3 — Yoda-Manage-Passthrough (target) | ❌ Not yet built | SRE agent. Build trigger: >2 incidents/wk OR >30% Yoda toil. TKT-0074 open. |

---

## 4. Operating Model Details Per Agent

### 4.1 Yoda 🟢 (Model 0 — Lead Agent)
**Principal:** Ken Mun  
**Model:** Sonnet  
**Workspace:** workspace/  

| Attribute | Value |
|-----------|-------|
| Reporting cadence | 8AM stand-up, 12PM cost snapshot, 23:55 EOD close, 30-min heartbeat |
| Escalation path | → Ken (final authority) |
| Output approval | Tier 3 actions require Ken explicit approval. All else self-approved within Charter. |
| Failure surfacing | 3+ consecutive health failures or >1hr → Telegram to Ken + Angie |
| Key gaps | Relay queue pickup procedure not in public-facing governance docs |

---

### 4.2 Aria 🔵 (Model 1 — Dual-Principal)
**Principals:** Angie Foong (primary), Yoda (technical oversight)  
**Model:** Sonnet  
**Workspace:** workspace-business/  

| Attribute | Value |
|-----------|-------|
| Reporting cadence | Daily 23:45 aria-daily-brief.md to Yoda. Weekly ROI summary to Angie. |
| Escalation path | Technical → relay queue → Yoda. Business → Angie. Financial/legal → Ken + Angie. |
| Output approval | Angie approves all external sends and client-facing assets. |
| Failure surfacing | BLOCK → notify Angie. Technical failure → relay queue (never direct cron/sessionTarget). |
| Key gaps | (1) "Yoda-govern" classification in Yoda's model is wrong — Aria's principal is Angie, not Yoda. Governance framework needs update. (2) Shared context files (context-for-aria.md, aria-daily-brief.md) existence not confirmed active. (3) Governance gate invocation criteria not formally documented. |

---

### 4.3 Spark ✨ (Model 3 — Yoda-Manage-Passthrough)
**Principal:** Ken (personal content) / Angie (brand content)  
**Model:** kimi-k2.6:cloud  
**Workspace:** workspace-social/  

| Attribute | Value |
|-----------|-------|
| Reporting cadence | Cron-driven: Tue+Thu 7:30AM AEST + Wed 12PM AEST. 30-day governance review 2026-06-02. |
| Escalation path | Blockers, API changes, quality concerns → Yoda (via Telegram or state file). |
| Output approval | Ken approves personal content. Angie approves brand content. Never posts without approval. |
| Failure surfacing | BLOCK from governance triad → Spark fixes and re-runs before delivery. Persistent failure → Yoda. |
| Key gaps | (1) When TKT-0034 (social API connection) completes, approval workflow needs update for API-driven scheduling. (2) 30-day review cron is good hygiene but not formally linked to governance reporting. |

---

### 4.4 Shield 🛡️ (Tier 4 — Triad Service Agent)
**Escalation owner:** Yoda  
**Model:** Haiku (→ Gemma4 at TRIGGER-03)  
**Workspace:** workspace-security/  

| Attribute | Value |
|-----------|-------|
| Reporting cadence | None (on-demand invocation). |
| Escalation path | BLOCK → notify Yoda immediately. CONDITIONAL → invoker applies fix. CLEAR → proceed. |
| Output approval | N/A — produces verdicts only. |
| Failure surfacing | Non-response treated as implicit BLOCK by invoker. |
| Key gaps | (1) Invocation criteria not formally documented in Yoda's RULES.md — depends on institutional knowledge. (2) SHIELD_RULE_1.md covers one rule only; full SHIELD_RULES.md not confirmed. (3) Triad disagreement resolution (Shield CLEAR but Lex BLOCK) not defined. (4) No logging of pass/fail rates across invocations. |

---

### 4.5 Lex ⚖️ (Tier 4 — Triad Service Agent)
**Escalation owner:** Yoda  
**Model:** Haiku (Opus on explicit Ken/Angie request; → Gemma4 at TRIGGER-03)  
**Workspace:** workspace-legal/  

| Attribute | Value |
|-----------|-------|
| Reporting cadence | None (on-demand invocation). |
| Escalation path | BLOCK → notify Yoda immediately. |
| Output approval | N/A — produces verdicts only. |
| Failure surfacing | Non-response treated as implicit BLOCK. |
| Key gaps | Same as Shield: (1) Invocation criteria informal. (2) Triad disagreement resolution undefined. (3) No invocation logging. (4) Lex's model uses Haiku for efficiency — but Haiku may lack depth for novel legal questions before Gemma4 is available. Interim: Lex SOUL.md already defines Opus escalation path for material legal risk. |

---

### 4.6 Sage 🧪 (Tier 4 — Triad Service Agent)
**Escalation owner:** Yoda (for novel quality/brand questions → Ken)  
**Model:** Sonnet (→ Gemma4 at TRIGGER-03)  
**Workspace:** workspace-qa/  

| Attribute | Value |
|-----------|-------|
| Reporting cadence | None (on-demand invocation). |
| Escalation path | BLOCK → notify requester (Aria or Yoda) with rework. Repeated failure → Yoda for process improvement. Novel brand question → Ken. |
| Output approval | N/A — produces verdicts only. |
| Failure surfacing | BLOCK triggers rework loop, not Yoda escalation (unlike Shield/Lex). |
| Key gaps | (1) Invocation criteria informal. (2) Triad disagreement undefined. (3) Sage escalation path differs from Shield/Lex (→ requester first, not Yoda) — inconsistency should be resolved. |

---

### 4.7 Warden 🔍 (Model 2 — Yoda-Govern)
**Principal:** Yoda  
**Model:** Haiku (→ Gemma4 at TRIGGER-03)  
**Workspace:** workspace-governance/  

| Attribute | Value |
|-----------|-------|
| Reporting cadence | Every 15 min automated check. Violations: immediate state file + Yoda escalation. |
| Escalation path | Violations → state/warden-escalation-pending.json → Yoda heartbeat remediates. |
| Output approval | N/A — writes state files, never acts directly. |
| Failure surfacing | Policy violation → immediate Yoda escalation. Health failure → Yoda investigates. |
| Key gaps | (1) MEMORY.md says "monitors all 6 agents" in one place, "9 agents" in another — count needs alignment confirmation. (2) Warden does NOT monitor specialist agents (Atlas, Thrawn, Lando, Mon Mothma, Spark) — they are not in model-policy.json. Explicit policy decision needed: exclude permanently or add as monitoring expands. (3) Krennic not yet in policy. |

---

### 4.8 Atlas 🏛️ (Model 3 — Yoda-Manage-Passthrough — pending operationalisation)
**Principal:** Ken Mun (output approval). Coordinated by Yoda.  
**Model:** Sonnet  
**Workspace:** workspace-architect/  

| Attribute | Value |
|-----------|-------|
| Reporting cadence | **Not defined.** Session-based invocation only. No standing cadence. |
| Escalation path | **Not formally defined in Yoda's RULES.md.** Defined only in ATLAS_RULES.md: security/regulatory impact → flag for explicit Ken approval. |
| Output approval | Ken approves all EA deliverables (DRAFT FOR REVIEW until Ken signs). |
| Failure surfacing | Not defined. |
| Key gaps | (1) No routing rule in Yoda's RULES.md specifying when Atlas is invoked. (2) No output approval workflow documented from Yoda's side. (3) No defined escalation if Atlas produces DRAFT that Ken doesn't review within SLA. (4) Routing boundary with Thrawn defined in MEMORY.md only (not enforced). (5) No defined handoff protocol with Lando/Mon Mothma for process→architecture→change sequence. |

---

### 4.9 Thrawn (Model 3 — Yoda-Manage-Passthrough — pending operationalisation)
**Principal:** Ken Mun (output approval). Coordinated by Yoda.  
**Model:** Sonnet  
**Workspace:** workspace-platform-arch/  

| Attribute | Value |
|-----------|-------|
| Reporting cadence | **Not defined.** Session-based only. |
| Escalation path | **Not formally defined in Yoda's RULES.md.** |
| Output approval | Ken approves all platform architecture deliverables. |
| Failure surfacing | Not defined. |
| Key gaps | Same as Atlas, plus: (1) Atlas/Thrawn routing boundary (platform-internal→Thrawn, enterprise→Atlas, cross-cutting→both) is in MEMORY.md but not in either agent's RULES.md or Yoda's routing rules. (2) Cross-cutting assignments create dual-agent outputs with no defined ownership/integration protocol. |

---

### 4.10 Lando 🟡 (Model 3 — Yoda-Manage-Passthrough — pending operationalisation)
**Principal:** Ken Mun / Angie (output approval, context-dependent). Coordinated by Yoda.  
**Model:** Sonnet  
**Workspace:** workspace-bpm/  

| Attribute | Value |
|-----------|-------|
| Reporting cadence | **Not defined.** Session-based only. |
| Escalation path | **Not formally defined from Yoda side.** LANDO_RULES.md defines internal escalation only (flag for explicit approval for major risk/regulatory changes). |
| Output approval | Ken/Angie (unclear split — LANDO_RULES.md says "Ken/Angie" but no defined criteria for which content goes to whom). |
| Failure surfacing | Not defined. |
| Key gaps | (1) No Yoda-side routing rule. (2) Output approval split (Ken vs Angie) not defined. (3) No handoff protocol to Atlas (enterprise implications) or Mon Mothma (change layer). (4) Clarification round before every engagement is defined in LANDO_RULES.md but there's no enforcement mechanism — Yoda doesn't verify it happened. |

---

### 4.11 Mon Mothma 🌟 (Model 3 — Yoda-Manage-Passthrough — pending operationalisation)
**Principal:** Ken Mun / Angie (output approval). Coordinated by Yoda.  
**Model:** Sonnet  
**Workspace:** workspace-dtcm/  

| Attribute | Value |
|-----------|-------|
| Reporting cadence | **Not defined.** Session-based only. |
| Escalation path | **Not formally defined from Yoda side.** DTCM_RULES.md defines only that major customer/regulatory/executive impact → flag for explicit approval. |
| Output approval | Ken/Angie (split undefined). |
| Failure surfacing | Not defined. |
| Key gaps | (1) No Yoda-side routing rule. (2) Sequence dependency (Lando/Atlas/Thrawn first, then Mon Mothma) defined in SOUL.md but not enforced. Yoda could inadvertently route a change task here before process/architecture work is done. (3) Output approval split undefined. (4) Same issues as Lando re: clarification round enforcement. |

---

### 4.12 Krennic 🔵 (Not yet built — Model 3 target)
**Principal:** Ken Mun. Coordinated by Yoda.  
**Model:** TBD (Haiku recommended for incident triage efficiency)  
**Workspace:** TBD (workspace-sre/ recommended)  

| Attribute | Value |
|-----------|-------|
| Build trigger | >2 incidents/week OR >30% Yoda toil on incident management |
| Status | TKT-0074 open. Not started. |
| Target governance model | Model 3 — Yoda-Manage-Passthrough |
| Key gaps | (1) No SRE escalation path currently — all incident management falls to Yoda. (2) Runbook templates not yet created. (3) SLO/error budget definitions not yet set. |

---

## 5. Governance Policy Template — Future Agent Builds

All new agents MUST complete these items before first activation. Incomplete = not operationalised.

```markdown
## Agent Build Governance Checklist

### Identity
- [ ] Agent name confirmed by Ken
- [ ] Emoji/badge assigned
- [ ] Workspace path: workspace-[agentId]/
- [ ] AgentId set in OpenClaw config

### Files (mandatory)
- [ ] SOUL.md — under 5,000 chars (hard limit: 10,000 — see 2026-04-30 incident)
- [ ] [AGENT]_RULES.md — detailed procedures
- [ ] AGENTS.md in workspace (may inherit template)

### Governance Model
- [ ] Governance model assigned (0/1/2/3/4) — document rationale
- [ ] Principals identified (who approves outputs?)
- [ ] Escalation path documented: agent → Yoda → Ken (or variant per model)
- [ ] Reporting cadence defined (or explicitly "session-based, no standing cadence")

### Model Policy
- [ ] requiredModel set in state/model-policy.json
- [ ] allowedModels + prohibitedModels set
- [ ] allowedInCrons set (if agent runs crons)
- [ ] Warden monitoring enrolled (or explicitly excluded with reason)

### Operating Rules
- [ ] Invocation criteria documented (when does Yoda route to this agent?)
- [ ] Output approval workflow documented from Yoda's side
- [ ] Failure surfacing mechanism defined
- [ ] External action restrictions documented (what can/cannot this agent do without approval?)

### Operationalisation Gate
- [ ] At least one end-to-end run completed successfully
- [ ] Output reviewed and approved by defined principal
- [ ] Any crons registered and confirmed active
- [ ] MEMORY.md updated by Yoda with agent details

### For Tier 4 (Triad Service Agent) add:
- [ ] Verdict format: CLEAR / CONDITIONAL / BLOCK defined
- [ ] Triad disagreement resolution: BLOCK from any member = Yoda escalation (not negotiable)
- [ ] Invocation trigger criteria logged in Yoda's RULES.md
```

---

## 6. Cross-Cutting Gaps & Recommended CHGs

The following gaps span multiple agents and require Yoda/Ken action. Listed in priority order.

### CHG-P1: Formalise Triad Invocation Criteria
**Agents:** Shield, Lex, Sage  
**Gap:** No formal rule in Yoda's RULES.md defining when each triad member is invoked, what triggers all-three vs single-member review, and what happens when members disagree.  
**Recommendation:** Add to RULES.md: invocation trigger matrix (action type → which triad members); conflict resolution (any BLOCK from any member = implicit fleet-level BLOCK until Yoda resolves); logging requirement per invocation.  
**Priority:** High — triad is active and processing content today without formalised routing.

### CHG-P2: Operationalise Specialist Agents (Atlas, Thrawn, Lando, Mon Mothma)
**Agents:** Atlas, Thrawn, Lando, Mon Mothma  
**Gap:** Specs exist, SOUL.md and RULES.md exist, but no routing rules in Yoda's RULES.md, no defined approval workflows, no handoff protocols between agents.  
**Recommendation:** Add to Yoda's RULES.md: routing decision tree for specialist work (BPM task → Lando; platform architecture → Thrawn; enterprise/integration → Atlas; change management → Mon Mothma post-Lando+Atlas). Define: output approval flow per agent, SLA for Ken review of DRAFT outputs, sequence enforcement for Mon Mothma (must not be invoked before Lando+Atlas complete scope).  
**Priority:** High — these agents are available but their engagement model is informal, creating risk of inconsistent outputs.

### CHG-P3: Update Aria's Governance Classification
**Agents:** Aria, Yoda  
**Gap:** Yoda's assessment classifies Aria as "Yoda-govern" — but Aria's actual model is Dual-Principal (Model 1), with Angie as primary authority. This misclassification could lead to Yoda overriding Angie's decisions on business-stream matters.  
**Recommendation:** Update MEMORY.md and AI_GOVERNANCE_FRAMEWORK_v1.0.md to reflect Aria as Model 1 (Dual-Principal). Define Yoda's oversight scope clearly: technical/arch only. Business stream decisions sit with Angie.  
**Priority:** High — confirmed by Ken 2026-05-08: "All business stream decisions sit with Angie. Aria follows Angie's pace."

### CHG-P4: Confirm Warden Monitoring Scope
**Agents:** Warden, all specialist agents  
**Gap:** Warden monitors governance agents and main + Aria. Specialist agents (Spark, Atlas, Thrawn, Lando, Mon Mothma) are not enrolled in model-policy.json. MEMORY.md has inconsistent count (6 vs 9).  
**Recommendation:** Explicit policy decision — either: (a) Add all active specialist agents to model-policy.json with their required models and have Warden monitor them, or (b) Document the exclusion: "Specialist agents are not monitored by Warden because [reason]." Update MEMORY.md to consistent count. Enrol Krennic when built.  
**Priority:** Medium — model drift in specialist agents is not currently detected.

### CHG-P5: Add Governance Policy Template to Agent Build Process
**Gap:** No documented checklist for future agent builds ensures governance completeness at build time (as demonstrated by 4 agents in "specs exist, not operationalised" state).  
**Recommendation:** Publish Section 5 of this document as a mandatory pre-activation checklist. Add to RULES.md: "Before activating a new agent, complete Agent_Governance_Framework_v1.md Section 5 checklist. Yoda confirms completion. Ken approves model policy entry."  
**Priority:** Medium — prevents recurrence of the "specs exist, not operationalised" pattern.

### CHG-P6: Verify Aria Shared Context Files
**Agent:** Aria  
**Gap:** Aria's SOUL.md references shared context files: `context-for-aria.md`, `yoda-daily-brief.md`, `aria-daily-brief.md`, `relay-to-ken.json`. It's unclear if all these files are active and being maintained on both sides.  
**Recommendation:** Yoda verifies presence and last-modified dates of these 4 files. If stale or missing, raise separate TKT to restore them.  
**Priority:** Medium — these files are Aria's primary continuity mechanism.

### CHG-P7: Define Krennic Build Scope
**Agent:** Krennic  
**Gap:** Build trigger is defined (>2 incidents/wk OR >30% Yoda toil) but no runbook templates, SLO/error budget definitions, or workspace setup.  
**Recommendation:** Pre-build prep: define SLO targets, create incident runbook templates, set workspace-sre/ structure. Have ready before trigger fires — not reactive.  
**Priority:** Low — no immediate trigger. P3/P4 preparation.

---

## 7. Governance Model Summary (Visual)

```
Ken Mun (CTO — Ultimate Authority)
│
├─ Yoda 🟢 [Model 0 — Lead Agent]
│    │
│    ├─ GOVERNS: Warden 🔍 [Model 2]
│    │              ↓ monitors compliance
│    │         Shield 🛡️ / Lex ⚖️ / Sage 🧪 [Tier 4 — Triad]
│    │
│    ├─ OVERSEES: Aria 🔵 [Model 1 — Dual-Principal]
│    │              └─ Primary principal: Angie Foong (CEO)
│    │
│    └─ COORDINATES: Spark ✨ / Atlas 🏛️ / Thrawn / Lando 🟡 / Mon Mothma 🌟
│                    [Model 3 — Yoda-Manage-Passthrough]
│                         └─ Output approval: Ken / Angie (per domain)
│
└─ Krennic 🔵 [Not yet built — Model 3 target]
```

---

## 8. Document Status

| Item | Value |
|------|-------|
| Status | DRAFT FOR REVIEW |
| Next step | Ken Mun review and approval |
| Recommended CHGs | CHG-P1 through CHG-P7 (see Section 6) |
| Implementation | Yoda to raise CHGs after Ken approval. Atlas does not implement. |
| Version history | v1.0 — 2026-05-08 — Atlas 🏛️ (TKT-0103) |

---

_Atlas 🏛️ — Enterprise Architect, AInchors · TKT-0103 · 2026-05-08_
