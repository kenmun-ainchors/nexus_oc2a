# OC2A Fresh Install Plan — Option 4: Strong Separation

**Document:** OC2A-Fresh-Install-Plan-v1.0.md  
**Author:** Yoda 🟢 (Lead Orchestrator)  
**Date:** 2026-07-12  
**Classification:** DRAFT FOR REVIEW  
**Status:** Pending Ken approval

---

## 1. Executive Summary — Option 4 Chosen

Ken selected **Option 4: OC2A self-governs; OC1 is truly sandbox only**. This is the strongest separation model.

**Core principle:**
- **OC2A** is the sole authority for production Nexus operations.
- **OC1** is a non-privileged dev/test/sandbox. It may experiment, but it **cannot** push changes or execute commands on OC2A.
- **Configuration flow is one-way:** OC1 sandbox → manual review → reimplemented on OC2A by its own Forge/Yoda.
- **Yoda on OC1** can still observe OC2A in read-only mode for awareness, but not control it.

This removes the high-risk scenario where a compromised or misconfigured OC1 sandbox can destroy production.

---

## 2. Target Architecture

| Node | Role | Can write to OC2A? | Can read OC2A? | Primary Yoda for Ken |
|---|---|---|---|---|
| **OC2A** | Production — Full Nexus | Self only | Self | **Primary production orchestrator** |
| **OC1** | Dev / Test / Sandbox | **No** | Yes (read-only health/logs) | Sandbox/dev experimentation only |
| **OC2B** | TBD — planned after OC2A | TBD | TBD | TBD |

### 2.1 OC2A — Fresh OpenClaw Full Production

- **Hardware:** Mac Mini M4 Pro, 48GB RAM
- **Network:** Tailscale tailnet (`ainchorsoc2as-mac-mini.tailfc3ed1.ts.net`, `100.112.241.16`)
- **OpenClaw mode:** `local` gateway, fresh profile/workspace
- **Base port:** `18789` (production, per port convention)
- **Ollama:** Cloud-only via shared Ollama Cloud account
- **PostgreSQL:** Local PG on OC2A for all platform data (tickets, sprints, cost, state, memory)
- **Agents:** Full current fleet, same roles and names as OC1 today:
  - `main` (Yoda 🟢) — lead orchestrator; Ken connects here for primary ops
  - `business` (Aria 🔵) — business lead
  - `architect` (Atlas 🏛️) — enterprise architecture
  - `platform-arch` (Thrawn) — AI platform architecture
  - `infra` (Forge 🏗️) — build, SRE, ops
  - `ahsoka` — client discovery / consulting
  - `social` (Spark ✨) — social/marketing
  - `biz-process` (Lando) — business process design
  - `change-mgt` (Mon Mothma) — change governance
  - `security` (Shield 🛡️) — security & compliance
  - `legal` (Lex ⚖️) — legal & regulatory
  - `qa` (Sage 🧪) — quality assurance
  - `governance` (Warden) — model/policy enforcement
  - `luthen` — queued for P2
- **Channels:** All current channels (Telegram Ken/Angie, LinkedIn, webchat, crons)
- **Tailscale expose:** `serve` mode for tailnet access
- **Note:** This is a fresh install, not a clone of OC1. Configuration will be rebuilt to match current production intent, without carrying forward OC1 drift.

### 2.2 OC1 — Dev/Test/Sandbox Only

- **No admin path to OC2A.**
- No OC2A gateway token stored.
- No OC2A SSH key stored.
- No OpenClaw node pairing to OC2A as a control channel.
- Can run local experiments and validate changes in isolation.
- Read-only observability of OC2A via public health endpoints or shared logs (if exposed).
- Retain historical OC1 data for reference; new canonical data lives on OC2A PG.
- Runs a minimal sandbox fleet: Yoda (main), Forge (infra sandbox), Atlas (architect sandbox), plus any agents needed to reproduce production issues.

---

## 3. OC1 → OC2A Control Surface Under Option 4

