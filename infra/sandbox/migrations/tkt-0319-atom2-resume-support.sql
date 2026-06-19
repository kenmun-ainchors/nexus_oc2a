-- TKT-0319 Atom 2: Resume support schema migration
-- Idempotent; safe to re-run.
-- Owner: Yoda (main session) | Approved: Ken 2026-06-19 21:10 AEST

BEGIN;

-- 1. Add resume columns to state_task_queue (if not present)
ALTER TABLE state_task_queue
  ADD COLUMN IF NOT EXISTS resume_attempts integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_checkpoint jsonb;

-- 2. Composite indexes for resume detector / re-queuer / executor queries
CREATE INDEX IF NOT EXISTS idx_task_queue_status_updated
  ON state_task_queue (status, updated_at_ts);

CREATE INDEX IF NOT EXISTS idx_task_queue_claimed_status_updated
  ON state_task_queue (claimedby, status, updated_at_ts);

CREATE INDEX IF NOT EXISTS idx_task_queue_parent_status
  ON state_task_queue (parent_task_id, status)
  WHERE parent_task_id IS NOT NULL;

-- 3. Checkpoint table for durable resume snapshots
CREATE TABLE IF NOT EXISTS state_resume_checkpoints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id text NOT NULL REFERENCES state_task_queue(id) ON DELETE CASCADE,
  checkpoint_at timestamptz NOT NULL DEFAULT now(),
  payload_hash text NOT NULL,
  payload jsonb NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_resume_checkpoints_task_time
  ON state_resume_checkpoints (task_id, checkpoint_at DESC);

-- 4. Ensure previous_status has an index for rollback lookups
CREATE INDEX IF NOT EXISTS idx_task_queue_previous_status
  ON state_task_queue (previous_status)
  WHERE previous_status IS NOT NULL;

COMMIT;
