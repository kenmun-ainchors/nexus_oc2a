# TKT-0178 — Routing Discipline Enforcement
## Deep Groom | Priority: P1-urgent | Groomed: 2026-05-15
## Status: DEFERRED | Ken approved 2026-05-15 | CHG-0330
## Ticket: TKT-0178
## Est: 6.5 days | Sprint: S4-S5 | Owner: Forge (lead), Thrawn (arch), Sage (QA)

---

## 1. Background

### Trigger
2026-05-15, Yoda wrote LinkedIn content directly instead of routing to Spark. Three iterations with Ken to get right. Ken raised concern: "In P1-P4, clients won't detect this. How do we ensure agents don't bypass routing rules?"

### Root Cause
OpenClaw gives every agent full tool access. Rules in markdown (AGENTS.md, SPARK_RULES.md) are advisory only. No technical enforcement of routing discipline exists. An agent can:
- Write to any directory
- Execute any script  
- Spawn any subagent
- Access any state file

Users cannot detect routing violations because they don't see internal tool calls.

### Impact
- **Today:** Internal ops friction, rework, governance inconsistency
- **P1-P2:** Quality degradation if agents skip specialist routing
- **P2+:** Client-facing — wrong agent handling tasks, policy violations
- **P3+:** Multi-tenant risk if external users get raw agent access

---

## 2. Problem Statement

