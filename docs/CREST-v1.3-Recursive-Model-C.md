# CREST v1.3 — Recursive Model C
## Cognitive Routing & Execution Sandwich Topology

**Status:** DRAFT FOR REVIEW v2 (oracle-revised) — supersedes CREST v1.2 upon Ken approval + CHG.  
**Version:** 1.3.0  
**Date:** 2026-06-20  
**Authors:** Yoda (draft), based on CREST-ALIGN-v0.4 handoff. Oracle-reviewed by kimi-k2.6:cloud 2026-06-20 09:15 AEST.  
**Approvers:** Ken Mun (pending).  

---

## 1. Purpose and Scope

CREST v1.3 updates CREST v1.2 with three architectural moves:

1. **External loop ownership.** The CREST loop boundary moves outside the executing agent. Yoda owns the loop now; a future controller will own it post-cutover. Agents execute phases when dispatched; they do not self-drive loops.
2. **Sage-as-Judge.** The *verdict* of the Verify phase moves from the specialist's self-verify to Sage. The specialist's Verify phase becomes **evidence assembly only**; Sage renders pass/fail.
3. **Capability-based multi-model routing.** The pro/flash binary is replaced by a `role × data_class × phase` capability matrix routed by a resolver. The first slot is Verify → `glm-5.1:cloud` (judge) to offload deepseek-pro and introduce a decorrelated judge.

This document is the authoritative CREST reference once approved. It supersedes `docs/CREST-v1.2-Recursive-Model-C.md` and the current `agent-skills/crest/SKILL.md`.

---

## 2. Core Sandwich (unchanged shape)

```
Plan → Execute → Verify → Replan → Synthesize → Done
```

CREST remains fractal: Master CREST (Yoda) decomposes into sub-CRESTs (specialists), which decompose into atoms with RVEV (Read → Validate → Execute → Verify).

What changes in v1.3 is **who owns the loop, who renders Verify verdicts, and how models are selected**.

---

## 3. External Loop Ownership (F1)

### 3.1 Current state (v1.2)
Agents are expected to self-drive the six-phase sandwich. This creates drift: agents skip Verify, iterate endlessly, or self-approve.

### 3.2 Target state (v1.3)
The CREST loop is owned by an external orchestrator:

- **Now:** Yoda is the loop owner. Yoda decides when an agent moves from Plan → Execute → Verify → etc.
- **Post-cutover:** A controller (infra component) owns the loop, dispatching phase jobs to agents and reading phase outputs from a durable state store (`state_sub_crest`).
- **Agent contract:** Agents are stateless phase executors. When dispatched a phase, they receive:
  - parent ticket, sub-ticket, atom id
  - phase name (Plan/Execute/Verify/Replan/Synthesize)
  - context blob (previous phase outputs + relevant state)
  - expected output schema
  - timeout
  - model assignment

Agents return phase outputs. They do not decide what phase comes next.

### 3.3 v1.3 stepping stone
Because the controller does not yet exist, v1.3 implements external loop ownership in two layers:

