# Nexus Platform Architecture: Unified Work-State Persistence (TQP Extension)
**APPROVED**
**Document ID:** PA_TQP_DRAFT_v1.0_2026-05-26
**Ticket:** TKT-0309
**Architect:** Thrawn

## 1. Context and Scope
The goal is to transition the `state_task_queue` (TQP) in PostgreSQL from a specialized queue for crons and sub-agents into a unified stateful execution ledger for all Nexus platform work. This eliminates ephemeral state loss during model drift, session compaction, or restarts.

**Scope:**
- **Phase 1:** Yoda inline atoms (Plan persistence).
- **Phase 2:** Aria business tasks.
- **Phase 3:** All 14 Nexus agents.
- **Constraint:** PG is the Single Source of Truth (SSOT). All interactions must use existing `db-read.sh`/`db-write.sh` or `pg_task_queue.py` wrappers.

---

## 2. TQP Schema Extension (Design)
The current `state_task_queue` is optimized for "claim-execute-complete". To support "atomic-progress-tracking" for complex plans, the following extensions are required:

- **`parent_task_id` (UUID/FK):** To support nested sub-agents and grouping of atoms under a single high-level Ticket/Plan.
- **`execution_context` (JSONB):** Stores the "snapshot" of the session (model version, key variables, current plan index) to allow seamless resumption.
- **`atom_index` (INT):** Tracks the sequence number (e.g., "Atom 2 of 5").
- **`state_payload` (JSONB):** Captures the actual output or state transition of the atom, allowing the next model to "read the trail" without re-running.
- **`persistence_type` (ENUM):** `CRON`, `SUBAGENT`, `INLINE_ATOM`, `BUSINESS_TASK`.

---

## 3. TQP as Execution Gate (The "Write" Flow)
To eliminate fragility caused by volatile session contexts and model drift, the platform shifts from "tracking" to "gating." The database (PG) is the authoritative gatekeeper for progress.

- **Logic:** No atom is considered complete—and the agent cannot announce its completion—until the state is committed to PG.
- **Mechanism:**
    1. **Hard Dependency:** The agent MUST call `sc_complete_atom` (via `pg_task_queue.py`) as a prerequisite for advancing the plan.
    2. **Sequence:** `Execute Atom` → `Write Result to TQP` → `Confirm Write Success` → `Announce "Atom X/Y Done"`.
    3. **Failure Mode:** If the PG write fails, the atom does not advance. The error is surfaced immediately, and the agent is blocked from proceeding to the next step.
- **Sync Point:** The write is an atomic commit. This ensures that the "trail" in TQP is never lagging behind the agent's perceived progress, removing the risk of state loss during compaction.

---

## 4. Auto-Resume Protocol (The "Read" Flow)
On session startup, model switch, or recovery from a crash:

1. **Identity Check:** The agent identifies its current TKT and role.
2. **TQP Query:** Call `sc_read` (or a specialized `get_last_stable_state`) to find the latest `completed` atom for that TKT.
3. **Context Reconstitution:** 
    - Load the `execution_context` from the last successful TQP entry.
    - Inject the `state_payload` of the previous atom into the system prompt as "Last Known State."
4. **Resumption:** The agent starts at `atom_index + 1`.
5. **Validation:** The agent confirms with the user: *"Resuming TKT-XXXX from Atom [N]. Current state: [Brief Summary]. Proceeding to Atom [N+1]."*

---

## 5. Edge Case Analysis
- **Nested Sub-agents:** Managed via `parent_task_id`. A child's completion triggers a state update in the parent's TQP entry.
- **Multi-session Work:** TQP uses TKT as the primary key, meaning different sessions can attach to the same work-stream.
- **Partial Atom Completion:** If an atom is "started" but not "completed" (crash), the auto-resume protocol treats it as `failed` or `pending` and re-triggers based on the `sc_reset` logic.
- **Plan Mutation:** If a human changes the plan mid-stream, the agent must call `sc_reset` on all subsequent atoms in that TQP chain to prevent stale resumption.

---

## 6. Implementation Phases

### Phase 1: Yoda Inline Work
- Extend schema with `atom_index` and `state_payload`.
- Implement `sc_complete_atom` as the mandatory execution gate for inline atoms.
- Enable recovery for Yoda's internal planning.

### Phase 2: Aria Business Tasks
- Map Aria's task-completion events to TQP entries.
- Integrate `execution_context` for business-process state (e.g., "Awaiting Approval").

### Phase 3: Global Agent Integration
- Standardize `db-read.sh`/`db-write.sh` wrappers for all 14 agents.
- Full rollout of the Auto-Resume Protocol across all Nexus roles.

---

## 7. Trade-off Analysis
| Alternative | Pros | Cons | Verdict |
| :--- | :--- | :--- | :--- |
| **Local JSON Cache** | Fast, simple | Ephemeral, risk of desync, not shared | Rejected |
| **Full State Mirroring** | Perfect recovery | High PG load, massive storage overhead | Rejected |
| **TQP Ledger (Chosen)** | Reliable, audit-ready, leverages existing `sc_*` logic | Slightly higher latency on writes | **Recommended** |

---

## 8. Risks & Mitigation
- **Risk:** DB bottleneck during high-frequency atom updates.
- **Mitigation:** Use JSONB for payloads to minimize schema migrations; optimize `sc_read` indices.
- **Risk:** "State Bloat" where the execution context becomes too large for the model window.
- **Mitigation:** Implement a "compaction" or "summarization" step every 5 atoms to distill the `state_payload`.