| Capability | Under Option 1 | Under Option 4 |
|---|---|---|
| SSH / Tailscale SSH from OC1 to OC2A | Yes | **No** |
| OC2A gateway API token on OC1 | Yes | **No** |
| OpenClaw node pairing (OC1 controls OC2A node) | Yes | **No** |
| Read OC2A public health endpoint | Maybe | **Yes** |
| View shared log target (e.g., NAS, cloud) | Yes | **Yes** |
| Push config/scripts from OC1 to OC2A | Yes | **No** |
| Restart/recover OC2A from OC1 | Yes | **No** — must be done on OC2A or by Ken directly |

**Security outcome:** OC1 compromise cannot be used to attack OC2A production.

---

## 4. Operational Model Under Option 4

### 4.1 Production changes happen on OC2A

- Forge on OC2A installs, updates, and repairs OC2A.
- Yoda on OC2A orchestrates production agents.
- Ken connects to Yoda on OC2A as primary.

### 4.2 Sandbox changes happen on OC1

- Forge on OC1 experiments freely.
- Yoda on OC1 tests new patterns in isolation.
- Nothing auto-propagates from OC1 to OC2A.

### 4.3 Promotion path: OC1 → review → OC2A

When a sandbox change is proven useful:

1. **Document it** in OC1 workspace (architecture note, CHG plan, script diff).
2. **Yoda on OC1 packages the proposal** for Ken/OC2A review.
3. **Ken approves** the change for production.
4. **Yoda/Forge on OC2A reimplements it** from the approved spec, not by copying OC1 files.
5. **Sage on OC2A verifies** the production implementation.

This is slower but eliminates config drift and sandbox contamination.

---

## 5. Implementation Plan (Option 4 Adjustments)

### Phase 0 — Access & Preparation (Option 4)

**Goal:** Enable safe, direct admin access to OC2A for its own setup. OC1 must end this phase with zero OC2A admin credentials.

| # | Task | Owner | Evidence |
|---|---|---|---|
| 0.1 | Enable Remote Login / Tailscale SSH on OC2A for **Ken direct access only** | Ken | `ssh info@oc2a.tailnet` succeeds from Ken's admin path |
| 0.2 | Verify Tailscale reachability from OC1 | Yoda on OC1 | `tailscale ping` passes |
| 0.3 | Confirm no OC1→OC2A control credentials stored on OC1 | Yoda | Audit: no tokens/keys in OC1 workspace or Keychain for OC2A admin |
| 0.4 | Document read-only observability path from OC1 to OC2A | Yoda | Health endpoint or shared log access confirmed |
| 0.5 | Prepare OC2A fresh-install runbook / script for execution **on OC2A** | Forge on OC2A | Script reviewed by Yoda on OC2A |

**Gate:** OC2A can be reached by its own Yoda/Forge; OC1 has no admin path.

### Phase 1 — Fresh OpenClaw Install on OC2A (Option 4)

**Goal:** Standalone OpenClaw production instance, built and operated from OC2A.

| # | Task | Owner | Evidence |
|---|---|---|---|
| 1.1 | Install OpenClaw CLI on OC2A (`npm install -g openclaw@latest` or brew) | Forge on OC2A via direct access | `openclaw --version` returns target version |
| 1.2 | Run `openclaw onboard` with fresh profile/workspace | Forge on OC2A | `~/.openclaw/openclaw.json` created |
| 1.3 | Configure gateway: mode=local, port=18789, bind=loopback or tailnet | Forge on OC2A | `openclaw config validate` passes |
| 1.4 | Install gateway + node LaunchAgents / services | Forge on OC2A | `openclaw gateway status` shows running |
| 1.5 | Configure Tailscale serve for OC2A gateway | Forge on OC2A | `tailscale serve status` shows proxy to 127.0.0.1:18789 |
| 1.6 | Set `gateway.auth.allowTailscale=true` and token auth | Forge on OC2A | `openclaw qr --json` returns wss:// URL |
| 1.7 | Test OC2A gateway health from OC2A itself | Yoda on OC2A | `openclaw status` healthy |
| 1.8 | Test OC2A gateway health from OC1 (read-only, no auth) | Yoda on OC1 | HTTP/Tailscale reachability only |

