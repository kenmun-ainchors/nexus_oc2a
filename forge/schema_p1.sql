-- Enable pgvector
CREATE EXTENSION IF NOT EXISTS vector;

-- Tier 1 — Episodic Audit
CREATE TABLE agent_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT now(),
    payload JSONB,
    tenant_id TEXT DEFAULT 'ainchors'
);

CREATE TABLE agent_decisions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id TEXT NOT NULL,
    decision_type TEXT NOT NULL,
    context JSONB,
    outcome TEXT,
    timestamp TIMESTAMPTZ DEFAULT now(),
    tenant_id TEXT DEFAULT 'ainchors'
);

CREATE TABLE decision_lineage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_decision_id UUID REFERENCES agent_decisions(id),
    child_decision_id UUID REFERENCES agent_decisions(id),
    relationship_type TEXT,
    tenant_id TEXT DEFAULT 'ainchors'
);

CREATE TABLE memory_access_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id TEXT NOT NULL,
    memory_key TEXT,
    access_type TEXT,
    timestamp TIMESTAMPTZ DEFAULT now(),
    tenant_id TEXT DEFAULT 'ainchors'
);

-- Tier 2 — Vector Store
CREATE TABLE knowledge_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT,
    source_path TEXT,
    mime_type TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    tenant_id TEXT DEFAULT 'ainchors'
);

CREATE TABLE knowledge_chunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID REFERENCES knowledge_documents(id),
    chunk_index INT,
    content TEXT,
    embedding vector(768),
    token_count INT,
    tenant_id TEXT DEFAULT 'ainchors'
);

-- Tier 3 — Session
CREATE TABLE agent_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id TEXT NOT NULL,
    session_key TEXT NOT NULL,
    status TEXT,
    started_at TIMESTAMPTZ DEFAULT now(),
    ended_at TIMESTAMPTZ,
    model_used TEXT,
    tenant_id TEXT DEFAULT 'ainchors'
);

-- Tier 4 — Shared State
CREATE TABLE agent_shared_state (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    state_key TEXT UNIQUE NOT NULL,
    state_value JSONB,
    version INT DEFAULT 1,
    updated_at TIMESTAMPTZ DEFAULT now(),
    updated_by TEXT,
    tenant_id TEXT DEFAULT 'ainchors'
);

-- Tier 5 — History
CREATE TABLE agent_state_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    state_id UUID REFERENCES agent_shared_state(id),
    state_value JSONB,
    version INT,
    changed_at TIMESTAMPTZ DEFAULT now(),
    changed_by TEXT,
    tenant_id TEXT DEFAULT 'ainchors'
);
