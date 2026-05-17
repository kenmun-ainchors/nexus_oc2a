### ASYNC STATELESS DESIGN — NON-NEGOTIABLE (CHG-0389)
# Effective: 2026-05-17 16:51 AEST
# Authority: Ken Mun (CTO) — ABSOLUTELY NON-NEGOTIABLE, PERSISTENT

**Agents must be able to resume work from any checkpoint if timeout kicks in.**

This rule is:
- **ARCHITECTURAL** — Changes how work is structured and saved
- **STATELESS** — Work survives agent/session death
- **RESILIENT** — Any agent can resume any task
- **ASYNC** — Work can run in background, progress checked later

---

## The Problem

**Current pattern (fragile):**
```
Agent starts work → works for 5 minutes → dies → work lost → restart from 0
```

**Why it fails:**
- Work is bound to agent session
- No checkpoints during execution
- No shared queue of pending work
- No concept of "pick up where left off"

---

## The Solution: Async Stateless Task Queue

### Core Principle

**Every unit of work is a Task. Every Task is a series of Atoms. Each Atom is a checkpoint.**

```
Task = {
  id: "task-2026-05-17-001",
  status: "pending|claimed|in-progress|complete|failed",
  atoms: [
    { id: 1, status: "complete", result: "..." },
    { id: 2, status: "in-progress", startedAt: "..." },
    { id: 3, status: "pending" }
  ]
}
```

Any agent can read this Task and resume from the first pending atom.

---

## Architecture

### 3 Layers

| Layer | Purpose | Storage | Example |
|-------|---------|---------|---------|
| **Task Queue** | Pending work pool | `state/task-queue.json` | "Create 5 tickets" |
| **Checkpoints** | Per-task atom status | `state/checkpoints/[taskId].json` | "Atom 3 of 5 complete" |
| **Artifacts** | Work output | Files, Notion pages, git commits | Created tickets |

### Flow

```
1. Ken requests work → Yoda creates Task in Queue
2. Any agent claims Task → marks "claimed"
3. Agent executes Atom 1 → saves checkpoint → marks "complete"
4. Agent executes Atom 2 → timeout kicks in → agent dies
5. New agent reads checkpoint → sees Atom 2 failed, Atom 3 pending
6. New agent resumes from Atom 3 → completes → marks Task "complete"
```

---

## Task Queue Format

**File:** `state/task-queue.json`

```json
{
  "schema": "task-queue-v1",
  "lastUpdated": "2026-05-17T16:51:00+10:00",
  "tasks": [
    {
      "id": "task-2026-05-17-001",
      "title": "Create 5 replacement tickets in Notion",
      "tier": 3,
      "status": "in-progress",
      "claimedBy": "agent:main:subagent:abc123",
      "claimedAt": "2026-05-17T16:30:00+10:00",
      "priority": "high",
      "source": "ken-directive",
      "relatedChg": "CHG-0388",
      "atoms": [
        {
          "id": 1,
          "description": "Create TKT-0201 in Notion",
          "status": "complete",
          "result": {
            "notionPageId": "363c1829-...",
            "notionUrl": "https://..."
          },
          "completedAt": "2026-05-17T16:31:00+10:00",
          "completedBy": "agent:main:subagent:abc123"
        },
        {
          "id": 2,
          "description": "Create TKT-0202 in Notion",
          "status": "failed",
          "error": "API timeout after 30s",
          "failedAt": "2026-05-17T16:35:00+10:00",
          "failedBy": "agent:main:subagent:abc123"
        },
        {
          "id": 3,
          "description": "Create TKT-0203 in Notion",
          "status": "pending"
        }
      ],
      "createdAt": "2026-05-17T16:25:00+10:00",
      "updatedAt": "2026-05-17T16:35:00+10:00"
    }
  ]
}
```

---

## Checkpoint Format

**File:** `state/checkpoints/[taskId].json`

```json
{
  "schema": "checkpoint-v1",
  "taskId": "task-2026-05-17-001",
  "currentAtom": 3,
  "atoms": [
    {
      "id": 1,
      "status": "complete",
      "completedAt": "2026-05-17T16:31:00+10:00",
      "result": {
        "notionPageId": "363c1829-...",
        "notionUrl": "https://..."
      }
    },
    {
      "id": 2,
      "status": "failed",
      "failedAt": "2026-05-17T16:35:00+10:00",
      "error": "API timeout after 30s",
      "retryCount": 1
    },
    {
      "id": 3,
      "status": "pending"
    }
  ],
  "lastUpdated": "2026-05-17T16:35:00+10:00"
}
```

---

## Recovery Protocol

### When Agent Dies (Timeout)

```
1. Check task-queue.json → find "in-progress" tasks with old timestamps
2. Read checkpoint file → identify first pending atom
3. Reset task status: "claimed" → "pending" (if dead agent)
4. Any new agent can claim and resume
```

### Resume Script

**`scripts/resume-task.sh`**

