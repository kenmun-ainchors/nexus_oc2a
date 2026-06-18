---
name: crest
description: CREST — Cognitive Routing & Execution Sandwich Topology (recursive Model C, v1.2). 6-phase sandwich, Master/Sub-CREST topology, model matrix, 2-Pass Contract, escalation protocol, governance placement.
---

# CREST skill — When to Load

Load this skill whenever you are:

- **Starting or executing any task** that involves planning + execution work — CREST is mandatory for every such loop (Ken mandate 2026-06-13).
- **Dispatching a sub-ticket** to a specialist (Atlas, Thrawn, Spark, Lando, Mon Mothma, Forge) — apply the Master/Sub-CREST topology.
- **Choosing a model tier** for a specialist (Plan/Verify/Replan vs Execute/Synthesize) — consult the model matrix.
- **Handling a Verify failure** — apply the Replan decision tree (iterate(n++) OR escalate).
- **Integrating sub-ticket deliverables across specialists** — Master Synthesize integration checklist.
- **Deciding whether to invoke governance agents** (Shield/Lex/Sage) — Master Synthesize Done gate only, external-facing only.
- **Closing a ticket** — DoD Verification Gate (RULES.md §DoD VERIFICATION GATE).
- **Self-checking** whether CREST was used (Ken asks "did you use CREST?" = violation → LESSONS.md).

> **Self-check rule (MEMORY.md §CREST Enforcement):** If Ken asks "did you use CREST?" that is itself a violation — log to LESSONS.md.

---

## Quick Reference — The 6-Phase Sandwich

CREST applies **recursively** (Model C, v1.2 LOCKED, dual PASS) at two levels:

```
Plan → Execute → Verify → Replan → Synthesize → Done
```

| # | Phase | Model tier | Cognitive work | Output |
|---|-------|------------|----------------|--------|
| 1 | **Plan** | pro (strong) | Scope, DAG, atoms, model spec, trade-offs | Typed DAG + atom breakdown |
| 2 | **Execute** | flash (cheap) | Mechanical work — write, build, dispatch | Atoms completed (RVEV per atom) |
| 3 | **Verify** | pro (strong) | Independent validation (L-054: never trust self-report) | Binary 0/1 verdict per atom |
| 4 | **Replan** | pro (strong) | Gap analysis; iterate(n++) OR escalate | Re-dispatch or escalate |
| 5 | **Synthesize** | flash (cheap) | Integration (specialist: domain-internal; master: cross-specialist) | Sub-ticket / master deliverable |
| 6 | **Done** | terminal | Audit emit, close, Holocron register | Closed ticket + audit trail |

**Tier rule:** Plan / Verify / Replan = strong (pro). Execute / Synthesize = cheap (flash). Exceptions documented below.

---

## Master CREST vs Sub-CREST Topology

CREST is **fractal**. The same 6-phase sandwich applies at every level of work decomposition:

```
Master ticket → sub-tickets → atoms
    │               │            │
    └── Master CREST └── Sub-CREST └── RVEV (READ → VALIDATE → EXECUTE → VERIFY)
```

| Level | Orchestrator | Inputs | Outputs |
|-------|--------------|--------|---------|
| **Master CREST** | Yoda (deepseek-pro) | Master ticket | Sub-ticket assignments, integration report, audit |
| **Sub-CREST** | Specialist (pro/flash mix per matrix) | Sub-ticket | Atom breakdown, sub-ticket deliverable |
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

## Model Assignment Matrix (CORRECTED per source docs/CREST-v1.2-Recursive-Model-C.md §4)

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

> Source: `docs/CREST-v1.2-Recursive-Model-C.md` §6 (LOCKED, dual PASS).

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

**Integration report shape** — see `references/CREST-v1.2-Recursive-Model-C.md` §7.3 for full JSON schema.

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

Full recursive CREST topology (Model C, v1.2 LOCKED, dual PASS — Atlas ✅ + Thrawn ✅):

→ `references/CREST-v1.2-Recursive-Model-C.md`

Authority boundary rules (Ken's 2026-06-13 mandate + MEMORY.md enforcement rules + RULES.md DoD gate):

→ `references/CREST-boundary-reference.md`
