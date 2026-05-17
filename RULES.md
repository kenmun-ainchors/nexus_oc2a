### TIERED OWL — NON-NEGOTIABLE (CHG-0388)
# Effective: 2026-05-17 16:48 AEST
# Authority: Ken Mun (CTO) — ABSOLUTELY NON-NEGOTIABLE, PERSISTENT

**Full OWL on ALL actions creates timeouts. Tiered OWL prevents this.**

## The Problem

Applying full 4.5-minute OWL analysis to EVERY action creates:
- Chat = unresponsive
- Subagents = timeout failures  
- Crons = missed executions
- UX = poor

## The Solution: 3 Tiers

| Tier | Trigger | OWL Depth | Time Budget | Timeout Config |
|------|---------|-----------|-------------|----------------|
| **Tier 1: Chat/Q&A** | Question, status, clarification | Owl-lite | 10-15s | N/A (webchat) |
| **Tier 2: Atomic Task** | Single step execution | Standard OWL | 3 min max | Subagent: 300s |
| **Tier 3: Complex Multi-step** | Multi-step, bulk, risky | Full OWL + background | 5+ min | Subagent: 0 (no timeout) + background |

---

## TIER 1 — Chat/Q&A (10-15 seconds)

### When to Use
- Ken asks a question
- Status updates
- Clarifications
- Simple lookups

### Process
```
1. Observe (5s): What is Ken asking?
2. Analyze (5s): Is this Q or request?  
3. Respond (5s): Answer or acknowledge
```

### Examples
| Input | Response Time | Action |
|-------|--------------|--------|
| "Status of TKT-0196?" | 10s | Quick lookup, immediate answer |
| "What did we decide yesterday?" | 15s | Memory search, summary |
| "Good morning" | 5s | Greeting + brief status |

---

## TIER 2 — Atomic Task (3 minutes max)

### When to Use
- Single step execution
- Create one ticket
- Update one file
- Run one script
- Verify one item

### Timeout Configuration

**Subagent spawn:**
```json
{
  "mode": "run",
  "runTimeoutSeconds": 300,
  "timeoutSeconds": 300
}
```

**Cron job:**
```json
{
  "timeoutSeconds": 300
}
```

### Process
```
1. Observe (30s): What exactly needs to be done?
2. Analyze (60s): Implications, risks, what could fail
3. Perspective (30s): What would Ken catch?
4. Plan (60s max): Exact commands, exact paths, verification
   - Must specify: exact command, exact file path, verification step
   - If planning reveals complexity > atomic → escalate to Tier 3
5. Risk check (30s): Hidden factors, edge cases
6. Execute (remaining time): Run the single atomic step
7. Verify: Confirm the step worked
8. Report: "Step complete, result: [X]"
```

### Time Budget (3 minutes = 180 seconds)

| Phase | Time | Running Total |
|-------|------|---------------|
| Analysis (steps 1-5) | 120s | 120s |
| Execution | 30s | 150s |
| Verification | 20s | 170s |
| Report | 10s | 180s |

**If analysis exceeds 120s → escalate to Tier 3**

### Checkpointing (Mandatory)

**After each atomic step, save progress:**
```json
{
  "taskId": "[uuid]",
  "tier": 2,
  "step": "[description]",
  "status": "complete|in-progress|failed",
  "completedAt": "2026-05-17T16:30:00+10:00",
  "result": "[summary]",
  "nextStep": "[description or null]",
  "retryCount": 0
}
```

**Save to:** `state/tier2-progress-[taskId].json`

---

## TIER 3 — Complex Multi-step (5+ minutes, background)

### When to Use
- Multi-step workflows
- Bulk operations (>1 item)
- Complex analysis
- Risky operations requiring HITL

### Timeout Configuration

**Subagent spawn (background, no timeout):**
```json
{
  "mode": "run",
  "runTimeoutSeconds": 0,
  "timeoutSeconds": 0,
  "label": "background-task-[name]"
}
```

**Critical:** `timeoutSeconds: 0` means no timeout. Work continues until complete.

### Process

