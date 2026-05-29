# Option Paper — Platform Separation: Business Stream Independence

**Document:** EA_Platform-Separation_Business-Stream_DRAFT_v1.0_2026-05-29  
**Author:** Atlas 🏛️ — Enterprise Architect  
**Requested by:** Ken Mun (CTO)  
**Classification:** DRAFT FOR REVIEW  
**Status:** Awaiting Ken approval

---

## 1. Executive Summary

**What is proposed:** Physically separate AInchors' Nexus platform into two independent OpenClaw instances — one dedicated to the business stream (Aria-led: client engagement, social/marketing, Angie/KL team operations) and one dedicated to the technical platform (Yoda-led: architecture, development, governance, infrastructure).

**Why now:** With the KL (Knowledge Leader) team pending onboarding (P1, 4-5 people) and new Mac Mini M4 Pro hardware arriving imminently (6-13 Jul 2026), this is the natural inflection point to assess whether business and technical workloads should live on separate hardware instances with independent governance and operational models.

**Strategic intent:** 
1. **Operational isolation** — business stream outages or model contention don't impact technical platform availability
2. **Access control simplification** — KL team access to OC3 (business instance) without exposure to internal architecture/development agents
3. **Governance clarity** — business agents operate under business rules; technical agents under engineering rules
4. **Hardware lifecycle** — extract maximum value from OC1 investment while OC2 provides the technical backbone

**Core question this paper answers:** Should we run two independent OpenClaw instances on separate hardware, or consolidate on the new OC2 hardware?

---

## 2. Current State

### 2.1 Hardware

| Asset | Spec | Current Role | Status |
|-------|------|-------------|--------|
| OC1 | Mac Mini M4, 24GB RAM | Primary — all 14 agents, PostgreSQL, all platform services | Active |
| OC2-A | Mac Mini M4 Pro, 48GB RAM | Planned — HIVE node A | ETA 6-13 Jul 2026 |
| OC2-B | Mac Mini M4 Pro, 48GB RAM | Planned — HIVE node B (HA standby) | ETA 6-13 Jul 2026 |

### 2.2 Agent Architecture (Current — OC1, Single Instance)

**14 active agents, single OpenClaw instance, no multi-node routing.**

| Agent | Stream | Role | Notes |
|-------|--------|------|-------|
| Yoda 🟢 | Technical | Architecture Orchestrator | Coordinates all architecture work |
| Aria 🔵 | Business | Lead Orchestrator (business) | Client engagement, Angie/KL interface |
| Shield 🛡️ | Governance | Security & Compliance | Cross-cutting |
| Lex ⚖️ | Governance | Legal & Regulatory | Cross-cutting |
| Sage 🧪 | Governance | Quality Assurance | Cross-cutting |
| Warden | Governance | Model/Policy Enforcement | Technical stream |
| Forge 🏗️ | Technical | Infrastructure & SRE | Build, deploy, monitoring, backup |
| Atlas 🏛️ | Technical | Enterprise Architect | This agent |
| Thrawn | Technical | AI Platform Architect | Nexus internals |
| Lando | Technical | Business Process | Process design |
| Mon Mothma | Technical | Change Management | Change governance |
| Ahsoka | Technical | (TBC) | TBC |
| Luthen | Technical | (TBC) | TBC |
| Spark ✨ | Business | Social & Marketing | Content, engagement |

**Parked:** Krennic (technical, parked — not active)

### 2.3 Business Stream — Current State

- **Lead:** Aria 🔵
- **Personnel:** Angie (business lead) + pending KL team (4-5 people, P1)
- **Agent complement:** Aria (orchestrator), Spark ✨ (social/marketing)
- **Current dependencies on tech stream:**
  - Governance Triad (Shield/Lex/Sage) — all agents share these
  - Forge — infrastructure operations (backup, monitoring)
  - PostgreSQL — shared database with all platform data
  - Single model endpoint — all agents share Ollama Cloud

### 2.4 Current Dependencies Between Streams

