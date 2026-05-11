# EA Assessment: AInchors Sandbox Environment
**Document:** EA_TKT-0135_SandboxEnv_DRAFT_v1.0_2026-05-14
**Ticket:** TKT-0135 | **Sprint:** 3 (12–18 May 2026)
**Author:** Atlas (Enterprise Architect)
**Status:** DRAFT FOR REVIEW — Pending Ken Mun approval
**Notion Page:** 35cc1829-53ff-81b6-a95e-d7c8367f7d5a

---

## 1. Executive Summary

**Recommended Option: A — Docker-based isolated OpenClaw instance (Colima)**

Docker on the existing Colima runtime delivers all four mandatory properties (Isolated, Ephemeral, Managed, Contained) with the lowest implementation risk and fastest path to Sprint 3 delivery. Colima is already installed and proven on OC1. A purpose-built compose stack gives Ken and Angie a single-command spin-up/teardown, a MinIO isolated bucket for any demo data, strict network namespace separation from OC1 production, and zero residual state after teardown. No new infrastructure is required. OC2 (Option D) is noted as the strategic end-state but cannot gate Sprint 3.

---

## 2. Options Analysis

### Option A — Docker / Colima Isolated Instance ✅ RECOMMENDED

**Description:** A Docker Compose stack running a fully self-contained OpenClaw instance, isolated agent workspace, and a dedicated MinIO bucket — all under Colima's existing socket. Single `make sandbox-up` / `make sandbox-down` interface.

| Dimension | Detail |
|---|---|
| **Isolation** | Full network namespace + separate compose project. Cannot reach OC1 containers or host services unless explicitly bridged. |
| **Ephemerality** | `docker compose down -v` destroys all volumes, credentials, and state. Verified via teardown script. |
| **Managed** | Compose file + Makefile = single-command lifecycle. Pre-seeded demo agents/data baked into image or init script. |
| **Contained** | Separate credential store (env-file, not host keychain). Tailscale not exposed into container by default. |
| **OC1 Impact** | Colima resource cap configurable. Recommend 4 vCPU / 6 GB RAM cap — leaves 18 GB for OC1 prod on M4 24 GB. |
| **Security (S1–S7)** | Sandbox creds never touch OC1 keychain. No shared secrets. MinIO isolated bucket (not prod bucket). |

**Pros:**
- Colima + Docker already on OC1 — zero new tooling
- Full ephemerality guaranteed by compose volumes
- Demo data/agents scriptable via init container or seed script
- Resource quotas enforceable at Colima level
- Fastest Sprint 3 delivery (~2–3 days implementation)
- Teardown is deterministic and auditable

**Cons:**
- Colima socket access means container escape = host access (mitigated by no privileged containers, no host mounts outside workspace-sandbox)
- Performance varies under load — needs resource cap discipline
- macOS-specific Docker socket path; not portable to future Linux host without minor changes

**Risk:** LOW
**Effort:** LOW — 2–3 days build, 1 day test/verify

---

### Option B — VM Snapshot (macOS or Linux VM)

**Description:** A lightweight VM (e.g., OrbStack or UTM) running a full Linux guest with OpenClaw installed. Snapshot before demo; restore after.

**Pros:**
- Strongest isolation boundary (hypervisor layer)
- Full OS-level reset via snapshot restore
- Can run a different OpenClaw version than OC1

**Cons:**
- Higher OC1 resource consumption (full OS guest = 2–4 GB RAM baseline before workload)
- Snapshot management is manual and error-prone without automation
- Spin-up time is seconds to minutes vs milliseconds for Docker
- OrbStack/UTM not currently installed — new tooling required
- No existing tooling to automate "snapshot → demo → restore" cycle

**Risk:** MEDIUM (resource contention with OC1 prod; snapshot drift)
**Effort:** MEDIUM-HIGH — 4–6 days + tooling setup

---

### Option C — Separate OpenClaw Agent Profile / Sandbox Mode Flag

**Description:** A separate `.openclaw/workspace-sandbox` profile and config, running as a different agent profile on the same binary and host process, with a sandbox flag to restrict credential scope.

**Pros:**
- No new runtime — same binary, same host
- Fastest to stand up if OpenClaw supports profile isolation natively
- No resource overhead for a second runtime

**Cons:**
- **Does NOT meet ISOLATED requirement** — same process, same host filesystem, same keychain access path. A misconfiguration could expose prod state.
- No network namespace separation — sandbox agent can reach OC1 production endpoints
- Ephemerality is config-managed, not enforced by runtime teardown. Human error risk.
- Not defensible to investors or clients as "isolated environment"
- S1–S7 compliance questionable: no hard boundary between sandbox and prod credentials

