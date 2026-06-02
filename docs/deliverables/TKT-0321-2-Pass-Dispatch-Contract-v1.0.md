# TKT-0321: 2-Pass Dispatch Contract v1.0

**Document Type:** Platform Architecture Contract
**Authority:** Ken Mun (Platform Architect)
**Ratified:** 2025-05-27
**Effective:** Platform-wide, immediate
**Depends On:** TKT-0322 (Execution Model Matrix), TKT-0323 (dispatch-validate.sh)
**Status:** ACTIVE

---

## 1. The Rule

> **"No executor receives undiscovered work."**

This is the single non-negotiable rule governing ALL agent-to-agent dispatches on the OpenClaw platform. It applies universally:

| Dispatch Type | Source | Target | Governed |
|---|---|---|---|
| Orchestrator → Specialist | Yoda | Forge/Spark/any specialist | ✅ |
| Assistant → Execution | Aria | Spark | ✅ |
| Self-dispatch | Forge | Forge | ✅ |
| Cron → Agent | Cron scheduler | Any agent | ✅ |
| Agent spawn | Any agent | Subagent | ✅ |
| Heartbeat trigger | Gateway | Any agent | ✅ (except single-tool) |
| Pipeline step | Any agent | Next agent in chain | ✅ |

**The corollary:** Every unit of work MUST be discovered, decomposed, and packaged BEFORE it crosses an agent boundary. The receiving agent executes pre-discovered atoms only — never performs discovery work.

---

## 2. The 2-Pass Pattern

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    2-PASS DISPATCH FLOW                      │
│                                                              │
│  PASS 1: DISCOVERY (Orchestrator)                            │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────────┐   │
│  │ TASK IN  │───▶│ ANALYZE  │───▶│ STRUCTURED BREAKDOWN │   │
│  └──────────┘    └──────────┘    │ • Atoms              │   │
│                                  │ • Dependencies       │   │
│                                  │ • Risks & unknowns   │   │
│                                  │ • Model assignment   │   │
│                                  └──────────┬───────────┘   │
│                                             │                │
│  PASS 2: EXECUTION (Specialist)              ▼                │
│  ┌──────────────────────┐    ┌──────────────────────────┐   │
│  │ EXECUTION RESULT ◀───│◀───│ PRE-DISCOVERED ATOMS      │   │
│  └──────────────────────┘    │ • READ → VALIDATE        │   │
│                              │ • EXECUTE → VERIFY       │   │
│                              └──────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Pass 1: Discovery (Orchestrator)

**Purpose:** Transform an ambiguous task into a structured, executable breakdown.

**Who runs it:** The orchestrating agent (Yoda, Aria, Cron, or any agent initiating dispatch).

**Model:** `deepseek-pro` or `claude-sonnet` (high reasoning capacity — per TKT-0322 matrix).

**Required outputs:**
1. **Atom List** — Discrete, independent units of work. Each atom is:
   - Self-contained (one verb: "read X", "validate Y", "write Z")
   - Idempotent where possible
   - Tagged with required tools
2. **Dependency Graph** — Which atoms depend on which. Cyclic dependencies are errors.
3. **Unknowns Catalog** — Explicit listing of what is NOT yet known. No "maybe" or "probably."
4. **Model Assignment** — Per-atom model selection from the TKT-0322 matrix.
5. **Validation Hooks** — Pre-flight checks for each atom (file exists? API reachable? etc.)

**Hard constraints:**
- Discovery MUST complete before dispatch. No streaming execution.
- The breakdown MUST survive TKT-0323's `dispatch-validate.sh` gate.
- Ambiguous atoms are rejected. Every atom must compile to a concrete tool call.

### Pass 2: Execution (Specialist)

**Purpose:** Execute pre-discovered atoms. Nothing more, nothing less.

**Who runs it:** The specialist agent receiving the dispatch.

**Model:** Per TKT-0322 execution model matrix (varies by workload: Forge uses gemma4:31b for tooling, Spark uses deepseek-pro, etc.).

