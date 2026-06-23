-- TKT-0357 Atom 1: pg_write_events audit log table
-- Path A: Separate table, not a view over agent_events.
-- Idempotent; safe to re-run.
-- Owner: Forge (subagent) | Approved: Ken 2026-06-23 19:05 AEST
-- CHG-0749

BEGIN;

-- 1. Create pg_write_events table (if not exists)
CREATE TABLE IF NOT EXISTS pg_write_events (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  actor TEXT NOT NULL,
  event_type TEXT NOT NULL,
  entity_type TEXT,
  entity_id TEXT,
  table_name TEXT NOT NULL,
  row_id TEXT,
  command TEXT,
  payload JSONB,
  prev_state JSONB,
  new_state JSONB,
  success BOOLEAN NOT NULL DEFAULT true,
  error_message TEXT,
  tenant_id TEXT DEFAULT 'ainchors'
);

-- 2. Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_pg_write_events_created_at
  ON pg_write_events(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_pg_write_events_table_row
  ON pg_write_events(table_name, row_id);

CREATE INDEX IF NOT EXISTS idx_pg_write_events_actor
  ON pg_write_events(actor);

-- 3. Create audit event function (idempotent via CREATE OR REPLACE)
CREATE OR REPLACE FUNCTION pg_write_audit_event(
  p_actor TEXT,
  p_event_type TEXT DEFAULT 'write',
  p_entity_type TEXT DEFAULT NULL,
  p_entity_id TEXT DEFAULT NULL,
  p_table_name TEXT DEFAULT NULL,
  p_row_id TEXT DEFAULT NULL,
  p_command TEXT DEFAULT NULL,
  p_payload JSONB DEFAULT NULL,
  p_prev_state JSONB DEFAULT NULL,
  p_new_state JSONB DEFAULT NULL,
  p_success BOOLEAN DEFAULT true,
  p_error_message TEXT DEFAULT NULL,
  p_tenant_id TEXT DEFAULT 'ainchors'
)
RETURNS TABLE(event_id_out BIGINT)
LANGUAGE plpgsql
AS $function$
DECLARE
  v_id BIGINT;
BEGIN
  INSERT INTO pg_write_events (
    actor, event_type, entity_type, entity_id,
    table_name, row_id, command,
    payload, prev_state, new_state,
    success, error_message, tenant_id
  ) VALUES (
    p_actor, p_event_type, p_entity_type, p_entity_id,
    p_table_name, p_row_id, p_command,
    p_payload, p_prev_state, p_new_state,
    p_success, p_error_message, p_tenant_id
  )
  RETURNING id INTO v_id;

  RETURN QUERY SELECT v_id;
END;
$function$;

COMMIT;