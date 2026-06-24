---
name: crest
description: CREST — Cognitive Routing & Execution Sandwich Topology (recursive Model C, v1.3). 6-phase sandwich, external loop ownership, Sage-as-Judge Verify, capability-based multi-model routing (PG SSOT), 2-Pass Contract, escalation protocol, governance placement.
---

# CREST skill — When to Load

Load this skill whenever you are:

- **Starting or executing any task** that involves planning + execution work — CREST is mandatory for every such loop (Ken mandate 2026-06-13).
- **Dispatching a sub-ticket** to a specialist (Atlas, Thrawn, Spark, Lando, Mon Mothma, Forge) — apply the Master/Sub-CREST topology.
- **Choosing a model** for a specialist phase — use `scripts/model-policy-query.sh --agent <id> --phase <phase>` (PG-first, JSON fallback).
- **Handling a Verify failure** — Sage renders verdict; apply the Replan decision tree (iterate(n++) OR escalate).
- **Integrating sub-ticket deliverables across specialists** — Master Synthesize integration checklist.
- **Deciding whether to invoke governance agents** (Shield/Lex/Sage) — Master Synthesize Done gate only, external-facing only.
- **Closing a ticket** — DoD Verification Gate (RULES.md §DoD VERIFICATION GATE).
- **Self-checking** whether CREST was used (Ken asks "did you use CREST?" = violation → LESSONS.md).

> **Self-check rule (MEMORY.md §CREST Enforcement):** If Ken asks "did you use CREST?" that is itself a violation — log to LESSONS.md.

---

## Quick Reference — The 6-Phase Sandwich

CREST applies **recursively** (Model C, v1.3 LOCKED, CHG-0680) at two levels:

```
Plan → Execute → Verify → Replan → Synthesize → Done
```

| # | Phase | Model tier | Cognitive work | Output |
|---|-------|------------|----------------|--------|
| 1 | **Plan** | role-dependent | Scope, DAG, atoms, model spec, trade-offs | Typed DAG + atom breakdown |
| 2 | **Execute** | role-dependent | Mechanical work — write, build, dispatch | Atoms completed (RVEV per atom) |
| 3 | **Verify** | gemma4:31b-cloud (primary) | Sage renders verdict; specialists assemble evidence | Binary pass/fail/needs_human verdict |
| 4 | **Replan** | role-dependent | Gap analysis; iterate(n++) OR escalate | Re-dispatch or escalate |
| 5 | **Synthesize** | role-dependent | Integration (specialist: domain-internal; master: cross-specialist) | Sub-ticket / master deliverable |
| 6 | **Done** | terminal | Audit emit, close, Holocron register | Closed ticket + audit trail |

**CREST v1.3:** Capability-based multi-model routing by **role × phase**. Each role×phase has a specific default_model + fallback_model in PG `crest_phase_rules`. The `data_class` dimension is schema-ready but intentionally unpopulated in v1.3; full `role × data_class × phase` routing is deferred to CREST v2.0 / TKT-0710.
**Concrete model resolution:** use `scripts/model-policy-query.sh --agent <agent-id> --phase <phase>` (PG-first, JSON fallback).
The authoritative source is PG `state_model_policy.crest_phase_rules`. Do not hardcode models in plans.

---

## Model Assignment Matrix (CREST v1.3)

| Role | Plan | Execute | Verify | Replan | Synthesize |
|------|------|---------|--------|--------|-----------|
| **yoda_master** (Yoda) | kimi-k2.7-code | **none** | deepseek-v4-pro | kimi-k2.7-code | kimi-k2.7-code |
| **design_backend** (Atlas/Thrawn/Lando/Mon) | deepseek-v4-pro | deepseek-v4-flash | gemma4:31b | deepseek-v4-pro | deepseek-v4-flash |
| **creative** (Spark) | kimi-k2.6 | deepseek-v4-flash¹ | gemma4:31b | kimi-k2.6 | deepseek-v4-flash |
| **build** (Forge) | deepseek-v4-flash² | deepseek-v4-flash | gemma4:31b | deepseek-v4-pro | deepseek-v4-flash |
| **business** (Ahsoka/Luthen) | kimi-k2.7-code | deepseek-v4-flash | gemma4:31b | kimi-k2.7-code | deepseek-v4-flash |
| **governance** (Shield/Lex/Sage/Warden) | gemma4:31b | deepseek-v4-flash | gemma4:31b | gemma4:31b | deepseek-v4-flash |

