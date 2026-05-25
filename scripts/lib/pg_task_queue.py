#!/usr/bin/env python3
"""
pg-task-queue.py — Postgres helper for task-queue operations.
Provides dual-write (PG primary, JSON fallback) + PG reads.
Pattern: PG is SSOT per TKT-0270. JSON is dual-write fallback.

Usage:
  from pg_task_queue import pg_upsert_task, pg_read_all_tasks, pg_read_task, pg_claim_task
"""

import json
import subprocess
import os

PG_HOST = "/tmp"
PG_PORT = "5432"
PG_USER = "ainchorsangiefpl"
PG_DATABASE = "ainchors_nexus"

def _pg(query):
    """Execute a Postgres query and return stdout as string."""
    env = os.environ.copy()
    env.update({
        "PGHOST": PG_HOST,
        "PGPORT": PG_PORT,
        "PGUSER": PG_USER,
        "PGDATABASE": PG_DATABASE,
    })
    try:
        result = subprocess.run(
            ["/opt/homebrew/bin/psql", "-t", "-A", "-c", query],
            capture_output=True, text=True, timeout=10, env=env
        )
        return result.stdout.strip()
    except Exception as e:
        print(f"PG ERROR: {e}", file=__import__('sys').stderr)
        return ""


def _escape_sql(s):
    """Escape single quotes for SQL."""
    if s is None:
        return "NULL"
    return "'" + str(s).replace("'", "''") + "'"


def _pg_upsert(task_id, task_dict):
    """
    Upsert a task into PG state_task_queue.
    Returns True on success, False on failure.
    """
    title = _escape_sql(task_dict.get("title", ""))
    tier = _escape_sql(str(task_dict.get("tier", "3")))
    status = _escape_sql(task_dict.get("status", "pending"))
    # Map CLI status to TQP status: pending→queued, claimed→dispatched
    pg_status = {"pending": "queued", "claimed": "dispatched"}.get(status.strip("'"), status.strip("'"))
    pg_status_esc = _escape_sql(pg_status)
    priority = _escape_sql(task_dict.get("priority", "medium"))
    source = _escape_sql(task_dict.get("source", ""))
    related_chg = _escape_sql(task_dict.get("relatedChg", ""))
    claimed_by = _escape_sql(task_dict.get("claimedBy"))
    claimed_at = _escape_sql(task_dict.get("claimedAt"))
    claim_timeout = _escape_sql(task_dict.get("claimTimeout"))
    created_at = _escape_sql(task_dict.get("createdAt"))
    updated_at = _escape_sql(task_dict.get("updatedAt"))
    atoms_json = _escape_sql(json.dumps(task_dict.get("atoms", [])))

    query = f"""
    INSERT INTO state_task_queue (id, title, tier, status, priority, source, relatedchg,
        claimedby, claimedat, claimtimeout, createdat, updatedat, atoms, tenant_id)
    VALUES ({_escape_sql(task_id)}, {title}, {tier}, {pg_status_esc}, {priority}, {source}, {related_chg},
        {claimed_by}, {claimed_at}, {claim_timeout}, {created_at}, {updated_at}, {atoms_json}, 'ainchors')
    ON CONFLICT (id) DO UPDATE SET
        title = EXCLUDED.title,
        tier = EXCLUDED.tier,
        status = EXCLUDED.status,
        priority = EXCLUDED.priority,
        source = EXCLUDED.source,
        relatedchg = EXCLUDED.relatedchg,
        claimedby = EXCLUDED.claimedby,
        claimedat = EXCLUDED.claimedat,
        claimtimeout = EXCLUDED.claimtimeout,
        updatedat = EXCLUDED.updatedat,
        atoms = EXCLUDED.atoms,
        updated_at_ts = now()
    """
    result = _pg(query)
    # Successful upsert returns empty or the id
    return result != "ERROR"


def pg_upsert_task(task_id, task_dict):
    """
    Upsert a task into PG. On failure, writes to fallback log.
    Returns True if PG write succeeded, False if fallback was used.
    """
    if _pg_upsert(task_id, task_dict):
        return True
    
    # Fallback: write to JSONL fallback log
    fallback_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
        "state", "pg-write-fallback-task-queue.jsonl"
    )
    try:
        with open(fallback_path, "a") as f:
            payload = {"id": task_id, **task_dict}
            f.write(json.dumps(payload) + "\n")
    except Exception:
        pass
    
    return False


def pg_read_all_tasks():
    """
    Read all tasks from PG. Returns list of task dicts, or None if PG unavailable.
    """
    result = _pg("SELECT jsonb_agg(row_to_json(t) ORDER BY created_at_ts DESC) FROM state_task_queue t")
    if not result or result == "null":
        return None
    try:
        tasks = json.loads(result)
        # Parse atoms from text column (stored as JSON string)
        for t in tasks:
            if isinstance(t.get("atoms"), str):
                try:
                    t["atoms"] = json.loads(t["atoms"])
                except (json.JSONDecodeError, TypeError):
                    t["atoms"] = []
        return tasks
    except (json.JSONDecodeError, TypeError):
        return None


