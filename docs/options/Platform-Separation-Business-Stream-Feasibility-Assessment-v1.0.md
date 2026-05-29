# Platform Separation — Business Stream Feasibility Assessment

**Document:** PA_SEPARATION_FEASIBILITY_DRAFT_v1.0_2026-05-29
**Author:** Thrawn — AI Platform Architect, Nexus Core
**Status:** DRAFT FOR REVIEW
**Classification:** INTERNAL — Ken Mun (CTO) ONLY
**Dependencies:** OC2-A/B ETA 6–13 Jul 2026 (confirmed)

---

## Executive Summary

Ken Mun (CTO) has proposed physically separating the Nexus agentic platform into two independent OpenClaw instances — a business-facing node on the existing OC1 Mac Mini M4 24GB, and a dedicated technical platform on incoming OC2-A/B (Mac Mini M4 Pro 48GB ×2, HA pair). This assessment evaluates the technical feasibility, risks, and migration complexity of this architecture change.

**Verdict: CONDITIONALLY FEASIBLE.** Three conditions must be resolved before proceeding. No critical blockers that make the architecture impossible, but several risks require explicit acceptance by Ken.

---

## 1. OC1 Repurposing Feasibility

### 1.1 Hardware Assessment — Mac Mini M4 24GB

**Target Load:** 6 agents (Aria, Shield, Lex, Sage, Spark, Forge-ops) + reduced cron fleet + slim/no PG.

**Memory Analysis:**

| Component | Memory (Conservative) | Memory (Realistic) | Notes |
|-----------|----------------------|-------------------|-------|
| macOS overhead (idle) | 4 GB | 3 GB | M4 24GB — OS + window server + Tailscale |
| OpenClaw runtime + 6 agents | 12 GB | 6–8 GB | ~1–1.5 GB per agent process (no local inference) |
| Node.js runtime overhead | 2 GB | 1 GB | V8 heap per process |
| Slim PG (optional, business-only) | 1 GB | 0.5 GB | Minimal tables: tickets, state, memory |
| **Total with Ollama Cloud** | **~19 GB** | **~11–13 GB** | **Well within 24 GB** |
| Local inference: gemma4:26b | 26+ GB | N/A | **WILL NOT FIT** — model requires >24 GB |
| Local inference: gemma4:13b | 16 GB | 14 GB | Fits with ~8 GB headroom. Cramped but viable. |

**Verdict: 24 GB is sufficient for 6 agents using Ollama Cloud.** Local inference with gemma4:26b is impossible on this hardware. If local inference is required for air-gapped governance decisions, a smaller model (gemma4:13b or llama3.2:8b) must be used.

**CPU:** M4 10-core is more than adequate for 6 agents with cloud-offloaded inference. No concern.

**Storage:** OC1 currently uses internal SSD. 6-agent footprint with slim state is ~50–100 GB. No concern.

### 1.2 Migration Complexity

**What must be extracted from current OC1:**

| Artifact | Location | Complexity | Owner |
|----------|----------|------------|-------|
| Aria workspace (business agent state) | workspace-business/ | Low — copy directory | Aria |
| Aria Telegram bot config (@AInchorsAriaBot) | openclaw.json → agents array | Low — extract bot token, recreate config | Ken |
| Google Workspace credentials | Current: kenmun@ainchors.com | **Medium** — needs decision on account ownership | Angie/Ken |
| Notion API access | Per-instance auth token | Low — re-auth from new instance | Aria |
| Spark LinkedIn/cron configs | workspace-business/spark/ | Low — copy directory | Spark |
| Shared scripts Aria depends on | scripts/ (subset) | Low — identify and copy | Forge |
| Business-only crons | openclaw.json → cron section | Medium — extract and recreate | Yoda → Ken |

**What gets wiped from OC1:**

