# Postgres Migration — Phase 2 Assessment: Remaining Files

**Document ID:** ASSESSMENT_PG_Migration_Phase2_v1.0_2026-05-23
**Author:** Yoda 🟢 (Lead Orchestrator)
**For:** Ken Mun (CTO) — APPROVED 2026-05-25 02:02 GMT
**Ticket:** TKT-0271
**Status:** ✅ APPROVED — Ken Mun, 2026-05-25. Execution authorized.

---

## 1. Current State Inventory

After Sprint 4's Phase 1 migration (TKT-0252–TKT-0264), the `state/` directory contains:

| Category | Count | Status |
|----------|-------|--------|
| JSON files remaining | 129 | Down from 194 (67 migrated/archived) |
| MD files | 28 | Assessment docs, proposals, briefs |
| LOG files | 38 | Auto-heal raw logs (append-only) |
| Subdirectories | 12 | akb-pages, archive, backups, generated-images, etc. |
| **Total state/ items** | **~207** | Excluding backups/ and archive/ |

---

## 2. Categorization: Migrate vs Keep vs Archive

### 2.1 ✅ MIGRATE TO POSTGRES — 42 files

These files have clear Postgres destinations and provide operational value when queryable.

#### Category A: Cost & Finance (3 files)
| File | Destination | Rationale |
|------|------------|-----------|
| `cost-forecast-2026-05-15.json` | `cost_events` (existing) | Structured cost data. Join with agent events for spend-per-agent. |
| `cost-investigation-2026-05-14.json` | `cost_events` | Investigation findings. One-time, but valuable for audit. |
| `p1-cost-forecast-2026-05-15.json` | `cost_events` | P1 forecasts. Historical reference for P2 planning. |
| `api-cost-actuals.json` | `cost_events` | API actuals by provider. Core cost tracking data. |

#### Category B: Operations — Auto-Heal (26 files)
| File | Destination | Rationale |
|------|------------|-----------|
| `auto-heal-2026-04-27.json` through `auto-heal-2026-05-21.json` (26 files) | `state_autoheal_log` (NEW table) | 26 daily JSON summaries. Currently unqueryable as loose files. Single table enables trend analysis ("when did X start failing?"). Raw .log files stay as files. |
| `autoheal-status-report.json` | Merge → `state_autoheal_log` | Current auto-heal status. Consolidate into log table with `is_current=true`. |

#### Category C: Operations — Diagnostics & Uptime (5 files)
| File | Destination | Rationale |
|------|------------|-----------|
| `diagnostics-2026-04-27-0715.json` | `state_diagnostics` (NEW) | Historical diagnostics. Queryable by date for trend analysis. |
| `diagnostics-2026-04-27-0719.json` | `state_diagnostics` | Same as above. |
| `diagnostics-2026-04-27-2206.json` | `state_diagnostics` | Same as above. |
| `diagnostics-2026-04-28-1431.json` | `state_diagnostics` | Same as above. |
| `uptime-log.json` | `state_uptime` (NEW table) | Platform uptime history. Currently a flat file. Useful for SLA tracking. |

#### Category D: Model Performance & Trials (8 files)
| File | Destination | Rationale |
|------|------------|-----------|
| `gemma4-rtb-trial.json` | `state_model_trials` (NEW) | Model trial results. Query: "Which model had lowest latency in May?" |
| `gemma4-shadow.json` | `state_model_trials` | Shadow deployment results. |
| `kimi-rtb-trial.json` | `state_model_trials` | Kimi trial data (decommissioned). |
| ~~`kimi-confidence-mapping.json`~~ | REMOVED (2026-05-26) | DeepSeek is permanent primary model. |
| `interim-model-period.json` | `state_model_trials` | Interim model period tracking. |
| `model-drift-state.json` | `state_model_trials` | Warden drift detection state. |
| `model-drift-violations.json` | `state_model_trials` | Drift violation history. |
| `fallback-chain-status.json` | `state_model_trials` | Active fallback chain configuration. |

#### Category E: Architecture & KRI (1 file)
| File | Destination | Rationale |
|------|------------|-----------|
| `architecture-kri-state.json` | `state_kri` (NEW) | Key Risk Indicators. Strategic platform health metric. Single row, queryable. |