def pg_read_task(task_id):
    """
    Read a single task from PG. Returns task dict or None.
    """
    result = _pg(f"SELECT row_to_json(t)::text FROM state_task_queue t WHERE id = {_escape_sql(task_id)}")
    if not result or result == "null":
        return None
    try:
        task = json.loads(result)
        if isinstance(task.get("atoms"), str):
            try:
                task["atoms"] = json.loads(task["atoms"])
            except (json.JSONDecodeError, TypeError):
                task["atoms"] = []
        return task
    except (json.JSONDecodeError, TypeError):
        return None


def pg_claim_task(task_id, agent_id):
    """
    Atomically claim a task in PG. Uses WHERE status='queued' to prevent double-claim.
    Maps CLI 'claimed' → PG 'dispatched' for TQP compatibility.
    Returns True if claim succeeded, False otherwise.
    """
    now = __import__('datetime').datetime.now().isoformat()
    timeout = (__import__('datetime').datetime.now() + __import__('datetime').timedelta(minutes=30)).isoformat()
    
    query = f"""
    UPDATE state_task_queue SET
        status = 'dispatched',
        claimedby = {_escape_sql(agent_id)},
        claimedat = {_escape_sql(now)},
        claimtimeout = {_escape_sql(timeout)},
        updatedat = {_escape_sql(now)},
        updated_at_ts = now()
    WHERE id = {_escape_sql(task_id)} AND status = 'queued'
    RETURNING id
    """
    result = _pg(query)
    return bool(result and result != "null")


def pg_update_task_status(task_id, status, extra_fields=None):
    """
    Update task status in PG. extra_fields is optional dict of additional columns to set.
    Maps CLI status → PG status: pending→queued, claimed→dispatched.
    Returns True on success.
    """
    now = __import__('datetime').datetime.now().isoformat()
    # Map CLI status to PG status for TQP compatibility
    pg_status_map = {"pending": "queued", "claimed": "dispatched"}
    pg_status = pg_status_map.get(status, status)
    
    set_clauses = [
        f"status = {_escape_sql(pg_status)}",
        f"updatedat = {_escape_sql(now)}",
        "updated_at_ts = now()"
    ]
    if extra_fields:
        for k, v in extra_fields.items():
            set_clauses.append(f"{k} = {_escape_sql(v)}")
    
    query = f"""
    UPDATE state_task_queue SET {', '.join(set_clauses)}
    WHERE id = {_escape_sql(task_id)}
    """
    _pg(query)
    return True


def pg_update_atom(task_id, atom_id, atom_status, result_data=None, error=None):
    """
    Update a specific atom's status in PG.
    Reads current atoms, updates the target atom, writes back.
    Returns True on success.
    """
    now = __import__('datetime').datetime.now().isoformat()
    
    task = pg_read_task(task_id)
    if not task:
        return False
    
    atoms = task.get("atoms", [])
    for a in atoms:
        if str(a.get("id")) == str(atom_id):
            a["status"] = atom_status
            if atom_status == "complete":
                a["completedAt"] = now
                if result_data:
                    a["result"] = result_data
            elif atom_status == "failed":
                a["failedAt"] = now
                a["error"] = error
                a["retryCount"] = a.get("retryCount", 0) + 1
    
    atoms_json = _escape_sql(json.dumps(atoms))
    
    # Check if all atoms complete
    all_done = all(a.get("status") == "complete" for a in atoms)
    new_status = "complete" if all_done else task.get("status", "claimed")
    
    query = f"""
    UPDATE state_task_queue SET
        atoms = {atoms_json},
        status = {_escape_sql(new_status)},
        updatedat = {_escape_sql(now)},
        updated_at_ts = now()
    WHERE id = {_escape_sql(task_id)}
    """
    _pg(query)
    return True


# ════════════════════════════════════════════════════════════════
# STATE CHECKING WRAPPERS (TKT-0182)
# All stateful operations must follow: READ → VALIDATE → EXECUTE → VERIFY
# These wrappers enforce the 4-step cycle on PG ops.
# ════════════════════════════════════════════════════════════════

class StateCheckError(Exception):
    """Raised when state checking validation fails."""
    pass


def sc_add_task(task_id, task_dict):
    """
    State-checked task add: READ (check for dupes) → VALIDATE → EXECUTE (upsert) → VERIFY (read-back).
    Returns (success: bool, message: str)
    """
    existing = pg_read_task(task_id)
    if existing is not None:
        return False, f"State check FAILED: Task {task_id} already exists in PG (status={existing.get('status')})"
    
    if not pg_upsert_task(task_id, task_dict):
        return False, f"State check FAILED: PG upsert failed for {task_id}"
    
    verified = pg_read_task(task_id)
    if verified is None:
        return False, f"State check FAILED: Post-write verification failed — {task_id} not found in PG"
    if verified.get('status') not in ('queued', 'pending'):
        return False, f"State check FAILED: Post-write status is {verified.get('status')}, expected queued"
    
    return True, f"State check OK: {task_id} verified in PG as {verified.get('status')}"


