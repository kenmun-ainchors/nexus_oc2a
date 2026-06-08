"""
P0 schema integration tests — T1, T2, T3, T5, T6.

Exit-gate tests for CP3-P0-DDL-v0.2.  Run after `alembic upgrade head`
against the sandbox/shadow PG (NEXUS_TEST_DB_URL or NEXUS_DB_URL).

T4 (zero-divergence vs live TQP) is operational and run by Forge post-merge.

Requires: asyncpg, pytest-asyncio (asyncio_mode = "auto" set in pyproject.toml).
"""
import asyncio
import os
import uuid

import asyncpg
import pytest

# ---------------------------------------------------------------------------
# Connection
# ---------------------------------------------------------------------------

_DB_URL: str = os.environ.get("NEXUS_TEST_DB_URL") or os.environ.get("NEXUS_DB_URL", "")

if not _DB_URL:
    pytest.skip(
        "NEXUS_TEST_DB_URL (or NEXUS_DB_URL) not set — skipping integration tests",
        allow_module_level=True,
    )


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(scope="module")
async def pool() -> asyncpg.Pool:
    """Module-scoped connection pool — created once for the full test module."""
    p = await asyncpg.create_pool(_DB_URL, min_size=2, max_size=5)
    yield p
    await p.close()


@pytest.fixture(autouse=True)
async def clean_tables(pool: asyncpg.Pool) -> None:
    """Truncate all nexus_controller tables before every test.

    TRUNCATE bypasses row triggers (including the append-only block), so
    episodic_event can be cleared for test isolation.
    Restart identity resets the event_seq sequence.
    """
    async with pool.acquire() as conn:
        await conn.execute("""
            TRUNCATE TABLE
                nexus_controller.episodic_event,
                nexus_controller.side_effect_log,
                nexus_controller.replan_decision,
                nexus_controller.verification,
                nexus_controller.atom_result,
                nexus_controller.plan_atom,
                nexus_controller.loop_plan
            RESTART IDENTITY CASCADE
        """)
    yield


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def _insert_loop_plan(
    conn: asyncpg.Connection,
    tenant_id: str = "test-tenant",
    data_class: str = "own_ops",
) -> uuid.UUID:
    return await conn.fetchval(
        """
        INSERT INTO nexus_controller.loop_plan (tenant_id, data_class, task_spec)
        VALUES ($1, $2, '{"task": "test"}')
        RETURNING id
        """,
        tenant_id,
        data_class,
    )


async def _insert_plan_atom(
    conn: asyncpg.Connection,
    loop_id: uuid.UUID,
    seq: int = 1,
) -> uuid.UUID:
    return await conn.fetchval(
        """
        INSERT INTO nexus_controller.plan_atom (loop_id, seq, task_spec)
        VALUES ($1, $2, '{"step": "test"}')
        RETURNING id
        """,
        loop_id,
        seq,
    )


async def _insert_atom_result(
    conn: asyncpg.Connection,
    atom_id: uuid.UUID,
    loop_id: uuid.UUID,
    executor_model: str = "model-a",
    attempt_no: int = 1,
) -> uuid.UUID:
    return await conn.fetchval(
        """
        INSERT INTO nexus_controller.atom_result
            (atom_id, loop_id, attempt_no, executor_model)
        VALUES ($1, $2, $3, $4)
        RETURNING id
        """,
        atom_id,
        loop_id,
        attempt_no,
        executor_model,
    )


async def _insert_verification(
    conn: asyncpg.Connection,
    atom_result_id: uuid.UUID,
    atom_id: uuid.UUID,
    loop_id: uuid.UUID,
    judge_model: str = "model-b",
) -> uuid.UUID:
    return await conn.fetchval(
        """
        INSERT INTO nexus_controller.verification
            (atom_result_id, atom_id, loop_id, judge_model, completeness, status)
        VALUES ($1, $2, $3, $4, 0.9, 'pass')
        RETURNING id
        """,
        atom_result_id,
        atom_id,
        loop_id,
        judge_model,
    )


async def _insert_episodic_event(
    conn: asyncpg.Connection,
    event_type: str = "system",
    payload: str = '{"msg": "test"}',
    loop_id: uuid.UUID | None = None,
) -> int:
    """Insert an episodic_event; trigger computes row_hash / prev_hash."""
    return await conn.fetchval(
        """
        INSERT INTO nexus_controller.episodic_event (loop_id, event_type, payload)
        VALUES ($1, $2, $3::jsonb)
        RETURNING event_seq
        """,
        loop_id,
        event_type,
        payload,
    )


# ---------------------------------------------------------------------------
# T1 — judge ≠ executor independence
# ---------------------------------------------------------------------------