| What | Detail |
|---|---|
| **Symptom** | Agent executes task outside its domain instead of routing to correct specialist |
| **Example** | Yoda writes LinkedIn draft (Spark's domain) → 3 iterations, rules missed |
| **Detection** | Only visible to deeply involved user (Ken). Silent to regular users/clients. |
| **Prevention** | None today. No technical enforcement. |
| **Remediation** | Manual catch by Ken or governance review. After the fact. |

### Scenarios
| Scenario | Today | With TKT-0178 Layer 1+2 |
|---|---|---|
| Ken asks Yoda for LinkedIn post | Yoda writes directly. Rules missed. 3 iterations. | Yoda routes to Spark. If tries direct → violation detected, Ken alerted. |
| Client asks Ahsoka for architecture doc | Ahsoka might write directly or route inconsistently | Ahsoka must spawn Atlas. Routing logged. Audit trail. |
| Forge runs infra task | Works correctly (Forge's domain) | No violation. Audit shows correct routing. |
| Shield runs security review | Shield runs correctly (Shield's domain) | No violation. |

---

## 3. Constraints & Scope

### In Scope
- File write audit (which agent wrote to which path)
- Cross-domain violation detection
- Routing gate for subagent spawns
- Warden integration (S2 routing discipline violations)
- Alerting to Ken via Telegram

### Out of Scope
- **Layer 3 (RBAC/JWT):** Deferred to P3. Over-engineering for internal agents. See §10.
- **OpenClaw upstream changes:** We work with what we have. If OpenClaw adds native RBAC later, we adopt.
- **Agent capability restrictions:** We audit, not restrict. Restriction is Layer 3 territory.

### Constraints
- Must not break existing agent workflows
- Must not add >5% latency to agent operations
- Must run on OC1 (Mac Mini M4, 24GB)
- Must integrate with existing Warden/health-check infrastructure
- Must produce actionable alerts, not noise

---

## 4. Proposed Solution

### Layer 1: Audit + Detection (P1 — S4, ~1.5 days)

**What:** Automated audit of all file writes and tool calls. Cross-domain violations flagged in real time.

**How:**
```
scripts/audit-routing.sh
├── Read agent-session logs (OpenClaw session logs)
├── Parse write/exec tool calls per agent
├── Compare write path against AGENTS.md routing table
├── If Yoda writes to workspace-social/drafts/ → violation: "routing-bypass"
├── Log to state/routing-violations.json
├── Warden picks up as S2 violation
└── Alert Ken via Telegram (immediate, non-batched)
```

**Implementation details:**
- **Data source:** OpenClaw session logs are JSONL in `state/sessions/*.jsonl`. Contains all tool calls with agentId.
- **Frequency:** 15-minute cron (piggybacks on existing health-check cycle)
- **Routing table source:** `AGENTS.md` domain column. Parse at runtime.
- **Path mapping:**
  - `workspace-social/` → Spark
  - `docs/` → Atlas (architecture), Ahsoka (consulting)
  - `scripts/` → Forge
  - `infra/` → Forge
  - `state/` → Warden (read), agent-specific (write)
  - `memory/` → Yoda (own memory), Aria (business memory)
  - `skills/` → Thrawn (platform), Atlas (EA)
  - `canvas/` → Spark
  - `blog/` → Spark
  - `journal/` → Yoda (system)

**Violation format:**
```json
{
  "violationId": "RV-20260515-001",
  "timestamp": "2026-05-15T10:05:00+10:00",
  "agentId": "yoda",
  "taskType": "social",
  "expectedRouter": "spark",
  "actualAction": "write",
  "path": "workspace-social/drafts/linkedin-c1-w2-p1-v1.md",
  "severity": "warning",
  "status": "open"
}
```

**Alert format (Telegram):**
```
⚠️ Routing Violation: RV-20260515-001
Agent: Yoda | Task: social | Expected: Spark
Path: workspace-social/drafts/linkedin-c1-w2-p1-v1.md
Action: Direct write instead of routing to specialist
Time: 2026-05-15 10:05 AEST
Status: OPEN
```

**Edge cases:**
- Yoda reviewing Spark output (read-only) → OK, no violation
- Agent writing to its own memory/state → OK, no violation
- System crons (auto-heal, drive-sync) → whitelisted, no violation
- Emergency override (Ken says "just do it") → log but flag as `override: true`

---

### Layer 2: Routing Gate (P1-P2 boundary — S5, ~4 days)

**What:** Before any subagent is spawned, validate that the task routes to the correct specialist agent.

**How:**
```
scripts/routing-gate.sh --task "Write LinkedIn post" --requestedAgent "yoda"
├── Classify task type from brief text (keyword matching)
├── Query AGENTS.md routing table: taskType → expectedAgent
├── Compare requestedAgent vs expectedAgent
├── If mismatch: REJECT with clear error message
└── Log to state/routing-decisions.json
```

**Task classification (v1):**
```
Keyword-based heuristic:
- "LinkedIn" / "social" / "post" / "campaign" / "content" → social → Spark
- "architecture" / "TOGAF" / "EA" / "enterprise" / "roadmap" → enterprise-arch → Atlas
- "infra" / "deploy" / "backup" / "health" / "server" / "SRE" → infra → Forge
- "security" / "audit" / "S1-S7" / "compliance" → security → Shield
- "legal" / "APP" / "compliance" / "privacy" → legal → Lex
- "QA" / "accuracy" / "test" / "review" → qa → Sage
- "change" / "ADKAR" / "adoption" → change-mgmt → Mon Mothma
- "BPM" / "process" / "workflow" → bpm → Lando
- "consulting" / "client" / "discovery" / "proposal" → consulting → Ahsoka
- "budget" / "cost" / "ROI" / "capacity" → business → Aria
- "model" / "drift" / "compliance" / "tier" → model-compliance → Warden
```

**Rejection message:**
```
ROUTING GATE REJECTED
Task: "Write LinkedIn post about AIOps governance"
Detected type: social
Expected router: Spark
Requested: yoda

Action: Use sessions_spawn with agent=spark, or route via Aria.
Do not execute social tasks directly. See AGENTS.md routing table.
```

**Integration point:**
- Option A: Wrap `sessions_spawn` in a pre-flight check
- Option B: Monitor spawn events via cron (read state, detect wrong spawns after)
- Recommendation: Start with Option B (audit-based, no OpenClaw changes), then Option A when feasible

**State format:**
```json
{
  "routingDecisions": [
    {
      "decisionId": "RD-20260519-001",
      "timestamp": "2026-05-19T07:30:00Z",
      "taskBrief": "Write LinkedIn post...",
      "taskType": "social",
      "expectedAgent": "spark",
      "spawnedAgent": "spark",
      "spawnedBy": "yoda",
      "result": "approved"
    }
  ]
}
```

---

### Layer 3: RBAC with Agent Identity Tokens (DEFERRED — P3)

**What:** JWT identity tokens per agent. Policy engine evaluates every tool call.

**Why deferred:**
- Over-engineering for internal agents (all trusted, same permissions today)
- Adds significant complexity (JWT infrastructure, policy engine, token management)
- Not needed until multi-tenant or untrusted agents exist (P3+)
- OpenClaw may add native RBAC — building custom may be wasted work

**When to revisit:**
- P3 enterprise: external users get agent access
- OpenClaw adds native agent scoping
- Security audit mandates RBAC (pre-APRA)

---

## 5. Success Criteria

| # | Criterion | How measured |
|---|---|---|
| 1 | Every cross-domain file write detected within 15 min | Audit cron coverage, manual spot-check |
| 2 | Routing violations alerted to Ken within 15 min | Telegram delivery confirmation |
| 3 | Zero false positives on legitimate agent writes | Read-only access, own-memory writes, system crons whitelisted |
| 4 | Subagent spawn routing validated before spawn | routing-gate.sh test suite |
| 5 | Audit log persists for 90 days | state/routing-violations.json retention |
| 6 | No agent workflow disruption | Existing agents continue operating normally |

---

## 6. Acceptance Criteria (Definition of Done)

- [ ] `scripts/audit-routing.sh` created and tested
- [ ] `state/routing-violations.json` format defined and documented
- [ ] Warden integration: violations surface in warden-escalation-pending.json
- [ ] Telegram alerts working (tested end-to-end)
- [ ] `scripts/routing-gate.sh` design approved by Ken
- [ ] routing-gate.sh implemented and tested with 5 scenario tests
- [ ] AGENTS.md routing table updated with path mappings
- [ ] Documentation: routing-enforcement.md in docs/
- [ ] Sage QA: end-to-end test pass
- [ ] Ken sign-off: APPROVED or DEFERRED

---

## 7. Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| False positives overwhelm Ken | Medium | High | Whitelist system crons, read-only access, own-memory writes |
| Audit cron adds load to OC1 | Low | Medium | 15-min interval, lightweight parsing, can be throttled |
| OpenClaw changes break integration | Low | High | Use file-based integration (JSON), not API hooks |
| Routing gate too restrictive | Medium | Medium | Start with audit-only (Layer 1), gate is advisory before enforcement |
| Ken overrides routing frequently | Medium | Low | Log overrides as `override: true`, review pattern monthly |

---

## 8. Dependencies

| Dependency | Status | Blocker? |
|---|---|---|
| AGENTS.md routing table (current) | ✅ Current | No |
| Warden infrastructure | ✅ Current | No |
| Telegram alerting | ✅ Current | No |
| OpenClaw session logs | ✅ Current | No |
| AGENTS.md domain/path mapping (new) | ⏳ TKT-0178-a | Blocks Layer 1 |
| routing-gate.sh design approval | ⏳ Ken | Blocks Layer 2 implementation |

---

## 9. Subtasks

| ID | Title | Sprint | Effort | Owner | Dependency | Status |
|---|---|---|---|---|---|---|
| TKT-0178-a | Create AGENTS.md domain/path mapping table | S4 | 0.5d | Forge | — | OPEN |
| TKT-0178-b | Create audit-routing.sh (Layer 1) | S4 | 1.0d | Forge | TKT-0178-a | OPEN |
| TKT-0178-c | Warden integration: S2 routing violations | S4 | 0.5d | Thrawn | TKT-0178-b | OPEN |
| TKT-0178-d | Telegram alert integration | S4 | 0.5d | Forge | TKT-0178-b | OPEN |
| TKT-0178-e | routing-gate.sh design + review | S5 | 1.0d | Thrawn | TKT-0178-a,b,c,d | OPEN |
| TKT-0178-f | routing-gate.sh implementation | S5 | 2.0d | Forge | TKT-0178-e | OPEN |
| TKT-0178-g | Test suite: 5 scenario tests | S5 | 0.5d | Sage | TKT-0178-f | OPEN |
| TKT-0178-h | Documentation + Ken sign-off | S5 | 0.5d | Yoda | TKT-0178-g | OPEN |

**Total:** 6.5 days
**Critical path:** TKT-0178-a → b → c → d → e → f → g → h

---

## 10. Alternatives Considered

| Alternative | Why Rejected |
|---|---|
| OpenClaw native RBAC | Doesn't exist. Would require upstream contribution or fork. Out of scope. |
| Linux file permissions (chmod) | Too coarse. Agents run as same user. Doesn't solve routing classification. |
| Docker container per agent | Overhead on OC1. Doesn't address spawn routing. |
| Manual routing checklist | Advisory only, no enforcement. Same problem as today. |
| Agent SOUL.md self-declaration | Advisory. Agents can still bypass. No technical enforcement. |

---

## 11. P2 Client Context

**Important:** P2 clients interact through Citadel (client portal), not raw agent access. Routing is handled at the portal layer:
- Client request → Citadel → Intent classifier → Correct agent spawn
- Client never calls `sessions_spawn` directly
- This means Layer 1+2 primarily protects **internal ops**, not client-facing workflows

**However:** Internal agent routing consistency = quality. If Yoda bypasses Spark for social tasks internally, the same pattern could leak into Citadel routing logic. Layer 1+2 ensures the platform learns correct routing before client exposure.

---

## 12. Approval

**Ken — groomed deeper. Ready for Sprint 4 commit?**

Reply: **APPROVED** (commit to S4, start TKT-0178-a) | **EDIT** [feedback] | **DEFER** (move to S5 or later)

Full doc: `/Users/ainchorsangiefpl/.openclaw/workspace/docs/TKT-0178-Routing-Enforcement-Proposal.md`
