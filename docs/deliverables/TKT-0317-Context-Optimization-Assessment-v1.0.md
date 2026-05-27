# Context Optimization Assessment — Nexus Agent Fleet

**Status:** DRAFT FOR REVIEW | TKT-0317 Epic Pre-Work
**Author:** Atlas 🏛️ (Enterprise Architecture)
**Date:** 2026-05-27
**Version:** v1.0
**Classification:** Nexus Internal — Architecture Assessment

---

## Executive Summary

The AInchors Nexus agent fleet currently injects ~124KB of context into every Yoda session and 4–8KB of shared context into every specialist session. Cross-agent rule duplication stands at **92%** — only 8% of rules are domain-specific. The platform burns an estimated **79,942 tokens per day** on injected context alone (excluding conversation, tool output, and model thinking). This assessment identifies five optimization vectors: context de-duplication, progressive disclosure, model-task routing, path safety hardening, and phased implementation — targeting a **40–60% reduction** in wasted context tokens without reducing agent capability.

---

## 1. Context Audit

### 1.1 Yoda (Orchestrator) — Current State

| File                 | Size (KB) | Sections | Purpose                                  |
|----------------------|-----------|----------|------------------------------------------|
| AGENTS.md            | 17.9      | 14       | Workspace discipline, heartbeat, memory  |
| SOUL.md              | 4.7       | 9        | Yoda identity & role                     |
| MEMORY.md            | 9.0       | 26       | Long-term memory / decisions             |
| HEARTBEAT.md         | 13.6      | 2        | Periodic task checklist                  |
| RULES.md             | 46.5      | 34       | Master rules (PG write, tickets, etc.)   |
| YODA_RULES.md        | 24.5      | 14       | Yoda-specific orchestration rules        |
| SHARED_CONTEXT.md    | 4.7       | 10       | Cross-agent shared context               |
| **Total**            | **123.8** | **109**  |                                          |

**Yoda per-session token burn:** ~30,943 tokens (injected context only).

> ⚠️ **Critical Finding:** Yoda loads 123.8KB every session. The HEARTBEAT.md (13.6KB) and AGENTS.md (17.9KB) are the largest contributors, while YODA_RULES.md (24.5KB) and RULES.md (46.5KB) have significant overlap.

### 1.2 Specialist Agents — Current State

| Agent          | Role                         | SOUL (KB) | RULES (KB) | Total (KB) | Tokens/Session | Shared Rules |
|----------------|------------------------------|-----------|------------|------------|----------------|--------------|
| Spark ✨       | Social & Digital Marketing   | 4.4       | 22.6       | **27.0**   | 8,130          | 2            |
| Aria 🔵        | Business Operations (CEO)    | 4.7       | 12.1       | **16.9**   | 5,523          | 2            |
| Atlas 🏛️       | Enterprise Architecture      | 2.8       | 7.1        | 9.9        | 3,733          | 2            |
| Lex ⚖️         | Legal Governance             | 2.5       | 8.2        | 10.7       | 3,939          | 2            |
| Mon Mothma 🌟  | Change Management            | 3.4       | 6.3        | 9.7        | 3,702          | 0            |
| Sage 🧪        | Quality Assurance            | 2.0       | 6.8        | 8.8        | 3,449          | 2            |
| Thrawn 🔵      | Platform Architecture        | 3.3       | 5.4        | 8.7        | 3,446          | 4            |
| Lando 🟡       | Business Process             | 2.9       | 6.0        | 8.8        | 3,463          | 4            |
| Shield 🔐      | Security Governance          | 4.0       | 3.6        | 7.6        | 3,151          | 2            |
| Forge 🏗️       | Infrastructure/SRE           | 1.2       | 5.6        | 6.9        | 2,962          | 2            |
| Luthen 🔍      | Marketing Intelligence       | 2.0       | 3.8        | 5.8        | 2,691          | 2            |
| Warden 🔍      | Model Governance             | 1.5       | 3.8        | 5.3        | 2,553          | 2            |
| Ahsoka 🤍      | AI Transformation Consulting | 0.9       | 3.2        | 4.1        | 2,257          | 2            |

