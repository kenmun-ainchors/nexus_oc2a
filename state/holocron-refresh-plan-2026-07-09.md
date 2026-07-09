# Holocron (AKB) Comprehensive Refresh — CREST Plan v1.0
**Date:** 2026-07-09 18:15 AEST  
**Requested by:** Ken Mun  
**Approach:** CREST (Plan → Verify → Execute → Replan → Synthesize → Close)  

## Goal
Review and update the AInchors Holocron / AKB (Agent Knowledge Base) so all content reflects the **current system state** as of 2026-07-09. Eliminate stale references, drift between PG/Notion/local, and outdated tribal knowledge.

---

## 1. Scope — What is "Holocron"
| Source | Location | Size / Count | Owner / Agent |
|---|---|---|---|
| Notion workspace root + DBs | Notion API | 10+ DBs, 100s pages | Mon Mothma / Yoda |
| Notion AKB pages (synced) | `state/akb-pages/` | 598 pages synced | akb-sync.sh |
| Core reference docs | `SOUL.md`, `AGENTS.md`, `TOOLS.md`, `USER.md`, `MEMORY.md` | ~21 KB total | Yoda |
| Shared memory wiki | `memory/shared/*.md` | 10 files | Yoda / memory-maintenance |
| Architecture & framework docs | `docs/*.md` | 88 files | Atlas / Thrawn |
| Agent instruction files | `*/SOUL.md`, `*/AGENTS.md`, `*/TOOLS.md`, `*/USER.md` | 8 agents × 4 files | per-agent |
| Agent skills | `agent-skills/*/SKILL.md` | 10 skills | Forge + domain agents |
| Daily / short-term memory | `memory/YYYY-MM-DD.md`, `memory/journal-YYYY-MM-DD.md` | 137+ files | memory-maintenance |
| Change log | `memory/CHANGELOG.md`, `docs/CHANGELOG.md` | ~2 MB | changelog skill |
| PG SSOT tables | `agent_registry`, `state_changes`, `state_notion_sync`, etc. | live | pg-sprint-backlog skill |
| State snapshots | `state/*.json` | 215 files | runtime / scripts |

---

## 2. Staleness Criteria
Content is **stale** if any of the following are true:
1. **Date threshold:** Not edited in the last **30 days** AND references runtime facts that have changed.
2. **Drift:** Local copy contradicts PG or Notion source of truth.
3. **Missing:** Recent CHGs / tickets / decisions are not reflected in reference docs or Notion DBs.
4. **Tribal knowledge:** Instructions duplicated across SOUL/AGENTS/MEMORY instead of living in canonical skill files.
5. **Broken links:** Notion page/DB IDs, file paths, or agent references that no longer resolve.

---

## 3. Phases

### Phase 1 — Audit & Inventory (Atlas + Thrawn)
- Catalog all Holocron artifacts with last-modified dates.
- Compare PG `agent_registry` against `*/SOUL.md` + `*/AGENTS.md`.
- Compare Notion DBs against local `state/akb-pages/` and `state_notion_sync`.
- Identify stale docs and drift.
- Deliver: `state/holocron-audit-2026-07-09.json`

### Phase 2 — Prioritize (Yoda + Ken)
- Classify findings into P1 (must fix), P2 (should fix), P3 (nice to have).
- P1 candidates:
  - `memory/shared/notion.md` (old page IDs, API notes)
  - Missing recent CHGs in Notion Archive DB C
  - Pending `state_notion_sync` audit from 2026-06-04
  - `MEMORY.md` compactness / promoted memories
  - Agent SOUL/AGENTS hard-limit compliance
- Deliver: `state/holocron-priorities-2026-07-09.md`

### Phase 3 — Update Core Reference Docs (Forge + Yoda)
- Update `memory/shared/notion.md` with current DB IDs and API conventions.
- Refresh `MEMORY.md` — move stale inline knowledge to skills or daily memory.
- Verify `TOOLS.md` matches current tooling (gog, colima, ports, Notion IDs).
- Verify `AGENTS.md` Non-Negotiables and Journal Discipline rule are current.
- Ensure all agent SOUL.md ≤ 5,000 chars (TKT-0541 gate).
- Ensure every active agent has AGENTS.md.

### Phase 4 — Sync Notion AKB (Mon Mothma / Notion skill)
- Backfill recent CHGs (CHG-0837 → CHG-0845) to Archive DB C if missing.
- Resolve pending `state_notion_sync` audit (`sync_type='audit'`).
- Update Notion Backlog DB A with latest ticket statuses from PG.
- Update Auto-Heal DB B with current open `needs_ken` items.
- Refresh AKB data source pages if required.
- Run `scripts/akb-sync.sh` and commit updated `state/akb-sync-state.json`.

### Phase 5 — Refresh Agent Skills (Forge + domain agents)
- Audit `agent-skills/*/SKILL.md` for stale tool lists, env paths, DB IDs.
- Update skill files where runtime conventions have changed (e.g., `model-routing`, `changelog`, `notion`).
- Ensure all skills are registered in `agent-skills/.index.json`.

### Phase 6 — Memory Maintenance (memory-maintenance skill)
- Promote high-recall short-term memories to `MEMORY.md`.
- Archive old daily memory files if needed.
- Ensure journal files for 2026-07-07/08/09 are complete and committed.

### Phase 7 — Verify Consistency (Sage)
- Cross-check PG `state_changes` vs `memory/CHANGELOG.md` vs Notion Archive C.
- Cross-check PG ticket tables vs Notion Backlog A.
- Verify `agent_registry` vs local agent directories.
- Run health checks and report drift.
- Deliver: `state/holocron-verification-2026-07-09.json`

### Phase 8 — Commit & Close (Yoda)
- Git commit all Holocron changes.
- Update `state/akb-sync-state.json`.
- Final report to Ken with before/after metrics.

---

## 4. Execution Model
- **Yoda:** Plan, prioritize, synthesize, close.
- **Atlas / Thrawn:** Audit architecture/docs.
- **Forge:** Script/skill edits, Notion sync automation.
- **Mon Mothma:** Notion DB updates, change-record hygiene.
- **Sage:** Verification and consistency checks.
- **Domain agents:** Update their own SOUL/AGENTS if needed.

---

## 5. Risks & Mitigations
| Risk | Mitigation |
|---|---|
| Large blast radius | Do it in phases; commit after each phase. |
| Overwrite active work | Read-only audit first; writes only after Yoda/Ken approve phase outputs. |
| Notion rate limits | Sleep 350ms between calls; batch updates. |
| PG drift from manual fixes | Use canonical `db-raw.sh` and `changelog-append.sh` only. |
| Context overflow | Run as isolated subagents per phase; keep main session lean. |

---

## 6. Success Criteria
- `state/holocron-audit-*.json` shows zero P1 drift.
- All CHGs from last 30 days exist in PG + markdown + Notion Archive C.
- `memory/shared/notion.md` matches live Notion workspace.
- All agent SOUL.md ≤ 5,000 chars and have active AGENTS.md.
- `akb-sync.sh` runs clean with `changes=0 updated=0 new=0` after all updates.
- Git diff is committed and tagged.

---

## 7. First Step
Approve this plan and Phase 1 scope. Yoda will dispatch Atlas + Thrawn to run the audit and deliver `state/holocron-audit-2026-07-09.json`.
