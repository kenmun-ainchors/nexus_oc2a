"""003 — indexes: all P0 supporting indexes.

Implements CP3-P0-DDL-v0.2 §5 exactly (12 indexes).

Revision ID: p0c003
Revises: p0c002
Create Date: 2026-06-08
"""
from typing import Sequence, Union

from alembic import op

revision: str = "p0c003"
down_revision: Union[str, None] = "p0c002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # plan_atom
    op.execute("""
CREATE INDEX idx_plan_atom_loop_status
  ON nexus_controller.plan_atom (loop_id, status)
""")
    op.execute("""
CREATE INDEX idx_plan_atom_lease
  ON nexus_controller.plan_atom (status, lease_until)
  WHERE status = 'running'
""")
    op.execute("""
CREATE INDEX idx_plan_atom_deps_gin
  ON nexus_controller.plan_atom
  USING gin (dependencies)
""")

    # loop_plan
    op.execute("""
CREATE INDEX idx_loop_plan_active
  ON nexus_controller.loop_plan (status)
  WHERE status NOT IN ('done','failed')
""")
    op.execute("""
CREATE INDEX idx_loop_plan_tenant
  ON nexus_controller.loop_plan (tenant_id, data_class)
""")

    # atom_result
    op.execute("""
CREATE INDEX idx_atom_result_atom
  ON nexus_controller.atom_result (atom_id)
""")
    op.execute("""
CREATE INDEX idx_atom_result_loop
  ON nexus_controller.atom_result (loop_id)
""")

    # verification
    op.execute("""
CREATE INDEX idx_verification_atom
  ON nexus_controller.verification (atom_id)
""")
    op.execute("""
CREATE INDEX idx_verification_loop
  ON nexus_controller.verification (loop_id)
""")

    # replan_decision
    op.execute("""
CREATE INDEX idx_replan_loop
  ON nexus_controller.replan_decision (loop_id)
""")

    # side_effect_log
    op.execute("""
CREATE INDEX idx_side_effect_atom
  ON nexus_controller.side_effect_log (atom_id)
""")

    # episodic_event
    op.execute("""
CREATE INDEX idx_episodic_loop
  ON nexus_controller.episodic_event (loop_id)
""")


def downgrade() -> None:
    # Drop in reverse creation order (no strict dependency, but mirrors upgrade).
    op.execute("DROP INDEX IF EXISTS nexus_controller.idx_episodic_loop")
    op.execute("DROP INDEX IF EXISTS nexus_controller.idx_side_effect_atom")
    op.execute("DROP INDEX IF EXISTS nexus_controller.idx_replan_loop")
    op.execute("DROP INDEX IF EXISTS nexus_controller.idx_verification_loop")
    op.execute("DROP INDEX IF EXISTS nexus_controller.idx_verification_atom")
    op.execute("DROP INDEX IF EXISTS nexus_controller.idx_atom_result_loop")
    op.execute("DROP INDEX IF EXISTS nexus_controller.idx_atom_result_atom")
    op.execute("DROP INDEX IF EXISTS nexus_controller.idx_loop_plan_tenant")
    op.execute("DROP INDEX IF EXISTS nexus_controller.idx_loop_plan_active")
    op.execute("DROP INDEX IF EXISTS nexus_controller.idx_plan_atom_deps_gin")
    op.execute("DROP INDEX IF EXISTS nexus_controller.idx_plan_atom_lease")
    op.execute("DROP INDEX IF EXISTS nexus_controller.idx_plan_atom_loop_status")