**Subtotal: 42 files → 5 new tables + 1 merge into existing**

---

### 2.2 ⚠️ REVIEW & DECIDE — 27 files

These files need Ken's decision. They could go either way.

| File | Options | Recommendation |
|------|---------|---------------|
| `tickets.json` (850KB, 260+ records) | A) Keep as file until Sprint 5 agent cutover (TKT-0270) then archive | **Recommend A** — `ticket.sh` still reads from this file as primary. After TKT-0270 (agent docs update), switch to PG-primary reads. THEN archive. Don't migrate now — change the read source instead. |
| `sprints-pg-export.json` | A) Delete — this is a sync-out.sh export, redundant | **Recommend A** — Delete. It's a PG export file, not source data. |
| `standups-pg-export.json` | A) Delete — sync-out.sh export | **Recommend A** — Delete. |
| `tickets-pg-export.json` | A) Delete — sync-out.sh export | **Recommend A** — Delete. |
| `file-inventory.json` | A) Keep as permanent record | **Recommend A** — This documents the transition. Historical artifact, not operational. |
| `ci-cycle-b-template.json` | A) Keep as reference template | **Recommend A** — Template file, not state data. |
| `linkedin-auth.json` | A) Keep — auth credentials, not state data | **Recommend A** — Auth tokens should not go in PG. Keep in Keychain or encrypted file. |
| `linkedin-metrics-errors.json` | A) Archive — residual error log | **Recommend A** — Archive. Low value, no query need. |
| `minio-routing-policy.json` | A) Keep — routing config, rarely changes | **Recommend A** — Infrastructure config. Not agent state. |
| `skill-url-allowlist.json` | A) Keep — security config | **Recommend A** — Security boundary config. |
| `template-lock.json` | A) Keep — operational lock file | **Recommend A** — Lock file, not data. |
| `drive-folder-ids.json` | A) Migrate to `agent_shared_state` | **Recommend B** — It's a key-value config that agents reference. Fit for shared_state. |
| `drive-link-map.json` | A) Migrate to `agent_shared_state` | **Recommend B** — Same as above. |
| `gdrive-folders.json` | A) Delete — superseded by drive-folder-ids | **Recommend A** — Redundant. |
| `strategy-index.json` | A) Keep as reference doc | **Recommend A** — Strategic reference, not operational state. |
| `active-work.json` | A) Migrate to `agent_shared_state` | **Recommend B** — Active work context, agents reference it. |
| `ahsoka-pilot-state.json` | A) Migrate to `state_tickets` notes | **Recommend B** — Pilot completion tracking. Link to TKT-0082/0083. |
| `channel-state.json` | A) Migrate to `agent_shared_state` | **Recommend B** — Cross-channel decision bridge. Fits key-value pattern. |
| `daily-note.json` | A) Migrate to `agent_shared_state` | **Recommend B** — Daily note state. Simple KV. |
| `yoda-relay-queue.json` (not archived) | A) Migrate to `state_relay_queue` NEW | **Recommend B** — Previously in archive list but wasn't archived. Message relay queue. |
| `task-queue.json` (remaining) | A) Keep — task-queue-dispatch already merged | **Recommend A** — This may be the TQP master file. Review before touching. |
| `tkt-0088-decisions.json` | A) Archive — legacy sprint output | **Recommend A** — Historical only, low query value. |
| `tkt-0230-groomed.json` | A) Archive — legacy grooming output | **Recommend A** — Historical only. |
| `atlas-p3-amendment-summary.json` | A) Archive — legacy assessment | **Recommend A** — EA assessment, already in knowledge_documents. |
| `atlas-tkt-0046-summary.json` | A) Archive | **Recommend A** — Historical. |
| `atlas-tkt-0103-summary.json` | A) Archive | **Recommend A** — Historical. |
| `atlas-tkt-0104-summary.json` | A) Archive | **Recommend A** — Historical. |

**Recommendation: 8 migrate, 17 keep/archive, 3 delete**

---

### 2.3 ❌ DO NOT MIGRATE — Keep as Files (60 files)

These are operational files that should remain as files. They are not state data.

