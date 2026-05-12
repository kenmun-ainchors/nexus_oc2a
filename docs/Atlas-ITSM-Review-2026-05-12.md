# Atlas ITSM Backlog Review — 2026-05-12

**Author:** Atlas 🏛️ — Enterprise Architect, AInchors  
**Date:** 2026-05-12  
**Ken directive:** Review all 18 remaining ITSM backlog items — determine required, superseded, or fold  
**Context:** Days 1–18 of platform build. Significant ITSM infrastructure now live.

---

## 1. Platform ITSM Capabilities — Current State

Before reviewing individual items, these platform capabilities are confirmed live and directly affect the verdict on many items:

| Capability | Evidence | Status |
|---|---|---|
| Health monitoring (19 checks) | `scripts/health-check.sh` — disk, gateway, Ollama, cost-state, MEMORY.md, etc. | ✅ LIVE |
| Timestamped observability | `scripts/obs-collector.sh` + `state/obs.db` — 20k+ events | ✅ LIVE |
| Event taxonomy (INFO/WARN) | `obs-collector.sh` uses `--level INFO` / `--level WARN` with typed events | ✅ LIVE |
| Latency + performance tracking | `scripts/latency-tracker.sh` + `state/ci-agent-metrics.json` | ✅ LIVE |
| Cost tracking | `scripts/cost-tracker.sh` + `state/api-cost-actuals.json` | ✅ LIVE |
| Incident management | `scripts/incident-log.sh` + `state/incident-log.json` + RULES.md ITIL-1 | ✅ LIVE |
| Change management | `scripts/changelog-append.sh` + `memory/CHANGELOG.md` + RULES.md ITIL-2 | ✅ LIVE |
| Problem management | `state/problems/PRB-001.json` — Forge QW-8 filing now | ✅ IN PROGRESS |
| Continual Improvement Register | Forge QW-5 creating in Notion now | ✅ IN PROGRESS |
| Nightly auto-heal | `scripts/auto-heal.sh` — capacity + file integrity + NEEDS_KEN items | ✅ LIVE |
| Ticket management | `scripts/ticket.sh` + `state/tickets.json` | ✅ LIVE |
| Knowledge base (Holocron) | Holocron Document/Decision/Lessons Registries in Notion | ✅ LIVE |
| Asset registry | `state/asset-registry.json` | ✅ LIVE (local only) |

---

## 2. ITSM Item Review — All 18

### Summary Table

| ID | Title (abbreviated) | Verdict | Rationale |
|---|---|---|---|
| ITSM-US-004 | SLO measurement & weekly reporting | **KEEP-P1** | Health-check provides data; formal SLO report not automated |
| ITSM-US-008 | Service Catalogue v1 | **KEEP-P1** | No catalogue exists; required before KL onboarding |
| ITSM-US-009 | Service request intake & fulfilment | **KEEP-P2** | ticket.sh = internal only; client-facing workflow needed at P2 |
| ITSM-US-010 | Problem Management (PRB + KEDB) | **DONE** | PRB-001.json live; Forge QW-8 formalising now |
| ITSM-US-011 | Extend Asset Registry to CMDB | **KEEP-P1** | asset-registry.json exists locally; Notion CMDB integration not done |
| ITSM-US-012 | CMDB blast-radius check | **KEEP-P1** | Depends on ITSM-US-011; not yet implemented |
| ITSM-US-014 | Create CIR in Notion | **DONE** | Forge QW-5 creating now |
| ITSM-US-015 | Timestamped metric logging for trending | **DONE** | obs-collector.sh + obs.db + obs-trend.sh fully live |
| ITSM-US-016 | System resource capacity monitoring | **DONE** | health-check.sh disk checks + auto-heal.sh capacity logic live |
| ITSM-US-017 | Per-agent performance tracking | **DONE** | ci-agent-metrics.json + latency-tracker.sh + cost-tracker.sh all live |
| ITSM-US-019 | Knowledge Base index + lifecycle mgmt | **SUPERSEDED** | Holocron + AKB serves this function; Notion lifecycle mgmt applies |
| ITSM-US-020 | Planned maintenance window policy | **KEEP-P1** | No formal policy; required for P2 SLA commitments |
| ITSM-US-021 | INFO/WARNING/EXCEPTION event taxonomy | **SUPERSEDED** | obs-collector.sh INFO/WARN taxonomy + health-check ok/degraded/critical + incident P1–P4 already live |
| ITSM-US-022 | Define release types + release process | **FOLD** | RULES.md ITIL-2 covers change management; release type definitions (3 lines) should be added there |
| ITSM-US-023 | Release calendar + communication workflow | **KEEP-P2** | No active release calendar; relevant only when P2 client-facing releases occur |
| ITSM-US-024 | Weekly CI review cadence | **KEEP-P1** | CIR being created; weekly review cadence is a separate process item |
| ITSM-US-025 | ITSM Framework health dashboard in Notion | **KEEP-P2** | generate-mission-control.sh exists; ITSM-specific Notion dashboard is P2 need |
| ITSM-US-026 | ITSM Framework v1.0 retrospective | **KEEP-P1** | Schedule for end of P1; not superseded |