| Dependency | Business → Tech | Tech → Business | Risk if severed |
|------------|----------------|-----------------|-----------------|
| Governance Triad | Required | Required | Policy divergence |
| PostgreSQL | Shared schema | Shared schema | Data migration needed |
| Ollama Cloud | Shared account | Shared account | Account separation? |
| Forge (infra) | Backup, monitoring | All infra ops | OC1 needs own Forge |
| OpenClaw instance | Single instance | Single instance | Two separate lifecycle mgmt |
| Network | Same LAN | Same LAN | Minimal — same network |

### 2.5 TRIGGER State

- **TRIGGER-01:** OC2 hardware procurement → IN PROGRESS (ETA 6-13 Jul 2026)
- **TRIGGER-02:** Platform migration OC1→OC2 → PENDING (blocked on TRIGGER-01)
- **TRIGGER-10:** Business stream migration OC1→OC2 → DEFINED but not activated
- **TRIGGER-03:** KL team onboarding → PENDING (P1, post OC2 availability)

---

## 3. Options

### Option A: Clean Split (Ken's Proposal)

**Architecture:** OC1 (M4 24GB) → standalone business node. OC2-A/B (M4 Pro 48GB ×2) → technical HIVE HA pair. Two completely independent OpenClaw instances. No cross-node orchestration. No shared state.

**OC1 — Business Node (6 agents):**
- Aria 🔵 — lead orchestrator
- Governance Triad (duplicated): Shield 🛡️, Lex ⚖️, Sage 🧪
- Spark ✨ — social/marketing
- Forge 🏗️ — scoped to ops only (backup, monitoring, auto-heal, daily reports)
- **Total: 6 agents, 24GB RAM**

**OC2-A/B — Technical HIVE (HA pair, 48GB each):**
- Yoda 🟢 — lead orchestrator
- Governance Triad (original): Shield 🛡️, Lex ⚖️, Sage 🧪
- Atlas 🏛️, Thrawn, Forge 🏗️ (full SRE), Lando, Mon Mothma, Warden, Ahsoka, Luthen
- Krennic (parked)
- **Total: ~10 agents, 48GB each node (HA)**

**Assessment:**

| Dimension | Evaluation |
|-----------|------------|
| **Feasibility** | HIGH. OpenClaw supports independent instances. Two identical software stacks, separate configs. No custom development required. |
| **Cost** | MEDIUM. OC1 already owned (sunk cost). OC2-A/B already ordered. No new hardware beyond what's planned. Ollama Cloud: one account sufficient if key-based access, but two instances = 2× concurrent model calls = potential throughput contention on single $100/mo plan. May need second subscription (~$100/mo additional). Electricity: negligible delta (~$50/yr). |
| **Timeline** | 2-3 weeks post-OC2 arrival (~late Jul 2026). OC1 re-provisioning can begin now (wipe, fresh OpenClaw install). Business separation could complete before OC2 arrival if desired. |
| **Risks** | **(1) Governance divergence:** Two Triad instances = two policy evolution paths. Mitigation: policy-as-code in shared git repo, sync via cron/CI. **(2) OC1 hardware headroom:** M4 24GB running 6 agents + local PG. Model is Ollama Cloud (no local model RAM overhead), so 24GB is sufficient for 6 agent processes + PG. Adequate. **(3) OC1 single point of failure:** Business node has no HA. Acceptable for MVP/P1 — business continuity risk is low. **(4) Forge scoping:** OC1 Forge is ops-only. If OC1 OS breaks, manual intervention needed. Mitigation: document OC1 recovery runbook. |
| **Benefits** | Cleanest separation. Immediate (can start now on OC1). No cross-contamination. KL team gets clean OC1 instance with no tech agent exposure. Independent upgrade/maintenance windows. |

---

### Option B: OC2 Hosts Both (Status Quo Path)

**Architecture:** OC1 runs everything until OC2 arrives, then migrate all 14 agents to OC2-A/B HIVE pair. Business stream runs as an isolated workspace on OC2 — same physical hardware, separate OpenClaw workspace, not separate hardware.

