# Holocron/AKB Refresh + AKB Sync Redesign — CREST Master Plan v2.0
**Date:** 2026-07-11 07:52 AEST
**Requested by:** Ken Mun
**Status:** Pending approval
**Approach:** CREST v1.3 (Plan → Execute → Verify → Replan → Synthesize → Done)

---

## 1. Goal

1. **Refresh AInchors Holocron / AKB** so all content reflects current system state as of 2026-07-11. Eliminate stale references, drift between PG/Notion/local, and outdated tribal knowledge.
2. **Redesign the AKB sync process** so it detects and reports staleness/drift, not just Notion-side edits. Prevent the "Agent Fleet Roster still shows Sonnet" class of bug from recurring.

---

## 2. Evidence Triggering This Plan

- Notion page **Agent Fleet — Roster & TOM** (`355c1829-53ff-81af-a99e-f9080e190322`) showed:
  - All interactive agents assigned `Sonnet` (Anthropic parked per CHG-0502).
  - Governance agents assigned `Haiku` (now `gemma4:31b-cloud`).
  - Lando and Mon Mothma still "Activating" / "Soft-activated" despite being activated 2026-05-10.
  - Model Strategy child page still described 3-tier Anthropic policy from 2026-04.
- `scripts/akb-sync.sh` (3AM daily cron `dce1ada4`) only pulls Notion edits to local `state/akb-pages/`. It does **not** detect stale Notion content when the page itself has not been edited externally.
- `state/akb-sync-state.json` (2026-07-10 03:20 AEST): "10 pages synced, no changes detected. No alert sent." — false negative.

---

## 3. Scope

### 3.1 Holocron Refresh Scope
Same as `state/holocron-refresh-plan-2026-07-09.md` v1.0:

| Source | Location | Owner |
|---|---|---|
| Notion workspace root + DBs | Notion API | Mon Mothma / Yoda |
| Notion AKB pages (synced) | `state/akb-pages/` | akb-sync.sh |
| Core reference docs | `SOUL.md`, `AGENTS.md`, `TOOLS.md`, `USER.md`, `MEMORY.md` | Yoda |
| Shared memory wiki | `memory/shared/*.md` | Yoda / memory-maintenance |
| Architecture & framework docs | `docs/*.md` | Atlas / Thrawn |
| Agent instruction files | `*/SOUL.md`, `*/AGENTS.md`, `*/TOOLS.md` | per-agent |
| Agent skills | `agent-skills/*/SKILL.md` | Forge + domain agents |
| Change log | `memory/CHANGELOG.md`, `docs/CHANGELOG.md` | changelog skill |
| PG SSOT tables | `agent_registry`, `state_changes`, `state_notion_sync`, etc. | pg-sprint-backlog skill |
| State snapshots | `state/*.json` | runtime / scripts |

### 3.2 AKB Sync Redesign Scope
- Build `scripts/akb-drift-check.sh` that compares **canonical sources** against **Notion pages** and produces a drift report.
- Update 3AM cron to run drift check after sync and raise `needs_ken` items / Auto-Heal DB B entries when drift is found.
- Keep current `akb-sync.sh` as the **pull** half; add a new **drift detection** half. Do **not** implement auto-push to Notion without HITL approval.
- Add a regression test that verifies the Agent Fleet page model column matches `state/model-policy.json`.

---

## 4. Staleness / Drift Criteria

1. **Date threshold:** Notion page not edited in 30 days AND references runtime facts changed since last edit.
2. **Drift:** Notion content contradicts PG SSOT or `state/*.json` canonical state.
3. **Missing:** Recent CHGs / tickets / decisions not reflected in reference docs or Notion DBs.
4. **Tribal knowledge:** Instructions duplicated across SOUL/AGENTS/MEMORY instead of canonical skill files.
5. **Broken links:** Notion page/DB IDs, file paths, agent references no longer resolve.

---

## 5. Master DAG

