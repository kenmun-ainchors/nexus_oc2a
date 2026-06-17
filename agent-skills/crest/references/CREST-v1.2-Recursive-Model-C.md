# CREST v1.2 — Recursive Execution Topology (Model C)

**Status:** LOCKED | **Author:** Yoda 🟢 | **Date:** 2026-06-10 | **Approved by:** Ken Mun (decision: 2026-06-10 04:34 AEST)
**Version:** v1.2 — resolves all 16 review findings (13 v1.1 + 3 v1.2 observations) | **Review:** Atlas ✅ PASS | Thrawn ✅ PASS
**Supersedes:** CREST v1.1 (2026-06-10), CREST v1.0 (flat topology, MEMORY.md 2026-06-09)
**Linked:** TKT-0368 (CREST structural implementation), TKT-0370 (Flash Dispatcher), TKT-0321 (2-Pass Contract), TKT-0322 (Model-Task Matrix), TKT-0323 (Dispatch Validator)

---

## 1. Executive Summary

CREST v1.1 adopts a **recursive (fractal) topology** for the CREST execution loop. The same 6-phase sandwich — Plan → Execute → Verify → Replan → Synthesize → Done — applies at two levels:

- **Master CREST:** Yoda (deepseek-pro) orchestrates sub-tickets across specialists
- **Sub-CREST:** Each specialist agent (Atlas, Thrawn, Spark, Lando, Mon Mothma, Forge) runs their own CREST loop for their sub-ticket, using pro models for cognitive phases and cheap models for mechanical execution

**Ken's designation: Model C.** Decision locked 2026-06-10 04:34 AEST.

---

## 2. Why Recursive CREST?

### 2.1 The Flat CREST Limitation

CREST v1.0 has Yoda as the sole strong-tier orchestrator. Yoda Plans ALL atoms for ALL sub-tickets, regardless of domain. This creates two problems:

1. **Cognitive ceiling:** Yoda cannot Plan atoms for enterprise architecture (Atlas domain), platform security design (Thrawn domain), or content strategy (Spark domain) with the same depth as the specialist who owns that domain.
2. **Serial bottleneck:** All atoms flow through Yoda for Plan → Verify → Replan. Parallel specialist work is impossible at the cognitive level.

### 2.2 The Fractal Insight

CREST is fractal. Plan → Execute → Verify → Replan → Synthesize → Done applies at every level of work decomposition:

```
Master ticket → sub-tickets → atoms
    │               │            │
    └── CREST       └── CREST    └── RVEV (READ → VALIDATE → EXECUTE → VERIFY)
```

The same sandwich topology, the same strong-tier-plans/cheap-tier-executes principle, applied recursively.

### 2.3 Model C Benefits

| Dimension | Flat CREST (v1.0) | Recursive CREST (v1.1) |
|-----------|-------------------|------------------------|
| **Yoda Plans** | All atoms for all sub-tickets | Sub-ticket assignments only |
| **Specialist role** | Execute pre-planned atoms | Plan/Verify/Replan own atoms |
| **Domain depth** | Yoda must understand all domains | Specialists bring domain depth |
| **Parallelism** | Serial through Yoda | Parallel sub-CRESTs |
| **Gap detection** | Yoda catches all gaps | Specialist catches domain gaps, Yoda catches integration gaps |
| **Model alignment** | Pro overused for discovery, cheap underused | Pro for all cognitive work, cheap for all mechanical work |

---

## 3. Architecture

### 3.1 Full Recursive Topology

```
MASTER CREST (Yoda, deepseek-pro)
│
├── PLAN: Break master ticket → sub-tickets, assign specialists, set DAG dependencies
│   └── Output: sub-ticket assignments with model specs per specialist matrix (§4)
│
├── EXECUTE: Dispatch sub-tickets to specialists (parallel where DAG allows)
│   │
│   ├── SUB-CREST: Atlas (pro Plan/Verify/Replan, flash Execute, flash Synthesize)
│   │   ├── Plan: TOGAF scoping, clarifying questions, trade-off framework, deliverable structure
│   │   ├── Execute: flash sub-agents draft docs, research, generate diagrams
│   │   ├── Verify: Pro coherence check, TOGAF domain coverage, constraint compliance
│   │   ├── Replan: Gap → iterate(n++) OR escalate to Yoda (§6)
│   │   └── Synthesize: Domain-internal atom integration → sub-ticket deliverable
│   │
│   ├── SUB-CREST: Thrawn (pro Plan/Verify/Replan, flash Execute, flash Synthesize)
│   │   └── [same structure, platform-internal domain]
│   │
│   ├── SUB-CREST: Spark (pro Plan/Verify/Replan, flash Execute*, flash Synthesize)
│   │   └── [same structure, creative-strategic domain]
│   │   └── *Some creative Execute atoms may warrant pro; specialist judgment call
│   │
│   ├── SUB-CREST: Lando (pro Plan/Verify/Replan, flash Execute, flash Synthesize)
│   │   └── [same structure, BPM/BPMN domain]
│   │
│   ├── SUB-CREST: Mon Mothma (pro Plan/Verify/Replan, flash Execute, flash Synthesize)
│   │   └── [same structure, ADKAR domain]
│   │
│   └── SUB-CREST: Forge (flash Plan/Synthesize, pro Verify/Replan, flash Execute) ⚠️ EXCEPTION
│       └── [exception structure, infra/SRE domain — see §5.2]
│
├── VERIFY: Per-sub-ticket binary judgment (0/1)
│   ├── Output received? Delivered on time? Atom breakdown valid?
│   ├── Escalation present? Resolved? (§6)
│   ├── Specialist sub-CREST process valid? (meta-verification)
│   └── Independent checks (grep, test, execute — NEVER trust self-report. L-054)
│
├── REPLAN: Master gap detection
│   ├── Any sub-ticket failed Verify? → re-dispatch specialist (n++)
│   ├── Cross-specialist conflict? → coordinate or re-sequence DAG
│   ├── Escalation from specialist? → assess, decide, re-dispatch if needed (§6)
│   ├── Scope change needed? → adjust DAG, re-dispatch affected specialists
│   └── All passed? → advance to Synthesize
│
├── SYNTHESIZE: Cross-specialist integration (flash — mechanical assembly)
│   ├── Interface consistency checks (did two specialists define same concept differently?)
│   ├── Assumption alignment checks (contradictory assumptions across sub-tickets?)
│   ├── Gap detection (anything NO specialist owned?)
│   ├── Narrative coherence (one story or five disconnected stories?)
│   └── Integration report → gaps found? → back to Replan (§7)
│
└── DONE: Emit audit trail, close master ticket, Holocron registration
```