**OC2-A/B — Unified HIVE (HA pair, 48GB each):**
- All 14 agents (business + tech) on shared HIVE infrastructure
- Business stream: isolated workspace, not isolated hardware
- No OC1 repurposing — OC1 becomes dev/test or retires

**Assessment:**

| Dimension | Evaluation |
|-----------|------------|
| **Feasibility** | HIGH. Simplest path — no architectural change. Single OpenClaw HIVE, single PostgreSQL, single config to maintain. OpenClaw workspace isolation provides logical separation. |
| **Cost** | LOWEST. No additional subscriptions. Single Ollama Cloud account (~$100/mo). OC1 electricity cost eliminated when retired. |
| **Timeline** | 4-6 weeks post-OC2 arrival (~Aug 2026). Must wait for OC2 before any migration. OC1→OC2 full platform migration is significant scope. |
| **Risks** | **(1) No real separation:** Logical workspace isolation ≠ physical separation. Business stream outage from model contention impacts tech stream. **(2) KL team access control:** Workspace-level access control required — more complex than physical separation. KL team could potentially access tech agents if ACL misconfigured. **(3) Resource contention:** 14 agents on 48GB HA pair. If any models run locally for dev/testing, RAM pressure. Ollama Cloud reduces this risk. **(4) Single failure domain:** HIVE HA protects against hardware failure, but configuration errors or model API issues affect both streams. **(5) TRIGGER-10 confusion:** "Business stream migration OC1→OC2" becomes a workspace move, not a hardware separation — may not satisfy original intent. |
| **Benefits** | Lowest complexity. Single governance Triad (no divergence). Single Forge (no duplication). HIVE HA for both streams. Cheapest ongoing cost. Fastest to implement (once OC2 arrives) if no hardware separation needed. |

---

### Option C: OC2-A Tech, OC2-B Business (Node-per-Stream)

**Architecture:** Repurpose OC2-B as dedicated business node instead of HA standby for OC2-A. OC2-A (48GB) runs tech solo (lose HA). OC2-B (48GB) runs business standalone. OC1 becomes dev/test or retires.

**OC2-A — Tech Node (solo, 48GB):**
- Yoda 🟢 + Governance Triad + all tech agents (~10 agents)
- No HA — single point of failure for tech platform
- 48GB provides comfortable headroom for all tech agents

**OC2-B — Business Node (standalone, 48GB):**
- Aria 🔵 + Governance Triad (duplicated) + Spark ✨ + Forge (ops-only)
- 48GB provides excellent headroom for 6 agents
- KL team accesses this node only

**OC1 — Retired or repurposed as dev/test sandbox**

**Assessment:**

| Dimension | Evaluation |
|-----------|------------|
| **Feasibility** | MEDIUM-HIGH. Technically identical to Option A but on better hardware. Requires accepting loss of HA for tech platform. |
| **Cost** | LOW. No new hardware — just repurpose what's ordered. Possibly second Ollama Cloud subscription (~$100/mo additional). OC1 electricity cost eliminated. |
| **Timeline** | 2-3 weeks post-OC2 arrival (~late Jul 2026). Must wait for OC2 delivery. OC1 wiped after migration confirmed. |
| **Risks** | **(1) Loss of HA:** Tech platform running solo on OC2-A. Hardware failure = total platform outage. Recovery: restore from backup to OC2-B (but OC2-B is running business — conflict). Mitigation: keep OC1 as cold standby for tech. **(2) Governance divergence:** Same as Option A. **(3) OC2-B over-provisioned:** 48GB for 6 agents is significant over-provisioning for MVP/P1. Justifiable if P2 business workload grows. **(4) Hardware commitment:** Loses flexibility of HA pair. If tech platform needs HA later, need new hardware. |
| **Benefits** | Best hardware for both streams (48GB each). Clean separation. Business gets premium hardware. OC1 freed for dev/test/experimentation. |

