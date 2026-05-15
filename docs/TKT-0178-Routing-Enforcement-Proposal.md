# Routing Discipline Enforcement Proposal
## TKT-0178 | Priority: P1-urgent
## Status: DRAFT FOR REVIEW | Ken Mun approval required
## Version: 1.0 | 2026-05-15

---

## 1. Problem

Agents have full tool access. An agent can execute any task directly instead of routing to the correct specialist. Users cannot detect this. Governance rules in markdown files (AGENTS.md, SPARK_RULES.md) are advisory — no technical enforcement exists.

**Recent incident:** Yoda wrote LinkedIn content directly (3 iterations with Ken) instead of routing to Spark. Spark would have done it correctly in one pass. The user (Ken) noticed because he's deeply involved. In P1-P4, clients will not notice.

**Risk:** Silent governance violations. Wrong agent executing specialist work. Rules violated without detection. No audit trail of routing decisions.

---

## 2. Current State (OpenClaw Limitations)

OpenClaw does not provide:
- Agent-scoped tool permissions
- Role-based access control (RBAC)
- Policy engine for tool-call validation
- Routing gate in session_spawn

Every agent can theoretically:
- Write to any directory
- Execute any script
- Spawn any subagent
- Access any state file

This is by design in OpenClaw — agents are privileged. Enforcement must be added at the platform layer.

---

## 3. Proposed Solution — Three Enforcement Layers

### Layer 1: Audit + Detection (P1 — ~2 days, Forge)

**What:** Automated audit of all file writes and tool calls. Cross-domain violations flagged in real time.

**Implementation:**
- Extend `scripts/audit-routing.sh` (new): Log every `write` and `exec` tool call per agent
- Compare write paths against agent's declared domain (from AGENTS.md routing table)
- If Yoda writes to `workspace-social/drafts/linkedin-*.md` → **violation**: `routing-bypass`
- Log to `state/routing-violations.json` with: agent, expectedRouter, actualAgent, file, timestamp
- Warden picks this up as S2 violation (routing discipline breach)
- Alert Ken via Telegram on every routing violation

**Detection latency:** Near real-time (within the audit cron interval, 15 min)
**Prevention:** None — it catches after the fact
**Cost:** Low — extends existing audit infrastructure

---

### Layer 2: Routing Gate in Subagent Spawns (P1-P2 boundary — ~1 sprint, Forge + Thrawn)

**What:** Before any subagent is spawned, validate that the task routes to the correct specialist agent.

**Implementation:**
- Create `scripts/routing-gate.sh`:
  - Accepts: taskType, briefText, requestedAgent
  - Queries AGENTS.md routing table for taskType → expectedAgent
  - If requestedAgent ≠ expectedAgent: reject spawn with clear error
  - If Yoda tries to spawn "itself" for a social task: rejected, must spawn Spark
- Integrate into session_spawn wrapper (or enforce via cron monitoring spawn calls)
- Log every routing decision: `state/routing-decisions.json`

**Example:**
```
Task: "Write LinkedIn post about AIOps"
Task type: social
Expected router: Spark
Actual attempt: Yoda direct execution
Result: REJECTED — must route to Spark
```

**Prevention:** Partial — prevents wrong subagent spawns, but direct tool calls by the main agent still possible
**Cost:** Medium — needs wrapper or OpenClaw enhancement request

---

### Layer 3: Agent Identity + RBAC (P2-P3 — ~2 sprints, Thrawn + Atlas)

**What:** Each agent has a signed identity token. Tool calls are validated against agent's scope.

**Implementation:**
- Agent identity tokens (JWT) injected at session creation:
  ```
  { "agentId": "spark", "scope": ["write:workspace-social/*", "exec:linkedin-post.sh"], "iat": ... }
  ```
- Policy engine (Open Policy Agent / Rego) evaluates every tool call:
  - `write /Users/.../workspace-social/drafts/linkedin-*.md` → allowed for Spark, denied for Yoda
  - `exec scripts/linkedin-post.sh` → allowed for Spark, denied for Yoda
- Violations: blocked at API layer, logged, alerted

**Prevention:** Full — agent cannot execute outside scope
**Cost:** High — new infrastructure component, maintenance burden
**Trade-off:** Adds complexity. Is it worth it for a system where all agents are trusted internally?

---

## 4. Recommendation

| Layer | When | Do? | Why |
|---|---|---|---|
| Layer 1 (Audit + Detection) | Now (P1) | ✅ YES | Low cost, high value. Catches violations. Foundation for Layer 2. |
| Layer 2 (Routing Gate) | P1-P2 boundary | ✅ YES | Prevents wrong subagent spawns. Solves the LinkedIn routing problem directly. |
| Layer 3 (RBAC) | P3 | ❌ DEFER | Over-engineering for internal agents. Revisit when multi-tenant or untrusted agents exist. |

**Primary risk today:** Not malicious agents, but well-meaning agents routing incorrectly or taking shortcuts. Layer 1 + 2 addresses this with proportionate cost.

**P2 client context:** Clients don't spawn agents directly — they interact through Citadel (client portal). Routing is handled at the portal layer, not by raw agent access. Layer 3 becomes relevant only if we expose raw agent APIs to external users.

---

## 5. Implementation Plan

| Task | Ticket | Agent | Sprint | Effort |
|---|---|---|---|---|
| Create audit-routing.sh (Layer 1) | TKT-0178-a | Forge | S4 | 1 day |
| Integrate with Warden violations | TKT-0178-b | Thrawn | S4 | 0.5 day |
| Design routing-gate.sh (Layer 2) | TKT-0178-c | Thrawn | S5 | 2 days |
| Implement routing gate | TKT-0178-d | Forge | S5 | 3 days |
| Test end-to-end (LinkedIn scenario) | TKT-0178-e | Sage | S5 | 1 day |

**Total:** ~1.5 sprints, ~7 days work

---

## 6. What Changes for Users

| Scenario | Today (no enforcement) | With Layer 1+2 |
|---|---|---|
| Ken asks Yoda for LinkedIn post | Yoda writes directly (3 iterations, rules missed) | Yoda routes to Spark. If Yoda tries direct write → violation logged, Ken alerted. Spark handles in one pass. |
| Client asks Ahsoka for architecture doc | Ahsoka might write directly or route to Atlas inconsistently | Ahsoka must spawn Atlas. Routing decision logged. Audit trail exists. |
| Forge runs infra task | Forge runs correctly (it's Forge's domain) | No violation. Audit shows correct routing. |

**User-visible difference:** None. Enforcement is transparent. Users get correct routing, fewer iterations, consistent quality.

**Ken-visible difference:** Alert only when violation detected. Otherwise silent correct operation.

---

## 7. Open Question

Does OpenClaw have plans for native RBAC or agent scoping? If so, Layer 3 may be unnecessary — we can adopt upstream. Worth checking with OpenClaw team before building custom RBAC.

---

## 8. Approval

Ken — approve this proposal? Layer 1 + 2 as described, Layer 3 deferred to P3. I'll raise TKT-0178 and assign to Forge/Thrawn for Sprint 4-5 if yes.

Reply: **APPROVED** | **EDIT [feedback]** | **REJECT [reason]**