**Specialist shared inject:** All specialists load SHARED_CONTEXT.md (4.7KB).

### 1.3 Duplication Analysis

| Metric                     | Value |
|----------------------------|-------|
| Total rule instances       | 234   |
| Duplicate instances        | 215   |
| Unique domain-specific     | 19    |
| **Duplication ratio**      | **92%** |

**Most duplicated rules (appear in 8+ agents):**
- Non-Negotiable Rules (12 agents)
- Ken approval required (12 agents)
- `db-read.sh` for state reads (11 agents)
- `state_tickets` reference (10 agents)
- Postgres as SSOT (9 agents)
- DRAFT FOR REVIEW (9 agents)
- Ticket Discipline (9 agents)
- Holocron template (9 agents)
- `agent_shared_state` reference (8 agents)

**Key Insight:** 92% of every specialist agent's RULES.md is redundant across the fleet. Only 8% is domain-specific methodology (TOGAF, BPMN, ADKAR, etc.). Every byte of duplicated context burns tokens in every specialist session.

### 1.4 Platform Daily Token Burn

| Component                          | Est. Tokens/Day |
|------------------------------------|-----------------|
| Yoda (est. 1 session)              | 30,943          |
| 13 specialists (est. 1 each)       | 48,999          |
| **Platform total (injected)**      | **79,942**      |

> These estimates cover injected context only. Actual token consumption including conversation turns, tool output, and model reasoning is typically 4–8× higher.

---

## 2. Progressive Disclosure Design

### 2.1 Proposed Tiered Context Model

**Tier 0 — Essential (always loaded, ~1–2KB)**
Identity, role, and the core operational contract. Loaded every session for every agent.

Per agent: SOUL.md only (identity + role + core traits)
Estimated: 1–3KB per agent (vs 4–27KB today)

**Tier 1 — Situational (loaded for relevant task types, ~2–8KB)**
Domain rules loaded only when the route matches. Example: Lando loads BPMN rules only on BPM tickets; Thrawn loads architecture rules only on platform-arch tickets.

**Tier 2 — Never-Needed (migrated to SHARED_CONTEXT.md only, loaded once)**
Cross-cutting rules that every agent currently duplicates. These rules should live exclusively in SHARED_CONTEXT.md and be removed from individual RULES.md files.

### 2.2 Estimated Token Savings per Agent

| Agent   | Current KB | Tier 0 | Tier 1 (loaded) | Net KB | Savings |
|---------|-----------|--------|-----------------|--------|---------|
| Spark   | 27.0      | 4.4    | 5.0             | 9.4    | **65%** |
| Aria    | 16.9      | 4.7    | 4.0             | 8.7    | **48%** |
| Lex     | 10.7      | 2.5    | 3.0             | 5.5    | **49%** |
| Atlas   | 9.9       | 2.8    | 3.0             | 5.8    | **41%** |
| Mon M.  | 9.7       | 3.4    | 2.5             | 5.9    | **39%** |
| Sage    | 8.8       | 2.0    | 2.5             | 4.5    | **49%** |
| Lando   | 8.8       | 2.9    | 3.0             | 5.9    | **33%** |
| Thrawn  | 8.7       | 3.3    | 3.0             | 6.3    | **28%** |
| Shield  | 7.6       | 4.0    | 2.0             | 6.0    | **21%** |
| Forge   | 6.9       | 1.2    | 2.5             | 3.7    | **46%** |
| Luthen  | 5.8       | 2.0    | 2.0             | 4.0    | **31%** |
| Warden  | 5.3       | 1.5    | 1.5             | 3.0    | **43%** |
| Ahsoka  | 4.1       | 0.9    | 1.5             | 2.4    | **41%** |
| **Fleet average** | | | | | **~41%** |