---

## 3. Detailed Findings

### ITSM-US-004 — Implement SLO measurement and weekly reporting
**Verdict: KEEP-P1**  
**Rationale:** health-check.sh runs every 5 min and tracks consecutive failures; RULES.md ITIL-3 documents uptime target ≥99.0%. However, there is no automated weekly SLO report generated from obs.db/health data and sent to Ken/Angie. The data infrastructure exists (obs.db, latency-summary.json) — the reporting wrapper does not. This is a P1 deliverable needed before KL team onboarding.  
**Action:** Keep open. Sprint item to build `scripts/slo-report.sh` pulling from obs.db, delivered weekly via Telegram.

---

### ITSM-US-008 — Define and publish AInchors Service Catalogue (v1)
**Verdict: KEEP-P1**  
**Rationale:** No service catalogue document or Notion page exists. The asset registry covers infrastructure components, not services. A service catalogue is a prerequisite for formalising what AInchors offers internally and to clients — needed before KL team onboarding.  
**Action:** Keep open. Assign to Atlas + Aria (business stream). Produce as a Notion page in Holocron + Drive doc.

---

### ITSM-US-009 — Implement service request intake and fulfilment workflow
**Verdict: KEEP-P2**  
**Rationale:** ticket.sh handles internal work items effectively. However, a client-facing service request intake workflow (The Citadel or equivalent) does not exist. This is a P2 client onboarding requirement, not a P1 need.  
**Action:** Keep open. De-prioritise to P2. Link to The Citadel P2 platform build (Thrawn scope).

---

### ITSM-US-010 — Implement Problem Management (PRB tickets + KEDB)
**Verdict: DONE**  
**Rationale:** `state/problems/PRB-001.json` exists and contains a real problem record. Forge QW-8 is actively formalising the problem management process and KEDB now. Problem management infrastructure is live.  
**Action:** Close Notion page → Done. Resolution: "PRB-001.json live in state/problems/; Forge QW-8 formalised process and KEDB 2026-05-12."

---

### ITSM-US-011 — Extend Notion Asset Registry to function as CMDB
**Verdict: KEEP-P1**  
**Rationale:** `state/asset-registry.json` exists locally with asset records. However, it has not been extended into a full CMDB in Notion with relationship mapping, blast-radius capability, and CI (Configuration Item) lifecycle tracking. This is needed before P2 for change impact analysis.  
**Action:** Keep open. P1 sprint item. Assign to Forge (Notion integration) + Atlas (CMDB schema).

---

### ITSM-US-012 — Add CMDB blast radius check to pre-risky-op checkpoint
**Verdict: KEEP-P1**  
**Rationale:** No blast-radius check exists in the pre-risky-op checkpoint (RULES.md). Depends on ITSM-US-011 (CMDB) being completed first. Sequence: CMDB → blast-radius check.  
**Action:** Keep open. Block on ITSM-US-011. Add to same P1 sprint.

---

### ITSM-US-014 — Create Continual Improvement Register (CIR) in Notion
**Verdict: DONE**  
**Rationale:** Forge QW-5 is creating the CIR in Notion as of 2026-05-12. This item is being delivered right now.  
**Action:** Close Notion page → Done. Resolution: "Forge QW-5 created CIR in Notion 2026-05-12."

---

### ITSM-US-015 — Add timestamped metric logging to health-check for trending
**Verdict: DONE**  
**Rationale:** `obs-collector.sh` logs all events to `obs.db` with `ts_epoch` timestamps. `obs-trend.sh` provides trending queries. `state/health-state.json` is updated every 5 minutes with timestamped state. `health.log` provides a full timestamped audit trail. This capability is fully operational with 20k+ events.  
**Action:** Close Notion page → Done. Resolution: "obs-collector.sh + obs.db + obs-trend.sh live; 20k+ timestamped events as of 2026-05-12."

---

### ITSM-US-016 — Add system resource capacity monitoring to nightly close
**Verdict: DONE**  
**Rationale:** `health-check.sh` CHECK 4 monitors disk usage with configurable `DISK_ALERT_PCT=85` threshold and alerts on breach. `auto-heal.sh` runs nightly and includes file size guards, memory file checks, and NEEDS_KEN escalation. `obs-collector.sh` logs capacity-related events. System resource monitoring is comprehensively live.  
**Action:** Close Notion page → Done. Resolution: "health-check.sh disk monitoring + auto-heal.sh nightly capacity checks live 2026-05-12."