| Artifact | Action | Rationale |
|----------|--------|-----------|
| All tech agent workspaces (Yoda, Forge-dev, etc.) | Remove | No longer needed on business node |
| PG database (tech tables) | Drop or slim | Keep business-only tables if PG stays |
| Yoda's tech cron fleet | Remove | Recreated on OC2 |
| HIVE multi-node config | Remove completely | Business node is standalone |
| Tailscale serve for tech agents | Reconfigure | May keep Tailscale for remote access only |

**What stays on OC1 but is harmless:**

| Artifact | Rationale |
|----------|-----------|
| Workspace repo (git history) | Historical reference, no runtime impact |
| docs/ directory | Reference only, no runtime impact |
| state/ files (pre-migration) | Archive after migration verified |

### 1.3 OpenClaw Configuration Questions

**Q1: Edit existing openclaw.json or clean install?**
- **Recommendation:** Edit existing config. A clean install adds unnecessary risk (license re-binding, lost state, re-auth overhead). The config can be trimmed to 6 agents, business-only crons, and standalone mode via `config.patch`.
- **Risk:** Editing config means residual artifacts may linger. Mitigation: post-migration audit of config completeness.

**Q2: Does Ken's OpenClaw license cover a second instance?**
- **⚠️ UNRESOLVED — CONDITION #1.** OpenClaw licensing terms for multiple instances on the same account must be verified. Two independent production instances (OC1 business + OC2 tech) may require a second license or a multi-node/workspace license tier. This is a **critical blocker** — must be resolved before any migration begins.

**Q3: Tailscale configuration on business node:**
- Current OC1 uses Tailscale serve for agent accessibility. Business node has different requirements:
  - **Option A:** Keep Tailscale for Ken's remote SSH/management access only. No agent exposure via Tailscale serve. (Recommended — simpler, more secure.)
  - **Option B:** Business node on separate Tailscale FQDN with only business agents exposed. (Adds complexity, questionable value for a 6-agent standalone node.)
  - **Option C:** Remove Tailscale entirely. Ken loses remote access to business node. (Not recommended.)

---

## 2. OC2 Technical Platform — Impact Assessment

### 2.1 Agent Fleet Changes

| Current OC1 (14 agents) | OC2 Tech Platform (est. ~10 agents) | Delta |
|--------------------------|-------------------------------------|-------|
| Yoda (orchestrator) | Yoda | Unchanged |
| Shield, Lex, Sage (Triad) | Shield, Lex, Sage | **Duplicated** if business node has Triad; otherwise migrated |
| Warden | Warden (tech-only scope) | Simplified scope |
| Forge (dev + ops) | Forge (full dev + ops + SRE) | Restored to full capability |
| Aria (business lead) | **Removed** | Moves to OC1 |
| Spark (marketing) | **Removed** | Moves to OC1 |
| ~6 tech specialist agents | ~6 tech specialists | Unchanged, minus shared-serve overhead |
| Observer, Scribe, etc. | Observer, Scribe | Unchanged |

**Net effect on OC2:** ~10 agents vs current 14. Reduced context-switching for Yoda (no dual-principal routing). Cleaner TOM authority boundaries.

### 2.2 HA Architecture Simplification

**Original plan:** OC2-A/B HA pair for full platform (tech + business). Complex state sync across all agent domains.

**After separation:** HA is tech-only. Benefits:
- Fewer state sync targets (no business state to replicate)
- Simpler failover decision logic (tech metrics only, no business SLA conflicts)
- PG replication scope reduced (tech tables only)
- Warden monitoring scope reduced (tech drift only)

**No new complexity introduced.** HA implementation is strictly simpler post-separation.

### 2.3 Agent Routing Simplification

Yoda's routing table currently includes business stream routing:
- `"I need help with a customer"` → Aria
- `"Schedule social media post"` → Spark
- `"Check marketing analytics"` → Spark

After separation, all business routing is removed from OC2. Yoda becomes a pure technical orchestrator. This is architecturally cleaner:
- No dual-principal routing conflicts
- No need for TOM to distinguish business vs tech authority
- Clearer observability: all Yoda-routed tasks are technical