| Category | Files | Count | Why |
|----------|-------|-------|-----|
| **Auto-heal raw logs** | `auto-heal-2026-*.log` | 38 | Append-only sequential writes. Terrible for DB, perfect for files. |
| **AKB pages cache** | `akb-pages/*.md` | 24 | Notion cache — regenerated automatically. Not platform state. |
| **Subdirectories** | `benchmark/`, `cache/`, `checkpoints/`, `generated-images/`, `incidents/`, `owl-archive/`, `phase5-results/`, `pir/`, `problems/` | 9 dirs | Binary files, images, incident reports, checkpoints. Keep as files. |
| **MD assessment docs** | `atlas-*.md`, `thrawn-*.md`, `tkt-*.md`, etc. | 20 | Human-authored work products. Already in knowledge_documents for search. Keep originals. |
| **PG exports** | `*pg-export.json` | 3 | Generated by sync-out.sh. Delete these — don't archive, don't migrate. They're copies. |
| **Infra config** | `minio-routing-policy.json`, `skill-url-allowlist.json` | 2 | Security boundary configs. |
| **Auth** | `linkedin-auth.json` | 1 | Auth tokens — not database material. |
| **Lock/template** | `template-lock.json`, `ci-cycle-b-template.json` | 1 | Operational lock files. |

---

### 2.4 🗑️ DELETE — Low-value artifacts (3 files)

| File | Reason |
|------|--------|
| `sprints-pg-export.json` | PG export. Redundant copy of state_sprints table. |
| `standups-pg-export.json` | PG export. Redundant copy of state_standups table. |
| `tickets-pg-export.json` | PG export. Redundant copy of state_tickets table. |
| `gdrive-folders.json` | Superseded by `drive-folder-ids.json`. |

---

## 3. Recommended Migration: 50 files total

| New Table | Files | Count | Effort |
|-----------|-------|-------|--------|
| `state_autoheal_log` | 26 daily JSON + 1 status | 27 | 1hr — batch ETL |
| `state_diagnostics` | 4 diagnostic JSON | 4 | 30min — date-partitioned |
| `state_uptime` | 1 uptime log | 1 | 15min — simple table |
| `state_model_trials` | 8 model files | 8 | 1hr — unified schema |
| `state_kri` | 1 KRI file | 1 | 15min — single row |
| `cost_events` (merge) | 4 cost files | 4 | 30min — merge into existing |
| `agent_shared_state` (merge) | 5 KV config files | 5 | 30min — key-value inserts |
| **TOTAL** | | **50** | **~4 hours** |

---

## 4. Post-Migration State

After executing this migration:

| Category | Before | After |
|----------|--------|-------|
| JSON files in `state/` | 129 | ~79 |
| Files migrated to PG | 0 (Phase 1 complete) | +50 |
| Total PG rows added | N/A | ~150+ |
| Tickets.json status | File-primary | File-primary (read source unchanged — TKT-0270 handles switch) |
| Deleted (PG exports) | 3 | 0 |
| Archived | 0 | ~47 historical JSON |

**Remaining ~79 files will be:** 38 auto-heal .logs, 24 akb-pages cache, 9 subdirectories, 5 config/auth, 3 MD assessments. All legitimately file-resident.

---

## 5. Recommended Execution

1. **Review & approve** this assessment
2. Execute TKT-0268 (24h stability) + TKT-0269 (backup) first
3. Execute TKT-0271 in Sprint 5:
   - Create 4 new tables + 1 merge
   - Migrate 50 files
   - Delete 4 PG exports
   - Re-run sync-out.sh
   - Update file-inventory.json
4. Execute TKT-0270 (agent SOUL/RULES update) in parallel or after
5. Then: switch `ticket.sh` to PG-primary reads (part of TKT-0270 scope)
6. After 48h stability: archive tickets.json

---

## 6. Decision Required

Ken, please review and select:

**Option A (recommended):** Execute as recommended above — 50 files migrated, 4 new tables, ~4 hours effort.

**Option B:** Execute with modifications — let me know what to change.

**Option C:** Defer to Sprint 6 — continue with current state, revisit later.

---

*End of Assessment. For Ken Mun review before TKT-0271 execution.*