---

### Option D: Hybrid — OC1 Business Now, OC2-B Business Later

**Architecture:** Two-phase migration.

**Phase 1 (NOW — pre-OC2):**
- OC1 immediately re-provisioned as standalone business node (6 agents)
- OC1 runs business stream independently
- Tech stream continues on OC1??? **Problem:** Can't do this — tech stream needs a home. 

**Correction — Phase 1 (NOW):**
- OC1 continues running tech stream (Yoda + tech agents, ~10 agents) AND business stream is separated to... nothing. There's no second machine yet.

**Re-evaluated Architecture:**

This option only becomes viable as:

**Phase 1 (post-OC2 arrival, ~Jul 2026):**
- OC2-A/B arrive. OC2-A runs tech solo or HIVE pair with OC2-B
- OC1 immediately re-provisioned as business standalone (6 agents)
- Business stream gets immediate separation on OC1

**Phase 2 (future, when business workload justifies it):**
- Business stream migrated from OC1 (24GB) → OC2-B (48GB)
- OC2-A becomes tech solo (lose HA) OR new hardware acquired for tech HA
- OC1 becomes dev/test or retires

**Assessment:**

| Dimension | Evaluation |
|-----------|------------|
| **Feasibility** | MEDIUM. Phase 1 works (OC2-A HIVE for tech, OC1 for business). Phase 2 requires accepting loss of HA or buying new hardware — a downgrade in platform resilience. |
| **Cost** | MEDIUM (Phase 1), HIGH (Phase 2). Phase 1: no new hardware. Phase 2: either lose HA (risk cost) or buy replacement HA node (~$2-3K AUD). Two migrations = double the migration effort. |
| **Timeline** | Phase 1: 2-3 weeks post-OC2 (~Jul 2026). Phase 2: unbounded (when business needs justify). Total timeline: indefinite. |
| **Risks** | **(1) Two migrations = two disruption windows.** Business stream moves twice: tech→OC1, then OC1→OC2-B. Each migration carries data integrity risk. **(2) Phase 2 trigger undefined:** "When business workload justifies" is vague. Could never happen, leaving business on inferior hardware indefinitely. **(3) OC1 aging:** By Phase 2, OC1 may be 1-2 years old. Hardware depreciation. **(4) OC2-B stranded capacity:** 48GB machine waiting for Phase 2 trigger while business runs on 24GB. Waste during interim. |
| **Benefits** | Earliest possible business separation (Phase 1 starts immediately after OC2 arrives). Business gets dedicated hardware from Day 1 post-OC2. Phase 2 provides upgrade path if needed. No governance divergence in Phase 1 if Triad stays on tech node (business calls remotely). |

---

## 4. Option Comparison Matrix