**Yoda savings:** Consolidating RULES.md + YODA_RULES.md (71KB combined) into a tiered structure could reduce Yoda injection from 123.8KB to ~45–55KB — a **55–64% reduction**.

**Platform daily savings estimate:** From 79,942 tokens/day to approximately 35,000–48,000 tokens/day.

---

## 3. Model-Task Fit Matrix

### 3.1 Current State — Model Assignments

| Agent              | Primary Model                   | Fallbacks                     |
|--------------------|----------------------------------|-------------------------------|
| Yoda (main)        | deepseek-v4-pro:cloud           | gemma4:31b-cloud, kimi-k2.6   |
| Aria (business)    | deepseek-v4-pro:cloud           | gemma4:31b-cloud, kimi-k2.6   |
| Spark (social)     | kimi-k2.6:cloud                 | gemma4:31b-cloud, deepseek    |
| Shield (security)  | gemma4:31b-cloud                | deepseek, kimi                |
| Lex (legal)        | gemma4:31b-cloud                | deepseek, kimi                |
| Sage (QA)          | gemma4:31b-cloud                | deepseek, kimi                |
| Warden (gov)       | gemma4:31b-cloud                | deepseek, kimi                |
| Forge (infra)      | gemma4:31b-cloud                | deepseek, kimi                |
| Atlas (arch)       | gemma4:31b-cloud                | deepseek, kimi                |
| Thrawn (plat-arch) | gemma4:31b-cloud                | deepseek, kimi                |
| Lando (BPM)        | gemma4:31b-cloud                | deepseek, kimi                |
| Mon Mothma (OCM)   | gemma4:31b-cloud                | deepseek, kimi                |
| Ahsoka             | gemma4:31b-cloud                | deepseek, kimi                |
| Luthen             | gemma4:31b-cloud                | deepseek, kimi                |

**Observation:** 12 of 14 agents use gemma4:31b-cloud as primary. Only Yoda and Aria use deepseek-v4-pro:cloud; Spark uniquely uses kimi-k2.6:cloud. The fallback chain is identical for 13 agents — deepseek → gemma → kimi.

### 3.2 Recommended: Task-Complexity Routing

Current model assignment is agent-identity based. Recommendation: route by **task complexity**, not agent identity. Many specialist tasks are low-complexity (format validation, template application, status checks) and can run on cheaper models.

**Proposed Routing Table:**

| Complexity Tier | Task Examples                           | Recommended Model      | Current Agents |
|-----------------|-----------------------------------------|------------------------|----------------|
| **T4 — Routine**    | Status checks, format validation, state reads, template fills | gemma4:31b-cloud (or smaller) | Warden, Forge, Ahsoka, Luthen (simple tasks) |
| **T3 — Standard**   | Ticket execution, rule application, domain work | gemma4:31b-cloud       | Atlas, Thrawn, Lando, Mon Mothma, Sage, Lex, Shield |
| **T2 — Complex**    | Cross-domain analysis, multi-step planning, trade-off decisions | deepseek-v4-pro:cloud  | Yoda, Aria (complex), Thrawn (complex) |
| **T1 — Critical**   | Enterprise decisions, regulatory analysis, security incidents | deepseek-v4-pro:cloud + human review | Shield (incidents), Lex (compliance), Atlas (enterprise decisions) |

**Quick Wins — Immediate Model Adjustments:**

| Agent    | Current Model    | Proposed Change                           | Rationale                                      |
|----------|------------------|-------------------------------------------|-------------------------------------------------|
| Aria     | deepseek-v4-pro  | gemma4:31b-cloud (default), deepseek for complex | Business ops mostly template/fill; deepseek overkill for 80% of tasks |
| Warden   | gemma4:31b-cloud | Consider smaller model (e.g., gemma3:12b) for routine checks | Hourly drift checks are mechanical, not reasoning-heavy |
| Forge    | gemma4:31b-cloud | gemma4:31b-cloud (keep)                   | Infra work needs reliability; keep current      |
| Ahsoka   | gemma4:31b-cloud | Consider smaller model for discovery templates | Template-heavy work; downgrade candidate        |
| Spark    | kimi-k2.6:cloud  | gemma4:31b-cloud (content), kimi for API integration | Social content generation doesn't need kimi's reasoning |