async def test_t1_independence_trigger_fires(pool: asyncpg.Pool) -> None:
    """INSERT verification with judge_model == executor_model must be rejected."""
    async with pool.acquire() as conn:
        loop_id = await _insert_loop_plan(conn)
        atom_id = await _insert_plan_atom(conn, loop_id)
        result_id = await _insert_atom_result(conn, atom_id, loop_id, executor_model="model-a")

        with pytest.raises(asyncpg.exceptions.RaiseError, match="independence"):
            await conn.execute(
                """
                INSERT INTO nexus_controller.verification
                    (atom_result_id, atom_id, loop_id, judge_model, completeness, status)
                VALUES ($1, $2, $3, 'model-a', 0.9, 'pass')
                """,
                result_id,
                atom_id,
                loop_id,
            )


async def test_t1_independence_different_models_accepted(pool: asyncpg.Pool) -> None:
    """Sanity: judge_model ≠ executor_model must be accepted."""
    async with pool.acquire() as conn:
        loop_id = await _insert_loop_plan(conn)
        atom_id = await _insert_plan_atom(conn, loop_id)
        result_id = await _insert_atom_result(conn, atom_id, loop_id, executor_model="model-a")

        vid = await _insert_verification(
            conn, result_id, atom_id, loop_id, judge_model="model-b"
        )
        assert vid is not None


# ---------------------------------------------------------------------------
# T2 — episodic_event is append-only
# ---------------------------------------------------------------------------


async def test_t2_append_only_update_rejected(pool: asyncpg.Pool) -> None:
    """UPDATE on episodic_event must raise the append-only exception."""
    async with pool.acquire() as conn:
        seq = await _insert_episodic_event(conn)

        with pytest.raises(asyncpg.exceptions.RaiseError, match="append-only"):
            await conn.execute(
                "UPDATE nexus_controller.episodic_event SET event_type = 'plan' "
                "WHERE event_seq = $1",
                seq,
            )


async def test_t2_append_only_delete_rejected(pool: asyncpg.Pool) -> None:
    """DELETE on episodic_event must raise the append-only exception."""
    async with pool.acquire() as conn:
        seq = await _insert_episodic_event(conn)

        with pytest.raises(asyncpg.exceptions.RaiseError, match="append-only"):
            await conn.execute(
                "DELETE FROM nexus_controller.episodic_event WHERE event_seq = $1",
                seq,
            )


# ---------------------------------------------------------------------------
# T3 — hash chain integrity
# ---------------------------------------------------------------------------


async def test_t3_chain_integrity(pool: asyncpg.Pool) -> None:
    """Append N events; walk chain; all row_hash values match recomputation;
    prev_hash links are clean; a tampered payload breaks the computed hash.

    Hash recomputation is done via the DB (pgcrypto digest) to avoid
    Python↔PG type-cast drift in created_at::text formatting.
    """
    n_events = 6
    event_types = ["state_transition", "plan", "dispatch", "result", "verification", "replan"]

    async with pool.acquire() as conn:
        loop_id = await _insert_loop_plan(conn)

        # --- Insert N events ---
        for i, etype in enumerate(event_types):
            await _insert_episodic_event(
                conn,
                event_type=etype,
                payload=f'{{"step": {i}}}',
                loop_id=loop_id,
            )

        # --- Fetch in chain order ---
        rows = await conn.fetch("""
            SELECT event_seq, loop_id, event_type, payload, prev_hash,
                   row_hash, created_at
            FROM nexus_controller.episodic_event
            ORDER BY event_seq
        """)
        assert len(rows) == n_events

        # --- Recompute every row_hash via DB (same digest() call as the trigger) ---
        for row in rows:
            computed = await conn.fetchval(
                """
                SELECT encode(
                    digest(
                        coalesce($1::text, '') || '|' ||
                        $2                     || '|' ||
                        $3::text               || '|' ||
                        $4::text               || '|' ||
                        coalesce($5, ''),
                        'sha256'
                    ),
                    'hex'
                )
                """,
                row["loop_id"],
                row["event_type"],
                row["payload"],
                row["created_at"],
                row["prev_hash"],
            )
            assert computed == row["row_hash"], (
                f"row_hash mismatch at event_seq={row['event_seq']}: "
                f"stored={row['row_hash']} computed={computed}"
            )

        # --- prev_hash linkage: each row's prev_hash == prior row's row_hash ---
        assert rows[0]["prev_hash"] is None, "First event must have prev_hash = NULL"
        for i in range(1, len(rows)):
            assert rows[i]["prev_hash"] == rows[i - 1]["row_hash"], (
                f"Chain broken between event_seq {rows[i-1]['event_seq']} "
                f"and {rows[i]['event_seq']}"
            )

        # --- Tamper test: altered payload produces a different hash ---
        victim = rows[2]
        tampered_computed = await conn.fetchval(
            """
            SELECT encode(
                digest(
                    coalesce($1::text, '') || '|' ||
                    $2                     || '|' ||
                    $3::text               || '|' ||
                    $4::text               || '|' ||
                    coalesce($5, ''),
                    'sha256'
                ),
                'hex'
            )
            """,
            victim["loop_id"],
            victim["event_type"],
            '{"tampered": true}',    # altered payload
            victim["created_at"],
            victim["prev_hash"],
        )
        assert tampered_computed != victim["row_hash"], (
            "Tampered payload must produce a different hash (chain break)"
        )