```
Master Ticket: TKT-XXXX — Holocron/AKB Refresh + AKB Sync Redesign
├── Sub-CREST A: Audit & Inventory (Atlas + Thrawn)
│   └── atom: Catalog Holocron artifacts and drift
│   └── atom: Compare agent_registry vs SOUL/AGENTS
│   └── atom: Compare Notion DBs vs state/akb-pages and state_notion_sync
├── Sub-CREST B: AKB Sync Drift Detection Design (Thrawn + Forge)
│   └── atom: Design drift-check architecture
│   └── atom: Prototype scripts/akb-drift-check.sh
├── Sub-CREST C: Prioritize & Plan Updates (Yoda + Ken)
│   └── atom: Classify P1/P2/P3 findings
├── Sub-CREST D: Update Core Reference Docs (Yoda + Forge)
│   └── atom: Refresh memory/shared/notion.md, MEMORY.md, TOOLS.md
│   └── atom: Agent SOUL/AGENTS hard-limit compliance (TKT-0541)
├── Sub-CREST E: Notion AKB Sync & Backfill (Mon Mothma + Forge)
│   └── atom: Backfill CHGs to Archive DB C
│   └── atom: Update Backlog DB A + Auto-Heal DB B
│   └── atom: Refresh AKB data source pages
├── Sub-CREST F: Refresh Agent Skills (Forge + domain agents)
│   └── atom: Audit skills for stale tool lists / DB IDs
├── Sub-CREST G: Memory Maintenance (memory-maintenance skill)
│   └── atom: Promote high-recall memories; archive old dailies
├── Sub-CREST H: AKB Sync Redesign Implementation (Forge)
│   └── atom: Implement akb-drift-check.sh
│   └── atom: Update 3AM cron to run drift check
│   └── atom: Add regression test for Agent Fleet model column
├── Master Verify (Yoda + Sage)
│   └── atom: Cross-check PG vs markdown vs Notion
│   └── atom: Run akb-drift-check.sh and confirm zero P1 drift
└── Master Synthesize & Close (Yoda)
    └── atom: Git commit + final report
```

---

## 6. Phase Details

### Phase 1 — Audit & Inventory (Atlas + Thrawn)
- Catalog all Holocron artifacts with last-modified dates.
- Compare PG `agent_registry` against `*/SOUL.md` + `*/AGENTS.md`.
- Compare Notion DBs against local `state/akb-pages/` and `state_notion_sync`.
- Identify stale docs and drift.
- Deliver: `state/holocron-audit-2026-07-11.json`

### Phase 2 — AKB Sync Drift Detection Design (Thrawn + Forge)
- Decide architecture for `scripts/akb-drift-check.sh`.
- Candidate canonical sources to watch:
  - `state/model-policy.json` → Notion Agent Fleet roster model column
  - `state/agent-status.json` / `state/health-state.json` → Notion status dashboards
  - PG `agent_registry` → agent SOUL/AGENTS existence and metadata
  - PG `state_changes` → CHG Archive DB C completeness
  - `state/akb-sync-state.json` → sync health
- Candidate outputs:
  - `state/akb-drift-report-YYYY-MM-DD.json`
  - Auto-Heal DB B entries for `needs_ken`
  - Telegram alert if P1 drift detected
- Deliver: `state/akb-drift-check-design-2026-07-11.md`

### Phase 3 — Prioritize (Yoda + Ken)
- Classify findings into P1 (must fix), P2 (should fix), P3 (nice to have).
- P1 candidates already known:
  - Agent Fleet roster model assignments ✅ (fixed ad-hoc today, must be regression-tested)
  - `memory/shared/notion.md` old page IDs/API notes
  - Missing recent CHGs in Notion Archive DB C
  - Pending `state_notion_sync` audit from 2026-06-04
  - `MEMORY.md` compactness / promoted memories
  - Agent SOUL/AGENTS hard-limit compliance
- Deliver: `state/holocron-priorities-2026-07-11.md`

### Phase 4 — Update Core Reference Docs (Yoda + Forge)
- Refresh `memory/shared/notion.md` with current DB IDs and API conventions.
- Refresh `MEMORY.md` — move stale inline knowledge to skills or daily memory.
- Verify `TOOLS.md` matches current tooling (gog, colima, ports, Notion IDs).
- Verify `AGENTS.md` Non-Negotiables and Journal Discipline rule are current.
- Ensure all agent SOUL.md ≤ 5,000 chars (TKT-0541 gate).
- Ensure every active agent has AGENTS.md.

### Phase 5 — Notion AKB Sync & Backfill (Mon Mothma + Forge)
- Backfill recent CHGs (CHG-0837 → current) to Archive DB C if missing.
- Resolve pending `state_notion_sync` audit (`sync_type='audit'`).
- Update Notion Backlog DB A with latest ticket statuses from PG.
- Update Auto-Heal DB B with current open `needs_ken` items.
- Refresh AKB data source pages if required.
- Run `scripts/akb-sync.sh` and commit updated `state/akb-sync-state.json`.

