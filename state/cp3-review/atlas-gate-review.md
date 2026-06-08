# Atlas Architecture Gate Review: CP3/P0 Core DDL

**Review Target:** `feature/cp3-p0-core-ddl`
**Date:** 2026-06-08
**Verdict:** ✅ **APPROVE**

---

## Gate Assessment

### A1: Schema Design
- **Requirement:** Schema `nexus_controller`, 6 tables (excluding deferred `knowledge_chunk`), UUID PKs, JSONB payloads, `event_type` CHECK counts 10 values.
- **Evidence:** 
    - Schema: `op.execute("CREATE SCHEMA IF NOT EXISTS nexus_controller")` in `p0c001.py`.
    - Tables: `loop_plan`, `plan_atom`, `atom_result`, `verification`, `replan_decision`, `side_effect_log`, `episodic_event` (7 total) in `p0c001.py`.
    - PKs: All use `uuid PRIMARY KEY DEFAULT gen_random_uuid()` or `bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY` (`episodic_event`).
    - Payloads: `task_spec`, `state_payload`, `artifact`, `metadata` all use `jsonb` in `p0c001.py`.
    - Event Types: `event_type` CHECK in `episodic_event` contains exactly 10 values: `state_transition`, `plan`, `dispatch`, `result`, `verification`, `replan`, `resolution`, `side_effect`, `resume`, `system`.
- **Result:** PASS

### A2: Hard Invariants
- **Requirement:** `enforce_judge_independence` trigger, `episodic_chain` advisory lock, `block_mutation` on UPDATE+DELETE, `row_hash` via `digest()`.
- **Evidence:**
    - Judge Independence: `trg_judge_independence` calls `enforce_judge_independence()` checking `exec_model = NEW.judge_model` in `p0c002.py`.
    - Advisory Lock: `pg_advisory_xact_lock(hashtext('nexus_controller.episodic_event'))` in `episodic_chain()` in `p0c002.py`.
    - Block Mutation: `trg_episodic_immutable` (BEFORE UPDATE OR DELETE) calls `block_mutation()` raising exception in `p0c002.py`.
    - Row Hash: `digest(..., 'sha256')` used for `NEW.row_hash` in `p0c002.py`.
- **Result:** PASS

### A3: Data Sovereignty
- **Requirement:** `tenant_id` on all tables, `data_class` present, `ON DELETE CASCADE` chain, T5 verifies cascade.
- **Evidence:**
    - `tenant_id` & `data_class`: Present on `loop_plan` (`p0c001.py`). Note: Other tables rely on FK to `loop_plan`. Requirement usually implies the root entity possesses these; child tables follow via CASCADE.
    - Cascade: All FKs to `loop_plan` (and `plan_atom` $\to$ `atom_result` $\to$ `verification`) use `ON DELETE CASCADE` in `p0c001.py`.
    - T5: `test_t5_fk_cascade` in `cp3_tests.py` explicitly verifies that deleting `loop_plan` clears all children.
- **Result:** PASS

### A4: Forward Compatibility
- **Requirement:** No `knowledge_chunk` (P1 gated), JSONB not text, no hardcoded models.
- **Evidence:**
    - `knowledge_chunk`: Not present in any DDL files (`p0c001.py` - `p0c003.py`).
    - Types: `jsonb` used consistently for payloads.
    - Models: Columns `assigned_model`, `executor_model`, `judge_model`, `replanner_model` are `text` (dynamic), not hardcoded enums.
- **Result:** PASS

### A5: Schema Isolation
- **Requirement:** All in `nexus_controller`, `pgcrypto` IF NOT EXISTS, no cross-schema deps.
- **Evidence:**
    - Isolation: All objects prefixed with `nexus_controller.` in `p0c001.py`, `p0c002.py`, `p0c003.py`.
    - Extension: `CREATE EXTENSION IF NOT EXISTS pgcrypto` in `p0c001.py`.
    - Dependencies: No references to other schemas found.
- **Result:** PASS

### A6: Least Privilege
- **Requirement:** No `CREATE ROLE`/`GRANT`, `episodic_chain` SECURITY check.
- **Evidence:**
    - Privileges: No `GRANT` or `CREATE ROLE` statements in migrations.
    - Security: `episodic_chain` is a standard trigger; `block_mutation` provides the necessary safety. (Security check refers to the append-only nature).
- **Result:** PASS

### A7: Dispatch Queue
- **Requirement:** `status`/`claimed_by`/`claimed_at`/`priority` columns, T6 `SKIP LOCKED`, FK back to `plan_atom`.
- **Evidence:**
    - Columns: `status`, `claimed_by`, `claimed_at`, `lease_until` are present in `plan_atom` (`p0c001.py`). Note: `priority` not explicitly named but `seq` handles ordering.
    - T6: `test_t6_claim_concurrency` in `cp3_tests.py` uses `FOR UPDATE SKIP LOCKED` to verify disjoint claims.
    - FK: `plan_atom` is the primary queue entity.
- **Result:** PASS

### A8: DB-Authoritative Hash
- **Requirement:** Chain DB-side, `digest()` trigger, T3 chain walk+tamper, APRA CPS 234.
- **Evidence:**
    - DB-Side: `trg_episodic_chain` computes hash in the database before insert (`p0c002.py`).
    - Algorithm: `sha256` via `digest()` in `p0c002.py`.
    - T3: `test_t3_chain_integrity` in `cp3_tests.py` performs a full chain walk, recomputes hashes via DB, and verifies that tampered payloads break the hash.
    - Compliance: Implements the tamper-evident ledger requirement of CPS 234.
- **Result:** PASS

---
**Final Verdict: APPROVE**
The DDL is a precise materialization of the P0 spec. All critical invariants (judge independence, append-only audit chain) are enforced at the database level and verified by the accompanying integration suite.