### 2.4 PG Database — Single Source of Truth

PG stays on OC2 as tech SSOT. Business node may retain a slim PG for business-only state (tickets, memory, Notion sync state) or operate PG-free with file-based state. Recommendation: slim PG on OC1 for business continuity if Aria/Spark need persistent state beyond files.

---

## 3. Cross-Cutting Concerns

### 3.1 Shared Services Impact Matrix

| Service | Current State | After Split | Risk Level | Mitigation |
|---------|--------------|-------------|------------|------------|
| **Notion AKB** | Both streams read/write | Both instances auth independently to same Notion workspace | ✅ LOW | Notion is cloud-native. Two OAuth tokens, same workspace. Works seamlessly. |
| **Google Workspace** | Aria uses kenmun@ainchors.com | Business node needs own auth scope | ⚠️ MEDIUM | **Decision needed:** Should business node use Angie's account or kenmun@ from separate instance? Google may flag two simultaneous OAuth sessions from same account on different machines. |
| **Telegram Bots** | @AInchorsOC1Bot, @AInchorsAriaBot | Aria bot moves to OC1 business node | ✅ LOW | Bot token is portable. Copy token, configure on new instance. No Telegram-side changes needed. |
| **Ollama Cloud** | One $100/mo subscription | Two OpenClaw instances → two API consumers | 🔴 **HIGH — CONDITION #2** | **CRITICAL: Must verify Ollama Cloud subscription terms.** Does one subscription allow N concurrent OpenClaw instances? If Ollama enforces instance limits or API key per-instance binding, this blocks the architecture. |
| **Tailscale** | One tailnet, OC1 with serve | OC1 may stay on tailnet (remote access), OC2 on tailnet (HA coordination) | ✅ LOW | Both nodes on same tailnet is fine. OC1 doesn't need `serve` — just `ssh` access for Ken. |
| **MinIO** | On OC1 currently | Must move to OC2 or remain on OC1 | ⚠️ MEDIUM | Object storage needs a permanent home. OC2 is the logical home (tech platform owns infrastructure). Migration: S3 bucket sync from OC1 → OC2. One-time effort. |
| **GitHub** | kenmun-ainchors, single gh auth | Both nodes can use same gh CLI auth | ✅ LOW | gh CLI auth is per-machine, not per-instance. Both nodes auth independently to same GitHub account. |
| **LinkedIn** | Spark on OC1 | Spark moves to business node, token migrates | ⚠️ MEDIUM | LinkedIn API token migration: re-auth on new instance. Document token recovery procedure. |

### 3.2 Governance Triad Architecture — The Hardest Problem

**Current state:** One Triad (Shield/Lex/Sage) serves both streams with verdict-only, reactive governance.

**Ken's proposal:** DUPLICATE Triad on business node. Two independent governance layers — one on OC1 (business), one on OC2 (tech).

**Problem analysis:**

| Dimension | Single Triad (current) | Duplicated Triad (proposed) | Remote Triad (alternative) |
|-----------|----------------------|---------------------------|--------------------------|
| Policy consistency | ✅ Unified | ❌ Divergence over time | ✅ Unified |
| Business governance coverage | ✅ Covered | ✅ Covered | ⚠️ Requires cross-node call |
| Tech governance coverage | ✅ Covered | ✅ Covered | ✅ Covered |
| Cross-node dependency | N/A | ✅ None (clean separation) | ❌ Business node depends on tech node |
| Failure mode | Single Triad down = both streams ungoverned | One Triad down = one stream ungoverned | Tech Triad down = business ungoverned |
| Operational complexity | ✅ Low | ⚠️ Medium (two configs to maintain) | ❌ High (cross-node API reliability) |
| Policy drift risk | ✅ None | ⚠️ Medium (inevitable over time) | ✅ None |

**Recommendation: Duplicated Triad with explicit risk acceptance.**

