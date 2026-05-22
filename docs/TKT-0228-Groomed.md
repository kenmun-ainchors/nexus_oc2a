# TKT-0228 — OWL Drift Detection System (Groomed)
**Sprint 4 | Owner: Yoda | Effort: 2h | 5 atoms | Sequential**

## Why This Exists
Today's session was a live demonstration: deepseek-pro chain-reacted through 4 tickets without verification pauses. Journal format drift wasn't caught until Ken flagged it. OWL was restricted to kimi-only — but the model isn't the variable. The execution pattern is.

## What It Builds
A pre-flight guard that injects OWL constraints into any agent session executing MEDIUM/HIGH currency work, regardless of model. Combined with TKT-0237's DoD gate, this creates defense-in-depth: OWL prevents bad patterns, DoD gate catches bad outputs.

---

## Atom 1 — Create owl-guard.sh pre-flight check
**Effort:** 30 min | **Owner:** Yoda

A script sourced by the agent before any MEDIUM+ work begins. Injects OWL thinking constraints into the agent's context.

**What it does:**
- Checks `state/owl-compliance-state.json` for current session context
- If task currency = MEDIUM or HIGH → activates OWL mode
- Injects into agent context: "OWL MODE ACTIVE. Before each action: (1) pause 10s thinking, (2) state your reasoning, (3) assess risk, (4) execute single atom, (5) verify output before next atom. Chain-reacting through 3+ atoms without verification pauses = VIOLATION."
- Writes `state/owl-active.json` — `{sessionId, model, active: true, activatedAt, currency, reason}`
- If currency = LOW → OWL not activated (normal mode)

**Deliverable:** `scripts/owl-guard.sh`

**Acceptance Criteria:**
- [ ] AC1: Script runs, checks currency level from ticket/context, sets OWL active for MEDIUM+
- [ ] AC2: Writes owl-active.json with correct session/model/currency fields
- [ ] AC3: For LOW currency → OWL not activated, owl-active.json shows active=false
- [ ] AC4: Works for any model (deepseek, kimi, gemma4, sonnet, haiku) — model-agnostic

---

## Atom 2 — Update owl-compliance-state.json schema
**Effort:** 15 min | **Owner:** Yoda

Add model tracking to the existing compliance state file. Today's session would show: model=deepseek-v4-pro:cloud, drift_detected=true, chain_reactions=4.

**Schema update:**
```json
{
  "sessionId": "...",
  "model": "deepseek-v4-pro:cloud",
  "owlActive": true,
  "currency": "MEDIUM",
  "atomsExecuted": 26,
  "verificationPauses": 26,
  "chainReactions": 0,
  "driftsToday": 0,
  "dailyCompliance": 100,
  "lastDriftDetected": null
}
```

**Deliverable:** Updated `state/owl-compliance-state.json`

**Acceptance Criteria:**
- [ ] AC1: Schema includes `model` field tracking which model was in use
- [ ] AC2: Schema includes `currency` field tracking task complexity level
- [ ] AC3: Backward compatible — existing fields preserved
- [ ] AC4: File is valid JSON

---

## Atom 3 — Build OWL compliance heartbeat check
**Effort:** 20 min | **Owner:** Yoda

Add a lightweight compliance tracker that runs with the heartbeat. Not full audit — just the self-check from HEARTBEAT.md turned into a quick script.

**What it does:**
- Reads `state/owl-compliance-state.json`
- Calculates daily compliance score: (atomsExecuted - chainReactions - driftsToday) / atomsExecuted * 100
- If score < 70%: escalate to Ken via Telegram
- Resets daily counters at midnight AEST
- Updates HEARTBEAT.md to call this script

**Deliverable:** `scripts/owl-compliance-check.sh` + HEARTBEAT.md update

**Acceptance Criteria:**
- [ ] AC1: Script calculates compliance percentage correctly
- [ ] AC2: Daily reset works — counters zero at midnight
- [ ] AC3: Score <70% triggers Telegram alert with specific drift count
- [ ] AC4: HEARTBEAT.md updated to run this check

---

## Atom 4 — Update RULES.md OWL section
**Effort:** 10 min | **Owner:** Yoda

Strike "kimi-class only" from the OWL mandate. Replace with model-agnostic language.

**Changes:**
- OWL section: "ALL agents executing MEDIUM or HIGH currency work, regardless of model"
- Add reference to `scripts/owl-guard.sh` as the enforcement mechanism
- Add: "OWL compliance tracked in owl-compliance-state.json. Violations flagged by Warden (R05 in TKT-0237)"

**Deliverable:** Updated RULES.md

**Acceptance Criteria:**
- [ ] AC1: No mention of "kimi-class only" remains in OWL section
- [ ] AC2: Model-agnostic language present
- [ ] AC3: References owl-guard.sh and owl-compliance-state.json
- [ ] AC4: Git committed

---

## Atom 5 — End-to-end verification
**Effort:** 15 min | **Owner:** Yoda

Run a simulated MEDIUM currency task through the full OWL flow.

**Test:**
1. Set OWL active via owl-guard.sh (simulated MEDIUM task)
2. Execute 3 atoms rapidly without verification pauses → owl-compliance-check.sh should detect chain-reaction
3. Execute 3 atoms with explicit pauses → compliance score should be 100%
4. Verify Telegram alert fires when score <70%

**Deliverable:** Test log in notes

**Acceptance Criteria:**
- [ ] AC1: Chain-reaction pattern correctly detected
- [ ] AC2: Compliant pattern correctly reported as 100%
- [ ] AC3: No false positives on LOW currency tasks
- [ ] AC4: All scripts exit clean

---

## Summary

| Atom | What | Effort |
|------|------|--------|
| 1 | owl-guard.sh — pre-flight OWL activation | 30m |
| 2 | owl-compliance-state.json — add model+currency fields | 15m |
| 3 | owl-compliance-check.sh — heartbeat integration | 20m |
| 4 | RULES.md — strike kimi-only, model-agnostic | 10m |
| 5 | End-to-end verification | 15m |

**Total: 1.5h (reduced from 2h — leverages TKT-0237 R05 for full audit, no need for separate audit script)**

## Dependencies
- TKT-0237 complete ✅ (R05 State Checking covers OWL compliance in rule-audit.sh)
- No other dependencies

## DoD
- [ ] owl-guard.sh activates OWL for any model on MEDIUM+ currency
- [ ] owl-compliance-state.json tracks model + compliance score
- [ ] Heartbeat surfaces OWL drift alerts to Ken
- [ ] RULES.md updated: all models, not just kimi
- [ ] End-to-end test passes: chain-reaction detected, compliant path scores 100%