¹ Spark high-stakes Execute may override to kimi-k2.6 with `override_allowed: true` + `override_reason`.
² Forge exception (Ken 2026-06-10): Plan/Execute/Synthesize use flash-tier; Verify/Replan use gemma4:31b/deepseek-v4-pro.

**Concrete models:** Query `scripts/model-policy-query.sh --all`. PG `crest_phase_rules` is SSOT. Updated by CHG-0690: `yoda_master` and `business` Plan/Replan now default to `kimi-k2.7-code:cloud`.

---

## Model resolution (CREST v1.3)

Models are resolved by role×phase from PG `state_model_policy.crest_phase_rules` (SSOT).

1. `scripts/model-policy-query.sh --agent <id> --phase <phase>` queries PG first.
2. Falls back to `state/model-policy.json` `crest_v13.phase_rules` if PG unavailable.
3. Further falls back to `agentTiers` (v1.2 compat) if v1.3 section missing.

**Verify phase:** Sage (qa agent) renders verdict. All other agents assemble evidence only.
**Verify fallback chain:** gemma4:31b-cloud → deepseek-v4-pro:cloud.
**needs_human timeout:** 4 hours; auto-escalates to Yoda.

**L-026:** Build/scripts → Forge ONLY. Atlas = EA assessment. Thrawn = architecture design. Never route build work to Atlas or Thrawn.

**Yoda Execute gate:** Any Yoda Execute requires per-instance Ken approval and a CHG record.

CREST is **fractal**. The same 6-phase sandwich applies at every level of work decomposition:

```
Master ticket → sub-tickets → atoms
    │               │            │
    └── Master CREST └── Sub-CREST └── RVEV (READ → VALIDATE → EXECUTE → VERIFY)
```

| Level | Orchestrator | Inputs | Outputs |
|-------|--------------|--------|---------|
| **Master CREST** | Yoda (deepseek-pro) | Master ticket | Sub-ticket assignments, integration report, audit |
| **Sub-CREST** | Specialist (role×phase matrix per CREST v1.3) | Sub-ticket | Atom breakdown, sub-ticket deliverable |
| **RVEV** | Cheap executor | Atom | Atom result + self-trace |

**Parallel execution:** Sub-CRESTs run in parallel where the master DAG allows. Race-condition guard: shared write targets must be declared in the specialist's Plan output → Yoda sequences them (no parallel writes to shared state).

---

## Yoda Boundary Rules — NON-NEGOTIABLE (Ken 2026-06-13, CHG-0545)

Yoda's CREST activities:

| Phase | Yoda's role? |
|-------|--------------|
| Plan | ✅ Yes (pro) |
| Execute | ❌ **NEVER** — delegate to specialists / Forge / infra executors |
| Verify | ✅ Yes (pro, independent — L-054) |
| Replan | ✅ Yes (pro) |
| Synthesize | ✅ Yes (flash — cross-specialist integration) |
| Close | ✅ Yes (terminal — emit audit) |

**Exception path:** Any Yoda Execute requires per-instance Ken approval, logged to CHANGELOG.md, before dispatch.

**Build/scripts → Forge ONLY.** Atlas = EA assessment. Thrawn = architecture design. NEVER route build work to Atlas or Thrawn (L-026).

---

## Model Assignment Matrix (CREST v1.3 — PG state_model_policy.crest_phase_rules)