**Rationale:**
- Remote Triad (business calls tech Triad via cross-node API) violates the "clean separation" principle. It creates a hard dependency between nodes — if OC2 is down, OC1 governance is down.
- Single Triad on business node alone is architecturally wrong (tech platform should own governance).
- Duplicated Triad is the only option that preserves clean separation.

**Mitigation for policy divergence:**
1. Bootstrap both Triads from **identical config** (same rules, same S1–S7 thresholds, same approval gates).
2. Document in AGENTS.md that governance policy changes must be manually synced between nodes.
3. Accept that slow divergence is acceptable for MVP phase. Business governance rules and tech governance rules have different scopes anyway — divergence may be natural and correct.
4. **Quarterly governance audit:** Warden (tech) and Forge-ops (business) cross-check each other's policy configs. Manual, not automated.

**Risk accepted:** Over 6–12 months, the two Triads will diverge. This is acceptable if Ken reviews both policy sets quarterly.

### 3.3 Forge on Business Node — Ops-Only Scope

**Current Forge capabilities:** Platform build, scripts, CI, infra, backups, monitoring, auto-heal, daily reports.

**Proposed Forge-ops scope on business node:** Backup, monitoring, auto-heal, daily reports.

**What Forge-ops CANNOT do on business node:**
- Build new scripts or tools (no dev capability)
- Fix broken infrastructure (no SRE capability)
- CI/CD pipeline operations (no pipeline)
- OpenClaw config changes or agent debugging

**The SRE Gap — Real Risk:**

If OC1's OpenClaw runtime breaks, the recovery path is:
1. Forge-ops detects the failure (monitoring still works)
2. Forge-ops alerts Ken (daily report or notification)
3. **Ken manually intervenes** — SSH into OC1, debug, fix, restart
4. No automated recovery. Accept downtime until Ken is available.

**This is a real risk.** Current OC1 has Yoda + Forge (full SRE capability) providing self-healing. Business node has no SRE. If Aria goes down during Australian business hours and Ken is in a meeting, the business stream is dead until Ken can intervene.

**Mitigation:** Ken must explicitly accept this risk. Forge-ops can be given limited SRE scripts (restart OpenClaw, restart a specific agent) without full dev capability, as a middle ground.

**Alternative:** Keep Forge at full capability on business node. But this blurs the "business-only" boundary and creates a dev-capable agent on a supposedly business-pure node. Ken's call.

---

## 4. Migration Sequence

### Phase 1: OC1 Preparation (Now → OC2 arrival)

**Duration:** 1–2 days effort (can be done incrementally over weeks)

1. **Inventory:** Catalog all business-stream state on OC1
   - Aria workspace, Spark workspace, business crons, scripts
   - Telegram bot tokens, API keys, auth tokens
2. **Dependency mapping:** Document every script, cron, and integration Aria/Spark depend on
3. **Test extraction:** Verify all extracted artifacts are complete and functional (dry run)
4. **License verification:** Resolve Condition #1 (OpenClaw licensing for second instance)
5. **Ollama Cloud verification:** Resolve Condition #2 (subscription terms for two nodes)
6. **Google Workspace decision:** Resolve Condition #3 (which account for business node)

### Phase 2: OC1 Wipe & Rebuild (After all conditions resolved)

**Duration:** 4–8 hours (single maintenance window)

