-- TKT-0253: SSOT New Tables — Phase 1 Set
-- Run: bash /Users/ainchorsangiefpl/.openclaw/workspace/scripts/db.sh -f forge/schema_p2.sql

-- ============================================
-- T6 CONFIGURATION & MANAGEMENT TABLES
-- ============================================

-- 1. Structured Config (TOML/YAML parsed into individual paths)
CREATE TABLE IF NOT EXISTS config_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config_path TEXT NOT NULL,
    config_value JSONB NOT NULL,
    value_type TEXT NOT NULL DEFAULT 'json',
    description TEXT,
    source_file TEXT,
    is_secret BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    updated_by TEXT,
    tenant_id TEXT DEFAULT 'ainchors',
    UNIQUE(config_path, tenant_id)
);

-- 2. Canonical CHG tracking
CREATE TABLE IF NOT EXISTS changelog (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    change_id TEXT NOT NULL UNIQUE,
    description TEXT,
    affected_systems TEXT[],
    change_type TEXT,
    author TEXT,
    approved_by TEXT,
    applied_at TIMESTAMPTZ DEFAULT now(),
    reverted_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'::jsonb,
    tenant_id TEXT DEFAULT 'ainchors'
);

-- 3. Agent Registry (canonical agent list)
CREATE TABLE IF NOT EXISTS agent_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id TEXT NOT NULL UNIQUE,
    agent_name TEXT NOT NULL,
    tier INTEGER NOT NULL CHECK (tier BETWEEN 0 AND 4),
    model_preference TEXT,
    capabilities TEXT[],
    status TEXT DEFAULT 'active',
    budget_limit NUMERIC(10,4),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    tenant_id TEXT DEFAULT 'ainchors'
);

-- 4. Structured Cost Tracking
CREATE TABLE IF NOT EXISTS cost_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_date DATE NOT NULL,
    model_id TEXT NOT NULL,
    agent_id TEXT,
    input_tokens INTEGER DEFAULT 0,
    output_tokens INTEGER DEFAULT 0,
    cost_usd NUMERIC(10,6) DEFAULT 0,
    source TEXT,
    tenant_id TEXT DEFAULT 'ainchors'
);

-- 5. Notification/Alerts
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    severity TEXT NOT NULL CHECK (severity IN ('info', 'warning', 'critical')),
    source_agent TEXT,
    title TEXT NOT NULL,
    body TEXT,
    acknowledged BOOLEAN DEFAULT false,
    acknowledged_by TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    tenant_id TEXT DEFAULT 'ainchors'
);

-- ============================================
-- EXTEND EXISTING TABLES
-- ============================================

-- Add structured columns to state_task_queue
DO $$ BEGIN
    ALTER TABLE state_task_queue ADD COLUMN IF NOT EXISTS created_at_ts TIMESTAMPTZ;
    ALTER TABLE state_task_queue ADD COLUMN IF NOT EXISTS updated_at_ts TIMESTAMPTZ;
    ALTER TABLE state_task_queue ADD COLUMN IF NOT EXISTS atoms_jsonb JSONB;
    ALTER TABLE state_task_queue ADD COLUMN IF NOT EXISTS tenant_id TEXT DEFAULT 'ainchors';
EXCEPTION WHEN others THEN NULL;
END $$;

-- Add metadata columns to state_tickets
DO $$ BEGIN
    ALTER TABLE state_tickets ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();
    ALTER TABLE state_tickets ADD COLUMN IF NOT EXISTS tags TEXT[];
    ALTER TABLE state_tickets ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;
    ALTER TABLE state_tickets ADD COLUMN IF NOT EXISTS tenant_id2 TEXT DEFAULT 'ainchors';
EXCEPTION WHEN others THEN NULL;
END $$;

-- Add agent status to sessions
DO $$ BEGIN
    ALTER TABLE agent_sessions ADD COLUMN IF NOT EXISTS agent_status JSONB;
    ALTER TABLE agent_sessions ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ;
EXCEPTION WHEN others THEN NULL;
END $$;

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_config_path ON config_entries(config_path, tenant_id);
CREATE INDEX IF NOT EXISTS idx_changelog_applied ON changelog(applied_at DESC);
CREATE INDEX IF NOT EXISTS idx_agent_registry_active ON agent_registry(status) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_cost_events_date ON cost_events(event_date DESC);
CREATE INDEX IF NOT EXISTS idx_cost_events_model ON cost_events(model_id, event_date);
CREATE INDEX IF NOT EXISTS idx_notifications_unacked ON notifications(acknowledged) WHERE acknowledged = false;
CREATE INDEX IF NOT EXISTS idx_task_queue_tid ON state_task_queue(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tickets_tags ON state_tickets USING gin(tags) WHERE tags IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_agent_sessions_active ON agent_sessions(status) WHERE status = 'active';

-- ============================================
-- STATE_V VIEWS (backward compat)
-- ============================================
CREATE SCHEMA IF NOT EXISTS state_v;

-- View: config as JSON (mirrors old JSON format)
CREATE OR REPLACE VIEW state_v.config_entries AS
SELECT jsonb_agg(jsonb_build_object('path', config_path, 'value', config_value)) AS data
FROM config_entries;

-- View: changelog as JSON
CREATE OR REPLACE VIEW state_v.changelog AS
SELECT jsonb_agg(jsonb_build_object('id', change_id, 'description', description, 'applied_at', applied_at)) AS data
FROM changelog
ORDER BY applied_at DESC;

-- View: agents as JSON  
CREATE OR REPLACE VIEW state_v.agents AS
SELECT jsonb_agg(jsonb_build_object('id', agent_id, 'name', agent_name, 'tier', tier, 'status', status)) AS data
FROM agent_registry
WHERE status = 'active';

-- View: notifications as JSON
CREATE OR REPLACE VIEW state_v.notifications AS
SELECT jsonb_agg(jsonb_build_object('title', title, 'severity', severity, 'acknowledged', acknowledged)) AS data
FROM notifications
WHERE acknowledged = false;