### 3.2 Specialist Agent Cognitive Work Domains

Each specialist's sub-CREST is defined by their domain-specific cognitive work at each phase.

#### Atlas 🏛️ — Enterprise Architect

| Phase | Model | Cognitive Work | Mechanical Work (→ cheap executors) |
|-------|-------|---------------|-------------------------------------|
| **Plan** | pro | TOGAF ADM scoping, clarifying questions to Ken, architectural assumptions, trade-off framework selection, deliverable template | File reads, context loading |
| **Execute** | flash | — NONE — (design-only, never implements) | Research (web_search), document drafting, diagram generation, formatting |
| **Verify** | pro | Architecture coherence check, TOGAF domain coverage, cross-domain consistency, enterprise constraint compliance, trade-off completeness | Syntax/lint checks, file existence, cross-reference validation |
| **Replan** | pro | Gap analysis (missing domain, weak trade-off, assumption change), re-scope decision, escalation to Yoda if enterprise boundary crossed | — |
| **Synthesize** | flash | Final architecture narrative, executive summary, recommendation framing | Document assembly, format polishing, Holocron registration |

#### Thrawn 🔵 — Platform Architect

| Phase | Model | Cognitive Work | Mechanical Work (→ cheap executors) |
|-------|-------|---------------|-------------------------------------|
| **Plan** | pro | Platform architecture scoping, Nexus internals design, model strategy, S1-S7 control design, HITL flow architecture | File reads, current-state inspection |
| **Execute** | flash | — NONE — (design-only, never implements) | Research, document drafting, config analysis, integration mapping |
| **Verify** | pro | Platform architecture coherence, S1-S7 completeness, integration point validation, constraint compliance (Atlas-set enterprise boundaries) | Lint, schema validation, cross-reference checks |
| **Replan** | pro | Gap analysis (missing control, integration gap, security concern), re-design, escalation to Yoda if platform boundary crossed | — |
| **Synthesize** | flash | Architecture document, CTO-ready summary, trade-off matrix | Document assembly, formatting |

#### Spark ✨ — Social & Digital Marketing

| Phase | Model | Cognitive Work | Mechanical Work (→ cheap executors) |
|-------|-------|---------------|-------------------------------------|
| **Plan** | pro | Content strategy, campaign design, audience/ICP analysis, platform sequencing, AIDA/PAS framework selection, editorial calendar construction | Queue file reads, platform tracker reads |
| **Execute** | flash* | Post drafting, headline generation, hook writing, format adaptation (LinkedIn→IG→FB), analytics collection | *Some creative atoms may need pro; specialist judgment call per atom |
| **Verify** | pro | Brand voice check, topic uniqueness validation, audience fit, hook effectiveness | Em-dash check, length check, platform format validation, duplicate detection |
| **Replan** | pro | Content angle revision, hook rework, platform adaptation fail → redesign, strategy pivot if analytics show poor performance | — |
| **Synthesize** | flash | Campaign narrative, cross-platform cohesion, analytics story | Report assembly, queue updates |

#### Lando 🟡 — Business Process (BPM/BPMN)

| Phase | Model | Cognitive Work | Mechanical Work (→ cheap executors) |
|-------|-------|---------------|-------------------------------------|
| **Plan** | pro | Process discovery, BPMN modelling decisions, swimlane design, process decomposition, bottleneck analysis | Current-state documentation reading |
| **Execute** | flash | — NONE — (design-oriented) | BPMN diagram generation, process documentation drafting, workflow simulation runs |
| **Verify** | pro | Process completeness, deadlock detection, swimlane correctness, compliance gate checking | BPMN syntax validation, tool linting |
| **Replan** | pro | Process redesign, bottleneck resolution, compliance gap closure | — |
| **Synthesize** | flash | Process architecture narrative, implementation roadmap | Document assembly, format export |

#### Mon Mothma 🌟 — Change Management (ADKAR)

| Phase | Model | Cognitive Work | Mechanical Work (→ cheap executors) |
|-------|-------|---------------|-------------------------------------|
| **Plan** | pro | ADKAR assessment (Awareness/Desire/Knowledge/Ability/Reinforcement), stakeholder analysis, change impact scoring, adoption strategy | Current-state surveys, stakeholder list compilation |
| **Execute** | flash | — NONE — (strategy-oriented) | Communications drafting, training material drafting, adoption metric collection, report generation |
| **Verify** | pro | ADKAR dimension coverage, stakeholder completeness, adoption risk assessment, resistance planning adequacy | Metric accuracy, document completeness |
| **Replan** | pro | Adoption gap analysis, resistance strategy revision, communication plan redesign | — |
| **Synthesize** | flash | Change readiness assessment, adoption roadmap, executive summary | Report assembly |

#### Forge 🏗️ — Infrastructure & SRE (Exception — §5.5)

| Phase | Model | Cognitive Work | Mechanical Work (→ cheap executors) |
|-------|-------|---------------|-------------------------------------|
| **Plan** | **flash** | Infra assessment, dependency mapping, tool selection | — (exception: flash for Plan) |
| **Execute** | flash | — ALL mechanical — | Script writing, config changes, Docker ops, PG writes, test runs |
| **Verify** | pro | Independent verification of execution results — did the build work correctly? | Lint, test runs, exit code checks |
| **Replan** | pro | Gap analysis, error root cause, fix strategy | — |
| **Synthesize** | **flash** | Log assembly, report generation | — (exception: flash for Synthesize) |