**Risk:** HIGH (isolation properties are soft, not hard)
**Effort:** LOW (but unacceptable risk profile for this use case)

> **Verdict:** Option C is disqualified on isolation and security grounds. Not recommended.

---

### Option D — OC2 Dedicated Sandbox Tenant (Future State)

**Description:** When OC2 arrives (~Jul 2026), provision a dedicated tenant for sandbox/demo purposes, fully separated at the platform level from OC1 production.

**Pros:**
- True platform-level multi-tenancy — strongest isolation
- Likely to have native ephemeral/demo tenant features
- Aligns with long-term SaaS architecture (P3/P4 roadmap)
- Zero OC1 resource consumption

**Cons:**
- **Not available until Jul 2026** — cannot address Sprint 3 requirement
- OC2 capabilities/APIs unknown; cannot design against them now
- Migration of demo agents from Option A to OC2 will still be needed

**Risk:** N/A for Sprint 3 (not available)
**Effort:** N/A for Sprint 3

> **Verdict:** Option D is the strategic end-state. Note in roadmap. Build Option A for Sprint 3; plan OC2 migration in Sprint 5–6 when OC2 spec is confirmed.

---

## 3. Recommended Architecture

### Decision: Option A — Docker / Colima Isolated Instance

**Architectural Rationale (TOGAF-aligned):**

**Business Architecture:** The sandbox serves three stakeholder journeys — client demos, PoC evaluations, investor showcases. All three require a credible, clean environment that cannot accidentally surface production data or agent state. Docker provides a hard runtime boundary that is explainable and demonstrable to non-technical stakeholders ("it runs in a container, destroyed after").

**Data Architecture:** Demo data lives exclusively in a sandbox-scoped MinIO bucket (`sandbox-demo` bucket, not `prod` bucket). No data persists beyond `sandbox-down`. No prod data is ever seeded into the sandbox — all demo content is synthetic or purpose-built fixtures.

**Application Architecture:**

