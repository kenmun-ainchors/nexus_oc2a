# Yoda Inline TQP Contract v1.0
**Document ID:** TKT-0309-PH2-CONTRACT-v1.0
**Status:** DRAFT FOR REVIEW
**Date:** 2026-05-27
**Author:** Yoda
**Parent:** TKT-0309 Phase 2 — Yoda Inline Adoption

## 1. Purpose

This contract defines the persistence discipline for Yoda's inline execution atoms.
Every atom Yoda executes in webchat/Telegram sessions MUST be gated through
`sc_persist_atom()` before advancing to the next atom. This eliminates the
"hydration void" where Yoda's progress is held only in volatile session context.

## 2. What Gets Persisted

| Field | Source | Example |
|-------|--------|---------|
| `task_id` | TKT-NNNN | `TKT-0309` |
| `atom_index` | Sequential (0-based) | `0` (Atom A1), `1` (Atom A2) |
| `state_payload` | JSONB — atom output summary | `{"deliverable": "docs/.../contract-v1.0.md", "status": "complete", "verification": "file written + CHG logged"}` |
| `execution_context` | JSONB — session snapshot | `{"model": "deepseek-v4-pro", "session_key": "webchat-main", "channel": "webchat", "plan_id": "TKT-0309-PH2", "plan_atoms_total": 5}` |
| `persistence_type` | Enum | `INLINE_ATOM` |
| `parent_task_id` | NULL for top-level atoms | `TKT-0309` (only if nested sub-agent) |

## 3. Execution Sequence (Non-Negotiable)

```
1. Plan atoms → announce to Ken
2. Execute Atom[N]
3. Call sc_persist_atom(task_id, N, state_payload, execution_context)
4. Verify return: (True, "State check OK...")
5. Announce "Atom N complete ✅" to Ken
6. Proceed to Atom[N+1] only after gate passes
```

**Failure mode:** If `sc_persist_atom` returns `False`, the atom does NOT advance.
Yoda MUST surface the error to Ken and retry the persist, not skip it.

## 4. Resumption Protocol

On session restart, model switch, or after `sessions_yield`:

```
1. Identify current TKT from session context or Ken
2. Call sc_resume_context(task_id)
3. If resume_data.last_atom_index is not None:
   a. Load state_payload as "Last Known State"
   b. Start at atom_index + 1
   c. Announce: "Resuming TKT-XXXX from Atom N. Last: [summary]. Proceeding to Atom N+1."
4. If no resume data: start fresh plan
```

## 5. When to Persist

| Scenario | Persist? | Notes |
|----------|----------|-------|
| Yoda executes planned atom | ✅ REQUIRED | Gate before advancing |
| Yoda reports to Ken (no atom) | ❌ Skip | Pure reporting has no atom to track |
| Yoda spawns sub-agent | ✅ REQUIRED | Persist atom + link parent_task_id |
| Heartbeat check | ❌ Skip | Not an execution atom |
| Ken asks a question / Yoda answers | ❌ Skip | Conversational, not an atom |
| Yoda does research/reads files | ✅ REQUIRED | If part of a planned atom |

## 6. state_payload Schema (JSONB)

```json
{
  "atom_id": "A1",
  "description": "Define Yoda's inline TQP contract",
  "status": "complete",
  "deliverable": "docs/deliverables/TKT-0309-Yoda-Inline-TQP-Contract-v1.0.md",
  "verification": "File written, reviewed by Ken",
  "output_summary": "Contract defining Yoda's TQP persistence discipline",
  "chg_ref": "CHG-XXXX",
  "completed_at": "2026-05-27T18:30:00+10:00"
}
```

## 7. execution_context Schema (JSONB)

```json
{
  "model": "ollama/deepseek-v4-pro:cloud",
  "channel": "webchat",
  "session_key": "main",
  "plan_id": "TKT-0309-PH2",
  "total_atoms": 5,
  "atom_labels": ["A1: Contract", "A2: Wrapper", "A3: AGENTS.md", "A4: Self-test", "A5: DoD"],
  "started_at": "2026-05-27T18:27:00+10:00"
}
```

## 8. Verification

- [ ] Contract doc written
- [ ] Ken reviewed and approved
- [ ] CHG logged
- [ ] Registered in Holocron