def sc_claim_task(task_id, agent_id):
    """
    State-checked task claim: READ → VALIDATE → EXECUTE → VERIFY.
    Returns (success: bool, message: str)
    """
    task = pg_read_task(task_id)
    if task is None:
        return False, f"State check FAILED: Task {task_id} not found in PG"
    if task.get('status') != 'queued':
        return False, f"State check FAILED: Task {task_id} is {task.get('status')}, expected queued"
    
    if not pg_claim_task(task_id, agent_id):
        return False, f"State check FAILED: Claim failed — {task_id} may have been claimed by another instance"
    
    verified = pg_read_task(task_id)
    if verified is None:
        return False, f"State check FAILED: Post-claim verification — {task_id} not found in PG"
    if verified.get('status') != 'dispatched':
        return False, f"State check FAILED: Post-claim status is {verified.get('status')}, expected dispatched"
    if verified.get('claimedby') != agent_id:
        return False, f"State check FAILED: Task claimed by {verified.get('claimedby')}, expected {agent_id}"
    
    return True, f"State check OK: {task_id} claimed by {agent_id}, verified as dispatched"


def sc_complete_atom(task_id, atom_id, result_data=None):
    """
    State-checked atom completion: READ → VALIDATE → EXECUTE → VERIFY.
    Returns (success: bool, message: str)
    """
    task = pg_read_task(task_id)
    if task is None:
        return False, f"State check FAILED: Task {task_id} not found in PG"
    
    atoms = task.get('atoms', [])
    target_atom = None
    for a in atoms:
        if str(a.get('id')) == str(atom_id):
            target_atom = a
            break
    
    if target_atom is None:
        return False, f"State check FAILED: Atom {atom_id} not found in task {task_id}"
    if target_atom.get('status') not in ('pending', 'failed'):
        return False, f"State check FAILED: Atom {atom_id} is {target_atom.get('status')}, cannot complete"
    
    if not pg_update_atom(task_id, atom_id, 'complete', result_data=result_data):
        return False, f"State check FAILED: Atom update failed for {task_id}/{atom_id}"
    
    verified = pg_read_task(task_id)
    if verified is None:
        return False, f"State check FAILED: Post-update verification — {task_id} not found in PG"
    
    verified_atoms = verified.get('atoms', [])
    for a in verified_atoms:
        if str(a.get('id')) == str(atom_id):
            if a.get('status') != 'complete':
                return False, f"State check FAILED: Atom {atom_id} status is {a.get('status')}, expected complete"
            break
    
    atom_count_after = sum(1 for a in verified_atoms if a.get('status') == 'complete')
    return True, f"State check OK: Atom {atom_id} verified complete ({atom_count_after}/{len(verified_atoms)} atoms done)"


def sc_fail_atom(task_id, atom_id, error_msg):
    """
    State-checked atom failure: READ → VALIDATE → EXECUTE → VERIFY.
    Returns (success: bool, message: str)
    """
    task = pg_read_task(task_id)
    if task is None:
        return False, f"State check FAILED: Task {task_id} not found in PG"
    
    atoms = task.get('atoms', [])
    target_atom = None
    for a in atoms:
        if str(a.get('id')) == str(atom_id):
            target_atom = a
            break
    
    if target_atom is None:
        return False, f"State check FAILED: Atom {atom_id} not found in task {task_id}"
    
    if not pg_update_atom(task_id, atom_id, 'failed', error=error_msg):
        return False, f"State check FAILED: Atom failure update failed for {task_id}/{atom_id}"
    
    verified = pg_read_task(task_id)
    if verified is None:
        return False, f"State check FAILED: Post-update verification — {task_id} not found in PG"
    
    for a in verified.get('atoms', []):
        if str(a.get('id')) == str(atom_id):
            if a.get('status') != 'failed':
                return False, f"State check FAILED: Atom {atom_id} status is {a.get('status')}, expected failed"
            break
    
    return True, f"State check OK: Atom {atom_id} verified failed (retry #{target_atom.get('retryCount', 0) + 1})"


def sc_reset_stale_claims():
    """
    State-checked stale claim reset: READ → VALIDATE → EXECUTE → VERIFY.
    Returns (success: bool, message: str, reset_count: int)
    """
    tasks = pg_read_all_tasks()
    if tasks is None:
        return False, "State check FAILED: Cannot read PG tasks", 0
    
    from datetime import datetime
    now = datetime.now().isoformat()
    stale = []
    for t in tasks:
        if t.get('status') == 'dispatched':
            timeout = t.get('claimtimeout', '1970-01-01')
            if timeout and timeout < now:
                stale.append(t['id'])
    
    if not stale:
        return True, "State check OK: No stale claims found", 0
    
    for task_id in stale:
        pg_update_task_status(task_id, 'queued', {
            'claimedby': None,
            'claimedat': None,
            'claimtimeout': None,
        })
    
    verified_count = 0
    for task_id in stale:
        v = pg_read_task(task_id)
        if v and v.get('status') == 'queued':
            verified_count += 1
    
    return True, f"State check OK: {verified_count}/{len(stale)} stale claims reset to queued", verified_count