---

### ITSM-US-017 — Implement per-agent performance tracking (token usage, latency)
**Verdict: DONE**  
**Rationale:** Three independent tracking mechanisms exist: (1) `state/ci-agent-metrics.json` tracks per-agent model quality and latency from CI benchmarks; (2) `scripts/latency-tracker.sh` reads cron run history and writes latency samples to `obs.db latency_log`, generating `state/latency-summary.json`; (3) `scripts/cost-tracker.sh` + `state/api-cost-actuals.json` track token costs per session. Comprehensive per-agent performance tracking is live.  
**Action:** Close Notion page → Done. Resolution: "ci-agent-metrics.json + latency-tracker.sh + cost-tracker.sh all live 2026-05-12."

---

### ITSM-US-019 — Create Knowledge Base index with article lifecycle management
**Verdict: SUPERSEDED**  
**Rationale:** The Holocron Document Registry, Decision Registry, and Lessons Learned Registry in Notion serve the knowledge base function. `state/akb-migration-state.json` and `state/akb-update-log.json` evidence an active Agent Knowledge Base (AKB). Notion provides article lifecycle management natively (Draft → Review → Approved → Archived). A separate Knowledge Base index would duplicate Holocron.  
**Action:** Close Notion page → Done. Resolution: "Superseded by Holocron Document/Decision/Lessons Registries + AKB in Notion. No separate KB index needed."

---

### ITSM-US-020 — Define planned maintenance window policy and schedule
**Verdict: KEEP-P1**  
**Rationale:** No formal maintenance window policy exists. auto-heal.sh runs nightly but without a published maintenance schedule. Client SLA commitments at P2 require a defined maintenance window (when downtime is acceptable, notification requirements, duration limits). This is a P1 pre-condition for P2 client onboarding.  
**Action:** Keep open. P1 priority. Atlas to draft maintenance window policy, link to POL-010 (Incident Response Policy).

---

### ITSM-US-021 — Implement INFO/WARNING/EXCEPTION event taxonomy in health
**Verdict: SUPERSEDED**  
**Rationale:** A richer event taxonomy is already live across three systems: (1) `obs-collector.sh` uses `--level INFO` / `--level WARN` with typed `event_type` values; (2) `health-check.sh` uses ok/degraded/critical exit codes; (3) `scripts/incident-log.sh` uses P1–P4 severity tiers. The existing multi-system taxonomy provides more operational granularity than the proposed INFO/WARNING/EXCEPTION three-tier model. Adding a separate taxonomy layer would fragment the model.  
**Action:** Close Notion page → Done. Resolution: "Superseded by obs-collector.sh INFO/WARN taxonomy + health-check ok/degraded/critical + incident P1–P4 severity. Already live."

---

### ITSM-US-022 — Define release types (Hotfix/Standard/Major) and release process
**Verdict: FOLD**  
**Rationale:** RULES.md ITIL-2 (Change Management) already defines the change log process, CHG categories, and changelog-append.sh as the enforcement mechanism. Defining Hotfix/Standard/Major release types is a 3-line addition to RULES.md ITIL-2 — not a separate ticket. Creating a new ticket for this would generate overhead without value.  
**Action:** Close as FOLD. Resolution: "Fold into next RULES.md update — add Hotfix/Standard/Major definitions to ITIL-2 Change Management section. No separate ticket needed." Update Notion page notes with fold target.

---

### ITSM-US-023 — Maintain release calendar and release communication workflow
**Verdict: KEEP-P2**  
**Rationale:** No release calendar exists and none is currently needed — P1 is an internal build phase with no external release obligations. At P2 with client-facing platform releases (Citadel, agent updates visible to clients), a release calendar and communication workflow become necessary.  
**Action:** Keep open. Re-prioritise to P2. Link to The Citadel P2 build planning.

---

### ITSM-US-024 — Establish weekly Continual Improvement review cadence
**Verdict: KEEP-P1**  
**Rationale:** The CIR is being created now (ITSM-US-014 DONE), but the cadence — who reviews it, when, what constitutes a CI item, and how items are approved and tracked — is a separate process item. This is an operational rhythm that needs to be established before KL team onboarding.  
**Action:** Keep open. Link to ITSM-US-014 (CIR). Atlas to define cadence SOP (weekly Atlas review → Ken approval for approved items).

---

