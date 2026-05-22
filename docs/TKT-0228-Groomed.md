# TKT-0228 — OWL Drift Detection System (Groomed — Final)
**Sprint 4 | Owner: Yoda | Effort: 3h | 6 atoms | Sequential**

## Why This Exists
TKT-0237 proved that Plan→Breakdown→Sequence→Execute→Verify works when enforced. But enforcement today was manual — Ken watching Yoda. Tomorrow, any agent (deepseek, kimi, gemma4, future models) picks up work without that oversight.

TKT-0228 makes the execution discipline we demonstrated today the DEFAULT for ALL agents on ALL models, enforced by the platform, not by Ken's attention.

## What It Builds
A pre-session OWL contract. Before any MEDIUM+ work begins, the platform injects OWL constraints. The agent doesn't choose to follow OWL — the session starts in OWL mode. Combined with TKT-0237's TQP (for queued tasks) and DoD gate (for all tasks), this creates three-layer enforcement:
1. **OWL guard (TKT-0228):** Agent must think before acting
2. **TQP (TKT-0237 C1):** Platform verifies output before marking done
3. **DoD gate (TKT-0237 A1):** Close blocked without real deliverable

---

## Atom 1 — owl-guard.sh: Pre-session OWL contract enforcement
**Effort:** 45 min | **Owner:** Yoda

This is NOT a script agents optionally run. This is the execution contract that activates at session start for any MEDIUM+ currency work, regardless of model.

### What it does

**Phase A — Currency Detection (automatic)**
- At session start, detect the task's currency level:
  - **LOW:** single-step, read-only, status check, heartbeat → OWL not activated
  - **MEDIUM:** multi-step, state changes, ticket operations, script creation → OWL activated
  - **HIGH:** architecture decisions, platform changes, Notion API writes, cron modification → OWL activated
- Detection method: parse the task prompt for keywords (create/ticket/close/config/cron/notion/deploy/migrate → MEDIUM+), count expected deliverables, check if task involves state mutation
- If task explicitly tagged `OWL:OFF` (emergency mode only, Ken-authorized) → skip activation

**Phase B — OWL Contract Injection (mandatory for MEDIUM+)**
- Write `state/owl-active.json`:
  ```json
  {
    "sessionId": "...",
    "model": "deepseek-v4-pro:cloud",
    "owlActive": true,
    "currency": "MEDIUM",
    "activatedAt": "ISO",
    "planRequired": true,
    "maxAtomsPerTurn": 1,
    "verificationRequired": true,
    "pauseRequiredMs": 10000
  }
  ```
- Inject OWL constraints into the agent's system prompt/context:
  ```
  OWL MODE ACTIVE — NON-NEGOTIABLE

  EXECUTION CONTRACT:
  1. PLAN: Before executing, output your plan as numbered atoms.
  2. BREAKDOWN: Each atom = 1 observable unit of work. No multi-atom turns.
  3. SEQUENCE: Execute atoms one at a time. Verify each before next.
  4. EXECUTE: Produce output. Do NOT self-report "done."
  5. VERIFY: After each atom — file exists? git committed? test passes?

  VIOLATIONS (detected by platform, not by agent self-report):
  - 3+ atoms without verification pause → CHAIN REACTION VIOLATION
  - Execute without plan → NO PLAN VIOLATION
  - Error → immediate fix without assessment → RUSH VIOLATION
  - Claim "done" without verification → FALSE DONE VIOLATION

  ENFORCEMENT:
  - Violations logged to owl-compliance-state.json
  - 3 violations in 24h → Telegram alert to Ken
  - Daily compliance <70% → session restricted to LOW currency only
  - TKT-0237 R05 (State Checking) audits OWL compliance post-execution
  ```

**Phase C — TQP Integration (for queued tasks)**
- If task comes through TQP (TKT-0237 C1), OWL is automatically active
- TQP enforces: atom verification → re-queue on fail → escalate on 3x fail
- OWL guard + TQP = double enforcement: agent can't skip thinking, platform can't skip verification

**Phase D — Accountability Recording**
- Every atom executed is logged to `state/owl-compliance-state.json`:
  ```json
  {
    "atoms": [
      {
        "atomId": "A1",
        "description": "Create verify_before_close() skeleton",
        "startedAt": "ISO",
        "completedAt": "ISO",
        "verificationPauseMs": 12400,
        "verified": true,
        "output": "scripts/ticket.sh: function added, bash -n PASS"
      }
    ]
  }
  ```
- This creates an audit trail. If an agent claims "done" but the file doesn't exist, the log shows what they claimed vs reality.
- Combined with TKT-0237 A3 (post-close validator), gaps are caught within 2h.

### Deliverable
`scripts/owl-guard.sh` — sourced at session start by heartbeat, cron agents, and manual sessions.