| Criteria | Option A (Clean Split) | Option B (OC2 hosts both) | Option C (Node-per-stream) | Option D (Hybrid 2-phase) |
|----------|------------------------|---------------------------|----------------------------|---------------------------|
| **Cost (hardware + ongoing)** | $$$$ (OC1 sunk, OC2 ordered, possible 2nd Ollama Cloud $100/mo) | $$ (OC2 ordered, single Ollama Cloud $100/mo) | $$$ (OC2 ordered repurposed, possible 2nd Ollama Cloud $100/mo, OC1 retired) | $$$$ (same as A for Phase 1; Phase 2 may need new hardware $2-3K) |
| **Timeline to separation** | 🟢 Fastest — OC1 reprovisioning can begin now. Business separation possible pre-OC2 arrival (if tech can run temporarily on OC1 post-wipe? No — OC1 IS the business node. Tech needs OC2.) | 🔴 Slowest — must wait for OC2, then full platform migration before any separation occurs | 🟡 Medium — must wait for OC2 arrival, then parallel provisioning | 🟡 Medium — Phase 1 waits for OC2; business separation on OC1 immediately after OC2 tech migration |
| **Technical complexity** | 🟡 Medium — two independent OpenClaw installs, two PG instances, policy sync mechanism | 🟢 Low — single HIVE, single PG, no duplication | 🟡 Medium — two independent installs (like A) but on identical HW configs | 🔴 High — two-phase migration, shifting hardware roles, two disruption windows |
| **Angie/KL team experience** | 🟢 Best — clean dedicated instance, no tech agent visibility, simple access control | 🔴 Worst — workspace ACL complexity, risk of tech exposure, shared resource contention | 🟢 Best — clean dedicated instance (like A), better hardware than A | 🟡 Good initially (Phase 1 on OC1 24GB), better later (Phase 2 on 48GB) |
| **Governance integrity** | 🔴 Risk — two Triad instances = policy divergence without sync mechanism | 🟢 Best — single Triad, single source of truth | 🔴 Risk — same as A | 🟢 Phase 1 (Triad on tech, business calls remote); 🔴 Phase 2 (Triad duplicated) |
| **Platform resilience (HA)** | 🟡 Business: no HA. Tech: HA pair (OC2-A/B) | 🟢 Best — HIVE HA for everything | 🔴 Worst — tech solo (no HA), business solo (no HA) | 🟡 Phase 1: Tech HA, Business solo. 🔴 Phase 2: Tech solo, Business solo |
| **Operational overhead** | 🔴 Highest — two instances to patch, monitor, backup, maintain. Two Forge configurations. | 🟢 Lowest — single instance, single Forge, single backup | 🔴 Highest — same as A | 🔴 Highest — same as A, plus two migrations |
| **Future scalability** | 🟡 Business: 24GB may constrain P2 growth. Tech: 48GB HA pair scales well. | 🟢 Best — 48GB HA pair with headroom for both streams | 🟡 Business: 48GB oversupplied for P1, good for P2. Tech: 48GB solo — tight if agent count grows. | 🟡 Phase 1: Business on 24GB. Phase 2: Business on 48GB. But tech loses HA. |
| **Risk score (1-5, lower=better)** | **3** — Governance divergence, OC1 SPOF for business | **2** — No real separation, ACL complexity, single failure domain | **4** — No HA anywhere, governance divergence, hardware commitment | **3.5** — Two migration risks, undefined Phase 2 trigger, eventual HA loss |

---

## 5. Key Considerations

### 5.1 Governance Triad Duplication

**Problem:** Options A, C, and Phase 2 of D require two copies of Shield 🛡️, Lex ⚖️, and Sage 🧪 — one on business node, one on tech node. Over time, each Triad instance will accumulate context, refine policies, and potentially diverge.

**Risk:** Policy divergence leads to inconsistent security postures, compliance gaps, and QA standards drift between business and tech streams.

**Mitigation options:**
1. **Policy-as-code in shared git repo** — Both Triad instances read from the same policy files. Cron/CI sync ensures consistency. Triad agents treat policy files as authoritative.
2. **Triad stays on tech node, business calls remotely** — Business agents call Shield/Lex/Sage via OpenClaw remote agent API. Single Triad, single policy source. Requires cross-instance API calls (adds latency, coupling). Not "completely independent" but governance remains unified.
3. **Triad + Warden cross-platform sync** — Both instances run Triad, but Warden (on tech node) periodically audits business Triad for divergence and raises alerts.

**Recommendation:** Mitigation option 1 (policy-as-code) for Options A/C. Governance policy files are the source of truth, stored in git, synced to both instances. This preserves independence while preventing divergence.

### 5.2 Forge Scoping — Business Node

**On business node, Forge is ops-only:** backup, monitoring, auto-heal, daily reports. No build pipelines, no SRE responsibilities, no deployment orchestration.

**Question:** Is an ops-only Forge sufficient for OC1 standalone maintenance?