```bash
#!/bin/bash
# Resume a task from checkpoint

TASK_ID="$1"
CHECKPOINT_FILE="/Users/ainchorsangiefpl/.openclaw/workspace/state/checkpoints/${TASK_ID}.json"

if [ ! -f "$CHECKPOINT_FILE" ]; then
  echo "ERROR: No checkpoint found for $TASK_ID"
  exit 1
fi

# Find first pending or failed atom
PENDING_ATOM=$(python3 -c "
import json
with open('$CHECKPOINT_FILE') as f:
    cp = json.load(f)
for atom in cp.get('atoms', []):
    if atom['status'] in ['pending', 'failed']:
        print(atom['id'])
        break
")

if [ -z "$PENDING_ATOM" ]; then
  echo "Task $TASK_ID is complete"
  exit 0
fi

echo "Resuming task $TASK_ID from atom $PENDING_ATOM"
# Spawn subagent to resume from this atom
# ...
```

---

## Async Execution Pattern

### For Tier 3 Complex Work

**Phase 1: Enqueue (Foreground, fast)**
```
1. Ken: "Create 50 tickets"
2. Yoda: Analyzes → Creates Task with 50 atoms
3. Yoda: "Task queued: task-2026-05-17-002 (50 atoms). Starting background execution."
4. Yoda spawns background subagent with timeout=0
```

**Phase 2: Execute (Background, stateless)**
```
Subagent loop:
  while task not complete:
    1. Read checkpoint file
    2. Find first pending atom
    3. Execute atom
    4. Update checkpoint file
    5. If timeout approaching → save state, exit cleanly
    6. If API error → mark failed, increment retry, continue
```

**Phase 3: Monitor (Anytime)**
```
Ken: "Status of task-2026-05-17-002?"
Yoda: Reads checkpoint → "35 of 50 complete. Atom 36 in progress."
```

**Phase 4: Resume (If needed)**
```
Subagent dies at atom 36.
New subagent spawns → reads checkpoint → resumes at atom 36.
```

---

## Race Condition Prevention

### Task Locking

```json
{
  "id": "task-2026-05-17-001",
  "status": "claimed",
  "claimedBy": "agent:main:subagent:abc123",
  "claimedAt": "2026-05-17T16:30:00+10:00",
  "claimTimeout": "2026-05-17T17:00:00+10:00"
}
```

**Rules:**
- Agent claims task → sets claimTimeout = now + 30 min
- If agent dies → claimTimeout expires → status resets to "pending"
- New agent can claim expired task
- If agent is alive → extends claimTimeout every 10 minutes

### Atom Locking

```json
{
  "id": 36,
  "status": "in-progress",
  "claimedBy": "agent:main:subagent:abc123",
  "startedAt": "2026-05-17T16:45:00+10:00"
}
```

**Rules:**
- Atom in "in-progress" for > 30 min → assume agent died → reset to "pending"
- Only one agent can have atom in "in-progress"

---

## Implementation

### New Files

| File | Purpose |
|------|---------|
| `state/task-queue.json` | Master queue of all tasks |
| `state/checkpoints/[taskId].json` | Per-task checkpoint state |
| `scripts/task-queue.sh` | CLI for queue management |
| `scripts/resume-task.sh` | Resume from checkpoint |
| `scripts/claim-task.sh` | Claim next pending task |

### New Cron

**Task Queue Processor (every 5 min):**
```
1. Read task-queue.json
2. Find "pending" tasks
3. Find expired claims (claimTimeout passed)
4. Reset expired claims to "pending"
5. Report to Ken: "[N] tasks pending, [M] stale claims reset"
```

### Integration with Tiered OWL

| Tier | Queue Usage |
|------|-------------|
| **Tier 1** | No queue (immediate response) |
| **Tier 2** | Optional queue for tracking |
| **Tier 3** | **Mandatory queue** — all complex work is queued |

---

## Benefits

| Benefit | Explanation |
|---------|-------------|
| **Timeout resilience** | Work survives agent death |
| **Load balancing** | Any agent can pick up work |
| **Observability** | Ken can check progress anytime |
| **Retry logic** | Failed atoms can be retried independently |
| **Parallelization** | Multiple agents can work on different tasks |
| **Audit trail** | Complete history of what was done when |

---

## Ken's Directive

> "is there option where we can consider async and stateless design that would allow agents to pick-up/resume where left off should the timeout does kick-in"

**Date:** 2026-05-17 16:51 AEST  
**Channel:** openclaw-control-ui  
**Decision:** Yes — Async Stateless Task Queue  
**CHG:** CHG-0389

---

## Enforcement

**Warden Check (every 15 min):**
- Verify Tier 3 tasks use task queue
- Verify checkpoints are being saved
- Flag stale claims > 30 min old
- Report queue statistics to Ken

**Agent Self-Check:**
```
Before starting Tier 3 work:
  1. "Is this task in the queue?" → If NO, add it
  2. "Have I claimed it?" → If NO, claim it
  3. "Where is the checkpoint file?" → Define path
  4. "What if I timeout?" → Save checkpoint after every atom
```

---

**This rule is MANDATORY and PERSISTENT until explicitly revoked by Ken.**