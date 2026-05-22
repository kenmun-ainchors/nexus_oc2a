# Sources of Truth Register

**Canonical map of data locations and ownership for the Nexus platform.**
**Last Updated:** 2026-05-21
**Status:** Scope Locked (Ken Mun)
**Linked Tickets:** TKT-0195 (Postgres Deploy ✅), TKT-0198 (JSON Migration 🔄), TKT-0162 (Option Paper)
**Unlocks:** TKT-0182 (Explicit State Checking Pattern)

---

## 1. Core Data Domains & SSOT Mapping

| # | Domain | SSOT Location | Storage | Migration Status |
|---|---|---|---|---|
| 1 | Tickets/Work Items | Notion DB A | Notion + Postgres (`state_tickets`) | TKT-0198 migrating |
| 2 | Agent Configuration | `openclaw.json` | Gateway config (never in Postgres) | N/A |
| 3 | Cost/Financial | Postgres `state_cost` | Postgres | TKT-0198 migrating |
| 4 | Model Governance | Postgres `state_model_policy` | Postgres | TKT-0198 migrating |
| 5 | Config Baseline | Postgres `state_config_baseline` | Postgres | TKT-0198 migrating |
| 6 | Task Queue | Postgres `state_task_queue` | Postgres | TKT-0198 migrating |
| 7 | Compliance/Audit | Postgres T1 tables (`agent_events`, `agent_decisions`, `decision_lineage`, `memory_access_log`) | Postgres | T1 tables live |
| 8 | External Content | `content-queue.json` + `linkedin-queue.json` | JSON (Sprint 5 Postgres migration) | Transitional |
| 9 | Governance/Policy | `policy-register.json` + Notion Holocron | JSON + Notion (Sprint 5+ Postgres) | Low churn |
| 10 | Backup/DR | `backup-state.json` | JSON (ephemeral) | Does not need Postgres |

---

## 2. Read/Write Rules

| Domain | Agent Access Rule | Human Access Rule | System Constraint |
|---|---|---|---|
| **1. Tickets** | Read/Write via `ticket.sh` $\to$ Postgres (Check-Before-Act) | Direct Edit in Notion | Never write JSON directly |
| **2. Agent Config** | Read-only from `openclaw.json` | Direct Edit | Gateway-level config |
| **3. Cost/Financial** | Read/Write via `cost-tracker.sh` $\to$ Postgres (Check-Before-Act) | Read via Dashboard | JSON is read-only cache |
| **4. Model Gov** | Read/Write $\to$ Postgres (Check-Before-Act) | Policy Review in Notion | Strictly Postgres |
| **5. Config Baseline** | Read/Write $\to$ Postgres (Check-Before-Act) | Baseline Approval | Strictly Postgres |
| **6. Task Queue** | Read/Write $\to$ Postgres (Check-Before-Act) | Monitoring only | Strictly Postgres |
| **7. Compliance** | Append-only $\to$ Postgres T1 | Audit Review | Immutable lineage |
| **8. Ext Content** | Read/Write $\to$ JSON $\to$ Postgres (S5) | Content Calendar | Transitioning to DB |
| **9. Gov/Policy** | Read $\to$ JSON/Notion $\to$ Postgres (S5+) | Holocron Maintenance | Transitioning to DB |
| **10. Backup/DR** | Read/Write $\to$ JSON | DR Trigger | Ephemeral / Non-DB |

---

## 3. Agent Access Matrix

| Agent | 1. Tkt | 2. Conf | 3. Cost | 4. Model | 5. Base | 6. Queue | 7. Audit | 8. Cont | 9. Pol | 10. DR |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Warden** | R | R | - | RW | R | R | W | - | R | R |
| **Architect** | R | RW | R | R | RW | R | R | - | RW | R |
| **Finance-Bot** | R | - | RW | - | - | - | R | - | - | - |
| **Content-Gen** | R | - | - | - | - | R | R | RW | R | - |
| **Scribe** | RW | - | - | - | - | - | W | R | R | - |
| **Auditor** | R | R | R | R | R | R | R | R | R | R |
| **Ops-Agent** | R | RW | R | - | RW | RW | W | - | R | RW |
| **Policy-Bot** | R | - | - | RW | R | - | W | - | RW | - |
| **Memory-Mgr** | R | - | - | - | - | - | RW | - | R | RW |
| **Task-Master** | RW | - | - | - | - | RW | W | - | - | - |
| **Gateway-Bot** | R | RW | - | - | - | - | W | - | R | - |
| **Analyst** | R | - | R | R | R | - | R | R | R | - |
| **Nexus-Core** | RW | RW | RW | RW | RW | RW | RW | RW | RW | RW |

*(R = Read, W = Write, RW = Read/Write, - = No Access)*

---

## 4. Archive & Deletion Plan

### 📂 Archive Path: `state/archive/`
The following files are identified for movement to the archive to reduce workspace noise:
- All daily logs (`state/logs/YYYY-MM-DD.json`)
- One-off research dumps
- Duplicates of legacy state files

### 🗑️ Deletion Candidates (Obsolete)
The following are obsolete duplicates and should be deleted:
- `cost-forecast-*.json`
- `p1-cost-forecast-*.json`
- `atlas-tkt-*.json`

---

## 5. Migration Roadmap

- **Sprint 4 (Current):** Top 5 State Files Migration (TKT-0198). In-progress.
- **Sprint 5:** Transition Content (Domain 8) and Policy (Domain 9) domains from JSON to Postgres.
- **Sprint 6:** Migrate remaining relevant JSON state to Postgres where architectural benefit exists.
- **Post-P2:** Final transition of all Compliance/Audit JSON logs into T1 Postgres tables.