**Assessment:**
- **Backup:** Yes — standard OpenClaw backup procedures, PostgreSQL dumps. Forge can run these.
- **Monitoring:** Yes — health checks, disk usage, memory pressure, model API responsiveness.
- **Auto-heal:** Yes — restart failed agents, rotate logs, clear caches.
- **OS patching:** PARTIAL — Forge can detect and report, but macOS system updates typically require manual intervention or MDM. Forge can script `softwareupdate` but risk of breaking changes is real.
- **Hardware failure:** NO — physical issues require human intervention. Acceptable for MVP/P1.
- **Network/DNS:** LIMITED — Forge can detect outages, can't reconfigure router/firewall.

**Gap:** If OC1 experiences a non-trivial failure (disk corruption, OS kernel panic loop, network misconfiguration), ops-only Forge cannot recover. Mitigation: document OC1 recovery runbook, keep OS installer USB, maintain configuration-as-code.

### 5.3 Cost Model

| Line Item | Option A | Option B | Option C | Option D |
|-----------|----------|----------|----------|----------|
| Hardware (sunk) | OC1: ~$1,000 | OC1: ~$1,000 | OC1: ~$1,000 | OC1: ~$1,000 |
| Hardware (ordered) | OC2-A/B: ~$4-5K | OC2-A/B: ~$4-5K | OC2-A/B: ~$4-5K | OC2-A/B: ~$4-5K |
| Ollama Cloud | 1-2× $100/mo | 1× $100/mo | 1-2× $100/mo | 1-2× $100/mo |
| Electricity (est.) | ~$30/mo (OC1+OC2) | ~$20/mo (OC2 only) | ~$25/mo (OC2 only) | ~$30/mo (OC1+OC2 → OC2 only) |
| Additional HW | None | None | None | Possible $2-3K for Phase 2 HA replacement |
| Annual run rate | ~$1,560-2,760 | ~$1,440 | ~$1,500-2,700 | ~$1,560-2,760 + possible $2-3K |

**Ollama Cloud question:** Does the $100/mo fixed plan support concurrent requests from two separate OpenClaw instances? If rate-limited, second subscription needed. If concurrent requests share the same quota, single subscription works but throughput halves per instance under load.

### 5.4 Data Separation

**Current state:** Single PostgreSQL instance on OC1 contains all platform data — business conversations, technical architecture docs, governance policies, agent state, user data.

**For any separation option:**
1. **Schema audit** — Identify business-only tables vs tech-only tables vs shared tables (governance, user auth)
2. **Data migration** — Business data extracted and migrated to business PG instance
3. **Data wipe** — After migration verified, business data removed from tech PG
4. **Shared reference data** — Governance policies, user accounts — replicated to both instances or kept on tech with API access

**Risk:** If business PG contains technical data (e.g., Aria discussions referencing architecture decisions), data classification exercise needed before migration. GDPR/privacy implications if KL team gains access to PG backups containing non-business data.

### 5.5 Angie/KL Team Onboarding

**Context:** P1 KL team (4-5 people) need access to OC3 (business-facing instance). Their workflow:
- Interact with Aria for client engagement
- Access business documents, proposals, client deliverables
- Potentially use Spark for social/marketing content
- Must NOT access technical architecture, development agents, internal platform state

**Impact on options:**
- **Option A/C:** Cleanest. KL team gets OC1/OC2-B credentials. No path to tech agents. Simple ACL.
- **Option B:** Worst. Workspace-level ACL on shared HIVE. Risk of misconfiguration exposing tech agents. KL team shares model throughput with tech agents.
- **Option D:** Good for Phase 1 (clean OC1), complex for Phase 2 migration.

### 5.6 OC1 Hardware Sufficiency

**Question:** Is M4 24GB sufficient for 6 agents (Aria, Shield, Lex, Sage, Spark, Forge-ops)?

**Analysis:**
- **Model:** DeepSeek V4 Pro via Ollama Cloud. No local model RAM overhead. Each agent process consumes ~500MB-1GB for runtime (Node.js process, context window, tool state).
- **6 agents × 1GB = 6GB** for agent processes
- **PostgreSQL:** ~2-4GB for shared buffer + connections
- **OpenClaw runtime:** ~2GB
- **OS overhead:** ~4GB
- **Total estimated:** ~14-16GB
- **Headroom:** ~8-10GB