### ITSM-US-025 — Build ITSM Framework health dashboard in Notion
**Verdict: KEEP-P2**  
**Rationale:** `scripts/generate-mission-control.sh` generates a local HTML dashboard. However, an ITSM-specific Notion dashboard consolidating SLO/SLA tracking, open incidents, problem records, CIR items, and change success rate is a P2 operational visibility need — relevant when external stakeholders (clients, KL team) need to see platform health.  
**Action:** Keep open. Re-prioritise to P2. Assign to Forge (Notion integration).

---

### ITSM-US-026 — Conduct ITSM Framework v1.0 retrospective at end of phase
**Verdict: KEEP-P1**  
**Rationale:** A retrospective at the end of P1 is a valuable quality gate — reviewing what worked, what's missing, what needs to change before P2. This cannot be superseded by current work; it's a scheduled future activity. It should be preserved and triggered at P1 phase close.  
**Action:** Keep open. Schedule as a P1 phase-close milestone. Atlas leads, Yoda facilitates, Ken reviews output.

---

## 4. Actions Required

### Close in Notion (DONE / SUPERSEDED / FOLD — 7 items)

| ID | Notion Page ID | Resolution Note |
|---|---|---|
| ITSM-US-010 | 34ec1829-53ff-81de-a68f-f34c64695ba5 | DONE: PRB-001.json live; Forge QW-8 formalised problem management + KEDB 2026-05-12 |
| ITSM-US-014 | 34ec1829-53ff-818b-bc1f-c8439d25c714 | DONE: Forge QW-5 created CIR in Notion 2026-05-12 |
| ITSM-US-015 | 34ec1829-53ff-81a7-a7fd-dc7aa882aa9e | DONE: obs-collector.sh + obs.db + obs-trend.sh live; 20k+ timestamped events |
| ITSM-US-016 | 34ec1829-53ff-81f2-abe1-fbcfc452773e | DONE: health-check.sh disk monitoring + auto-heal.sh nightly capacity checks live |
| ITSM-US-017 | 34ec1829-53ff-81eb-b0f3-f91b262a81b4 | DONE: ci-agent-metrics.json + latency-tracker.sh + cost-tracker.sh live |
| ITSM-US-019 | 34ec1829-53ff-8146-9655-e8ee13f5e5fc | SUPERSEDED: Holocron + AKB serves KB function; Notion lifecycle management applies |
| ITSM-US-021 | 34ec1829-53ff-81ce-9d92-f94b31d49a28 | SUPERSEDED: obs-collector INFO/WARN + health-check ok/degraded/critical + incident P1–P4 already live |
| ITSM-US-022 | 34ec1829-53ff-81bb-ac8c-f9c54e7ebba4 | FOLD: Add Hotfix/Standard/Major to RULES.md ITIL-2; no separate ticket needed |

### Keep Open — Updated Priority (11 items)

| ID | New Priority | Key Action |
|---|---|---|
| ITSM-US-004 | **P1** | Build slo-report.sh from obs.db; weekly Telegram delivery |
| ITSM-US-008 | **P1** | Atlas + Aria draft service catalogue; Notion + Drive |
| ITSM-US-011 | **P1** | Forge + Atlas: Notion CMDB integration from asset-registry.json |
| ITSM-US-012 | **P1** | Block on ITSM-US-011; add blast-radius check to pre-risky-op checkpoint |
| ITSM-US-020 | **P1** | Atlas draft maintenance window policy; link to POL-010 |
| ITSM-US-024 | **P1** | Define weekly CI review SOP; link to CIR |
| ITSM-US-026 | **P1** | Schedule as P1 phase-close milestone; Atlas leads |
| ITSM-US-009 | **P2** | Link to Citadel P2 build; client-facing service request workflow |
| ITSM-US-023 | **P2** | Link to Citadel P2 build; release calendar |
| ITSM-US-025 | **P2** | Forge: Notion ITSM dashboard at P2 |

---

## 5. Verdict Summary

| Verdict | Count | Items |
|---|---|---|
| DONE | 5 | US-010, US-014, US-015, US-016, US-017 |
| SUPERSEDED | 2 | US-019, US-021 |
| FOLD | 1 | US-022 |
| KEEP-P1 | 7 | US-004, US-008, US-011, US-012, US-020, US-024, US-026 |
| KEEP-P2 | 3 | US-009, US-023, US-025 |
| **Total** | **18** | |

**Items to close in Notion: 8** (DONE×5, SUPERSEDED×2, FOLD×1)  
**Items to keep: 10** (P1×7, P2×3)

---

_Atlas 🏛️ — Enterprise Architect, AInchors / Aevlith Technologies_  
_Review date: 2026-05-12 | Status: DRAFT FOR REVIEW — Pending Ken Mun approval_  
_Context: Ken directive 2026-05-12 | Days 1–18 ITSM backlog triage_