**What the specialist receives:**
```json
{
  "dispatchId": "dsp-abc123",
  "pass1Hash": "sha256:...",
  "atoms": [
    {
      "id": "atom-01",
      "verb": "READ",
      "target": "src/config.yaml",
      "purpose": "Extract current Redis config",
      "model": "gemma4:31b-cloud",
      "dependsOn": [],
      "validation": { "fileExists": "src/config.yaml" }
    },
    {
      "id": "atom-02",
      "verb": "WRITE",
      "target": "src/config.yaml",
      "purpose": "Update Redis timeout to 30s",
      "model": "gemma4:31b-cloud",
      "dependsOn": ["atom-01"],
      "validation": { "backupExists": "src/config.yaml.bak" }
    }
  ],
  "context": { "maxTokens": 8000, "domain": "platform-config" }
}
```

**What the specialist MUST NOT do:**
- ❌ Figure out what needs to be done (that's Pass 1 work)
- ❌ Decide which tools to use (pre-specified in atoms)
- ❌ Search for dependencies or files (pre-located)
- ❌ Interpret ambiguous instructions (atoms are concrete)
- ❌ Perform discovery work of any kind

**What the specialist MUST do:**
- ✅ READ each atom's target
- ✅ VALIDATE pre-conditions (per atom's validation hooks)
- ✅ EXECUTE the verb on the target
- ✅ VERIFY post-conditions
- ✅ Report results with per-atom status

---

## 3. The RVEV Cycle

Codified as a non-negotiable, platform-wide rule. Every dispatch MUST follow this cycle. No exceptions.

### The Four Phases

```
     ┌──────────────────────────────────────────┐
     │              RVEV CYCLE                   │
     │                                           │
     │  ┌────────┐                               │
     │  │  READ  │  Read the atom, its target,   │
     │  └───┬────┘  its dependencies, its context │
     │      │                                     │
     │      ▼                                     │
     │  ┌──────────┐                             │
     │  │ VALIDATE │  Run validation hooks,       │
     │  └────┬─────┘  check pre-conditions         │
     │       │                                    │
     │       ▼                                    │
     │  ┌──────────┐                             │
     │  │ EXECUTE  │  Perform the atom's verb     │
     │  └────┬─────┘  on its target               │
     │       │                                    │
     │       ▼                                    │
     │  ┌──────────┐                             │
     │  │ VERIFY   │  Confirm post-conditions,    │
     │  └──────────┘  report atom-level status    │
     │                                           │
     └──────────────────────────────────────────┘
```

### RVEV Specification

| Phase | Required Action | Success Criterion | Failure Behavior |
|---|---|---|---|
| **READ** | Load atom definition, target content, dependency outputs | Target accessible and readable; deps resolved | Abort atom, flag deps |
| **VALIDATE** | Execute validation hooks from atom definition | All hooks return true | Abort atom, report hook failure |
| **EXECUTE** | Perform atom.verb on atom.target with atom.context | Verb completes without error | Abort atom, capture error |
| **VERIFY** | Confirm atom.purpose was achieved; check post-conditions | Post-conditions met | Flag atom for retry, escalate |

### RVEV Rules

1. **Sequential within an atom.** READ must complete before VALIDATE before EXECUTE before VERIFY. No parallel phases within a single atom.
2. **Independent atoms can RVEV in parallel.** Dependency graph determines ordering.
3. **Any phase failure = atom failure.** No partial execution. State must be revertible.
4. **RVEV is per-atom, not per-dispatch.** Each atom gets its own cycle trace.
5. **RVEV traces are logged.** `dispatch-validate.sh` (TKT-0323) verifies trace completeness.

### RVEV Trace Format

```json
{
  "atomId": "atom-01",
  "dispatchId": "dsp-abc123",
  "rvEv": {
    "read": { "status": "OK", "target": "src/config.yaml", "bytes": 2048, "tookMs": 120 },
    "validate": { "status": "OK", "hooks": ["fileExists"], "tookMs": 15 },
    "execute": { "status": "OK", "verb": "READ", "tookMs": 340 },
    "verify": { "status": "OK", "bytesRead": 2048, "tookMs": 10 }
  },
  "overall": "OK"
}
```

---

## 4. Contract Scope

### Who MUST Follow

All **14 platform agents** are bound by this contract:

| # | Agent | Role | Dispatch Role |
|---|---|---|---|
| 1 | Yoda | Platform Orchestrator | Pass 1 initiator |
| 2 | Aria | Executive Assistant | Pass 1 initiator |
| 3 | Forge | Code & Tooling | Pass 2 executor (self-dispatch OK) |
| 4 | Spark | Analysis & Research | Pass 2 executor |
| 5 | Sage | Knowledge Synthesis | Pass 2 executor |
| 6 | Echo | Communication | Pass 2 executor |
| 7 | Scout | Data Gathering | Pass 2 executor |
| 8 | Warden | Security & Audit | Pass 2 executor |
| 9 | Nexus | Integration Hub | Pass 1 + Pass 2 executor |
| 10 | Prism | UI & Presentation | Pass 2 executor |
| 11 | Atlas | Infrastructure | Pass 2 executor |
| 12 | Quill | Documentation | Pass 2 executor |
| 13 | Pulse | Monitoring & Alerts | Pass 2 executor |
| 14 | Cron | Scheduled Tasks | Pass 1 initiator |

### Exceptions (Explicitly Permitted)

The following dispatch types are exempt from the 2-pass contract:

1. **systemEvent payloads** — Pre-validated, platform-generated events (e.g., node connect/disconnect, gateway restart). These carry immutable payloads with no discovery needed.
2. **Single-tool fire-and-forget heartbeats** — Heartbeat polls that execute exactly one tool call with zero interpretation (e.g., `HEARTBEAT_OK` with no processing). Any heartbeat that performs multi-step work falls under the contract.
3. **Explicit human-in-the-loop overrides** — When a human directly instructs an agent to perform a specific, fully-specified task with no interpretation required. The instruction must be concrete enough to constitute a self-contained atom.

### Enforcement

**Gate:** `dispatch-validate.sh` (TKT-0323) will validate ALL dispatches at the boundary before any executor receives work.

**Validation checks:**
- [ ] Dispatch payload contains `pass1Hash` (proof of discovery pass)
- [ ] Every atom passes `dispatch-validate.sh` schema validation
- [ ] No atom requires discovery (ambiguous verbs, unknown targets)
- [ ] Dependency graph is acyclic
- [ ] RVEV trace format is valid
- [ ] Model assignment is present and matches TKT-0322 matrix

**Violations:**
- **First violation:** Dispatch rejected. Incident logged to `logs/dispatch-violations/`. Alert sent to platform-health channel.
- **Second violation (same agent, 24h):** Agent's dispatch capability suspended for 1 hour. Ken notified.
- **Third violation (same agent, 7d):** Agent's dispatch capability suspended until manual review by Ken. Agent flagged in platform-health dashboard.
- **Systemic pattern (>5 violations across agents in 24h):** Platform-wide dispatch freeze. All dispatches require manual approval.

---

## 5. Example Flows

### 5.1 Yoda → Forge Dispatch

**BEFORE (Anti-pattern — CURRENT state without contract):**

```
Yoda: "Forge, optimize the Redis connection pool for the gateway."
Forge: [Receives ambiguous task]
       [Must figure out: where's the config? what's the current pool size?
        what's the load pattern? should I use connection pooling or pipelining?]
       [Spends 40% of context on DISCOVERY before executing]
       [Context used: ~22,000 tokens total]
```

**AFTER (2-Pass Contract):**

```
PASS 1 — Yoda (deepseek-pro):
  ┌─ Analyzes task
  ├─ Atom-01: READ gateway/config/redis.yaml → current pool config
  ├─ Atom-02: READ gateway/metrics/connections.log → last 24h load
  ├─ Atom-03: ANALYZE atoms 01+02 → determine optimal pool size
  ├─ Atom-04: WRITE gateway/config/redis.yaml → updated pool config
  ├─ Atom-05: VALIDATE gateway/config/redis.yaml → config schema check
  ├─ Deps: 03→{01,02}, 04→03, 05→04
  └─ Model: Atom 01-02,05 = gemma4:31b; Atom 03 = deepseek-pro

PASS 2 — Forge (atom-by-atom):
  RVEV atom-01: READ → VALIDATE → EXECUTE → VERIFY ✅
  RVEV atom-02: READ → VALIDATE → EXECUTE → VERIFY ✅
  RVEV atom-03: READ → VALIDATE → EXECUTE → VERIFY ✅
  RVEV atom-04: READ → VALIDATE → EXECUTE → VERIFY ✅
  RVEV atom-05: READ → VALIDATE → EXECUTE → VERIFY ✅
  [Context used per atom: ~3,000 tokens × 5 = ~15,000 tokens total]
  [Context reduction: ~32% from 22K → 15K]
  [Discovery overhead: ZERO in Forge's context]
```

### 5.2 Aria → Spark Dispatch

**BEFORE:**

```
Aria: "Spark, research the best Rust async runtime for our gateway
       rewrite and give me a recommendation."
Spark: [Must figure out: what are the criteria? latency? throughput?
        ecosystem? team familiarity? what's the gateway's current bottleneck?]
       [Performs BOTH discovery (figuring out what matters) AND
        execution (researching runtimes)]
       [Context: ~18,000 tokens, ~50% on discovery]
```

**AFTER:**

```
PASS 1 — Aria (claude-sonnet):
  ┌─ Analyzes research question
  ├─ Atom-01: READ gateway/docs/ARCHITECTURE.md → current constraints
  ├─ Atom-02: READ gateway/metrics/latency-p95-7d.json → performance reqs
  ├─ Atom-03: WEB_SEARCH "tokio vs monoio vs glommio 2025 benchmark" → perf data
  ├─ Atom-04: WEB_SEARCH "rust async runtime ecosystem mature 2025" → ecosystem
  ├─ Atom-05: SYNTHESIZE 01-04 → scored recommendation matrix
  ├─ Deps: 05→{01,02,03,04}
  └─ Model: 01-02 = gemma4:31b; 03-04 = deepseek-pro; 05 = claude-sonnet

PASS 2 — Spark (deepseek-pro for synthesis):
  RVEV atom-01 through atom-05
  [Spark receives fully-scoped research brief with pre-identified criteria]
  [Zero discovery work in Spark's context]
  [Context: ~10,000 tokens → 44% reduction from 18K]
```

### 5.3 Cron → Agent Dispatch

**BEFORE:**

```
Cron: "Every Monday 9AM, run the weekly report generation."
Agent: [Wakes up, must figure out: what report? what data sources?
        what format? who receives it?]
       [Discovery work happens EVERY Monday at 9AM, burning context weekly]
```

**AFTER:**

```
PASS 1 — Cron (deepseek-pro, one-time discovery):
  ┌─ Analyzes weekly report requirements
  ├─ Atom-01: READ db/weekly-metrics.sql → query template
  ├─ Atom-02: EXECUTE_SQL atom-01 → raw data
  ├─ Atom-03: TRANSFORM atom-02 → formatted report
  ├─ Atom-04: SEND_EMAIL atom-03 → ken+team@platform.local
  ├─ Deps: 02→01, 03→02, 04→03
  └─ Cached dispatchId: "cron-weekly-report-v1"

PASS 2 — Agent (gemma4:31b, every Monday):
  RVEV atom-01 through atom-04 using cached dispatch
  [Zero discovery — atoms are pre-computed, only re-executed]
  [Context: fixed at ~8,000 tokens every run]
  [Atom updates: modify Pass 1 breakdown, not the cron trigger]
```

---

## 6. Agent RULES.md Update Specification

Every agent's `RULES.md` MUST include the following clause verbatim. It replaces any existing dispatch instructions.

### Mandatory RULES.md Addition

````markdown
## 2-Pass Dispatch Contract (TKT-0321)

You are bound by the platform 2-pass dispatch contract.

### When Dispatching Work (Pass 1)

1. **You MUST complete discovery before dispatch.** Analyze the task. Break it into concrete atoms. Each atom must compile to a specific tool call with a specific target.
2. **Your breakdown MUST pass `dispatch-validate.sh` (TKT-0323).** Ambiguous atoms (unclear verbs, unknown targets, "figure out" steps) will be rejected.
3. **Produce:** atom list, dependency graph, unknowns catalog, model assignment per TKT-0322 matrix.
4. **Dispatch with `dispatchId`** and full RVEV-ready payload.

### When Receiving Work (Pass 2)

1. **You MUST NOT perform discovery.** If you receive an ambiguous task, reject it. Demand a proper Pass 1 breakdown.
2. **Follow the RVEV cycle per atom:** READ → VALIDATE → EXECUTE → VERIFY.
3. **Report per-atom RVEV traces.** Each atom gets its own status.
4. **If validation fails, abort that atom.** Do not guess. Do not "figure it out."

### Violations

Violations are logged, alerted, and escalate per TKT-0321 Section 4 enforcement policy. Repeated violations result in dispatch capability suspension.

### Exceptions

- systemEvent payloads (pre-validated)
- Single-tool fire-and-forget heartbeats
- Explicit human-in-the-loop instructions that constitute self-contained atoms
````

### Per-Agent Customization

Each agent adds one line below the contract clause specifying their dispatch role:

| Agent | Addition |
|---|---|
| Yoda | `Your role: Pass 1 initiator. You rarely execute atoms directly.` |
| Aria | `Your role: Pass 1 initiator for research, scheduling, and communication dispatches.` |
| Forge | `Your role: Pass 2 executor. Self-dispatch allowed but must follow 2-pass internally.` |
| Spark | `Your role: Pass 2 executor for analysis and research atoms.` |
| Sage | `Your role: Pass 2 executor for knowledge synthesis atoms.` |
| Echo | `Your role: Pass 2 executor for communication atoms.` |
| Scout | `Your role: Pass 2 executor for data gathering atoms.` |
| Warden | `Your role: Pass 2 executor for security and audit atoms.` |
| Nexus | `Your role: Pass 1 initiator and Pass 2 executor (hybrid).` |
| Prism | `Your role: Pass 2 executor for UI and presentation atoms.` |
| Atlas | `Your role: Pass 2 executor for infrastructure atoms.` |
| Quill | `Your role: Pass 2 executor for documentation atoms.` |
| Pulse | `Your role: Pass 2 executor for monitoring and alert atoms.` |
| Cron | `Your role: Pass 1 initiator. Dispatch with cached, reusable breakdowns.` |

---

## 7. AGENTS.md Integration Points

The platform `AGENTS.md` requires updates in the following sections. Exact replacement text provided.

### 7.1 New Section: "Dispatch Rules" (Insert after "Red Lines")

````markdown
## Dispatch Rules

### The 2-Pass Contract (TKT-0321)

**"No executor receives undiscovered work."**

All agent-to-agent dispatches follow a 2-pass pattern:

1. **Pass 1 (Discovery):** The orchestrator analyzes the task, breaks it into concrete atoms, maps dependencies, assigns models. No execution.
2. **Pass 2 (Execution):** The specialist receives pre-discovered atoms and executes them via RVEV (Read → Validate → Execute → Verify). No discovery.

**If you are an orchestrator dispatching work:** Complete Pass 1 fully before dispatching. Ambiguous atoms will be rejected by `dispatch-validate.sh`.

**If you are an executor receiving work:** If the dispatch is ambiguous or requires discovery, REJECT IT. Demand a proper Pass 1 breakdown.

### RVEV Cycle

Every atom execution follows: **READ → VALIDATE → EXECUTE → VERIFY**

- READ: Load the atom and its target
- VALIDATE: Check pre-conditions
- EXECUTE: Perform the verb
- VERIFY: Confirm post-conditions

Report per-atom RVEV traces. Partial execution is not permitted.
````

### 7.2 Update: "External vs Internal" → Add dispatch boundary note

Replace the "External vs Internal" section with:

````markdown
## External vs Internal

**Safe to do freely:**
- Read files, explore, organize, learn
- Search the web, check calendars
- Work within this workspace
- Execute pre-discovered atoms per RVEV cycle

**Ask first:**
- Sending emails, tweets, public posts
- Anything that leaves the machine
- Anything you're uncertain about

**Dispatch boundaries:**
- When dispatching to another agent, complete discovery (Pass 1) first
- When receiving a dispatch, execute only (Pass 2) — no discovery
- Cross-agent dispatches MUST pass `dispatch-validate.sh` (TKT-0323)
````

### 7.3 Update: "Group Chats" → Add multi-agent dispatch note

Insert after the "Don't overdo it" line:

````markdown
**Multi-agent dispatch in groups:** When another agent is mentioned and needs to take action, the 2-pass contract applies. Either the requesting agent provides a Pass 1 breakdown, or the responding agent (as orchestrator) performs Pass 1 before executing. No agent should interpret ambiguous requests from other agents.
````

---

## 8. Success Metrics

### Primary Metrics

| Metric | Current (Pre-Contract) | Target | Measurement |
|---|---|---|---|
| Dispatch validation rate | 0% (no validation) | **100%** | `dispatch-validate.sh` pass rate |
| Undiscovered work reaching executors | ~85% of dispatches | **0** | Audit of executor context logs |
| Yoda context per dispatch | ~22,000 tokens avg | **9,900–12,100 tokens** (55-64% reduction) | Context window snapshots |
| Specialist dispatch efficiency | Baseline 1x | **3x** (atoms/hour vs pre-contract) | Per-atom timing logs |

### Secondary Metrics

| Metric | Target | Measurement |
|---|---|---|
| Ambiguous dispatches rejected | >95% rejection rate | `dispatch-validate.sh` rejection logs |
| Repeat violators | 0 within 30 days of rollout | Violation log aggregation |
| RVEV trace completeness | 100% of executed atoms | Trace log parsing |
| Dispatch contract compliance (automated) | 100% within 14 days | Compliance scanner (TKT-0323 periodic check) |

### Rollout Phases

| Phase | Timeline | Scope | Success Gate |
|---|---|---|---|
| Phase 1: Yoda + Forge + Spark | Week 1 | Core orchestration agents | 3 agents compliant, <5 violations/day |
| Phase 2: All initiators | Week 2 | Aria, Cron, Nexus | 0 Pass 1 failures across initiators |
| Phase 3: All executors | Week 3 | All 14 agents | 0 Pass 2 discovery attempts detected |
| Phase 4: Automated enforcement | Week 4 | `dispatch-validate.sh` as hard gate | Gateway-level enforcement active |

---

## Appendix A: Atom Schema Reference

```json
{
  "$schema": "https://platform.local/schemas/dispatch-atom-v1.json",
  "atomId": "string (required, unique within dispatch)",
  "verb": "READ | WRITE | EXECUTE | ANALYZE | SYNTHESIZE | TRANSFORM | SEND | VALIDATE | WEB_SEARCH | WEB_FETCH",
  "target": "string (required, concrete path/URL/identifier)",
  "purpose": "string (required, one-sentence description of what this atom achieves)",
  "model": "string (required, per TKT-0322 matrix)",
  "dependsOn": ["atomId (optional, references other atoms in same dispatch)"],
  "validation": {
    "preConditions": ["string (hook name)"],
    "postConditions": ["string (hook name)"]
  },
  "context": {
    "maxTokens": "number (optional)",
    "domain": "string (optional)"
  },
  "retry": {
    "maxAttempts": "number (default: 1)",
    "backoffMs": "number (default: 0)"
  }
}
```

## Appendix B: dispatch-validate.sh Interface (TKT-0323)

```
dispatch-validate.sh --dispatch <payload.json> [--strict] [--trace]

Exit codes:
  0 — All atoms valid, dispatch approved
  1 — Schema validation failed (malformed payload)
  2 — Discovery requirement detected (ambiguous atom)
  3 — Dependency cycle found
  4 — Model assignment missing or invalid
  5 — Unknown verb or target pattern
```

## Appendix C: Violation Log Format

```json
{
  "violationId": "viol-abc123",
  "timestamp": "ISO8601",
  "violatingAgent": "agent-name",
  "dispatchId": "dsp-xyz789",
  "violationType": "UNDISCOVERED_WORK | AMBIGUOUS_ATOM | SKIPPED_PASS1 | NO_RVEV_TRACE",
  "severity": "WARN | BLOCK | SUSPEND",
  "details": "Human-readable description",
  "resolution": "REJECTED | RETRY_WITH_PASS1 | MANUAL_REVIEW"
}
```

---

**Document Version:** 1.0
**Last Updated:** 2025-06-02
**Next Review:** 2025-07-02 (30-day compliance audit)
**Related Tickets:** TKT-0322 (Execution Model Matrix), TKT-0323 (dispatch-validate.sh), TKT-0324 (RVEV Trace Logger)