**Verdict:** 24GB is sufficient for 6 cloud-model agents with comfortable headroom. If any agent requires local model inference (e.g., small embedding model for document search), headroom remains adequate. Not generous, but adequate for P1 workload.

**Contrast with Option C (OC2-B 48GB for business):** Significant over-provisioning at P1. Justifiable only if P2 business workload expands to include local models or additional agents.

### 5.7 TRIGGER-10: Redefinition Required

**Current definition:** "Business stream migration OC1→OC2"

**Impact of this decision:**
- **Options A/C/D:** TRIGGER-10 is partially obsolete. Business stream migrates to separate hardware, not OC2. TRIGGER-10 should be redefined as "Business stream platform separation" with the chosen option's target architecture.
- **Option B:** TRIGGER-10 remains valid but scope changes from "separate hardware" to "workspace migration to OC2."
- **All options:** TRIGGER-10 should be split into sub-triggers: data migration, agent provisioning, access control, validation.

**Recommendation:** Redefine TRIGGER-10 post-decision to reflect the chosen option's specific migration path.

### 5.8 Timeline Alignment with OC2 ETA (6-13 Jul 2026)

**Can business separation happen before OC2 arrives?**

| Scenario | Feasibility |
|----------|-------------|
| Business on OC1, tech stays on OC1 | ❌ Impossible — OC1 can only run one OpenClaw instance (or two with port separation, unsupported complexity) |
| Business on OC1 new instance, tech on OC1 old instance | ❌ Not supported without containerization/virtualization — out of scope |
| Business on OC1, tech migrated to cloud interim | ❌ No cloud OpenClaw hosting in architecture |

**Conclusion:** Business separation to dedicated hardware cannot happen before OC2 arrives, unless a third machine is provisioned. OC1 must continue running both streams until OC2 takes over the tech workload.

**Exception:** If Ken acquires a temporary machine (e.g., Mac Mini base model ~$800) for business stream, separation could begin now. Not recommended — wait for OC2.

---

## 6. Recommendation

### Preferred Option: **Option A — Clean Split** (with governance mitigation)

**Rationale:**

1. **Best alignment with strategic intent** — Ken's original proposal calls for complete independence. Option A delivers this with minimal deviation.

2. **Earliest practical separation** — OC1 re-provisioning can be scripted and tested now (dry run). When OC2 arrives, tech stream migrates to OC2-A/B, and OC1 is immediately available for business. No waiting for second migration phase.

3. **Best KL team experience** — Clean, dedicated hardware with no path to tech agents. Simple access control. No ACL complexity.

4. **Preserves HIVE HA for tech platform** — OC2-A/B HA pair protects the technical platform (the core IP). Business node being non-HA is acceptable risk for MVP/P1 — if OC1 fails, business disruption is limited (manual fallback to direct communication).

5. **Maximises hardware ROI** — OC1 (already purchased) continues delivering value instead of becoming a dev/test afterthought. OC2-A/B used as designed (HA pair).

6. **Reversible** — If separation proves problematic, OC1 business agents can be migrated to OC2 as workspaces (fallback to Option B). Hardware separation to consolidation is easier than consolidation to separation.

**Primary risk (governance divergence) is mitigated via:** Policy-as-code in shared git repository. Both Triad instances read from the same authoritative policy files. Warden (tech node) performs periodic divergence audits. This preserves platform independence while maintaining governance consistency.

### Pre-conditions

1. **Governance policy-as-code repository established** — Shield/Lex/Sage policies extracted to version-controlled files before duplication
2. **Forge ops-only runbook documented** — OC1 Forge scope, capabilities, and limitations clearly specified
3. **Data classification exercise completed** — Identify business-only vs tech-only vs shared data in current PG
4. **Ollama Cloud concurrency confirmed** — Verify whether $100/mo plan supports two independent instance connections without rate limiting
5. **OC1 recovery runbook** — Documented procedure for OC1 OS failure recovery
6. **TRIGGER-10 redefined** — Split into: data migration, OC1 provisioning, agent deployment, access control, validation, cutover

