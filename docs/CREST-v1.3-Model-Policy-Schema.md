:# CREST v1.3 — Normalized Model Policy Schema

## Status
DRAFT FOR REVIEW. Supersedes the single-row JSONB design in `state_model_policy`.

## Rationale
The current `state_model_policy` stores the entire policy as one JSONB blob. This makes diffs, drift detection, and per-agent/per-phase queries difficult. v1.3 splits it into normalized tables so the routing resolver can query exactly what it needs.

## Proposed Schema

### 1. `policy_matrices` — matrix version registry

```sql
CREATE TABLE policy_matrices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version TEXT NOT NULL UNIQUE,          -- e.g., 'v1.3.0'
  description TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT FALSE,
  approved_by TEXT,
  approved_at TIMESTAMPTZ,
  source_chg TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  tenant_id TEXT DEFAULT 'ainchors'
);

CREATE UNIQUE INDEX idx_policy_matrices_active_one
  ON policy_matrices(tenant_id) WHERE active = TRUE;
```

Only one matrix version can be active per tenant. Rollback = update active flag.

### 2. `crest_phase_rules` — role × phase → model

```sql
CREATE TABLE crest_phase_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  matrix_version TEXT NOT NULL REFERENCES policy_matrices(version),
  role TEXT NOT NULL,                      -- yoda_master, design_backend, build, creative, business, governance
  phase TEXT NOT NULL,                     -- Plan, Execute, Verify, Replan, Synthesize
  default_model TEXT NOT NULL,             -- primary model for this role+phase
  fallback_model TEXT NOT NULL,            -- fallback if primary unavailable
  override_allowed BOOLEAN DEFAULT FALSE,  -- can caller override with reason?
  data_class_whitelist TEXT[],             -- if non-null, only these data_classes use this rule
  rationale TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  tenant_id TEXT DEFAULT 'ainchors',
  UNIQUE(matrix_version, role, phase, data_class_whitelist)
);

CREATE INDEX idx_crest_phase_rules_lookup
  ON crest_phase_rules(matrix_version, role, phase, tenant_id);
```

### 3. `model_capabilities` — model × data_class scoring

```sql
CREATE TABLE model_capabilities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  matrix_version TEXT NOT NULL REFERENCES policy_matrices(version),
  model TEXT NOT NULL,
  data_class TEXT NOT NULL,                -- code, policy, creative, data, infra, analysis
  capability_score INT NOT NULL CHECK (capability_score BETWEEN 1 AND 5),
  cost_tier TEXT NOT NULL CHECK (cost_tier IN ('cheap','strong','premium')),
  latency_ms_estimate INT,               -- rough OC1 latency for warm prompt
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  tenant_id TEXT DEFAULT 'ainchors',
  UNIQUE(matrix_version, model, data_class, tenant_id)
);

CREATE INDEX idx_model_capabilities_lookup
  ON model_capabilities(matrix_version, model, data_class, tenant_id);
```

### 4. `model_registry` — approved models and tags

```sql
CREATE TABLE model_registry (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  canonical_name TEXT NOT NULL UNIQUE,     -- ollama/glm-5.1:cloud
  provider TEXT NOT NULL,                  -- ollama
  family TEXT NOT NULL,                    -- glm
  parameter_size TEXT,                     -- 397B
  quantization TEXT,                       -- BF16
  cloud_tag TEXT,                          -- :cloud
  status TEXT NOT NULL CHECK (status IN ('active','pending','deprecated','prohibited')),
  max_context INT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  tenant_id TEXT DEFAULT 'ainchors'
);

CREATE INDEX idx_model_registry_status
  ON model_registry(status, tenant_id);
```

### 5. `routing_log` — runtime resolution audit

```sql
CREATE TABLE routing_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  matrix_version TEXT NOT NULL,
  agent_id TEXT NOT NULL,
  phase TEXT NOT NULL,
  data_class TEXT,
  stakes TEXT,
  selected_model TEXT NOT NULL,
  fallback_model TEXT NOT NULL,
  override_used BOOLEAN DEFAULT FALSE,
  override_reason TEXT,
  request_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  tenant_id TEXT DEFAULT 'ainchors'
);

CREATE INDEX idx_routing_log_agent_time
  ON routing_log(agent_id, created_at, tenant_id);
```

Used by Warden for drift checks and cost analysis.

## Migration from v1.2

1. Create new tables.
2. Insert `v1.3.0` matrix with `active = FALSE`.
3. Populate `crest_phase_rules` and `model_capabilities` from the v1.3 capability matrix.
4. Populate `model_registry` with v1.3 base-set models.
5. Run parallel: keep `state/model-policy.json` as cache for 1 sprint.
6. After v1.3 proves stable, set `v1.3.0` active = TRUE and retire JSON cache.
7. Update `scripts/model-policy-query.sh` to query PG first, JSON cache as fallback.

## Resolver Query Pattern

```sql
SELECT default_model, fallback_model, override_allowed, rationale
FROM crest_phase_rules
WHERE matrix_version = (SELECT version FROM policy_matrices WHERE active = TRUE AND tenant_id = 'ainchors')
  AND role = $1
  AND phase = $2
  AND (data_class_whitelist IS NULL OR $3 = ANY(data_class_whitelist))
  AND tenant_id = 'ainchors'
ORDER BY data_class_whitelist NULLS LAST
LIMIT 1;
```

## File cache

`state/model-policy.json` becomes a read-only export generated nightly or on policy change:

```bash
scripts/model-policy-export.sh --matrix v1.3.0 > state/model-policy.json
```

Warden and other consumers can continue reading the JSON during transition. After v1.3 is stable, consumers migrate to PG-first.

## Notes

- All tables are tenant-scoped for future multi-tenant P4 readiness.
- Matrix versions are immutable once active; changes require a new version + CHG.
- Rollback = flip active flag to previous matrix version.