**Gate:** OC2A gateway healthy and self-administered.

### Phase 2 — Agent Provisioning (Option 4)

**Goal:** Deploy full agent fleet on OC2A.

| # | Task | Owner | Evidence |
|---|---|---|---|
| 2.1 | Create OC2A workspace structure: `SOUL.md`, `AGENTS.md`, `USER.md`, `MEMORY.md`, `HEARTBEAT.md` | Forge / Aria on OC2A | Files present, ≤ size limits |
| 2.2 | Configure all agents: Yoda, Aria, Atlas, Thrawn, Forge, Ahsoka, Spark, Lando, Mon Mothma, Shield, Lex, Sage, Warden | Forge on OC2A | `openclaw.json` agent list correct |
| 2.3 | Set model policy per CREST v1.3 / `state/model-policy.json` canonical baseline | Yoda on OC2A | `state/model-policy.json` valid |
| 2.4 | Set skills allowlists per agent | Forge on OC2A | Skill indexes validated |
| 2.5 | Configure channels: Telegram Ken/Angie, LinkedIn, webchat | Forge on OC2A | Channel status enabled |
| 2.6 | Configure memory wiki / PG state | Forge on OC2A | `openclaw memory status` ok |
| 2.7 | Smoke-test each agent with a hello task | Yoda on OC2A | All agents respond correctly |

**Gate:** Full fleet operational on OC2A.

### Phase 3 — Data, Config & Operational Readiness (Option 4)

**Goal:** Migrate or rebuild production data, backups, monitoring, and governance on OC2A.

| # | Task | Owner | Evidence |
|---|---|---|---|
| 3.1 | Install and configure local PostgreSQL on OC2A | Forge on OC2A | `pg_isready` returns accepting connections |
| 3.2 | Initialize full platform schema (tickets, sprint, cost, state, memory, changelog) | Forge on OC2A | Schema migration applied |
| 3.3 | **Migrate essential production data from OC1 to OC2A** via validated export/import | Forge on OC2A | Data verification query passes |
| 3.4 | Configure daily backup to NAS / cloud target | Forge on OC2A | Backup script runs, test restore OK |
| 3.5 | Configure health checks and alerts routed to Ken + Angie | Forge on OC2A | Alert test delivered |
| 3.6 | Port governance policies and rules to OC2A workspace from canonical git baselines | Lex / Shield / Sage / Warden on OC2A | `SOUL.md`, `AGENTS.md`, `RULES.md`/`YODA_RULES.md` present and validated |
| 3.7 | Document OC2A runbook and recovery procedures | Mon Mothma / Forge on OC2A | Runbook in `docs/runbooks/` |

**Data migration rules under Option 4:**
- Export from OC1 in a validated, versioned format.
- Inspect and approve the export before import.
- Import on OC2A only after schema and policy checks.
- No live OC1→OC2A replication or file sync.

**Gate:** Backup, monitoring, and governance in place.

### Phase 4 — Validation & Cutover (Option 4)

**Goal:** Confirm OC2A is ready as the standalone production Nexus.

| # | Task | Owner | Evidence |
|---|---|---|---|
| 4.1 | End-to-end workflow test: Yoda on OC2A routes a task through Atlas/Thrawn/Forge and reports back | Yoda on OC2A | Workflow completes with audit trail |
| 4.2 | Business workflow test: Aria + Spark + governance review | Aria on OC2A | Workflow completes |
| 4.3 | Ken connects with Yoda on OC2A via webchat and confirms primary control | Ken + Yoda on OC2A | Active `agent:main:dashboard` session on OC2A |
| 4.4 | Verify OC1 cannot authenticate to OC2A gateway | Yoda on OC1 | Auth failure expected and logged |
| 4.5 | Verify OC1 cannot SSH to OC2A | Yoda on OC1 | Connection failure expected and logged |
| 4.6 | Failover / recovery drill: restart OC2A gateway, verify auto-start | Forge on OC2A | Service returns within RTO target |
| 4.7 | Sign-off from Ken | Ken | Go/No-Go decision recorded |