### Phased Migration Plan (High-Level)

**Phase 0 — Preparation (Now → OC2 arrival, ~2-4 weeks)**
- Establish governance policy-as-code repo
- Document Forge ops-only runbook
- Complete data classification exercise
- Script OC1 clean-provisioning (automated OpenClaw install + agent config)
- Dry-run OC1 re-provisioning on a VM if possible
- Confirm Ollama Cloud multi-instance support

**Phase 1 — OC2 Tech Migration (Week of OC2 arrival, ~1 week)**
- Unbox, provision OC2-A/B
- Install OpenClaw HIVE on OC2-A/B
- Migrate tech agents + Governance Triad to OC2
- Migrate tech PostgreSQL data to OC2
- Validate tech platform on OC2
- **Gate check:** All tech agents operational on OC2 before touching OC1

**Phase 2 — OC1 Business Provisioning (Week 2, ~1 week)**
- Wipe OC1 (after tech migration confirmed)
- Fresh macOS (if needed) + OpenClaw standalone install
- Deploy business agents: Aria, Shield (copy), Lex (copy), Sage (copy), Spark, Forge (ops-only)
- Restore business data from tech PG backup
- Configure policy-as-code sync from shared repo
- **Gate check:** All 6 business agents operational

**Phase 3 — Validation & Cutover (Week 3, ~3-5 days)**
- End-to-end testing: Aria → client workflow, Spark → social workflow
- Governance sync verification: policy changes on tech Triad reflected on business Triad within sync interval
- KL team access testing (simulated)
- Backup validation on both instances
- **Go/No-Go:** Ken approval for production cutover
- Cutover: Angie/KL team directed to OC1 business instance

**Phase 4 — Stabilisation (Week 4+, ongoing)**
- Monitor both instances for 2 weeks
- Governance divergence audit (Warden, weekly)
- Performance baseline: OC1 memory/CPU under business load
- TRIGGER-10 closed; new operational triggers created for ongoing maintenance

**Total timeline: ~4 weeks post-OC2 arrival → Late Jul / Early Aug 2026**

---

## Appendix A: Assumptions

1. OpenClaw supports two completely independent instances on the same LAN without conflict (port assignment, agent naming)
2. Ollama Cloud $100/mo plan supports multiple concurrent connections OR a second subscription is acceptable cost
3. DeepSeek V4 Pro remains the primary model for both streams
4. OC2-A/B HIVE configuration is compatible with the current agent architecture
5. No regulatory/compliance requirements mandate physical separation (separation is for operational/access control reasons)
6. KL team onboarding timeline is flexible — can align with Phase 3 cutover
7. OC1 hardware is in good health and expected to remain reliable through P1 (6-12 months)

## Appendix B: Decisions Required from Ken

| # | Decision | Impact |
|---|----------|--------|
| D1 | Approve Option A as preferred architecture | Triggers Phase 0 preparation |
| D2 | Approve governance duplication with policy-as-code mitigation | Two Triad instances, shared policy repo |
| D3 | Approve second Ollama Cloud subscription if needed (~$100/mo) | Budget impact |
| D4 | Confirm KL team onboarding target date | Aligns Phase 3 cutover |
| D5 | Approve Forge ops-only scope on OC1 | Defines business node support boundaries |
| D6 | Authorise OC1 wipe post-OC2 tech migration | Irreversible — requires Phase 1 gate check pass |
| D7 | Approve TRIGGER-10 redefinition | Change management process |

---

*This document is DRAFT FOR REVIEW. No architecture decisions are final until approved by Ken Mun (CTO). All timelines are estimates and subject to OC2 delivery schedule.*

*Atlas 🏛️ — Enterprise Architect, AInchors Nexus Platform*