### Acceptance Criteria
- [ ] AC1: Script detects MEDIUM+ currency from task context (keyword matching + deliverable count)
- [ ] AC2: Writes owl-active.json with all required fields: sessionId, model, owlActive, currency, planRequired, maxAtomsPerTurn, verificationRequired
- [ ] AC3: LOW currency tasks → OWL not activated (owlActive=false). Verify: `echo "status check" | detect_currency` → LOW
- [ ] AC4: MEDIUM currency tasks → OWL activated. Verify: `echo "create ticket for cron fix" | detect_currency` → MEDIUM
- [ ] AC5: HIGH currency tasks → OWL activated with maxAtomsPerTurn=1. Verify: `echo "deploy postgres migration" | detect_currency` → HIGH
- [ ] AC6: Model-agnostic — works for deepseek, kimi, gemma4, sonnet, haiku. Test: set MODEL=gemma4, run guard → OWL still activates
- [ ] AC7: `OWL:OFF` emergency tag respected → owl-active.json shows active=false, reason="emergency_override"
- [ ] AC8: OWL constraints injected into agent context — verify the constraint text is present in system prompt/context after activation
- [ ] AC9: owl-compliance-state.json updated with atom-level audit trail (atoms array with timestamps + verification status)
- [ ] AC10: Integration test: TQP queue task → OWL auto-activates → agent executes → TQP verifies → done. Full pipe.

---

## Atom 2 — owl-compliance-state.json schema + daily tracking
**Effort:** 20 min | **Owner:** Yoda

Update the compliance state file to capture per-atom tracking with model attribution.

**Schema:**
```json
{
  "sessionId": "...",
  "model": "deepseek-v4-pro:cloud",
  "owlActive": true,
  "currency": "MEDIUM",
  "activatedAt": "ISO",
  "atoms": [],
  "summary": {
    "totalAtoms": 0,
    "verifiedAtoms": 0,
    "chainReactions": 0,
    "driftsToday": 0,
    "dailyCompliance": 100,
    "lastDriftDetected": null,
    "responsesToday": 0
  }
}
```

**Deliverable:** Updated `state/owl-compliance-state.json` + `scripts/owl-reset-daily.sh`

**Acceptance Criteria:**
- [ ] AC1: Schema includes model, currency, atoms array with per-atom tracking
- [ ] AC2: Daily reset at midnight AEST via cron — counters zero, atoms array archived
- [ ] AC3: Chain-reaction detection: 3+ atom completions without verification pauses (>30s gap) → chainReactions++
- [ ] AC4: Backward compatible with existing owl-compliance-state.json

---

## Atom 3 — owl-compliance-check.sh: Heartbeat integration
**Effort:** 20 min | **Owner:** Yoda