---

## 4. Model Assignment Matrix

| Specialist | Plan | Execute | Verify | Replan | Synthesize | Design-Only? |
|-----------|------|---------|--------|--------|-----------|-------------|
| **Atlas** | pro | flash | pro | pro | flash | ✅ Yes |
| **Thrawn** | pro | flash | pro | pro | flash | ✅ Yes |
| **Spark** | pro | flash* | pro | pro | flash | ❌ No (creative) |
| **Lando** | pro | flash | pro | pro | flash | ✅ Yes |
| **Mon Mothma** | pro | flash | pro | pro | flash | ✅ Yes |
| **Forge** | **flash** ⚠️ | flash | pro | pro | **flash** ⚠️ | ❌ No (build) |
| **Yoda** | pro | — | pro | pro | flash | Master orchestrator |

**Spark Execute note:** Some creative atoms (e.g., high-stakes LinkedIn thought-leadership post drafting) may warrant pro-tier execution. Specialist judgment call per atom. Default: flash.

**Forge exceptions:** Plan + Synthesize use flash (not pro). Verify + Replan use pro. Rationale: Forge's domain is execution-heavy by nature. Plan is mechanical (dependency mapping, tool selection), not deep cognitive design. Verify IS cognitive — judging whether a build worked correctly requires pro-level reasoning.

---

## 5. Specialist Exceptions & Edge Cases

### 5.1 Spark Creative Exception

Spark's Execute phase includes creative work (post drafting, headline generation). Unlike Atlas/Thrawn who produce design documents (mechanical formatting), Spark produces creative content where quality is subjective and brand-sensitive.

