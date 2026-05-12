# File Routing Policy — AInchors Nexus Platform
**Version:** 1.0
**Status:** APPROVED — Ken Mun (CTO), 2026-05-12
**Author:** Yoda 🟢 (with Atlas 🏛️ review pending)
**Scope:** MVP phase. Reviewed at P1 gate.
**Supersedes:** Informal routing assumptions. Amends TKT-0124 (Hybrid Storage Amendment).

---

**ITIL Practice:** Service Configuration Management

## Core Principle

> **Google Drive is the Single Source of Truth (SSOT) for all human-readable, human-accessible files.**
> OC1 local is agent-reference only — a working copy, not the master.
> MinIO is the agent layer — machine-readable, not human-facing.
> OC1 local state/scripts/config are platform-internal — never routed out.

Sync integrity is non-negotiable. Drive and local must not drift. All routing rules include a sync obligation where both destinations are used.

---

## Storage Destinations — Reference

| Destination | Purpose | Access |
|---|---|---|
| **Google Drive** | SSOT for all human-readable files | Ken, Angie, KL team (P1+), mobile, Windows, any browser |
| **OC1 local `docs/`** | Agent-reference copy of Drive docs | Agents only — read for context, write to sync to Drive |
| **OC1 local `canvas/`** | Working render path for HTML deliverables | Ken opens by local path OR via Drive copy |
| **OC1 local `workspace-social/`** | Working draft staging for social content | Agents only — source for Drive sync |
| **OC1 local `reports/`** | Diagnostic and sprint reports | Agents only — sprint reports synced to Drive |
| **OC1 local `state/`** | Machine state — JSON, counters, flags | Platform-internal only. Never synced or shared. |
| **OC1 local `scripts/`** | Automation scripts | Platform-internal only. GitHub is the SSOT for scripts. |
| **MinIO `agent-memory`** | Aria + agent persistent memory (structured) | Agent API only — not human-facing |
| **MinIO `generated-media`** | HF/FLUX images, presigned URL delivery | Agent writes; humans receive via presigned URL |
| **MinIO `workspace-assets`** | Internal ops, script outputs, state backups | Agent API only |
| **MinIO `brand-code`** | Structured Brand Code JSON/MD for agent consumption | Agent API only |

---

## File Routing Rules (LOCKED — Ken Mun, 2026-05-12)

### 1. EA / Architecture Documents
- **Primary (SSOT):** Google Drive → `AInchors — Yoda Working Files/EA Assessments/`
- **Secondary (agent-ref):** OC1 `docs/` local
- **Sync obligation:** Every write to `docs/` triggers a Drive upload via `gog drive upload`
- **Examples:** EA addendums, Atlas deliverables, architecture decision records

### 2. Canvas HTML (Standup, Blog, Slides, Pitch Decks)
- **Primary (SSOT):** Google Drive → `AInchors — Yoda Working Files/Canvas/`
- **Secondary (render path):** OC1 `canvas/documents/` local (Ken opens by local path during session)
- **Sync obligation:** Every canvas file created triggers a Drive upload
- **Classification:** Permanent deliverables — not working files
- **Examples:** Daily standup HTML, blog posts, openclaw-slides decks, marketing collaterals

### 3. Proposals / Client Pitch Documents
- **Primary (SSOT):** Google Drive → `AInchors — Yoda Working Files/Proposals/`
- **Secondary (agent-ref):** OC1 `docs/` or `canvas/` local depending on format
- **Sync obligation:** Immediate Drive upload on creation
- **Examples:** Consulting proposals, capability decks, Ahsoka client deliverables

### 4. Marketing Collaterals
- **Primary (SSOT):** Google Drive → `AInchors — Yoda Working Files/Marketing/`
- **Secondary:** OC1 `canvas/documents/` local (render path only)
- **Sync obligation:** Immediate Drive upload on creation
- **Access note:** Angie accesses via Drive — local path is not accessible to her
- **Examples:** Company overview, training brochure, client pitch HTML

### 5. LinkedIn / Social Content Drafts
- **Primary (SSOT):** Google Drive → `AInchors — Yoda Working Files/Social/Drafts/`
- **Secondary (staging):** OC1 `workspace-social/` local
- **Sync obligation:** Drive upload before Ken/Angie review. Posted = archived to `Social/Published/`
- **Examples:** LinkedIn posts, campaign copy, Spark outputs

### 6. Sprint Reports / Operational Reports
- **Primary (SSOT):** Google Drive → `AInchors — Yoda Working Files/Sprint Docs/`
- **Secondary:** OC1 `reports/` local
- **Sync obligation:** Sprint reports synced to Drive at sprint close. Diagnostics: local only unless Ken requests.
- **Examples:** Sprint reviews, burndowns, SLA reports