```
Phase 1: Analysis (5+ minutes, foreground)
  1. Observe: Full requirements gathering
  2. Analyze: Deep implications, dependencies, risks
  3. Perspective: Multiple viewpoints (Ken, user, system)
  4. Plan: Comprehensive plan with all steps documented
  5. Risk check: Edge cases, alternatives, rollback plans
  → Output: Detailed plan document

Phase 2: HITL Gate (if risky)
  → Present plan to Ken
  → Ken approves/modifies/rejects
  → Only proceed after explicit approval

Phase 3: Execution (background)
  → Spawn background subagent with timeout=0
  → Subagent executes plan step-by-step
  → Progress saved to state file every step
  → Ken can check progress via state file

Phase 4: Completion Report
  → Subagent completes or fails
  → Final report delivered to Ken
  → State file updated with completion status
```

### Background Subagent Pattern

**Spawn command:**
```bash
# Example: Creating 10 tickets in background
sessions_spawn \
  --mode run \
  --runTimeoutSeconds 0 \
  --label "bulk-ticket-creation-TKT-0200-0209" \
  --task "Create 10 tickets per CHG-0377 atomic task rule. 
    Step 1: Read current tickets.json to verify no duplicates.
    Step 2: Create TKT-0200, verify in Notion.
    Step 3: Create TKT-0201, verify in Notion.
    ...
    Step 10: Create TKT-0209, verify in Notion.
    After each step: Save progress to state/tier3-progress-[taskId].json
    If any step fails: Stop, report failure, do NOT continue."
```

### Progress Tracking (Mandatory)

**Progress state file:**
```json
{
  "taskId": "bulk-ticket-creation-2026-05-17",
  "tier": 3,
  "status": "in-progress",
  "startedAt": "2026-05-17T16:30:00+10:00",
  "totalSteps": 10,
  "completedSteps": 3,
  "currentStep": {
    "number": 4,
    "description": "Create TKT-0203 in Notion",
    "startedAt": "2026-05-17T16:35:00+10:00"
  },
  "completed": [
    {
      "step": 1,
      "description": "Read tickets.json",
      "result": "Found 220 tickets, no duplicates for TKT-0200-0209",
      "completedAt": "2026-05-17T16:31:00+10:00"
    }
  ],
  "failed": null,
  "lastUpdated": "2026-05-17T16:35:00+10:00"
}
```

**Save to:** `state/tier3-progress-[taskId].json`

**Update frequency:** After EVERY atomic step within the Tier 3 task.

### Recovery Mechanisms

**If subagent stalls:**
1. Progress file exists → resume from last completed step
2. Ken can check: `read state/tier3-progress-[taskId].json`
3. Yoda can resume or kill stalled subagent

**If subagent dies:**
1. Check progress file for last completed step
2. Determine: resume from next step or restart from beginning
3. Report to Ken: "Task [N]% complete, resuming from step [X]"

**If gateway disconnects:**
1. Background subagent continues running
2. Progress file continues updating
3. When Ken reconnects, read progress file for status

---

## Timeout Prevention Checklist

### Before Spawning ANY Subagent

| Check | Tier 1 | Tier 2 | Tier 3 |
|-------|--------|--------|--------|
| Timeout configured? | N/A | 300s | 0 (unlimited) |
| Progress file path defined? | No | Yes | Yes |
| Rollback plan documented? | No | Yes | Yes |
| Ken notified it's starting? | No | Yes | Yes |
| Progress reporting configured? | No | No | Yes |

### Subagent Self-Check

**Before starting work:**
```
1. "What tier is this task?" → Set timeout accordingly
2. "Where do I save progress?" → Define state file path
3. "What if I timeout?" → Document last step completed
4. "How do I report progress?" → Update state file after each step
```

---

## Ken's Directive

> "A. For Tier 2 and 3, what can be done to ensure total execution time does not cause any work to be cut-off/killed/stalled due to timeout risk?"

**Date:** 2026-05-17 16:48 AEST  
**Channel:** openclaw-control-ui  
**Decision:** Tiered OWL (Option A) + Timeout Prevention  
**CHG:** CHG-0388

---

## Enforcement

**Warden Check (every 15 min):**
- Verify subagent timeouts match tier
- Flag Tier 2 subagents with timeout < 300s
- Flag Tier 3 subagents with timeout != 0
- Escalate violations to Yoda → Ken

**Self-Reporting:**
- Before spawning: Report tier and timeout configured
- After completion: Report actual time taken vs budget
- If timeout occurred: Report which step was in progress

---

**This rule is MANDATORY and PERSISTENT until explicitly revoked by Ken.**