```
┌─────────────────────────────────────────────────────┐
│  OC1 Mac Mini M4 24GB                                │
│                                                      │
│  ┌─────────────────────┐  ┌──────────────────────┐  │
│  │  OC1 PRODUCTION     │  │  SANDBOX (Docker)    │  │
│  │  (host process)     │  │  Compose Project:    │  │
│  │  workspace: /oc/ws  │  │  openclaw-sandbox    │  │
│  │  MinIO: prod bucket │  │                      │  │
│  │  Tailscale: active  │  │  ┌────────────────┐  │  │
│  │                     │  │  │ openclaw-sb    │  │  │
│  │  ❌ NO BRIDGE ❌    │  │  │ (container)    │  │  │
│  └─────────────────────┘  │  │ workspace vol  │  │  │
│                            │  └───────┬────────┘  │  │
│  Colima socket:            │          │            │  │
│  unix:///...colima/...     │  ┌───────▼────────┐  │  │
│  /docker.sock              │  │ minio-sb       │  │  │
│                            │  │ (container)    │  │  │
│                            │  │ bucket: demo   │  │  │
│                            │  └────────────────┘  │  │
│                            │                      │  │
│                            │  Network: sandbox-net│  │
│                            │  (isolated bridge)   │  │
│                            └──────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

**Technology Architecture:**

| Component | Choice | Rationale |
|---|---|---|
| Container runtime | Colima (existing) | Zero new tooling; already proven on OC1 |
| Compose project | `openclaw-sandbox` | Isolated project name prevents name collisions with prod |
| OpenClaw image | Custom Dockerfile FROM official OC image | Bake in demo agents, seed scripts, synthetic data |
| Credentials | `.env.sandbox` (not host keychain) | Strictly scoped; destroyed with teardown |
| Storage | MinIO container (sandbox bucket) | Mirrors prod MinIO API; isolated; ephemeral on teardown |
| Network | Docker bridge `sandbox-net` | No routes to OC1 containers or host services |
| Resource cap | 4 vCPU / 6 GB RAM (Colima quota) | Leaves ≥18 GB for OC1 prod |
| Interface | `Makefile` with `sandbox-up`, `sandbox-down`, `sandbox-verify` | Single-command lifecycle for Ken/Angie |

**Key Design Decisions:**
1. **No shared volumes** with OC1 workspace. Sandbox workspace is an ephemeral Docker volume, not a host bind mount to `/Users/ainchorsangiefpl/.openclaw/workspace`.
2. **No Tailscale** inside container by default. If remote demo access is needed, expose via Colima port-forward to a non-production port only.
3. **Teardown verification** — `sandbox-verify` script confirms zero residual volumes, containers, and networks after teardown. Output logged for audit.
4. **Seed data** — synthetic demo data loaded via init script at startup. No prod data ever enters sandbox. Seed scripts version-controlled.

---

## 4. Implementation Approach (Sprint 3)

> High-level only. Implementation owned by Thrawn (AI Platform Architect) within these constraints.

**Phase 1 — Foundation (Day 1–2)**
- [ ] Create `openclaw-sandbox` Docker Compose file (compose project isolated from OC1)
- [ ] Define `sandbox-net` bridge network (no external routing to prod services)
- [ ] Configure MinIO sandbox container with `demo` bucket, separate access key/secret
- [ ] Create `.env.sandbox.template` — credential template with placeholder values; never committed with real values

**Phase 2 — OpenClaw Sandbox Container (Day 2–3)**
- [ ] Dockerfile: FROM official OpenClaw image, add demo agent configs, seed script entrypoint
- [ ] Workspace volume: ephemeral (`tmpfs` or named volume, not host bind)
- [ ] Validate no OC1 credential paths mounted or reachable
- [ ] Test: start sandbox, verify agents load, verify MinIO connectivity within sandbox

**Phase 3 — Lifecycle Interface (Day 3)**
- [ ] `Makefile` targets: `sandbox-up`, `sandbox-down`, `sandbox-verify`, `sandbox-status`
- [ ] `sandbox-verify` post-teardown: assert zero containers, volumes, networks in project
- [ ] README / runbook: one-pager for Ken/Angie to trigger demo environment

**Phase 4 — Validation & Handoff (Day 4)**
- [ ] Full lifecycle test: up → demo workflow → down → verify
- [ ] Resource consumption test: confirm OC1 prod unaffected under sandbox load
- [ ] S1–S7 compliance check: credential isolation, no prod data in sandbox, audit log of teardown
- [ ] Thrawn sign-off → Atlas Architecture Assurance review → Ken approval gate

**Deliverables:**
- `docker-compose.sandbox.yml`
- `Dockerfile.sandbox`
- `.env.sandbox.template`
- `Makefile` with lifecycle targets
- `sandbox-verify.sh` teardown verification script
- `docs/sandbox-runbook.md` (one-pager for Ken/Angie)

---

## 5. Risk & Constraints

### Risk 1 — Container Escape / Privileged Mount
**Description:** A misconfigured container with host volume mounts or `--privileged` flag could access OC1 production workspace or credentials.
**Mitigation:** Thrawn must enforce: no `--privileged`, no bind mounts to `/Users/ainchorsangiefpl/.openclaw/workspace` or host keychain paths. Atlas Architecture Assurance review will verify compose file before build approval.
**Residual Risk:** LOW (enforced by design constraint, not convention)

### Risk 2 — Resource Contention on OC1
**Description:** Sandbox under demo load (e.g., multiple agents active) could degrade OC1 production performance, impacting live workloads during the demo itself.
**Mitigation:** Hard resource cap in Colima config: `cpus: 4`, `memory: 6GiB` for sandbox compose project. Ken/Angie should not run sandbox and production-heavy workloads simultaneously. `sandbox-status` command reports live resource usage.
**Residual Risk:** LOW-MEDIUM (Colima cap is soft limit; M4 24 GB provides adequate headroom for typical demo load)

### Risk 3 — Demo Data Governance / Credential Leakage
**Description:** Real client or investor data accidentally seeded into sandbox (which is then shared in a demo context), or sandbox credentials reused/shared outside the environment.
**Mitigation:** Policy: only synthetic, purpose-built demo data permitted in sandbox. `.env.sandbox` credentials generated fresh per spin-up (or rotated post-demo). `sandbox-down` destroys `.env.sandbox` local copy. Seed data repo reviewed by Ken before first use.
**Residual Risk:** LOW (process control; no technical substitute for human discipline here)

---

## 6. Decision Required

Ken must approve the following before Thrawn begins build:

| # | Decision | Options | Recommendation |
|---|---|---|---|
| D1 | **Confirm Option A as selected approach** | A / B / C / D | Option A |
| D2 | **Resource cap for sandbox** | 4 vCPU / 6 GB (recommended) vs higher | 4 vCPU / 6 GB — leaves comfortable headroom for OC1 prod |
| D3 | **Remote access to sandbox during demos** | Port-forward via Colima (no Tailscale in container) vs Tailscale sidecar | Port-forward only — simpler, no Tailscale credential scope in sandbox |
| D4 | **Demo data ownership** | Thrawn builds synthetic seed data vs Ken/Angie provides demo scripts | Recommend Thrawn builds synthetic fixtures; Ken reviews before Sprint 3 close |
| D5 | **OC2 migration trigger** | Plan OC2 migration when OC2 spec confirmed (~Jul 2026) or defer | Plan in Sprint 5–6 backlog; no action Sprint 3 |

---

## 7. Out of Scope

- **OpenClaw internals / container implementation** — owned by Thrawn (AI Platform Architect). Atlas sets constraints; Thrawn designs within them.
- **OC2 architecture** — not available Sprint 3. Future assessment when OC2 spec is confirmed.
- **Tailscale mesh reconfiguration** — sandbox uses Colima port-forward only; no Tailscale topology changes in scope.
- **Production MinIO changes** — sandbox uses a separate MinIO container (or isolated bucket on existing MinIO instance per TKT-0124). No prod MinIO schema changes.
- **CI/CD pipeline** for sandbox — not required Sprint 3. Single-command Makefile is sufficient for Ken/Angie trigger use case.
- **Multi-user sandbox access** — Sprint 3 scope is Ken and Angie only. Multi-user or client self-serve is a future capability.
- **Cost modelling** — OC1 is owned infrastructure; no incremental cloud cost. Out of scope for this assessment.

---

## Appendix: Option Comparison Summary

| Criterion | Option A (Docker) | Option B (VM) | Option C (Profile) | Option D (OC2) |
|---|---|---|---|---|
| Isolation (hard boundary) | ✅ Network NS | ✅ Hypervisor | ❌ Soft only | ✅ Platform |
| Ephemerality (enforced) | ✅ Volume destroy | ✅ Snapshot restore | ⚠️ Manual | ✅ Tenant delete |
| Managed (single-command) | ✅ Compose | ⚠️ Complex | ✅ Easy | ✅ API |
| Contained (cred scope) | ✅ env-file | ✅ Guest OS | ❌ Shared host | ✅ Tenant scope |
| OC1 resource impact | LOW (capped) | MEDIUM-HIGH | LOW | NONE |
| Sprint 3 available | ✅ YES | ✅ YES | ✅ YES | ❌ NO |
| New tooling required | NONE | NEW (OrbStack/UTM) | NONE | N/A |
| Effort | LOW | MEDIUM-HIGH | LOW (disqualified) | N/A |
| **Overall** | **✅ RECOMMENDED** | **⚠️ Viable fallback** | **❌ Disqualified** | **📋 Future state** |

---

*Document: EA_TKT-0135_SandboxEnv_DRAFT_v1.0_2026-05-14*
*DRAFT FOR REVIEW — Atlas (Enterprise Architect) | Pending Ken Mun approval*
*Next review: Ken approval gate before Thrawn build commences*

---

## Addendum: Ken Mun Decision Log (2026-05-11 15:23 AEST)

All open questions resolved. Decisions below supersede any placeholder assumptions in the assessment above.

| # | Decision | Resolution |
|---|---|---|
| D1 | Architecture option | **Option A — Docker / Colima** ✅ Approved |
| D2 | Resource cap | **4 vCPU / 6 GB RAM** ✅ Approved |
| D3 | Remote demo access | **Port-forward only** — no Tailscale in container ✅ Approved |
| D4 | Demo seed data ownership | **Thrawn builds synthetic fixtures** — Mini Yoda + Aria agents ✅ Approved |
| D5 | OC2 migration | **Sprint 5–6 backlog** — no Sprint 3 action ✅ Approved |
| Demo agents | Which agents in sandbox | **Mini Yoda + Aria** — showcase multi-agent Nexus IP |
| Trigger mechanism | Who/how triggers sandbox | **Yoda-triggered** — after gathering and validating all requirements and scope with Ken/Angie |
| Reset vs Destroy | Post-demo lifecycle | **4C Hybrid** — Full destroy after each demo + versioned seed image (Docker image, not live snapshot). Fast spin-up (~30–60s), true ephemerality, auditable, no snapshot drift. |

**Status: All decisions approved. Ready for Thrawn build.**
*Approved by: Ken Mun (CTO) | 2026-05-11 15:23 AEST*
