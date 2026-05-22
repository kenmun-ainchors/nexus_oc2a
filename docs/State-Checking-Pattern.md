# State Checking Pattern — Codify Check-Before-Act

**Status:** Approved by Ken Mun 2026-05-21
**Linked Tickets:** TKT-0182, TKT-0196, TKT-0197, TKT-0198
**Authority:** Enterprise Architecture Standard

## 1. Objective
Prevent agents from acting on stale or incomplete state, reducing JSON drift, ID collisions, and path confusion. This pattern mandates that agents explicitly verify the current state of the system before performing any stateful operation.

## 2. The 4-Step Cycle
Before any stateful operation (Write/Update/Create), agents MUST follow this cycle:

### Step 1: READ
Query the Single Source of Truth (SSOT) for the current state.
- **Postgres:** Query the relevant `state_*` table.
- **JSON:** Read the canonical state file from the workspace root.
- **Notion:** Fetch the current page/database properties.

### Step 2: VALIDATE
Verify that the operation is valid given the current state.
- **Status Transition:** Is the move valid? (e.g., `open` $\to$ `in-progress` is OK; `closed` $\to$ `open` is NOT OK).
- **ID Uniqueness:** If creating a new entity, verify the ID does not already exist to prevent collisions.
- **Path Accuracy:** Verify the target path is an absolute path from the workspace root.
- **Schema Validation:** Ensure the data structure matches the expected schema before writing.

### Step 3: EXECUTE
Perform the write or update operation using the approved tool (e.g., `ticket.sh`, `state_write.py`).

### Step 4: VERIFY
Read back the state immediately after the write to confirm the change landed correctly.
- Confirm the value changed to the expected state.
- Verify no unexpected side effects occurred in the record.

---

## 3. Error Handling Matrix

| Scenario | Agent Action |
|---|---|
| **State Stale** (version mismatch) | Re-read current state, resolve conflict, retry once. |
| **State Locked** (concurrent write) | Wait (exponential backoff), then retry. |
| **State Invalid** (corrupt/malformed) | **HITL:** Stop operation, alert Ken immediately. |
| **Operation Invalid** (bad transition) | Abort operation, log the specific reason for failure. |

## 4. Idempotency Requirement
All stateful operations must be **idempotent**. If a task is retried after a timeout or failure, the result must be the same as a sign-off execution.

---

## 5. Domain Application Examples

| Domain | Check-Before-Act Requirement |
|---|---|
| **Tickets** | Check `state_tickets` (Postgres) before using `ticket.sh update`. Validate status transition. |
| **Cost Tracking** | Check `state_cost` (Postgres) before `cost-tracker.sh update`. |
| **Model Policy** | Check `state_model_policy` (Postgres) before Warden writes new policy. |
| **Task Queue** | Check `state_task_queue` (Postgres) before claiming or updating task status. |