### Phase 6 — Refresh Agent Skills (Forge + domain agents)
- Audit `agent-skills/*/SKILL.md` for stale tool lists, env paths, DB IDs.
- Update skill files where runtime conventions have changed.
- Ensure all skills are registered in `agent-skills/.index.json`.

### Phase 7 — Memory Maintenance (memory-maintenance skill)
- Promote high-recall short-term memories to `MEMORY.md`.
- Archive old daily memory files if needed.
- Ensure journal files for recent days are complete and committed.

### Phase 8 — AKB Sync Redesign Implementation (Forge)
- Implement `scripts/akb-drift-check.sh` per Phase 2 design.
- Update 3AM cron `dce1ada4` to run drift check after sync.
- Add regression test: Agent Fleet roster model column must match `state/model-policy.json`.
- Add Auto-Heal integration: P1 drift → DB B + Telegram alert.

### Phase 9 — Verify Consistency (Sage + Yoda)
- Cross-check PG `state_changes` vs `memory/CHANGELOG.md` vs Notion Archive C.
- Cross-check PG ticket tables vs Notion Backlog A.
- Verify `agent_registry` vs local agent directories.
- Run `akb-drift-check.sh` and confirm zero P1 drift.
- Run `akb-sync.sh` and confirm clean.
- Deliver: `state/holocron-verification-2026-07-11.json`

### Phase 10 — Commit & Close (Yoda)
- Git commit all Holocron changes.
- Update `state/akb-sync-state.json`.
- Final report to Ken with before/after metrics.
- Close master ticket.

---

## 7. Execution Model

| Phase | Owner | CREST Role |
|---|---|---|
| 1 Audit | Atlas + Thrawn | design_backend |
| 2 Drift Design | Thrawn + Forge | design_backend + build |
| 3 Prioritize | Yoda + Ken | yoda_master |
| 4 Core Docs | Yoda + Forge | yoda_master + build |
| 5 Notion Sync | Mon Mothma + Forge | change-mgt + build |
| 6 Skills | Forge + domain agents | build + specialist |
| 7 Memory | memory-maintenance skill | yoda_master |
| 8 AKB Sync Impl | Forge | build |
| 9 Verify | Sage + Yoda | governance + yoda_master |
| 10 Close | Yoda | yoda_master |

**Yoda boundaries:** Plan, Prioritize, Verify, Replan, Synthesize, Close. Execution routed to specialists/Forge.

---

## 8. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Large blast radius | Phased execution; commit after each phase; read-only audit first. |
| Overwrite active work | No auto-push to Notion; drift flagged → `needs_ken` → Yoda approves updates. |
| Notion rate limits | Sleep 350ms between calls; batch updates. |
| PG drift from manual fixes | Use canonical `db-raw.sh` and `changelog-append.sh` only. |
| False positives in drift check | Start with narrow canonical sources; tune thresholds before enabling alerts. |
| Context overflow | Run as isolated subagents per phase; keep main session lean. |

---

## 9. Success Criteria

- `state/holocron-audit-*.json` shows all known P1 drift items resolved.
- All CHGs from last 30 days exist in PG + markdown + Notion Archive C.
- `memory/shared/notion.md` matches live Notion workspace.
- All agent SOUL.md ≤ 5,000 chars and have active AGENTS.md.
- `akb-sync.sh` runs clean with no missed changes after updates.
- `akb-drift-check.sh` runs nightly and reports zero P1 drift.
- Git diff is committed and tagged.

---

## 10. Decisions Needed from Ken

1. **Approve this combined plan** (refresh + AKB sync redesign) and Phase 1/2 scope.
2. **AKB sync scope:** Do you want drift detection to **flag only** (safe, HITL), or also **auto-update a whitelist of pages** (e.g. Agent Fleet roster) from canonical state?
3. **Priority:** Should this take precedence over CRESTv2-P1 WS-3 tickets (TKT-0354/0359) currently in progress?
4. **Create master ticket?** I can file `TKT-XXXX` for this work and link it to the existing refresh plan.

---

## 11. First Step (if approved)

Create master ticket and dispatch Atlas + Thrawn to run the audit and deliver `state/holocron-audit-2026-07-11.json` + `state/akb-drift-check-design-2026-07-11.md`.