**Rule:** Spark defaults to flash for Execute. If the atom is high-stakes (Ken's personal LinkedIn, campaign launch, client-facing content), Spark may assign pro for that specific atom. This is a per-atom judgment call documented in the atom spec.

**Governance:** Pro-assigned creative atoms are flagged in the atom spec with `model_override: "pro"` and `override_reason`. Warden's 15-min compliance check scans for pro-assigned atoms and logs them for Yoda visibility. This ensures per-atom model assignment decisions have an audit trail — not a governance gap. If pro assignment rate exceeds threshold (suggested: >20% of Spark atoms in a sprint), Warden alerts Yoda for review.

### 5.2 Forge Exception (Agreed by Ken 2026-06-10)

Forge is the build agent — execution-heavy by nature. The sub-CREST structure applies but model assignments shift:

- **Plan = flash:** Infra assessment, dependency mapping, tool selection are mechanical, not deep cognitive design
- **Verify = pro:** Judging whether a build, script, or config change worked correctly requires pro-level reasoning — this is where Forge's cognitive work lives
- **Replan = pro:** Root cause analysis, fix strategy design
- **Synthesize = flash:** Mechanical log assembly and report generation

This is the exception that proves the rule — Forge still has a sub-CREST loop, but the tier assignments reflect the execution-heavy domain.

**Flash Plan → Pro Replan loop risk:** If a flash-planned Forge task fails Verify, the pro Replan must effectively re-Plan on pro — the flash Plan was insufficient. This is accepted overhead for Forge's domain. The cost of running Plan on pro every time (for tasks where flash Plan is usually sufficient) exceeds the cost of occasional pro Replan that re-does planning. **Monitor:** Yoda checks via TQP state at Master Verify — if >30% of Forge sub-CRESTs hit Replan (iteration_count > 0), reassess flash-for-Plan assumption. Warden's 15-min cron also scans Forge Replan rate and alerts if threshold breached between Master Verify cycles.

### 5.3 Parallel Sub-CREST Execution — State Isolation

Sub-CRESTs run in parallel where the master DAG allows (e.g., Atlas and Thrawn can Plan concurrently on independent sub-tickets). The current `sessions_spawn` infrastructure supports parallel execution.

**Race condition guard:** If two parallel sub-CRESTs share a write target (same PG table, same state file, same config), the specialist must declare the shared resource in their Plan output. Yoda's DAG then sequences them (no parallel writes to shared state).

**DAG dependency model:**
```json
{
  "sub_ticket_dag": {
    "nodes": [
      {"id": "TKT-xxxx-atlas", "specialist": "atlas", "writes": ["docs/EA_v2.1.md"]},
      {"id": "TKT-xxxx-thrawn", "specialist": "thrawn", "writes": ["docs/PA_v2.1.md"], "depends_on": ["TKT-xxxx-atlas"]},
      {"id": "TKT-xxxx-forge", "specialist": "forge", "writes": ["scripts/", "state/"], "shared_state": ["state/tickets"]}
    ],
    "parallel_groups": [["TKT-xxxx-atlas"], ["TKT-xxxx-thrawn"], ["TKT-xxxx-forge"]]
  }
}
```

**Rule:** Any shared-state declaration → sequential execution. No shared-state declaration → parallel eligible.

### 5.4 Governance Agents (Shield, Lex, Sage, Warden)

**NOT subject to sub-CREST.** These are T4 reactive verdict-only agents. They receive inputs and return verdicts. They do not Plan, Execute multi-step work, or Replan.

**Correct governance gate placement:**

| Agent | Cadence | Placement | What It Gates |
|-------|---------|-----------|---------------|
| **Shield 🛡️** | On-demand (verdict) | **Master Synthesize Done gate** — external-facing outputs only | Security review of content exiting AInchors boundaries |
| **Lex ⚖️** | On-demand (verdict) | **Master Synthesize Done gate** — external-facing outputs only | Legal/compliance/APP review |
| **Sage 🧪** | On-demand (verdict) | **Master Synthesize Done gate** — external-facing outputs only | Accuracy, completeness, quality |
| **Warden 🔍** | 15-min cron (auto) | **Continuous** — monitors all agent model assignments | Model compliance, drift detection |

**Key architectural principle:** Shield/Lex/Sage govern **external-facing outputs** — content that exits AInchors boundaries. They do NOT gate internal artifacts:
- Atlas architecture documents → internal (no Sanctum gate)
- Thrawn platform designs → internal (no Sanctum gate)
- Forge build outputs → internal (no Sanctum gate)
- Spark LinkedIn posts → **external** (Sanctum gate at Master Done)
- Aria external communications → **external** (Sanctum gate at Master Done)
- Client deliverables → **external** (Sanctum gate at Master Done)

**Master Synthesize Done Gate sequence:**
1. Yoda Synthesize completes → integration report passes
2. If ANY sub-ticket output is external-facing → Shield → Lex → Sage (sequential)
3. Any NO-GO verdict → back to Replan with governance findings
4. All PASS → advance to Done

**Rationale:** Placing Sanctum at specialist-internal Verify (as v1.0 implied) is architecturally wrong for two reasons: (a) Sanctum reviews internal architecture documents — waste of governance tokens with no external surface to protect, and (b) cross-specialist governance issues (e.g., Spark content referencing unapproved Thrawn platform details) only surface when outputs are combined — which happens at Master Synthesize, not specialist Verify.

### 5.5 Aria (Business Lead)

**TBD at P2.** Aria is T1 (dual-principal: CEO + Yoda). Currently operates at OC1 scope. Sub-CREST model applies when Aria dispatches business-stream sub-tickets to Spark/Lando/Mon Mothma — but this is a P2 design concern. Current: Aria routes through Yoda per existing governance.

### 5.6 Design-Only Specialists (Atlas, Thrawn, Lando, Mon Mothma)

These specialists NEVER implement. Their Execute phase produces documents, diagrams, and analysis — not code, config, or state changes. This constraint is enforced at the sub-CREST level: the specialist's Plan phase never includes build atoms. If implementation is needed, the specialist's Synthesize output feeds into a Forge sub-ticket (dispatched by Yoda).

### 5.7 TOGAF Domain Coverage — Business Architecture Gap

**Current state:** No dedicated specialist for TOGAF Business Architecture domain (capability mapping, value streams, organization mapping, business model design). Lando (BPM/BPMN) covers process architecture. Mon Mothma (ADKAR) covers change/people architecture. Neither owns full Business Architecture.

**P1 (current):** Ken Mun is the de facto Business Architect. Yoda routes business architecture questions to Ken directly or infers from existing strategy docs. This is acceptable for MVP — the two-founder company IS the business architecture.

**P2 (Aug 2026 target):** Business Architecture needs explicit ownership. Options:
- **Option A:** New specialist agent (e.g., "Tarkin" — Business Architect) — separate agent with BA SOUL
- **Option B:** Expand Atlas scope to include full TOGAF BA domain (Atlas already covers B/D/A/T)
- **Option C:** Elevate Lando to Business Architecture + BPM combined role

**Decision deferred to P2 sprint planning.** No action needed for v1.1 lock — acknowledged gap with known P2 resolution path.

### 5.8 Model Routing — Phase-Aware Update Required

Model3-Policy.md (v1.0, 2026-05-10) defines per-agent model assignments with 3-level fallback chains. It was written for a Claude-primary world and does not reflect:
1. **Deepseek-primary reality** (CHG-0349 — Claude credits depleted, deepseek-pro is now primary)
2. **Per-phase model awareness** — an agent's model varies by CREST phase (Plan=pro, Execute=flash)
3. **Fallback chain degradation** — pro→kimi fallback for Plan/Verify phases is inappropriate (kimi cannot perform cognitive CREST work)

**Required before structural adoption:**
- Update Model3-Policy.md to reflect deepseek-primary
- Add `crest_phase_model_map` to agent registry for automated dispatch
- Ensure fallback chain is phase-aware: Plan/Verify/Replan fallback stays at pro tier (deepseek-pro → deepseek-pro retry, not pro → kimi)
- Warden compliance checks understand per-phase model assignments

---

## 6. Escalation Protocol

### 6.1 The Replan Decision Tree

Specialist Replan is a binary decision:

```
Specialist Replan:
├── Gap fixable at atom level?
│   └── YES → iterate (n++) back to Execute. No escalation.
│
└── Gap NOT fixable at atom level?
    └── ESCALATE to Yoda with structured handshake (§6.2)
```

**Rule: iterate(n++) OR escalate. No third option.** Specialists must never silently work around scope gaps.

### 6.2 Escalation Handshake

```json
{
  "sub_crest_escalation": {
    "status": "pending",
    "from_specialist": "atlas",
    "reason": "scope_gap | cross_specialist | assumption_change | external_block",
    "description": "Enterprise security zoning requires Thrawn's S1-S7 platform control design — not in my sub-ticket scope",
    "impacted_sub_tickets": ["TKT-xxxx-thrawn"],
    "proposed_resolution": "Yoda to sequence: Thrawn designs S1-S7 controls → Atlas incorporates into EA security domain",
    "escalated_at": "2026-06-10T04:30:00+10:00"
  }
}
```

### 6.3 Escalation Scenarios

| Scenario | Example | Resolution Path |
|----------|---------|-----------------|
| **Atom-level gap** | Forge script failed on edge case | Specialist Replan → re-execute atom. No escalation. |
| **Cross-specialist dependency** | Atlas needs Thrawn's S1-S7 design to complete EA security domain | Escalate → Yoda sequences Thrawn then Atlas |
| **Master DAG assumption change** | Thrawn discovers platform constraint invalidating Atlas's enterprise assumption | Escalate → Yoda replans: may re-dispatch Atlas with updated constraints |
| **External dependency block** | Spark needs Instagram API but not provisioned | Escalate → Yoda decides: wait / descope / workaround |
| **Specialist uncertain** | "Is this a scope gap or am I overthinking?" | Escalate. Err on side of escalation. Yoda has cross-DAG view. |

### 6.4 Yoda's Master Replan on Escalation

1. **Accept specialist's proposed fix** → specialist iterates at atom level
2. **Cross-specialist coordination needed** → spawn coordination atom, re-sequence DAG
3. **Scope change required** → adjust master DAG, potentially re-dispatch other specialists
4. **External blocker** → park sub-ticket, continue parallel sub-tickets, flag Ken if blocking critical path

---

## 6.5 Enterprise Constraint Propagation (ECU)

### 6.5.1 The Missing Direction

§6 (Escalation Protocol) handles **reactive** gap detection: specialist discovers a constraint issue → escalates to Yoda. This covers the bottom-up direction.

The **top-down direction** is equally critical: when Atlas (Enterprise Architect) produces or updates enterprise constraints, they must propagate proactively to affected specialists BEFORE they begin their Plan phase. A Thrawn sub-CREST Plan that unknowingly violates a newly-set Atlas constraint creates rework caught only at Verify or Master Synthesize.

### 6.5.2 Enterprise Constraint Update (ECU) Handoff

The ECU is a structured interface between Atlas's Synthesize output and Yoda's master CREST loop:

```json
{
  "enterprise_constraint_update": {
    "source": "atlas",
    "version": "EA_v2.1_2026-06-10",
    "constraints": [
      {
        "id": "ECU-001",
        "domain": "security",
        "statement": "API Gateway MUST reside at enterprise boundary, not inside Nexus platform",
        "applies_to": ["thrawn", "forge"],
        "type": "hard | soft | advisory",
        "priority": 10,
        "rationale": "S2 compliance: separation of concerns between platform and enterprise layers"
      }
    ],
    "invalidates": ["EA_v2.0_constraint_12"],
    "propagated_at": "2026-06-10T05:00:00+10:00"
  }
}
```

### 6.5.3 Propagation Flow

1. **Atlas Synthesize** produces ECU as part of sub-ticket deliverable, persisted to `state/enterprise-constraints.json` (PG-backed, versioned)
2. **Yoda Master Verify** reads ECU from state → identifies impacted specialists via `applies_to` field
3. **Yoda Replan** adjusts DAG: affected specialists receive ECU constraints as input to their Plan phase, referenced by ECU version
4. **Specialist Plan** reads ECU from `state/enterprise-constraints.json` (latest version) — constraints are design boundaries consumed at Plan time, not discovered mid-execution
5. **Yoda Master Verify** confirms constraint propagation coverage before advancing

**ECU discovery:** Specialists always read the current ECU version from `state/enterprise-constraints.json` (PG-backed) at Plan start. The ECU `version` field is incremented on each Atlas Synthesize that changes constraints. Yoda's Master Verify confirms the specialist consumed the correct ECU version.

**Constraint conflict resolution:** When multiple ECU constraints apply to a specialist and conflict, resolution follows: (1) `type` precedence: hard > soft > advisory, (2) `priority` numeric tiebreaker within same type (higher number = higher priority), (3) escalation to Yoda if both type and priority are equal.

### 6.5.4 Integration with Escalation Protocol

- ECU handles **proactive** constraint propagation (Atlas → Yoda → specialists)
- Escalation Protocol (§6) handles **reactive** gap detection (specialist → Yoda)
- Both feed into Yoda's Master Replan as inputs to the DAG adjustment decision
- If a specialist discovers a constraint issue that should have been in ECU, both mechanisms fire: escalation triggers immediately, and the gap is logged back to Atlas for ECU completeness

### 6.5.5 Non-CREST Constraint Propagation

Enterprise constraints also apply outside CREST execution:
- **Warden 15-min cron:** model compliance checks read from ECU for model assignment validation
- **Governance agents (Shield/Lex/Sage):** consume ECU at Master Synthesize gate for external-output compliance
- **Agent onboarding:** new specialists receive current ECU as part of their SOUL.md constraints section

---

## 7. Synthesize Boundaries

### 7.1 Two-Level Synthesize

CREST v1.1 has TWO distinct Synthesize phases at different recursion levels:

| Level | Who | What It Integrates | What It Tests |
|-------|-----|-------------------|---------------|
| **Specialist Synthesize** | Atlas/Thrawn/etc (flash) | Atoms within one sub-ticket | Internal coherence, domain completeness, atom-to-atom consistency |
| **Master Synthesize** | Yoda (flash) | Sub-ticket deliverables across specialists | Cross-domain coherence, interface consistency, contradictory assumptions, end-to-end narrative |

### 7.2 Master Synthesize Integration Checklist

Master Synthesize is NOT "read all sub-ticket outputs and concatenate." It is an active integration test:

1. **Interface consistency:** Does specialist A's output reference a concept specialist B defines differently?
   - *Automatable:* Named-entity extraction + cross-reference matching
2. **Assumption alignment:** Did two specialists make contradictory assumptions?
   - *Semi-automatable:* Keyword matching for known assumption patterns; conflicts flagged for Yoda judgment
3. **Gap detection:** Is there a piece that NO specialist owned?
   - *Human-judgment gate:* Requires understanding of the master ticket's full scope — Yoda performs this
4. **Narrative coherence:** Does the combined output tell one story, or disconnected stories?
   - *Human-judgment gate:* Yoda reads combined outputs and applies editorial judgment

**Automation target:** Checks 1 and 2 can be assisted by tooling (cross-reference extractors, assumption keyword matchers). Checks 3 and 4 are inherently Yoda's cognitive judgment — no automation target. The checklist is a structured guide for Yoda's review, not a script to run.

### 7.3 Integration Report Format

```json
{
  "master_synthesize": {
    "sub_tickets_integrated": ["TKT-xxxx-atlas", "TKT-xxxx-thrawn", "TKT-xxxx-forge"],
    "interface_checks": [
      {"pair": ["atlas", "thrawn"], "interface": "API Gateway placement", "status": "aligned"},
      {"pair": ["atlas", "forge"], "interface": "Infra spec vs EA infra domain", "status": "conflict", "detail": "Atlas specifies 18789, Forge built 18791"}
    ],
    "assumption_checks": [
      {"pair": ["thrawn", "forge"], "assumption": "Container runtime", "status": "aligned"}
    ],
    "gaps_found": 1,
    "gaps": [
      {"description": "Data residency policy not addressed by any specialist", "severity": "high"}
    ],
    "verdict": "gaps_found → Replan"
  }
}
```

### 7.4 L-054 Compliance

Lesson L-054 (CREST First Execution Learnings, 2026-06-10): "Synthesize e2e test MUST test ALL atoms together, not just individual atoms. The integration gaps only surfaced when all pieces ran together."

Master Synthesize is the embodiment of this lesson at the cross-specialist level. Individual specialist Synthesizes catch domain-internal gaps. Master Synthesize catches integration gaps that no single specialist could see.

---

## 8. Dispatch Validation (Risk 1 — Resolved)

### 8.1 Two Dispatch Levels

Model C introduces two dispatch levels:

| Level | From → To | What's Dispatched | Validation |
|-------|-----------|-------------------|------------|
| **Level 1** | Yoda → Specialist | Sub-ticket (scope, ACs, domain, model assignment) | `dispatch-validate.sh` (TKT-0323) |
| **Level 2** | Specialist → Cheap Executor | Atom (verb, target, pre/post conditions) | Specialist self-validation + Yoda meta-verification |

### 8.2 Level 2 Validation — Atom Pre-Flight Gate

Level 2 dispatch (Specialist → Cheap Executor) uses a **lightweight pre-flight validation wrapper.** It is NOT a full `dispatch-validate.sh` clone — it is a ~20-line structural check invoked by the specialist before spawning the cheap executor.

**Pre-flight checks (all MUST pass):**
1. `verb` field present and non-empty
2. `target` field present and non-empty (file path, resource, endpoint)
3. `pre_conditions` array present (at least one entry)
4. `post_conditions` array present (at least one entry)
5. Atom is non-empty (no null/whitespace-only atoms)
6. Model assignment is explicit (no "default" or ambiguous model)

**Why machine-gate instead of discipline-only:**
- Flash-tier executors (gemma4, kimi) do NOT challenge ambiguous inputs — they attempt execution regardless
- L-053: direct spawn bypasses atom tracking → burned tokens on undefined work
- L-054: never trust self-report → same principle applies to atom validity
- The 2-Pass Contract is enforced at Level 1 by `dispatch-validate.sh` (machine-enforceable)
- Level 2 needs equivalent structural protection, specialized for atom granularity

**Implementation:** `scripts/atom-validate.sh` — invoked by specialist as part of Execute dispatch. Returns exit 0 (valid) or exit 1 with error details (invalid). Specialist blocks dispatch on exit 1.

**Yoda meta-verification** (§8.3) provides the post-hoc audit: were all dispatched atoms valid? This catches discipline failures but does not prevent them — the pre-flight gate prevents them.

### 8.3 TKT-0323 Extension

TKT-0323 (`dispatch-validate.sh`) remains at Level 1 (Yoda → Specialist). Additional ACs:
- CREST-specific validation: "Specialist atom breakdown present and concrete" as DoD gate at master Verify
- `scripts/atom-validate.sh` created and integrated into specialist dispatch flow
- Level 2 pre-flight gate blocks invalid atom dispatches (exit 1 → no execution)

### 8.4 Tool-Call Rejection Recovery (L-089 — New)

**Failure mode (L-089, 2026-06-13):** A batched tool call returned a schema-rejection error (`invalid cron.update params: at /patch: unexpected property '$text'`). The agent (Yoda) emitted architectural commentary *instead of* retrying the corrected call in the same turn, and waited for the user to manually nudge with "update." A human should never have to nudge a tool-rejection recovery.

**Root causes (compound):**
1. **Tool-call hygiene** — batched N>2 tool calls of the same type were not independently validated before the next was issued. One contained a copy-paste artifact (leaked tool-call template syntax) that contaminated the `patch` payload.
2. **Stall-on-rejection pattern** — the rejected result was treated as a stop condition rather than a signal to retry. Architectural explanation was emitted *instead of* the corrected retry, not *before* it.

**Structural enforcement rules (NON-NEGOTIABLE — same status as 8.1–8.3):**

1. **Reject-on-failure, do not stop.** When a tool call returns a non-success result (schema rejection, validation error, network failure), the next action in the same turn is to **retry the corrected call alone**. Do not pivot to architecture, summary, or commentary. Do not wait for user input.
2. **Batch validation gate.** When batching N>2 tool calls of the same type, after each call check the result. On any non-success result, **stop the batch, retry the failed call alone, then continue with the remaining batch**. Do not assume remaining batched calls will succeed.
3. **Same-turn completion test.** Before yielding the turn, run a self-check: "If this tool call had failed on the next turn, would the user need to nudge me?" If yes, finish the retry loop in this turn. A user nudge is a S1-grade signal that the loop was broken.
4. **Copy-paste hygiene.** When constructing N similar tool calls, the Nth call's JSON payload must be a fresh composition, not a paste of the (N-1)th. Validate each call's `params` shape before issuing — particularly `patch` and `metadata` objects that have nested required fields.
5. **Rejection classification.** Distinguish three rejection types:
   - **Schema/format error** (e.g., `unexpected property '$text'`) → my fault, retry with corrected payload, same turn.
   - **Validation/business error** (e.g., `ticket not found`, `permission denied`) → fix and retry, same turn.
   - **External/environment error** (e.g., Telegram HTTP 500, PG connection refused) → escalate to user, do not loop.

**Detection hook:** The Lesson Registry (`memory/LESSONS.md`) already captures each occurrence. The `scripts/crest-done-gate.sh` is the natural enforcement point — add a check: "if any tool call in the past N turns returned a non-success result and the agent emitted an explanatory block without a follow-up tool call, the gate FAILS with a CREST-rejection-stall error."

**Verified:** L-089 logged 2026-06-13. This section added 2026-06-13 same day. CHG-0523 to be filed by Atlas (not Yoda, per routing rules — the lesson is about Yoda's stall, so the change should be reviewed by a non-Yoda agent).

**Linked:** L-089, TKT-0501, CHG-0522, scripts/crest-done-gate.sh (enforcement point).

---

## 9. 2-Pass Contract Alignment

### 9.1 Recursive 2-Pass

The 2-Pass Contract (TKT-0321) applies recursively:

```
Level 1 (Yoda → Specialist):
  Pass 1 (Discovery): Yoda analyzes master ticket, breaks into sub-tickets, assigns specialists
  Pass 2 (Execution): Specialist receives sub-ticket, runs sub-CREST

Level 2 (Specialist → Executor):
  Pass 1 (Discovery): Specialist Plans atoms for sub-ticket
  Pass 2 (Execution): Cheap executor receives pre-discovered atoms, runs RVEV
```

### 9.2 RVEV Still Applies

RVEV (READ → VALIDATE → EXECUTE → VERIFY) is the leaf-level execution cycle. Every atom dispatched by a specialist to a cheap executor follows RVEV. The specialist's Verify phase independently checks executor outputs — never trusts self-report (L-054).

---

## 10. Cost Model

### 10.1 Per-Cycle Estimates

Per sub-CREST cycle (no Replan iterations):

| Phase | Model | Typical Tokens |
|-------|-------|---------------|
| Specialist Plan | pro | 2-4K |
| Specialist Execute (N atoms) | flash | 1-3K per atom |
| Specialist Verify | pro | 1-3K |
| Specialist Replan | pro (only if gap) | 1-2K |
| Specialist Synthesize | flash | 1-2K |

Per master CREST cycle:

| Phase | Model | Typical Tokens |
|-------|-------|---------------|
| Yoda Plan | pro | 2-4K |
| Yoda Verify (M sub-tickets) | pro | 1-2K per sub-ticket |
| Yoda Replan | pro (only if gap) | 1-3K |
| Yoda Synthesize | flash | 1-3K |

### 10.2 Example: 3-Sub-Ticket Master Ticket

- Yoda: ~3 pro calls (Plan + Verify×3 + Synthesize via flash) = ~10K pro tokens
- 3 specialists: ~3 pro calls each (Plan + Verify, no Replan) = ~18K pro tokens
- Execute atoms: ~5-10 flash calls across all specialists = ~10-20K flash tokens
- **Total: ~28K pro + ~15K flash tokens**

This is higher than flat CREST in pro token count, but the quality differential is massive — domain experts do cognitive work instead of Yoda guessing across domains. The cost is justified by correctness.

---

## 11. Adoption Path

### 11.1 Immediate (Discipline-Process)

- Yoda applies Model C manually when dispatching sub-tickets
- Specialists self-enforce sub-CREST phases (Plan → Execute → Verify → Replan → Synthesize)
- Escalation protocol via structured handshake (not yet automated — manual JSON state file)
- Master Synthesize integration checklist run manually

### 11.2 Structural Implementation Prerequisites

These items MUST be designed and built before structural CREST adoption. They are listed here as prerequisites, not "target" items — the lessons from L-053 and L-054 demonstrate that discipline-only enforcement fails under load.

#### 11.2.1 PG State Schema — Sub-CREST Tables

**`state_sub_crest` table** — one row per specialist sub-ticket execution:

| Column | Type | Description |
|--------|------|-------------|
| `sub_crest_id` | UUID PK | Unique sub-CREST execution ID |
| `parent_ticket_id` | TEXT FK | Master ticket this sub-CREST belongs to |
| `specialist` | TEXT | Agent ID (atlas, thrawn, spark, etc.) |
| `current_phase` | ENUM | planning/executing/verifying/replanning/synthesizing/done/escalated |
| `iteration_count` | INT | Number of Replan→Execute loops (n++) |
| `plan_model` | TEXT | Model used for Plan phase |
| `execute_model` | TEXT | Model used for Execute phase |
| `verify_model` | TEXT | Model used for Verify phase |
| `verify_verdict` | ENUM | pending/pass/fail |
| `escalation_json` | JSONB | Escalation handshake data (§6.2) |
| `created_at` | TIMESTAMP | Sub-CREST creation time |
| `updated_at` | TIMESTAMP | Last state transition |

**`state_sub_crest_atoms` table** — per-atom tracking within a sub-CREST:

| Column | Type | Description |
|--------|------|-------------|
| `atom_id` | UUID PK | Unique atom ID |
| `sub_crest_id` | UUID FK | Parent sub-CREST |
| `atom_index` | INT | Ordinal position in sequence |
| `verb` | TEXT | Atom verb |
| `target` | TEXT | Atom target |
| `model` | TEXT | Executor model assigned |
| `rvev_trace` | JSONB | READ/VALIDATE/EXECUTE/VERIFY results |
| `status` | ENUM | pending/running/completed/failed |

#### 11.2.2 TQP State Machine Extension

Current TQP: `pending → claimed → completed | failed` (flat, single-level).

Extended TQP for recursive CREST:

```
MASTER LEVEL (Yoda):
  master_planning → sub_tickets_dispatched → master_verifying → master_replanning → master_synthesizing → done

SUB-CREST LEVEL (Specialist):  
  sub_crest_planning → sub_crest_executing → sub_crest_verifying → sub_crest_replanning → sub_crest_synthesizing → sub_crest_done
  
  Any sub-CREST state → escalated (terminal sub-state, triggers master_replanning)
  sub_crest_replanning → sub_crest_executing (n++ loop)

ATOM LEVEL (Executor):
  pending → claimed → completed | failed  (unchanged)
```

**Key additions:**
- `parent_task_id` column in TQP tasks — links atoms to sub-tickets to master ticket
- New transition types: `escalate`, `replan_iterate`, `sub_crest_complete`
- Yoda can query: which specialist is in which sub-CREST phase right now?
- TQP Execution Gate (TKT-0309) extended: persist sub-CREST phase transitions to PG before announcing

#### 11.2.3 Build Order

1. PG schema (state_sub_crest + state_sub_crest_atoms tables)
2. TQP state machine extension (new states + transitions)
3. Model3-Policy.md update (deepseek-primary, per-phase model assignments, phase-aware fallback chains — §5.8)
4. `scripts/atom-validate.sh` (Level 2 pre-flight gate)
5. `dispatch-validate.sh` extended for CREST sub-ticket schema
6. Flash dispatcher (TKT-0370) handles Level 1 + Level 2 dispatch with phase-aware routing
7. Escalation protocol integrated with TQP state transitions
8. Master Synthesize integration checks automated (where automatable)

### 11.3 Trigger Gates

| Trigger | What Unlocks |
|---------|-------------|
| TKT-0368 Phase 1 | CREST structural foundation |
| TKT-0370 (Flash Dispatcher) | Automated Level 1 + Level 2 dispatch |
| TKT-0323 extended | CREST-aware dispatch validation |
| OC2 (TRIGGER-03) | Full parallel sub-CREST execution (hardware capacity) |

---

## 12. Non-Negotiables (Carried Forward from v1.0)

1. **CREST Verify MUST be independent** — Yoda greps, executes, tests. Never accept sub-agent self-report as proof. (L-054)
2. **Replan MUST iterate back to Execute** when gap found. Never forward-fix in Replan phase. (L-054)
3. **Synthesize tests ALL atoms/sub-tickets together.** Integration gaps only surface in combination. (L-054)
4. **Replan gate is critical.** Premature "stop met" skips gap detection. (L-054)
5. **2-Pass Contract:** No executor receives undiscovered work. (TKT-0321)
6. **TQP Execution Gate:** Persist state to PG before announcing completion. (TKT-0309)
7. **Strong-tier plans/judges, cheap-tier executes.** Pro = cognitive, flash = mechanical. (CREST core)
8. **Forge exception (§5.2):** Forge Plan + Synthesize = flash. Verify + Replan = pro.
9. **Escalation is iterate(n++) OR escalate. No third option. (§6)**

---

## 13. Review & Approval

| Reviewer | Role | Verdict | Date | Notes |
|----------|------|---------|------|-------|
| Ken Mun | CTO | APPROVED (Model C) | 2026-06-10 04:34 AEST | Decision: recursive CREST topology |
| Atlas 🏛️ | Enterprise Architect | PASS WITH FINDINGS (v1.1) | 2026-06-10 04:42 AEST | 5 findings: constraint propagation, governance gates, TOGAF BA gap, ECU interface, Spark model governance. All resolved in v1.2. |
| Thrawn 🔵 | Platform Architect | PASS WITH FINDINGS (v1.1) | 2026-06-10 04:44 AEST | 8 findings: Level 2 validation, TQP state, PG schema, model routing, parallel exec, escalation TQP, Forge loop, Synthesize automation. All resolved in v1.2. |
| Atlas 🏛️ | Enterprise Architect | **PASS (v1.2)** | 2026-06-10 04:56 AEST | All 5 v1.1 findings closed. 3 LOW observations (ECU priority, Forge monitor owner, Model3-Policy dependency) — addressed in final v1.2. |
| Thrawn 🔵 | Platform Architect | **PASS (v1.2)** | 2026-06-10 04:57 AEST | All 8 v1.1 findings closed. 3 LOW observations (duplicate §5.3, build order incomplete, ECU discovery) — addressed in final v1.2. |

---

## Appendix A: Glossary

| Term | Definition |
|------|-----------|
| **CREST** | Cognitive Routing & Execution Sandwich Topology |
| **Master CREST** | Yoda's 6-phase loop over sub-tickets |
| **Sub-CREST** | Specialist's 6-phase loop over atoms within a sub-ticket |
| **RVEV** | READ → VALIDATE → EXECUTE → VERIFY — leaf-level atom execution |
| **Pro** | deepseek-v4-pro:cloud — cognitive work (Plan, Verify, Replan) |
| **Flash** | deepseek-v4-flash:cloud — mechanical work (Execute, Synthesize) |
| **Escalation** | Specialist Replan → Yoda handshake when gap not fixable at atom level |
| **ECU** | Enterprise Constraint Update — Atlas-to-specialists proactive constraint propagation |
| **Master Synthesize** | Cross-specialist integration test (not concatenation) |
| **Specialist Synthesize** | Domain-internal atom integration |
| **2-Pass Contract** | Pass 1 (Discovery) → Pass 2 (Execution); no executor receives undiscovered work |

## Appendix B: Change History

| Version | Date | Author | Change |
|---------|------|--------|--------|
| v1.0 | 2026-06-09 | Yoda | Initial CREST topology (flat) — MEMORY.md locked |
| v1.1 | 2026-06-10 | Yoda | Recursive topology (Model C) — initial DRAFT FOR REVIEW |
| v1.2 | 2026-06-10 | Yoda | Atlas (5) + Thrawn (8) findings resolved + 3 v1.2 observations fixed. LOCKED with dual PASS. |
| v1.2.1 | 2026-06-13 | Yoda | §8.4 Tool-Call Rejection Recovery added (L-089). 5 structural rules: reject-on-failure-no-stop, batch validation gate, same-turn completion test, copy-paste hygiene, rejection classification. Enforcement point: scripts/crest-done-gate.sh. DRAFT FOR REVIEW (Ken). |