**Gate:** Ken/Angie approve standalone production use.

### Phase 5 — OC1 Demotion (Option 4)

**Goal:** Reconfigure OC1 as a true non-production sandbox with zero OC2A control surface.

| # | Task | Owner | Evidence |
|---|---|---|---|
| 5.1 | Strip any OC2A credentials that may have been temporarily used during setup | Forge on OC2A + Yoda on OC1 | Keychain/workspace audit clean |
| 5.2 | Disable production channels/crons on OC1 (Telegram, LinkedIn posting, daily close) | Forge on OC1 | Only sandbox/test channels remain |
| 5.3 | Stop or disable non-essential agents on OC1; retain sandbox copies of Yoda/Forge/Atlas for validation | Forge on OC1 | `openclaw agents list` shows sandbox roster |
| 5.4 | Relabel OC1 in documentation and monitoring | Yoda | Docs updated |
| 5.5 | Verify OC1 cannot accidentally route production traffic | Yoda | Channel bindings and crons point nowhere or to OC2A endpoints |
| 5.6 | Establish documented promotion path: OC1 sandbox → review → OC2A reimplementation | Yoda / Forge | Runbook in `docs/runbooks/oc1-to-oc2a-promotion.md` |
| 5.7 | Repurpose OC1 storage/state for sandbox/experiments | Forge on OC1 | Sandbox workspace created |

**Gate:** OC1 is clearly non-production and has no admin path to OC2A.

---

## 6. Risks & Mitigations (Option 4)

| Risk | Impact | Mitigation |
|---|---|---|
| Slower iteration (no auto-push from OC1) | Medium | Clear promotion spec; use git/Notion for handoff |
| Recovery requires direct OC2A access | Medium | Tailscale SSH + Ken direct access; document runbook on OC2A |
| OC1 becomes isolated/less useful | Low | OC1 still valuable for risky experiments and reproduction |
| Governance drift between OC1 and OC2A | Medium | Shared git repo for canonical policies; promotion process enforces reimplementation |
| Ollama Cloud contention from two instances | Medium | Monitor request rates; upgrade plan if needed |
| OC2A remote access not available | Blocking | Enable Remote Login / Tailscale SSH as first step |
| Data migration complexity | Medium | Scope to essential data; validate before import |
| OC2A hardware/software issues during fresh install | Medium | Use tested runbook; keep OC1 operational as fallback |

---

## 7. Decisions Required from Ken (Option 4)

| # | Decision | Default |
|---|---|---|
| D1 | Approve Option 4 strong-separation model | **Yes — per Ken's direction** |
| D2 | Approve OC2A as fresh production Nexus | Yes |
| D3 | Approve OC1 as non-privileged sandbox | Yes |
| D4 | Authorise Remote Login / Tailscale SSH on OC2A for direct admin access | Required |
| D5 | OC2A full agent roster | Yes |
| D6 | Shared Ollama Cloud account | Yes |
| D7 | Data migration scope = essential production data only | Yes |
| D8 | Port governance policies to OC2A via canonical repo | Yes |
| D9 | Defer OC2B planning until OC2A validated | Yes |

---

## 8. Next Steps

1. **Ken reviews and approves** this Option 4 plan.
2. **Create CHG record** for OC2A fresh install under strong-separation model.
3. **Create tickets** per phase.
4. **Update `state/chg-triggers.json`** to reflect new topology.
5. **Begin Phase 0** once Ken enables Remote Login / Tailscale SSH on OC2A.

---

*This document is DRAFT FOR REVIEW. No actions until approved by Ken Mun (CTO).*