1. **Procedural layer:** `agent-skills/crest/SKILL.md` and `scripts/dispatch-validate.sh` encode that Yoda (or the specialist's caller) decides phase transitions.
2. **State layer:** `state_sub_crest` table records phase ownership, status, and outputs. Yoda reads/writes this table. When the controller is built, it will read the same table and dispatch agents automatically.

### 3.4 Agent conditioning
Agents' prompts must be updated so that:
- They accept a phase as input.
- They do not emit phase-transition statements like "moving to Verify" or "now I will Synthesize".
- They return structured output matching the expected schema for that phase.

This conditioning is part of the Tier C work in the execution plan.

---

## 4. Sage-as-Judge (F2)

### 4.1 Problem
In v1.2, the specialist executing a sub-CREST also performs Verify. This is the root cause of WO-002: agents self-green their own work.

### 4.2 Target
A different agent renders the Verify verdict. That agent is **Sage**.

### 4.3 New separation of responsibilities

| Role | Verify duty | Model tier |
|---|---|---|
| Specialist | **Evidence assembly** — collect logs, outputs, diffs, PG state, test results | cheap / mechanical |
| Sage | **Verdict rendering** — read evidence and pass/fail the atom against pre/post conditions | strong / judge |

### 4.4 Sage dispatch contract
Sage receives:
- sub-ticket id, atom id
- atom Plan output (pre/post conditions, expected output schema)
- specialist Execute output
- specialist Verify evidence blob
- relevant baseline/config snapshot

Sage returns:
- verdict: `pass`, `fail`, or `needs_human`
- evidence summary
- confidence (high/medium/low)
- recommendation: `iterate`, `escalate`, or `close`

### 4.5 Failure modes
- **fail + fixable:** loop owner re-dispatches Execute with iteration counter incremented.
- **fail + not fixable:** escalate to Yoda.
- **needs_human:** pause and alert Ken/Yoda.

### 4.6 Governance placement
Sage is T4 reactive verdict-only, but v1.3 expands Sage's scope to **active Verify verdicts** within CREST. This is a role expansion, not a tier change. Sage remains verdict-only — it does not Plan, Execute, or Synthesize.

**Warden scope update:** Warden's 15-min cron now also monitors Sage verdict patterns (pass/fail ratio, `needs_human` rate, confidence distribution). If Sage verdicts show bias (e.g., >95% pass rate over 100 atoms), Warden alerts Yoda.

### 4.7 `needs_human` timeout
If Sage returns `needs_human`, the loop owner starts a 4-hour timeout. If Ken does not respond within 4 hours, the atom is auto-escalated to Yoda for disposition (defer, retry with different model, or park). This prevents infinite blocking on human unavailability.

---

## 5. Capability-Based Multi-Model Routing (§6)

### 5.1 Why
The pro/flash binary is too coarse. It forces deepseek-pro to do all strong work, creating cost concentration and a single point of failure. A capability matrix lets different models own different roles based on what they do best.

### 5.2 Base set (v1.3)
These are the models available and approved for v1.3 routing:

| Model | Size / quant | Best-fit role | Current status |
|---|---|---|---|
| `deepseek-v4-pro:cloud` | ~pro | General strong; Plan, Replan, complex Synthesize | Available, current default |
| `deepseek-v4-flash:cloud` | ~flash | Cheap execution, simple Synthesize | Available, current default |
| `gemma4:31b-cloud` | 31B | Governance strong; security/legal/QA verdicts | Available |
| `glm-5.1:cloud` | 397B BF16 | Judge / Verify; decorrelated from deepseek | Available, callable |
| `kimi-k2.6:cloud` | — | Business/creative strong | Available |
| `kimi-k2.7-code:cloud` | — | Code-heavy interactive | Available |
| `minimax-m3:cloud` | — | Forge Verify/Replan | Available |

**Not in v1.3 base set:** `gpt-oss:20b:cloud` and `qwen3.6:25B` are absent from OC1; deferred.

### 5.3 Data classes
A `data_class` tag is attached to each atom by the Plan phase:

- `code` — source code, scripts, config
- `policy` — governance, legal, security, compliance
- `creative` — LinkedIn, marketing, external-facing copy
- `data` — database schema, state manipulation
- `infra` — Docker, gateways, cron, networking
- `analysis` — architecture assessment, research, report synthesis

### 5.4 Capability matrix (v1.3)
This is a simplified starting matrix. It lives in `state_model_policy` and is versioned.

| role / phase | Plan | Execute | Verify | Replan | Synthesize |
|---|---|---|---|---|---|
| `yoda_master` | deepseek-pro | — | deepseek-pro | deepseek-pro | kimi-k2.7 |
| `design_backend` (Atlas/Thrawn/Lando/Mon Mothma) | deepseek-pro | flash | gemma4:31b | deepseek-pro | flash |
| `build` (Forge) | flash | flash | gemma4:31b | deepseek-pro | flash |
| `creative` (Spark) | kimi-k2.6 | flash* | gemma4:31b | kimi-k2.6 | flash |
| `business` (Ahsoka/Luthen) | kimi-k2.6 | flash | gemma4:31b | kimi-k2.6 | flash |
| `governance` (Shield/Lex/Sage/Warden) | gemma4:31b | flash | gemma4:31b | gemma4:31b | flash |

\* Spark high-stakes Execute (e.g., Ken's LinkedIn) may override to strong with `model_override: pro` + `override_reason`.

### 5.5 Routing resolver
The resolver is a script (`scripts/model-policy-query.sh` v2) that:

1. Reads the matrix from `state_model_policy`.
2. Accepts inputs: `agent_id`, `phase`, `data_class`, `stakes` (low/medium/high).
3. Returns: `model`, `tier`, `fallback`, `override_allowed`, `reason`.

For v1.3, the resolver is procedural and deterministic. Future versions may add dynamic scoring based on cost, latency, and observed capability.

### 5.6 Verify first-slot rule
The highest-leverage first move is:

> **All Verify phases default to `gemma4:31b-cloud` unless explicitly overridden.**

**Finding (2026-06-20 G4 benchmark):** `glm-5.1:cloud` outputs verdicts to `.thinking` field, not `.response` — incompatible with current Ollama/OpenClaw wiring. `gemma4:31b-cloud` scored 20/20 (100%) on the judgment benchmark and is the effective v1.3 Verify primary. `glm-5.1:cloud` is deferred until thinking-output handling is resolved.

Exceptions:
- High-stakes external-facing Verify → `deepseek-v4-pro:cloud` with override reason.

**Verify fallback chain:** If `gemma4:31b-cloud` is unavailable:
1. `deepseek-v4-pro:cloud` (correlated with executor but better than no verdict)
2. `kimi-k2.6:cloud` (decorrelated, business-tier strong)

---

## 6. Data Model: `state_sub_crest`

The sub-CREST state table is the durable record of every loop.

```sql
CREATE TABLE state_sub_crest (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_ticket TEXT NOT NULL,
  sub_ticket TEXT,
  atom_id TEXT,
  phase TEXT NOT NULL CHECK (phase IN ('Plan','Execute','Verify','Replan','Synthesize','Done')),
  owner TEXT NOT NULL,          -- agent registry id
  status TEXT NOT NULL CHECK (status IN ('pending','running','completed','failed','escalated','needs_human')),
  model TEXT,
  input JSONB,
  output JSONB,
  evidence JSONB,
  verdict TEXT CHECK (verdict IN ('pass','fail','needs_human')),
  iteration_count INT DEFAULT 0,
  timeout_seconds INT,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  tenant_id TEXT DEFAULT 'ainchors'
);
```

Indexes: parent_ticket, sub_ticket, owner, status, phase.

---

## 7. Normalized Model Policy Schema

`state_model_policy` is split from one JSONB blob into normalized tables. See `docs/CREST-v1.3-Model-Policy-Schema.md` for full DDL.

Key tables:
- `crest_phase_rules` — role × phase → model + fallback + rationale
- `model_capabilities` — model × data_class → capability score (1–5)
- `capability_matrix` — canonical matrix version + metadata

`state/model-policy.json` is retired as SSOT; it becomes a read-only cache generated nightly by `scripts/model-policy-export.sh` (cron TBD). During the v1.3 proving period (1 sprint), both PG and JSON cache are maintained. After v1.3 proves stable, the JSON cache is deprecated and consumers migrate to PG-first queries.

---

## 8. Verification Corpus

Every CREST execution must have a verifier corpus authored by the orchestrator before dispatch. This is unchanged from v1.2 but emphasized:

- Verifier corpus is a set of checks or file paths.
- Subagent runs the verifier and reports raw totals.
- Subagent MUST NOT modify the verifier or the system under test.

---

## 9. Escalation Protocol

Unchanged from v1.2:

```
Specialist Replan:
├── Gap fixable at atom level?  → iterate (n++)
└── Gap not fixable?             → escalate to Yoda
```

With Sage-as-Judge, escalation can also come from a `needs_human` verdict or a `fail` that Replan cannot resolve.

---

## 10. Transition and Cutover

### 10.1 v1.3 does NOT include
- Controller build (post-v1.3, Tier-1 PG SSOT proving run).
- Agentic dev+test loops (parked, §7 of v0.4).
- New model onboarding beyond the v1.3 base set.

### 10.2 Pre-execution gates
Before any Tier A execution:
1. **Judgment benchmark:** `glm-5.1:cloud` must pass 20-atom benchmark (≥90% correct).
2. **CHG record:** CHG must be logged and Ken-approved.
3. **Baseline snapshot:** `state/model-policy.json` and PG `state_model_policy` captured.
4. **Down-migration DDL:** Rollback scripts written and tested.

### 10.3 Execution tiers
See `.openclaw/tmp/crest-v1.3-execution-plan-draft.md` for Tier A–D atom breakdown.

---

## 11. Rollback

Rollback trigger (any of):
- Verify failure rate > 5% for 24h after Tier A.
- Gateway instability or increased error rate after any tier.
- Ken explicit "rollback CREST v1.3" command.

Rollback procedure:
1. Set `state_model_policy.active_matrix_version` back to v1.2.
2. Restore `state/model-policy.json` from git (`git checkout HEAD -- state/model-policy.json`).
3. Revert `state_sub_crest` changes if they caused instability.
4. Update `agent-skills/crest/SKILL.md` to reference v1.2.
5. Log CHG-rollback and alert Ken.

---

## 12. References

- v0.4 handoff: `.openclaw/tmp/CREST-ALIGN-v0.4.md`
- v1.2 reference: `docs/CREST-v1.2-Recursive-Model-C.md`
- Model policy schema: `docs/CREST-v1.3-Model-Policy-Schema.md`
- Execution plan: `.openclaw/tmp/crest-v1.3-execution-plan.md`

---

**END DRAFT — awaiting Ken review.**
