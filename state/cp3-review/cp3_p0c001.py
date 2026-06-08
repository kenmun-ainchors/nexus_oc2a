"""001 — core tables: nexus_controller schema + 7 loop tables.

Implements CP3-P0-DDL-v0.2 §2 (conventions) and §3 (DDL) exactly.
No functions, triggers, or indexes — those follow in p0c002/p0c003.

Revision ID: p0c001
Revises: —
Create Date: 2026-06-08
"""
from typing import Sequence, Union

from alembic import op

revision: str = "p0c001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ------------------------------------------------------------------
    # Schema + extension
    # ------------------------------------------------------------------
    op.execute("CREATE SCHEMA IF NOT EXISTS nexus_controller")
    op.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")

    # ------------------------------------------------------------------
    # 3.1  loop_plan — one row per task/loop
    # ------------------------------------------------------------------
    op.execute("""
CREATE TABLE nexus_controller.loop_plan (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       text        NOT NULL,
  data_class      text        NOT NULL
                                CHECK (data_class IN ('own_ops','client')),
  task_spec       jsonb       NOT NULL,
  status          text        NOT NULL DEFAULT 'planning'
                                CHECK (status IN (
                                  'planning','executing','verifying','replanning',
                                  'synthesizing','awaiting_approval','done','failed'
                                )),
  iteration       int         NOT NULL DEFAULT 0,
  max_iterations  int         NOT NULL DEFAULT 3,
  stop_reason     text
                                CHECK (stop_reason IN (
                                  'completeness','high_conf_partial','low_improvement',
                                  'token_budget','max_iterations','failed','hard_block'
                                )),
  token_budget    bigint,
  tokens_used     bigint      NOT NULL DEFAULT 0,
  final_artifact  jsonb,
  metadata        jsonb       NOT NULL DEFAULT '{}',
  version         int         NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
)
""")

    # ------------------------------------------------------------------
    # 3.2  plan_atom — DAG nodes (+ queue/claim columns)
    # ------------------------------------------------------------------
    op.execute("""
CREATE TABLE nexus_controller.plan_atom (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  loop_id         uuid        NOT NULL
                                REFERENCES nexus_controller.loop_plan(id)
                                ON DELETE CASCADE,
  seq             int         NOT NULL,
  dependencies    uuid[]      NOT NULL DEFAULT '{}',
  task_spec       jsonb       NOT NULL,
  assigned_agent  text,
  assigned_model  text,
  verify_criteria jsonb,
  status          text        NOT NULL DEFAULT 'pending'
                                CHECK (status IN (
                                  'pending','running','complete','incomplete','failed','skipped'
                                )),
  max_attempts    int         NOT NULL DEFAULT 3,
  claimed_by      text,
  claimed_at      timestamptz,
  lease_until     timestamptz,
  reclaim_count   int         NOT NULL DEFAULT 0,
  state_payload   jsonb,
  metadata        jsonb       NOT NULL DEFAULT '{}',
  version         int         NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (loop_id, seq)
)
""")

    # ------------------------------------------------------------------
    # 3.3  atom_result — one row per execution attempt
    # ------------------------------------------------------------------
    op.execute("""
CREATE TABLE nexus_controller.atom_result (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  atom_id           uuid        NOT NULL
                                  REFERENCES nexus_controller.plan_atom(id)
                                  ON DELETE CASCADE,
  loop_id           uuid        NOT NULL
                                  REFERENCES nexus_controller.loop_plan(id)
                                  ON DELETE CASCADE,
  attempt_no        int         NOT NULL,
  executor_model    text        NOT NULL,
  code_check        text        CHECK (code_check IN ('pass','fail','na')),
  code_check_detail jsonb,
  artifact          jsonb,
  tokens            bigint,
  metadata          jsonb       NOT NULL DEFAULT '{}',
  created_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (atom_id, attempt_no)
)
""")

    # ------------------------------------------------------------------
    # 3.4  verification — judge output; independence enforced by trigger
    # ------------------------------------------------------------------
    op.execute("""
CREATE TABLE nexus_controller.verification (
  id              uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
  atom_result_id  uuid         NOT NULL
                                 REFERENCES nexus_controller.atom_result(id)
                                 ON DELETE CASCADE,
  atom_id         uuid         NOT NULL
                                 REFERENCES nexus_controller.plan_atom(id)
                                 ON DELETE CASCADE,
  loop_id         uuid         NOT NULL
                                 REFERENCES nexus_controller.loop_plan(id)
                                 ON DELETE CASCADE,
  judge_model     text         NOT NULL,
  completeness    numeric(4,3) NOT NULL
                                 CHECK (completeness >= 0 AND completeness <= 1),
  status          text         NOT NULL
                                 CHECK (status IN ('pass','partial','fail')),
  missing_aspects jsonb,
  recommendation  text
                                 CHECK (recommendation IN (
                                   'accept','retry','retry_escalate','replan'
                                 )),
  metadata        jsonb        NOT NULL DEFAULT '{}',
  created_at      timestamptz  NOT NULL DEFAULT now(),
  UNIQUE (atom_result_id)
)
""")

    # ------------------------------------------------------------------
    # 3.5  replan_decision — one per iteration
    # ------------------------------------------------------------------
    op.execute("""
CREATE TABLE nexus_controller.replan_decision (
  id                     uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
  loop_id                uuid         NOT NULL
                                         REFERENCES nexus_controller.loop_plan(id)
                                         ON DELETE CASCADE,
  iteration              int          NOT NULL,
  action                 text         NOT NULL
                                         CHECK (action IN ('replan','accept','fail')),
  replanner_model        text         NOT NULL,
  aggregate_completeness numeric(4,3),
  rationale              jsonb,
  metadata               jsonb        NOT NULL DEFAULT '{}',
  created_at             timestamptz  NOT NULL DEFAULT now(),
  UNIQUE (loop_id, iteration)
)
""")

    # ------------------------------------------------------------------
    # 3.6  side_effect_log — exactly-once ledger for external irreversible actions
    # ------------------------------------------------------------------
    op.execute("""
CREATE TABLE nexus_controller.side_effect_log (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  atom_id         uuid        NOT NULL
                                REFERENCES nexus_controller.plan_atom(id)
                                ON DELETE CASCADE,
  loop_id         uuid        NOT NULL
                                REFERENCES nexus_controller.loop_plan(id)
                                ON DELETE CASCADE,
  action          text        NOT NULL,
  idempotency_key text        NOT NULL UNIQUE,
  status          text        NOT NULL DEFAULT 'intended'
                                CHECK (status IN ('intended','confirmed','failed')),
  external_ref    text,
  metadata        jsonb       NOT NULL DEFAULT '{}',
  created_at      timestamptz NOT NULL DEFAULT now(),
  confirmed_at    timestamptz
)
""")

    # ------------------------------------------------------------------
    # 3.7  episodic_event (T3) — append-only, hash-chained audit
    # ------------------------------------------------------------------
    op.execute("""
CREATE TABLE nexus_controller.episodic_event (
  event_seq  bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  loop_id    uuid        REFERENCES nexus_controller.loop_plan(id),
  event_type text        NOT NULL
                           CHECK (event_type IN (
                             'state_transition','plan','dispatch','result',
                             'verification','replan','resolution','side_effect',
                             'resume','system'
                           )),
  payload    jsonb       NOT NULL,
  prev_hash  text,
  row_hash   text        NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
)
""")


def downgrade() -> None:
    # Drop in reverse dependency order; episodic_event first (FK → loop_plan only),
    # then tables with multiple FKs working back to loop_plan, drop schema last.
    op.execute("DROP TABLE IF EXISTS nexus_controller.episodic_event")
    op.execute("DROP TABLE IF EXISTS nexus_controller.side_effect_log")
    op.execute("DROP TABLE IF EXISTS nexus_controller.replan_decision")
    op.execute("DROP TABLE IF EXISTS nexus_controller.verification")
    op.execute("DROP TABLE IF EXISTS nexus_controller.atom_result")
    op.execute("DROP TABLE IF EXISTS nexus_controller.plan_atom")
    op.execute("DROP TABLE IF EXISTS nexus_controller.loop_plan")
    op.execute("DROP SCHEMA IF EXISTS nexus_controller")
    # pgcrypto not dropped — may be used by other schemas; removing it here
    # could be destructive. If a clean slate is needed, drop it manually.