**Estimated cost impact:** Moving Aria from deepseek-v4-pro to gemma4:31b-cloud as default could reduce her per-session cost by 60–80% for routine business ops tasks.

---

## 4. Path Safety Analysis

### 4.1 Workspace Access Assessment

Based on the pattern observed in the discovery data — all agents have workspace-level access via their own workspace directories (workspace-architect, workspace-business, etc.). The key concern is cross-workspace write access and sensitive file exposure.

### 4.2 Over-Privilege Findings

| Agent        | Risk Level | Concern                                                                 | Current Overlap                  |
|--------------|------------|-------------------------------------------------------------------------|----------------------------------|
| **Spark ✨** | **HIGH**   | Marketing agent with 27KB context; rules reference db-read.sh. Should Spark have ANY DB access? | Shares rules with Aria, Luthen   |
| **Aria 🔵**  | **MEDIUM** | CEO business ops agent has deepseek-v4-pro access. Business ops tasks don't warrant top-tier model for routine work. | Shares rules with Luthen, Spark  |
| **Luthen 🔍**| **LOW**    | Marketing intel agent — verify no write access to business or governance directories. | Shares rules with Aria, Spark    |
| **Thrawn 🔵**| **LOW**    | Platform architect with 4 shared rules overlaps (highest in fleet). Ensure platform-arch workspace is read-only to other workspaces. | Shares with Lando, Mon M., Atlas |
| **Forge 🏗️** | **MEDIUM** | Infrastructure agent with workspace-infra access. Confirm no cross-workspace sudo/write capability without explicit Ken approval. | Shares rules with Warden          |

### 4.3 Recommended Write Scope Restrictions

1. **Spark** — Should NOT have access to `db-read.sh` or `db-write.sh`. Social media content generation has no legitimate need for database access. Restrict to workspace-social only.

2. **Aria** — Business operations workspace should be isolated from infrastructure and security workspaces. Verify `workspace-business` does not have cross-workspace write permissions.

3. **Luthen** — Marketing intelligence: read-only on shared state. No write access to any workspace outside workspace-luthen.

4. **General principle:** Agents should only have write access to their own workspace directory. Cross-agent data exchange should go through SHARED_CONTEXT.md (read-only) or explicit ticket-passing via Yoda.

5. **Forge** — The infrastructure agent has legitimate need for broad system access, but should require Ken approval for any destructive or cross-workspace operations. Flag for Shield review.

### 4.4 Critical Flags for Ken Approval

- **FLAG-01:** Spark's RULES.md references `db-read.sh`. Marketing agent with database access is a potential data exfiltration vector. Recommend immediate audit and removal.
- **FLAG-02:** Aria running deepseek-v4-pro:cloud for routine business ops tasks is a cost concern, not a security concern — but the model is over-privileged for the work performed 80% of the time.
- **FLAG-03:** The fleet-wide fallback chain (deepseek → gemma → kimi) is identical for 13 agents. If deepseek is down, all 13 agents cascade simultaneously — this is a single-point-of-contention risk.

---

## 5. Implementation Roadmap

### Phase 1 — Sprint 6 (Immediate Quick Wins)

| #   | Ticket                        | Description                                                    | Effort | Savings Impact    |
|-----|-------------------------------|----------------------------------------------------------------|--------|-------------------|
| 1.1 | TKT-0321                      | Update SHARED_CONTEXT.md — consolidate 9 most-duplicated rules | S      | 12–18% per specialist |
| 1.2 | TKT-0322                      | Trim duplicate rules from specialist RULES.md files (remove rules now in SHARED_CONTEXT) | M      | 15–25% per specialist |
| 1.3 | TKT-0323                      | Reduce Yoda RULES.md + YODA_RULES.md overlap — merge or tier   | M      | 20–30% of Yoda injection |
| 1.4 | TKT-0324                      | Adjust Aria model: gemma4:31b-cloud default, deepseek for complex tasks only | S      | 60–80% cost reduction on Aria sessions |
| 1.5 | TKT-0325                      | Audit and remove Spark's db-read.sh access (FLAG-01)           | S      | Security hardening |
| 1.6 | TKT-0326                      | Move HEARTBEAT.md tasks to cron jobs where possible; reduce Yoda injection | M      | 10–15% of Yoda injection |