### 7. Journals (Daily + Blog)
- **Primary (SSOT):** Google Drive → `AInchors — Yoda Working Files/Journal/`
- **Secondary:** OC1 `memory/journal-YYYY-MM-DD.md` local
- **Sync obligation:** EOD cron `c5a3911d` handles Drive sync at 23:00 AEST nightly
- **Note:** EOD cron owns this — heartbeat must never touch it

### 8. Generated Images (HF/FLUX)
- **Primary:** MinIO `ainchors-generated-media` bucket
- **Delivery:** Presigned URL (time-limited) for LinkedIn/social delivery
- **No Drive copy** — transient media, not archival documents
- **No local persistence** beyond temp generation path

### 9. Agent Memory (Aria, structured)
- **Primary:** MinIO `ainchors-agent-memory` bucket
- **No Drive copy** — machine-readable, not human-facing
- **Human-readable summaries** (if needed): route via Rule 1 (EA/docs) to Drive

### 10. Brand Code (Structured)
- **Primary (machine):** MinIO `ainchors-brand-code` bucket (JSON/MD for agent consumption)
- **Primary (human):** Google Drive → Brand Code Google Doc (Angie-authored, Ken approved)
- **Sync obligation:** When Brand Code is updated in Drive, agent syncs structured version to MinIO
- **Note:** Drive = human SSOT. MinIO = agent consumption copy.

### 11. State / Config / Scripts
- **Destination:** OC1 local only (`state/`, `scripts/`, `openclaw.json`)
- **No Drive sync, no MinIO**
- **Scripts SSOT:** GitHub (`kenmun-ainchors` account)
- **Exception:** `state/` backups → MinIO `ainchors-workspace-assets` (automated, not human-facing)

---

## Sync Rules

### Drive ↔ Local Sync Obligations

| Trigger | Action | Cron / Script |
|---|---|---|
| Agent creates file in `docs/` | Upload to Drive EA Assessments folder | `gog drive upload` inline or post-task |
| Agent creates canvas HTML | Upload to Drive Canvas folder | `gog drive upload` inline or post-task |
| Agent creates marketing/proposal | Upload to Drive Marketing or Proposals folder | `gog drive upload` inline or post-task |
| Agent creates social draft | Upload to Drive Social/Drafts folder | `gog drive upload` inline or post-task |
| EOD (23:00 AEST nightly) | Sync journals + sprint docs to Drive | Cron `c5a3911d` |
| Sprint close | Sprint report uploaded to Drive | Manual trigger or sprint-close script |

### Sync Integrity Rule
- If Drive upload fails: log to `state/drive-sync-failures.json`, alert Ken at next heartbeat
- Agents must not assume Drive is current — always confirm upload success before marking task done
- Drive is SSOT: if Drive and local conflict, Drive wins

---

## Google Drive Folder Structure (Target)

```
AInchors — Yoda Working Files/
├── EA Assessments/          ← Atlas docs, architecture decisions
├── Canvas/                  ← HTML deliverables (standup, blog, slides)
├── Proposals/               ← Client pitches, consulting proposals
├── Marketing/               ← Marketing collaterals, brand assets
├── Social/
│   ├── Drafts/              ← Spark outputs, pending review
│   └── Published/           ← Archived after posting
├── Sprint Docs/             ← Sprint reviews, burndowns, reports
├── Journal/                 ← Daily journals, blog posts
└── Generated Images/        ← If Drive copy needed (normally MinIO only)
```

---

## Agent Behaviour Rules (Enforceable)

Every agent that produces a human-readable output MUST:

1. **Write locally first** (fast, always works)
2. **Upload to Drive immediately** using `gog drive upload` (or queue for EOD cron)
3. **Confirm upload success** before marking deliverable as done
4. **Log failure** to `state/drive-sync-failures.json` if upload fails
5. **Never report a local path to Ken as the access point** — always provide the Drive link OR confirm it's been synced

Ken accesses files via Drive or via local path during an active session only. Local path is not a durable access method.

---

## Open Items — Pending Atlas Gap Analysis

- [ ] Verify Drive folder structure matches target above (folders may not all exist yet)
- [ ] Verify MinIO buckets match TKT-0124 spec (4 buckets confirmed?)
- [ ] Audit existing `docs/`, `canvas/`, `reports/` for files not yet on Drive
- [ ] Confirm EOD Drive sync cron (`c5a3911d`) is syncing correct folders
- [ ] Backfill: canvas HTML files (8 folders) not yet on Drive
- [ ] Backfill: marketing collaterals (TKT-0027) not yet on Drive
- [ ] Drive-local sync failure logging: `state/drive-sync-failures.json` — does it exist?

---

*Approved: Ken Mun (CTO) — 2026-05-12*
*Next review: P1 gate (OC2 arrival ~Jul 2026)*
*Atlas gap analysis: pending (same session)*