Lightweight compliance check that runs with heartbeat. Not the full audit (that's TKT-0237 R05) — just the real-time alerting layer.

**What it does:**
- Reads `state/owl-compliance-state.json`
- Calculates daily compliance: verifiedAtoms/totalAtoms * 100
- If score <70%: creates `state/owl-drift-alert.json` with details
- Heartbeat reads alert → surfaces to Ken: "⚠️ OWL Compliance: 56% today. 4 chain-reactions, 2 false-dones. Model: deepseek-v4-pro. Last drift: [time]."
- If score >=70% AND previous alert existed → clears alert (compliance recovered)
- Updates `state/heartbeat-state.json` → lastChecks.owlCompliance

**Deliverable:** `scripts/owl-compliance-check.sh` + HEARTBEAT.md update

**Acceptance Criteria:**
- [ ] AC1: Script calculates compliance percentage: (verifiedAtoms / totalAtoms) * 100
- [ ] AC2: Score <70% → owl-drift-alert.json created with model + drift details
- [ ] AC3: Score >=70% → existing alert cleared (recovery tracked)
- [ ] AC4: Division by zero handled (0 atoms = 100% compliance, not error)
- [ ] AC5: HEARTBEAT.md updated with OWL compliance check section
- [ ] AC6: Alert message includes: compliance %, model in use, drift count, last drift timestamp, recommended action

---

## Atom 4 — RULES.md OWL section: model-agnostic + execution contract
**Effort:** 15 min | **Owner:** Yoda

Rewrite the OWL mandate to be enforceable, model-agnostic, and integrated with the platform verification stack.

**Changes:**
1. Strike ALL mentions of "kimi-class only"
2. Add: "OWL applies to ALL agents executing MEDIUM or HIGH currency work, regardless of model (deepseek, kimi, gemma4, sonnet, haiku, future models)"
3. Add execution contract: Plan → Breakdown → Sequence → Execute → Verify
4. Reference enforcement: owl-guard.sh (pre-session) + TQP (queued tasks) + DoD gate (close)
5. Add: "OWL compliance is audited by TKT-0237 R05 (State Checking). Violations are non-negotiable DoD failures."

**Deliverable:** Updated RULES.md

**Acceptance Criteria:**
- [ ] AC1: Zero mentions of "kimi-class only" or "kimi only" in OWL section
- [ ] AC2: Execution contract (Plan→Breakdown→Sequence→Execute→Verify) documented
- [ ] AC3: Cross-references: owl-guard.sh, TKT-0237, TKT-0237 R05, TQP
- [ ] AC4: Violation consequences: 3 violations → alert, <70% daily → restricted to LOW

---

## Atom 5 — Platform-wide enforcement integration
**Effort:** 20 min | **Owner:** Yoda

Wire OWL guard into the session startup path so it activates automatically — not just when an agent remembers to run it.

**Integration points:**
1. **HEARTBEAT.md:** Add OWL pre-check at top — "If OWL not active for this session, run owl-guard.sh to assess currency level"
2. **TQP (TKT-0237 C1):** Add OWL guard call before dispatching task — if currency MEDIUM+, set owlActive=true in task-queue.json entry
3. **AGENTS.md:** Add OWL section — "Before executing any MEDIUM+ work, verify owl-active.json shows active=true. If not, source owl-guard.sh."
4. **Warden cron (R05):** TKT-0237's rule-audit.sh already checks State Checking pattern — R05 now includes OWL compliance as a sub-check

**Deliverable:** Updated HEARTBEAT.md, AGENTS.md, task-queue-processor.sh

**Acceptance Criteria:**
- [ ] AC1: HEARTBEAT.md updated with OWL pre-check as first step
- [ ] AC2: TQP dispatch includes OWL activation check before task spawn
- [ ] AC3: AGENTS.md includes OWL execution contract reference
- [ ] AC4: R05 in rule-audit.sh detects OWL violations as part of State Checking
- [ ] AC5: End-to-end: session starts → OWL activated automatically for MEDIUM+ → no manual sourcing needed

---

## Atom 6 — End-to-end verification
**Effort:** 15 min | **Owner:** Yoda

Prove the full pipe works end-to-end.

**Test plan:**
1. **LOW currency:** Heartbeat check → OWL not activated → normal mode → compliance 100%
2. **MEDIUM currency:** Ticket close task → OWL auto-activates → atoms with pauses → verified → compliance 100%
3. **MEDIUM currency, chain-reaction:** Execute 3 atoms without pauses → compliance check detects → owl-drift-alert.json created
4. **Compliance recovery:** After alert, execute properly → score recovers → alert cleared
5. **Model-agnostic:** Repeat test with MODEL=gemma4 and MODEL=kimi → same behavior

**Deliverable:** Test log in TKT-0228 notes

**Acceptance Criteria:**
- [ ] AC1: Chain-reaction correctly detected (3+ atoms, no verification pauses)
- [ ] AC2: Compliant path scores 100% with proper pauses
- [ ] AC3: All 5 test scenarios pass
- [ ] AC4: No false positives on LOW currency tasks
- [ ] AC5: Scripts exit clean, no zombie processes

---

## Summary

| Atom | What | Effort | Depends On |
|------|------|--------|------------|
| 1 | owl-guard.sh — pre-session OWL contract | 45m | — |
| 2 | owl-compliance-state.json — atom tracking | 20m | A1 |
| 3 | owl-compliance-check.sh — heartbeat alerting | 20m | A2 |
| 4 | RULES.md — model-agnostic mandate | 15m | — |
| 5 | Platform-wide integration | 20m | A1-A4 |
| 6 | End-to-end verification | 15m | A1-A5 |

**Total: 2h 15min (adjusted from 1.5h — added platform integration atom)**

## How This Ensures Future Agents Follow the Same Discipline

| Layer | What enforces it | Model-dependent? |
|-------|-----------------|------------------|
| OWL guard (TKT-0228) | Pre-session contract injection | No — runs before agent starts |
| TQP (TKT-0237 C1) | Platform verifies output | No — shell script, not LLM |
| DoD gate (TKT-0237 A1) | Blocks close without proof | No — bash function |
| Post-close validator (TKT-0237 A3) | Catches drift within 2h | No — cron |
| Rule audit R05 (TKT-0237 B1) | Audits OWL compliance | No — scheduled sweep |
| Weekly report (TKT-0237 B2) | Surfaces trends to Ken | No — automated HTML |

**None of these depend on the agent model.** A future Sonnet-6, GPT-6, or local Llama-5 agent will be held to the same standard because the enforcement is in the platform, not the agent.

## Dependencies
- TKT-0237 complete ✅
- No other dependencies

## DoD
- [ ] owl-guard.sh activates OWL for any model on MEDIUM+ currency
- [ ] Platform auto-activates OWL — no manual sourcing required
- [ ] Compliance tracked per-atom with model attribution
- [ ] <70% compliance → Telegram alert within 1 heartbeat cycle
- [ ] RULES.md: model-agnostic, execution contract documented
- [ ] End-to-end: chain-reaction detected, compliant path scores 100%, all models behave identically