**Phase 1 target:** 25–35% reduction in platform daily token burn.

### Phase 2 — Sprint 7+ (Structural Improvements)

| #   | Ticket                        | Description                                                    | Effort | Savings Impact    |
|-----|-------------------------------|----------------------------------------------------------------|--------|-------------------|
| 2.1 | TKT-0327                      | Implement progressive disclosure loader — Tier 0/Tier 1 routing | L      | 30–50% per specialist |
| 2.2 | TKT-0328                      | Build task-complexity routing table — model selection by task, not agent | L      | Variable (cost optimization) |
| 2.3 | TKT-0329                      | SHARED_CONTEXT.md as single source of truth for cross-cutting rules | M      | Eliminates duplication maintenance |
| 2.4 | TKT-0330                      | Agent-specific RULES.md reduced to domain methodology only (Tier 1) | L      | 40–65% per specialist |
| 2.5 | TKT-0331                      | Write scope enforcement — agent workspace isolation audit       | M      | Security hardening |
| 2.6 | TKT-0332                      | Diversify fallback chains — reduce single-point contention (FLAG-03) | S      | Resilience |

**Phase 2 target:** Additional 15–25% reduction, cumulative 40–55% vs baseline.

### Phase 3 — Post-OC2 (Platform Maturity)

| #   | Ticket                        | Description                                                    | Effort | Impact            |
|-----|-------------------------------|----------------------------------------------------------------|--------|-------------------|
| 3.1 | TKT-0333                      | Full platform context optimization — Yoda injection <50KB      | L      | 55–64% Yoda reduction |
| 3.2 | TKT-0334                      | Model cost governance dashboard — track per-agent, per-model spend | M      | Ongoing cost visibility |
| 3.3 | TKT-0335                      | Automated duplication detection — CI check for rule drift across workspaces | M      | Prevent regression |
| 3.4 | TKT-0336                      | Krennic SRE integration — infrastructure observability for context budgets | L      | Operations maturity |

**Phase 3 target:** Sustained 50–60% reduction vs baseline, automated governance.

---

## Summary of Recommendations

| Vector                   | Current State                  | Target State                        | Est. Improvement |
|--------------------------|--------------------------------|-------------------------------------|-------------------|
| Context duplication      | 92% duplicate rules            | <20% duplication (SHARED_CONTEXT)   | 40–65% tokens     |
| Yoda injection           | 123.8KB / session              | <50KB / session                     | 55–64% tokens     |
| Model-task fit           | Identity-based routing         | Complexity-based routing            | Cost optimization |
| Path safety              | Marketing agent has DB access  | Role-based write isolation          | Security hardening |
| Platform daily burn      | ~79,942 tokens/day             | ~32,000–40,000 tokens/day           | 50–60% reduction  |

---

## Approval Gates

| Gate  | Authority | Decision Required                                    |
|-------|-----------|------------------------------------------------------|
| G1    | Ken       | Approve Phase 1 quick wins (TKT-0321 through TKT-0326) |
| G2    | Ken       | Approve Spark db-read.sh removal (FLAG-01)            |
| G3    | Ken       | Approve Aria model downgrade (TKT-0324)               |
| G4    | Yoda      | Coordinate specialist RULES.md updates                |
| G5    | Shield    | Review path safety findings (Section 4)               |

---

*End of Assessment — DRAFT FOR REVIEW*
*Next: Ken approval → Phase 1 execution via Yoda orchestration*