| Specialist | Plan | Execute | Verify | Replan | Synthesize | Design-only? |
|-----------|------|---------|--------|--------|-----------|-------------|
| **Yoda** | pro | — | pro | pro | flash | Master orchestrator |
| **Atlas 🏛️** | pro | flash | pro | pro | flash | ✅ Yes (design-only) |
| **Thrawn 🔵** | pro | flash | pro | pro | flash | ✅ Yes (design-only) |
| **Spark ✨** | pro | **flash** ⚠️¹ | pro | pro | flash | ❌ No (creative) |
| **Lando 🟡** | pro | flash | pro | pro | flash | ✅ Yes (design-only) |
| **Mon Mothma 🌟** | pro | flash | pro | pro | flash | ✅ Yes (design-only) |
| **Forge 🏗️** | **flash** ⚠️² | flash | pro | pro | **flash** ⚠️² | ❌ No (build) |

**⚠️¹ Spark creative override:** Spark defaults to flash for Execute. High-stakes atoms (Ken's personal LinkedIn, campaign launch, client-facing content) may be assigned pro for that specific atom — per-atom judgment call, documented with `model_override: "pro"` + `override_reason`. Warden's 15-min cron scans for pro-assigned atoms and logs for Yoda visibility. If pro-assignment rate > 20% of Spark atoms in a sprint, Warden alerts Yoda for review.

**⚠️² Forge exception (agreed by Ken 2026-06-10):** Forge is execution-heavy by nature — Plan/Synthesize use flash (mechanical: dependency mapping, tool selection, log assembly). Verify/Replan use pro (judging whether a build worked correctly requires pro-level reasoning). Monitor: Yoda checks via TQP state at Master Verify — if > 30% of Forge sub-CRESTs hit Replan (iteration_count > 0), reassess flash-for-Plan assumption. Warden's 15-min cron also scans Forge Replan rate.

**Design-only constraint (Atlas, Thrawn, Lando, Mon Mothma):** These specialists NEVER implement. Their Execute phase produces documents, diagrams, analysis — not code, config, or state changes. If implementation is needed, specialist's Synthesize output feeds into a Forge sub-ticket dispatched by Yoda.

---

## 2-Pass Contract (TKT-0321, applies recursively)

```
Level 1 (Yoda → Specialist):
  Pass 1 (Discovery): Yoda analyzes master ticket → sub-tickets + specialist assignment
  Pass 2 (Execution): Specialist receives sub-ticket → runs Sub-CREST

Level 2 (Specialist → Executor):
  Pass 1 (Discovery): Specialist Plans atoms for sub-ticket
  Pass 2 (Execution): Cheap executor receives pre-discovered atoms → runs RVEV
```

**Rule:** No executor receives undiscovered work. Every atom has verb, target, pre/post conditions, model assignment — explicit, no defaults.

**Level 2 pre-flight gate:** `scripts/atom-validate.sh` (~20-line structural check) — specialist invokes before dispatch. Exit 1 = blocked. Checks: verb, target, pre_conditions, post_conditions, non-empty atom, explicit model.

### TQP — Mandatory Atom Queue (TKT-0504)

Every CREST Execute phase that produces more than one atom **MUST pass through the Task Queue Processor (TQP)**. TQP is the durable dispatch layer for CREST atoms.

**When TQP is mandatory:**
- Any Execute phase with ≥ 2 atoms.
- Any cross-specialist or cross-system change (state, config, infra, external API).
- Any work that needs recovery if interrupted (gateway restart, timeout, crash).
- Any atom with a verify step that may require iteration.

**TQP usage pattern:**
1. **Plan** writes atoms as TQP rows in `state_task_queue`:
   - `atom_id`, `parent_ticket`, `verb`, `target`, `pre_conditions`, `post_conditions`, `model`, `timeout_seconds`, `owner` (agent/executor)
2. **TQP executor** (`scripts/tqp-executor.sh --poll-once`, cron `dc88affb`) claims ready atoms and dispatches them.
3. **Executor** runs RVEV on its claimed atom and writes the result + evidence back to the queue.
4. **Yoda Verify** reads completed atoms from TQP, judges 0/1 per atom.
5. **Replan** re-queues failed atoms with `iteration_count` incremented OR escalates.
6. **Synthesize** integrates TQP-completed atoms into the deliverable.

**Single-atom exception:** A CREST loop with exactly one simple, idempotent, low-risk atom (e.g., one file read, one Telegram status reply) may bypass TQP, but must still produce explicit atom documentation in the Plan output.

**Safety rules for TQP atoms:**
- Every atom is **idempotent** — running it twice must not corrupt state.
- Every atom declares its **side-effect scope** (read-only, file-write, db-write, API-call, infra-change).
- Parallel atoms must declare **shared resources**; conflicting writes are sequentialised by TQP priority.
- On gateway restart, TQP picks up unclaimed/incomplete atoms automatically.

**Level 2 pre-flight gate (TQP extension):** `scripts/atom-validate.sh` checks structure; `scripts/tqp-validate.sh` checks queue schema and idempotency declaration for TQP-queued atoms.

---

## Escalation Protocol — iterate(n++) OR escalate (no third option)

> Source: `docs/CREST-v1.3-Recursive-Model-C.md` §6 (LOCKED, CHG-0680).

```
Specialist Replan:
├── Gap fixable at atom level?
│   └── YES → iterate (n++) back to Execute. No escalation.
│
└── Gap NOT fixable at atom level?
    └── ESCALATE to Yoda with structured handshake (§6.2)
```

**Rule:** Specialists must never silently work around scope gaps. **No iteration threshold** — escalation triggers immediately when the gap is not atom-fixable.

**Escalation handshake (specialist → Yoda):**

```json
{
  "sub_crest_escalation": {
    "status": "pending",
    "from_specialist": "<agent_id>",
    "reason": "scope_gap | cross_specialist | assumption_change | external_block",
    "description": "<what's blocked>",
    "impacted_sub_tickets": ["TKT-xxxx-<specialist>"],
    "proposed_resolution": "<Yoda action requested>",
    "escalated_at": "<ISO 8601>"
  }
}
```

**Escalation scenarios (full table in references/§6.3):**
- Atom-level gap → iterate, no escalation
- Cross-specialist dependency → escalate, Yoda sequences
- Master DAG assumption change → escalate, Yoda replans
- External dependency block → escalate, Yoda decides wait/descope/workaround
- Specialist uncertain → escalate (err on side of escalation)

**Yoda Master Replan options on escalation:**
1. Accept specialist's proposed fix → specialist iterates at atom level
2. Cross-specialist coordination → spawn coordination atom, re-sequence DAG
3. Scope change → adjust master DAG, potentially re-dispatch other specialists
4. External blocker → park sub-ticket, continue parallel sub-tickets, flag Ken if blocking critical path

---

## Master Synthesize Integration Checklist (NOT concatenation)

Master Synthesize is an **active integration test** across sub-ticket deliverables:

1. **Interface consistency** — Does specialist A's output reference a concept specialist B defines differently? (Automatable: named-entity extraction + cross-reference matching.)
2. **Assumption alignment** — Did two specialists make contradictory assumptions? (Semi-automatable: keyword matching for known patterns.)
3. **Gap detection** — Is there a piece NO specialist owned? (Human-judgment gate: Yoda performs this.)
4. **Narrative coherence** — Does the combined output tell one story, or disconnected stories? (Human-judgment gate: Yoda reads combined outputs and applies editorial judgment.)

**L-054 compliance:** Synthesize tests ALL atoms/sub-tickets together. Integration gaps only surface in combination.

**Integration report shape** — see `docs/CREST-v1.3-Recursive-Model-C.md` §7.3 for full JSON schema.

---

## Exceptions Summary

| Exception | Scope | Mechanism |
|-----------|-------|-----------|
| **Spark creative pro override** | High-stakes Execute atoms | Per-atom `model_override: "pro"` + `override_reason`; Warden 15-min cron audits; alert if > 20% pro-rate per sprint |
| **Forge Plan/Synthesize flash** | Forge only | Agreed by Ken 2026-06-10; rationale: Forge domain is execution-heavy (Plan/Synthesize are mechanical); Verify/Replan remain pro. Monitor > 30% Replan rate. |
| **Yoda Execute** | Yoda only | Per-instance Ken approval, logged to CHANGELOG.md, before dispatch |
| **Old-code audit remediation policy** | TKT-0529 and future old-code audits | Auto-destructive hygiene/health housekeeping retained; context-file rewrites gated to NEEDS_KEN; new shared lib `scripts/lib/atomic-write.sh` for atomic state writes (Ken 2026-06-18) |

## Old-Code Audit Remediation Policy (TKT-0529, Ken 2026-06-18)
When remediating legacy scripts discovered through CREST old-code audits:
1. **Auto-destructive hygiene/health housekeeping ops are retained** (e.g. stale plugin dir cleanup, stale lock cleanup, orphan gateway kill, PG sequence resync) when they have proven safety history and are bounded to platform health.
2. **Exception:** any auto-rewrite of injected context files (SOUL.md, AGENTS.md, MEMORY.md, HEARTBEAT.md) MUST be gated to `NEEDS_KEN`, not auto-executed.
3. **Atomic state writes** MUST use the shared helper at `scripts/lib/atomic-write.sh` rather than being inlined per script.
4. **Baseline hygiene** applies to all audited scripts: `set -euo pipefail`; replace hardcoded user paths with `${WORKSPACE_ROOT}`; prefer PG SSOT over JSON where canonical.
---

## Governance Agents Placement (Shield 🛡️ / Lex ⚖️ / Sage 🧪 / Warden 🔍)

**Architectural principle:** Shield/Lex/Sage are **T4 reactive verdict-only** agents. They gate **external-facing outputs** at **Master Synthesize Done**. They do **NOT** gate specialist-internal Verify (no Sanctum gate on internal architecture docs, platform designs, or build outputs).

| Agent | Cadence | Placement | What It Gates |
|-------|---------|-----------|---------------|
| **Shield 🛡️** | On-demand (verdict) | Master Synthesize Done gate — external-facing only | Security review |
| **Lex ⚖️** | On-demand (verdict) | Master Synthesize Done gate — external-facing only | Legal/compliance/APP |
| **Sage 🧪** | On-demand (verdict) | Master Synthesize Done gate — external-facing only | Accuracy, completeness, quality |
| **Warden 🔍** | 15-min cron (auto) | **Continuous** — all agent model assignments | Model compliance, drift |

**External-facing surfaces (require governance gate):**
- Spark LinkedIn posts
- Aria external communications
- Client deliverables
- Any output crossing AInchors boundaries

**Master Synthesize Done Gate sequence:**
1. Yoda Synthesize completes → integration report passes
2. If ANY sub-ticket output is external-facing → Shield → Lex → Sage (sequential)
3. Any NO-GO verdict → back to Replan with governance findings
4. All PASS → advance to Done

**Rationale (why not at specialist Verify):** Sanctum reviews at specialist Verify would (a) waste governance tokens on internal artefacts with no external surface, and (b) miss cross-specialist governance issues that only surface when outputs combine at Master Synthesize.

---

## CREST Enforcement Rules — NON-NEGOTIABLE (MEMORY.md, LOCKED 2026-06-11)

1. **No silent execution** — Plan phase explicit even for single-atom tasks.
2. **Skill-gate always** — `bash scripts/skill-load.sh <name>` before domain scripts (TKT-0396).
3. **No tribal knowledge** — reference skills, not inline memory.
4. **Model tier discipline** — Plan/Verify/Replan = strong, Execute/Synthesize = cheap.
5. **Triage mode is not an exemption** — each operational action starts a new CREST loop.
6. **Self-check** — if Ken asks "did you use CREST?" that's a violation → LESSONS.md.

### Evidence-Only Verification Rule (L-054 + L-113)

> **Done/verified/closed = validated + backed by artifacts. Vibe ≠ fact. Assertion ≠ execution.**

| What counts as evidence | What does NOT count |
|------------------------|---------------------|
| Tool output (exec, cron, test, build, lint, DB query) | "I believe it worked" |
| File diff or git commit SHA | "The script ran" without checking exit code/output |
| Screenshot / canvas snapshot | "It should be fine" |
| PG state query showing expected row/status | Specialist self-report without Yoda independent verify |
| Service health endpoint / status code | "I would have fixed that" |

**Verify phase discipline:**
- For every atom, the Verify agent must inspect the **actual artifact or state** — not read the executor's summary.
- If an atom claims a file was written → verify the file exists with expected content (hash, structure, or test).
- If an atom claims a DB was updated → query the DB and compare to expected.
- If an atom claims a service is healthy → run the health check, read the status endpoint, or inspect logs.
- If an atom claims tests pass → run the tests and read the pass/fail output.

**Done gate enforcement:** `scripts/crest-done-gate.sh` checks for evidence artifacts before allowing `status: closed`. Missing evidence → gate returns exit 1 and ticket stays open.

**Anti-regression:** Subagent-written tests are suspect — the verifier_corpus must come from Yoda/Atlas/Thrawn, not the executing subagent. See Anti-Subagent-Trap (L-139).

---

## Done Gate — RULES.md §DoD VERIFICATION GATE

**NO ticket may be closed without passing the DoD Verification Gate.**

- Ticket close: `bash scripts/db-ticket.sh update <ID> '{"status":"closed"}'`
- Gate enforced by `scripts/crest-done-gate.sh` pre-close hook
- Override: Ken only, via `--skip-verify` flag (every override MUST be logged to CHANGELOG.md)
- Reference: `docs/DoD-Validation-Rules.md`

This is the machine-enforced CREST Done gate for ticket lifecycle.

---

## Related Skills & Scripts

- **Model routing / phase tier assignments:** `agent-skills/model-routing/SKILL.md`
- **Sprint/ticket workflow (CREST Plan input):** `agent-skills/pg-sprint-backlog/SKILL.md`
- **CHG records (for any CREST-driven config change):** `agent-skills/changelog/SKILL.md`
- **Scripts:** `scripts/atom-validate.sh` (Level 2 pre-flight), `scripts/dispatch-validate.sh` (Level 1), `scripts/crest-done-gate.sh` (close hook), `scripts/crest-execute-gate.sh` (dispatch discipline audit)

---

## References

Full recursive CREST topology (Model C, v1.3 LOCKED, CHG-0680):

→ `docs/CREST-v1.3-Recursive-Model-C.md`

Authority boundary rules (Ken's 2026-06-13 mandate + MEMORY.md enforcement rules + RULES.md DoD gate):

→ `references/CREST-boundary-reference.md`

---

## Canonical TKT-0761 Pattern — CREST v1.3 External-Loop Discipline

This section defines the **canonical external-loop pattern** for CREST v1.3, codified from TKT-0761. It applies when a CREST loop involves **external-facing work** (client deliverables, public communications, third-party integrations) or any work where **Sage-as-Judge Verify** is the primary verification mechanism.

### 10-Step Canonical Loop

```
Plan → Execute → Yoda Spot-Check → Sage Verify → Replan (if defect) → re-Verify → Synthesize → Done Gate → Audit → Close
```

| # | Step | Owner | Description |
|---|------|-------|-------------|
| 1 | **Plan** | Yoda (pro) | Scope, DAG, atoms, model spec, trade-offs. Typed DAG + atom breakdown. |
| 2 | **Execute** | Specialist (role×phase) | Mechanical work — write, build, dispatch. RVEV per atom. |
| 3 | **Yoda Spot-Check** | Yoda (pro) | Pre-Verify sanity gate: Yoda inspects output for obvious defects before Sage spends tokens. See checklist below. |
| 4 | **Sage Verify** | Sage (gemma4:31b-cloud) | Sage-as-Judge renders binary verdict (pass/fail/needs_human). See verdict checklist below. |
| 5 | **Replan (if defect)** | Yoda (pro) | Gap analysis on Sage's findings. Iterate(n++) OR escalate. See trigger conditions below. |
| 6 | **re-Verify** | Sage (gemma4:31b-cloud) | Re-run Sage Verify on the revised output. Same verdict checklist. |
| 7 | **Synthesize** | Yoda (flash) | Integrate verified output into deliverable. Assemble evidence. See checklist below. |
| 8 | **Done Gate** | Yoda (terminal) | Governance agents (Shield → Lex → Sage) for external-facing outputs. `scripts/crest-done-gate.sh` enforces evidence artifacts. |
| 9 | **Audit** | Yoda (terminal) | Emit audit trail: atom results, Sage verdicts, iteration count, evidence artifacts. Register in Holocron. |
| 10 | **Close** | Yoda (terminal) | `bash scripts/db-ticket.sh update <ID> '{"status":"closed"}'`. DoD Verification Gate enforced. |

**Key discipline:** Step 3 (Yoda Spot-Check) is **mandatory** — never skip to Sage Verify without Yoda's pre-check. Sage tokens are expensive; Yoda catches obvious defects cheaply.

---

### Yoda Spot-Check Checklist (mandatory before Sage Verify)

Yoda MUST run this checklist on every specialist output before routing to Sage:

1. **Structural completeness** — Does the output have all required sections/fields? No obvious truncation or placeholders?
2. **Format compliance** — Does the output match the expected format (JSON schema, markdown structure, file layout)?
3. **Internal consistency** — No contradictory statements, no undefined references, no dangling cross-references?
4. **Scope fidelity** — Does the output stay within the atom's declared scope? No scope creep or missing scope?
5. **Obvious errors** — Typos in identifiers, broken links, malformed syntax, missing closing tags?
6. **Pre-condition satisfaction** — Were all pre-conditions met before execution? (Check evidence, not assertion.)
7. **Post-condition verification** — Do the post-conditions declared in the atom hold? (Quick structural check, not deep.)
8. **Evidence presence** — Does the executor's RVEV trace include actual evidence (tool output, file diffs, DB queries)? Not just "it worked".
9. **No secrets leak** — No hardcoded credentials, API keys, or internal paths in the output?
10. **Replan-readiness** — If this fails Sage, is the output structured enough to diagnose the failure?

**Pass threshold:** All 10 checks pass → route to Sage Verify. Any FAIL → return to Execute with specific findings. Do NOT pass known defects to Sage.

---

### Sage-as-Judge Verdict Checklist

Sage renders a binary verdict on each atom using this checklist:

1. **Correctness** — Does the output correctly implement the atom's requirements? (Primary criterion.)
2. **Completeness** — Are all required elements present? No missing edge cases, error handling, or configuration?
3. **Consistency** — Is the output internally consistent and consistent with related atoms/sub-tickets?
4. **Quality** — Does the output meet the expected quality bar for its domain (code hygiene, prose clarity, data accuracy)?
5. **Security** — Any security concerns? (Secrets, injection, access control, data exposure.)
6. **Performance** — Any obvious performance issues? (For code: algorithmic efficiency, resource usage. For config: scaling implications.)
7. **Maintainability** — Is the output maintainable? (For code: comments, structure, testability. For docs: clarity, updateability.)
8. **Evidence traceability** — Can every claim in the output be traced to evidence in the RVEV trace?

**Verdict values:**
- **PASS** — All checks pass. Output is ready for Synthesize.
- **FAIL** — One or more checks fail with specific findings. Output returns to Replan with Sage's findings attached.
- **NEEDS_HUMAN** — Sage cannot determine pass/fail (ambiguous requirements, subjective quality call, security grey area). Escalates to Yoda with Sage's analysis. 4-hour timeout; auto-escalates to Ken if unresolved.

**Sage output format:**
```json
{
  "atom_id": "<id>",
  "verdict": "PASS|FAIL|NEEDS_HUMAN",
  "findings": [
    {
      "check": "<check_name>",
      "status": "PASS|FAIL|SKIP",
      "detail": "<specific finding>"
    }
  ],
  "summary": "<one-line verdict summary>",
  "evidence_referenced": ["<evidence artifact paths>"]
}
```

---

### Replan Trigger Conditions

Replan is triggered when Sage returns **FAIL** or **NEEDS_HUMAN**. The response depends on the failure type:

| Condition | Action | Escalate? |
|-----------|--------|-----------|
| **Atom-level defect** (incorrect implementation, missing element) | Iterate(n++): return to Execute with Sage's findings | No — atom-fixable |
| **Scope gap** (atom requirements were insufficient) | Iterate with updated atom spec from Yoda | No — Yoda adjusts scope |
| **Cross-atom inconsistency** (two atoms contradict) | Yoda replans the DAG; may re-sequence or merge atoms | No — Yoda-level fix |
| **Cross-specialist dependency** (output depends on another specialist's unfinished work) | Escalate to Yoda for sequencing | Yes — escalate to Yoda |
| **Assumption change** (Plan assumption invalidated by execution) | Escalate to Yoda for master DAG replan | Yes — escalate to Yoda |
| **External block** (third-party API down, dependency unavailable) | Escalate to Yoda; Yoda decides wait/descope/workaround | Yes — escalate to Yoda |
| **Sage uncertainty** (NEEDS_HUMAN verdict) | Escalate to Yoda with Sage's analysis | Yes — escalate to Yoda |
| **Iteration limit exceeded** (n > 3 iterations on same atom) | Escalate to Yoda; Yoda may escalate to Ken | Yes — escalate to Yoda → Ken |

**Rule:** Specialists iterate atom-level defects without escalation. Any non-atom-level gap escalates immediately. No silent workarounds.

---

### Synthesize Evidence Assembly Checklist

Before Synthesize, Yoda assembles and validates all evidence artifacts:

1. **Atom completion log** — Every atom in the DAG has a status (PASS/FAIL/ESCALATED) and iteration count.
2. **Sage verdicts** — All Sage verdict JSON objects collected, one per atom per iteration.
3. **RVEV traces** — Executor's RVEV output for each atom (tool output, file diffs, DB queries, test results).
4. **Yoda Spot-Check results** — Yoda's pre-check findings for each atom (pass/fail per checklist item).
5. **Replan history** — For any atom that hit Replan: the Sage findings that triggered it, the iteration count, and the fix applied.
6. **Escalation records** — Any escalations with full handshake JSON.
7. **Governance verdicts** — Shield/Lex/Sage verdicts from the Done Gate (if external-facing).
8. **Integration test results** — Cross-atom consistency check: named-entity cross-reference, assumption alignment, gap detection.
9. **Deliverable artifact** — The final integrated output (file path or content reference).
10. **Audit trail** — Timestamps, agent IDs, model assignments, CHG references for any config changes.

**Evidence validation rule:** Every evidence artifact must be inspectable — file exists with expected content, DB query returns expected rows, test output shows pass/fail. Assertion without artifact is not evidence (L-054).

**Synthesize output shape:**
```json
{
  "ticket_id": "<TKT-ID>",
  "deliverable": "<path or reference>",
  "evidence_artifacts": ["<path1>", "<path2>", "..."],
  "atom_summary": {
    "total": 5,
    "passed": 4,
    "failed": 0,
    "escalated": 1,
    "total_iterations": 6
  },
  "sage_verdicts": ["<verdict JSON objects>"],
  "governance_verdicts": ["<Shield/Lex/Sage verdicts if applicable>"],
  "audit_trail": {
    "started_at": "<ISO 8601>",
    "completed_at": "<ISO 8601>",
    "agents_involved": ["<agent IDs>"],
    "chg_references": ["<CHG IDs>"]
  }
}
```