1. **Full backup:** Copy all OC1 state to NAS/external drive (`/Volumes/NAS/oc1-pre-migration-backup/`)
2. **Trim openclaw.json:** Remove tech agents, tech crons, HIVE config, Tailscale serve. Keep 6 business agents, business crons, Tailscale SSH.
3. **Install/restore business agents:** Copy Aria, Spark workspaces. Configure Telegram bot. Install Forge-ops with ops-only scope.
4. **Google Workspace auth:** Authenticate with resolved account (Angie's or kenmun@ from separate session)
5. **Notion re-auth:** Generate new Notion API token for business node
6. **Validation checklist:**
   - [ ] Angie can message @AInchorsAriaBot on Telegram, Aria responds
   - [ ] Spark can post to LinkedIn (test post, immediately delete)
   - [ ] Forge-ops monitoring is running, daily report generated
   - [ ] All 6 agents respond to sessions_spawn
   - [ ] Business crons firing on schedule
   - [ ] Tailscale SSH access working for Ken

### Phase 3: OC2 Commission (ETA 6–13 Jul 2026)

**Duration:** 2–3 days

1. **Hardware arrival:** OC2-A and OC2-B delivered → TRIGGER-01 fires
2. **Physical setup:** Both Mac Minis racked, networked, Tailscale installed
3. **OpenClaw install on OC2-A (primary):** Clean install, configure ~10 tech agents
4. **OpenClaw install on OC2-B (standby):** Mirror config, HA pair setup
5. **PG migration:** Restore PG from OC1 backup (tech tables only) to OC2-A. Configure HA replication to OC2-B.
6. **MinIO migration:** Sync buckets from OC1 → OC2. Update routing policy.
7. **Validation checklist:**
   - [ ] Yoda operational, routing table correct (tech-only, no business routes)
   - [ ] All tech agents responding
   - [ ] HA failover: kill OC2-A, verify OC2-B takes over
   - [ ] PG replication healthy
   - [ ] Warden monitoring tech drift
   - [ ] Triad governance active

### Phase 4: Decommission Old State

**Duration:** 1 week observation + 2 hours cleanup

1. **Observation period:** Run OC1 (business) + OC2 (tech) in parallel for 1 week minimum
2. **Cross-check:** Verify no missing state, no unexpected dependencies, no broken integrations
3. **Remove tech artifacts from OC1 backup:** Clean up pre-migration archive
4. **Archive documentation:** Final state captured in docs/

**⚠️ CRITICAL RULE:** Do NOT wipe OC1 until OC2 is live AND validated for ≥1 week. If OC2 is delayed (shipping, hardware defect), OC1 remains the fallback. Premature wipe = platform down with no recovery.

---

## 5. Risk Register

| # | Risk | Likelihood | Impact | Severity | Mitigation |
|---|------|-----------|--------|----------|------------|
| R1 | **Ollama Cloud subscription doesn't cover 2 nodes** | Medium | **Critical** | 🔴 | Verify with Ollama before proceeding. If blocked, evaluate: (a) second sub ($100/mo), (b) OC1 uses local inference only, (c) single sub with API proxy. |
| R2 | **OC1 hardware failure with no SRE on business node** | Low | **High** | 🟠 | Ken accepts manual SRE role. Forge-ops can be given restart scripts without full dev scope. Document recovery runbook. |
| R3 | **Governance policy divergence between duplicated Triads** | Medium | Medium | 🟡 | Bootstrap from identical config. Quarterly manual audit. Accept slow drift as acceptable for MVP. |
| R4 | **Aria loses Google Workspace during migration** | Low | High | 🟠 | Test auth on new instance in dry-run phase before cutting over. Keep backup of working config. |
| R5 | **Spark LinkedIn token breaks during migration** | Low | Medium | 🟡 | Re-auth procedure documented. LinkedIn OAuth is standard — re-auth takes 5 minutes. |
| R6 | **OC2 hardware delayed, OC1 already wiped** | Low | **Critical** | 🔴 | **HARD RULE:** Do not wipe OC1 until OC2 is live + validated for 1 week. Sequencing is non-negotiable. |
| R7 | **Business cron fleet breaks during migration** | Medium | Low | 🟢 | Extract cron config as JSON artifact. Replay on new instance. Dry-run validation before cutover. |
| R8 | **Two OpenClaw instances = double maintenance overhead** | High | Medium | 🟡 | Accept as cost of clean separation. Document upgrade procedure for both nodes. Schedule upgrades together. |
| R9 | **OpenClaw license doesn't cover second instance** | Medium | **Critical** | 🔴 | **Must resolve before Phase 2.** If blocked, explore: (a) second license purchase, (b) single-instance multi-workspace mode (if supported by OpenClaw). |
| R10 | **MinIO migration causes data loss** | Low | Medium | 🟡 | `mc mirror` with `--dry-run` first. Verify checksums post-migration. |
| R11 | **Business node cannot use Ollama Cloud at all (Condition #2 blocks)** | Medium | High | 🟠 | Fallback: OC1 uses local inference only (small models) or Ollama Cloud via proxy from OC2. Both degrade the "clean separation" principle. |
| R12 | **Google Workspace OAuth conflict — two sessions from kenmun@ flagged** | Medium | Medium | 🟡 | Mitigation: Use Angie's account for business node OR create a service account (ainchors-biz@ainchors.com). Google Workspace admin can create this. |

---

## 6. Verdict

### Overall: CONDITIONALLY FEASIBLE

The architecture is technically sound. No fundamental barriers prevent separation. The Mac Mini M4 24GB is adequate for 6 agents with cloud-offloaded inference. The HA pair (OC2-A/B) becomes simpler post-separation. Agent routing, governance scope, and observability all benefit from clean separation.

### Three Conditions That Must Be Resolved Before Proceeding

| # | Condition | Owner | Deadline |
|---|-----------|-------|----------|
| **C1** | **Verify OpenClaw licensing** — Does Ken's license cover a second production OpenClaw instance? If not, what is the cost of a second license or multi-instance tier? | Ken | Before Phase 2 |
| **C2** | **Verify Ollama Cloud subscription terms** — Does one $100/mo subscription allow two concurrent OpenClaw instances making API calls? If not, what is the cost of a second subscription or multi-node add-on? | Ken | Before Phase 2 |
| **C3** | **Decide Google Workspace account for business node** — Angie's account, kenmun@ from separate instance, or a new service account (ainchors-biz@)? Consider Google's OAuth session policies. | Ken + Angie | Before Phase 2 |

### Risks Requiring Explicit Ken Acceptance

1. **No SRE on business node** — If OpenClaw breaks on OC1, Ken is the recovery path. Accept downtime risk.
2. **Duplicated Triad governance divergence** — Two Triads will naturally drift. Quarterly manual audit accepted as cost of separation.
3. **Double maintenance overhead** — Two OpenClaw instances means double the upgrade work, double the config management, double the monitoring surface. Operational cost, not architectural blocker.

### What Becomes Better After Separation

- ✅ Yoda's routing logic is cleaner (tech-only, no dual-principal)
- ✅ TOM authority boundaries are unambiguous
- ✅ Warden monitoring scope is simpler
- ✅ HA failover logic is simpler (tech-only state)
- ✅ Business stream has physical isolation from tech experiments
- ✅ Angie's business operations don't compete with tech workloads
- ✅ Each node can be upgraded independently

### What Becomes Harder After Separation

- ❌ Two OpenClaw instances to maintain, upgrade, monitor
- ❌ No single-pane-of-glass observability across both streams
- ❌ Governance policy synchronization is manual
- ❌ Cross-stream workflows (if any) require explicit inter-node communication design
- ❌ OC1 hardware failure has no automated recovery

---

## Appendix A: Target Architecture Diagram (Text)

```
┌─────────────────────────────────────────────────────────────────┐
│                        TAILSCALE TAILNET                         │
│                                                                  │
│  ┌──────────────────────────┐    ┌────────────────────────────┐ │
│  │   OC1 — BUSINESS NODE    │    │   OC2-A/B — TECH PLATFORM  │ │
│  │   Mac Mini M4 24GB       │    │   Mac Mini M4 Pro 48GB ×2  │ │
│  │                          │    │                            │ │
│  │  Agents (6):             │    │  Agents (~10):             │ │
│  │  • Aria (lead)           │    │  • Yoda (orchestrator)     │ │
│  │  • Shield (governance)   │    │  • Shield (governance)     │ │
│  │  • Lex (governance)      │    │  • Lex (governance)        │ │
│  │  • Sage (governance)     │    │  • Sage (governance)       │ │
│  │  • Spark (marketing)     │    │  • Warden (tech drift)     │ │
│  │  • Forge (ops-only)      │    │  • Forge (full dev+SRE)    │ │
│  │                          │    │  • 4-5 tech specialists    │ │
│  │  Storage:                │    │                            │ │
│  │  • Slim PG (optional)    │    │  Storage:                  │ │
│  │  • File-based state      │    │  • PG (tech SSOT)          │ │
│  │                          │    │  • MinIO (object storage)  │ │
│  │  Integrations:           │    │  • HA replication (A↔B)    │ │
│  │  • Telegram (Aria bot)   │    │                            │ │
│  │  • Google Workspace      │    │  Integrations:             │ │
│  │  • Notion AKB            │    │  • Notion AKB              │ │
│  │  • LinkedIn (Spark)      │    │  • GitHub                  │ │
│  │                          │    │  • Ollama Cloud            │ │
│  │  Inference: Ollama Cloud │    │  • Tailscale (HA + SSH)    │ │
│  │  or local (small model)  │    │                            │ │
│  │                          │    │  Inference: Ollama Cloud   │ │
│  │  NO HIVE. Standalone.    │    │  or local (48GB capacity)  │ │
│  │                          │    │                            │ │
│  │  Access: Tailscale SSH   │    │  HIVE: OC2-A/B HA pair     │ │
│  └──────────────────────────┘    └────────────────────────────┘ │
│                                                                  │
│              ◄── NO CROSS-NODE DEPENDENCIES ──►                  │
│         (except shared cloud services: Notion, Ollama)           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Appendix B: Agent Capability Matrix Post-Separation

| Agent | OC1 (Business) | OC2 (Tech) | Notes |
|-------|---------------|------------|-------|
| **Aria** | ✅ Lead | ❌ | Business-only |
| **Spark** | ✅ Marketing | ❌ | Business-only |
| **Yoda** | ❌ | ✅ Orchestrator | Tech-only |
| **Shield** | ✅ Governance | ✅ Governance | Duplicated |
| **Lex** | ✅ Governance | ✅ Governance | Duplicated |
| **Sage** | ✅ Governance | ✅ Governance | Duplicated |
| **Warden** | ❌ | ✅ Tech drift | Single instance, tech scope |
| **Forge** | ✅ Ops-only | ✅ Full dev+SRE | Split capability |
| **Tech Specialists** | ❌ | ✅ ~5 agents | Tech-only |

---

## Appendix C: Decision Log

| ID | Decision | Status | Owner |
|----|----------|--------|-------|
| D-001 | Proceed with physical separation architecture | Pending Ken approval | Ken |
| D-002 | OC1 keeps Tailscale for SSH access only (no serve) | Recommended | Ken |
| D-003 | OC1 uses Ollama Cloud (Condition C2 permitting) | Recommended | Ken |
| D-004 | OC1 keeps slim PG for business state | Recommended | Ken |
| D-005 | Duplicated Triad with quarterly manual audit | Recommended | Ken |
| D-006 | Forge-ops scope: monitoring, backup, auto-heal, reports. No dev/SRE. | Recommended | Ken |
| D-007 | MinIO migrates to OC2 | Recommended | Ken |
| D-008 | Migration sequence: Phase 1 (prep) → Phase 2 (OC1 rebuild) → Phase 3 (OC2 commission) → Phase 4 (decommission old state) | Recommended | Ken |

---

**Next Step:** Ken review and approval of conditions C1–C3, risk acceptance R1–R3. Upon resolution, Thrawn produces detailed migration runbook (separate document).

---

_Document prepared by Thrawn — Platform Architect, Nexus Core. DRAFT FOR REVIEW. Not for distribution beyond Ken Mun (CTO)._