# ---------------------------------------------------------------------------
# T5 — FK cascade: deleting loop_plan removes atoms / results / verifications
# ---------------------------------------------------------------------------


async def test_t5_fk_cascade(pool: asyncpg.Pool) -> None:
    """Deleting a loop_plan must cascade to all child tables."""
    async with pool.acquire() as conn:
        loop_id = await _insert_loop_plan(conn)
        atom_id = await _insert_plan_atom(conn, loop_id)
        result_id = await _insert_atom_result(conn, atom_id, loop_id, executor_model="model-a")
        await _insert_verification(conn, result_id, atom_id, loop_id, judge_model="model-b")

        # Verify children exist before deletion.
        assert await conn.fetchval(
            "SELECT COUNT(*) FROM nexus_controller.plan_atom WHERE loop_id = $1", loop_id
        ) == 1
        assert await conn.fetchval(
            "SELECT COUNT(*) FROM nexus_controller.atom_result WHERE loop_id = $1", loop_id
        ) == 1
        assert await conn.fetchval(
            "SELECT COUNT(*) FROM nexus_controller.verification WHERE loop_id = $1", loop_id
        ) == 1

        # Delete the parent.
        await conn.execute(
            "DELETE FROM nexus_controller.loop_plan WHERE id = $1", loop_id
        )

        # All children must be gone.
        assert await conn.fetchval(
            "SELECT COUNT(*) FROM nexus_controller.plan_atom WHERE loop_id = $1", loop_id
        ) == 0, "plan_atom rows not cascaded"
        assert await conn.fetchval(
            "SELECT COUNT(*) FROM nexus_controller.atom_result WHERE loop_id = $1", loop_id
        ) == 0, "atom_result rows not cascaded"
        assert await conn.fetchval(
            "SELECT COUNT(*) FROM nexus_controller.verification WHERE loop_id = $1", loop_id
        ) == 0, "verification rows not cascaded"


# ---------------------------------------------------------------------------
# T6 — claim concurrency: SKIP LOCKED claimers grab disjoint atoms
# ---------------------------------------------------------------------------


async def test_t6_claim_concurrency(pool: asyncpg.Pool) -> None:
    """Two concurrent SELECT … FOR UPDATE SKIP LOCKED claimers must receive
    disjoint sets of pending atoms (no double-claim).

    Each claimer acquires up to 3 atoms inside its own transaction; both
    run concurrently via asyncio tasks on separate connections.
    The union of claimed IDs must equal the full set of pending atoms
    and the intersection must be empty.
    """
    # Seed 6 pending atoms across 2 loop_plans for variety.
    async with pool.acquire() as conn:
        loop_id_1 = await _insert_loop_plan(conn, tenant_id="t1")
        loop_id_2 = await _insert_loop_plan(conn, tenant_id="t2")
        all_atom_ids: list[uuid.UUID] = []
        for seq in range(1, 4):
            all_atom_ids.append(await _insert_plan_atom(conn, loop_id_1, seq=seq))
            all_atom_ids.append(await _insert_plan_atom(conn, loop_id_2, seq=seq))

    async def claim_batch(batch_size: int = 3) -> list[uuid.UUID]:
        """Open a fresh connection, claim up to batch_size atoms, return IDs,
        then roll back (we only want to verify disjointness, not mutate state)."""
        conn = await asyncpg.connect(_DB_URL)
        try:
            await conn.execute("BEGIN")
            rows = await conn.fetch(
                """
                SELECT id FROM nexus_controller.plan_atom
                WHERE status = 'pending'
                ORDER BY created_at
                LIMIT $1
                FOR UPDATE SKIP LOCKED
                """,
                batch_size,
            )
            return [r["id"] for r in rows]
        finally:
            await conn.execute("ROLLBACK")
            await conn.close()

    # Run both claimers concurrently.
    results = await asyncio.gather(claim_batch(), claim_batch())
    set_a: set[uuid.UUID] = set(results[0])
    set_b: set[uuid.UUID] = set(results[1])

    # Disjoint: no atom claimed by both.
    overlap = set_a & set_b
    assert not overlap, f"Double-claimed atoms: {overlap}"

    # Together they cover all 6 atoms (3 per claimer).
    assert set_a | set_b == set(all_atom_ids), (
        f"Claimed {set_a | set_b} but expected {set(all_atom_ids)}"
    )
