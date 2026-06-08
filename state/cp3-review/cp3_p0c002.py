"""002 — functions and triggers.

Implements CP3-P0-DDL-v0.2 §4 exactly:
  - touch_updated_at        (loop_plan, plan_atom)
  - enforce_judge_independence  (verification BEFORE INSERT)
  - episodic_chain          (episodic_event BEFORE INSERT — advisory-lock serialised)
  - block_mutation          (episodic_event BEFORE UPDATE OR DELETE — append-only)

Revision ID: p0c002
Revises: p0c001
Create Date: 2026-06-08
"""
from typing import Sequence, Union

from alembic import op

revision: str = "p0c002"
down_revision: Union[str, None] = "p0c001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ------------------------------------------------------------------
    # 4.1  updated_at bump
    # ------------------------------------------------------------------
    op.execute("""
CREATE OR REPLACE FUNCTION nexus_controller.touch_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
""")

    op.execute("""
CREATE TRIGGER trg_loop_plan_touch
  BEFORE UPDATE ON nexus_controller.loop_plan
  FOR EACH ROW EXECUTE FUNCTION nexus_controller.touch_updated_at()
""")

    op.execute("""
CREATE TRIGGER trg_plan_atom_touch
  BEFORE UPDATE ON nexus_controller.plan_atom
  FOR EACH ROW EXECUTE FUNCTION nexus_controller.touch_updated_at()
""")

    # ------------------------------------------------------------------
    # 4.2  judge != executor independence (NHEA §6.1)
    # ------------------------------------------------------------------
    op.execute("""
CREATE OR REPLACE FUNCTION nexus_controller.enforce_judge_independence()
RETURNS trigger AS $$
DECLARE
  exec_model text;
BEGIN
  SELECT executor_model INTO exec_model
    FROM nexus_controller.atom_result
   WHERE id = NEW.atom_result_id;

  IF exec_model = NEW.judge_model THEN
    RAISE EXCEPTION
      'judge_model (%) must differ from executor_model (%) — independence',
      NEW.judge_model, exec_model;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
""")

    op.execute("""
CREATE TRIGGER trg_judge_independence
  BEFORE INSERT ON nexus_controller.verification
  FOR EACH ROW EXECUTE FUNCTION nexus_controller.enforce_judge_independence()
""")

    # ------------------------------------------------------------------
    # 4.3  episodic hash chain (tamper-evident, DB-authoritative)
    #
    # Advisory lock serialises concurrent appends so the chain stays
    # linear regardless of concurrency (single-writer at P0; the lock
    # makes correctness unconditional).
    #
    # Hash input: coalesce(loop_id::text,'') | event_type | payload::text
    #             | created_at::text | coalesce(prev_hash,'')
    # ------------------------------------------------------------------
    op.execute("""
CREATE OR REPLACE FUNCTION nexus_controller.episodic_chain()
RETURNS trigger AS $$
DECLARE
  last_hash text;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('nexus_controller.episodic_event'));

  SELECT row_hash INTO last_hash
    FROM nexus_controller.episodic_event
   ORDER BY event_seq DESC
   LIMIT 1;

  NEW.prev_hash := last_hash;   -- NULL for the first event
  NEW.row_hash  := encode(
    digest(
      coalesce(NEW.loop_id::text, '') || '|' ||
      NEW.event_type                  || '|' ||
      NEW.payload::text               || '|' ||
      NEW.created_at::text            || '|' ||
      coalesce(last_hash, ''),
      'sha256'
    ),
    'hex'
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
""")

    op.execute("""
CREATE TRIGGER trg_episodic_chain
  BEFORE INSERT ON nexus_controller.episodic_event
  FOR EACH ROW EXECUTE FUNCTION nexus_controller.episodic_chain()
""")

    # ------------------------------------------------------------------
    # 4.4  append-only enforcement
    # Defense in depth: trigger + recommended REVOKE at deploy time
    # (see §4 note in spec — app role REVOKE is an ops step, not DDL here).
    # ------------------------------------------------------------------
    op.execute("""
CREATE OR REPLACE FUNCTION nexus_controller.block_mutation()
RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'nexus_controller.episodic_event is append-only';
END;
$$ LANGUAGE plpgsql
""")

    op.execute("""
CREATE TRIGGER trg_episodic_immutable
  BEFORE UPDATE OR DELETE ON nexus_controller.episodic_event
  FOR EACH ROW EXECUTE FUNCTION nexus_controller.block_mutation()
""")


def downgrade() -> None:
    # Drop triggers before functions (triggers depend on functions).
    op.execute("DROP TRIGGER IF EXISTS trg_episodic_immutable  ON nexus_controller.episodic_event")
    op.execute("DROP TRIGGER IF EXISTS trg_episodic_chain      ON nexus_controller.episodic_event")
    op.execute("DROP TRIGGER IF EXISTS trg_judge_independence  ON nexus_controller.verification")
    op.execute("DROP TRIGGER IF EXISTS trg_plan_atom_touch     ON nexus_controller.plan_atom")
    op.execute("DROP TRIGGER IF EXISTS trg_loop_plan_touch     ON nexus_controller.loop_plan")

    op.execute("DROP FUNCTION IF EXISTS nexus_controller.block_mutation()")
    op.execute("DROP FUNCTION IF EXISTS nexus_controller.episodic_chain()")
    op.execute("DROP FUNCTION IF EXISTS nexus_controller.enforce_judge_independence()")
    op.execute("DROP FUNCTION IF EXISTS nexus_controller.touch_updated_at()")
